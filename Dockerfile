# 阶段一：构建前端
FROM node:18-alpine AS frontend-builder
WORKDIR /app/web-ui
COPY web-ui/package*.json ./
RUN npm install
COPY web-ui/ ./
RUN npm run build

# 阶段二：最终镜像
FROM python:3.10-slim

WORKDIR /app

# ============================================
# 关键修改：更换软件源并增加重试
# ============================================

# 1. 先配置 Debian 软件源为阿里云镜像（更稳定）
RUN echo "deb http://mirrors.aliyun.com/debian bookworm main contrib non-free non-free-firmware" > /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/debian bookworm-updates main contrib non-free non-free-firmware" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/debian bookworm-backports main contrib non-free non-free-firmware" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/debian-security bookworm-security main contrib non-free non-free-firmware" >> /etc/apt/sources.list

# 2. 更新软件包列表（如果失败，重试）
RUN apt-get update -o Acquire::Retries=5 || (echo "第一次更新失败，等待5秒后重试..." && sleep 5 && apt-get update -o Acquire::Retries=5)

# 3. 安装系统依赖（分步安装，确保关键包成功）
RUN apt-get install -y --no-install-recommends --fix-missing \
        wget \
        ca-certificates \
    && apt-get clean

RUN apt-get install -y --no-install-recommends --fix-missing \
        libgl1-mesa-glx \
        libglib2.0-0 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 复制前端构建产物
COPY --from=frontend-builder /app/web-ui/dist /app/web-ui/dist

# 复制后端源码
COPY . .

# ----- 安装 AI 依赖 -----
RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
RUN pip install --no-cache-dir ultralytics

# 下载 YOLO 模型（增加重试和超时）
RUN mkdir -p /app/models && \
    wget -O /app/models/yolov8n.pt --tries=5 --timeout=60 \
        https://github.com/ultralytics/assets/releases/download/v0.0.0/yolov8n.pt || \
    (echo "下载失败，使用备用地址..." && \
     wget -O /app/models/yolov8n.pt --tries=5 --timeout=60 \
        https://huggingface.co/ultralytics/assets/resolve/main/yolov8n.pt)

# 安装项目其他依赖（跳过可能冲突的包）
RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 8765
CMD ["python", "web_server.py"]
