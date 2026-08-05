#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env}"

# shellcheck source=env.sh
source "${ROOT_DIR}/scripts/env.sh"
load_project_env "${ROOT_DIR}" "${ENV_FILE}"

OLLAMA_BIND_HOST="${OLLAMA_BIND_HOST:-127.0.0.1}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
URL="http://${OLLAMA_BIND_HOST}:${OLLAMA_PORT}/api/tags"

echo "Testando Ollama em ${URL}"
curl --fail --silent --show-error "${URL}" >/dev/null
echo "Ollama respondeu com sucesso."
