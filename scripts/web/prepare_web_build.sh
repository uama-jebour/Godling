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
  perl -0pi -e "s#src=([\\\"'])index\\.js(?:\\?[^\\\"']*)?\\1#src=\\1index.js?v=${BUILD_ID}\\1#g" "${INDEX_HTML}"

  BUILD_GUARD_FILE="$(mktemp)"
  cat > "${BUILD_GUARD_FILE}" <<EOF
<!-- GODLING_BUILD_GUARD_START -->
<script>
window.__GODLING_BUILD_ID__ = "${BUILD_ID}";
(function () {
  const currentBuild = window.__GODLING_BUILD_ID__;
  if (!currentBuild || !window.fetch || !window.URL) {
    return;
  }
  const probeUrl = ".build-id?probe=" + encodeURIComponent(Date.now().toString());
  fetch(probeUrl, { cache: "no-store" })
    .then((response) => (response.ok ? response.text() : ""))
    .then((text) => {
      const latestBuild = String(text || "").trim();
      if (!latestBuild || latestBuild === currentBuild) {
        return;
      }
      const url = new URL(window.location.href);
      if (url.searchParams.get("build_reload") === latestBuild) {
        return;
      }
      url.searchParams.set("build_reload", latestBuild);
      window.location.replace(url.toString());
    })
    .catch(() => {});
}());
</script>
<!-- GODLING_BUILD_GUARD_END -->
EOF

  TMP_HTML="$(mktemp)"
  sed '/<!-- GODLING_BUILD_GUARD_START -->/,/<!-- GODLING_BUILD_GUARD_END -->/d' "${INDEX_HTML}" > "${TMP_HTML}"
  awk -v guard_file="${BUILD_GUARD_FILE}" '
BEGIN {
  while ((getline line < guard_file) > 0) {
    guard = guard line "\n"
  }
  close(guard_file)
}
/<\/body>/ && !inserted {
  printf "%s", guard
  inserted = 1
}
{
  print
}
END {
  if (!inserted) {
    printf "%s", guard
  }
}
' "${TMP_HTML}" > "${INDEX_HTML}"
  rm -f "${TMP_HTML}" "${BUILD_GUARD_FILE}"
fi

if [[ -f "${INDEX_JS}" ]]; then
  perl -0pi -e "s#\\.side\\.wasm\\?v=[A-Za-z0-9._:-]+#\\.side.wasm#g; s#(?<!side)\\.wasm\\?v=[A-Za-z0-9._:-]+#\\.wasm#g; s#\\.pck\\?v=[A-Za-z0-9._:-]+#\\.pck#g; s#(?<!side)\\.wasm([\\\"'])#\\.wasm?v=${BUILD_ID}\\1#g; s#\\.pck([\\\"'])#\\.pck?v=${BUILD_ID}\\1#g" "${INDEX_JS}"

  if grep -q "\\.side\\.wasm?v=" "${INDEX_JS}"; then
    echo "Unexpected cache suffix on side.wasm after prepare step." >&2
    exit 1
  fi
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
