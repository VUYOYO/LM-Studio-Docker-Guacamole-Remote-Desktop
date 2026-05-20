# LM Studio Docker（Guacamole 远程桌面）

作者：VUYOYO

## 1. 项目概述

本项目在 Docker 中运行 LM Studio + XFCE 桌面，并通过 Guacamole 提供浏览器远程访问。

![项目预览图](images/image.png)


当前架构：

- LM Studio 容器：桌面环境、LM Studio、x11vnc、API 服务（容器内端口 1234）
- guacd 容器：Guacamole 协议代理
- guacamole 容器：Web 访问入口

项目额外的特性：

- XFCE 桌面提供 Chrome 浏览器用于资料查看。
- XFCE 桌面里，LM Studio若被关闭，则LM Studio会自动重新运行。
- 内置中文环境与输入法，方便用于即时聊天。
- 使用UTF8编码的HTTP独立链路剪贴板，支持包括中文等各种字符。（需HTTPS协议）


## 2. 宿主机要求

### 2.1 通用要求

- Docker Engine 或 Docker Desktop（Compose v2）
- 建议内存不少于 16 GB
- 建议使用 NVIDIA GPU

如果使用 NVIDIA 路线，需要保证宿主机 CUDA/GPU 运行时环境可用。

### 2.2 Linux 宿主机（推荐）

- 已安装并可用的 NVIDIA 驱动（`nvidia-smi` 可正常返回）
- 已安装 NVIDIA Container Toolkit
- Docker 可以正常启动 GPU 容器

### 2.3 Windows 宿主机
- 如果你是windows的电脑，直接使用windows平台的LM studio更好，除非有特殊需求。
- Windows 10/11
- Docker Desktop 使用 WSL2 后端
- 宿主机安装最新 NVIDIA 驱动
- Docker Desktop 已开启 GPU 支持
- 宿主机检查命令：
  - Windows 终端执行 `nvidia-smi` 可以正常返回
  - WSL 内执行 `wsl -d <你的发行版> nvidia-smi` 可以正常返回

### 2.4 CUDA / GPU 运行时完备性检查

- 驱动与运行时可见性：
  - `nvidia-smi` 无报错并能显示 GPU 信息
  - 容器启动后，容器内 `nvidia-smi` 可用
- Docker GPU 贯通验证：
  - `docker run --rm --gpus all nvidia/cuda:12.6.1-cudnn-devel-ubuntu22.04 nvidia-smi`
  - 命令应能正常输出 GPU 信息
- 可选工具链检查：
  - `nvcc --version`（可选；本项目并不强制依赖 host 侧 nvcc）

### 2.5 已知问题
  - 经本人测试，nvidia 570驱动可能会导致LM studio的Runtime错误地显示为不兼容CUDA和Vulkan，但是不影响实际推理的能力。
  - 目前经本人测试，建议升级到580驱动，580驱动下runtime能够正确地显示。

## 3. 配置（.env）

首次启动前请编辑 `.env`。

关键字段：

- `GUAC_WEB_PORT`：Guacamole Web 宿主机端口，默认 `8888`
- `LMS_API_PORT`：LM Studio API 宿主机端口，默认 `1234`
- `GUAC_WEB_HTTPS_ENABLE`：Guacamole Web 端口 HTTPS 开关
- `LMS_API_HTTPS_ENABLE`：LM Studio API 端口 HTTPS 开关
- `GUAC_WEB_HTTPS_VERIFY_CERT` / `GUAC_WEB_CERT_FILE` / `GUAC_WEB_KEY_FILE`：Guacamole Web HTTPS 的证书校验策略与证书文件
- `LMS_API_HTTPS_VERIFY_CERT` / `LMS_API_CERT_FILE` / `LMS_API_KEY_FILE`：LM Studio API HTTPS 的证书校验策略与证书文件
- `GUAC_USERNAME` / `GUAC_PASSWORD`：Guacamole 登录账号
- `GUAC_TARGET_PASSWORD`：Guacamole 到桌面 VNC 服务使用的密码

重要警告：

- 不要在 LM Studio UI 内修改 API 端口。
- 容器内 API 固定监听 `1234`。
- 如需变更外部访问端口，仅修改 `.env` 中的 `LMS_API_PORT`。

## 4. 启动

本项目提供两种 Compose 模式：

- 发布版（默认）：`docker-compose.yml`，使用镜像 `vuyoyo/lmstudio-guacamole:latest`
- 本地版：`docker-compose.local.yml`，在默认配置基础上覆盖为本地源码构建

在项目根目录执行：

发布版（默认）：

```bash
docker compose up -d
```

本地版（使用本地源码构建）：

```bash
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d --build
```

访问地址：

- Guacamole Web：`http://` 或 `https://<宿主机IP>:<GUAC_WEB_PORT>`（由 `GUAC_WEB_HTTPS_ENABLE` 控制）
- LM Studio API：`http://` 或 `https://<宿主机IP>:<LMS_API_PORT>`（由 `LMS_API_HTTPS_ENABLE` 控制）

默认示例：

- Guacamole：`http://localhost:8888`
- API：`http://localhost:1234`

## 5. 停止 / 重启 / 日志

```bash
# 停止（发布版）
docker compose down

# 停止（本地版）
docker compose -f docker-compose.yml -f docker-compose.local.yml down

# 重启（发布版）
docker compose up -d --force-recreate

# 重建并重启（本地版）
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d --build --force-recreate

# 查看日志
docker compose logs -f
docker compose logs -f lmstudio
docker compose logs -f guacamole
```

## 6. 持久化数据

以下目录会映射并持久保存：

- `./data` -> `/app/lm-studio`
- `./cache` -> `/root/.cache/lm-studio`
- `./models` -> `/root/.cache/lm-studio/models`
- `./guacamole` -> Guacamole 配置与 user-mapping

关于 `./guacamole`：

- 连接与 user-mapping 内容会在启动时根据环境变量动态改变。
- 该目录应用于仅仅查看；实际生效值以 `.env` 与 `docker-compose.yml` 为准。

## 7. 常见问题排查

### 7.1 无法访问 Guacamole 页面

- 检查 `GUAC_WEB_PORT` 是否被占用
- 检查防火墙策略
- 检查容器状态：

```bash
docker compose ps
```

### 7.2 GPU 不可用

- 检查宿主机驱动与运行时
- 检查 Docker GPU 能力是否正常
- 查看容器日志中 NVIDIA runtime 检测信息

### 7.3 API 无法访问

- 确认 `.env` 中 `LMS_API_PORT` 值
- 确认 `docker-compose.yml` 中端口映射
- 不要在 LM Studio UI 中修改 API 端口

## 8. AMD / Intel GPU 推理建议

当前工程默认针对 NVIDIA 运行时优化。若需 AMD 或 Intel GPU 推理，可参考以下方向。

### 8.1 推荐方向

- Intel GPU：建议使用 Vulkan 后端
  - `.env` 中建议：
    - `PREFERRED_GPU_BACKEND=vulkan`
    - `FALLBACK_GPU_BACKEND=vulkan`
  - `docker-compose.yml` 中移除 NVIDIA 专属配置：
    - 删除 `runtime: nvidia`
    - 删除 `gpus: all`
    - 删除 `NVIDIA_VISIBLE_DEVICES` 与 `NVIDIA_DRIVER_CAPABILITIES`
  - 保留 Vulkan 用户态依赖，并使用 `vulkaninfo` 验证
  - Linux 建议挂载 `/dev/dri`

- AMD GPU：建议优先 ROCm 后端
  - 若 LM Studio 版本支持，在 `.env` 中设置：
    - `PREFERRED_GPU_BACKEND=rocm`
    - `FALLBACK_GPU_BACKEND=vulkan`
  - `docker-compose.yml` 中替换掉 NVIDIA 专属配置：
    - 删除 `runtime: nvidia`
    - 删除 `gpus: all`
    - 删除 `NVIDIA_VISIBLE_DEVICES` 与 `NVIDIA_DRIVER_CAPABILITIES`
  - 说明：`gpus: all` 是 NVIDIA 运行时连接项，不是 ROCm 必需项
  - Linux 建议挂载 ROCm 相关设备：
    - `/dev/kfd`
    - `/dev/dri`
  - 确保容器用户具备 `render` 与 `video` 组访问权限

### 8.2 验证清单

- Intel 路线：
  - 容器内可见 Vulkan 设备
  - LM Studio runtime survey 可检测到 Vulkan 后端
- AMD 路线：
  - 容器内可见 ROCm 栈（例如可用 `rocminfo`）
  - LM Studio runtime survey 可检测到 ROCm 后端
  - 若 ROCm 未检测到，可临时回退到 Vulkan
- 先用小模型验证，再进行大模型压力测试

### 8.3 免责声明

- 由于设备限制，我尚未在本项目中实际验证 AMD GPU 或 Intel GPU 推理。
- 若你需要 AMD/Intel 生产可用方案，请在你的硬件环境中自行探索、适配并完成验证。
