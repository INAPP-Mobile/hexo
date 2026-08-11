# syntax=docker/dockerfile:1
# Artalk comments engine — official image + config entrypoint
# Listens on PORT (injected by Railway)
FROM artalk/artalk-go:2.10.0
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD wget -qO- http://127.0.0.1:${PORT:-8080}/ >/dev/null 2>&1 || exit 1
ENTRYPOINT ["/docker-entrypoint.sh"]