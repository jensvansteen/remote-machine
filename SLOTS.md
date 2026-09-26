# Parallel Work Slot Allocation

For projects running at the same time, assign each one a Metro port and device.
Pin a project to a slot via its `.envrc` (requires direnv). Adjust the examples
to match the simulators and emulators installed on your Mac.

## Allocation table

| Slot | Metro port | Example iOS simulator | Example Android emulator |
|------|------------|-----------------------|--------------------------|
| 1 | 8081 | iPhone 16 | emulator-5554 |
| 2 | 8082 | iPhone 16 Pro | emulator-5556 |
| 3 | 8083 | iPhone 16 Pro Max | emulator-5558 |
| 4 | 8084 | iPhone 16 Plus | emulator-5560 |
| 5 | 8085 | iPhone 15 | emulator-5562 |

## Per-project setup

In each project root, create `.envrc`:

```bash
# Slot N values:
export RCT_METRO_PORT=8081
export RN_SIMULATOR="iPhone 16"
export RN_ANDROID_DEVICE="emulator-5554"
```

Then `direnv allow`. Whenever you `cd` into the project, the slot is loaded.

SimDeck can pair a browser or mobile app with the mini's simulator service over
Tailscale. Start it on the mini with `simdeck pair`, then scan the displayed QR
code from SimDeck. Keep the service on Tailscale.

## Helper commands (from `shell-helpers.sh`)

| Command | What it does |
|---------|--------------|
| `rn-start` | Starts Metro on the project's port |
| `rn-ios` | Boots iOS sim and runs the app on it |
| `rn-android` | Runs app on project's Android emulator |

## Assignment etiquette

- Slot 1 is the "default" — use it for the project you're actively working on
- Pin long-lived projects to specific slots so muscle memory builds up
- For short-lived experiments (PR reviews, scratch worktrees), grab the next free slot
- `wt-ls` to see what's currently active across slots
