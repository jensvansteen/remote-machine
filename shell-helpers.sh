# Shell helpers for the agent-driven workflow.
# Source this from ~/.zshrc using the checkout path where you installed it.

# VS Code Remote CLI — make the `code` binary discoverable from any shell.
# The new (2026+) install path is .vscode-server/cli/servers/Stable-<commit>/...
if [ -d "$HOME/.vscode-server/cli/servers" ]; then
  __vscode_latest=$(ls -t "$HOME/.vscode-server/cli/servers" 2>/dev/null | head -1)
  [ -n "$__vscode_latest" ] && export PATH="$HOME/.vscode-server/cli/servers/$__vscode_latest/server/bin/remote-cli:$PATH"
  unset __vscode_latest
fi

# `code` — print a clickable vscode:// URL that opens this path in VS Code on
# your laptop. Click the link in Ghostty (or any OSC 8 -capable terminal) and
# macOS dispatches the URL handler to VS Code locally.
#
# No new SSH access required. No listeners. No attack surface.
# Just one click vs zero clicks.
#
# The remote host defaults to this machine's Tailscale hostname, which matches
# the laptop's ~/.ssh/config alias (both come from MagicDNS) — so the link works
# unedited on every mini. Falls back to the local hostname if Tailscale/jq are
# unavailable. Override explicitly if needed:  CODE_REMOTE_HOST=my-other-mini code .
# rn-start — start Expo/Metro on the project's configured port.
# Reads RCT_METRO_PORT from .envrc (via direnv), defaults to 8081.
rn-start() {
  local port="${RCT_METRO_PORT:-8081}"
  echo "Starting Metro on port $port..."
  npx expo start --port "$port" "$@"
}

# rn-ios — boot the project's configured simulator and run the app on it.
# Reads RN_SIMULATOR from .envrc (via direnv), defaults to "iPhone 16".
rn-ios() {
  local sim="${RN_SIMULATOR:-iPhone 16}"
  local port="${RCT_METRO_PORT:-8081}"
  echo "Booting $sim..."
  xcrun simctl boot "$sim" 2>/dev/null || true
  open -a Simulator   # bring sim window up
  npx expo run:ios --device "$sim" --port "$port" "$@"
}

# rn-android — same idea for Android emulator.
rn-android() {
  local device="${RN_ANDROID_DEVICE:-emulator-5554}"
  local port="${RCT_METRO_PORT:-8081}"
  echo "Running on $device (port $port)..."
  npx expo run:android --device "$device" --port "$port" "$@"
}

code() {
  # Prefer an explicit override; else this machine's Tailscale hostname (matches
  # the laptop's ~/.ssh/config alias); else fall back to the local hostname.
  local remote="${CODE_REMOTE_HOST:-}"
  if [ -z "$remote" ]; then
    remote="$(tailscale status --json 2>/dev/null | jq -r '.Self.HostName // empty' 2>/dev/null)"
  fi
  remote="${remote:-$(hostname -s)}"
  local path="${1:-.}"
  local abs_path
  abs_path="$(cd "$path" && pwd)" || return 1
  local url="vscode://vscode-remote/ssh-remote+${remote}${abs_path}"

  # Copy URL to laptop clipboard via OSC 52 (works through Ghostty,
  # zero dependency on clickable hyperlink rendering).
  printf '\e]52;c;%s\e\\' "$(printf '%s' "$url" | base64 | tr -d '\n')"

  # Also print the URL + OSC 8 wrap (clickable if your terminal supports it)
  printf '\e]8;;%s\e\\%s\e]8;;\e\\\n' "$url" "$url"

  echo "→ URL copied to clipboard. Either Cmd+click above, or:"
  echo "    Cmd+Space (Spotlight) → Cmd+V → Enter"
}

# wt — Create a git worktree, switch to it, and optionally launch an agent.
#
# Usage:
#   wt <name>                    -> branch feature/<name> from origin's default branch
#                                    (fetches first so you start from latest remote main)
#   wt <name> <base>             -> branch feature/<name> from <base> instead
#                                    (e.g. "wt feat-x HEAD" to use current branch)
#   wt <name> <base> -a claude   -> launch Claude Code in the new worktree
#   wt <name> <base> -a codex    -> launch Codex in the new worktree
#
# Default base = `origin/<default-branch>` (usually origin/main or origin/master)
# fetched fresh — keeps new branches grounded in the latest production code, not
# whatever you happen to have checked out.
#
# Layout: worktree goes to ../<project>-<name> (sibling of the repo).
wt() {
  local name="$1"
  local base="${2:-}"
  local agent=""

  # Parse optional -a flag (3rd or 4th arg)
  if [[ "${3:-}" == "-a" && -n "${4:-}" ]]; then
    agent="$4"
  fi

  if [[ -z "$name" ]]; then
    echo "Usage: wt <name> [base-branch] [-a claude|codex]" >&2
    return 1
  fi

  # Find the repo root + project name
  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Error: not in a git repo (cd into one first)" >&2
    return 1
  }
  local project_name
  project_name="$(basename "$repo_root")"

  # Strip any existing "-<previous-feature>" suffix from project name
  # (so `wt second` from inside proj-first creates proj-second, not proj-first-second)
  project_name="${project_name%-*}"

  local worktree_path
  worktree_path="$(dirname "$repo_root")/${project_name}-${name}"
  local branch="feature/${name}"

  # If no explicit base, default to origin's default branch (fetched fresh)
  if [[ -z "$base" ]]; then
    local default_ref
    default_ref="$(git -C "$repo_root" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)" || {
      # Remote tracking not set up — fall back to current HEAD
      echo "Warning: origin/HEAD not set, falling back to current HEAD as base."
      echo "         (Tip: run 'git remote set-head origin -a' once to enable origin/HEAD detection.)"
      base="HEAD"
    }
    if [[ -n "$default_ref" ]]; then
      base="$default_ref"
      echo "Fetching latest $base..."
      git -C "$repo_root" fetch origin "${default_ref#origin/}" || return 1
    fi
  fi

  # Create the worktree (creates the branch if missing)
  if [[ -d "$worktree_path" ]]; then
    echo "Worktree already exists at $worktree_path — reusing it"
  else
    echo "Creating worktree: $worktree_path on $branch from $base"
    git -C "$repo_root" worktree add "$worktree_path" -b "$branch" "$base" || return 1
  fi

  echo ""
  echo "  Worktree:  $worktree_path"
  echo "  Branch:    $branch"
  cd "$worktree_path" || return 1
  if [[ -n "$agent" ]]; then
    command -v "$agent" >/dev/null 2>&1 || { echo "$agent is not installed" >&2; return 1; }
    echo "Launching $agent in $worktree_path"
    "$agent"
  else
    echo "Switched to $worktree_path"
  fi
}

# wt-pr — Check out a GitHub PR into a worktree and switch to it.
#
# Usage:
#   wt-pr <number>              -> fetches PR, creates worktree 'pr-<number>'
#   wt-pr <number> -a claude    -> also launches Claude Code
#   wt-pr <number> -a codex     -> also launches Codex
#
# Works for PRs from forks too (uses GitHub's universal pull/N/head ref).
# Requires `gh` (GitHub CLI) authenticated for private repos.
wt-pr() {
  local pr="$1"
  local agent=""
  if [[ "${2:-}" == "-a" && -n "${3:-}" ]]; then
    agent="$3"
  fi

  if [[ -z "$pr" ]]; then
    echo "Usage: wt-pr <pr-number> [-a claude|codex]" >&2
    return 1
  fi
  if ! command -v gh >/dev/null 2>&1; then
    echo "Error: gh CLI not found. brew install gh" >&2
    return 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq not found. brew install jq" >&2
    return 1
  fi

  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Error: not in a git repo (cd into one first)" >&2
    return 1
  }
  local project_name
  project_name="$(basename "$repo_root")"
  project_name="${project_name%-*}"

  # Look up the PR — fails early if it doesn't exist or you're not authorized
  local pr_info pr_title pr_branch
  pr_info="$(gh pr view "$pr" --json title,headRefName 2>/dev/null)" || {
    echo "Error: PR #$pr not found or not visible to your gh auth" >&2
    return 1
  }
  pr_title="$(echo "$pr_info" | jq -r .title)"
  pr_branch="$(echo "$pr_info" | jq -r .headRefName)"

  local name="pr-${pr}"
  local worktree_path
  worktree_path="$(dirname "$repo_root")/${project_name}-${name}"
  local local_branch="${name}"

  # Fetch without moving a branch that might already be checked out in a worktree.
  echo "Fetching PR #$pr: $pr_title (from $pr_branch)"
  git -C "$repo_root" fetch origin "pull/${pr}/head" || return 1
  local pr_head
  pr_head="$(git -C "$repo_root" rev-parse FETCH_HEAD)" || return 1

  # Create the worktree
  if [[ -d "$worktree_path" ]]; then
    if [[ -n "$(git -C "$worktree_path" status --porcelain)" ]]; then
      echo "Worktree has local changes: $worktree_path. Review them before updating." >&2
      return 1
    fi
    if ! git -C "$worktree_path" merge-base --is-ancestor HEAD "$pr_head"; then
      echo "PR head diverged from $worktree_path. Review its commits before updating." >&2
      return 1
    fi
    git -C "$worktree_path" merge --ff-only "$pr_head" || return 1
  else
    if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$local_branch"; then
      echo "Branch $local_branch already exists; inspect it before creating a worktree." >&2
      return 1
    fi
    git -C "$repo_root" worktree add -b "$local_branch" "$worktree_path" "$pr_head" || return 1
  fi

  echo ""
  echo "  PR:       #$pr ($pr_title)"
  echo "  Branch:   $pr_branch"
  echo "  Worktree: $worktree_path"
  cd "$worktree_path" || return 1
  if [[ -n "$agent" ]]; then
    command -v "$agent" >/dev/null 2>&1 || { echo "$agent is not installed" >&2; return 1; }
    echo "Launching $agent in $worktree_path"
    "$agent"
  else
    echo "Switched to $worktree_path"
  fi
  echo "When done: wt-rm $name --force"
}

# wt-rm — Remove a worktree and optionally its local branch.
# Use after you've merged, abandoned, or finished reviewing.
#
# Usage:
#   wt-rm <name>           -> safe remove (refuses if uncommitted changes)
#   wt-rm <name> --force   -> force remove + delete the branch
#
# Auto-detects branch name from the worktree itself, so works for both
# `wt`-created (feature/<name>) and `wt-pr`-created (pr-<number>) worktrees.
wt-rm() {
  local name="$1"
  local force=""
  [[ "${2:-}" == "--force" ]] && force="--force"

  if [[ -z "$name" ]]; then
    echo "Usage: wt-rm <name> [--force]" >&2
    return 1
  fi


  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Error: not in a git repo" >&2
    return 1
  }
  local project_name
  project_name="$(basename "$repo_root")"
  project_name="${project_name%-*}"

  local worktree_path
  worktree_path="$(dirname "$repo_root")/${project_name}-${name}"

  if [[ -d "$worktree_path" ]]; then
    # Get branch name from worktree HEAD (works for both 'feature/x' and 'pr-N')
    local branch
    branch="$(git -C "$worktree_path" symbolic-ref --short HEAD 2>/dev/null || true)"

    git -C "$repo_root" worktree remove $force "$worktree_path" || return 1
    echo "Removed worktree $worktree_path"

    if [[ -n "$force" && -n "$branch" ]]; then
      git -C "$repo_root" branch -D "$branch" 2>/dev/null && echo "Deleted branch $branch"
    fi
  else
    echo "No worktree at $worktree_path"
  fi
}

# wt-ls — Show all current worktrees.
wt-ls() {
  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Error: not in a git repo" >&2
    return 1
  }

  echo "Worktrees:"
  git -C "$repo_root" worktree list
}
