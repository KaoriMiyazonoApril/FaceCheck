#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
NGINX_SOURCE_CONF="${REPO_ROOT}/deploy/facecheck/nginx/facecheck-campus.conf"
NGINX_AVAILABLE_DIR="${FACECHECK_NGINX_AVAILABLE_DIR:-/etc/nginx/sites-available}"
NGINX_ENABLED_DIR="${FACECHECK_NGINX_ENABLED_DIR:-/etc/nginx/sites-enabled}"
NGINX_TARGET_CONF="${NGINX_AVAILABLE_DIR}/facecheck-campus.conf"
NGINX_ENABLED_LINK="${NGINX_ENABLED_DIR}/facecheck-campus.conf"

if ! command -v nginx >/dev/null 2>&1; then
    apt-get install -y nginx
fi

mkdir -p "${NGINX_AVAILABLE_DIR}" "${NGINX_ENABLED_DIR}"
cp "${NGINX_SOURCE_CONF}" "${NGINX_TARGET_CONF}"
ln -sfn "${NGINX_TARGET_CONF}" "${NGINX_ENABLED_LINK}"

nginx -t
systemctl enable --now nginx
systemctl reload nginx
