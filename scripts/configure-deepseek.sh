#!/usr/bin/env bash
# Point Hermes / this robot at DeepSeek. Reads DEEPSEEK_API_KEY from the
# environment; never prints the key.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY="${DEEPSEEK_API_KEY:-${OPENAI_API_KEY:-}}"

if [[ -z "${KEY}" ]]; then
  echo "Set DEEPSEEK_API_KEY before running this script." >&2
  exit 1
fi

upsert_env() {
  local file="$1"
  local name="$2"
  local value="$3"
  mkdir -p "$(dirname "${file}")"
  touch "${file}"
  python3 - "$file" "$name" "$value" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
name = sys.argv[2]
value = sys.argv[3]
lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
prefix = f"{name}="
kept = [line for line in lines if not line.startswith(prefix) and not line.startswith(f"{name} =")]
kept.append(f"{name}={value}")
text = "\n".join(kept).rstrip() + "\n"
path.write_text(text, encoding="utf-8")
PY
}

upsert_env "${ROOT}/.env" "LLM_PROVIDER" "deepseek"
upsert_env "${ROOT}/.env" "OPENAI_BASE_URL" "https://api.deepseek.com"
upsert_env "${ROOT}/.env" "OPENAI_MODEL" "deepseek-flash"
upsert_env "${ROOT}/.env" "DEEPSEEK_API_KEY" "${KEY}"
upsert_env "${ROOT}/.env" "OPENAI_API_KEY" "${KEY}"

HERMES_ENV="${HERMES_HOME:-${HOME}/.hermes}/.env"
HERMES_CONFIG="${HERMES_HOME:-${HOME}/.hermes}/config.yaml"
upsert_env "${HERMES_ENV}" "DEEPSEEK_API_KEY" "${KEY}"

python3 - "${HERMES_CONFIG}" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
path.parent.mkdir(parents=True, exist_ok=True)
snippet = """model:
  provider: deepseek
  default: deepseek-flash
  base_url: https://api.deepseek.com
"""
existing = path.read_text(encoding="utf-8") if path.exists() else ""
if "provider: deepseek" in existing and "deepseek-flash" in existing:
    if "base_url:" not in existing:
        path.write_text(existing.rstrip() + "\n  base_url: https://api.deepseek.com\n", encoding="utf-8")
    sys.exit(0)
if existing.strip():
    path.write_text(existing.rstrip() + "\n\n" + snippet, encoding="utf-8")
else:
    path.write_text(snippet, encoding="utf-8")
PY

if command -v hermes >/dev/null 2>&1 || [[ -x "${HOME}/.local/bin/hermes" ]]; then
  export PATH="${HOME}/.local/bin:${PATH}"
  hermes config set model.provider deepseek >/dev/null
  hermes config set model.default deepseek-flash >/dev/null
  hermes config set model.base_url https://api.deepseek.com >/dev/null
  echo "Hermes CLI model: $(hermes config get model.provider) / $(hermes config get model.default)"
fi

echo "DeepSeek configured as Hermes model deepseek-flash."
echo "Wrote local .env (gitignored) and ${HERMES_ENV}."
echo "Do not commit API keys. For Vercel/Render, set DEEPSEEK_API_KEY in the host env."
