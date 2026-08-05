#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env}"

# shellcheck source=env.sh
source "${ROOT_DIR}/scripts/env.sh"
load_project_env "${ROOT_DIR}" "${ENV_FILE}"

SEARXNG_BIND_HOST="${SEARXNG_BIND_HOST:-127.0.0.1}"
SEARXNG_PORT="${SEARXNG_PORT:-8080}"
URL="http://${SEARXNG_BIND_HOST}:${SEARXNG_PORT}/search?q=ollama&format=json"

echo "Testando SearXNG em ${URL}"
curl --fail --silent --show-error "${URL}" >/dev/null
echo "SearXNG respondeu com JSON com sucesso."
