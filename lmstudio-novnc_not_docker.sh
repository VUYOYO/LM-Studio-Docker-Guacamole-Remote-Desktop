#!/bin/bash

# ==================== 配置 ====================
VNC_PASSWORD="${VNC_PASSWORD:-lmstudio}"
WEB_PORT="${WEB_PORT:-6080}"
VNC_PORT="${VNC_PORT:-5900}"
DISPLAY_NUM="${DISPLAY_NUM:-99}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-$HOME/lm-studio-app}"
DATA_DIR="${DATA_DIR:-$HOME/lm-studio-data}"
FORCE_UPDATE="${FORCE_UPDATE:-false}"
ENABLE_GPU_RENDERING="${ENABLE_GPU_RENDERING:-true}"

# ==================== 智能查找命令路径 ====================
find_cmd() {
    # 在常见路径中查找可执行文件
    for p in /usr/bin /usr/sbin /bin /sbin /usr/local/bin /usr/local/sbin; do
        if [ -x "$p/$1" ]; then
            echo "$p/$1"
            return 0
        fi
    done
    # 最后尝试 which
    if which "$1" &>/dev/null; then
        which "$1"
        return 0
    fi
    return 1
}

# 检查并获取关键命令的完整路径
XVFB=$(find_cmd Xvfb)
X11VNC=$(find_cmd x11vnc)
WEBSOCKIFY=$(find_cmd websockify)
GIT=$(find_cmd git)
WGET=$(find_cmd wget)
CURL=$(find_cmd curl)

MISSING=""
[ -z "$XVFB" ] && MISSING="$MISSING xvfb/Xvfb"
[ -z "$X11VNC" ] && MISSING="$MISSING x11vnc"
[ -z "$WEBSOCKIFY" ] && MISSING="$MISSING websockify"
[ -z "$GIT" ] && MISSING="$MISSING git"
[ -z "$WGET" ] && MISSING="$MISSING wget"
[ -z "$CURL" ] && MISSING="$MISSING curl"

if [ -n "$MISSING" ]; then
    echo "错误：缺少以下命令，请安装：$MISSING"
    echo "Ubuntu/Debian: sudo apt install xvfb x11vnc websockify git wget curl"
    exit 1
fi

echo ">>> 系统依赖已就绪。"

# 检查 FUSE
USE_EXTRACT=false
if [ ! -c /dev/fuse ] && [ ! -e /dev/fuse ]; then
    echo ">>> FUSE 不可用，将使用解压方式运行 LM Studio。"
    USE_EXTRACT=true
fi

# 创建工作目录
mkdir -p "$DOWNLOAD_DIR" "$DATA_DIR"

export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8

# GPU 渲染设置
if [ "${ENABLE_GPU_RENDERING}" = "true" ] && command -v nvidia-smi &>/dev/null; then
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json
else
    export LIBGL_ALWAYS_SOFTWARE=1
fi

# ==================== LM Studio 更新 ====================
echo ">>> 检查 LM Studio 更新..."
VERSION_FILE="$DOWNLOAD_DIR/.version"
LATEST_URL=$("$CURL" -sI "https://lmstudio.ai/download/latest/linux/x64" \
    | grep -i "location:" | awk '{print $2}' | tr -d '\r')
if [ -z "$LATEST_URL" ]; then
    echo "!!! 无法获取最新版本，使用备用地址。"
    LATEST_URL="https://installers.lmstudio.ai/linux/x64/latest/LM-Studio.AppImage"
fi

REMOTE_VERSION=$(echo "$LATEST_URL" | grep -oP '\d+\.\d+\.\d+' | head -1)
LOCAL_VERSION=""
[ -f "$VERSION_FILE" ] && LOCAL_VERSION=$(cat "$VERSION_FILE")

if [ "${FORCE_UPDATE}" = "true" ] || [ "$LOCAL_VERSION" != "$REMOTE_VERSION" ]; then
    echo ">>> 下载 LM Studio ${REMOTE_VERSION} ..."
    "$WGET" -O "$DOWNLOAD_DIR/LM-Studio.AppImage" "$LATEST_URL"
    chmod +x "$DOWNLOAD_DIR/LM-Studio.AppImage"
    if [ "$USE_EXTRACT" = true ]; then
        echo ">>> 解压 AppImage..."
        cd "$DOWNLOAD_DIR" || exit 1
        rm -rf squashfs-root
        ./LM-Studio.AppImage --appimage-extract
        if [ -d squashfs-root ]; then
            echo "$REMOTE_VERSION" > "$VERSION_FILE"
        else
            echo "!!! 解压失败，删除不完整的文件。"
            rm -f LM-Studio.AppImage
        fi
        cd - > /dev/null || exit 1
    else
        echo "$REMOTE_VERSION" > "$VERSION_FILE"
    fi
    echo ">>> 更新完成。"
else
    echo ">>> LM Studio 已是最新（${LOCAL_VERSION}）。"
fi

# 确定运行方式
if [ -f "$DOWNLOAD_DIR/squashfs-root/lm-studio" ]; then
    LM_CMD="$DOWNLOAD_DIR/squashfs-root/lm-studio"
elif [ -f "$DOWNLOAD_DIR/LM-Studio.AppImage" ]; then
    LM_CMD="$DOWNLOAD_DIR/LM-Studio.AppImage"
else
    echo "没有找到可执行的 LM Studio！"
    exit 1
fi

# ==================== 启动虚拟桌面 ====================
echo ">>> 启动 Xvfb (${XVFB}) ..."
"$XVFB" ":${DISPLAY_NUM}" -screen 0 1920x1080x24 +extension GLX +render &
sleep 2
export DISPLAY=":${DISPLAY_NUM}"

# 尝试启动桌面
if command -v startxfce4 &>/dev/null; then
    echo ">>> 启动 Xfce4 桌面..."
    startxfce4 &
    sleep 5
elif command -v openbox &>/dev/null; then
    echo ">>> 启动 Openbox..."
    openbox &
    sleep 3
else
    echo ">>> 未找到桌面环境，仅运行 LM Studio。"
fi

# ==================== 启动 LM Studio ====================
echo ">>> 启动 LM Studio（API 端口 1234）..."
"$LM_CMD" --no-sandbox --server --host 0.0.0.0 --port 1234 &

# ==================== VNC + noVNC ====================
echo ">>> 设置 VNC 密码..."
mkdir -p ~/.vnc
"$X11VNC" -storepasswd "$VNC_PASSWORD" ~/.vnc/passwd

echo ">>> 启动 x11vnc (${X11VNC}) ..."
"$X11VNC" -display ":${DISPLAY_NUM}" -forever -rfbauth ~/.vnc/passwd \
    -listen 0.0.0.0 -xkb -noxdamage -nowf &
sleep 2

# 准备 noVNC（如果不存在则克隆）
if [ ! -d /tmp/novnc ]; then
    echo ">>> 下载 noVNC..."
    "$GIT" clone -b v1.4.0 https://github.com/novnc/noVNC.git /tmp/novnc
fi

echo ">>> 启动 noVNC Web 代理 (${WEBSOCKIFY}) ..."
"$WEBSOCKIFY" --web=/tmp/novnc "${WEB_PORT}" localhost:"${VNC_PORT}" &

# 显示访问信息
IP_ADDR=$(hostname -I | awk '{print $1}')
echo ""
echo "==============================================="
echo "  LM Studio 已启动！"
echo "  浏览器访问: http://${IP_ADDR}:${WEB_PORT}/vnc.html"
echo "  VNC 地址 : ${IP_ADDR}:${VNC_PORT}"
echo "  API 地址 : http://${IP_ADDR}:1234"
echo "==============================================="

wait