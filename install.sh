#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_URL="https://github.com/gut0leao/localhost.ai.git"
LEGACY_REPOSITORY_URL="https://github.com/gut0leao/ai.localhost.git"
OLDER_LEGACY_REPOSITORY_URL="https://github.com/gut0leao/local-coding-ai.git"
RAW_INSTALLER_URL="https://raw.githubusercontent.com/gut0leao/localhost.ai/main/install.sh"
DEFAULT_INSTALL_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/localhost-ai"
STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/localhost-ai"
LEGACY_STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/local-coding-ai"
INSTALL_DIR="${LOCALHOST_AI_INSTALL_DIR:-${LOCAL_AI_INSTALL_DIR:-${DEFAULT_INSTALL_DIR}}}"
PROJECT_DIR="${LOCALHOST_AI_PROJECT_DIR:-${LOCAL_AI_PROJECT_DIR:-${AIDER_PROJECT_DIR:-${PWD}}}}"
GENERAL_MODEL="${LOCALHOST_AI_GENERAL_MODEL:-${LOCAL_AI_GENERAL_MODEL:-}}"
CODE_MODEL="${LOCALHOST_AI_CODE_MODEL:-${LOCAL_AI_CODE_MODEL:-}}"
AIDER_MODEL="${LOCALHOST_AI_AIDER_MODEL:-${LOCAL_AI_AIDER_MODEL:-}}"
OPENCODE_MODEL="${LOCALHOST_AI_OPENCODE_MODEL:-${LOCAL_AI_OPENCODE_MODEL:-}}"
AI_COMMAND_PATH="${HOME}/.local/bin/localhost.ai"
OPENCODE_BINARY_PATH="${HOME}/.opencode/bin/opencode"
OPENCODE_COMMAND_PATH="${HOME}/.local/bin/opencode"
OPENCODE_CONFIG_PATH="${XDG_CONFIG_HOME:-${HOME}/.config}/opencode/opencode.json"
ASSUME_YES=false
CHECK_ONLY=false
FORCE_CPU=false
LAUNCH_CLIENT=""
GPU_AVAILABLE=false
GPU_VRAM_MB=0
SYSTEM_RAM_MB=0
REQUIRED_DISK_GB=0
SCRIPT_ROOT=""
USER_BIN_WAS_ON_PATH=false
case ":${PATH}:" in
  *":${HOME}/.local/bin:"*) USER_BIN_WAS_ON_PATH=true ;;
esac

state_mark() {
  mkdir -p "${STATE_DIR}"
  touch "${STATE_DIR}/$1"
}

state_append_unique() {
  local file="${STATE_DIR}/$1"
  local value="$2"

  mkdir -p "${STATE_DIR}"
  touch "${file}"
  grep -Fqx -- "${value}" "${file}" || printf '%s\n' "${value}" >>"${file}"
}

init_install_state() {
  local recorded_install_dir

  mkdir -p "${STATE_DIR}"
  chmod 0700 "${STATE_DIR}"
  if [[ -r "${STATE_DIR}/install-dir" ]]; then
    IFS= read -r recorded_install_dir <"${STATE_DIR}/install-dir"
    if [[ "$(realpath -m "${recorded_install_dir}")" != "$(realpath -m "${INSTALL_DIR}")" ]]; then
      fail "já existe uma instalação registrada em ${recorded_install_dir} no manifesto ${STATE_DIR}; execute o desinstalador ou remova esse manifesto antes de usar outro --install-dir"
    fi
  fi
  printf '1\n' >"${STATE_DIR}/format-version"
  printf '%s\n' "${INSTALL_DIR}" >"${STATE_DIR}/install-dir"
}

reuse_legacy_installation() {
  local legacy_install_dir

  [[ -z "${SCRIPT_ROOT}" ]] || return 0
  [[ "${INSTALL_DIR}" == "${DEFAULT_INSTALL_DIR}" ]] || return 0
  [[ -r "${LEGACY_STATE_DIR}/format-version" && -r "${LEGACY_STATE_DIR}/install-dir" ]] || return 0

  IFS= read -r legacy_install_dir <"${LEGACY_STATE_DIR}/install-dir"
  [[ -n "${legacy_install_dir}" ]] || return 0
  STATE_DIR="${LEGACY_STATE_DIR}"
  INSTALL_DIR="${legacy_install_dir}"
  warn "reutilizando instalação anterior em ${INSTALL_DIR}; os diretórios legados serão preservados"
}

record_new_apt_packages() {
  local before_file="$1"
  local after_file
  local package

  after_file="$(mktemp)"
  dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}\n' 2>/dev/null \
    | awk '$1 ~ /^ii/ { print $2 }' | sort -u >"${after_file}"
  while IFS= read -r package; do
    [[ -n "${package}" ]] && state_append_unique apt-packages "${package}"
  done < <(comm -13 "${before_file}" "${after_file}")
  rm -f "${after_file}"
}

backup_system_file_once() {
  local source_file="$1"
  local state_name="$2"
  local metadata="${STATE_DIR}/system-${state_name}.recorded"

  [[ ! -e "${metadata}" ]] || return 0
  if sudo test -e "${source_file}"; then
    sudo cp -a "${source_file}" "${STATE_DIR}/system-${state_name}.backup"
    state_mark "system-${state_name}.existed"
  else
    state_mark "system-${state_name}.absent"
  fi
  state_mark "system-${state_name}.recorded"
}

backup_user_file_once() {
  local source_file="$1"
  local state_name="$2"

  [[ ! -e "${STATE_DIR}/${state_name}.recorded" ]] || return 0
  if [[ -e "${source_file}" ]]; then
    cp -a "${source_file}" "${STATE_DIR}/${state_name}.backup"
    state_mark "${state_name}.existed"
  else
    state_mark "${state_name}.absent"
  fi
  state_mark "${state_name}.recorded"
}

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
Instalador do localhost.ai

Uso local:
  ./install.sh [opções]

Uso remoto:
  curl -fsSL ${RAW_INSTALLER_URL} | bash -s -- [opções]

Opções:
  --check-only           Verifica o ambiente sem instalar ou baixar arquivos.
  --yes                  Aceita as confirmações automaticamente.
  --cpu                  Ignora GPU e configura execução em CPU.
  --no-launch            Instala sem abrir um assistente ao final (padrão).
  --launch-aider         Ao final, oferece abrir o Aider no repositório informado.
  --launch-opencode      Ao final, oferece abrir o OpenCode no repositório informado.
  --install-dir CAMINHO  Diretório da stack (padrão: ${DEFAULT_INSTALL_DIR}).
  --project-dir CAMINHO  Repositório que o assistente escolhido abrirá (padrão: diretório atual).
  --general-model MODELO Sobrescreve o modelo Qwen geral escolhido automaticamente.
  --code-model MODELO    Sobrescreve o modelo Qwen de código escolhido automaticamente.
  --aider-model MODELO   Sobrescreve o modelo usado para abrir o Aider.
  --opencode-model MODELO Sobrescreve o modelo usado para abrir o OpenCode.
  -h, --help             Exibe esta ajuda.

As mesmas opções de modelos podem ser definidas por LOCALHOST_AI_GENERAL_MODEL,
LOCALHOST_AI_CODE_MODEL, LOCALHOST_AI_AIDER_MODEL e LOCALHOST_AI_OPENCODE_MODEL.
LOCALHOST_AI_INSTALL_DIR e LOCALHOST_AI_PROJECT_DIR também são aceitas. As variáveis
LOCAL_AI_* e AIDER_PROJECT_DIR permanecem compatíveis com instalações anteriores.
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
        LAUNCH_CLIENT=""
        ;;
      --launch-aider)
        LAUNCH_CLIENT="aider"
        ;;
      --launch-opencode)
        LAUNCH_CLIENT="opencode"
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
      --opencode-model)
        [[ $# -ge 2 ]] || fail "--opencode-model requer um modelo"
        OPENCODE_MODEL="$2"
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

  AIDER_MODEL="${AIDER_MODEL:-${CODE_MODEL}}"
  OPENCODE_MODEL="${OPENCODE_MODEL:-${CODE_MODEL}}"

  [[ "${GENERAL_MODEL}" =~ ^[A-Za-z0-9._:/-]+$ ]] \
    || fail "identificador de modelo geral inválido: ${GENERAL_MODEL}"
  [[ "${CODE_MODEL}" =~ ^[A-Za-z0-9._:/-]+$ ]] \
    || fail "identificador de modelo de código inválido: ${CODE_MODEL}"
  [[ "${AIDER_MODEL}" =~ ^[A-Za-z0-9._:/-]+$ ]] \
    || fail "identificador de modelo do Aider inválido: ${AIDER_MODEL}"
  [[ "${OPENCODE_MODEL}" =~ ^[A-Za-z0-9._:/-]+$ ]] \
    || fail "identificador de modelo do OpenCode inválido: ${OPENCODE_MODEL}"

  case "${GENERAL_MODEL} ${CODE_MODEL} ${AIDER_MODEL} ${OPENCODE_MODEL}" in
    *qwen3.6*|*qwen3-coder:30b*) REQUIRED_DISK_GB=45 ;;
    *qwen3.5:9b*|*qwen2.5-coder:7b*) REQUIRED_DISK_GB=18 ;;
    *qwen3.5:4b*|*qwen2.5-coder:3b*) REQUIRED_DISK_GB=12 ;;
    *) REQUIRED_DISK_GB=8 ;;
  esac
}

collect_missing_packages() {
  local -n result_ref=$1

  command -v curl >/dev/null 2>&1 || result_ref+=(curl)
  command -v tar >/dev/null 2>&1 || result_ref+=(tar)
  command -v git >/dev/null 2>&1 || result_ref+=(git)
  command -v make >/dev/null 2>&1 || result_ref+=(make)
  command -v python3 >/dev/null 2>&1 || result_ref+=(python3)
  command -v pipx >/dev/null 2>&1 || result_ref+=(pipx)
  command -v mkcert >/dev/null 2>&1 || result_ref+=(mkcert)
  command -v openssl >/dev/null 2>&1 || result_ref+=(openssl)
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
    https://github.com/gut0leao/localhost.ai >/dev/null \
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
      && ! docker ps --format '{{.Names}}' | grep -Eq "^(${expected_container})$"; then
      fail "a porta local ${port} já está em uso por outro serviço"
    fi
  done <<'EOF'
80 localhost-ai-reverse-proxy|ai-reverse-proxy
443 localhost-ai-reverse-proxy|ai-reverse-proxy
11434 localhost-ai-ollama|ai-ollama
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
  printf 'Modelo OpenCode: %s\n' "${OPENCODE_MODEL}"
  printf 'Disco mínimo:  ~%s GB livres\n' "${REQUIRED_DISK_GB}"
  printf 'Instalação:    %s\n' "${INSTALL_DIR}"
  printf 'Projeto assistente: %s\n' "${PROJECT_DIR}"
}

install_base_packages() {
  local missing_packages=("$@")
  local package
  local packages_before

  [[ ${#missing_packages[@]} -gt 0 ]] || return 0
  command -v apt-get >/dev/null 2>&1 \
    || fail "pacotes ausentes (${missing_packages[*]}) e gerenciador apt-get indisponível"
  command -v sudo >/dev/null 2>&1 || fail "sudo é necessário para instalar: ${missing_packages[*]}"

  confirm "Instalar os pacotes ausentes: ${missing_packages[*]}?" \
    || fail "instalação cancelada"

  packages_before="$(mktemp)"
  dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}\n' 2>/dev/null \
    | awk '$1 ~ /^ii/ { print $2 }' | sort -u >"${packages_before}"
  for package in "${missing_packages[@]}"; do
    state_append_unique apt-packages "${package}"
  done
  sudo apt-get update
  sudo apt-get install -y "${missing_packages[@]}"
  record_new_apt_packages "${packages_before}"
  rm -f "${packages_before}"
}

test_or_configure_gpu() {
  local docker_os
  local packages_before

  [[ "${GPU_AVAILABLE}" == true ]] || return 0

  info "Validando acesso da GPU pelo Docker"
  if ! docker image inspect ubuntu:24.04 >/dev/null 2>&1; then
    state_append_unique docker-images ubuntu:24.04
  fi
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

  backup_system_file_once /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg nvidia-keyring
  backup_system_file_once /etc/apt/sources.list.d/nvidia-container-toolkit.list nvidia-list
  backup_system_file_once /etc/docker/daemon.json docker-daemon

  local key_file
  key_file="$(mktemp)"

  packages_before="$(mktemp)"
  dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}\n' 2>/dev/null \
    | awk '$1 ~ /^ii/ { print $2 }' | sort -u >"${packages_before}"
  state_append_unique apt-packages nvidia-container-toolkit

  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | gpg --dearmor >"${key_file}"
  sudo install -m 0644 "${key_file}" /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y nvidia-container-toolkit
  sudo nvidia-ctk runtime configure --runtime=docker
  record_new_apt_packages "${packages_before}"
  rm -f "${packages_before}"
  state_mark nvidia-runtime-configured
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
    case "$(git -C "${INSTALL_DIR}" remote get-url origin 2>/dev/null || true)" in
      "${REPOSITORY_URL}"|"${LEGACY_REPOSITORY_URL}"|"${OLDER_LEGACY_REPOSITORY_URL}"|git@github.com:gut0leao/localhost.ai.git|git@github.com:gut0leao/ai.localhost.git|git@github.com:gut0leao/local-coding-ai.git) ;;
      *) fail "o checkout em ${INSTALL_DIR} não pertence ao projeto localhost.ai" ;;
    esac
    if [[ -n "$(git -C "${INSTALL_DIR}" status --porcelain)" ]]; then
      fail "o checkout em ${INSTALL_DIR} possui alterações locais; revise-as antes de atualizar"
    fi
    info "Atualizando checkout existente"
    if [[ ! -e "${STATE_DIR}/checkout-previous-head" ]]; then
      git -C "${INSTALL_DIR}" rev-parse HEAD >"${STATE_DIR}/checkout-previous-head"
    fi
    git -C "${INSTALL_DIR}" pull --ff-only
    git -C "${INSTALL_DIR}" rev-parse HEAD >"${STATE_DIR}/checkout-installed-head"
  elif [[ -e "${INSTALL_DIR}" ]]; then
    fail "${INSTALL_DIR} já existe, mas não é um checkout deste projeto"
  else
    info "Clonando localhost.ai"
    mkdir -p "$(dirname "${INSTALL_DIR}")"
    git clone --depth 1 "${REPOSITORY_URL}" "${INSTALL_DIR}"
    state_mark checkout-created
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

  backup_user_file_once "${env_file}" environment
  if [[ ! -f "${env_file}" ]]; then
    cp "${INSTALL_DIR}/.env.example" "${env_file}"
  fi

  set_env_value "${env_file}" OLLAMA_MODEL_DEFAULT "${GENERAL_MODEL}"
  set_env_value "${env_file}" OLLAMA_CODE_MODEL_DEFAULT "${CODE_MODEL}"
  set_env_value "${env_file}" OLLAMA_AIDER_MODEL_DEFAULT "${AIDER_MODEL}"
  set_env_value "${env_file}" OLLAMA_OPENCODE_MODEL_DEFAULT "${OPENCODE_MODEL}"
  set_env_value "${env_file}" LOCALHOST_AI_CA_BUNDLE "/etc/ssl/certs/ca-certificates.crt"
  set_env_value "${env_file}" SEARXNG_QUERY_URL "'http://searxng:8080/search?q=<query>'"
  if [[ "${GPU_AVAILABLE}" == true ]]; then
    set_env_value "${env_file}" LOCALHOST_AI_RUNTIME "gpu"
  else
    set_env_value "${env_file}" LOCALHOST_AI_RUNTIME "cpu"
  fi
  set_env_value "${env_file}" LOCALHOST_AI_HOSTNAME "ai.localhost"
  success "configuração gravada em ${env_file}"
}

install_ai_command() {
  local config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/localhost-ai"
  local stack_dir_file="${config_dir}/stack-dir"

  mkdir -p "${HOME}/.local/bin" "${config_dir}"
  printf '%s\n' "${AI_COMMAND_PATH}" >"${STATE_DIR}/launcher-path"
  printf '%s\n' "${stack_dir_file}" >"${STATE_DIR}/stack-dir-config-path"
  backup_user_file_once "${AI_COMMAND_PATH}" launcher
  backup_user_file_once "${stack_dir_file}" stack-dir-config
  install -m 0755 "${INSTALL_DIR}/bin/localhost.ai" "${AI_COMMAND_PATH}"
  printf '%s\n' "${INSTALL_DIR}" >"${stack_dir_file}"
  export PATH="${HOME}/.local/bin:${PATH}"
  ensure_user_bin_path
  success "comando localhost.ai instalado em ${AI_COMMAND_PATH}"
}

install_integrated_assistant_commands() {
  local shell_config
  local marker_start="# >>> localhost-ai assistants >>>"

  case "$(basename "${SHELL:-bash}")" in
    zsh) shell_config="${HOME}/.zshrc" ;;
    *) shell_config="${HOME}/.bashrc" ;;
  esac

  if [[ -f "${shell_config}" ]] && grep -Fqx "${marker_start}" "${shell_config}"; then
    return 0
  fi
  if [[ ! -e "${shell_config}" ]]; then
    state_append_unique assistant-command-created-files "${shell_config}"
  fi
  {
    printf '\n%s\n' "${marker_start}"
    printf '%s\n' '# Integra os comandos interativos ao Ollama local e à stack localhost.ai.'
    printf '%s\n' 'aider() {'
    printf '%s\n' '  case "${1:-}" in'
    printf '%s\n' '    -h|--help|-v|--version) command aider "$@" ;;'
    printf '%s\n' '    *) command localhost.ai --aider "$@" ;;'
    printf '%s\n' '  esac'
    printf '%s\n' '}'
    printf '%s\n' 'opencode() {'
    printf '%s\n' '  case "${1:-}" in'
    printf '%s\n' '    -h|--help|-v|--version|models|agent|providers|upgrade|uninstall|completion|mcp|debug) command opencode "$@" ;;'
    printf '%s\n' '    *) command localhost.ai --opencode "$@" ;;'
    printf '%s\n' '  esac'
    printf '%s\n' '}'
    printf '%s\n' '# <<< localhost-ai assistants <<<'
  } >>"${shell_config}"
  state_append_unique assistant-command-files "${shell_config}"
  success "comandos aider e opencode integrados ao shell ${shell_config}"
}

ensure_user_bin_path() {
  local shell_config
  local marker_start="# >>> localhost-ai PATH >>>"

  [[ "${USER_BIN_WAS_ON_PATH}" == false ]] || return 0

  case "$(basename "${SHELL:-bash}")" in
    zsh) shell_config="${HOME}/.zshrc" ;;
    *) shell_config="${HOME}/.bashrc" ;;
  esac

  if [[ -f "${shell_config}" ]] && grep -Fqx "${marker_start}" "${shell_config}"; then
    return 0
  fi
  if [[ ! -e "${shell_config}" ]]; then
    state_append_unique path-created-files "${shell_config}"
  fi
  {
    printf '\n%s\n' "${marker_start}"
    printf '%s\n' 'export PATH="$HOME/.local/bin:$PATH"'
    printf '%s\n' '# <<< localhost-ai PATH <<<'
  } >>"${shell_config}"
  state_append_unique path-files "${shell_config}"
}

install_aider() {
  info "Instalando Aider no ambiente do usuário"
  export PATH="${HOME}/.local/bin:${PATH}"

  if command -v aider >/dev/null 2>&1; then
    success "Aider já está instalado; preservando a instalação atual"
  else
    [[ -e "${HOME}/.local/share/pipx" ]] || state_mark pipx-share-created
    [[ -e "${HOME}/.local/pipx" ]] || state_mark pipx-legacy-home-created
    [[ -e "${HOME}/.cache/pipx" ]] || state_mark pipx-cache-created
    [[ -e "${HOME}/.local/state/pipx" ]] || state_mark pipx-state-created
    pipx install aider-chat
    state_mark aider-installed
  fi

  command -v aider >/dev/null 2>&1 || fail "Aider foi instalado, mas não foi encontrado no PATH"
  success "$(aider --version | head -n 1)"
}

install_opencode_configuration() {
  local config_dir
  local temporary_config

  config_dir="$(dirname "${OPENCODE_CONFIG_PATH}")"
  if [[ -e "${OPENCODE_CONFIG_PATH}" ]]; then
    success "configuração existente do OpenCode preservada em ${OPENCODE_CONFIG_PATH}"
    return 0
  fi

  [[ -d "${config_dir}" ]] || state_mark opencode-config-dir-created
  mkdir -p "${config_dir}"
  backup_user_file_once "${OPENCODE_CONFIG_PATH}" opencode-config
  temporary_config="$(mktemp)"
  sed \
    -e "s|__OPENCODE_BUILD_MODEL__|${OPENCODE_MODEL}|g" \
    -e "s|__OPENCODE_PLAN_MODEL__|${GENERAL_MODEL}|g" \
    "${INSTALL_DIR}/opencode/opencode.json" >"${temporary_config}"
  install -m 0600 "${temporary_config}" "${OPENCODE_CONFIG_PATH}"
  rm -f "${temporary_config}"
  success "OpenCode configurado: Build usa ${OPENCODE_MODEL}; Plan usa ${GENERAL_MODEL}"
}

install_opencode() {
  info "Instalando OpenCode no ambiente do usuário"
  export PATH="${HOME}/.local/bin:${HOME}/.opencode/bin:${PATH}"

  if command -v opencode >/dev/null 2>&1 \
    && opencode --version >/dev/null 2>&1; then
    success "OpenCode já está instalado; preservando a instalação atual"
    success "$(opencode --version | head -n 1)"
    install_opencode_configuration
    return 0
  fi

  if command -v opencode >/dev/null 2>&1; then
    warn "o comando OpenCode encontrado no PATH não funciona neste Linux/WSL; instalando a versão nativa"
  fi

  if [[ ! -x "${OPENCODE_BINARY_PATH}" ]]; then
    backup_user_file_once "${OPENCODE_BINARY_PATH}" opencode-binary
    curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path
    state_mark opencode-installed
  fi

  [[ -x "${OPENCODE_BINARY_PATH}" ]] \
    || fail "OpenCode foi instalado, mas não foi encontrado em ${OPENCODE_BINARY_PATH}"

  mkdir -p "${HOME}/.local/bin"
  if [[ ! -e "${OPENCODE_COMMAND_PATH}" && ! -L "${OPENCODE_COMMAND_PATH}" ]]; then
    backup_user_file_once "${OPENCODE_COMMAND_PATH}" opencode-command
    ln -s "${OPENCODE_BINARY_PATH}" "${OPENCODE_COMMAND_PATH}"
  elif [[ "$(readlink -f "${OPENCODE_COMMAND_PATH}" 2>/dev/null || true)" != "${OPENCODE_BINARY_PATH}" ]]; then
    fail "já existe um comando OpenCode não gerenciado em ${OPENCODE_COMMAND_PATH}"
  fi
  [[ -x "${OPENCODE_COMMAND_PATH}" ]] \
    || fail "não foi possível disponibilizar o comando OpenCode em ${OPENCODE_COMMAND_PATH}"

  install_opencode_configuration
  success "$(opencode --version | head -n 1)"
}

record_compose_images() {
  local image

  while IFS= read -r image; do
    [[ -n "${image}" ]] || continue
    if ! docker image inspect "${image}" >/dev/null 2>&1; then
      state_append_unique docker-images "${image}"
    fi
  done < <(docker compose -f "${INSTALL_DIR}/docker-compose.yml" config --images | sort -u)
}

configure_https() {
  info "Configurando certificado HTTPS local"
  backup_user_file_once "${INSTALL_DIR}/certs/local-ai.pem" certificate
  backup_user_file_once "${INSTALL_DIR}/certs/local-ai-key.pem" certificate-key
  STATE_DIR="${STATE_DIR}" make -C "${INSTALL_DIR}" setup-https
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

  if [[ "${OPENCODE_MODEL}" != "${GENERAL_MODEL}" \
    && "${OPENCODE_MODEL}" != "${CODE_MODEL}" \
    && "${OPENCODE_MODEL}" != "${AIDER_MODEL}" ]]; then
    info "Baixando modelo adicional configurado para o OpenCode: ${OPENCODE_MODEL}"
    make -C "${INSTALL_DIR}" pull-model MODEL="${OPENCODE_MODEL}"
  fi
}

show_handoff() {
  local bold=""
  local cyan=""
  local dim=""
  local green=""
  local reset=""

  if [[ -t 1 ]]; then
    bold=$'\033[1m'
    cyan=$'\033[36m'
    dim=$'\033[2m'
    green=$'\033[32m'
    reset=$'\033[0m'
  fi

  printf '\n%s%s✓ Ambiente local de IA pronto%s\n' "${bold}" "${green}" "${reset}"
  printf '  %sWeb%s      https://ai.localhost\n' "${cyan}" "${reset}"
  printf '  %sModelos%s  chat: %s  código: %s\n' "${cyan}" "${reset}" "${GENERAL_MODEL}" "${CODE_MODEL}"
  printf '\n%sNo repositório:%s\n' "${bold}" "${reset}"
  printf '  %saider%s     %s# edição, conversa e arquiteto%s\n' "${green}" "${reset}" "${dim}" "${reset}"
  printf '  %sopencode%s  %s# Build; Tab alterna para Plan%s\n' "${green}" "${reset}" "${dim}" "${reset}"
  printf '\n%sGerenciar:%s  make -C "%s" {models,logs,ps,down}\n' \
    "${bold}" "${reset}" "${INSTALL_DIR}"
}

resolve_launch_project() {
  local chosen_path

  if git -C "${PROJECT_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    PROJECT_DIR="$(cd "${PROJECT_DIR}" && pwd)"
    return 0
  fi

  if [[ -z "${LAUNCH_CLIENT}" ]]; then
    return 1
  fi

  if [[ ! -r /dev/tty ]]; then
    warn "${PROJECT_DIR} não é um repositório Git; nenhum assistente será aberto"
    return 1
  fi

  printf 'Caminho do repositório Git para abrir o %s (vazio para não abrir): ' "${LAUNCH_CLIENT}" >/dev/tty
  read -r chosen_path </dev/tty || true
  [[ -n "${chosen_path}" ]] || return 1
  [[ -d "${chosen_path}" ]] || fail "diretório não encontrado: ${chosen_path}"
  git -C "${chosen_path}" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || fail "o caminho informado não é um repositório Git: ${chosen_path}"
  PROJECT_DIR="$(cd "${chosen_path}" && pwd)"
}

launch_assistant() {
  [[ -n "${LAUNCH_CLIENT}" ]] || return 0
  resolve_launch_project || return 0
  confirm "Abrir o ${LAUNCH_CLIENT} agora em ${PROJECT_DIR}?" || return 0

  info "Abrindo ${LAUNCH_CLIENT}"
  exec "${AI_COMMAND_PATH}" "--${LAUNCH_CLIENT}" --project "${PROJECT_DIR}"
}

main() {
  local missing_packages=()

  parse_args "$@"
  detect_script_root
  reuse_legacy_installation
  if [[ -n "${SCRIPT_ROOT}" ]]; then
    INSTALL_DIR="${SCRIPT_ROOT}"
  fi
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

  init_install_state
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
  install_opencode
  record_compose_images
  configure_https
  start_stack
  download_models
  install_ai_command
  install_integrated_assistant_commands
  show_handoff
  launch_assistant
}

main "$@"
