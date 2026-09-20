#!/usr/bin/env bash
# Resolve the latest Hermes Agent release tag from GitHub, with optional pin.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="${ROOT}/hermes/VERSION"
GITHUB_API="${HERMES_RELEASES_API:-https://api.github.com/repos/NousResearch/hermes-agent/releases/latest}"

fetch_latest_tag() {
  python3 - "$GITHUB_API" <<'PY'
import json, os, sys, urllib.request

url = sys.argv[1]
req = urllib.request.Request(url, headers={"User-Agent": "chatgpt-dingtalk-robot-hermes-updater"})
with urllib.request.urlopen(req, timeout=30) as resp:
    data = json.load(resp)
tag = data.get("tag_name")
if not tag:
    raise SystemExit("latest Hermes release is missing tag_name")
print(tag)
PY
}

if [[ "${1:-}" == "--pinned" ]]; then
  if [[ ! -f "${VERSION_FILE}" ]]; then
    echo "missing ${VERSION_FILE}" >&2
    exit 1
  fi
  tr -d '[:space:]' < "${VERSION_FILE}"
  exit 0
fi

if [[ -n "${HERMES_VERSION:-}" ]]; then
  echo "${HERMES_VERSION}"
  exit 0
fi

fetch_latest_tag
