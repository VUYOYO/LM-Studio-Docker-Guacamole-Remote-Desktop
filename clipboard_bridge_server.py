#!/usr/bin/env python3
import argparse
import datetime
import json
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def run_command(args, input_text=None):
    try:
        proc = subprocess.run(
            args,
            input=input_text,
            text=True,
            capture_output=True,
            check=False,
            timeout=3,
        )
        return proc.returncode, proc.stdout
    except Exception:
        return 1, ""


def read_selection(selection):
    code, out = run_command(["xclip", "-selection", selection, "-o"])
    if code != 0:
        return ""
    return out


def write_selection(selection, text):
    run_command(["xclip", "-selection", selection, "-i"], input_text=text)


def send_hotkey(combo):
    code, _ = run_command(["xdotool", "key", "--clearmodifiers", combo])
    return code == 0


def type_text(text):
    code, _ = run_command(["xdotool", "type", "--clearmodifiers", "--file", "-"], input_text=text)
    return code == 0


def now_ts():
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def preview_text(text, max_len=80):
    if text is None:
        return ""
    safe = text.replace("\n", "\\n").replace("\r", "\\r")
    if len(safe) <= max_len:
        return safe
    return safe[:max_len] + "..."


def log_event(event, **kwargs):
    details = " ".join([f"{k}={json.dumps(v, ensure_ascii=False)}" for k, v in kwargs.items()])
    if details:
        print(f"[clipboard-bridge] {now_ts()} event={event} {details}", flush=True)
    else:
        print(f"[clipboard-bridge] {now_ts()} event={event}", flush=True)


class ClipboardBridgeHandler(BaseHTTPRequestHandler):
    max_chars = 8192
    last_pull_seen = ""
    ignored_frontend_actions = {
        "remote_paste_hotkey_ok",
        "remote_paste_hotkey_failed",
        "remote_paste_hotkey_error",
    }

    def log_message(self, fmt, *args):
        return

    def _send_json(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Pragma", "no-cache")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):
        if self.path == "/health":
            self._send_json(200, {"ok": True})
            return

        if self.path == "/pull":
            text = read_selection("clipboard")
            if text != ClipboardBridgeHandler.last_pull_seen:
                ClipboardBridgeHandler.last_pull_seen = text
            self._send_json(200, {"ok": True, "text": text, "length": len(text)})
            return

        self._send_json(404, {"ok": False, "error": "not_found"})

    def do_POST(self):
        if self.path not in ("/push", "/event", "/action"):
            self._send_json(404, {"ok": False, "error": "not_found"})
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            length = 0

        body = self.rfile.read(max(length, 0)).decode("utf-8", errors="replace")
        try:
            payload = json.loads(body) if body else {}
        except Exception:
            self._send_json(400, {"ok": False, "error": "invalid_json"})
            return

        if self.path == "/event":
            action = payload.get("action", "unknown")
            detail = payload.get("detail", {})
            if not isinstance(detail, dict):
                detail = {"value": str(detail)}

            # Older frontend builds may emit remote_paste_hotkey_* telemetry.
            # Drop these noisy delayed events to keep logs aligned with push-only flow.
            if action in self.ignored_frontend_actions:
                self._send_json(200, {"ok": True, "ignored": True})
                return

            log_event("frontend", action=action, detail=detail)
            self._send_json(200, {"ok": True})
            return

        if self.path == "/action":
            action = payload.get("action", "")
            request_id = payload.get("request_id", "")
            source = payload.get("source", "web")
            if action == "remote_paste_hotkey":
                log_event(
                    "action_blocked",
                    action=action,
                    request_id=request_id,
                    source=source,
                    reason="push_only_mode",
                )
                self._send_json(
                    200,
                    {
                        "ok": False,
                        "error": "remote_paste_hotkey_disabled",
                        "request_id": request_id,
                    },
                )
                return

            self._send_json(400, {"ok": False, "error": "unknown_action"})
            return

        text = payload.get("text", "")
        source = payload.get("source", "web")
        request_id = payload.get("request_id", "")
        if not isinstance(text, str):
            text = str(text)

        if len(text) > self.max_chars:
            text = text[: self.max_chars]

        write_selection("clipboard", text)
        write_selection("primary", text)
        log_event("push", source=source, request_id=request_id, length=len(text), preview=preview_text(text))

        self._send_json(200, {"ok": True, "written": len(text), "request_id": request_id})


def clipboard_watch_loop(poll_interval):
    last_clipboard = None
    last_primary = None
    while True:
        clip = read_selection("clipboard")
        prim = read_selection("primary")

        if clip != last_clipboard:
            log_event("remote_clipboard_changed", length=len(clip), preview=preview_text(clip))
            last_clipboard = clip

        if prim != last_primary:
            log_event("remote_primary_changed", length=len(prim), preview=preview_text(prim))
            last_primary = prim

        time.sleep(max(0.2, poll_interval))


def main():
    parser = argparse.ArgumentParser(description="HTTP clipboard bridge")
    parser.add_argument("--bind", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=18080)
    parser.add_argument("--max-chars", type=int, default=8192)
    parser.add_argument("--poll-interval", type=float, default=0.8)
    args = parser.parse_args()

    ClipboardBridgeHandler.max_chars = max(1, args.max_chars)
    watcher = threading.Thread(target=clipboard_watch_loop, args=(args.poll_interval,), daemon=True)
    watcher.start()
    server = ThreadingHTTPServer((args.bind, args.port), ClipboardBridgeHandler)
    log_event("bridge_started", bind=args.bind, port=args.port, max_chars=args.max_chars)
    server.serve_forever()


if __name__ == "__main__":
    main()
