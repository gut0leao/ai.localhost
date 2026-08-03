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

OLLAMA_BIND_HOST="${OLLAMA_BIND_HOST:-127.0.0.1}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
URL="http://${OLLAMA_BIND_HOST}:${OLLAMA_PORT}/api/tags"

echo "Testando Ollama em ${URL}"
curl --fail --silent --show-error "${URL}" >/dev/null
echo "Ollama respondeu com sucesso."
