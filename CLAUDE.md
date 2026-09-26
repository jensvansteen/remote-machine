# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A reproducible bootstrap for a cloud-hosted Mac mini dev box (Scaleway, OakHost, MacStadium, etc.). It is **not** an application — it is a sequence of standalone bash scripts plus shell/Hammerspoon config that can be cloned onto a fresh mini and run in order. `install.sh` is the one-line entry point; `bootstrap.sh` asks a few configuration questions, then orchestrates the scripts.

There are no `build`, `test`, or `lint` commands. The [Remote Machine setup skill](.agents/skills/remote-machine-setup/SKILL.md) has the agent workflow; it is also exposed in `.claude/skills` through a symlink. Use `bash -n` to check shell syntax when editing scripts; a full bootstrap changes the host and requires an intended target Mac.

## The numbered-script architecture

Scripts `01-prereqs.sh` through `16-clipboard-handoff.sh` are sequenced phases of a one-time setup; `16-clipboard-handoff.sh` is optional. `bootstrap.sh` is the orchestrator. Each script:

1. **Is idempotent** — re-running must be a no-op when its state already exists. Check before mutating (`grep -q`, `command -v`, `[[ -e ... ]]`, `if ! ... then`).
2. **Is independently runnable** — never assume the prior script's in-memory state; re-read config from disk.
3. **Sets `set -euo pipefail`** at the top.
4. **Prints next-step instructions** when human action is required (Tailscale auth URL, Apple ID prompt, etc.).

Phase 05 configures Tailscale SSH through the open-source macOS service. It reuses an existing daemon or installs the Homebrew formula and starts its service when absent. It stops for an active GUI app and directs the owner to migrate from an independent desktop session. Preserve existing preferences, use an explicit daemon socket, and never start a second service over an existing one.

Each phase runs as a child process. PATH exports inside a numbered script do not reach `bootstrap.sh`; keep its `refresh_setup_environment` calls after installing Homebrew, mise, or safe-chain so later phases can find their tools.

When adding a new script:
- Append a `run_step` call in `bootstrap.sh` in the right slot
- Update the relevant guidance in the [setup skill](.agents/skills/remote-machine-setup/SKILL.md) and README
- Document any interactive pause points in the script and README

## Three layers of documentation — keep in sync

| File | Audience | When to update |
|---|---|---|
| [README.md](README.md) | Human reading the repo | When the "what's where" table, laptop checklist, or manual steps change |
| [Remote Machine setup skill](.agents/skills/remote-machine-setup/SKILL.md) | Agents helping with setup or recovery | When the agent workflow, constraints, or recovery path changes |
| [FILE-HANDOFF.md](FILE-HANDOFF.md), [SLOTS.md](SLOTS.md) | Both | Companion features (Hammerspoon SCP handoff, parallel-project port allocation) |

Read the setup skill's access and recovery guidance before changing `05-tailscale.sh`, `09-android.sh`, or `11-osquery.sh`. Preserve existing Tailscale daemon state and preferences; never reset a configured node or disconnect the GUI automatically. An already configured daemon should be safe to reuse from SSH.

## Shell helpers and runtime model

[shell-helpers.sh](shell-helpers.sh) defines functions sourced into the user's `~/.zshrc` by `14-shell.sh`. The key abstractions:

- **`wt` / `wt-pr` / `wt-rm` / `wt-ls`** — direct CLI Git worktree helpers. `wt` and `wt-pr` create or reuse a worktree and switch the current shell into it; `-a claude|codex` launches the chosen agent in the foreground.
- **`rn-start` / `rn-ios` / `rn-android`** — React Native workflows that read per-project `.envrc` (direnv) to pick Metro port and simulator or emulator from a "slot" (see [SLOTS.md](SLOTS.md)). Pin a project to one via its `.envrc`.
- **`code`** — prints an OSC 52 / OSC 8 `vscode://` URL so clicking opens the path in VS Code on the laptop via Remote-SSH. No new ports, no listener.

When adding a new helper, source it from `shell-helpers.sh` (not a new file) so `14-shell.sh`'s single `source` line still picks it up.

## Pinned versions: read [mise.toml](mise.toml) before bumping Python

Python's minor version is configured in `mise.toml`; adjust it there when changing the runtime.

## Brewfile philosophy

[Brewfile](Brewfile) holds general-purpose Homebrew formulae, including Herdr. [02-homebrew.sh](02-homebrew.sh) installs OrbStack, Chrome, Paper Design, and the Claude/ChatGPT desktop apps with existing-app checks. Tool-specific packages live with the script that needs them — `xcodes` + `aria2` in `08-xcode.sh`, Android cmdline-tools in `09-android.sh`, and the Tailscale CLI formula in `05-tailscale.sh`. Keep those tool-specific dependencies near their setup logic.

## Security model — read the setup skill before changes

- **SSH access**: Tailscale SSH authenticates with tailnet identity and access rules. The laptop can use the GUI app; the remote Mac needs `tailscaled`. Use an independent provider console when switching, and verify a fresh laptop connection before changing saved app hosts. The bootstrap leaves macOS Remote Login unchanged.
- **Git security**: Git authentication and signing are configured by the user directly on the mini when needed.
- **npm/pip**: wrapped by Aikido safe-chain (`06-safe-chain.sh`) — `which npm` should resolve to `~/.safe-chain/shims/npm`.
- **FileVault**: this setup does not enable it on headless minis; review the recovery path before changing that decision.

## Conventions

- Scripts that need their own directory capture it before any `cd`: `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`.
- Document recovery for new cross-machine state such as daemons or launchd jobs in the setup skill or README.
- Heredocs ending with `EOF` use `'EOF'` (quoted) when the body contains `$` literals that should NOT expand.
