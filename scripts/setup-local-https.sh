#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env}"
ENV_PATH="${ROOT_DIR}/${ENV_FILE}"
CERT_DIR="${ROOT_DIR}/certs"
CERT_FILE="${CERT_DIR}/local-ai.pem"
KEY_FILE="${CERT_DIR}/local-ai-key.pem"
STATE_DIR="${STATE_DIR:-}"

read_env_value() {
  local key="$1"

  if [[ -f "${ENV_PATH}" ]]; then
    sed -n "s/^${key}=//p" "${ENV_PATH}" | tail -n 1
  fi
}

AI_HOSTNAME="${LOCALHOST_AI_HOSTNAME:-${AI_HOSTNAME:-$(read_env_value LOCALHOST_AI_HOSTNAME)}}"
AI_HOSTNAME="${AI_HOSTNAME:-$(read_env_value AI_HOSTNAME)}"
AI_HOSTNAME="${AI_HOSTNAME:-ai.localhost}"

if [[ ! "${AI_HOSTNAME}" =~ ^[A-Za-z0-9.-]+$ ]]; then
  echo "Erro: AI_HOSTNAME contém caracteres inválidos: ${AI_HOSTNAME}" >&2
  exit 1
fi

if ! command -v mkcert >/dev/null 2>&1; then
  echo "Erro: mkcert não está instalado." >&2
  echo "No Ubuntu/WSL, execute:" >&2
  echo "  sudo apt-get update" >&2
  echo "  sudo apt-get install -y mkcert libnss3-tools" >&2
  exit 1
fi

mkdir -p "${CERT_DIR}"

CAROOT="$(mkcert -CAROOT)"
if [[ -n "${STATE_DIR}" ]]; then
  mkdir -p "${STATE_DIR}"
  chmod 0700 "${STATE_DIR}"
  printf '%s\n' "${CAROOT}" >"${STATE_DIR}/mkcert-caroot"
  if [[ ! -f "${CAROOT}/rootCA.pem" && ! -e "${STATE_DIR}/mkcert-ca-observed" ]]; then
    touch "${STATE_DIR}/mkcert-ca-created"
  fi
  touch "${STATE_DIR}/mkcert-ca-observed"
fi

echo "Instalando a CA local do mkcert no armazenamento de confiança deste sistema."
echo "A chave da CA permanece fora do repositório, no diretório administrado pelo mkcert."
mkcert -install

echo "Gerando certificado para ${AI_HOSTNAME}."
mkcert \
  -cert-file "${CERT_FILE}" \
  -key-file "${KEY_FILE}" \
  "${AI_HOSTNAME}" localhost 127.0.0.1 ::1

chmod 0644 "${CERT_FILE}"
chmod 0600 "${KEY_FILE}"

if grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
  if command -v certutil.exe >/dev/null 2>&1 && command -v wslpath >/dev/null 2>&1; then
    ROOT_CA_FILE="${CAROOT}/rootCA.pem"
    WINDOWS_ROOT_CA_FILE="$(wslpath -w "${ROOT_CA_FILE}")"
    WINDOWS_CA_THUMBPRINT=""
    if command -v openssl >/dev/null 2>&1; then
      WINDOWS_CA_THUMBPRINT="$(openssl x509 -in "${ROOT_CA_FILE}" -noout -fingerprint -sha1 \
        | sed 's/^.*=//' | tr -d ':')"
    fi

    echo "Instalando a CA local no armazenamento do usuário Windows para o navegador do host."
    WINDOWS_CA_ALREADY_TRUSTED=false
    if [[ -n "${WINDOWS_CA_THUMBPRINT}" ]] \
      && certutil.exe -user -store Root "${WINDOWS_CA_THUMBPRINT}" >/dev/null 2>&1; then
      WINDOWS_CA_ALREADY_TRUSTED=true
    fi
    if ! certutil.exe -f -user -addstore Root "${WINDOWS_ROOT_CA_FILE}" >/dev/null; then
      echo "Aviso: não foi possível confiar automaticamente na CA no Windows." >&2
      echo "Importe manualmente este certificado no armazenamento 'Autoridades de Certificação Raiz Confiáveis':" >&2
      echo "  ${ROOT_CA_FILE}" >&2
    elif [[ -n "${STATE_DIR}" && "${WINDOWS_CA_ALREADY_TRUSTED}" == false \
      && -n "${WINDOWS_CA_THUMBPRINT}" ]]; then
      printf '%s\n' "${WINDOWS_CA_THUMBPRINT}" >"${STATE_DIR}/windows-ca-thumbprint"
    fi
  else
    echo "Aviso: WSL detectado, mas certutil.exe ou wslpath não está disponível." >&2
    echo "O navegador do Windows poderá exibir um alerta até que a CA do mkcert seja importada nele." >&2
  fi
fi

echo "HTTPS configurado para https://${AI_HOSTNAME}"
