#!/usr/bin/env bash
# Prepare the mini-side drop folder for direct Hammerspoon -> SSH/SCP handoff.
set -euo pipefail

MINI_HOST="${REMOTE_MACHINE_SSH_ALIAS:-mac-mini-dev}"
echo "==> Remote file handoff folder"
# This step is normally run on the mini itself, so only create the destination.
mkdir -p "$HOME/Sync/screenshots"
chmod 700 "$HOME/Sync/screenshots"
echo "Created $HOME/Sync/screenshots (mode 700)."
echo "On your laptop, ensure SSH alias '$MINI_HOST' reaches this Mac."
echo "Then follow FILE-HANDOFF.md to install Hammerspoon and configure its hotkey."
