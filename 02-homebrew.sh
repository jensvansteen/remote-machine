#!/usr/bin/env bash
# Install Homebrew (if missing) and apply the Brewfile.
set -euo pipefail

echo "==> Homebrew"

# A non-login bootstrap shell may not have loaded ~/.zprofile yet, even when
# Homebrew is already installed at its usual Apple silicon location.
if ! command -v brew >/dev/null 2>&1 && [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "Already installed at $(command -v brew)"
fi

if ! grep -qF 'eval "$(/opt/homebrew/bin/brew shellenv)"' "$HOME/.zprofile" 2>/dev/null; then
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
fi

cd "$(dirname "$0")"
brew bundle install --file=./Brewfile

install_cask_if_missing() {
  local cask="$1" app="$2" minimum_major="${3:-}"
  if [[ -d "/Applications/$app.app" ]] || [[ -d "$HOME/Applications/$app.app" ]] || brew list --cask "$cask" >/dev/null 2>&1; then
    echo "$app already installed — skipping"
    return 0
  fi
  if [[ -n "$minimum_major" ]]; then
    local macos_major
    macos_major="$(sw_vers -productVersion | cut -d. -f1)"
    if (( macos_major < minimum_major )); then
      echo "Skipping $app: macOS $minimum_major or newer is required."
      return 0
    fi
  fi
  brew install --cask "$cask"
}

install_cask_if_missing google-chrome "Google Chrome"
install_cask_if_missing paper-design Paper 12
install_cask_if_missing orbstack OrbStack 14
install_cask_if_missing claude Claude 13
install_cask_if_missing chatgpt ChatGPT 14

echo "Done."
