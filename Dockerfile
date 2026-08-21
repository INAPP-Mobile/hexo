# syntax=docker/dockerfile:1
# Hexo blog + hexo-admin + ttyd web terminal
# Single service, one public URL: nginx routes / (blog), /admin/, /terminal/

######## Stage 1: build site + node_modules ########
FROM node:26-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .
# Generate into /data/public (matches runtime source_dir/public_dir)
RUN mkdir -p /data/source && cp -a /app/source/. /data/source/ && npx hexo generate

######## Stage 2: runtime ########
FROM node:26-slim
ENV DEBIAN_FRONTEND=noninteractive \
    PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# nginx (web router), supervisor (process manager), curl (healthcheck), htpasswd (terminal auth), tzdata
RUN apt-get update \
 && apt-get install -y --no-install-recommends nginx supervisor curl apache2-utils ca-certificates tzdata \
 && rm -rf /var/lib/apt/lists/* \
 && rm -f /etc/nginx/sites-enabled/default

# ttyd 1.7.7 (web terminal, static binary)
RUN curl -fsSL https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 -o /usr/local/bin/ttyd \
 && chmod +x /usr/local/bin/ttyd

# ttyd launcher (injects basic-auth credential from env when set)
COPY start-ttyd.sh /usr/local/bin/start-ttyd.sh
RUN chmod +x /usr/local/bin/start-ttyd.sh

WORKDIR /app
COPY --from=build /app /app

# Pristine site copies used to seed the persistent volume (/data) on first boot
COPY --from=build /data /opt/hexo-data

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY supervisord.conf /etc/supervisor/conf.d/hexo.conf
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

USER root
EXPOSE 80

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -fsS http://127.0.0.1/ -o /dev/null || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]