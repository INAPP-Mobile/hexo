# syntax=docker/dockerfile:1
# Hexo + hexo-admin + Artalk (comments) + MinIO (S3) + ttyd (web terminal)
# Single service, one public URL: nginx :80 routes / (blog), /admin/, /comment/, /terminal/, /minio/

######## Stage 1: build site + node_modules ########
FROM node:22-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .
RUN npx hexo generate

######## Stage 2: runtime ########
FROM node:22-slim
ENV DEBIAN_FRONTEND=noninteractive \
    PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# nginx (web router), supervisor (process manager), curl (healthcheck), tzdata
RUN apt-get update \
 && apt-get install -y --no-install-recommends nginx supervisor curl ca-certificates tzdata \
 && rm -rf /var/lib/apt/lists/* \
 && rm -f /etc/nginx/sites-enabled/default

# Artalk v2.10.0 (comments engine, Go binary)
RUN curl -fsSL https://github.com/ArtalkJS/Artalk/releases/download/v2.10.0/artalk_v2.10.0_linux_amd64.tar.gz -o /tmp/artalk.tgz \
 && tar -xzf /tmp/artalk.tgz -C /opt --strip-components=1 artalk_v2.10.0_linux_amd64/artalk \
 && rm /tmp/artalk.tgz \
 && chmod +x /opt/artalk

# ttyd 1.7.7 (web terminal, static binary)
RUN curl -fsSL https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 -o /usr/local/bin/ttyd \
 && chmod +x /usr/local/bin/ttyd

# MinIO (S3-compatible object storage, official rolling binary)
RUN curl -fsSL https://dl.min.io/server/minio/release/linux-amd64/minio -o /usr/local/bin/minio \
 && chmod +x /usr/local/bin/minio

WORKDIR /app
COPY --from=build /app /app

# Pristine copies used to seed the persistent volumes on first boot
RUN mkdir -p /data \
 && cp -a /app/source /opt/hexo-source \
 && cp -a /app/public /opt/hexo-public

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY supervisord.conf /etc/supervisor/conf.d/hexo.conf
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

USER root
EXPOSE 80

HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
  CMD curl -fsS http://127.0.0.1/ -o /dev/null || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]