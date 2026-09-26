#!/usr/bin/env bash
# Guided orchestrator for setting up a fresh remote Mac mini.
#
# Runs the numbered scripts in the correct order, handles the interactive auth
# points (Tailscale, Git identity), and prints clear status at
# each phase so a human (or agent) can see where they are.
#
# This script is IDEMPOTENT — re-running it from any point skips the work
# that's already been done. Safe to re-run if something fails partway through.
#
# Usage:
#   ./bootstrap.sh                    # guided full bootstrap
#   ./bootstrap.sh --skip-xcode       # skip Xcode (already installed)
#   ./bootstrap.sh --skip-android     # skip Android SDK
#   ./bootstrap.sh --clipboard-handoff # prepare SSH drop folder for Hammerspoon
#   ./bootstrap.sh --resume-from 06   # start from script 06 onwards
#
# Designed to be run AFTER:
#   1. Your provider has provisioned the box and given you console or terminal access
#   2. You've run install.sh or cloned this repository
#   3. You've fixed terminfo from your laptop:
#        infocmp -x xterm-ghostty | ssh user@mini -- tic -x -
#
# Interactive points to know about:
#   - 05-tailscale.sh: prints a Tailscale sign-in URL when needed
#   - 10-git.sh: asks for Git identity if it is not already configured

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Flags
SKIP_XCODE=0
SKIP_ANDROID=0
SETUP_CLIPBOARD=0
INSTALL_SIMDECK=0
RESUME_FROM=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-xcode)    SKIP_XCODE=1; shift ;;
    --skip-android)  SKIP_ANDROID=1; shift ;;
    --clipboard-handoff) SETUP_CLIPBOARD=1; shift ;;
    --resume-from)   RESUME_FROM="$2"; shift 2 ;;
    -h|--help)
      sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown flag: $1" >&2
      exit 1
      ;;
  esac
done

# Color helpers
BOLD=$'\033[1m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
BLUE=$'\033[34m'
RESET=$'\033[0m'

print_phase() {
  echo ""
  echo "${BOLD}${BLUE}===========================================================${RESET}"
  echo "${BOLD}${BLUE}  Phase $1: $2${RESET}"
  echo "${BOLD}${BLUE}===========================================================${RESET}"
  echo ""
}

print_done() {
  echo "${GREEN}✓ $1${RESET}"
}

print_skip() {
  echo "${YELLOW}↷ Skipping: $1${RESET}"
}

refresh_setup_environment() {
  # Each phase runs as a child process, so PATH changes made there do not reach
  # this orchestrator. Refresh it before a resumed run and after tool installs.
  local brew_bin
  for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$brew_bin" ]]; then
      eval "$("$brew_bin" shellenv)"
      break
    fi
  done
  if [[ -d "$HOME/.local/share/mise/shims" ]]; then
    export PATH="$HOME/.local/share/mise/shims:$PATH"
  fi
  if [[ -d "$HOME/.safe-chain/shims" ]]; then
    export PATH="$HOME/.safe-chain/shims:$HOME/.safe-chain/bin:$PATH"
  fi
}

run_step() {
  local num="$1"
  local script="$2"
  local desc="$3"

  # Resume-from handling: skip everything before the resume point
  if [[ -n "$RESUME_FROM" ]] && [[ "$num" < "$RESUME_FROM" ]]; then
    print_skip "$num — $desc (resume-from=$RESUME_FROM)"
    return 0
  fi

  print_phase "$num" "$desc"

  if [[ -x "$SCRIPT_DIR/$script" ]]; then
    "$SCRIPT_DIR/$script"
  else
    /bin/bash "$SCRIPT_DIR/$script"
  fi

  print_done "$num — $desc"
}

# ============================================================
# Bootstrap sequence
# ============================================================

refresh_setup_environment
echo "${BOLD}Remote Mac setup — guided bootstrap${RESET}"
echo "Started: $(date)"
echo ""
DEFAULT_HOSTNAME="${HOSTNAME_OVERRIDE:-$(hostname -s)}"
read -r -p "Machine name [$DEFAULT_HOSTNAME]: " ANSWER_HOSTNAME
HOSTNAME_OVERRIDE="${ANSWER_HOSTNAME:-$DEFAULT_HOSTNAME}"
export HOSTNAME_OVERRIDE
export TAILSCALE_HOSTNAME="${TAILSCALE_HOSTNAME:-$HOSTNAME_OVERRIDE}"

if [[ $SKIP_XCODE -eq 0 ]]; then
  read -r -p "Install Xcode for iOS builds? [Y/n] " ANSWER_XCODE
  [[ "$ANSWER_XCODE" =~ ^[Nn]$ ]] && SKIP_XCODE=1
fi
if [[ $SKIP_ANDROID -eq 0 ]]; then
  read -r -p "Install Android SDK for Android builds? [Y/n] " ANSWER_ANDROID
  [[ "$ANSWER_ANDROID" =~ ^[Nn]$ ]] && SKIP_ANDROID=1
fi
if [[ $SETUP_CLIPBOARD -eq 0 ]]; then
  read -r -p "Prepare SSH folder for laptop-to-mini file handoff? [y/N] " ANSWER_CLIPBOARD
  [[ "$ANSWER_CLIPBOARD" =~ ^[Yy]$ ]] && SETUP_CLIPBOARD=1
fi
read -r -p "Install the optional SimDeck CLI for simulator control? [y/N] " ANSWER_SIMDECK
[[ "$ANSWER_SIMDECK" =~ ^[Yy]$ ]] && INSTALL_SIMDECK=1

HOSTNAME_OVERRIDE="${HOSTNAME_OVERRIDE:-$(hostname -s)}"
export INSTALL_SIMDECK
echo "Setup plan:"
echo "  Machine:       $HOSTNAME_OVERRIDE"
echo "  Xcode / iOS:   $([[ $SKIP_XCODE -eq 0 ]] && echo install || echo skip)"
echo "  Android SDK:   $([[ $SKIP_ANDROID -eq 0 ]] && echo install || echo skip)"
echo "  File handoff:  $([[ $SETUP_CLIPBOARD -eq 1 ]] && echo prepare || echo skip)"
echo "  SimDeck CLI:   $([[ $INSTALL_SIMDECK -eq 1 ]] && echo install || echo skip)"
echo "  Agent desktop: Claude + ChatGPT (Codex mode), when supported by this macOS version"
echo "  Long installs: visible in this CLI; tools already present are kept/skipped"
echo "  SSH access:    Tailscale SSH using your Tailscale identity"
echo ""
echo "Follow the setup and laptop checklist in this repo's README.md."
echo "Interactive steps when needed: Tailscale browser sign-in, Git identity, Apple ID for Xcode."
echo "Press Enter to continue, or Ctrl+C to abort..."
read -r

run_step 01 01-prereqs.sh    "Sanity checks (macOS, user, terminfo notes)"
run_step 02 02-homebrew.sh   "Homebrew + tools (OrbStack, Chrome, Paper, Claude, ChatGPT/Codex, git, gh, watchman)"
refresh_setup_environment
run_step 03 03-macos.sh      "Hostname, sleep prevention"
run_step 04 04-mise.sh       "mise + node@24, python@3.13, java@temurin-17, ruby@3.3"
refresh_setup_environment
run_step 05 05-tailscale.sh  "Tailscale SSH service + browser sign-in"
run_step 06 06-safe-chain.sh "Aikido safe-chain (npm/pip wrapper, 5-day age policy)"
refresh_setup_environment
run_step 07 07-agents.sh     "Claude Code, Claude desktop, ChatGPT desktop with Codex, agent-device, Argent"

# Keep long downloads in this CLI so progress and interactive prompts remain visible.
if [[ $SKIP_XCODE -eq 0 ]]; then
  echo ""
  echo "${YELLOW}Note: Xcode downloads can take a while. Leave this command running.${RESET}"
  echo ""
  run_step 08 08-xcode.sh    "Xcode (latest via xcodes)"
else
  print_skip "08 — Xcode (--skip-xcode)"
fi

if [[ $SKIP_ANDROID -eq 0 ]]; then
  run_step 09 09-android.sh  "Android SDK (cmdline-tools + API 36)"
else
  print_skip "09 — Android SDK (--skip-android)"
fi

run_step 10 10-git.sh        "Git identity and safe defaults"
run_step 11 11-osquery.sh    "osquery (forensic visibility)"

run_step 14 14-shell.sh      "Starship prompt + shell helpers (wt, wt-pr, code, rn-*)"

if [[ $SETUP_CLIPBOARD -eq 1 ]]; then
  run_step 16 16-clipboard-handoff.sh "Prepare SSH folder for laptop-to-mini file handoff"
else
  print_skip "16 — SSH file handoff (not selected)"
fi

# ============================================================
# Done
# ============================================================

cat <<EOF

${BOLD}${GREEN}Tool setup complete.${RESET}

Connect from your laptop using Tailscale SSH, then add the host to your agent apps.
The README covers tailnet access rules and migrating an existing GUI installation.

Verification commands you should run when these finish:
  claude --version
  codex --version
  open -a ChatGPT     # desktop app; select Codex from its mode menu
  open -a Claude      # Claude desktop app
  agent-device --version
  argent --version
  node --version  &&  python3 --version  &&  java --version
  adb --version   &&  xcodebuild -version
  which npm     # should be ~/.safe-chain/shims/npm

Finished: $(date)
EOF
