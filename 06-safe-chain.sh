#!/usr/bin/env bash
# Install Aikido safe-chain — wraps npm/npx/yarn/pnpm/pnpx/bun/bunx/pip/pip3/uv/poetry/pipx
# and checks every package against threat intel before install.
#
# Uses the official one-line installer (recommended by Aikido).
# Uses --ci mode: installs PATH shims instead of shell aliases. PATH shims work in
# any shell — including the subshells that agents (Claude Code, agent-device) spawn
# when they run `npm install` on your behalf, which is the whole point of running
# this on an agent-driven box.
#
# Install this BEFORE any other npm globals so it protects them.
set -euo pipefail

echo "==> safe-chain"

if ! command -v safe-chain >/dev/null 2>&1; then
  curl -fsSL https://github.com/AikidoSec/safe-chain/releases/latest/download/install-safe-chain.sh | sh -s -- --ci
else
  echo "safe-chain CLI already installed: $(safe-chain --version 2>/dev/null || echo 'unknown version')"
fi

# Persist PATH shims in .zshrc
if ! grep -q ".safe-chain/shims" "$HOME/.zshrc" 2>/dev/null; then
  cat <<'EOF' >> "$HOME/.zshrc"

# Aikido safe-chain — PATH shims wrap npm/yarn/pnpm/pip/uv/poetry/etc.
export PATH="$HOME/.safe-chain/shims:$HOME/.safe-chain/bin:$PATH"
EOF
  echo "Added safe-chain shims to PATH in ~/.zshrc"
fi

# Make active in the current shell so the verification below works
export PATH="$HOME/.safe-chain/shims:$HOME/.safe-chain/bin:$PATH"

# Configure: require packages to be at least 5 days (120h) old before install.
# Catches drive-by supply-chain attacks that get reported within a few days of
# publication. The default is 48h; we tighten to 120h for this box.
# Override per-install when you really need a fresh release:
#   SAFE_CHAIN_MINIMUM_PACKAGE_AGE_HOURS=0 npm install expo@latest
mkdir -p "$HOME/.safe-chain"
if [[ ! -f "$HOME/.safe-chain/config.json" ]]; then
  cat > "$HOME/.safe-chain/config.json" <<'EOF'
{
  "minimumPackageAgeHours": 120,
  "npm": {
    "minimumPackageAgeExclusions": [
      "@aikidosec/*"
    ]
  }
}
EOF
  echo "Wrote ~/.safe-chain/config.json (minimumPackageAgeHours=120)"
else
  echo "~/.safe-chain/config.json already exists — leaving as is"
fi

echo ""
echo "Installed. Reload shell first:  source ~/.zshrc"
echo "Then verify:  which npm    (should be ~/.safe-chain/shims/npm)"
echo "Test blocking: npm install safe-chain-test  (should be blocked as malware)"
echo "Done."
