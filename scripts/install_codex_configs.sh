#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="${ROOT_DIR}/codex-configs"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/install_codex_configs.sh [--activate <target>] [--help]

Options:
  --activate <target>  Activate target after syncing.
  --help               Show this help message.

Targets:
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

activate_target=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --activate)
      if [[ $# -lt 2 ]]; then
        echo "--activate requires a target." >&2
        usage
        exit 1
      fi
      activate_target="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -d "${SRC_DIR}" ]]; then
  echo "Source directory not found: ${SRC_DIR}" >&2
  exit 2
fi

mkdir -p "${CODEX_DIR}"

copied=0
for src in "${SRC_DIR}"/config_*.toml; do
  if [[ ! -f "${src}" ]]; then
    continue
  fi
  cp -f "${src}" "${CODEX_DIR}/"
  copied=$((copied + 1))
done

if [[ "${copied}" -eq 0 ]]; then
  echo "No config_*.toml files found in ${SRC_DIR}" >&2
  exit 3
fi

echo "Synced ${copied} config files to ${CODEX_DIR}"

if [[ -n "${activate_target}" ]]; then
  target_file=""
  if ! target_file="$(target_to_file "${activate_target}")"; then
    echo "Unknown activate target: ${activate_target}" >&2
    exit 4
  fi

  source_config="${CODEX_DIR}/${target_file}"
  if [[ ! -f "${source_config}" ]]; then
    echo "Target config not found after sync: ${source_config}" >&2
    exit 5
  fi

  active_config="${CODEX_DIR}/config.toml"
  if [[ -f "${active_config}" ]]; then
    backup_name="config.toml.install-backup.$(date +%Y%m%d-%H%M%S)"
    cp -p "${active_config}" "${CODEX_DIR}/${backup_name}"
    echo "Backup saved: ${CODEX_DIR}/${backup_name}"
  fi

  cp -f "${source_config}" "${active_config}"
  echo "Activated: ${source_config}"

  active_model="$(grep -E '^model\s*=' "${active_config}" | head -n 1 || true)"
  active_provider="$(grep -E '^model_provider\s*=' "${active_config}" | head -n 1 || true)"
  [[ -n "${active_model}" ]] && echo "Active ${active_model}"
  if [[ -n "${active_provider}" ]]; then
    echo "Active ${active_provider}"
  else
    echo "Active model_provider: (none)"
  fi
fi

echo "Done."
