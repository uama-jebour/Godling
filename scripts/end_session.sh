#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

FILES=(
  "agent.md"
  "项目记忆.md"
  "tasks/当前任务卡.md"
  "tasks/开发交接.md"
  "tasks/会话收尾检查清单.md"
)

OPEN_FILES=false

usage() {
  cat <<'EOF'
Usage:
  ./scripts/end_session.sh [--open] [--help]

Options:
  --open   Open key handoff files after checks.
  --help   Show this help message.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --open) OPEN_FILES=true ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg"
      usage
      exit 1
      ;;
  esac
done

echo "== End Session Check =="
echo "Project: $ROOT_DIR"
echo

missing=0
for rel in "${FILES[@]}"; do
  abs="$ROOT_DIR/$rel"
  if [[ -f "$abs" ]]; then
    echo "[OK] $rel"
  else
    echo "[MISSING] $rel"
    missing=$((missing + 1))
  fi
done

echo
if [[ "$missing" -gt 0 ]]; then
  echo "Missing files: $missing"
  echo "Create/fix missing files before ending this session."
  exit 2
fi

echo "Next actions:"
echo "1) Update tasks/开发交接.md"
echo "2) Check tasks/会话收尾检查清单.md"
echo "3) Sync 项目记忆.md and tasks/当前任务卡.md"
echo "4) Commit and push if you will continue on another machine"
echo

if [[ "$OPEN_FILES" == "true" ]]; then
  abs_files=()
  for rel in "${FILES[@]}"; do
    abs_files+=("$ROOT_DIR/$rel")
  done

  if command -v code >/dev/null 2>&1; then
    code "${abs_files[@]}"
    echo "Opened files with VS Code."
  elif command -v open >/dev/null 2>&1; then
    open "${abs_files[@]}"
    echo "Opened files with system default app."
  elif command -v xdg-open >/dev/null 2>&1; then
    for f in "${abs_files[@]}"; do
      xdg-open "$f" >/dev/null 2>&1 || true
    done
    echo "Attempted to open files with xdg-open."
  else
    echo "No supported opener found. Open files manually."
  fi
fi

echo
echo "End session check completed."
