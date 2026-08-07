#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env}"

# shellcheck source=env.sh
source "${ROOT_DIR}/scripts/env.sh"
load_project_env "${ROOT_DIR}" "${ENV_FILE}"

MODEL="${MODEL:-${OLLAMA_MODEL_DEFAULT:-qwen2.5-coder:7b}}"

echo "Baixando modelo: ${MODEL}"
# O instalador costuma ser executado por `curl | bash`; nesse caso stdin não é
# um terminal. Desabilitar a alocação de TTY mantém o progresso do pull e evita
# que o Compose interrompa o download antes de iniciá-lo.
docker compose --project-directory "${ROOT_DIR}" exec -T ollama ollama pull "${MODEL}"
echo "Modelo disponível: ${MODEL}"
