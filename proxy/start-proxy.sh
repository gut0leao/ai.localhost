#!/bin/sh
set -eu

if [ ! -s /certs/local-ai.pem ] || [ ! -s /certs/local-ai-key.pem ]; then
  echo "Erro: certificado HTTPS local não encontrado." >&2
  echo "Execute 'make setup-https' no host antes de iniciar o ambiente." >&2
  exit 1
fi

if [ "${AI_HTTPS_PORT:-443}" = "443" ]; then
  AI_HTTPS_ORIGIN="https://${AI_HOSTNAME:-ai.localhost}"
else
  AI_HTTPS_ORIGIN="https://${AI_HOSTNAME:-ai.localhost}:${AI_HTTPS_PORT}"
fi
export AI_HTTPS_ORIGIN

echo "Certificado local encontrado; habilitando HTTPS com redirecionamento de HTTP."
exec caddy run --config /etc/caddy/Caddyfile.https --adapter caddyfile
