#!/bin/sh
# Artalk config generator + launcher for Artalk 2.10
# Writes /data/artalk.yml from env, then execs artalk server
# POSIX sh compatible (no bashisms)

set -e

export TZ="${TZ:-UTC}"
export PORT="${PORT:-8080}"

# Generate a random app_key if not set (needed for JWT stability)
if [ -z "${ARTALK_APP_KEY}" ]; then
    export ARTALK_APP_KEY=$(head -c 32 /dev/urandom | base64 | tr -d '\n' | cut -c1-32)
fi

# Build trusted_domains YAML array (Artalk sends CORS headers only for these origins).
# Sources, in priority order:
#   1. ARTALK_TRUSTED_DOMAINS (space-separated list, e.g. "a.com b.com")
#   2. RAILWAY_SERVICE_HEXO_URL (Railway auto-injects sibling service URLs)
#   3. RAILWAY_PUBLIC_DOMAIN (fallback for local/dev runs)
# NOTE: POSIX sh does NOT interpret \n inside double quotes - use printf for real newlines.
if [ -n "${ARTALK_TRUSTED_DOMAINS}" ]; then
    DOMAINS_LIST="${ARTALK_TRUSTED_DOMAINS}"
elif [ -n "${RAILWAY_SERVICE_HEXO_URL}" ]; then
    DOMAINS_LIST="${RAILWAY_SERVICE_HEXO_URL}"
elif [ -n "${RAILWAY_PUBLIC_DOMAIN}" ]; then
    DOMAINS_LIST="${RAILWAY_PUBLIC_DOMAIN}"
else
    DOMAINS_LIST=""
fi

TRUSTED_YAML=""
if [ -n "${DOMAINS_LIST}" ]; then
    set -- ${DOMAINS_LIST}
    for domain in "$@"; do
        TRUSTED_YAML="${TRUSTED_YAML}$(printf '    - %s\n' "${domain}")"
    done
fi

# Generate artalk.yml from environment (Artalk 2.10 schema)
cat > /data/artalk.yml <<EOF
# Listen host
host: "0.0.0.0"

# Listen port
port: ${PORT}

# App Key (for generation of JWT)
app_key: "${ARTALK_APP_KEY}"

# Debug mode
debug: false

# Language (follow Unicode BCP 47)
locale: "${ARTALK_LOCALE:-en}"

# Timezone (follow IANA Time Zone Database)
timezone: "${TZ}"

# Default site name (create when app is first launched)
site_default: "${ARTALK_SITE_NAME:-My Hexo Blog}"

# Default site url
site_url: "${ARTALK_SITE_URL:-}"

# Login timeout (in seconds)
login_timeout: 259200

# Database
db:
  type: "${ARTALK_DB_TYPE:-sqlite}"
  file: "/data/artalk.db"
  table_prefix: ""
  name: artalk
  host: localhost
  port: 3306
  user: root
  password: ""
  charset: utf8mb4
  ssl: false
  prepare_stmt: true

# Web server
http:
  body_limit: 100
  proxy_header: ""

# Logging
log:
  enabled: true
  filename: "/data/artalk.log"

# Admin
admin:
  enabled: false
  anonymous: false
  callback: "http://127.0.0.1:${PORT}/api/v2/auth/{provider}/callback"
  email:
    enable: false
    host: ""
    port: 25
    username: ""
    password: ""
    from: ""
    to: ""
  accounts:
    - email: "${ARTALK_ADMIN_EMAIL:-admin@example.com}"
      password: "${ARTALK_ADMIN_PASSWORD:-changeme}"
      nickname: "${ARTALK_ADMIN_NAME:-admin}"
      permission: ["admin"]

# Trusted domains (for CORS)
trusted_domains:
${TRUSTED_YAML}

# Frontend (minimal; Artalk uses defaults for omitted fields)
frontend:
  pwa: false
  preview: false
  emoji: true
  markdown: true
  highlight: true
  math: false
  mermaid: false
  anchor: false
  dark_mode: false
  edit: false
  collapse: false

# Moderator
moderator:
  pending_default: false
  api_fail_block: false
  akismet_key: ""
  tencent:
    enabled: false

# Admin notifications
admin_notify:
  notify_tpl: default
  notify_pending: false
  noise_mode: false
  email:
    enable: false
    host: ""
    port: 465
    username: ""
    password: ""
    from: ""
    to: ""
    use_tls: true
  webhook:
    enable: false
    url: ""
    secret: ""

# Email
email:
  enable: false
  host: ""
  port: 465
  username: ""
  password: ""
  from: ""
  use_tls: true

# Security
security:
  ratelimit:
    enabled: true
    limit: 100
    window: 60
  ipblock:
    enabled: false
    duration: 3600
  captcha:
    enabled: false
    provider: "turnstile"
    site_key: ""
    secret_key: ""

# SSL (disabled by default; Railway provides TLS at edge)
ssl:
  enabled: false
  cert_path: ""
  key_path: ""
EOF

echo "[entrypoint] starting artalk on port ${PORT}"
exec /artalk server -c /data/artalk.yml --host 0.0.0.0 --port "${PORT}"