#!/usr/bin/env bash
# Install or upgrade to the latest Xcode via `xcodes` in the foreground CLI.
# Handles three scenarios cleanly:
#   1. Fresh box with no Xcode             -> installs latest
#   2. Pre-provisioned box (Scaleway etc.) -> upgrades from old Xcode to latest
#   3. Already on latest                    -> fast no-op, just selects + accepts license
#
# Long-running on scenarios 1 and 2 — ~30-60 min for the ~10 GB download.
#
# Apple ID auth: xcodes prompts for Apple ID credentials before it downloads.
set -euo pipefail

echo "==> Xcode"

# Ensure command-line developer tools are present (xcodes depends on them).
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install || true
fi

# Install xcodes + aria2 if missing. Homebrew prereq from 02-homebrew.sh.
# xcodes lives in homebrew-core — no third-party tap needed.
if ! command -v xcodes >/dev/null 2>&1; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found. Run 02-homebrew.sh first."
    exit 1
  fi
  brew install xcodes aria2
fi

# Authenticate in the current CLI. xcodes caches credentials in Keychain so
# subsequent runs usually do not prompt.
echo ""
echo "Verifying Apple ID auth (xcodes prompts the first time; subsequent runs use Keychain)..."
xcodes list >/dev/null
echo "Apple ID OK."
echo ""

# Show what's already installed (useful with pre-provisioned boxes).
echo "Currently installed Xcode versions:"
xcodes installed 2>/dev/null || echo "  (none)"
echo ""

# Run in this CLI: progress and any credential prompt stay visible. If an SSH
# connection drops, re-run this script; xcodes resumes/reuses completed work.
echo "Installing/selecting latest Xcode in this CLI."
echo "This can take 30–60 minutes; keep the command running."
xcodes install --latest --select
sudo xcodebuild -license accept 2>/dev/null || true

echo "Xcode install/upgrade complete."
echo ""
echo "After it finishes you can prune older versions to save disk:"
echo "  xcodes installed"
echo "  xcodes uninstall <old-version>"
