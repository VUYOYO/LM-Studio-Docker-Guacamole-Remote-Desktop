(function () {
  function bootstrap() {
    if (window.__guacClipboardBridgeLoaded) {
      return;
    }
    window.__guacClipboardBridgeLoaded = true;

    var bridgeBase = '/__clipboard_bridge';
    var pullUrl = bridgeBase + '/pull';
    var pushUrl = bridgeBase + '/push';
    var eventUrl = bridgeBase + '/event';
    var maxLocalText = 81920; // 不建议调整，太多的话可能会导致浏览器剪贴板接口调用失败，甚至崩溃。
    var pasteLocked = false;
    var copySyncInFlight = false;

    function debugLog() {
      if (!window.console || !console.log) {
        return;
      }
      var args = Array.prototype.slice.call(arguments);
      args.unshift('[clipboard-bridge]');
      console.log.apply(console, args);
    }

    function postEvent(action, detail) {
      fetch(eventUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        cache: 'no-store',
        keepalive: true,
        body: JSON.stringify({ action: action, detail: detail || {} }),
      }).catch(function () {});
    }

    function pageFocused() {
      return !!(document.hasFocus && document.hasFocus() && document.visibilityState === 'visible');
    }

    async function apiJson(url, options) {
      var res = await fetch(url, Object.assign({ cache: 'no-store' }, options || {}));
      if (!res.ok) {
        throw new Error('HTTP ' + res.status + ' @ ' + url);
      }
      return res.json();
    }

    async function readLocalClipboard() {
      if (!navigator.clipboard || !navigator.clipboard.readText) {
        return '';
      }
      try {
        return await navigator.clipboard.readText();
      } catch (e) {
        return '';
      }
    }

    async function writeLocalClipboard(text) {
      if (!text || !navigator.clipboard || !navigator.clipboard.writeText) {
        return false;
      }
      try {
        await navigator.clipboard.writeText(text);
        return true;
      } catch (e) {
        return false;
      }
    }

    async function sendClipboardToRemote(source, text) {
      if (!text) {
        return;
      }
      var payloadText = text;
      if (payloadText.length > maxLocalText) {
        payloadText = payloadText.slice(0, maxLocalText);
      }

      debugLog('send_clipboard', {
        source: source,
        text: payloadText,
        length: payloadText.length,
      });

      await apiJson(pushUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: payloadText, source: source }),
      });

      postEvent('push_ok', { source: source, length: payloadText.length });
    }

    function setPasteLocked(locked, reason) {
      if (pasteLocked === locked) {
        return;
      }
      pasteLocked = locked;
      debugLog(locked ? 'paste_locked' : 'paste_unlocked', { reason: reason || '' });
      postEvent(locked ? 'paste_locked' : 'paste_unlocked', { reason: reason || '' });
    }

    async function syncRemoteCopyToLocal(source) {
      if (!pageFocused()) {
        return;
      }

      if (copySyncInFlight) {
        postEvent('copy_cut_sync_skipped', { source: source, reason: 'in_flight' });
        return;
      }

      copySyncInFlight = true;
      setPasteLocked(true, source + ':start');

      try {
        var payload = await apiJson(pullUrl);
        var remoteText = (payload && typeof payload.text === 'string') ? payload.text : '';
        if (!remoteText) {
          postEvent('copy_cut_sync_empty', { source: source });
          return;
        }

        var ok = await writeLocalClipboard(remoteText);
        debugLog('copy_cut_sync', {
          source: source,
          length: remoteText.length,
          localWrite: ok,
        });
        postEvent('copy_cut_sync', { source: source, length: remoteText.length, localWrite: ok });
      } catch (e) {
        postEvent('copy_cut_sync_error', { source: source, message: String((e && e.message) || e) });
      } finally {
        setPasteLocked(false, source + ':done');
        copySyncInFlight = false;
      }
    }

    window.addEventListener('keydown', function (e) {
      if (!e) {
        return;
      }

      var key = String(e.key || '').toLowerCase();
      var ctrl = !!e.ctrlKey;
      var meta = !!e.metaKey;

      if (ctrl && !meta && key === 'v') {
        debugLog('keydown window', { key: 'v', ctrl: true, meta: false });
        if (pasteLocked) {
          if (e.preventDefault) {
            e.preventDefault();
          }
          if (e.stopPropagation) {
            e.stopPropagation();
          }
          if (e.stopImmediatePropagation) {
            e.stopImmediatePropagation();
          }
          postEvent('ctrl_v_blocked', {
            pasteLocked: pasteLocked,
            reason: 'copy_cut_sync_in_progress',
          });
          return;
        }

        readLocalClipboard().then(function (text) {
          if (!text) {
            postEvent('ctrl_v_empty_clipboard', {});
            return;
          }
          return sendClipboardToRemote('window:ctrl-v', text);
        }).catch(function (err) {
          postEvent('ctrl_v_error', { message: String((err && err.message) || err) });
        });
        return;
      }

      if (!pageFocused()) {
        return;
      }

      if (ctrl && !meta && (key === 'c' || key === 'x')) {
        syncRemoteCopyToLocal('window:ctrl-' + key);
      }
    }, true);

    window.addEventListener('copy', function () {
      if (!pageFocused()) {
        return;
      }
      syncRemoteCopyToLocal('window:copy-event');
    }, true);

    window.addEventListener('cut', function () {
      if (!pageFocused()) {
        return;
      }
      syncRemoteCopyToLocal('window:cut-event');
    }, true);

    debugLog('script_loaded_simple_mode', { href: location.href });
    postEvent('script_loaded_simple_mode', { href: location.href });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', bootstrap, { once: true });
  } else {
    bootstrap();
  }
})();
