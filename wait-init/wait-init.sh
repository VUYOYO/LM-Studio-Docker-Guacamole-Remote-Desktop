#!/bin/sh
set -eu

DELAY="${WAIT_INIT_DELAY_SECONDS:-20}"
TIMEOUT="${WAIT_INIT_TIMEOUT_SECONDS:-180}"
INTERVAL="${WAIT_INIT_POLL_INTERVAL_SECONDS:-5}"

reason=""

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
    if [ ! -f /host/usr/share/vulkan/icd.d/nvidia_icd.json ]; then
        reason="missing file: /usr/share/vulkan/icd.d/nvidia_icd.json"
        return 1
    fi

    if [ ! -f /host/usr/share/glvnd/egl_vendor.d/10_nvidia.json ]; then
        reason="missing file: /usr/share/glvnd/egl_vendor.d/10_nvidia.json"
        return 1
    fi

    if [ ! -e /host/dev/nvidiactl ] && [ ! -e /host/dev/nvidia0 ]; then
        reason="NVIDIA device nodes are not ready (/dev/nvidiactl or /dev/nvidia0)"
        return 1
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
