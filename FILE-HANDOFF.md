# Laptop-to-mini file handoff

Send screenshots and files from your laptop into an **interactive SSH terminal
session** on the Mac mini. It works with a remote Codex CLI or Claude Code CLI
running in that terminal. It does not paste into the Codex or Claude desktop
apps. The feature leaves your normal clipboard contents unchanged.

## Workflow

1. Copy a file in Finder, or take a screenshot to the clipboard with
   `Cmd+Shift+Ctrl+4`.
2. Focus the SSH terminal on your laptop, with the remote agent prompt ready,
   and press `Cmd+Shift+V`.
3. Hammerspoon sends the file with `scp` and types its remote path only after
   the transfer succeeds. Your normal `Cmd+V` clipboard stays unchanged.

The mini destination defaults to `~/Sync/screenshots`. The mini bootstrap can
prepare this folder with `./16-clipboard-handoff.sh`. File handoff uses your
laptop's ordinary SSH client configuration. This feature does not require
special SSH options or port-forward rules.

## Laptop setup

First confirm the laptop can connect to the mini using the SSH alias configured
in `~/.ssh/config` (default `mac-mini-dev`):

```bash
ssh mac-mini-dev 'mkdir -p ~/Sync/screenshots'
if [[ -d /Applications/Hammerspoon.app ]] || brew list --cask hammerspoon >/dev/null 2>&1; then
  echo "Hammerspoon already installed"
else
  brew install --cask hammerspoon
fi
mkdir -p ~/.hammerspoon
curl -fsSL https://raw.githubusercontent.com/jensvansteen/remote-machine/main/hammerspoon-init.lua -o ~/.hammerspoon/remote-machine.lua
```

Add this line to your existing `~/.hammerspoon/init.lua` (create the file if it
does not exist), then reload Hammerspoon:

```lua
dofile(os.getenv("HOME") .. "/.hammerspoon/remote-machine.lua")
```

This keeps any other Hammerspoon shortcuts you already use.

Create `~/.hammerspoon/user-config.lua` locally. Keep this file out of Git:

```lua
return {
  miniHost = "mac-mini-dev",
  miniDropDir = "/Users/YOUR_MINI_USERNAME/Sync/screenshots",
}
```

Find the mini account name with `ssh mac-mini-dev 'id -un'`. If your SSH alias
or destination differs, change the two values above. The destination path must
contain only letters, numbers, slash, period, underscore, and hyphen.

Launch Hammerspoon and grant it Accessibility access in System Settings →
Privacy & Security → Accessibility:

```bash
open -a Hammerspoon
```

Press `Cmd+Alt+Ctrl+R` to reload the Hammerspoon config. To transfer a file,
copy it or capture a screenshot, focus the interactive SSH terminal on your
laptop (the one running the remote Codex or Claude Code CLI), and press
`Cmd+Shift+V`. A failure alert is shown if SSH/SCP fails; the path is typed only
after successful transfer.

## Troubleshooting

- **No file or image found:** use `Cmd+Shift+Ctrl+4` to put a screenshot on the
  clipboard, or copy a file in Finder.
- **SSH/SCP fails:** check `ssh mac-mini-dev` from the laptop, confirm your
  SSH config provides key-based authentication to Hammerspoon, and verify that
  `miniHost` in `user-config.lua` matches the SSH alias.
- **Permission prompt blocks typing:** grant Hammerspoon Accessibility access,
  then quit and relaunch Hammerspoon.
- **Logs:** `/tmp/hammerspoon.log` and `/tmp/hammerspoon-py.err`.

## Files

- `hammerspoon-init.lua` — laptop-side transfer hotkey; load it from
  `~/.hammerspoon/init.lua`.
- `16-clipboard-handoff.sh` — creates the destination folder on the mini.
