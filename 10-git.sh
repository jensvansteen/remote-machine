#!/usr/bin/env bash
# Safe Git defaults and identity. Authentication and signing remain user-managed.
set -euo pipefail

echo "==> Git"
command -v git >/dev/null 2>&1 || { echo "git not found. Run 02-homebrew.sh first."; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "gh not found. Run 02-homebrew.sh first."; exit 1; }

git config --global pull.rebase false
git config --global init.defaultBranch main
git config --global push.autoSetupRemote true
if [[ -z "$(git config --global user.name 2>/dev/null)" ]]; then
  read -r -p "Git user.name: " GIT_NAME
  git config --global user.name "$GIT_NAME"
fi
if [[ -z "$(git config --global user.email 2>/dev/null)" ]]; then
  read -r -p "Git user.email: " GIT_EMAIL
  git config --global user.email "$GIT_EMAIL"
fi

echo "Current Git identity: $(git config --global user.name) <$(git config --global user.email)>"
echo "Authentication and commit signing are not changed by this setup."
echo "Configure GitHub access on this Mac with: gh auth login"
echo "Done."
