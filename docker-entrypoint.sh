#!/bin/sh
# Hexo blogging platform container bootstrap.
# - fixes volume ownership (idempotent)
# - seeds /app/source and /app/public from pristine image copies on first boot
# - injects hexo-admin auth + site URL into _config.yml from env
# - generates /data/artalk.yml (Artalk comments) from env
# - hands off to supervisord (nginx + hexo + artalk + ttyd + minio)

set -e

export TZ="${TZ:-UTC}"
export PORT="${PORT:-80}"

# --- volumes: ownership (Railway mounts them as root) ---
chown -R node:node /app /data 2>/dev/null || true

# --- seed site content on first boot ---
if [ ! -d /app/source/_posts ] || [ -z "$(ls -A /app/source/_posts 2>/dev/null)" ]; then
  echo "[entrypoint] seeding /app/source from image copy"
  cp -a /opt/hexo-source/. /app/source/
fi
if [ ! -f /app/public/index.html ]; then
  echo "[entrypoint] seeding /app/public from image copy"
  cp -a /opt/hexo-public/. /app/public/
fi

# --- hexo _config.yml: public URL from Railway ---
if [ -n "$RAILWAY_PUBLIC_DOMAIN" ]; then
  sed -i "s|^url:.*|url: https://${RAILWAY_PUBLIC_DOMAIN}|" /app/_config.yml
fi

# --- hexo-admin auth (bcrypt hash; removed when ADMIN_PASSWORD is unset) ---
node /app/tools/admin-auth.js "$ADMIN_USERNAME" "$ADMIN_PASSWORD"

# --- Artalk comments config ---
node /app/tools/gen-artalk-config.js

# --- MinIO defaults ---
export MINIO_ROOT_USER="${MINIO_ROOT_USER:-minioadmin}"
export MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-minioadmin}"

echo "[entrypoint] starting supervisord"
exec supervisord -n -c /etc/supervisor/supervisord.conf