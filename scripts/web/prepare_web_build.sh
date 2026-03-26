#!/usr/bin/env bash
set -euo pipefail

WEB_DIR="${1:-dist/web}"
BUILD_ID="${2:-}"

if [[ ! -d "${WEB_DIR}" ]]; then
  echo "Web build directory not found: ${WEB_DIR}" >&2
  exit 1
fi

if [[ -z "${BUILD_ID}" ]]; then
  SHORT_SHA="${GITHUB_SHA:-local}"
  SHORT_SHA="${SHORT_SHA:0:7}"
  BUILD_ID="$(date -u +'%Y%m%dT%H%M%SZ')-${SHORT_SHA}"
fi

BUILD_ID="$(printf '%s' "${BUILD_ID}" | tr -cd '[:alnum:]_.:-')"
INDEX_HTML="${WEB_DIR}/index.html"
INDEX_JS="${WEB_DIR}/index.js"

if [[ -f "${INDEX_HTML}" ]]; then
  perl -0pi -e "s#src=\\\"index\\.js(?:\\?v=[^\\\"]*)?\\\"#src=\\\"index.js?v=${BUILD_ID}\\\"#g" "${INDEX_HTML}"
fi

if [[ -f "${INDEX_JS}" ]]; then
  perl -0pi -e "s#\\.wasm\\?v=[A-Za-z0-9._:-]+#\\.wasm#g; s#\\.pck\\?v=[A-Za-z0-9._:-]+#\\.pck#g; s#\\.wasm([\\\"'])#\\.wasm?v=${BUILD_ID}\\1#g; s#\\.pck([\\\"'])#\\.pck?v=${BUILD_ID}\\1#g" "${INDEX_JS}"
fi

cat > "${WEB_DIR}/build-meta.json" <<EOF
{
  "build_id": "${BUILD_ID}",
  "generated_at_utc": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
  "git_sha": "${GITHUB_SHA:-local}"
}
EOF

printf '%s\n' "${BUILD_ID}" > "${WEB_DIR}/.build-id"
echo "Prepared web build with cache-busting build id: ${BUILD_ID}"
