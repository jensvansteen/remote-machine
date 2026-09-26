#!/usr/bin/env bash
# Shell customizations: starship prompt + Remote Machine helpers (wt, wt-pr, ...).
#
# Wires three things into ~/.zshrc:
#   1. starship init  — fast cross-shell prompt with prominent SSH hostname so
#      you always know which machine you're commanding
#   2. shell-helpers.sh source — exposes `wt`, `wt-pr`, `wt-rm`, `wt-ls`,
#      `code`, `rn-start`, `rn-ios`, `rn-android`
#   3. starship.toml — drops to ~/.config/ if not already customized
#
# Idempotent — safe to re-run.
set -euo pipefail

echo "==> Shell setup"

DEV_SETUP_DIR="$(cd "$(dirname "$0")" && pwd)"

if ! command -v starship >/dev/null 2>&1; then
  echo "starship not found. Run 02-homebrew.sh first." >&2
  exit 1
fi

# 1. Init starship in zsh. Append after any mise/safe-chain PATH exports so
#    starship sees the fully-built PATH.
if ! grep -q 'starship init zsh' "$HOME/.zshrc" 2>/dev/null; then
  cat <<'EOF' >> "$HOME/.zshrc"

# Starship prompt — shows SSH hostname so you always know which machine you're on
eval "$(starship init zsh)"
EOF
  echo "Added starship init to ~/.zshrc"
else
  echo "starship init already in ~/.zshrc"
fi

# 2. Drop the repo's starship config to ~/.config (preserve any existing customizations)
mkdir -p "$HOME/.config"
if [[ ! -f "$HOME/.config/starship.toml" ]]; then
  cp "$DEV_SETUP_DIR/starship.toml" "$HOME/.config/starship.toml"
  echo "Installed ~/.config/starship.toml"
else
  echo "~/.config/starship.toml already exists — leaving as-is"
fi

# 3. Source shell-helpers.sh (wt, wt-pr, wt-rm, wt-ls, code, rn-*)
HELPERS_LINE="source $DEV_SETUP_DIR/shell-helpers.sh"
if ! grep -qF "$HELPERS_LINE" "$HOME/.zshrc" 2>/dev/null; then
  cat <<EOF >> "$HOME/.zshrc"

# Remote Machine shell helpers: wt, wt-pr, wt-rm, wt-ls, code, rn-start, rn-ios, rn-android
$HELPERS_LINE
EOF
  echo "Added shell-helpers source to ~/.zshrc"
else
  echo "shell-helpers source already in ~/.zshrc"
fi

echo ""
echo "Done. Reload: source ~/.zshrc   (or just exit + re-SSH)"
echo ""
echo "  Prompt now shows:   <user>@<host>:<dir> [git-branch] ❯"
echo "  Worktree helpers:   wt <name>            create worktree and switch to it"
echo "                      wt <name> HEAD       branch from current HEAD instead of origin/main"
echo "                      wt <name> HEAD -a claude   also launch claude in the new session"
echo "                      wt-pr <pr-number>    check out a GitHub PR and switch to it"
echo "                      wt-rm <name>         tear down (use --force to drop branch too)"
echo "                      wt-ls                list worktrees"
