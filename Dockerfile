FROM nvidia/cuda:12.6.1-cudnn-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# 1. 基础工具、库与 VNC
RUN apt-get update && apt-get install -y --no-install-recommends \
    procps \
    util-linux \
    wget \
    curl \
    ca-certificates \
    gnupg \
    locales \
    fontconfig \
    libfuse2 \
    fuse \
    libglib2.0-0 \
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libgtk-3-0 \
    libgbm1 \
    libasound2 \
    # X11/VNC
    xvfb \
    x11vnc \
    x11-utils \
    git \
    dbus-x11 \
    dbus-user-session \
    # 常用应用
    firefox \
    xdg-utils \
    sudo \
    # 图形与 Vulkan 支持
    libgl1-mesa-glx \
    libvulkan1 \
    mesa-vulkan-drivers \
    vulkan-tools \
    && rm -rf /var/lib/apt/lists/*

# 2. 中文环境与输入法
RUN apt-get update && apt-get install -y --no-install-recommends \
    language-pack-zh-hans \
    fonts-noto-cjk \
    fonts-noto-cjk-extra \
    fonts-noto-color-emoji \
    fonts-wqy-zenhei \
    fonts-wqy-microhei \
    fonts-arphic-uming \
    fonts-arphic-ukai \
    fcitx5 \
    fcitx5-chinese-addons \
    fcitx5-config-qt \
    fcitx5-frontend-gtk3 \
    fcitx5-frontend-gtk4 \
    fcitx5-frontend-qt5 \
    && rm -rf /var/lib/apt/lists/*

# 3. Xfce4 桌面环境
RUN apt-get update && apt-get install -y --no-install-recommends \
    xfce4 \
    xfce4-goodies \
    xfce4-terminal \
    mate-desktop-environment-core \
    mate-terminal \
    mate-applets \
    pluma \
    dconf-cli \
    network-manager-gnome \
    gnome-session \
    gnome-session-flashback \
    gnome-terminal \
    nautilus \
    mousepad \
    ristretto \
    thunar \
    gvfs \
    gvfs-backends \
    xdg-user-dirs \
    && rm -rf /var/lib/apt/lists/*

# 4. 安装 Google Chrome
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/keyrings/google-linux.gpg && \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-linux.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && apt-get install -y --no-install-recommends google-chrome-stable && \
    rm -rf /var/lib/apt/lists/*

# 5. 生成中文 locale 并刷新字体缓存
RUN locale-gen en_US.UTF-8 zh_CN.UTF-8 && \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 && \
    fc-cache -f

# 6. 准备持久化目录与桌面快捷方式
RUN mkdir -p /app/lm-studio /root/.cache/lm-studio/models /root/Desktop && \
    if [ -f /usr/share/applications/google-chrome.desktop ]; then cp /usr/share/applications/google-chrome.desktop /root/Desktop/; fi

WORKDIR /app
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

EXPOSE 5900 1234

CMD ["/app/entrypoint.sh"]