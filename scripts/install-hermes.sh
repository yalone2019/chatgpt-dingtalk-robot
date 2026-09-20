#!/usr/bin/env bash
# Install the latest NousResearch Hermes Agent (CLI) for local DingTalk / API use.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_URL="${HERMES_INSTALL_URL:-https://hermes-agent.nousresearch.com/install.sh}"

if command -v hermes >/dev/null 2>&1; then
  echo "Hermes CLI already installed: $(hermes --version 2>/dev/null || echo unknown)"
  echo "Running update instead..."
  exec "${ROOT}/scripts/update-hermes.sh"
fi

if [[ -x "${HOME}/.local/bin/hermes" ]]; then
  export PATH="${HOME}/.local/bin:${PATH}"
  echo "Found ${HOME}/.local/bin/hermes — running update..."
  exec "${ROOT}/scripts/update-hermes.sh"
fi

echo "Installing latest Hermes Agent from ${INSTALL_URL}"
echo "Browser automation is skipped (headless/local robot install)."
curl -fsSL "${INSTALL_URL}" | bash -s -- --skip-browser

if [[ -x "${HOME}/.local/bin/hermes" ]]; then
  export PATH="${HOME}/.local/bin:${PATH}"
fi

if ! command -v hermes >/dev/null 2>&1; then
  echo "Install finished but 'hermes' is not on PATH. Add ~/.local/bin to PATH and retry." >&2
  exit 1
fi

LATEST="$("${ROOT}/scripts/hermes-version.sh")"
echo "${LATEST}" > "${ROOT}/hermes/VERSION"
echo "Hermes installed: $(hermes --version 2>/dev/null || echo ok)"
echo "Pinned repo version file to ${LATEST}"
echo
echo "Next:"
echo "  1. source ~/.bashrc   # or reopen the shell"
echo "  2. hermes setup       # or: hermes setup --portal"
echo "  3. hermes gateway setup   # choose DingTalk"
echo "  4. hermes gateway"
echo "Optional: point this Node robot at http://127.0.0.1:8642/v1 (see .env.example)."
