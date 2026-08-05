#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env}"

# shellcheck source=env.sh
source "${ROOT_DIR}/scripts/env.sh"
load_project_env "${ROOT_DIR}" "${ENV_FILE}"

MODEL="${MODEL:-${OLLAMA_MODEL_DEFAULT:-qwen2.5-coder:7b}}"

echo "Baixando modelo: ${MODEL}"
docker compose --project-directory "${ROOT_DIR}" exec ollama ollama pull "${MODEL}"
echo "Modelo disponível: ${MODEL}"
