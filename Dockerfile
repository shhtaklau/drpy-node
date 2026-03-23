# 构建器阶段
FROM node:20-alpine AS builder

# 安装 git 和构建工具
RUN apk add --no-cache git python3 make g++

# 设置国内镜像源（加速下载）
RUN yarn config set registry https://registry.npmmirror.com && \
    npm config set registry https://registry.npmmirror.com

# 创建工作目录
WORKDIR /app

# 复制 package.json 文件（利用 Docker 缓存）
COPY package.json yarn.lock* ./

# 安装依赖（增加超时时间）
RUN yarn install --network-timeout 100000 || \
    npm install --network-timeout 100000

# 安装 puppeteer（跳过 Chromium 下载，减小体积）
RUN yarn add puppeteer --ignore-optional || \
    npm install puppeteer --ignore-optional

# 复制所有源代码
COPY . .

# 复制到临时目录
RUN mkdir -p /tmp/drpys && \
    cp -r /app/. /tmp/drpys/

# 运行器阶段
FROM alpine:latest AS runner

# 安装运行时环境
RUN apk add --no-cache \
    nodejs \
    npm \
    php83 \
    php83-cli \
    php83-curl \
    php83-mbstring \
    php83-xml \
    php83-pdo \
    php83-pdo_mysql \
    php83-pdo_sqlite \
    php83-openssl \
    php83-sqlite3 \
    php83-json \
    php83-phar \
    python3 \
    py3-pip \
    py3-setuptools \
    py3-wheel \
    bash \
    curl \
    ca-certificates \
    && ln -sf /usr/bin/php83 /usr/bin/php \
    && ln -sf /usr/bin/python3 /usr/bin/python

# 创建工作目录
WORKDIR /app

# 从构建器复制文件
COPY --from=builder /tmp/drpys/. /app/

# 配置文件处理
RUN cp /app/.env.development /app/.env 2>/dev/null || true && \
    rm -f /app/.env.development 2>/dev/null || true && \
    mkdir -p /app/config && \
    echo '{"ali_token":"","ali_refresh_token":"","quark_cookie":"","uc_cookie":"","bili_cookie":"","thread":"10","enable_dr2":"1","enable_py":"2"}' > /app/config/env.json

# 设置 Python 虚拟环境
RUN python3 -m venv /app/.venv && \
    . /app/.venv/bin/activate && \
    if [ -f /app/spider/py/base/requirements.txt ]; then \
        pip3 install -r /app/spider/py/base/requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple; \
    fi

# 创建数据目录
RUN mkdir -p /app/data /app/logs && \
    chmod -R 755 /app

# 暴露端口
EXPOSE 5757

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:5757/health || exit 1

# 启动命令
CMD ["node", "index.js"]
