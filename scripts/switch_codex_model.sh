#!/usr/bin/env bash
set -euo pipefail

CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
ACTIVE_CONFIG="${CODEX_DIR}/config.toml"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/switch_codex_model.sh <target>
  ./scripts/switch_codex_model.sh --list
  ./scripts/switch_codex_model.sh --help

Targets:
  codex-5.3      -> ~/.codex/config_codex_5.3.toml
  glm-5          -> ~/.codex/config_glm-5.toml
  kimi-k2.5      -> ~/.codex/config_kimi-k2.5.toml
  minmax-m2.5    -> ~/.codex/config_minmax-m2.5.toml
  official-gpt   -> ~/.codex/config_official_gpt_login.toml

Aliases:
  codex / codex_5.3 / codex-5.3
  glm / glm-5
  kimi / kimi-k2.5
  minmax / minmax-m2.5
  official / official-gpt / official-gpt-login
EOF
}

print_targets() {
  cat <<'EOF'
Available switch targets:
  codex-5.3
  glm-5
  kimi-k2.5
  minmax-m2.5
  official-gpt
EOF
}

target_to_file() {
  case "$1" in
    codex|codex_5.3|codex-5.3|config_codex_5.3.toml)
      echo "config_codex_5.3.toml"
      ;;
    glm|glm-5|config_glm-5.toml)
      echo "config_glm-5.toml"
      ;;
    kimi|kimi-k2.5|config_kimi-k2.5.toml)
      echo "config_kimi-k2.5.toml"
      ;;
    minmax|minmax-m2.5|config_minmax-m2.5.toml)
      echo "config_minmax-m2.5.toml"
      ;;
    official|official-gpt|official-gpt-login|config_official_gpt_login.toml)
      echo "config_official_gpt_login.toml"
      ;;
    *)
      return 1
      ;;
  esac
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

case "$1" in
  --help|-h)
    usage
    exit 0
    ;;
  --list|-l)
    print_targets
    exit 0
    ;;
esac

target_file=""
if ! target_file="$(target_to_file "$1")"; then
  echo "Unknown target: $1" >&2
  echo >&2
  usage
  exit 2
fi

source_config="${CODEX_DIR}/${target_file}"
if [[ ! -f "${source_config}" ]]; then
  echo "Target config not found: ${source_config}" >&2
  exit 3
fi

mkdir -p "${CODEX_DIR}"
if [[ -f "${ACTIVE_CONFIG}" ]]; then
  backup_name="config.toml.switch-backup.$(date +%Y%m%d-%H%M%S)"
  cp -p "${ACTIVE_CONFIG}" "${CODEX_DIR}/${backup_name}"
  echo "Backup saved: ${CODEX_DIR}/${backup_name}"
fi

cp -p "${source_config}" "${ACTIVE_CONFIG}"
echo "Switched active config to: ${source_config}"

active_model="$(grep -E '^model\s*=' "${ACTIVE_CONFIG}" | head -n 1 || true)"
active_provider="$(grep -E '^model_provider\s*=' "${ACTIVE_CONFIG}" | head -n 1 || true)"
if [[ -n "${active_model}" ]]; then
  echo "Active ${active_model}"
fi
if [[ -n "${active_provider}" ]]; then
  echo "Active ${active_provider}"
else
  echo "Active model_provider: (none)"
fi

echo "Done. Start a new Codex session to ensure full config refresh."
