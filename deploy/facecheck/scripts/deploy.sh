#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/deploy/facecheck/docker-compose.prod.yml"
ENV_FILE="${FACECHECK_ENV_FILE:-/etc/facecheck/facecheck.env}"
HOST_PORT="${FACECHECK_BACKEND_HOST_PORT:-18080}"
HEALTH_PATH="${FACECHECK_BACKEND_HEALTH_PATH:-/api/health}"
MAX_WAIT_SECONDS="${FACECHECK_DEPLOY_MAX_WAIT_SECONDS:-180}"
SLEEP_SECONDS="${FACECHECK_DEPLOY_POLL_INTERVAL_SECONDS:-5}"

if [[ ! -f "${ENV_FILE}" ]]; then
    echo "Missing deploy env file: ${ENV_FILE}" >&2
    exit 1
fi

docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" up -d --build --remove-orphans
docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" ps

health_url="http://127.0.0.1:${HOST_PORT}${HEALTH_PATH}"
deadline=$((SECONDS + MAX_WAIT_SECONDS))

until curl -fsS "${health_url}"; do
    if (( SECONDS >= deadline )); then
        echo "Backend did not become healthy within ${MAX_WAIT_SECONDS}s: ${health_url}" >&2
        docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" ps >&2
        docker logs --tail 200 facecheck-backend-1 >&2 || true
        exit 1
    fi
    sleep "${SLEEP_SECONDS}"
done
