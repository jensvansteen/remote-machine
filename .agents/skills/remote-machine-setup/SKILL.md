---
name: remote-machine-setup
description: Set up, resume, or repair a remote Apple silicon development Mac using this repository's guided CLI. Use for this repo's bootstrap, Tailscale SSH, and installed toolchain; not for unrelated macOS support.
---

# Remote Machine setup

This repository's scripts perform the setup. Use the [README](../../../README.md) for the human checklist and connections, [bootstrap.sh](../../../bootstrap.sh) for the current run order and questions, and the relevant numbered script for exact behavior. Do not maintain a second command list here.

## Choose the smallest useful path

- **New Mac:** establish console or initial terminal access, make sure the provider's recovery console is available, then run the guided installer from the README on the intended Mac. The CLI asks for the machine name, mobile toolchains, SimDeck, and optional file handoff. Let it show the plan before it changes the host.
- **Interrupted bootstrap:** inspect what completed on that Mac and the failing script's output. Rerun the relevant script or use `bootstrap.sh --resume-from NN` when the remaining sequence is wanted. Read the script before changing its configuration.
- **One missing tool:** run its numbered script on the intended Mac. Existing installations are kept or skipped where practical.
- **Connection problem:** inspect [README](../../../README.md), [FILE-HANDOFF.md](../../../FILE-HANDOFF.md), and `05-tailscale.sh` before changing network settings.

The one-line installer updates only a clean checkout on `main`; it refuses to replace local changes or unrelated commits. Keep authentication, Git signing, app sign-in, and machine-local credentials under the user's control.

Numbered scripts run as child processes. If a later phase cannot find a newly installed command, check `bootstrap.sh`'s `refresh_setup_environment` calls. The CLI refreshes Homebrew, mise, and safe-chain paths between phases; reloading the user's shell is not part of a normal run.

## Access and recovery

The intended path is Tailscale SSH using tailnet identity. The remote Mac runs the open-source `tailscaled` service; the laptop can keep the GUI app. `05-tailscale.sh` reuses an existing service, or installs the Homebrew formula and starts its service when absent. It addresses the daemon through an explicit socket, signs in with a bare `up`, and enables SSH with `set --ssh`, preserving other preferences. Never run `up --reset` on an existing node.

When a GUI app is active or its state is unknown, the phase stops with migration guidance. Switch from an independent provider console or desktop session: disconnect the remote GUI, confirm the desktop survives, rerun the phase, and sign into the same tailnet as the laptop. Do not run two active variants or start a second daemon. Existing custom launchd services are reused. Keep the GUI installed as a recovery option until the daemon connection works, unless a Homebrew cask conflict requires manual removal from the independent console.

Activation is refused inside an SSH session because it can interrupt that session; an already connected service with SSH enabled can be reused over SSH. The script checks local settings but cannot prove the tailnet policy permits a laptop login. Network access and SSH access rules must both allow the user's connection. Browser reauthentication can be required by policy. macOS Remote Login is left unchanged.

Avoid system-wide `tccutil reset` on a headless Mac. Do not enable FileVault without a reliable pre-boot recovery path. Use the hosting provider's console if tailnet access is lost. For Ghostty terminfo problems, run `infocmp -x xterm-ghostty | ssh <host> -- tic -x -` from the laptop.

## Confirm the outcome

Verify the tools the user selected with their version commands. From the laptop, test a fresh Tailscale SSH connection without a reused control socket or personal SSH keys, using the README command. After an app migration, the daemon may register a new device: update saved hosts using its actual name or IP only after verifying the login. Keep the remote GUI disconnected; it can be uninstalled once the service and agent apps work. Do not remove `tailscaled`. The README covers Codex, Claude Desktop, Herdr, VS Code, Paper, SimDeck, and the optional Hammerspoon file handoff. [SLOTS.md](../../../SLOTS.md) covers parallel mobile projects.

When changing setup behavior, update the scripts and their README guidance together. Distinguish local SSH activation from a verified laptop login.
