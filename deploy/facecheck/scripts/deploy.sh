#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/deploy/facecheck/docker-compose.prod.yml"
ENV_FILE="${FACECHECK_ENV_FILE:-/etc/facecheck/facecheck.env}"
HEALTH_PATH="${FACECHECK_BACKEND_HEALTH_PATH:-/api/health}"
MAX_WAIT_SECONDS="${FACECHECK_DEPLOY_MAX_WAIT_SECONDS:-180}"
SLEEP_SECONDS="${FACECHECK_DEPLOY_POLL_INTERVAL_SECONDS:-5}"
ENV_TEMPLATE_FILE="${REPO_ROOT}/deploy/facecheck/facecheck.env.example"

env_file_value() {
    local name="${1:?env name is required}"
    local default_value="${2:-}"
    local value=""

    if [[ -f "${ENV_FILE}" ]]; then
        value="$(grep -E "^${name}=" "${ENV_FILE}" | tail -n 1 | cut -d= -f2- || true)"
    fi

    if [[ -n "${value}" ]]; then
        printf '%s' "${value}"
    else
        printf '%s' "${default_value}"
    fi
}

generate_secret() {
    local length="${1:?secret length is required}"
    local secret=""

    while (( ${#secret} < length )); do
        secret+="$(
            dd if=/dev/urandom bs=64 count=1 status=none \
                | base64 \
                | tr -dc 'A-Za-z0-9'
        )"
    done

    printf '%s' "${secret:0:length}"
}

bootstrap_env_file() {
    local env_dir
    local postgres_password
    local redis_password
    local rabbitmq_password
    local jwt_secret

    if [[ -f "${ENV_FILE}" ]]; then
        return 0
    fi

    if [[ ! -f "${ENV_TEMPLATE_FILE}" ]]; then
        echo "Missing deploy env file: ${ENV_FILE}" >&2
        echo "Bootstrap template not found: ${ENV_TEMPLATE_FILE}" >&2
        exit 1
    fi

    env_dir="$(dirname "${ENV_FILE}")"
    mkdir -p "${env_dir}"
    cp "${ENV_TEMPLATE_FILE}" "${ENV_FILE}"
    chmod 600 "${ENV_FILE}"

    postgres_password="$(generate_secret 32)"
    redis_password="$(generate_secret 32)"
    rabbitmq_password="$(generate_secret 32)"
    jwt_secret="$(generate_secret 48)"

    sed -i \
        -e "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${postgres_password}|" \
        -e "s|^DB_PASSWORD=.*|DB_PASSWORD=${postgres_password}|" \
        -e "s|^REDIS_PASSWORD=.*|REDIS_PASSWORD=${redis_password}|" \
        -e "s|^RABBITMQ_PASSWORD=.*|RABBITMQ_PASSWORD=${rabbitmq_password}|" \
        -e "s|^JWT_SECRET=.*|JWT_SECRET=${jwt_secret}|" \
        "${ENV_FILE}"

    echo "Bootstrapped deploy env file: ${ENV_FILE}"
}

bootstrap_env_file

HOST_PORT="$(env_file_value FACECHECK_BACKEND_HOST_PORT "${FACECHECK_BACKEND_HOST_PORT:-18080}")"

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
