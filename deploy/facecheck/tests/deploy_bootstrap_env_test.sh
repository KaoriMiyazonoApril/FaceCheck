#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

FAKE_BIN="${TMP_DIR}/bin"
mkdir -p "${FAKE_BIN}" "${TMP_DIR}/etc"

FAKE_DOCKER_LOG="${TMP_DIR}/docker.log"
FAKE_CURL_LOG="${TMP_DIR}/curl.log"
export FAKE_DOCKER_LOG
export FAKE_CURL_LOG

cat > "${FAKE_BIN}/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${FAKE_DOCKER_LOG:?}"
EOF

cat > "${FAKE_BIN}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${FAKE_CURL_LOG:?}"
EOF

chmod +x "${FAKE_BIN}/docker" "${FAKE_BIN}/curl"

ENV_FILE="${TMP_DIR}/etc/facecheck.env"

PATH="${FAKE_BIN}:${PATH}" \
FACECHECK_ENV_FILE="${ENV_FILE}" \
bash "${REPO_ROOT}/deploy/facecheck/scripts/deploy.sh"

test -f "${ENV_FILE}"

if grep -q 'replace-with-a-strong' "${ENV_FILE}"; then
  echo "expected bootstrap to replace placeholder secrets in ${ENV_FILE}" >&2
  exit 1
fi

if ! grep -q '^POSTGRES_PASSWORD=' "${ENV_FILE}"; then
  echo "expected POSTGRES_PASSWORD in ${ENV_FILE}" >&2
  exit 1
fi

if ! grep -q '^DB_PASSWORD=' "${ENV_FILE}"; then
  echo "expected DB_PASSWORD in ${ENV_FILE}" >&2
  exit 1
fi

if ! grep -q '^JWT_SECRET=' "${ENV_FILE}"; then
  echo "expected JWT_SECRET in ${ENV_FILE}" >&2
  exit 1
fi

if [[ "$(stat -c '%a' "${ENV_FILE}")" != "600" ]]; then
  echo "expected ${ENV_FILE} to have 600 permissions" >&2
  exit 1
fi

if ! grep -q 'compose --env-file' "${FAKE_DOCKER_LOG}"; then
  echo "expected docker compose to be invoked" >&2
  exit 1
fi

if ! grep -q 'http://127.0.0.1:18080/api/health' "${FAKE_CURL_LOG}"; then
  echo "expected health check curl to be invoked" >&2
  exit 1
fi

CUSTOM_ENV_FILE="${TMP_DIR}/etc/custom-facecheck.env"
cp "${REPO_ROOT}/deploy/facecheck/facecheck.env.example" "${CUSTOM_ENV_FILE}"
sed -i \
  -e 's|^FACECHECK_BACKEND_HOST_PORT=.*|FACECHECK_BACKEND_HOST_PORT=19090|' \
  -e 's|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=test-postgres-password|' \
  -e 's|^DB_PASSWORD=.*|DB_PASSWORD=test-postgres-password|' \
  -e 's|^REDIS_PASSWORD=.*|REDIS_PASSWORD=test-redis-password|' \
  -e 's|^RABBITMQ_PASSWORD=.*|RABBITMQ_PASSWORD=test-rabbitmq-password|' \
  -e 's|^JWT_SECRET=.*|JWT_SECRET=test-jwt-secret-with-more-than-32-characters|' \
  "${CUSTOM_ENV_FILE}"

: > "${FAKE_CURL_LOG}"

PATH="${FAKE_BIN}:${PATH}" \
FACECHECK_ENV_FILE="${CUSTOM_ENV_FILE}" \
bash "${REPO_ROOT}/deploy/facecheck/scripts/deploy.sh"

if ! grep -q 'http://127.0.0.1:19090/api/health' "${FAKE_CURL_LOG}"; then
  echo "expected deploy health check to honor FACECHECK_BACKEND_HOST_PORT from env file" >&2
  exit 1
fi
