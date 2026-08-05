#!/usr/bin/env bash

load_env_file() {
  local env_file="$1"
  local key
  local line
  local value

  [[ -f "${env_file}" ]] || return 0

  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%$'\r'}"
    [[ "${line}" =~ ^[[:space:]]*$ || "${line}" =~ ^[[:space:]]*# ]] && continue
    if [[ ! "${line}" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      echo "Aviso: ignorando linha inválida em ${env_file}: ${line}" >&2
      continue
    fi

    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    if [[ "${value}" == \'*\' && "${value}" == *\' ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "${value}" == \"*\" && "${value}" == *\" ]]; then
      value="${value:1:${#value}-2}"
    fi

    printf -v "${key}" '%s' "${value}"
    export "${key}"
  done <"${env_file}"
}

load_project_env() {
  local root_dir="$1"
  local env_name="${2:-.env}"

  if [[ -f "${root_dir}/${env_name}" ]]; then
    load_env_file "${root_dir}/${env_name}"
  elif [[ -f "${root_dir}/.env.example" ]]; then
    load_env_file "${root_dir}/.env.example"
  fi
}
