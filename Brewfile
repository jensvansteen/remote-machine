# General-purpose CLI tools used across the box.
# Tool-specific packages live with the script that uses them (mise in 04, tailscale
# in 05, xcodes+aria2 in 08, Android SDK cmdline-tools in 09).
#
# Apply: brew bundle install --file=./Brewfile

brew "git"
brew "gh"                    # GitHub CLI
brew "herdr"                 # agent session and remote-machine manager
brew "watchman"              # required by Metro / React Native

# Engineering quality-of-life CLIs
brew "ripgrep"               # faster grep (rg) — agent-friendly
brew "fd"                    # faster find — agent-friendly
brew "jq"                    # JSON processor (package.json, expo configs, API responses)
brew "yq"                    # YAML processor (CI configs, k8s manifests)
brew "htop"                  # process viewer (classic)
brew "btop"                  # process viewer (modern, nicer UI)
brew "tree"                  # directory visualization
brew "fzf"                   # fuzzy finder for shell + files
brew "bat"                   # cat with syntax highlighting
brew "eza"                   # modern ls with git integration
brew "gum"                   # pretty terminal UIs for shell scripts
brew "git-delta"             # better git diff viewer
brew "direnv"                # per-directory env vars (essential for client repos)
brew "starship"              # cross-shell prompt — fast, sensible defaults
