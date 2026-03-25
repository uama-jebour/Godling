#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <version-tag> [release-title]"
  echo "Example: $0 v0.1.0 \"Godling v0.1.0\""
  exit 1
fi

VERSION_TAG="$1"
RELEASE_TITLE="${2:-Godling ${VERSION_TAG}}"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build/windows"
DIST_DIR="${ROOT_DIR}/dist/windows"
ZIP_PATH="${DIST_DIR}/Godling-windows-x64-${VERSION_TAG}.zip"
SHA_PATH="${ZIP_PATH}.sha256"
EXE_PATH="${BUILD_DIR}/Godling.exe"
PCK_PATH="${BUILD_DIR}/Godling.pck"

if [[ ! -f "${EXE_PATH}" ]]; then
  echo "Missing file: ${EXE_PATH}"
  echo "Export Windows release first."
  exit 2
fi

if [[ ! -f "${PCK_PATH}" ]]; then
  echo "Missing file: ${PCK_PATH}"
  echo "Export Windows release first."
  exit 2
fi

mkdir -p "${DIST_DIR}"
rm -f "${ZIP_PATH}" "${SHA_PATH}"

(
  cd "${BUILD_DIR}"
  zip -9 -q "${ZIP_PATH}" "Godling.exe" "Godling.pck"
)

shasum -a 256 "${ZIP_PATH}" > "${SHA_PATH}"
echo "Packaged:"
echo "  ${ZIP_PATH}"
echo "  ${SHA_PATH}"

if ! git -C "${ROOT_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repository. Skip tag and release."
  exit 0
fi

if git -C "${ROOT_DIR}" rev-parse "${VERSION_TAG}" >/dev/null 2>&1; then
  echo "Tag exists: ${VERSION_TAG}"
else
  git -C "${ROOT_DIR}" tag "${VERSION_TAG}"
  echo "Created tag: ${VERSION_TAG}"
fi

if git -C "${ROOT_DIR}" remote get-url origin >/dev/null 2>&1; then
  if git -C "${ROOT_DIR}" push origin "${VERSION_TAG}"; then
    echo "Pushed tag to origin: ${VERSION_TAG}"
  else
    echo "Failed to push tag. Check network and git auth."
  fi
else
  echo "No git remote origin configured. Skip push."
fi

if command -v gh >/dev/null 2>&1; then
  if gh auth status -h github.com >/dev/null 2>&1; then
    if gh release view "${VERSION_TAG}" >/dev/null 2>&1; then
      gh release upload "${VERSION_TAG}" "${ZIP_PATH}" "${SHA_PATH}" --clobber
      echo "Uploaded assets to existing release: ${VERSION_TAG}"
    else
      gh release create "${VERSION_TAG}" "${ZIP_PATH}" "${SHA_PATH}" --title "${RELEASE_TITLE}" --notes "Windows demo build"
      echo "Created GitHub release: ${VERSION_TAG}"
    fi
  else
    echo "gh exists but is not authenticated. Run: gh auth login"
  fi
else
  echo "gh is not installed. Install GitHub CLI to auto-upload assets."
fi
