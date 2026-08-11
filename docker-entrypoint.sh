#!/bin/sh
# Hexo blogging platform container bootstrap.
# - seeds /data/source and /data/public from pristine image copies on first boot
# - injects hexo-admin auth + site URL into _config.yml from env
# - generates /data/artalk.yml (Artalk comments) from env
# - hands off to supervisord (nginx + hexo + artalk + ttyd + minio)
#
# Single persistent volume at /data: site source, generated site, comment
# SQLite DB, uploaded images and MinIO data all live there.

set -e

export TZ="${TZ:-UTC}"
export PORT="${PORT:-80}"

# --- volumes: ownership (Railway mounts as root) ---
chown -R node:node /app /data 2>/dev/null || true

# --- seed site content on first boot (volume is empty) ---
mkdir -p /data/source /data/public
if [ -z "$(ls -A /data/source/_posts 2>/dev/null)" ]; then
  echo "[entrypoint] seeding /data/source from image copy"
  cp -a /opt/hexo-data/source/. /data/source/
fi
if [ ! -f /data/public/index.html ]; then
  echo "[entrypoint] seeding /data/public from image copy"
  cp -a /opt/hexo-data/public/. /data/public/
fi

# --- hexo _config.yml: public URL from Railway ---
if [ -n "$RAILWAY_PUBLIC_DOMAIN" ]; then
  sed -i "s|^url:.*|url: https://${RAILWAY_PUBLIC_DOMAIN}|" /app/_config.yml
fi

# --- hexo-admin auth (bcrypt hash; removed when ADMIN_PASSWORD is unset) ---
node /app/tools/admin-auth.js "$ADMIN_USERNAME" "$ADMIN_PASSWORD"

# --- Artalk comments config ---
node /app/tools/gen-artalk-config.js

# --- ensure everything the node processes touch is node-owned ---
chown -R node:node /app /data 2>/dev/null || true

# --- MinIO defaults ---
export MINIO_ROOT_USER="${MINIO_ROOT_USER:-minioadmin}"
export MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-minioadmin}"

echo "[entrypoint] starting supervisord"
exec supervisord -n -c /etc/supervisor/supervisord.conf