#!/bin/zsh

set -u

BACKEND_DIR="${0:A:h}"

if [[ -f "${BACKEND_DIR}/.env" ]]; then
    set -a
    source "${BACKEND_DIR}/.env"
    set +a
fi

export ALLOW_LOOPBACK_WITHOUT_TOKEN="${ALLOW_LOOPBACK_WITHOUT_TOKEN:-true}"

exec "${BACKEND_DIR}/.venv/bin/uvicorn" app.main:app \
    --app-dir "${BACKEND_DIR}" \
    --host 127.0.0.1 \
    --port 8000
