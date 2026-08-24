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

# ----- 安装系统依赖（增加重试） -----
RUN apt-get update -o Acquire::Retries=3 --fix-missing && \
    apt-get install -y --no-install-recommends \
        wget \
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

# 下载 YOLO 模型（增加重试）
RUN mkdir -p /app/models && \
    wget -O /app/models/yolov8n.pt --tries=5 --timeout=30 \
        https://github.com/ultralytics/assets/releases/download/v0.0.0/yolov8n.pt

# 安装项目其他依赖
RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 8765
CMD ["python", "web_server.py"]
