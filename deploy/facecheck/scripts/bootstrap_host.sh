#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
NGINX_SOURCE_CONF="${REPO_ROOT}/deploy/facecheck/nginx/facecheck-campus.conf"
ENV_FILE="${FACECHECK_ENV_FILE:-/etc/facecheck/facecheck.env}"
NGINX_AVAILABLE_DIR="${FACECHECK_NGINX_AVAILABLE_DIR:-/etc/nginx/sites-available}"
NGINX_ENABLED_DIR="${FACECHECK_NGINX_ENABLED_DIR:-/etc/nginx/sites-enabled}"
NGINX_TARGET_CONF="${NGINX_AVAILABLE_DIR}/facecheck-campus.conf"
NGINX_ENABLED_LINK="${NGINX_ENABLED_DIR}/facecheck-campus.conf"

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

if ! command -v nginx >/dev/null 2>&1; then
    apt-get update
    apt-get install -y nginx
fi

mkdir -p "${NGINX_AVAILABLE_DIR}" "${NGINX_ENABLED_DIR}"
cp "${NGINX_SOURCE_CONF}" "${NGINX_TARGET_CONF}"
BACKEND_HOST_PORT="$(env_file_value FACECHECK_BACKEND_HOST_PORT "${FACECHECK_BACKEND_HOST_PORT:-18080}")"
sed -i "s|proxy_pass http://127.0.0.1:[0-9][0-9]*;|proxy_pass http://127.0.0.1:${BACKEND_HOST_PORT};|" "${NGINX_TARGET_CONF}"
ln -sfn "${NGINX_TARGET_CONF}" "${NGINX_ENABLED_LINK}"

nginx -t
systemctl enable --now nginx
systemctl reload nginx
