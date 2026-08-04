#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_URL="https://github.com/gut0leao/local-coding-ai.git"
RAW_INSTALLER_URL="https://raw.githubusercontent.com/gut0leao/local-coding-ai/main/install.sh"
DEFAULT_INSTALL_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/local-coding-ai"
INSTALL_DIR="${LOCAL_AI_INSTALL_DIR:-${DEFAULT_INSTALL_DIR}}"
PROJECT_DIR="${AIDER_PROJECT_DIR:-${PWD}}"
GENERAL_MODEL="${LOCAL_AI_GENERAL_MODEL:-}"
CODE_MODEL="${LOCAL_AI_CODE_MODEL:-}"
AIDER_MODEL="${LOCAL_AI_AIDER_MODEL:-}"
AI_COMMAND_PATH="${HOME}/.local/bin/ai.localhost"
ASSUME_YES=false
CHECK_ONLY=false
FORCE_CPU=false
LAUNCH_AIDER=true
GPU_AVAILABLE=false
GPU_VRAM_MB=0
SYSTEM_RAM_MB=0
REQUIRED_DISK_GB=0
SCRIPT_ROOT=""

info() {
  printf '\n==> %s\n' "$*"
}

success() {
  printf 'OK: %s\n' "$*"
}

warn() {
  printf 'Aviso: %s\n' "$*" >&2
}

fail() {
  printf 'Erro: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<EOF
Instalador do local-coding-ai

Uso local:
  ./install.sh [opções]

Uso remoto:
  curl -fsSL ${RAW_INSTALLER_URL} | bash -s -- [opções]

Opções:
  --check-only           Verifica o ambiente sem instalar ou baixar arquivos.
  --yes                  Aceita as confirmações automaticamente.
  --cpu                  Ignora GPU e configura execução em CPU.
  --no-launch            Instala tudo sem abrir o Aider ao final.
  --install-dir CAMINHO  Diretório da stack (padrão: ${DEFAULT_INSTALL_DIR}).
  --project-dir CAMINHO  Repositório que o Aider abrirá (padrão: diretório atual).
  --general-model MODELO Sobrescreve o modelo Qwen geral escolhido automaticamente.
  --code-model MODELO    Sobrescreve o modelo Qwen de código escolhido automaticamente.
  --aider-model MODELO   Sobrescreve o modelo usado para abrir o Aider.
  -h, --help             Exibe esta ajuda.

As mesmas opções de modelos podem ser definidas por LOCAL_AI_GENERAL_MODEL,
LOCAL_AI_CODE_MODEL e LOCAL_AI_AIDER_MODEL. LOCAL_AI_INSTALL_DIR e
AIDER_PROJECT_DIR também são aceitas.
EOF
}

confirm() {
  local prompt="$1"
  local answer

  if [[ "${ASSUME_YES}" == true ]]; then
    return 0
  fi

  if [[ ! -r /dev/tty ]]; then
    fail "confirmação interativa indisponível; execute novamente com --yes"
  fi

  printf '%s [S/n] ' "${prompt}" >/dev/tty
  read -r answer </dev/tty || true
  [[ -z "${answer}" || "${answer}" =~ ^[SsYy]$ ]]
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --check-only)
        CHECK_ONLY=true
        ;;
      --yes)
        ASSUME_YES=true
        ;;
      --cpu)
        FORCE_CPU=true
        ;;
      --no-launch)
        LAUNCH_AIDER=false
        ;;
      --install-dir)
        [[ $# -ge 2 ]] || fail "--install-dir requer um caminho"
        INSTALL_DIR="$2"
        shift
        ;;
      --project-dir)
        [[ $# -ge 2 ]] || fail "--project-dir requer um caminho"
        PROJECT_DIR="$2"
        shift
        ;;
      --general-model)
        [[ $# -ge 2 ]] || fail "--general-model requer um modelo"
        GENERAL_MODEL="$2"
        shift
        ;;
      --code-model)
        [[ $# -ge 2 ]] || fail "--code-model requer um modelo"
        CODE_MODEL="$2"
        shift
        ;;
      --aider-model)
        [[ $# -ge 2 ]] || fail "--aider-model requer um modelo"
        AIDER_MODEL="$2"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "opção desconhecida: $1"
        ;;
    esac
    shift
  done
}

detect_script_root() {
  local source_path="${BASH_SOURCE[0]:-}"
  local candidate

  if [[ -n "${source_path}" && -f "${source_path}" ]]; then
    candidate="$(cd "$(dirname "${source_path}")" && pwd)"
    if [[ -f "${candidate}/docker-compose.yml" && -f "${candidate}/Makefile" ]]; then
      SCRIPT_ROOT="${candidate}"
      INSTALL_DIR="${candidate}"
    fi
  fi
}

detect_platform() {
  [[ "$(uname -s)" == "Linux" ]] || fail "este instalador suporta Linux e Ubuntu/WSL2"

  if [[ -r /proc/meminfo ]]; then
    SYSTEM_RAM_MB="$(awk '/MemTotal:/ { printf "%d", $2 / 1024 }' /proc/meminfo)"
  fi

  if [[ "${FORCE_CPU}" == false ]] && command -v nvidia-smi >/dev/null 2>&1; then
    if nvidia-smi >/dev/null 2>&1; then
      GPU_VRAM_MB="$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits \
        | awk '{ total += $1 } END { printf "%d", total }')"
      if [[ "${GPU_VRAM_MB}" -gt 0 ]]; then
        GPU_AVAILABLE=true
      fi
    else
      warn "nvidia-smi existe, mas a GPU não respondeu; será usado CPU"
    fi
  fi
}

select_models() {
  local capacity_mb

  if [[ "${GPU_AVAILABLE}" == true ]]; then
    capacity_mb="${GPU_VRAM_MB}"
  else
    capacity_mb="${SYSTEM_RAM_MB}"
  fi

  if [[ -z "${GENERAL_MODEL}" ]]; then
    if [[ "${GPU_AVAILABLE}" == true && "${capacity_mb}" -ge 20480 ]] \
      || [[ "${GPU_AVAILABLE}" == false && "${capacity_mb}" -ge 49152 ]]; then
      GENERAL_MODEL="qwen3.6:27b"
    elif [[ "${GPU_AVAILABLE}" == true && "${capacity_mb}" -ge 7168 ]] \
      || [[ "${GPU_AVAILABLE}" == false && "${capacity_mb}" -ge 24576 ]]; then
      GENERAL_MODEL="qwen3.5:9b"
    elif [[ "${GPU_AVAILABLE}" == true && "${capacity_mb}" -ge 4096 ]] \
      || [[ "${GPU_AVAILABLE}" == false && "${capacity_mb}" -ge 12288 ]]; then
      GENERAL_MODEL="qwen3.5:4b"
    elif [[ "${capacity_mb}" -ge 6144 ]]; then
      GENERAL_MODEL="qwen3.5:2b"
    else
      fail "memória insuficiente; são recomendados ao menos 6 GB de RAM"
    fi
  fi

  if [[ -z "${CODE_MODEL}" ]]; then
    if [[ "${GPU_AVAILABLE}" == true && "${capacity_mb}" -ge 22528 ]] \
      || [[ "${GPU_AVAILABLE}" == false && "${capacity_mb}" -ge 49152 ]]; then
      CODE_MODEL="qwen3-coder:30b"
    elif [[ "${GPU_AVAILABLE}" == true && "${capacity_mb}" -ge 7168 ]] \
      || [[ "${GPU_AVAILABLE}" == false && "${capacity_mb}" -ge 24576 ]]; then
      CODE_MODEL="qwen2.5-coder:7b"
    elif [[ "${GPU_AVAILABLE}" == true && "${capacity_mb}" -ge 4096 ]] \
      || [[ "${GPU_AVAILABLE}" == false && "${capacity_mb}" -ge 12288 ]]; then
      CODE_MODEL="qwen2.5-coder:3b"
    else
      CODE_MODEL="qwen2.5-coder:1.5b"
    fi
  fi

  AIDER_MODEL="${AIDER_MODEL:-${GENERAL_MODEL}}"

  [[ "${GENERAL_MODEL}" =~ ^[A-Za-z0-9._:/-]+$ ]] \
    || fail "identificador de modelo geral inválido: ${GENERAL_MODEL}"
  [[ "${CODE_MODEL}" =~ ^[A-Za-z0-9._:/-]+$ ]] \
    || fail "identificador de modelo de código inválido: ${CODE_MODEL}"
  [[ "${AIDER_MODEL}" =~ ^[A-Za-z0-9._:/-]+$ ]] \
    || fail "identificador de modelo do Aider inválido: ${AIDER_MODEL}"

  case "${GENERAL_MODEL} ${CODE_MODEL}" in
    *qwen3.6*|*qwen3-coder:30b*) REQUIRED_DISK_GB=45 ;;
    *qwen3.5:9b*|*qwen2.5-coder:7b*) REQUIRED_DISK_GB=18 ;;
    *qwen3.5:4b*|*qwen2.5-coder:3b*) REQUIRED_DISK_GB=12 ;;
    *) REQUIRED_DISK_GB=8 ;;
  esac
}

collect_missing_packages() {
  local -n result_ref=$1

  command -v curl >/dev/null 2>&1 || result_ref+=(curl)
  command -v git >/dev/null 2>&1 || result_ref+=(git)
  command -v make >/dev/null 2>&1 || result_ref+=(make)
  command -v python3 >/dev/null 2>&1 || result_ref+=(python3)
  command -v pipx >/dev/null 2>&1 || result_ref+=(pipx)
  command -v mkcert >/dev/null 2>&1 || result_ref+=(mkcert)
  command -v gpg >/dev/null 2>&1 || result_ref+=(gpg)
  command -v certutil >/dev/null 2>&1 || result_ref+=(libnss3-tools)
}

check_docker() {
  command -v docker >/dev/null 2>&1 || fail "Docker não está instalado; instale Docker Engine ou Docker Desktop com integração WSL2"
  docker compose version >/dev/null 2>&1 || fail "Docker Compose v2 não está disponível"
  docker info >/dev/null 2>&1 || fail "não foi possível acessar o daemon Docker; inicie-o e confirme as permissões do usuário"
}

check_network() {
  curl --fail --silent --show-error --head --max-time 15 \
    https://github.com/gut0leao/local-coding-ai >/dev/null \
    || fail "não foi possível acessar o repositório no GitHub"
  curl --fail --silent --show-error --head --max-time 15 \
    https://ollama.com >/dev/null \
    || fail "não foi possível acessar o catálogo do Ollama"
}

port_is_listening() {
  local port="$1"

  command -v ss >/dev/null 2>&1 || return 1
  ss -H -ltn 2>/dev/null | awk '{ print $4 }' | grep -Eq ":${port}$"
}

check_required_ports() {
  local port
  local expected_container

  while read -r port expected_container; do
    if port_is_listening "${port}" \
      && ! docker ps --format '{{.Names}}' | grep -qx "${expected_container}"; then
      fail "a porta local ${port} já está em uso por outro serviço"
    fi
  done <<'EOF'
80 ai-reverse-proxy
443 ai-reverse-proxy
11434 ai-ollama
EOF
}

check_disk_space() {
  local target_parent
  local available_kb
  local required_kb

  target_parent="$(dirname "${INSTALL_DIR}")"
  while [[ ! -d "${target_parent}" && "${target_parent}" != "/" ]]; do
    target_parent="$(dirname "${target_parent}")"
  done

  available_kb="$(df -Pk "${target_parent}" | awk 'NR == 2 { print $4 }')"
  required_kb=$((REQUIRED_DISK_GB * 1024 * 1024))
  if [[ "${available_kb}" -lt "${required_kb}" ]]; then
    fail "espaço insuficiente: são necessários aproximadamente ${REQUIRED_DISK_GB} GB livres"
  fi
}

show_preflight() {
  info "Diagnóstico do ambiente"
  printf 'Sistema:       %s\n' "$(uname -sr)"
  printf 'RAM:           %s MB\n' "${SYSTEM_RAM_MB}"
  if [[ "${GPU_AVAILABLE}" == true ]]; then
    printf 'GPU NVIDIA:    detectada (%s MB de VRAM)\n' "${GPU_VRAM_MB}"
    printf 'Modo:          GPU NVIDIA\n'
  else
    printf 'GPU NVIDIA:    não utilizada\n'
    printf 'Modo:          CPU\n'
  fi
  printf 'Modelo geral:  %s\n' "${GENERAL_MODEL}"
  printf 'Modelo código: %s\n' "${CODE_MODEL}"
  printf 'Modelo Aider:  %s\n' "${AIDER_MODEL}"
  printf 'Disco mínimo:  ~%s GB livres\n' "${REQUIRED_DISK_GB}"
  printf 'Instalação:    %s\n' "${INSTALL_DIR}"
  printf 'Projeto Aider: %s\n' "${PROJECT_DIR}"
}

install_base_packages() {
  local missing_packages=("$@")

  [[ ${#missing_packages[@]} -gt 0 ]] || return 0
  command -v apt-get >/dev/null 2>&1 \
    || fail "pacotes ausentes (${missing_packages[*]}) e gerenciador apt-get indisponível"
  command -v sudo >/dev/null 2>&1 || fail "sudo é necessário para instalar: ${missing_packages[*]}"

  confirm "Instalar os pacotes ausentes: ${missing_packages[*]}?" \
    || fail "instalação cancelada"

  sudo apt-get update
  sudo apt-get install -y "${missing_packages[@]}"
}

test_or_configure_gpu() {
  local docker_os

  [[ "${GPU_AVAILABLE}" == true ]] || return 0

  info "Validando acesso da GPU pelo Docker"
  if docker run --rm --gpus all ubuntu:24.04 nvidia-smi >/dev/null 2>&1; then
    success "Docker acessa a GPU NVIDIA"
    return 0
  fi

  docker_os="$(docker info --format '{{.OperatingSystem}}' 2>/dev/null || true)"
  if [[ "${docker_os}" == *"Docker Desktop"* ]]; then
    fail "Docker Desktop não acessou a GPU; verifique WSL Integration e o driver NVIDIA no Windows"
  fi

  command -v apt-get >/dev/null 2>&1 \
    || fail "NVIDIA Container Toolkit ausente e apt-get indisponível"
  command -v sudo >/dev/null 2>&1 || fail "sudo é necessário para configurar o runtime NVIDIA"

  confirm "Instalar e configurar o NVIDIA Container Toolkit?" \
    || fail "a GPU não pode ser habilitada sem o NVIDIA Container Toolkit"

  local key_file
  key_file="$(mktemp)"

  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | gpg --dearmor >"${key_file}"
  sudo install -m 0644 "${key_file}" /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y nvidia-container-toolkit
  sudo nvidia-ctk runtime configure --runtime=docker
  rm -f "${key_file}"

  if command -v systemctl >/dev/null 2>&1 && systemctl is-active docker >/dev/null 2>&1; then
    sudo systemctl restart docker
  else
    sudo service docker restart
  fi

  docker run --rm --gpus all ubuntu:24.04 nvidia-smi >/dev/null 2>&1 \
    || fail "a GPU continua indisponível no Docker após configurar o toolkit"
  success "runtime NVIDIA configurado"
}

prepare_repository() {
  if [[ -n "${SCRIPT_ROOT}" ]]; then
    INSTALL_DIR="${SCRIPT_ROOT}"
    success "usando checkout local em ${INSTALL_DIR}"
    return 0
  fi

  if [[ -d "${INSTALL_DIR}/.git" ]]; then
    if [[ -n "$(git -C "${INSTALL_DIR}" status --porcelain)" ]]; then
      fail "o checkout em ${INSTALL_DIR} possui alterações locais; revise-as antes de atualizar"
    fi
    info "Atualizando checkout existente"
    git -C "${INSTALL_DIR}" pull --ff-only
  elif [[ -e "${INSTALL_DIR}" ]]; then
    fail "${INSTALL_DIR} já existe, mas não é um checkout deste projeto"
  else
    info "Clonando local-coding-ai"
    mkdir -p "$(dirname "${INSTALL_DIR}")"
    git clone --depth 1 "${REPOSITORY_URL}" "${INSTALL_DIR}"
  fi
}

set_env_value() {
  local env_file="$1"
  local key="$2"
  local value="$3"

  if grep -q "^${key}=" "${env_file}"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "${env_file}"
  else
    printf '\n%s=%s\n' "${key}" "${value}" >>"${env_file}"
  fi
}

configure_environment() {
  local env_file="${INSTALL_DIR}/.env"

  if [[ ! -f "${env_file}" ]]; then
    cp "${INSTALL_DIR}/.env.example" "${env_file}"
  fi

  set_env_value "${env_file}" OLLAMA_MODEL_DEFAULT "${GENERAL_MODEL}"
  set_env_value "${env_file}" OLLAMA_CODE_MODEL_DEFAULT "${CODE_MODEL}"
  set_env_value "${env_file}" OLLAMA_AIDER_MODEL_DEFAULT "${AIDER_MODEL}"
  if [[ "${GPU_AVAILABLE}" == true ]]; then
    set_env_value "${env_file}" LOCAL_AI_RUNTIME "gpu"
  else
    set_env_value "${env_file}" LOCAL_AI_RUNTIME "cpu"
  fi
  set_env_value "${env_file}" AI_HOSTNAME "ai.localhost"
  success "configuração gravada em ${env_file}"
}

install_ai_command() {
  local config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/local-coding-ai"

  mkdir -p "${HOME}/.local/bin" "${config_dir}"
  install -m 0755 "${INSTALL_DIR}/bin/ai.localhost" "${AI_COMMAND_PATH}"
  printf '%s\n' "${INSTALL_DIR}" >"${config_dir}/stack-dir"
  export PATH="${HOME}/.local/bin:${PATH}"
  success "comando ai.localhost instalado em ${AI_COMMAND_PATH}"
}

install_aider() {
  info "Instalando Aider no ambiente do usuário"
  pipx ensurepath >/dev/null
  export PATH="${HOME}/.local/bin:${PATH}"

  if command -v aider >/dev/null 2>&1; then
    success "Aider já está instalado; preservando a instalação atual"
  else
    pipx install aider-chat
  fi

  command -v aider >/dev/null 2>&1 || fail "Aider foi instalado, mas não foi encontrado no PATH"
  success "$(aider --version | head -n 1)"
}

configure_https() {
  info "Configurando certificado HTTPS local"
  make -C "${INSTALL_DIR}" setup-https
}

start_stack() {
  local attempt

  info "Iniciando a stack local"
  if [[ "${GPU_AVAILABLE}" == true ]]; then
    make -C "${INSTALL_DIR}" up-gpu
  else
    make -C "${INSTALL_DIR}" up
  fi

  for attempt in $(seq 1 30); do
    if make -C "${INSTALL_DIR}" test-ollama >/dev/null 2>&1 \
      && make -C "${INSTALL_DIR}" test-open-webui >/dev/null 2>&1; then
      success "Ollama e Open WebUI responderam corretamente"
      return 0
    fi
    sleep 2
  done

  make -C "${INSTALL_DIR}" test-ollama || true
  make -C "${INSTALL_DIR}" test-open-webui || true
  fail "a stack não ficou pronta dentro do tempo esperado; consulte make -C \"${INSTALL_DIR}\" logs"
}

download_models() {
  info "Baixando modelo Qwen geral: ${GENERAL_MODEL}"
  make -C "${INSTALL_DIR}" pull-model MODEL="${GENERAL_MODEL}"

  if [[ "${CODE_MODEL}" != "${GENERAL_MODEL}" ]]; then
    info "Baixando modelo Qwen para código: ${CODE_MODEL}"
    make -C "${INSTALL_DIR}" pull-model MODEL="${CODE_MODEL}"
  fi

  if [[ "${AIDER_MODEL}" != "${GENERAL_MODEL}" && "${AIDER_MODEL}" != "${CODE_MODEL}" ]]; then
    info "Baixando modelo adicional configurado para o Aider: ${AIDER_MODEL}"
    make -C "${INSTALL_DIR}" pull-model MODEL="${AIDER_MODEL}"
  fi
}

show_handoff() {
  cat <<EOF

============================================================
Ambiente local de IA pronto
============================================================

Open WebUI:  https://ai.localhost
Ollama API:  http://localhost:11434
Modelo geral: ${GENERAL_MODEL}
Modelo Aider: ${AIDER_MODEL}
Stack:        ${INSTALL_DIR}

Comandos úteis:
  Abrir o Aider no repositório atual:
    ai.localhost

  Abrir com o modelo especializado em código:
    ai.localhost --code

  Abrir diretamente outro repositório:
    ai.localhost --project /caminho/do/projeto

  Baixar outro modelo:
    make -C "${INSTALL_DIR}" pull-model MODEL=<modelo>

  Listar modelos:
    make -C "${INSTALL_DIR}" models

  Ver containers:
    make -C "${INSTALL_DIR}" ps

  Ver logs:
    make -C "${INSTALL_DIR}" logs

  Testar o ambiente:
    make -C "${INSTALL_DIR}" test-ollama
    make -C "${INSTALL_DIR}" test-open-webui

  Reiniciar com GPU:
    make -C "${INSTALL_DIR}" restart-gpu

  Parar o ambiente:
    make -C "${INSTALL_DIR}" down

O Aider será aberto somente dentro de um repositório Git escolhido por você.
============================================================
EOF
}

resolve_aider_project() {
  local chosen_path

  if git -C "${PROJECT_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    PROJECT_DIR="$(cd "${PROJECT_DIR}" && pwd)"
    return 0
  fi

  if [[ "${LAUNCH_AIDER}" == false ]]; then
    return 1
  fi

  if [[ ! -r /dev/tty ]]; then
    warn "${PROJECT_DIR} não é um repositório Git; o Aider não será aberto"
    return 1
  fi

  printf 'Caminho do repositório Git para abrir no Aider (vazio para não abrir): ' >/dev/tty
  read -r chosen_path </dev/tty || true
  [[ -n "${chosen_path}" ]] || return 1
  [[ -d "${chosen_path}" ]] || fail "diretório não encontrado: ${chosen_path}"
  git -C "${chosen_path}" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || fail "o caminho informado não é um repositório Git: ${chosen_path}"
  PROJECT_DIR="$(cd "${chosen_path}" && pwd)"
}

launch_aider() {
  [[ "${LAUNCH_AIDER}" == true ]] || return 0
  resolve_aider_project || return 0
  confirm "Abrir o Aider agora em ${PROJECT_DIR}?" || return 0

  info "Abrindo Aider com ${AIDER_MODEL}"
  exec "${AI_COMMAND_PATH}" --project "${PROJECT_DIR}"
}

main() {
  local missing_packages=()

  parse_args "$@"
  detect_script_root
  detect_platform
  select_models
  collect_missing_packages missing_packages
  show_preflight

  if [[ ${#missing_packages[@]} -gt 0 ]]; then
    printf 'Pacotes ausentes: %s\n' "${missing_packages[*]}"
  else
    success "dependências básicas encontradas"
  fi

  check_disk_space

  if [[ "${CHECK_ONLY}" == true ]]; then
    if command -v docker >/dev/null 2>&1 \
      && docker compose version >/dev/null 2>&1 \
      && docker info >/dev/null 2>&1; then
      success "Docker, Compose e daemon disponíveis"
      check_required_ports
      check_network
      success "GitHub e catálogo do Ollama acessíveis"
    else
      warn "Docker, Compose ou daemon indisponível"
      exit 1
    fi
    [[ ${#missing_packages[@]} -eq 0 ]] || exit 1
    exit 0
  fi

  install_base_packages "${missing_packages[@]}"
  check_docker
  check_required_ports
  check_network

  info "Todas as verificações concluídas antes dos downloads principais"
  confirm "Continuar com configuração, imagens Docker e modelos (~${REQUIRED_DISK_GB} GB)?" \
    || fail "instalação cancelada"

  test_or_configure_gpu
  prepare_repository
  configure_environment
  install_aider
  configure_https
  start_stack
  download_models
  install_ai_command
  show_handoff
  launch_aider
}

main "$@"
