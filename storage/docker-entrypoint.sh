#!/bin/sh
# MinIO wrapper respecting Railway PORT
# Runs: minio server /data --address :$PORT --console-address :$CONSOLE_PORT

set -e

export TZ="${TZ:-UTC}"
export PORT="${PORT:-9000}"
export CONSOLE_PORT="${CONSOLE_PORT:-9001}"

echo "[entrypoint] starting minio on API port ${PORT}, console port ${CONSOLE_PORT}"
exec minio server /data --address ":${PORT}" --console-address ":${CONSOLE_PORT}"