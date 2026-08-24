FROM node:18-alpine AS frontend-builder
WORKDIR /app/web-ui
COPY web-ui/package*.json ./
RUN npm install
COPY web-ui/ ./
RUN npm run build

FROM python:3.10-slim
WORKDIR /app

# 复制前端构建
COPY --from=frontend-builder /app/web-ui/dist /app/web-ui/dist

# 复制后端代码
COPY . .

# 升级 pip，设置超时，使用清华源安装 PyTorch
RUN pip install --upgrade pip && \
    pip install --no-cache-dir --timeout=100 --index-url https://pypi.tuna.tsinghua.edu.cn/simple torch torchvision torchaudio && \
    pip install --no-cache-dir --timeout=100 --index-url https://pypi.tuna.tsinghua.edu.cn/simple ultralytics && \
    pip install --no-cache-dir --timeout=100 --index-url https://pypi.tuna.tsinghua.edu.cn/simple -r requirements.txt

# 下载模型（使用 python -c 内置 urllib，避免依赖 wget）
RUN python -c "import urllib.request; urllib.request.urlretrieve('https://github.com/ultralytics/assets/releases/download/v0.0.0/yolov8n.pt', '/app/models/yolov8n.pt')" || \
    python -c "import urllib.request; urllib.request.urlretrieve('https://huggingface.co/ultralytics/assets/resolve/main/yolov8n.pt', '/app/models/yolov8n.pt')"

EXPOSE 8765
CMD ["python", "web_server.py"]
