# 阶段一：构建前端
FROM node:18-alpine AS frontend-builder
WORKDIR /app/web-ui
COPY web-ui/package*.json ./
RUN npm install
COPY web-ui/ ./
RUN npm run build

# 阶段二：构建最终运行镜像
FROM python:3.10-slim
WORKDIR /app
COPY --from=frontend-builder /app/web-ui/dist /app/web-ui/dist
COPY . .
RUN pip install --no-cache-dir -r requirements.txt
EXPOSE 8765
CMD ["python", "web_server.py"]
