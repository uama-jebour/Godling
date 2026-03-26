#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_DIR="$REPO_ROOT/codex-configs/skills/azure-imagegen"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
TARGET_DIR="$CODEX_HOME_DIR/skills/azure-imagegen"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Source skill directory not found: $SOURCE_DIR" >&2
  exit 1
fi

mkdir -p "$CODEX_HOME_DIR/skills"
rm -rf "$TARGET_DIR"
cp -R "$SOURCE_DIR" "$TARGET_DIR"

echo "Installed azure-imagegen to: $TARGET_DIR"
echo "Next: export AZURE_OPENAI_API_KEY / AZURE_OPENAI_ENDPOINT / AZURE_OPENAI_API_VERSION / AZURE_OPENAI_IMAGE_DEPLOYMENT"
echo "Validate with: python3 '$TARGET_DIR/scripts/azure_image_gen.py' generate --prompt 'test' --out '$REPO_ROOT/output/imagegen/test.png' --dry-run"
