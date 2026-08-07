#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_URL="https://github.com/gut0leao/ai.localhost.git"
LEGACY_REPOSITORY_URL="https://github.com/gut0leao/local-coding-ai.git"
RAW_UNINSTALLER_URL="https://raw.githubusercontent.com/gut0leao/ai.localhost/main/uninstall.sh"
DEFAULT_INSTALL_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/local-coding-ai"
STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/local-coding-ai"
INSTALL_DIR="${LOCAL_AI_INSTALL_DIR:-}"
INSTALL_DIR_EXPLICIT=false
[[ -z "${INSTALL_DIR}" ]] || INSTALL_DIR_EXPLICIT=true
ASSUME_YES=false
DRY_RUN=false
SCRIPT_ROOT=""
HAS_STATE=false
REMOVE_CHECKOUT=false

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
Desinstalador completo do ai.localhost

Uso local:
  ./uninstall.sh [opções]

Uso remoto:
  curl -fsSL ${RAW_UNINSTALLER_URL} | bash -s -- [opções]

Opções:
  --yes                  Confirma a remoção sem perguntar.
  --dry-run              Mostra o que seria removido sem alterar a máquina.
  --install-dir CAMINHO  Informa a localização da stack quando não há manifesto.
  -h, --help             Exibe esta ajuda.

A desinstalação apaga modelos, conversas e demais dados persistidos nos volumes.
Pacotes e configurações compartilhados são removidos somente quando o manifesto
confirma que foram adicionados pelo instalador.
EOF
}

confirm() {
  local answer

  [[ "${ASSUME_YES}" == false ]] || return 0
  [[ -r /dev/tty ]] \
    || fail "confirmação interativa indisponível; execute novamente com --yes"
  printf 'Continuar com a desinstalação completa? [s/N] ' >/dev/tty
  read -r answer </dev/tty || true
  [[ "${answer}" =~ ^[SsYy]$ ]]
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes)
        ASSUME_YES=true
        ;;
      --dry-run)
        DRY_RUN=true
        ;;
      --install-dir)
        [[ $# -ge 2 ]] || fail "--install-dir requer um caminho"
        INSTALL_DIR="$2"
        INSTALL_DIR_EXPLICIT=true
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

detect_locations() {
  local source_path="${BASH_SOURCE[0]:-}"
  local candidate
  local manifest_install_dir

  if [[ -n "${source_path}" && -f "${source_path}" ]]; then
    candidate="$(cd "$(dirname "${source_path}")" && pwd)"
    if [[ -f "${candidate}/docker-compose.yml" ]]; then
      SCRIPT_ROOT="${candidate}"
    fi
  fi

  if [[ -r "${STATE_DIR}/format-version" && -r "${STATE_DIR}/install-dir" ]]; then
    HAS_STATE=true
    IFS= read -r manifest_install_dir <"${STATE_DIR}/install-dir"
    if [[ "${INSTALL_DIR_EXPLICIT}" == true \
      && "$(realpath -m "${INSTALL_DIR}")" != "$(realpath -m "${manifest_install_dir}")" ]]; then
      fail "--install-dir não corresponde ao manifesto em ${STATE_DIR}"
    fi
    INSTALL_DIR="${manifest_install_dir}"
  elif [[ -z "${INSTALL_DIR}" && -n "${SCRIPT_ROOT}" ]]; then
    INSTALL_DIR="${SCRIPT_ROOT}"
  elif [[ -z "${INSTALL_DIR}" ]]; then
    INSTALL_DIR="${DEFAULT_INSTALL_DIR}"
  fi

  INSTALL_DIR="$(realpath -m "${INSTALL_DIR}")"
  [[ "${INSTALL_DIR}" != "/" && "${INSTALL_DIR}" != "${HOME}" ]] \
    || fail "diretório de instalação inseguro: ${INSTALL_DIR}"

  if [[ "${HAS_STATE}" == true && -e "${STATE_DIR}/checkout-created" ]]; then
    if [[ ! -d "${INSTALL_DIR}" ]]; then
      warn "o manifesto indica um checkout criado pelo instalador, mas ${INSTALL_DIR} já foi removido"
    elif [[ -d "${INSTALL_DIR}/.git" ]]; then
      case "$(git -C "${INSTALL_DIR}" remote get-url origin 2>/dev/null || true)" in
        "${REPOSITORY_URL}"|"${LEGACY_REPOSITORY_URL}"|git@github.com:gut0leao/ai.localhost.git|git@github.com:gut0leao/local-coding-ai.git) REMOVE_CHECKOUT=true ;;
        *) fail "o manifesto pede a remoção do checkout, mas ${INSTALL_DIR} não corresponde ao repositório esperado" ;;
      esac
    else
      fail "o manifesto pede a remoção do checkout, mas ${INSTALL_DIR} não é um repositório Git"
    fi
  fi
}

show_plan() {
  cat <<EOF

============================================================
Desinstalação completa do ai.localhost
============================================================
Stack:      ${INSTALL_DIR}
Manifesto: ${STATE_DIR}

Serão removidos:
  - containers, rede, volumes, modelos e conversas da stack;
  - imagens Docker baixadas exclusivamente pelo instalador;
  - certificados locais e a confiança da CA criada pelo instalador;
  - comando ai.localhost e sua configuração;
  - Aider, OpenCode e pacotes APT somente se instalados por este projeto;
  - configuração NVIDIA criada pelo instalador, restaurando daemon.json;
  - checkout da stack somente se ele foi clonado pelo instalador.

Dados nos volumes Docker não poderão ser recuperados.
============================================================
EOF

  if [[ "${HAS_STATE}" == false ]]; then
    warn "manifesto não encontrado; esta parece ser uma instalação anterior ao rastreamento"
    warn "serão removidos os recursos próprios da stack, mas Aider, CA, pacotes APT e configuração NVIDIA serão preservados por segurança"
  fi
}

restore_user_file() {
  local target="$1"
  local state_name="$2"

  if [[ -e "${STATE_DIR}/${state_name}.existed" \
    && -f "${STATE_DIR}/${state_name}.backup" ]]; then
    mkdir -p "$(dirname "${target}")"
    cp -a "${STATE_DIR}/${state_name}.backup" "${target}"
  elif [[ -e "${STATE_DIR}/${state_name}.absent" ]]; then
    rm -f -- "${target}"
  fi
}

restore_system_file() {
  local target="$1"
  local state_name="$2"

  if [[ -e "${STATE_DIR}/system-${state_name}.existed" \
    && -f "${STATE_DIR}/system-${state_name}.backup" ]]; then
    sudo mkdir -p "$(dirname "${target}")"
    sudo cp -a "${STATE_DIR}/system-${state_name}.backup" "${target}"
  elif [[ -e "${STATE_DIR}/system-${state_name}.absent" ]]; then
    sudo rm -f -- "${target}"
  fi
}

remove_stack() {
  local image

  if command -v docker >/dev/null 2>&1 && [[ -f "${INSTALL_DIR}/docker-compose.yml" ]]; then
    info "Removendo containers, rede e volumes persistentes"
    docker compose --profile web-search -f "${INSTALL_DIR}/docker-compose.yml" \
      down --volumes --remove-orphans
  else
    warn "Docker ou docker-compose.yml indisponível; não foi possível remover a stack automaticamente"
  fi

  if command -v docker >/dev/null 2>&1 && [[ -r "${STATE_DIR}/docker-images" ]]; then
    info "Removendo imagens baixadas pelo instalador"
    while IFS= read -r image; do
      [[ -n "${image}" ]] || continue
      docker image rm "${image}" >/dev/null 2>&1 \
        || warn "a imagem ${image} está em uso ou já foi removida"
    done <"${STATE_DIR}/docker-images"
  fi
}

remove_certificates() {
  local caroot=""
  local thumbprint=""

  if [[ "${HAS_STATE}" == true ]]; then
    restore_user_file "${INSTALL_DIR}/certs/local-ai.pem" certificate
    restore_user_file "${INSTALL_DIR}/certs/local-ai-key.pem" certificate-key
  else
    rm -f -- "${INSTALL_DIR}/certs/local-ai.pem" "${INSTALL_DIR}/certs/local-ai-key.pem"
  fi
  if [[ -r "${STATE_DIR}/windows-ca-thumbprint" ]] \
    && command -v certutil.exe >/dev/null 2>&1; then
    info "Removendo a CA adicionada pelo instalador ao armazenamento Windows"
    IFS= read -r thumbprint <"${STATE_DIR}/windows-ca-thumbprint"
    certutil.exe -user -delstore Root "${thumbprint}" >/dev/null 2>&1 \
      || warn "não foi possível remover automaticamente a CA do armazenamento Windows"
  fi

  [[ "${HAS_STATE}" == true && -e "${STATE_DIR}/mkcert-ca-created" ]] || return 0

  info "Removendo confiança e arquivos da CA local criada pelo instalador"

  if command -v mkcert >/dev/null 2>&1; then
    mkcert -uninstall
  else
    warn "mkcert não está disponível para remover a CA dos armazenamentos Linux/NSS"
  fi

  if [[ -r "${STATE_DIR}/mkcert-caroot" ]]; then
    IFS= read -r caroot <"${STATE_DIR}/mkcert-caroot"
    caroot="$(realpath -m "${caroot}")"
    case "${caroot}" in
      "${HOME}"/*)
        [[ "${caroot}" != "${HOME}" ]] || fail "CAROOT inseguro: ${caroot}"
        if [[ -d "${caroot}" ]]; then
          find "${caroot}" -mindepth 1 -delete
          rmdir "${caroot}" 2>/dev/null || true
        fi
        ;;
      *) warn "CAROOT fora da pasta do usuário; preservando ${caroot}" ;;
    esac
  fi
}

restore_checkout_revision() {
  local current_head
  local installed_head
  local previous_head

  [[ "${REMOVE_CHECKOUT}" == false \
    && -r "${STATE_DIR}/checkout-previous-head" \
    && -r "${STATE_DIR}/checkout-installed-head" ]] || return 0
  IFS= read -r previous_head <"${STATE_DIR}/checkout-previous-head"
  IFS= read -r installed_head <"${STATE_DIR}/checkout-installed-head"
  current_head="$(git -C "${INSTALL_DIR}" rev-parse HEAD 2>/dev/null || true)"

  if [[ -z "$(git -C "${INSTALL_DIR}" status --porcelain 2>/dev/null)" \
    && "${current_head}" == "${installed_head}" ]]; then
    info "Restaurando revisão anterior do checkout preexistente"
    git -C "${INSTALL_DIR}" reset --hard "${previous_head}" >/dev/null
  else
    warn "o checkout mudou após a instalação; a revisão atual será preservada"
  fi
}

remove_aider() {
  local pipx_has_other_packages=false
  local venv_dir

  [[ "${HAS_STATE}" == true && -e "${STATE_DIR}/aider-installed" ]] || return 0
  if command -v pipx >/dev/null 2>&1; then
    info "Desinstalando Aider instalado pelo projeto"
    pipx uninstall aider-chat || warn "Aider já não estava instalado pelo pipx"
    for venv_dir in "${HOME}/.local/share/pipx/venvs" "${HOME}/.local/pipx/venvs"; do
      if [[ -d "${venv_dir}" ]] \
        && find "${venv_dir}" -mindepth 1 -maxdepth 1 -type d -print -quit | grep -q .; then
        pipx_has_other_packages=true
      fi
    done
  else
    warn "pipx indisponível; não foi possível remover o Aider"
    return 0
  fi

  if [[ "${pipx_has_other_packages}" == false ]]; then
    remove_created_directory "${HOME}/.local/share/pipx" pipx-share-created
    remove_created_directory "${HOME}/.local/pipx" pipx-legacy-home-created
    remove_created_directory "${HOME}/.cache/pipx" pipx-cache-created
    remove_created_directory "${HOME}/.local/state/pipx" pipx-state-created
  else
    warn "outros aplicativos pipx foram encontrados; caches compartilhados do pipx serão preservados"
  fi
}

remove_opencode() {
  local binary_path="${HOME}/.opencode/bin/opencode"
  local command_path="${HOME}/.local/bin/opencode"

  [[ "${HAS_STATE}" == true && -e "${STATE_DIR}/opencode-installed" ]] || return 0
  info "Removendo OpenCode instalado pelo projeto"
  restore_user_file "${command_path}" opencode-command
  restore_user_file "${binary_path}" opencode-binary
  rmdir "${HOME}/.opencode/bin" 2>/dev/null || true
  rmdir "${HOME}/.opencode" 2>/dev/null || true
}

remove_created_directory() {
  local directory="$1"
  local marker="$2"

  [[ -e "${STATE_DIR}/${marker}" && -d "${directory}" ]] || return 0
  case "$(realpath -m "${directory}")" in
    "${HOME}/.local/share/pipx"|"${HOME}/.local/pipx"|"${HOME}/.cache/pipx"|"${HOME}/.local/state/pipx") ;;
    *) fail "diretório pipx inesperado: ${directory}" ;;
  esac
  find "${directory}" -mindepth 1 -delete
  rmdir "${directory}" 2>/dev/null || true
}

remove_path_entries() {
  local path_file

  [[ -r "${STATE_DIR}/path-files" ]] || return 0
  while IFS= read -r path_file; do
    case "${path_file}" in
      "${HOME}/.bashrc"|"${HOME}/.zshrc"|"${HOME}/.profile") ;;
      *) warn "arquivo de shell inesperado no manifesto; preservando ${path_file}"; continue ;;
    esac
    if [[ -f "${path_file}" ]]; then
      sed -i '/^# >>> local-coding-ai PATH >>>$/,/^# <<< local-coding-ai PATH <<<$/{d;}' "${path_file}"
    fi
    if grep -Fqx -- "${path_file}" "${STATE_DIR}/path-created-files" 2>/dev/null \
      && [[ -f "${path_file}" ]] && ! grep -q '[^[:space:]]' "${path_file}"; then
      rm -f -- "${path_file}"
    fi
  done <"${STATE_DIR}/path-files"
}

restore_user_configuration() {
  local launcher_path="${HOME}/.local/bin/ai.localhost"
  local stack_config_path="${XDG_CONFIG_HOME:-${HOME}/.config}/local-coding-ai/stack-dir"
  local opencode_config_path="${XDG_CONFIG_HOME:-${HOME}/.config}/opencode/opencode.json"

  if [[ -r "${STATE_DIR}/launcher-path" ]]; then
    IFS= read -r launcher_path <"${STATE_DIR}/launcher-path"
  fi
  if [[ -r "${STATE_DIR}/stack-dir-config-path" ]]; then
    IFS= read -r stack_config_path <"${STATE_DIR}/stack-dir-config-path"
  fi
  [[ "$(realpath -m "${launcher_path}")" == "${HOME}/.local/bin/ai.localhost" ]] \
    || fail "caminho inesperado para o launcher: ${launcher_path}"
  case "$(realpath -m "${stack_config_path}")" in
    "${HOME}"/*/local-coding-ai/stack-dir) ;;
    *) fail "caminho inesperado para a configuração: ${stack_config_path}" ;;
  esac

  if [[ "${HAS_STATE}" == true ]]; then
    restore_user_file "${launcher_path}" launcher
    restore_user_file "${stack_config_path}" stack-dir-config
    restore_user_file "${opencode_config_path}" opencode-config
    restore_user_file "${INSTALL_DIR}/.env" environment
    remove_path_entries
  else
    rm -f -- "${launcher_path}" "${stack_config_path}" "${opencode_config_path}"
  fi

  rmdir "$(dirname "${stack_config_path}")" 2>/dev/null || true
  rmdir "$(dirname "${opencode_config_path}")" 2>/dev/null || true
}

restore_nvidia_configuration() {
  [[ "${HAS_STATE}" == true && -e "${STATE_DIR}/nvidia-runtime-configured" ]] || return 0

  info "Restaurando configuração anterior do runtime Docker/NVIDIA"
  restore_system_file /etc/docker/daemon.json docker-daemon
  restore_system_file /etc/apt/sources.list.d/nvidia-container-toolkit.list nvidia-list
  restore_system_file /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg nvidia-keyring
}

remove_apt_packages() {
  local package
  local packages=()

  [[ "${HAS_STATE}" == true && -r "${STATE_DIR}/apt-packages" ]] || return 0
  while IFS= read -r package; do
    [[ "${package}" =~ ^[A-Za-z0-9.+:-]+$ ]] \
      || fail "nome de pacote inválido no manifesto: ${package}"
    if dpkg-query -W -f='${db:Status-Abbrev}' "${package}" 2>/dev/null | grep -q '^ii'; then
      packages+=("${package}")
    fi
  done <"${STATE_DIR}/apt-packages"
  [[ ${#packages[@]} -gt 0 ]] || return 0

  info "Removendo pacotes APT instalados pelo projeto"
  sudo apt-get remove --purge -y "${packages[@]}"
}

restart_docker_if_needed() {
  [[ "${HAS_STATE}" == true && -e "${STATE_DIR}/nvidia-runtime-configured" ]] || return 0
  if command -v systemctl >/dev/null 2>&1 && systemctl is-active docker >/dev/null 2>&1; then
    sudo systemctl restart docker
  elif command -v service >/dev/null 2>&1; then
    sudo service docker restart
  fi
}

remove_checkout_and_state() {
  if [[ "${REMOVE_CHECKOUT}" == true && -d "${INSTALL_DIR}" ]]; then
    info "Removendo checkout criado pelo instalador"
    find "${INSTALL_DIR}" -mindepth 1 -delete
    rmdir "${INSTALL_DIR}" 2>/dev/null || true
  fi

  if [[ "${HAS_STATE}" == true && -d "${STATE_DIR}" ]]; then
    find "${STATE_DIR}" -mindepth 1 -delete
    rmdir "${STATE_DIR}" 2>/dev/null || true
  fi
}

main() {
  parse_args "$@"
  detect_locations
  show_plan

  if [[ "${DRY_RUN}" == true ]]; then
    success "simulação concluída; nenhuma alteração foi feita"
    exit 0
  fi
  confirm || fail "desinstalação cancelada"

  remove_stack
  remove_certificates
  remove_aider
  remove_opencode
  restore_user_configuration
  restore_nvidia_configuration
  restore_checkout_revision
  remove_apt_packages
  restart_docker_if_needed
  remove_checkout_and_state

  success "ai.localhost foi desinstalado"
  printf 'Abra um novo terminal para recarregar o PATH.\n'
}

main "$@"
