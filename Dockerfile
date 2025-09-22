# syntax = docker/dockerfile:1

# Adjust NODE_VERSION as desired
ARG NODE_VERSION=20.18.0
FROM node:${NODE_VERSION}-slim AS base

LABEL fly_launch_runtime="Node.js"

# Node.js app lives here
WORKDIR /app

# Set production environment
ENV NODE_ENV="production"

# ========= build stage =========
FROM base AS build

# Install packages needed to build node modules
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential node-gyp pkg-config python-is-python3

# Install node modules
COPY package.json ./
RUN npm install

# Copy application code
COPY . .

# ========= final stage =========
FROM node:${NODE_VERSION}-slim

# 安装 nginx 和 supervisor
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y nginx supervisor && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 从 build 阶段复制代码
COPY --from=build /app /app

# 把静态资源复制到 nginx 的 html 目录
# 这里假设 index.html 在仓库根目录
RUN cp /app/index.html /usr/share/nginx/html/
# 如果还有 css/js/img 目录，请一并复制
# RUN cp -r /app/public/* /usr/share/nginx/html/

# 复制 nginx.conf & supervisord.conf（你需要在 repo 里提供这两个文件）
COPY nginx.conf /etc/nginx/nginx.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# 暴露端口（nginx 会监听 8080）
EXPOSE 8080

# 启动 supervisor（同时跑 Node + Nginx）
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
