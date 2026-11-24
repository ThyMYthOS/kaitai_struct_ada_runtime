#!/bin/bash
# SessionStart hook for Claude Code cloud sessions: installs the toolchain.
# What is installed, and at which versions, is in scripts/install-toolchain.sh.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
   exit 0
fi

exec "${CLAUDE_PROJECT_DIR:-.}/scripts/install-toolchain.sh"
