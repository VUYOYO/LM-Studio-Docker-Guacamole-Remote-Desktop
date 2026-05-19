#!/bin/bash

FORCE_UPDATE="${FORCE_UPDATE:-false}"
ENABLE_GPU_RENDERING="${ENABLE_GPU_RENDERING:-true}"
AUTO_LOAD_MODEL="${AUTO_LOAD_MODEL:-false}"
CLEAN_LM_VENDOR_CACHE="${CLEAN_LM_VENDOR_CACHE:-false}"
ENABLE_GUAC_WEB="${ENABLE_GUAC_WEB:-true}"
AUTO_INSTALL_GPU_BACKENDS="${AUTO_INSTALL_GPU_BACKENDS:-true}"
RUNTIME_ENGINE_FAMILY="${RUNTIME_ENGINE_FAMILY:-llama.cpp}"
PREFERRED_GPU_BACKEND="${PREFERRED_GPU_BACKEND:-cuda}"
FALLBACK_GPU_BACKEND="${FALLBACK_GPU_BACKEND:-vulkan}"
LMS_BACKEND_SETUP_TIMEOUT="${LMS_BACKEND_SETUP_TIMEOUT:-240}"
LMS_BACKEND_SELECT_RETRIES="${LMS_BACKEND_SELECT_RETRIES:-1}"
LMS_BACKEND_AUTOCONFIG_STAMP="${LMS_BACKEND_AUTOCONFIG_STAMP:-/root/.cache/lm-studio/.internal/.backend-autoconfig-done}"
DISPLAY_NUM="${DISPLAY_NUM:-99}"
SCREEN_RESOLUTION="${SCREEN_RESOLUTION:-1600x900}"
SCREEN_DEPTH="${SCREEN_DEPTH:-24}"
ENABLE_MULTI_CLIENT_1080P_LOCK="${ENABLE_MULTI_CLIENT_1080P_LOCK:-true}"
MULTI_CLIENT_RESOLUTION="${MULTI_CLIENT_RESOLUTION:-1920x1080}"
RESOLUTION_MONITOR_INTERVAL="${RESOLUTION_MONITOR_INTERVAL:-2}"
ENABLE_SINGLE_CLIENT_DYNAMIC_RESOLUTION="${ENABLE_SINGLE_CLIENT_DYNAMIC_RESOLUTION:-true}"
SINGLE_CLIENT_RESOLUTION_HINT="${SINGLE_CLIENT_RESOLUTION_HINT:-}"
XVFB_MAX_RESOLUTION="${XVFB_MAX_RESOLUTION:-4096x2160}"
VNC_REQUESTED_RESOLUTION_FILE="${VNC_REQUESTED_RESOLUTION_FILE:-/tmp/vnc-requested-resolution}"
GUAC_USERNAME="${GUAC_USERNAME:-lmstudio}"
GUAC_PASSWORD="${GUAC_PASSWORD:-lmstudio}"
GUAC_CONN_NAME="${GUAC_CONN_NAME:-LM Studio Shared Desktop}"
GUAC_PROTOCOL="${GUAC_PROTOCOL:-vnc}"
GUAC_TARGET_HOST="${GUAC_TARGET_HOST:-lmstudio}"
GUAC_TARGET_PORT="${GUAC_TARGET_PORT:-5900}"
GUAC_TARGET_PASSWORD="${GUAC_TARGET_PASSWORD:-lmstudio}"
GUAC_AUTORETRY="${GUAC_AUTORETRY:-3}"
GUAC_DISABLE_DISPLAY_RESIZE="${GUAC_DISABLE_DISPLAY_RESIZE:-false}"
GUAC_COLOR_DEPTH="${GUAC_COLOR_DEPTH:-24}"
GUAC_CURSOR="${GUAC_CURSOR:-remote}"
GUAC_DISABLE_COPY="${GUAC_DISABLE_COPY:-false}"
GUAC_DISABLE_PASTE="${GUAC_DISABLE_PASTE:-false}"
GUAC_CLIPBOARD_ENCODING="${GUAC_CLIPBOARD_ENCODING:-UTF-8}"
SKIP_REMOTE_VERSION_CHECK="${SKIP_REMOTE_VERSION_CHECK:-true}"
UPDATE_CHECK_MAX_TIME="${UPDATE_CHECK_MAX_TIME:-8}"
LM_STUDIO_DOWNLOAD_URL="${LM_STUDIO_DOWNLOAD_URL:-}"
LM_STUDIO_DOWNLOAD_RETRIES="${LM_STUDIO_DOWNLOAD_RETRIES:-3}"
LM_STUDIO_DOWNLOAD_TIMEOUT="${LM_STUDIO_DOWNLOAD_TIMEOUT:-30}"
DESKTOP_SYNC_INTERVAL="${DESKTOP_SYNC_INTERVAL:-20}"
LM_ENSURE_RUNNING="${LM_ENSURE_RUNNING:-true}"
LM_RESTART_INTERVAL="${LM_RESTART_INTERVAL:-2}"
LM_ENSURE_WINDOW="${LM_ENSURE_WINDOW:-false}"
LM_WINDOW_MISSING_TICKS="${LM_WINDOW_MISSING_TICKS:-3}"
LM_WINDOW_GRACE_SECONDS="${LM_WINDOW_GRACE_SECONDS:-20}"
LM_WATCHDOG_DEBUG="${LM_WATCHDOG_DEBUG:-false}"
ENABLE_CLIPBOARD_SYNC="${ENABLE_CLIPBOARD_SYNC:-true}"
CLIPBOARD_GUARDIAN_ENABLE="${CLIPBOARD_GUARDIAN_ENABLE:-true}"
CLIPBOARD_GUARDIAN_INTERVAL="${CLIPBOARD_GUARDIAN_INTERVAL:-1}"
CLIPBOARD_FAKE_KEYBOARD_ENABLE="${CLIPBOARD_FAKE_KEYBOARD_ENABLE:-false}"
CLIPBOARD_MAX_TYPE_CHARS="${CLIPBOARD_MAX_TYPE_CHARS:-8192}"
CLIPBOARD_AUTOCUTSEL_ENABLE="${CLIPBOARD_AUTOCUTSEL_ENABLE:-false}"
CLIPBOARD_BRIDGE_ENABLE="${CLIPBOARD_BRIDGE_ENABLE:-true}"
CLIPBOARD_BRIDGE_PORT="${CLIPBOARD_BRIDGE_PORT:-18080}"
DESKTOP_LANGUAGE="${DESKTOP_LANGUAGE:-ENG}"

if ! echo "$SCREEN_RESOLUTION" | grep -Eq '^[0-9]+x[0-9]+$'; then
    echo ">>> Invalid SCREEN_RESOLUTION=$SCREEN_RESOLUTION, fallback to 1600x900"
    SCREEN_RESOLUTION="1600x900"
fi
if ! echo "$SCREEN_DEPTH" | grep -Eq '^[0-9]+$'; then
    echo ">>> Invalid SCREEN_DEPTH=$SCREEN_DEPTH, fallback to 24"
    SCREEN_DEPTH="24"
fi
if ! echo "$MULTI_CLIENT_RESOLUTION" | grep -Eq '^[0-9]+x[0-9]+$'; then
    echo ">>> Invalid MULTI_CLIENT_RESOLUTION=$MULTI_CLIENT_RESOLUTION, fallback to 1920x1080"
    MULTI_CLIENT_RESOLUTION="1920x1080"
fi
if ! echo "$XVFB_MAX_RESOLUTION" | grep -Eq '^[0-9]+x[0-9]+$'; then
    echo ">>> Invalid XVFB_MAX_RESOLUTION=$XVFB_MAX_RESOLUTION, fallback to 4096x2160"
    XVFB_MAX_RESOLUTION="4096x2160"
fi
if [ -n "$SINGLE_CLIENT_RESOLUTION_HINT" ] && ! echo "$SINGLE_CLIENT_RESOLUTION_HINT" | grep -Eq '^[0-9]+x[0-9]+$'; then
    echo ">>> Invalid SINGLE_CLIENT_RESOLUTION_HINT=$SINGLE_CLIENT_RESOLUTION_HINT, ignored"
    SINGLE_CLIENT_RESOLUTION_HINT=""
fi
if ! echo "$DESKTOP_SYNC_INTERVAL" | grep -Eq '^[0-9]+$'; then
    echo ">>> Invalid DESKTOP_SYNC_INTERVAL=$DESKTOP_SYNC_INTERVAL, fallback to 20"
    DESKTOP_SYNC_INTERVAL="20"
fi
if ! echo "$LM_RESTART_INTERVAL" | grep -Eq '^[0-9]+$'; then
    echo ">>> Invalid LM_RESTART_INTERVAL=$LM_RESTART_INTERVAL, fallback to 2"
    LM_RESTART_INTERVAL="2"
fi
if ! echo "$LM_WINDOW_MISSING_TICKS" | grep -Eq '^[0-9]+$' || [ "$LM_WINDOW_MISSING_TICKS" -le 0 ]; then
    echo ">>> Invalid LM_WINDOW_MISSING_TICKS=$LM_WINDOW_MISSING_TICKS, fallback to 3"
    LM_WINDOW_MISSING_TICKS="3"
fi
if ! echo "$LM_WINDOW_GRACE_SECONDS" | grep -Eq '^[0-9]+$' || [ "$LM_WINDOW_GRACE_SECONDS" -lt 0 ]; then
    echo ">>> Invalid LM_WINDOW_GRACE_SECONDS=$LM_WINDOW_GRACE_SECONDS, fallback to 20"
    LM_WINDOW_GRACE_SECONDS="20"
fi
if ! echo "$LM_STUDIO_DOWNLOAD_RETRIES" | grep -Eq '^[0-9]+$'; then
    echo ">>> Invalid LM_STUDIO_DOWNLOAD_RETRIES=$LM_STUDIO_DOWNLOAD_RETRIES, fallback to 3"
    LM_STUDIO_DOWNLOAD_RETRIES="3"
fi
if ! echo "$LM_STUDIO_DOWNLOAD_TIMEOUT" | grep -Eq '^[0-9]+$'; then
    echo ">>> Invalid LM_STUDIO_DOWNLOAD_TIMEOUT=$LM_STUDIO_DOWNLOAD_TIMEOUT, fallback to 30"
    LM_STUDIO_DOWNLOAD_TIMEOUT="30"
fi
if ! echo "$CLIPBOARD_GUARDIAN_INTERVAL" | grep -Eq '^[0-9]+([.][0-9]+)?$'; then
    echo ">>> Invalid CLIPBOARD_GUARDIAN_INTERVAL=$CLIPBOARD_GUARDIAN_INTERVAL, fallback to 1"
    CLIPBOARD_GUARDIAN_INTERVAL="1"
fi
if ! echo "$CLIPBOARD_MAX_TYPE_CHARS" | grep -Eq '^[0-9]+$' || [ "$CLIPBOARD_MAX_TYPE_CHARS" -le 0 ]; then
    echo ">>> Invalid CLIPBOARD_MAX_TYPE_CHARS=$CLIPBOARD_MAX_TYPE_CHARS, fallback to 8192"
    CLIPBOARD_MAX_TYPE_CHARS="8192"
fi
if ! echo "$CLIPBOARD_BRIDGE_PORT" | grep -Eq '^[0-9]+$' || [ "$CLIPBOARD_BRIDGE_PORT" -le 0 ] || [ "$CLIPBOARD_BRIDGE_PORT" -gt 65535 ]; then
    echo ">>> Invalid CLIPBOARD_BRIDGE_PORT=$CLIPBOARD_BRIDGE_PORT, fallback to 18080"
    CLIPBOARD_BRIDGE_PORT="18080"
fi
if ! echo "$LMS_BACKEND_SELECT_RETRIES" | grep -Eq '^[0-9]+$' || [ "$LMS_BACKEND_SELECT_RETRIES" -le 0 ]; then
    echo ">>> Invalid LMS_BACKEND_SELECT_RETRIES=$LMS_BACKEND_SELECT_RETRIES, fallback to 1"
    LMS_BACKEND_SELECT_RETRIES="1"
fi

case "$(echo "$DESKTOP_LANGUAGE" | tr '[:lower:]' '[:upper:]')" in
    ENG|EN|EN-US|EN_US)
        DESKTOP_LANGUAGE="ENG"
        ;;
    CN-ZH|ZH-CN|ZH_CN|CN|ZH)
        DESKTOP_LANGUAGE="CN-ZH"
        ;;
    *)
        echo ">>> Invalid DESKTOP_LANGUAGE=$DESKTOP_LANGUAGE, fallback to ENG"
        DESKTOP_LANGUAGE="ENG"
        ;;
esac

render_guacamole_user_mapping() {
    local guac_dir="/app/guacamole-config"
    local guac_file="$guac_dir/user-mapping.xml"

    [ "$ENABLE_GUAC_WEB" != "true" ] && return 0
    [ ! -d "$guac_dir" ] && return 0

    cat > "$guac_file" <<EOF
<user-mapping>
    <authorize username="$GUAC_USERNAME" password="$GUAC_PASSWORD">
        <connection name="$GUAC_CONN_NAME">
            <protocol>$GUAC_PROTOCOL</protocol>
            <param name="hostname">$GUAC_TARGET_HOST</param>
            <param name="port">$GUAC_TARGET_PORT</param>
            <param name="password">$GUAC_TARGET_PASSWORD</param>
            <param name="autoretry">$GUAC_AUTORETRY</param>
            <param name="disable-display-resize">$GUAC_DISABLE_DISPLAY_RESIZE</param>
            <param name="color-depth">$GUAC_COLOR_DEPTH</param>
            <param name="cursor">$GUAC_CURSOR</param>
            <param name="disable-copy">$GUAC_DISABLE_COPY</param>
            <param name="disable-paste">$GUAC_DISABLE_PASTE</param>
            <param name="clipboard-encoding">$GUAC_CLIPBOARD_ENCODING</param>
        </connection>
    </authorize>
</user-mapping>
EOF

    echo ">>> Guacamole user-mapping.xml rendered from environment: $guac_file"
}

render_guacamole_user_mapping

prepare_launcher_directories() {
    mkdir -p /root/Desktop /root/.local/share/applications /usr/local/share/applications /root/.config
}

trust_desktop_file() {
    local desktop_file="$1"

    [ -f "$desktop_file" ] || return 0
    chmod +x "$desktop_file" >/dev/null 2>&1 || true
    if command -v gio >/dev/null 2>&1; then
        gio set "$desktop_file" metadata::trusted true >/dev/null 2>&1 || true
    fi
}

sync_pinned_desktop_shortcuts() {
    local desktop_dir="/root/Desktop"
    local src=""
    local target=""
    local base=""
    local name=""

    prepare_launcher_directories
    mkdir -p "$desktop_dir"

    rm -f /root/Desktop/app-store.desktop /usr/local/share/applications/app-store.desktop /root/.local/share/applications/app-store.desktop /usr/local/bin/open-app-store 2>/dev/null || true

    for name in google-chrome.desktop; do
        src=""
        for target in \
            "/root/.local/share/applications/$name" \
            "/usr/local/share/applications/$name" \
            "/usr/share/applications/$name"; do
            if [ -f "$target" ]; then
                src="$target"
                break
            fi
        done

        if [ -n "$src" ]; then
            cp -f "$src" "$desktop_dir/$name" 2>/dev/null || true
            trust_desktop_file "$src"
            trust_desktop_file "$desktop_dir/$name"
        fi
    done

    find "$desktop_dir" -maxdepth 1 -type f -name '*.desktop' -print0 2>/dev/null | while IFS= read -r -d '' src; do
        base="$(basename "$src")"
        case "$base" in
            google-chrome.desktop)
                trust_desktop_file "$src"
                ;;
            *)
                rm -f "$src" || true
                ;;
        esac
    done
}

prepare_browser_command_wrappers() {
    local xwww_wrapper="/usr/local/bin/x-www-browser"
    local sensible_wrapper="/usr/local/bin/sensible-browser"
    local exo_wrapper="/usr/local/bin/exo-open"
    local xdg_wrapper="/usr/local/bin/xdg-open"

    cat > "$xwww_wrapper" <<'EOF'
#!/bin/sh
exec /usr/local/bin/google-chrome-safe "$@"
EOF
    chmod +x "$xwww_wrapper"

    cat > "$sensible_wrapper" <<'EOF'
#!/bin/sh
exec /usr/local/bin/google-chrome-safe "$@"
EOF
    chmod +x "$sensible_wrapper"

    if [ -x /usr/bin/exo-open ]; then
        cat > "$exo_wrapper" <<'EOF'
#!/bin/sh
if [ "$1" = "--launch" ] && [ "$2" = "WebBrowser" ]; then
    shift 2
    exec /usr/local/bin/google-chrome-safe "$@"
fi
case "$1" in
    http://*|https://*|about:*|chrome://*|www.*)
        exec /usr/local/bin/google-chrome-safe "$1"
        ;;
esac
exec /usr/bin/exo-open "$@"
EOF
        chmod +x "$exo_wrapper"
    fi

    cat > "$xdg_wrapper" <<'EOF'
#!/bin/sh
case "$1" in
    --help|--manual|--version)
        exec /usr/bin/xdg-open "$@"
        ;;
    http://*|https://*|about:*|chrome://*|www.*)
        exec /usr/local/bin/google-chrome-safe "$1"
        ;;
esac
exec /usr/bin/xdg-open "$@"
EOF
    chmod +x "$xdg_wrapper"
}

monitor_pinned_desktop_shortcuts() {
    local interval="$DESKTOP_SYNC_INTERVAL"
    [ -z "$interval" ] && interval=20

    while true; do
        sync_pinned_desktop_shortcuts
        sleep "$interval"
    done
}

prepare_chrome_launcher() {
    local chrome_wrapper="/usr/local/bin/google-chrome-safe"
    local chrome_override="/usr/local/share/applications/google-chrome.desktop"
    local desktop_file=""
    local source_file=""

    if [ ! -x /usr/bin/google-chrome-stable ]; then
        echo ">>> google-chrome-stable not found, skip launcher patch."
        return 0
    fi

    prepare_launcher_directories

    cat > "$chrome_wrapper" <<'EOF'
#!/bin/sh
exec /usr/bin/google-chrome-stable --no-sandbox --disable-dev-shm-usage "$@"
EOF
    chmod +x "$chrome_wrapper"

    for source_file in /usr/share/applications/google-chrome.desktop /root/.local/share/applications/google-chrome.desktop; do
        if [ -f "$source_file" ]; then
            cp -f "$source_file" "$chrome_override" >/dev/null 2>&1 || true
            break
        fi
    done

    if [ ! -f "$chrome_override" ]; then
        cat > "$chrome_override" <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Google Chrome
Comment=Access the Internet
Exec=/usr/local/bin/google-chrome-safe %U
Icon=google-chrome
Terminal=false
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/rss+xml;application/rdf+xml;image/gif;image/jpeg;image/png;x-scheme-handler/http;x-scheme-handler/https;
StartupNotify=true
EOF
    fi

    for desktop_file in \
        "$chrome_override" \
        /usr/share/applications/google-chrome.desktop \
        /root/Desktop/google-chrome.desktop \
        /root/.local/share/applications/google-chrome.desktop; do
        [ -f "$desktop_file" ] || continue

        sed -i -E 's|^Exec=.*|Exec=/usr/local/bin/google-chrome-safe %U|' "$desktop_file" || true
        chmod +x "$desktop_file" || true

        if command -v gio >/dev/null 2>&1; then
            gio set "$desktop_file" metadata::trusted true >/dev/null 2>&1 || true
        fi
    done

    echo ">>> Chrome launcher patched for container root startup."
}

set_default_browser_to_chrome() {
    local mimeapps="/root/.config/mimeapps.list"
    local local_mimeapps="/root/.local/share/applications/mimeapps.list"
    local xfce_helpers="/root/.config/xfce4/helpers.rc"

    prepare_launcher_directories
    mkdir -p /root/.config/xfce4

    cat > "$mimeapps" <<'EOF'
[Default Applications]
x-scheme-handler/http=google-chrome.desktop
x-scheme-handler/https=google-chrome.desktop
x-scheme-handler/about=google-chrome.desktop
x-scheme-handler/unknown=google-chrome.desktop
text/html=google-chrome.desktop

[Added Associations]
x-scheme-handler/http=google-chrome.desktop;
x-scheme-handler/https=google-chrome.desktop;
text/html=google-chrome.desktop;
EOF

    cat > "$local_mimeapps" <<'EOF'
[Default Applications]
x-scheme-handler/http=google-chrome.desktop
x-scheme-handler/https=google-chrome.desktop
text/html=google-chrome.desktop
EOF

    cat > "$xfce_helpers" <<'EOF'
WebBrowser=custom-WebBrowser
WebBrowserNeedsTerminal=false
WebBrowserCustom=/usr/local/bin/google-chrome-safe %s
EOF

    export BROWSER=/usr/local/bin/google-chrome-safe

    if command -v xdg-settings >/dev/null 2>&1; then
        xdg-settings set default-web-browser google-chrome.desktop >/dev/null 2>&1 || true
    fi

    if command -v xdg-mime >/dev/null 2>&1; then
        xdg-mime default google-chrome.desktop x-scheme-handler/http >/dev/null 2>&1 || true
        xdg-mime default google-chrome.desktop x-scheme-handler/https >/dev/null 2>&1 || true
        xdg-mime default google-chrome.desktop text/html >/dev/null 2>&1 || true
    fi

    if command -v update-alternatives >/dev/null 2>&1; then
        update-alternatives --set x-www-browser /usr/local/bin/google-chrome-safe >/dev/null 2>&1 || true
        update-alternatives --set gnome-www-browser /usr/local/bin/google-chrome-safe >/dev/null 2>&1 || true
    fi

    echo ">>> Default browser set to Google Chrome."
}

prepare_lmstudio_launcher() {
    local lm_wrapper="/usr/local/bin/start-lmstudio"
    local lm_desktop="/usr/local/share/applications/lmstudio.desktop"

    prepare_launcher_directories

    cat > "$lm_wrapper" <<'EOF'
#!/bin/sh
DOWNLOAD_DIR="/app/lm-studio"
EXTRACT_DIR="$DOWNLOAD_DIR/squashfs-root"
APPIMAGE_PATH="$DOWNLOAD_DIR/LM-Studio.AppImage"
LM_EXEC="$EXTRACT_DIR/lm-studio"

if [ ! -x "$LM_EXEC" ] && [ -x "$EXTRACT_DIR/AppRun" ]; then
    LM_EXEC="$EXTRACT_DIR/AppRun"
fi
if [ ! -x "$LM_EXEC" ] && [ -x "$APPIMAGE_PATH" ]; then
    LM_EXEC="$APPIMAGE_PATH"
fi

if [ ! -x "$LM_EXEC" ]; then
    if command -v xmessage >/dev/null 2>&1; then
        xmessage "LM Studio executable not found under /app/lm-studio."
    fi
    exit 1
fi

exec "$LM_EXEC" --no-sandbox --server --host 0.0.0.0 --port 1234 "$@"
EOF
    chmod +x "$lm_wrapper"

    cat > "$lm_desktop" <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=LM Studio
Name[zh_CN]=LM Studio
Comment=Launch LM Studio
Comment[zh_CN]=启动 LM Studio
Exec=/usr/local/bin/start-lmstudio
Icon=applications-development
Terminal=false
Categories=Development;AI;
StartupNotify=true
EOF

    trust_desktop_file "$lm_desktop"
}

prepare_chrome_launcher
prepare_browser_command_wrappers
sync_pinned_desktop_shortcuts
monitor_pinned_desktop_shortcuts &

download_lmstudio_appimage() {
    local url="$1"
    local out_file="$2"
    local max_time=$((LM_STUDIO_DOWNLOAD_TIMEOUT * 10))

    rm -f "$out_file" 2>/dev/null || true

    if command -v curl >/dev/null 2>&1; then
        curl -fL \
            --retry "$LM_STUDIO_DOWNLOAD_RETRIES" \
            --retry-all-errors \
            --connect-timeout "$LM_STUDIO_DOWNLOAD_TIMEOUT" \
            --max-time "$max_time" \
            -o "$out_file" \
            "$url"
    else
        wget \
            --tries="$LM_STUDIO_DOWNLOAD_RETRIES" \
            --timeout="$LM_STUDIO_DOWNLOAD_TIMEOUT" \
            -O "$out_file" \
            "$url"
    fi

    [ -s "$out_file" ]
}

echo ">>> Checking latest LM Studio version..."
DOWNLOAD_DIR="/app/lm-studio"
APPIMAGE_NAME="LM-Studio.AppImage"
APPIMAGE_PATH="$DOWNLOAD_DIR/$APPIMAGE_NAME"
EXTRACT_DIR="$DOWNLOAD_DIR/squashfs-root"
VERSION_FILE="$DOWNLOAD_DIR/.version"
LATEST_URL=""
REMOTE_VERSION=""

if [ "$SKIP_REMOTE_VERSION_CHECK" != "true" ]; then
    LATEST_URL=$(curl -fsSI --max-time "$UPDATE_CHECK_MAX_TIME" "https://lmstudio.ai/download/latest/linux/x64" 2>/dev/null | grep -i "location:" | awk '{print $2}' | tr -d '\r')
    if [ -n "$LATEST_URL" ]; then
        REMOTE_VERSION=$(echo "$LATEST_URL" | grep -oP '\d+\.\d+\.\d+' | head -1)
        if [ -n "$REMOTE_VERSION" ]; then
            echo ">>> Latest remote version: $REMOTE_VERSION"
        else
            echo ">>> Remote URL fetched but version parse failed, skip remote update decision."
        fi
    else
        echo ">>> Remote version check timed out/unavailable, skip remote update decision."
    fi
else
    echo ">>> Remote version check skipped."
fi

if [ -n "$LM_STUDIO_DOWNLOAD_URL" ]; then
    LATEST_URL="$LM_STUDIO_DOWNLOAD_URL"
    echo ">>> Using custom LM Studio download URL from LM_STUDIO_DOWNLOAD_URL"
fi

if [ -z "$LATEST_URL" ]; then
    LATEST_URL="https://lmstudio.ai/download/latest/linux/x64"
fi

LOCAL_VERSION=""
[ -f "$VERSION_FILE" ] && LOCAL_VERSION=$(cat "$VERSION_FILE")

HAS_LOCAL_INSTALL=false
if [ -x "$EXTRACT_DIR/lm-studio" ] || [ -x "$EXTRACT_DIR/AppRun" ] || [ -x "$DOWNLOAD_DIR/$APPIMAGE_NAME" ]; then
    HAS_LOCAL_INSTALL=true
fi

NEED_UPDATE=false
if [ "$FORCE_UPDATE" = "true" ]; then
    NEED_UPDATE=true
elif [ -n "$REMOTE_VERSION" ] && [ "$LOCAL_VERSION" != "$REMOTE_VERSION" ]; then
    NEED_UPDATE=true
elif [ "$HAS_LOCAL_INSTALL" = "false" ]; then
    echo ">>> No local LM Studio installation found, downloading fallback package."
    NEED_UPDATE=true
fi

if $NEED_UPDATE; then
    echo ">>> Downloading LM Studio package..."
    if download_lmstudio_appimage "$LATEST_URL" "$APPIMAGE_PATH"; then
        chmod +x "$APPIMAGE_PATH"
        echo ">>> Extracting AppImage..."
        cd "$DOWNLOAD_DIR" || exit 1
        rm -rf squashfs-root
        "./$APPIMAGE_NAME" --appimage-extract
        if [ -d squashfs-root ]; then
            echo ">>> Extraction successful."
            if [ -n "$REMOTE_VERSION" ]; then
                echo "$REMOTE_VERSION" > "$VERSION_FILE"
            fi
        else
            echo ">>> Extraction failed, will fallback to direct AppImage launch."
        fi
        cd / || exit 1
    else
        echo ">>> Download failed, keeping existing local installation if present."
    fi
else
    echo ">>> LM Studio is up to date (version $LOCAL_VERSION)."
fi

if [ "$DESKTOP_LANGUAGE" = "CN-ZH" ]; then
    export LANG=zh_CN.UTF-8
    export LC_ALL=zh_CN.UTF-8
else
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
fi
echo ">>> Desktop language profile: ${DESKTOP_LANGUAGE} (${LANG})"
export XDG_RUNTIME_DIR=/tmp/runtime-root
export XDG_SESSION_TYPE=x11
export GDK_BACKEND=x11
export NO_AT_BRIDGE=1
export BROWSER=/usr/local/bin/google-chrome-safe
mkdir -p "$XDG_RUNTIME_DIR"
chmod 0700 "$XDG_RUNTIME_DIR"

if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] && ! echo "$DBUS_SESSION_BUS_ADDRESS" | grep -Eq '^(unix|tcp):'; then
    unset DBUS_SESSION_BUS_ADDRESS
fi
if [ -n "${DBUS_SYSTEM_BUS_ADDRESS:-}" ] && ! echo "$DBUS_SYSTEM_BUS_ADDRESS" | grep -Eq '^(unix|tcp):'; then
    unset DBUS_SYSTEM_BUS_ADDRESS
fi

GPU_AVAILABLE=false
GPU_RUNTIME_AVAILABLE=false
if [ -e /dev/nvidiactl ] || [ -e /dev/nvidia0 ] || [ -e /proc/driver/nvidia/version ] || command -v nvidia-smi >/dev/null 2>&1; then
    GPU_RUNTIME_AVAILABLE=true
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    if [ -f /usr/share/glvnd/egl_vendor.d/10_nvidia.json ]; then
        export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json
    elif [ -f /etc/glvnd/egl_vendor.d/10_nvidia.json ]; then
        export __EGL_VENDOR_LIBRARY_FILENAMES=/etc/glvnd/egl_vendor.d/10_nvidia.json
    fi
    unset LIBGL_ALWAYS_SOFTWARE
    echo ">>> NVIDIA runtime detected in container."
    ls -l /dev/nvidia* 2>/dev/null || true
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi || true
    fi
fi

if [ "$GPU_RUNTIME_AVAILABLE" = "true" ] && [ "${ENABLE_GPU_RENDERING}" = "true" ]; then
    GPU_AVAILABLE=true
elif [ "$GPU_RUNTIME_AVAILABLE" = "true" ]; then
    echo ">>> NVIDIA runtime is available, but desktop GPU rendering is disabled by ENABLE_GPU_RENDERING=false."
else
    echo ">>> NVIDIA runtime not detected, desktop will use software rendering."
fi

echo ">>> Starting D-Bus..."
mkdir -p /run/dbus
dbus-daemon --system --fork
export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket
if command -v dbus-launch >/dev/null 2>&1; then
    eval "$(dbus-launch --sh-syntax)"
fi

echo ">>> Starting Xvfb..."
Xvfb ":${DISPLAY_NUM}" -screen 0 "${XVFB_MAX_RESOLUTION}x${SCREEN_DEPTH}" +extension GLX +render &
sleep 2
export DISPLAY=":${DISPLAY_NUM}"

if [ "$SCREEN_RESOLUTION" != "$XVFB_MAX_RESOLUTION" ]; then
    xrandr --display ":${DISPLAY_NUM}" -s "$SCREEN_RESOLUTION" >/dev/null 2>&1 || \
        xrandr --display ":${DISPLAY_NUM}" --fb "$SCREEN_RESOLUTION" >/dev/null 2>&1 || true
fi

echo ">>> Starting Xfce4 desktop..."
if [ "$GPU_AVAILABLE" = "true" ]; then
    startxfce4 &
else
    LIBGL_ALWAYS_SOFTWARE=1 GSK_RENDERER=cairo startxfce4 &
fi
sleep 5

set_default_browser_to_chrome
echo ">>> Startup stage: clipboard channel initialization..."

start_clipboard_sync() {
    [ "$ENABLE_CLIPBOARD_SYNC" != "true" ] && return 0

    if [ "$CLIPBOARD_AUTOCUTSEL_ENABLE" != "true" ]; then
        echo ">>> Clipboard autocutsel bridge disabled (CLIPBOARD_AUTOCUTSEL_ENABLE=false)."
        return 0
    fi

    if command -v autocutsel >/dev/null 2>&1; then
        pgrep -f 'autocutsel( |$)' >/dev/null 2>&1 || (DISPLAY="$DISPLAY" autocutsel >/tmp/autocutsel-primary.log 2>&1 &)
        pgrep -f 'autocutsel -selection CLIPBOARD' >/dev/null 2>&1 || (DISPLAY="$DISPLAY" autocutsel -selection CLIPBOARD >/tmp/autocutsel-clipboard.log 2>&1 &)
        echo ">>> Clipboard sync enabled via autocutsel."
    else
        echo ">>> autocutsel not found, clipboard sync bridge skipped."
    fi
}

start_clipboard_guardian() {
    [ "$ENABLE_CLIPBOARD_SYNC" != "true" ] && return 0
    [ "$CLIPBOARD_GUARDIAN_ENABLE" != "true" ] && return 0

    if ! command -v xclip >/dev/null 2>&1; then
        echo ">>> xclip not found, clipboard guardian skipped."
        return 0
    fi

    (
        local last_clipboard=""
        local last_primary=""
        local clipboard_text=""
        local primary_text=""

        while true; do

            clipboard_text="$(xclip -selection clipboard -o 2>/dev/null || true)"
            primary_text="$(xclip -selection primary -o 2>/dev/null || true)"

            if [ "$clipboard_text" != "$last_clipboard" ]; then
                if [ -n "$clipboard_text" ] && [ "$primary_text" != "$clipboard_text" ]; then
                    printf '%s' "$clipboard_text" | xclip -selection primary -i >/dev/null 2>&1 || true
                fi

                if [ "$CLIPBOARD_FAKE_KEYBOARD_ENABLE" = "true" ] && [ -n "$clipboard_text" ] && command -v xdotool >/dev/null 2>&1; then
                    if [ "${#clipboard_text}" -le "$CLIPBOARD_MAX_TYPE_CHARS" ]; then
                        printf '%s' "$clipboard_text" | xdotool type --clearmodifiers --file - >/dev/null 2>&1 || true
                    else
                        echo ">>> Clipboard fake keyboard skipped because text length exceeds CLIPBOARD_MAX_TYPE_CHARS=$CLIPBOARD_MAX_TYPE_CHARS"
                    fi
                fi

                last_clipboard="$clipboard_text"
            fi

            if [ "$primary_text" != "$last_primary" ]; then
                if [ -n "$primary_text" ] && [ "$clipboard_text" != "$primary_text" ]; then
                    printf '%s' "$primary_text" | xclip -selection clipboard -i >/dev/null 2>&1 || true
                fi
                last_primary="$primary_text"
            fi

            sleep "$CLIPBOARD_GUARDIAN_INTERVAL"
        done
    ) >/tmp/clipboard-guardian.log 2>&1 &

    echo ">>> Clipboard guardian enabled (interval=${CLIPBOARD_GUARDIAN_INTERVAL}s, fake-keyboard=${CLIPBOARD_FAKE_KEYBOARD_ENABLE})."
}

start_http_clipboard_bridge() {
    [ "$ENABLE_CLIPBOARD_SYNC" != "true" ] && return 0
    [ "$CLIPBOARD_BRIDGE_ENABLE" != "true" ] && return 0

    if ! command -v python3 >/dev/null 2>&1; then
        echo ">>> python3 not found, HTTP clipboard bridge skipped."
        return 0
    fi
    if ! command -v xclip >/dev/null 2>&1; then
        echo ">>> xclip not found, HTTP clipboard bridge skipped."
        return 0
    fi
    if [ ! -f /app/clipboard_bridge_server.py ]; then
        echo ">>> /app/clipboard_bridge_server.py not found, HTTP clipboard bridge skipped."
        return 0
    fi

    DISPLAY="$DISPLAY" python3 /app/clipboard_bridge_server.py \
        --bind "0.0.0.0" \
        --port "$CLIPBOARD_BRIDGE_PORT" \
        --max-chars "$CLIPBOARD_MAX_TYPE_CHARS" \
        --poll-interval 0.8 \
        >>/proc/1/fd/1 2>>/proc/1/fd/2 &

    echo ">>> HTTP clipboard bridge enabled on 0.0.0.0:${CLIPBOARD_BRIDGE_PORT}."
}

start_clipboard_sync
start_clipboard_guardian
start_http_clipboard_bridge

echo ">>> Startup stage: input method initialization..."
fcitx5 -d || true
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx

if [ "$CLEAN_LM_VENDOR_CACHE" = "true" ]; then
    echo ">>> Cleaning stale LM Studio vendor backend cache..."
    rm -rf /root/.cache/lm-studio/extensions/backends/vendor/_amphibian 2>/dev/null || true
    rm -rf /root/.cache/lm-studio/extensions/backends/runtime-index* 2>/dev/null || true
    rm -f "$LMS_BACKEND_AUTOCONFIG_STAMP" 2>/dev/null || true
fi

echo ">>> Launching LM Studio (API on port 1234)..."
LM_EXEC="$EXTRACT_DIR/lm-studio"
if [ ! -x "$LM_EXEC" ] && [ -x "$EXTRACT_DIR/AppRun" ]; then
    LM_EXEC="$EXTRACT_DIR/AppRun"
fi
if [ ! -x "$LM_EXEC" ] && [ -x "$APPIMAGE_PATH" ]; then
    echo ">>> Re-extracting AppImage because executable is missing..."
    (cd "$DOWNLOAD_DIR" && rm -rf squashfs-root && "./$APPIMAGE_NAME" --appimage-extract) || true
    if [ -x "$EXTRACT_DIR/lm-studio" ]; then
        LM_EXEC="$EXTRACT_DIR/lm-studio"
    elif [ -x "$EXTRACT_DIR/AppRun" ]; then
        LM_EXEC="$EXTRACT_DIR/AppRun"
    fi
fi
if [ ! -x "$LM_EXEC" ] && [ -x "$APPIMAGE_PATH" ]; then
    LM_EXEC="$APPIMAGE_PATH"
    echo ">>> Using direct AppImage launch fallback."
fi

launch_lmstudio() {
    if [ "$LM_EXEC" = "$APPIMAGE_PATH" ]; then
        APPIMAGE_EXTRACT_AND_RUN=1 "$LM_EXEC" --no-sandbox --server --host 0.0.0.0 --port 1234
    else
        "$LM_EXEC" --no-sandbox --server --host 0.0.0.0 --port 1234
    fi
}

ensure_vnc_password_file() {
    mkdir -p /root/.vnc

    if [ -s /root/.vnc/passwd ]; then
        return 0
    fi

    x11vnc -storepasswd "$GUAC_TARGET_PASSWORD" /root/.vnc/passwd >/tmp/x11vnc-storepasswd.log 2>&1
}

probe_lmstudio_api_ready() {
    (
        local deadline=$((SECONDS + 180))
        while [ "$SECONDS" -lt "$deadline" ]; do
            if curl -fsS --max-time 2 "http://127.0.0.1:1234/v1/models" >/dev/null 2>&1; then
                echo ">>> LM Studio API is ready on 127.0.0.1:1234."
                return 0
            fi
            sleep 2
        done
        echo ">>> LM Studio API did not become ready within 180s. Check /tmp/lmstudio-restart.log and watchdog settings."
    ) &
}

lmstudio_process_match='(/app/lm-studio/squashfs-root/lm-studio|/app/lm-studio/squashfs-root/AppRun|/app/lm-studio/LM-Studio.AppImage)'
lmstudio_main_process_match='(/app/lm-studio/squashfs-root/lm-studio|/app/lm-studio/squashfs-root/AppRun|/app/lm-studio/LM-Studio.AppImage).*--server --host 0.0.0.0 --port 1234'

lmstudio_is_running() {
    pgrep -f "$lmstudio_main_process_match" >/dev/null 2>&1
}

lmstudio_stop_all() {
    pkill -f "$lmstudio_main_process_match" >/dev/null 2>&1 || true
    pkill -f "$lmstudio_process_match" >/dev/null 2>&1 || true
}

lmstudio_window_present() {
    local ids=""
    local id=""
    local pid=""
    local cmdline=""
    local candidate="false"
    local wm_state=""

    if command -v xprop >/dev/null 2>&1; then
        ids="$(xprop -root _NET_CLIENT_LIST 2>/dev/null | sed -n 's/^.*# //p' | tr ',' ' ')"
        for id in $ids; do
            candidate="false"
            if xprop -id "$id" WM_CLASS 2>/dev/null | grep -Eqi 'lm-studio|lmstudio'; then
                candidate="true"
            fi

            if [ "$candidate" != "true" ]; then
                pid="$(xprop -id "$id" _NET_WM_PID 2>/dev/null | awk '{print $3}')"
                if [ -n "$pid" ]; then
                    cmdline="$(ps -p "$pid" -o args= 2>/dev/null || true)"
                    if echo "$cmdline" | grep -Eq "$lmstudio_process_match"; then
                        candidate="true"
                    fi
                fi
            fi

            if [ "$candidate" != "true" ]; then
                continue
            fi

            wm_state="$(xprop -id "$id" _NET_WM_STATE 2>/dev/null || true)"
            if echo "$wm_state" | grep -Eq '_NET_WM_STATE_HIDDEN'; then
                continue
            fi
            if command -v xwininfo >/dev/null 2>&1; then
                if ! xwininfo -id "$id" 2>/dev/null | grep -q 'Map State: IsViewable'; then
                    continue
                fi
            fi
            return 0
        done
        return 1
    fi

    if ! command -v xwininfo >/dev/null 2>&1; then
        return 0
    fi
    xwininfo -root -tree 2>/dev/null | grep -Eqi '"(LM Studio|LM-Studio)"'
}

if [ -x "$LM_EXEC" ]; then
    echo ">>> Startup stage: launching LM Studio process..."
    launch_lmstudio &
    echo ">>> LM Studio started with pid: $!"
    probe_lmstudio_api_ready

    if [ "$LM_ENSURE_RUNNING" = "true" ]; then
        (
            window_missing_ticks=0
            last_launch_epoch="$(date +%s)"
            watchdog_tick=0
            while true; do
                watchdog_tick=$((watchdog_tick + 1))
                if ! lmstudio_is_running; then
                    echo ">>> LM Studio exited, restarting..."
                    lmstudio_stop_all
                    launch_lmstudio >/tmp/lmstudio-restart.log 2>&1 &
                    last_launch_epoch="$(date +%s)"
                    window_missing_ticks=0
                elif [ "$LM_ENSURE_WINDOW" = "true" ]; then
                    now_epoch="$(date +%s)"
                    if [ $((now_epoch - last_launch_epoch)) -ge "$LM_WINDOW_GRACE_SECONDS" ]; then
                        if lmstudio_window_present; then
                            window_missing_ticks=0
                        else
                            window_missing_ticks=$((window_missing_ticks + 1))
                            if [ "$window_missing_ticks" -ge "$LM_WINDOW_MISSING_TICKS" ]; then
                                echo ">>> LM Studio window is missing, restarting..."
                                lmstudio_stop_all
                                launch_lmstudio >/tmp/lmstudio-restart.log 2>&1 &
                                last_launch_epoch="$(date +%s)"
                                window_missing_ticks=0
                            fi
                        fi
                    fi
                fi
                if [ "$LM_WATCHDOG_DEBUG" = "true" ]; then
                    if lmstudio_is_running; then
                        running_state="up"
                    else
                        running_state="down"
                    fi
                    if [ "$LM_ENSURE_WINDOW" = "true" ]; then
                        if lmstudio_window_present; then
                            window_state="present"
                        else
                            window_state="missing"
                        fi
                    else
                        window_state="disabled"
                    fi
                    echo ">>> watchdog tick=$watchdog_tick running=$running_state window=$window_state missing_ticks=$window_missing_ticks"
                fi
                sleep "$LM_RESTART_INTERVAL"
            done
        ) &
    fi
else
    echo ">>> LM Studio executable not found under $EXTRACT_DIR and no usable AppImage fallback at $APPIMAGE_PATH"
fi

setup_lms_runtime_backends() {
    local deadline=$((SECONDS + LMS_BACKEND_SETUP_TIMEOUT))
    local lms_bin=""
    local selected=""
    local ready=false
    local primary_queries=("${RUNTIME_ENGINE_FAMILY}:${PREFERRED_GPU_BACKEND}")
    local fallback_queries=()

    if [ -n "$FALLBACK_GPU_BACKEND" ] && [ "$FALLBACK_GPU_BACKEND" != "$PREFERRED_GPU_BACKEND" ]; then
        fallback_queries=("${RUNTIME_ENGINE_FAMILY}:${FALLBACK_GPU_BACKEND}")
    fi

    if [ -f "$LMS_BACKEND_AUTOCONFIG_STAMP" ] && [ "$FORCE_UPDATE" != "true" ] && [ "$CLEAN_LM_VENDOR_CACHE" != "true" ]; then
        echo ">>> Runtime backend auto-setup already done, skip."
        return 0
    fi

    while [ "$SECONDS" -lt "$deadline" ]; do
        if [ -x /root/.cache/lm-studio/bin/lms ]; then
            lms_bin="/root/.cache/lm-studio/bin/lms"
            break
        fi
        if command -v lms >/dev/null 2>&1; then
            lms_bin="$(command -v lms)"
            break
        fi
        sleep 2
    done

    if [ -z "$lms_bin" ]; then
        echo ">>> lms CLI not found within timeout, skip runtime backend auto-setup."
        return 0
    fi

    while [ "$SECONDS" -lt "$deadline" ]; do
        if "$lms_bin" runtime ls >/tmp/lms-runtime-ready.log 2>&1; then
            ready=true
            break
        fi
        sleep 2
    done

    if [ "$ready" != "true" ]; then
        echo ">>> lms CLI found but runtime service is not ready within timeout, skip runtime backend auto-setup."
        return 0
    fi

    echo ">>> Runtime backend auto-setup with $lms_bin (family: $RUNTIME_ENGINE_FAMILY, preferred: $PREFERRED_GPU_BACKEND, fallback: ${FALLBACK_GPU_BACKEND:-none})"

    for q in "${primary_queries[@]}"; do
        "$lms_bin" runtime get "$q" -y >>/tmp/lms-runtime-get-primary.log 2>&1 || true
    done

    for q in "${primary_queries[@]}"; do
        for _ in $(seq 1 "$LMS_BACKEND_SELECT_RETRIES"); do
            if "$lms_bin" runtime select "$q" --latest >>/tmp/lms-runtime-select.log 2>&1; then
                selected="$q"
                break
            fi
            sleep 2
        done
        [ -n "$selected" ] && break
    done

    if [ -z "$selected" ] && [ "${#fallback_queries[@]}" -gt 0 ]; then
        echo ">>> Primary runtime backend unavailable, trying fallback: $FALLBACK_GPU_BACKEND"
        for q in "${fallback_queries[@]}"; do
            "$lms_bin" runtime get "$q" -y >>/tmp/lms-runtime-get-fallback.log 2>&1 || true
        done

        for q in "${fallback_queries[@]}"; do
            for _ in $(seq 1 "$LMS_BACKEND_SELECT_RETRIES"); do
                if "$lms_bin" runtime select "$q" --latest >>/tmp/lms-runtime-select.log 2>&1; then
                    selected="$q"
                    break
                fi
                sleep 2
            done
            [ -n "$selected" ] && break
        done
    fi

    if [ -n "$selected" ]; then
        mkdir -p "$(dirname "$LMS_BACKEND_AUTOCONFIG_STAMP")"
        echo "$selected" > "$LMS_BACKEND_AUTOCONFIG_STAMP"
        echo ">>> Selected runtime backend: $selected"
    else
        echo ">>> Failed to select preferred/fallback runtime backend. Check /tmp/lms-runtime-*.log"
    fi

    "$lms_bin" runtime ls >/tmp/lms-runtime-ls.log 2>&1 || true
}

if [ "$GPU_RUNTIME_AVAILABLE" = "true" ] && [ "$AUTO_INSTALL_GPU_BACKENDS" = "true" ]; then
    setup_lms_runtime_backends &
fi

count_vnc_clients() {
    awk '
    FNR > 1 {
        split($2, localAddr, ":");
        split($3, remoteAddr, ":");
        remoteIp = toupper(remoteAddr[1]);
        if (toupper(localAddr[2]) == "170C" && $4 == "01" && remoteIp != "0100007F" && remoteIp != "00000000000000000000000001000000") {
            count++;
        }
    }
    END { print count + 0 }
    ' /proc/net/tcp /proc/net/tcp6 2>/dev/null
}

extract_requested_resolution_from_vnc_log() {
    local line="$1"
    local requested
    local previous
    requested="$(echo "$line" | sed -n 's/.*Client requested resolution change to (\([0-9]\+x[0-9]\+\)).*/\1/p')"
    if [ -n "$requested" ] && echo "$requested" | grep -Eq '^[0-9]+x[0-9]+$'; then
        previous=""
        if [ -f "$VNC_REQUESTED_RESOLUTION_FILE" ]; then
            previous="$(tr -d ' \r\n' < "$VNC_REQUESTED_RESOLUTION_FILE")"
        fi
        if [ "$requested" != "$previous" ]; then
            echo ">>> Captured VNC client requested resolution: $requested"
        fi
        echo "$requested" > "$VNC_REQUESTED_RESOLUTION_FILE"
    fi
}

start_x11vnc_server() {
    local cmd=(
        x11vnc
        -display ":${DISPLAY_NUM}"
        -rfbport 5900
        -forever
        -shared
        -rfbauth /root/.vnc/passwd
        -listen "0.0.0.0"
        -input KMBC
        -xkb
        -noxdamage
        -repeat
        -xrandr newfbsize
        -nowf
        -noscr
        -wait 10
        -defer 10
    )

    if [ "$ENABLE_SINGLE_CLIENT_DYNAMIC_RESOLUTION" = "true" ]; then
        rm -f "$VNC_REQUESTED_RESOLUTION_FILE"
        if [ -n "$SINGLE_CLIENT_RESOLUTION_HINT" ]; then
            echo "$SINGLE_CLIENT_RESOLUTION_HINT" > "$VNC_REQUESTED_RESOLUTION_FILE"
        fi

        "${cmd[@]}" 2>&1 | while IFS= read -r line; do
            echo "$line"
            extract_requested_resolution_from_vnc_log "$line"
        done &
    else
        "${cmd[@]}" &
    fi
}

monitor_resolution_policy() {
    local display_addr=":${DISPLAY_NUM}"
    local interval="$RESOLUTION_MONITOR_INTERVAL"
    local active_clients="0"
    local current_resolution=""
    local after_resolution=""
    local target_resolution=""
    local requested_resolution=""
    [ -z "$interval" ] && interval=2

    while true; do
        active_clients="$(count_vnc_clients)"
        target_resolution=""

        if [ "$active_clients" -gt 1 ]; then
            target_resolution="$MULTI_CLIENT_RESOLUTION"
        elif [ "$ENABLE_SINGLE_CLIENT_DYNAMIC_RESOLUTION" = "true" ]; then
            requested_resolution=""
            if [ -f "$VNC_REQUESTED_RESOLUTION_FILE" ]; then
                requested_resolution="$(tr -d ' \r\n' < "$VNC_REQUESTED_RESOLUTION_FILE")"
            elif [ -n "$SINGLE_CLIENT_RESOLUTION_HINT" ]; then
                requested_resolution="$SINGLE_CLIENT_RESOLUTION_HINT"
            fi

            if echo "$requested_resolution" | grep -Eq '^[0-9]+x[0-9]+$'; then
                target_resolution="$requested_resolution"
            fi
        fi

        if [ -n "$target_resolution" ]; then
            current_resolution="$(xrandr --display "$display_addr" --current 2>/dev/null | awk '/\*/ { print $1; exit }')"
            if [ "$current_resolution" != "$target_resolution" ]; then
                xrandr --display "$display_addr" -s "$target_resolution" >/dev/null 2>&1 || \
                    xrandr --display "$display_addr" --fb "$target_resolution" >/dev/null 2>&1 || \
                    xrandr --display "$display_addr" --output default --mode "$target_resolution" >/dev/null 2>&1 || true
                after_resolution="$(xrandr --display "$display_addr" --current 2>/dev/null | awk '/\*/ { print $1; exit }')"
                if [ "$after_resolution" = "$target_resolution" ]; then
                    echo ">>> Resolution policy applied: ${target_resolution} (active VNC clients: ${active_clients})"
                fi
            fi
        fi

        sleep "$interval"
    done
}

if [ "$ENABLE_GUAC_WEB" = "true" ]; then
    echo ">>> Startup stage: launching x11vnc..."
    echo ">>> Starting shared x11vnc server on :${DISPLAY_NUM}..."
    if ! ensure_vnc_password_file; then
        echo ">>> Failed to initialize /root/.vnc/passwd, x11vnc may fail. Check /tmp/x11vnc-storepasswd.log"
    fi
    start_x11vnc_server
    sleep 2

    if [ "$ENABLE_MULTI_CLIENT_1080P_LOCK" = "true" ]; then
        echo ">>> Resolution policy: single client uses dynamic resize, multi-client locks to ${MULTI_CLIENT_RESOLUTION}."
        monitor_resolution_policy &
    fi
fi

if [ "$AUTO_LOAD_MODEL" = "true" ] && [ -n "$MODEL_PATH" ]; then
    echo ">>> Waiting for LM Studio to initialize (40s)..."
    sleep 40
    if [ -f ~/.cache/lm-studio/bin/lms ]; then
        echo ">>> Loading model via CLI: $MODEL_PATH"
        ~/.cache/lm-studio/bin/lms load --gpu max --context-length "${CONTEXT_LENGTH:-4096}" "$MODEL_PATH" &
        echo ">>> Model loading initiated in background."
    else
        echo ">>> LM Studio CLI not found."
    fi
else
    echo ">>> AUTO_LOAD_MODEL is disabled. Use GUI manually."
fi

echo "==============================================="
echo "   Web Guacamole : http://<host-ip>:${GUAC_WEB_PORT:-8888}"
echo "   Shared desktop bus: VNC 5900"
echo "   API port: 1234"
echo "==============================================="

tail -f /dev/null
