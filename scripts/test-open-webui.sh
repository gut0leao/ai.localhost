#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env}"

# shellcheck source=env.sh
source "${ROOT_DIR}/scripts/env.sh"
load_project_env "${ROOT_DIR}" "${ENV_FILE}"

AI_BIND_HOST="${AI_BIND_HOST:-127.0.0.1}"
AI_HOSTNAME="${AI_HOSTNAME:-ai.localhost}"
AI_HTTP_PORT="${AI_HTTP_PORT:-80}"
AI_HTTPS_PORT="${AI_HTTPS_PORT:-443}"

if [[ "${AI_HTTP_PORT}" == "80" ]]; then
  URL="http://${AI_HOSTNAME}"
else
  URL="http://${AI_HOSTNAME}:${AI_HTTP_PORT}"
fi

if [[ "${AI_HTTPS_PORT}" == "443" ]]; then
  HTTPS_URL="https://${AI_HOSTNAME}"
else
  HTTPS_URL="https://${AI_HOSTNAME}:${AI_HTTPS_PORT}"
fi

echo "Testando redirecionamento de ${URL} para HTTPS"
read -r HTTP_STATUS REDIRECT_URL < <(
  curl --silent --show-error --output /dev/null \
    --write-out '%{http_code} %{redirect_url}\n' \
    --resolve "${AI_HOSTNAME}:${AI_HTTP_PORT}:${AI_BIND_HOST}" \
    "${URL}"
)

if [[ ! "${HTTP_STATUS}" =~ ^30[178]$ || "${REDIRECT_URL}" != "${HTTPS_URL}/" ]]; then
  echo "Erro: redirecionamento HTTPS inesperado: status=${HTTP_STATUS} destino=${REDIRECT_URL}" >&2
  exit 1
fi

echo "Redirecionamento HTTPS respondeu corretamente."
echo "Testando Open WebUI em ${HTTPS_URL}"
curl --fail --silent --show-error --location \
  --resolve "${AI_HOSTNAME}:${AI_HTTPS_PORT}:${AI_BIND_HOST}" \
  "${HTTPS_URL}" >/dev/null
echo "Open WebUI respondeu com HTTPS confiável."
