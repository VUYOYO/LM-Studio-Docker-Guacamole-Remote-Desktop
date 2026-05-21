#!/bin/sh
set -eu

DELAY="30"
TIMEOUT="180"
INTERVAL="5"

reason=""
json_warned="false"

if [ -r /proc/uptime ]; then
    host_uptime="$(cut -d. -f1 /proc/uptime 2>/dev/null || echo 0)"
    if echo "$host_uptime" | grep -Eq '^[0-9]+$' && [ "$host_uptime" -lt 300 ]; then
        DELAY=$((DELAY + 30))
        TIMEOUT=$((TIMEOUT + 120))
        echo "[wait_init] cold boot detected (uptime=${host_uptime}s), extending guard window"
    fi
fi

is_positive_int() {
    case "$1" in
        ''|*[!0-9]*)
            return 1
            ;;
        *)
            [ "$1" -gt 0 ]
            ;;
    esac
}

check_ready() {
    if [ ! -e /host/dev/nvidiactl ] && [ ! -e /host/dev/nvidia0 ]; then
        reason="NVIDIA device nodes are not ready (/dev/nvidiactl or /dev/nvidia0)"
        return 1
    fi

    has_vulkan_json="false"
    has_egl_json="false"
    for f in /host/usr/share/vulkan/icd.d/*nvidia*.json /host/etc/vulkan/icd.d/*nvidia*.json; do
        if [ -f "$f" ]; then
            has_vulkan_json="true"
            break
        fi
    done
    for f in /host/usr/share/glvnd/egl_vendor.d/*nvidia*.json /host/etc/glvnd/egl_vendor.d/*nvidia*.json; do
        if [ -f "$f" ]; then
            has_egl_json="true"
            break
        fi
    done

    if [ "$json_warned" != "true" ] && [ "$has_vulkan_json" != "true" ] && [ "$has_egl_json" != "true" ]; then
        echo "[wait_init] warning: no NVIDIA Vulkan/EGL JSON found in common paths; continue because device nodes are ready"
        json_warned="true"
    fi

    return 0
}

if ! is_positive_int "$DELAY" || ! is_positive_int "$TIMEOUT" || ! is_positive_int "$INTERVAL"; then
    echo "[wait_init] invalid wait parameters" >&2
    exit 2
fi

echo "[wait_init] start delay ${DELAY}s"
sleep "$DELAY"

deadline=$(( $(date +%s) + TIMEOUT ))
echo "[wait_init] polling environment readiness for up to ${TIMEOUT}s (interval=${INTERVAL}s)"

while true; do
    if check_ready; then
        echo "[wait_init] environment ready"
        exit 0
    fi

    now="$(date +%s)"
    if [ "$now" -ge "$deadline" ]; then
        echo "[wait_init] timeout: ${reason}" >&2
        exit 1
    fi

    remain=$(( deadline - now ))
    echo "[wait_init] not ready: ${reason}; retry in ${INTERVAL}s (remaining=${remain}s)"
    sleep "$INTERVAL"
done
