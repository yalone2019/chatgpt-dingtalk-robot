#!/usr/bin/env bash
# Update a local Hermes Agent install to the latest GitHub release.
# Supports: hermes CLI (git install) and Docker Compose in this repo.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${ROOT}/docker-compose.hermes.yml"
VERSION_FILE="${ROOT}/hermes/VERSION"
CHECK_ONLY=0
FORCE_DOCKER=0

usage() {
  cat <<'EOF'
Usage: scripts/update-hermes.sh [--check] [--docker]

  --check    Only report current vs latest; do not change anything
  --docker   Update via docker compose even if hermes CLI exists
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK_ONLY=1; shift ;;
    --docker) FORCE_DOCKER=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

export PATH="${HOME}/.local/bin:${PATH}"

LATEST="$("${ROOT}/scripts/hermes-version.sh")"
PINNED="$(tr -d '[:space:]' < "${VERSION_FILE}" 2>/dev/null || true)"

current_cli_version() {
  if command -v hermes >/dev/null 2>&1; then
    hermes --version 2>/dev/null || true
  fi
}

current_docker_image() {
  if [[ -f "${COMPOSE_FILE}" ]]; then
    python3 - "${COMPOSE_FILE}" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
match = re.search(r"image:\s*nousresearch/hermes-agent:(\S+)", text)
print(match.group(1) if match else "")
PY
  fi
}

CLI_VER="$(current_cli_version)"
DOCKER_TAG="$(current_docker_image)"

echo "Latest Hermes Agent release: ${LATEST}"
[[ -n "${PINNED}" ]] && echo "Pinned in hermes/VERSION: ${PINNED}"
[[ -n "${CLI_VER}" ]] && echo "Local hermes CLI: ${CLI_VER}"
[[ -n "${DOCKER_TAG}" ]] && echo "docker-compose.hermes.yml image tag: ${DOCKER_TAG}"

if [[ "${CHECK_ONLY}" -eq 1 ]]; then
  if [[ "${PINNED}" == "${LATEST}" && ( -z "${DOCKER_TAG}" || "${DOCKER_TAG}" == "${LATEST}" ) ]]; then
    echo "Already aligned with latest ${LATEST}"
    exit 0
  fi
  echo "Update available: ${PINNED:-unknown} / ${DOCKER_TAG:-no-compose} -> ${LATEST}"
  exit 0
fi

pin_version() {
  mkdir -p "$(dirname "${VERSION_FILE}")"
  printf '%s\n' "${LATEST}" > "${VERSION_FILE}"
  python3 - "${COMPOSE_FILE}" "${LATEST}" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
tag = sys.argv[2]
text = path.read_text(encoding="utf-8")
updated, n = re.subn(
    r"(image:\s*nousresearch/hermes-agent:)(\S+)",
    rf"\g<1>{tag}",
    text,
    count=1,
)
if n != 1:
    raise SystemExit(f"failed to pin image tag in {path}")
path.write_text(updated, encoding="utf-8")
PY
}

have_cli() {
  command -v hermes >/dev/null 2>&1
}

have_docker() {
  command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1
}

updated=0

if [[ "${FORCE_DOCKER}" -eq 0 ]] && have_cli; then
  echo "Updating git/CLI install with hermes update..."
  if hermes update --help 2>&1 | grep -q -- '--yes'; then
    hermes update --yes
  else
    hermes update
  fi
  echo "CLI version after update: $(hermes --version 2>/dev/null || echo unknown)"
  hermes doctor || true
  updated=1
fi

if [[ "${FORCE_DOCKER}" -eq 1 ]] || [[ "${updated}" -eq 0 ]]; then
  if have_docker; then
    echo "Updating Docker image to ${LATEST}..."
    pin_version
    docker compose -f "${COMPOSE_FILE}" pull
    docker compose -f "${COMPOSE_FILE}" up -d --force-recreate
    docker compose -f "${COMPOSE_FILE}" ps
    updated=1
  elif [[ "${FORCE_DOCKER}" -eq 1 ]]; then
    echo "Docker is not available." >&2
    exit 1
  fi
fi

if [[ "${updated}" -eq 0 ]]; then
  echo "No local Hermes CLI or Docker install found."
  echo "Install with: ${ROOT}/scripts/install-hermes.sh"
  pin_version
  echo "Pinned compose/VERSION to ${LATEST}. Install Hermes locally, then re-run this script."
  exit 1
fi

pin_version
echo "Local Hermes is now targeting ${LATEST}"
