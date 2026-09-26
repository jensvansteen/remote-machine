#!/usr/bin/env bash
# Download/update the setup repository and start its interactive bootstrap.
set -euo pipefail

REPO_URL="https://github.com/jensvansteen/remote-machine.git"
INSTALL_DIR="${REMOTE_MACHINE_DIR:-$HOME/Projects/remote-machine}"

mkdir -p "$(dirname "$INSTALL_DIR")"

if [[ -d "$INSTALL_DIR/.git" ]]; then
  CURRENT_REMOTE="$(git -C "$INSTALL_DIR" remote get-url origin 2>/dev/null || true)"
  case "$CURRENT_REMOTE" in
    "$REPO_URL"|"git@github.com:jensvansteen/remote-machine.git") ;;
    *)
      echo "Refusing to update $INSTALL_DIR: origin is '$CURRENT_REMOTE'." >&2
      echo "Set REMOTE_MACHINE_DIR to an empty path to install a separate copy." >&2
      exit 1
      ;;
  esac
  if [[ -n "$(git -C "$INSTALL_DIR" status --porcelain)" ]]; then
    echo "Refusing to update $INSTALL_DIR: it has local changes or untracked files." >&2
    exit 1
  fi
  if [[ "$(git -C "$INSTALL_DIR" branch --show-current)" != main ]]; then
    echo "Refusing to update $INSTALL_DIR: check out main first." >&2
    exit 1
  fi
  previous_remote_tree="$(git -C "$INSTALL_DIR" rev-parse --verify 'refs/remotes/origin/main^{tree}' 2>/dev/null || true)"
  current_tree="$(git -C "$INSTALL_DIR" rev-parse 'HEAD^{tree}')"
  echo "Updating setup repository in $INSTALL_DIR..."
  git -C "$INSTALL_DIR" fetch origin main
  fetched_commit="$(git -C "$INSTALL_DIR" rev-parse FETCH_HEAD)"
  if [[ "$(git -C "$INSTALL_DIR" rev-parse HEAD)" == "$fetched_commit" ]]; then
    echo "Setup repository is already current."
  elif git -C "$INSTALL_DIR" merge-base --is-ancestor HEAD "$fetched_commit"; then
    git -C "$INSTALL_DIR" merge --ff-only "$fetched_commit"
  elif [[ -n "$previous_remote_tree" && "$current_tree" == "$previous_remote_tree" ]] &&
       [[ "$(git -C "$INSTALL_DIR" rev-list --count HEAD)" == 1 ]] &&
       [[ "$(git -C "$INSTALL_DIR" rev-list --count "$fetched_commit")" == 1 ]]; then
    # The published one-commit repo may have a rewritten root commit. Only
    # replace a pristine checkout of the previously fetched remote tree.
    git -C "$INSTALL_DIR" switch -C main "$fetched_commit"
  else
    echo "Refusing to replace local commits in $INSTALL_DIR. Review its Git history manually." >&2
    exit 1
  fi
elif [[ -e "$INSTALL_DIR" ]]; then
  echo "$INSTALL_DIR exists and is not a Git checkout. Set REMOTE_MACHINE_DIR to another path." >&2
  exit 1
else
  echo "Downloading setup repository to $INSTALL_DIR..."
  git clone --branch main --single-branch "$REPO_URL" "$INSTALL_DIR"
fi

if [[ ! -e /dev/tty ]]; then
  echo "An interactive terminal is required. Run this from a terminal session." >&2
  exit 1
fi

exec /bin/bash "$INSTALL_DIR/bootstrap.sh" "$@" </dev/tty
