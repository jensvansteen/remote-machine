#!/usr/bin/env bash
# Install mise, activate it in the shell, and install runtimes from mise.toml.
set -euo pipefail

echo "==> mise"

# Install mise if missing. Homebrew is the prereq (from 02-homebrew.sh).
if ! command -v mise >/dev/null 2>&1; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found. Run 02-homebrew.sh first."
    exit 1
  fi
  brew install mise
fi

# Use mise shim mode (static PATH) instead of activation mode (dynamic precmd hook).
# Reason: activation mode re-prepends mise paths to PATH on every prompt, which
# defeats safe-chain's PATH-based shim interception (see 06-safe-chain.sh).
# Shim mode is friendlier when other tools also want to be early in PATH.
if grep -q "mise activate" "$HOME/.zshrc" 2>/dev/null; then
  # Migrate from activation mode to shim mode in place
  sed -i '' 's|eval "$(mise activate zsh)"|export PATH="$HOME/.local/share/mise/shims:$PATH"|' "$HOME/.zshrc"
  echo "Migrated ~/.zshrc from mise activate-mode to shim-mode"
elif ! grep -q ".local/share/mise/shims" "$HOME/.zshrc" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/share/mise/shims:$PATH"' >> "$HOME/.zshrc"
  echo "Added mise shims to PATH in ~/.zshrc"
else
  echo "mise shim PATH already in ~/.zshrc"
fi
export PATH="$HOME/.local/share/mise/shims:$PATH"

# Use the mise.toml in this directory as the global config. Trust it BEFORE
# any mise command that reads it (including reshim), otherwise mise refuses
# to parse the config and aborts.
cd "$(dirname "$0")"
mise trust
mise reshim                                 # ensure shims exist for installed tools
mise install                # installs everything listed in ./mise.toml
mise use --global node@24
mise use --global python@3.13
mise use --global java@temurin-17
mise use --global ruby@3.3

echo "Installed:"
mise list

echo "Done."
