# 阶段一：构建前端（保持不变）
FROM node:18-alpine AS frontend-builder
WORKDIR /app/web-ui
COPY web-ui/package*.json ./
RUN npm install
COPY web-ui/ ./
RUN npm run build

# 阶段二：构建最终运行镜像（增加 AI 依赖）
FROM python:3.10-slim

# 设置工作目录
WORKDIR /app

# 安装系统依赖（用于安装 PyTorch 和 OpenCV 等）
RUN apt-get update && apt-get install -y \
    wget \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# 从第一阶段复制构建好的前端静态文件
COPY --from=frontend-builder /app/web-ui/dist /app/web-ui/dist

# 复制后端 Python 代码
COPY . .

# ----- 重点：安装 AI 依赖 -----
# 1. 安装 CPU 版本的 PyTorch（因为 GitHub Actions 构建环境没有 GPU）
RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# 2. 安装 ultralytics（YOLO）
RUN pip install --no-cache-dir ultralytics

# 3. 下载 YOLOv8n 权重文件到 /app/models
RUN mkdir -p /app/models && \
    wget -O /app/models/yolov8n.pt https://github.com/ultralytics/assets/releases/download/v0.0.0/yolov8n.pt

# ----- 安装其他 Python 依赖（原 requirements.txt）-----
RUN pip install --no-cache-dir -r requirements.txt

# 暴露端口
EXPOSE 8765

# 启动命令
CMD ["python", "web_server.py"]
