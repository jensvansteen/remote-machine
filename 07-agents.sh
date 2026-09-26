#!/usr/bin/env bash
# Global agent CLIs. Run AFTER 06-safe-chain.sh so npm installs are protected.
#
# Install methods checked against each tool's official docs:
# - Claude Code: Homebrew cask (officially supported by Anthropic). The native
#                curl installer auto-updates but puts the binary at ~/.local/bin
#                which adds PATH-management complexity. Brew cask is consistent
#                with the rest of the stack and lives in /opt/homebrew/bin which
#                is already on PATH. Trade-off: manual upgrades via
#                `brew upgrade claude-code` instead of auto-update.
# - Codex CLI:   npm global (the default install option in OpenAI's docs).
#                MUST use the scoped name `@openai/codex` — unscoped `codex`
#                is an unrelated 2012 package.
# - agent-device: npm global is the documented recommendation for agent workflows.
# - Argent:      npm global is fine; `argent init` runs per-project to register MCP.
set -euo pipefail

echo "==> Agent stack"


# Claude Code via Homebrew cask
if ! command -v claude >/dev/null 2>&1; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found. Run 02-homebrew.sh first."
    exit 1
  fi
  brew install --cask claude-code
else
  echo "claude already installed: $(claude --version 2>/dev/null || echo 'unknown')"
fi

# All three of the next tools need npm — provided by mise from 04-mise.sh.
# npm installs are protected by safe-chain from 06-safe-chain.sh.
if ! command -v npm >/dev/null 2>&1; then
  echo "npm not found. Run 04-mise.sh first."
  exit 1
fi

# Codex CLI (OpenAI) — npm scoped package; latest tag for upgrades
command -v codex >/dev/null 2>&1 && echo "codex already installed — skipping CLI install" || npm install -g @openai/codex@latest

# agent-device (Callstack) — multi-platform device automation for agents
command -v agent-device >/dev/null 2>&1 && echo "agent-device already installed — skipping" || npm install -g agent-device@latest

# Argent (Software Mansion) — RN-native iOS simulator profiling
command -v argent >/dev/null 2>&1 && echo "argent already installed — skipping" || npm install -g @swmansion/argent

# SimDeck — optional browser/CLI control for iOS simulators and Android emulators.
if [[ "${INSTALL_SIMDECK:-0}" == "1" ]]; then
  command -v simdeck >/dev/null 2>&1 && echo "simdeck already installed — skipping" || npm install -g simdeck@latest
else
  echo "SimDeck install skipped by choice"
fi

echo ""
echo "Installed:"
echo "  claude          $(claude --version 2>/dev/null || echo 'check manually')"
echo "  codex           $(codex --version 2>/dev/null || echo 'check manually')"
echo "  agent-device    $(agent-device --version 2>/dev/null || echo 'check manually')"
echo "  argent          $(argent --version 2>/dev/null || echo 'check manually')"
command -v herdr >/dev/null 2>&1 && echo "  herdr           $(herdr --version 2>/dev/null || echo 'installed')"
if command -v simdeck >/dev/null 2>&1; then echo "  simdeck         $(simdeck --version 2>/dev/null || echo 'installed')"; fi
echo ""
echo "Per-project setup:"
echo "  argent init     # registers Argent's MCP server in the project"
if command -v simdeck >/dev/null 2>&1; then
  echo "  simdeck pair    # pair a browser or SimDeck mobile app over Tailscale"
fi
echo ""
echo "Auth flows (one-time, run each in a fresh shell):"
echo "  claude          # opens Anthropic OAuth"
echo "  codex           # sign in with ChatGPT (Plus/Pro) or API key"
echo "Done."
