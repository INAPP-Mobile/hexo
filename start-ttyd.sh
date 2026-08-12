#!/bin/sh
# ttyd web terminal launcher
# - binds to loopback only (Railway exposes nginx on PORT; ttyd is never public)
# - enables ttyd's native credential auth as a second layer behind nginx HTTP Basic Auth
# Runs as user `node` via supervisord; the shell is a login shell for that user.
set -e

if [ -n "${ADMIN_USERNAME}" ] && [ -n "${ADMIN_PASSWORD}" ]; then
    exec ttyd -W -i 127.0.0.1 -p 7681 -c "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" bash
fi

exec ttyd -W -i 127.0.0.1 -p 7681 bash
