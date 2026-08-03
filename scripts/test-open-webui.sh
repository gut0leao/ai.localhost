#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env}"

if [[ -f "${ROOT_DIR}/${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ROOT_DIR}/${ENV_FILE}"
  set +a
elif [[ -f "${ROOT_DIR}/.env.example" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env.example"
  set +a
fi

OPEN_WEBUI_BIND_HOST="${OPEN_WEBUI_BIND_HOST:-127.0.0.1}"
OPEN_WEBUI_PORT="${OPEN_WEBUI_PORT:-3000}"
URL="http://${OPEN_WEBUI_BIND_HOST}:${OPEN_WEBUI_PORT}"

echo "Testando Open WebUI em ${URL}"
curl --fail --silent --show-error --location "${URL}" >/dev/null
echo "Open WebUI respondeu com sucesso."
