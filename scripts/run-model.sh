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

MODEL="${MODEL:-${OLLAMA_MODEL_DEFAULT:-qwen2.5-coder:7b}}"

echo "Abrindo sessão interativa com: ${MODEL}"
docker compose --project-directory "${ROOT_DIR}" exec ollama ollama run "${MODEL}"
