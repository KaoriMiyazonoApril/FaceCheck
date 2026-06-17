#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

FAKE_BIN="${TMP_DIR}/bin"
FAKE_ROOT="${TMP_DIR}/root"
LOG_FILE="${TMP_DIR}/calls.log"

mkdir -p \
  "${FAKE_BIN}" \
  "${FAKE_ROOT}/etc/nginx/sites-available" \
  "${FAKE_ROOT}/etc/nginx/sites-enabled"

export LOG_FILE

cat > "${FAKE_BIN}/apt-get" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'apt-get %s\n' "$*" >> "${LOG_FILE:?}"
if [[ "${1:-}" == "install" && "${2:-}" == "-y" && "${3:-}" == "nginx" ]]; then
cat > "$(dirname "$0")/nginx" <<'INNER'
#!/usr/bin/env bash
set -euo pipefail
printf 'nginx %s\n' "$*" >> "${LOG_FILE:?}"
INNER
chmod +x "$(dirname "$0")/nginx"
fi
EOF

cat > "${FAKE_BIN}/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'systemctl %s\n' "$*" >> "${LOG_FILE:?}"
EOF

chmod +x "${FAKE_BIN}/apt-get" "${FAKE_BIN}/systemctl"

PATH="${FAKE_BIN}:${PATH}" \
FACECHECK_NGINX_AVAILABLE_DIR="${FAKE_ROOT}/etc/nginx/sites-available" \
FACECHECK_NGINX_ENABLED_DIR="${FAKE_ROOT}/etc/nginx/sites-enabled" \
bash "${REPO_ROOT}/deploy/facecheck/scripts/bootstrap_host.sh"

test -f "${FAKE_ROOT}/etc/nginx/sites-available/facecheck-campus.conf"
test -L "${FAKE_ROOT}/etc/nginx/sites-enabled/facecheck-campus.conf"

if ! grep -q '^apt-get install -y nginx$' "${LOG_FILE}"; then
  echo "expected bootstrap script to install nginx when command is missing" >&2
  exit 1
fi

if ! grep -q '^nginx -t$' "${LOG_FILE}"; then
  echo "expected bootstrap script to run nginx -t" >&2
  exit 1
fi

if ! grep -q '^systemctl enable --now nginx$' "${LOG_FILE}"; then
  echo "expected bootstrap script to enable nginx" >&2
  exit 1
fi

if ! grep -q '^systemctl reload nginx$' "${LOG_FILE}"; then
  echo "expected bootstrap script to reload nginx" >&2
  exit 1
fi
