#!/usr/bin/env bash
# Map Cloudera AI project environment variables into Vibe CLI / extension config.
set -Eeuo pipefail

VIBE_HOME="${VIBE_HOME:-${HOME}/.vibe}"
mkdir -p "${VIBE_HOME}"

# Project env (recommended names). Aliases for convenience.
MISTRAL_API_KEY="${MISTRAL_API_KEY:-${VIBE_API_KEY:-}}"
MISTRAL_API_URL="${MISTRAL_API_URL:-${VIBE_API_URL:-${MISTRAL_API_BASE:-}}}"

if [[ -n "${MISTRAL_API_KEY}" ]]; then
  export MISTRAL_API_KEY
fi

if [[ -n "${MISTRAL_API_URL}" ]]; then
  api_base="${MISTRAL_API_URL%/}"
  config_file="${VIBE_HOME}/config.toml"

  if [[ ! -f "${config_file}" ]]; then
    cat >"${config_file}" <<EOF
# Generated at session start from project environment (MISTRAL_API_URL).
active_model = "devstral-2512"

[[providers]]
name = "mistral"
backend = "mistral"
api_style = "openai"
api_base = "${api_base}"
api_key_env_var = "MISTRAL_API_KEY"
EOF
  else
    if grep -q '^name = "mistral"' "${config_file}" 2>/dev/null; then
      if grep -q '^api_base = ' "${config_file}"; then
        sed -i "s|^api_base = .*|api_base = \"${api_base}\"|" "${config_file}"
      else
        sed -i "/^name = \"mistral\"/a api_base = \"${api_base}\"" "${config_file}"
      fi
    else
      cat >>"${config_file}" <<EOF

[[providers]]
name = "mistral"
backend = "mistral"
api_style = "openai"
api_base = "${api_base}"
api_key_env_var = "MISTRAL_API_KEY"
EOF
    fi
  fi
fi

if [[ -n "${MISTRAL_API_KEY}" ]]; then
  env_file="${VIBE_HOME}/.env"
  tmp_file="${env_file}.tmp.$$"
  if [[ -f "${env_file}" ]]; then
    grep -v '^MISTRAL_API_KEY=' "${env_file}" >"${tmp_file}" || true
  else
    : >"${tmp_file}"
  fi
  printf 'MISTRAL_API_KEY=%s\n' "${MISTRAL_API_KEY}" >>"${tmp_file}"
  mv "${tmp_file}" "${env_file}"
  chmod 600 "${env_file}" 2>/dev/null || true
fi
