#!/usr/bin/env bash
# osquery — endpoint visibility for the headless Mac mini.
#
# Provides a forensic trace of system state changes:
#   - Persistence locations (launch daemons/agents, login items, kernel extensions)
#   - Outbound network connections (snapshot every 15 min)
#   - SSH authorized_keys changes
#   - New non-system users
#
# Query results land in /var/log/osquery/osqueryd.results.log — grep / jq them
# or open the file in vim to investigate. For ad-hoc queries: `sudo osqueryi`.
#
# This is OPTIONAL. The script is idempotent — safe to re-run.
set -euo pipefail

echo "==> osquery"

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Run 02-homebrew.sh first."
  exit 1
fi

# Install osquery via Homebrew cask (official distribution)
if ! command -v osqueryi >/dev/null 2>&1; then
  brew install --cask osquery
fi

# Drop a sensible config focused on what matters for a headless dev box.
sudo mkdir -p /var/osquery /var/log/osquery

sudo tee /var/osquery/osquery.conf >/dev/null <<'EOF'
{
  "options": {
    "logger_path": "/var/log/osquery",
    "logger_plugin": "filesystem",
    "events_expiry": "604800",
    "schedule_splay_percent": "10",
    "disable_events": "false",
    "enable_file_events": "true"
  },

  "schedule": {
    "launch_daemons_and_agents": {
      "query": "SELECT name, path, program, run_at_load, keep_alive FROM launchd WHERE path LIKE '/Library/LaunchDaemons/%' OR path LIKE '/Library/LaunchAgents/%' OR path LIKE '/Users/%/Library/LaunchAgents/%';",
      "interval": 3600,
      "description": "All launch daemons/agents — the primary macOS persistence locations"
    },

    "kernel_extensions": {
      "query": "SELECT name, version, linked_against FROM kernel_extensions;",
      "interval": 3600,
      "description": "Loaded kernel extensions — any change is interesting"
    },

    "startup_items": {
      "query": "SELECT name, path, source, status, type, username FROM startup_items;",
      "interval": 3600,
      "description": "Login items + startup items"
    },

    "non_system_users": {
      "query": "SELECT username, uid, gid, description, directory, shell FROM users WHERE uid >= 500;",
      "interval": 3600,
      "description": "Watch for unexpected new user accounts"
    },

    "ssh_authorized_keys": {
      "query": "SELECT users.username, authorized_keys.key, authorized_keys.key_file FROM users JOIN authorized_keys USING (uid);",
      "interval": 3600,
      "description": "Watch for new SSH authorized keys (a common backdoor)"
    },

    "outbound_connections_snapshot": {
      "query": "SELECT DISTINCT processes.pid, processes.name, processes.path, process_open_sockets.remote_address, process_open_sockets.remote_port FROM process_open_sockets JOIN processes USING (pid) WHERE remote_address NOT IN ('', '0.0.0.0', '::', '127.0.0.1', '::1') AND family IN (2, 30);",
      "interval": 900,
      "description": "Outbound connections snapshot every 15 min — useful for spotting unexpected callers"
    },

    "suid_binaries": {
      "query": "SELECT path, mode FROM file WHERE path LIKE '/usr/local/bin/%' AND (mode LIKE '4%' OR mode LIKE '6%');",
      "interval": 86400,
      "description": "SUID/SGID binaries in /usr/local/bin — daily check"
    }
  },

  "file_paths": {
    "ssh_config": [
      "/etc/ssh/%%",
      "/Users/%/.ssh/%%"
    ],
    "persistence_paths": [
      "/Library/LaunchDaemons/%%",
      "/Library/LaunchAgents/%%",
      "/Users/%/Library/LaunchAgents/%%"
    ]
  }
}
EOF
echo "Wrote /var/osquery/osquery.conf"

# Start the osqueryd LaunchDaemon. The brew cask ships an osqueryctl helper
# that handles the launchd plist wiring properly.
if ! sudo launchctl list 2>/dev/null | grep -q io.osquery.agent; then
  sudo osqueryctl start
  echo "Started osqueryd"
else
  echo "osqueryd already running"
fi

# Wait a moment, then verify
sleep 2
if sudo launchctl list 2>/dev/null | grep -q io.osquery.agent; then
  echo ""
  echo "Status: osqueryd running"
  echo "Logs:   /var/log/osquery/osqueryd.results.log"
  echo "Live:   sudo tail -f /var/log/osquery/osqueryd.results.log | jq ."
  echo "Query:  sudo osqueryi"
else
  echo "WARNING: osqueryd didn't start — check 'sudo osqueryctl status'"
fi

echo ""
echo "Done."
