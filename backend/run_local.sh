#!/bin/zsh

set -u

BACKEND_DIR="${0:A:h}"
PYTHON_BIN="${BACKEND_DIR}/.venv/bin/python"
UVICORN_BIN="${BACKEND_DIR}/.venv/bin/uvicorn"
LOG_FILE="${TMPDIR:-/tmp}/echome-backend.log"
PID_FILE="${TMPDIR:-/tmp}/echome-backend.pid"

/bin/launchctl remove app.echome.local-backend >/dev/null 2>&1 || true

if [[ -f "${PID_FILE}" ]]; then
    EXISTING_PID="$(<"${PID_FILE}")"
    if [[ "${EXISTING_PID}" == <-> ]] && /bin/kill -0 "${EXISTING_PID}" 2>/dev/null; then
        /bin/kill "${EXISTING_PID}" 2>/dev/null || true
        for _ in {1..20}; do
            /bin/kill -0 "${EXISTING_PID}" 2>/dev/null || break
            /bin/sleep 0.05
        done
    fi
    /bin/rm -f "${PID_FILE}"
fi

LISTENER_PID="$(/usr/sbin/lsof -tiTCP:8000 -sTCP:LISTEN 2>/dev/null | /usr/bin/head -n 1)"
if [[ -n "${LISTENER_PID}" ]]; then
    LISTENER_COMMAND="$(/bin/ps -p "${LISTENER_PID}" -o command= 2>/dev/null)"
    if [[ "${LISTENER_COMMAND}" == *uvicorn*app.main:app* ]]; then
        /bin/kill "${LISTENER_PID}" 2>/dev/null || true
        for _ in {1..20}; do
            /bin/kill -0 "${LISTENER_PID}" 2>/dev/null || break
            /bin/sleep 0.05
        done
    else
        echo "Port 8000 is already used by another process."
        exit 0
    fi
fi

if [[ ! -x "${PYTHON_BIN}" || ! -x "${UVICORN_BIN}" ]]; then
    echo "Echo.me backend dependencies are missing. See backend/README.md."
    exit 0
fi

/bin/rm -f "${LOG_FILE}"
"${PYTHON_BIN}" "${BACKEND_DIR}/start_daemon.py" \
    "${BACKEND_DIR}/serve_local.sh" \
    "${LOG_FILE}" \
    "${PID_FILE}"

for _ in {1..100}; do
    if /usr/bin/curl --silent --fail --max-time 1 http://127.0.0.1:8000/health >/dev/null 2>&1; then
        exit 0
    fi
    /bin/sleep 0.1
done

echo "Echo.me backend did not start. Check ${LOG_FILE}."
exit 0
