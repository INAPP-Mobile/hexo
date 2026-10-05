# MinIO's Docker Hub repository was deleted in 2026 — the upstream project was
# archived and all published images removed. minio/minio:RELEASE.2025-09-07T16-13-09Z
# now returns 404 from the Hub API, and dl.min.io answers 410 Gone, so this service
# cannot be built from MinIO at all.
#
# RustFS is a drop-in S3-compatible replacement: same S3 API, same path-style
# addressing, and it serves the same /minio/health/live endpoint. That means the
# healthcheck and every ${{storage.MINIO_ROOT_*}} companion reference stay valid
# unchanged.
#
# Deliberately NO custom entrypoint or CMD override. A wrapper that touched the
# command (or mapped MINIO_ROOT_* onto RUSTFS_*) failed every Railway deployment;
# the bare upstream image deploys and logs normally. RustFS natively reads
# MINIO_ROOT_USER and MINIO_ROOT_PASSWORD as credential sources, so the template's
# existing variables pass straight through.
#
# hexo specifics: the API port stays 9000 (RustFS's default) and the console 9001;
# only the custom PORT-wrapper entrypoint had to go. The template already sets
# both via RUSTFS_ADDRESS in this Dockerfile.
FROM rustfs/rustfs:latest

# Run as root, overriding the image's default `rustfs` user. Railway mounts volumes
# root-owned, and as uid 10001 rustfs cannot write its metadata directory: it dies at
# startup with "Permission denied (os error 13)". This USER change is the only
# customization the image needs.
USER root

ENV RUSTFS_VOLUMES=/data \
    RUSTFS_ADDRESS=0.0.0.0:9000 \
    RUSTFS_CONSOLE_ADDRESS=0.0.0.0:9001 \
    RUSTFS_CONSOLE_ENABLE=true

# No Dockerfile VOLUME directive — Railway rejects it; the volume is attached via
# railway.json at /data, which matches RUSTFS_VOLUMES above.
HEALTHCHECK --interval=10s --timeout=3s --retries=5 --start-period=15s \
  CMD curl -f http://127.0.0.1:9000/minio/health/live || exit 1

EXPOSE 9000
EXPOSE 9001