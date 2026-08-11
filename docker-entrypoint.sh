#!/bin/sh
# Hexo blogging platform container bootstrap.
# - seeds /data/source and /data/public from pristine image copies on first boot
# - injects hexo-admin auth + site URL into _config.yml from env
# - hands off to supervisord (nginx + hexo + ttyd + regenerate)

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

# --- protect ttyd web terminal with HTTP Basic Auth (same creds as admin) ---
if [ -n "$ADMIN_USERNAME" ] && [ -n "$ADMIN_PASSWORD" ]; then
  if command -v htpasswd >/dev/null 2>&1; then
    htpasswd -bc /etc/nginx/.htpasswd "$ADMIN_USERNAME" "$ADMIN_PASSWORD"
  else
    printf '%s:%s\n' "$ADMIN_USERNAME" "$(openssl passwd -apr1 "$ADMIN_PASSWORD")" > /etc/nginx/.htpasswd
  fi
  chmod 644 /etc/nginx/.htpasswd
  echo "[entrypoint] terminal auth enabled for user ${ADMIN_USERNAME}"
else
  echo "[entrypoint] WARNING: ADMIN_USERNAME/ADMIN_PASSWORD unset - /terminal/ is OPEN"
fi

# --- ensure everything the node processes touch is node-owned ---
chown -R node:node /app /data 2>/dev/null || true

echo "[entrypoint] starting supervisord"
exec supervisord -n -c /etc/supervisor/conf.d/hexo.conf