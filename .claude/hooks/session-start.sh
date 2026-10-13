#!/bin/bash
# Dev tools for Claude Code cloud sessions: what CLAUDE.md "Testing" runs, plus zsh to
# try the functions in stow/zsh. Never runs the playbooks themselves.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

# The container is root-owned and throwaway, no venv needed
pip install --quiet --root-user-action=ignore -r requirements.txt

if ! command -v zsh >/dev/null 2>&1; then
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq zsh >/dev/null
fi

# Same as CI (.github/workflows/lint.yml)
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo 'export ANSIBLE_INJECT_FACTS_AS_VARS=false' >> "$CLAUDE_ENV_FILE"
fi
