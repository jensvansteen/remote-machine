#!/usr/bin/env bash
# Hostname and sleep settings for a dedicated remote Mac.
set -euo pipefail

HOSTNAME="${HOSTNAME_OVERRIDE:-mac-mini-dev}"

echo "==> macOS settings"

sudo scutil --set HostName "$HOSTNAME"
sudo scutil --set ComputerName "$HOSTNAME"
sudo scutil --set LocalHostName "$HOSTNAME"
echo "Hostname: $HOSTNAME"

sudo pmset -a sleep 0 displaysleep 0 disksleep 0
sudo pmset -a powernap 0
sudo pmset -a tcpkeepalive 1
echo "Sleep disabled"

echo "Done."
