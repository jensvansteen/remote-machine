#!/usr/bin/env bash
# Sanity checks on a fresh Mac mini.
#
# Note on terminal weirdness (garbled backspace, ^@, "missing terminal" warnings):
# this is almost always a TERMINFO mismatch from your laptop terminal (e.g.
# Ghostty sends TERM=xterm-ghostty which the server doesn't know). Fix on the
# LAPTOP side, not here. From the laptop:
#
#   infocmp -x xterm-ghostty | ssh <this-host> -- tic -x -
#
# Or permanently in Ghostty's config:
#   shell-integration-features = ssh-terminfo
#
set -euo pipefail

echo "==> Prereqs"

[[ "$(uname)" == "Darwin" ]] || { echo "macOS only."; exit 1; }
[[ "$(id -u)" -ne 0 ]] || { echo "Run as a normal user, not root."; exit 1; }

echo "macOS $(sw_vers -productVersion) on $(uname -m), user $(whoami)"

echo "Done."
