#!/usr/bin/env bash
# Configure the open-source macOS service for identity-based Tailscale SSH.
set -euo pipefail

echo "==> Tailscale SSH"

# This phase can also run directly, before a new login shell has loaded brew.
for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [[ -x "$brew_bin" ]]; then
    eval "$("$brew_bin" shellenv)"
    break
  fi
done

SOCKET="/var/run/tailscaled.socket"
CLI_TAILSCALE=""

require_console() {
  if [[ -n "${SSH_CONNECTION:-}${SSH_CLIENT:-}" ]]; then
    echo "Run this phase from the Mac's provider console or independent Screen Sharing session." >&2
    echo "Enabling or switching Tailscale SSH can interrupt this SSH connection." >&2
    exit 1
  fi
}

# The GUI variant cannot host Tailscale SSH. Do not disconnect it automatically:
# the current desktop/terminal connection may depend on it.
for app_cli in /Applications/Tailscale.app/Contents/MacOS/Tailscale "$HOME/Applications/Tailscale.app/Contents/MacOS/Tailscale"; do
  [[ -x "$app_cli" ]] || continue
  app_status="$(TAILSCALE_BE_CLI=1 "$app_cli" status --json 2>/dev/null || true)"
  if ! grep -qE '"BackendState"[[:space:]]*:[[:space:]]*"(Stopped|NeedsLogin|NoState)"' <<< "$app_status"; then
    echo "The Tailscale GUI app is connected, starting, or its state could not be checked." >&2
    echo "In an independent provider desktop session, disconnect the app on THIS Mac, then rerun this phase." >&2
    echo "Keep your laptop's Tailscale app connected. See the README's app migration steps." >&2
    exit 1
  fi
done

# Prefer the formula's binary; a command on PATH may point to the GUI app.
if command -v brew >/dev/null 2>&1; then
  formula_prefix="$(brew --prefix tailscale 2>/dev/null || true)"
  if [[ -n "$formula_prefix" && -x "$formula_prefix/bin/tailscale" ]]; then
    CLI_TAILSCALE="$formula_prefix/bin/tailscale"
  fi
fi
for candidate in /opt/homebrew/bin/tailscale /usr/local/bin/tailscale; do
  if [[ -z "$CLI_TAILSCALE" && -x "$candidate" && -x "$(dirname "$candidate")/tailscaled" ]]; then
    CLI_TAILSCALE="$candidate"
  fi
done

if [[ -z "$CLI_TAILSCALE" ]]; then
  require_console
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found. Run 02-homebrew.sh first." >&2
    exit 1
  fi
  if ! brew install --formula tailscale; then
    echo "Could not install the CLI service. If Homebrew reports a GUI cask conflict, see the README migration steps." >&2
    exit 1
  fi
  CLI_TAILSCALE="$(brew --prefix tailscale)/bin/tailscale"
fi

ts() {
  sudo "$CLI_TAILSCALE" --socket="$SOCKET" "$@"
}

read_status() {
  daemon_status="$(ts status --json 2>/dev/null || true)"
  grep -q '"BackendState"' <<< "$daemon_status"
}

if ! read_status; then
  require_console
  if pgrep -x tailscaled >/dev/null 2>&1; then
    echo "An existing tailscaled process is not responding on $SOCKET." >&2
    echo "Restore that service before rerunning; a second service will not be started." >&2
    exit 1
  fi
  # Preserve a previously installed custom service instead of adding Homebrew's.
  if [[ -f /Library/LaunchDaemons/com.tailscale.tailscaled.plist ]]; then
    if sudo launchctl print system/com.tailscale.tailscaled >/dev/null 2>&1; then
      sudo launchctl kickstart system/com.tailscale.tailscaled
    else
      sudo launchctl bootstrap system /Library/LaunchDaemons/com.tailscale.tailscaled.plist
    fi
  elif command -v brew >/dev/null 2>&1 && brew list --formula tailscale >/dev/null 2>&1; then
    sudo "$(command -v brew)" services start tailscale
  else
    echo "Restore the existing tailscaled service, then rerun this phase." >&2
    exit 1
  fi
  for attempt in 1 2 3 4 5; do
    if read_status; then break; fi
    sleep 1
  done
  if ! read_status; then
    echo "The Tailscale service did not become ready. Check its service logs and rerun." >&2
    exit 1
  fi
fi

# Keep existing routes, DNS, hostname, and other preferences. A bare 'up'
# connects/signs in without the non-default-flag conflict caused by 'up --ssh'.
if ! grep -qE '"BackendState"[[:space:]]*:[[:space:]]*"Running"' <<< "$daemon_status"; then
  require_console
  echo "Sign into the same tailnet as your laptop using the URL printed below."
  ts up
  if ! read_status || ! grep -qE '"BackendState"[[:space:]]*:[[:space:]]*"Running"' <<< "$daemon_status"; then
    echo "Finish Tailscale sign-in/device approval, then rerun this phase." >&2
    exit 1
  fi
fi

# A rerun with SSH enabled should not disrupt an established connection.
ssh_preferences="$(ts debug prefs)"
if grep -qE '"RunSSH"[[:space:]]*:[[:space:]]*true' <<< "$ssh_preferences"; then
  echo "Tailscale SSH is already enabled."
elif grep -qE '"RunSSH"[[:space:]]*:[[:space:]]*false' <<< "$ssh_preferences"; then
  require_console
  ts set --ssh
else
  echo "Could not determine Tailscale SSH settings. Check the installed CLI/service versions." >&2
  exit 1
fi

# Confirm the local setting; only a laptop connection verifies the access policy.
ssh_preferences="$(ts debug prefs)"
if ! grep -qE '"RunSSH"[[:space:]]*:[[:space:]]*true' <<< "$ssh_preferences"; then
  echo "Tailscale SSH was not enabled. Review the command output and rerun." >&2
  exit 1
fi

tailnet_ip="$(ts ip -4 | sed -n '1p')"
echo "Tailscale SSH enabled. From your laptop, connect with: ssh $(id -un)@$tailnet_ip"
echo "Your tailnet's access rules must allow your identity to reach this Mac and log in as $(id -un)."
echo "Browser reauthentication may be requested; no Mac password or personal SSH key is needed for this login."
echo "Keep the GUI app disconnected on this Mac; keep it connected on your laptop."
echo "Test a fresh laptop connection before updating Codex, Claude, Herdr, or VS Code hosts."
echo "Done."
