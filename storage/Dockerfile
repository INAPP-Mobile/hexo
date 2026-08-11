# syntax=docker/dockerfile:1
# MinIO S3-compatible storage — official image + entrypoint for PORT
# Listens on PORT (injected by Railway), console on PORT+1
FROM minio/minio:RELEASE.2025-09-07T16-13-09Z
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
EXPOSE 9000
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -fsS http://127.0.0.1:${PORT:-9000}/minio/health/live >/dev/null 2>&1 || exit 1
ENTRYPOINT ["/docker-entrypoint.sh"]