#!/usr/bin/env bash
# Run ONCE on the VM to install IPFS as a systemd user service.
# After this, IPFS starts automatically on login and restarts on crash.
#
# Usage: bash setup-ipfs-service.sh

set -euo pipefail

IPFS_BIN=$(command -v ipfs 2>/dev/null || echo "")
if [[ -z "$IPFS_BIN" ]]; then
    echo "ERROR: ipfs binary not found in PATH. Install IPFS first." >&2
    exit 1
fi

SERVICE_DIR="$HOME/.config/systemd/user"
mkdir -p "$SERVICE_DIR"

cat > "$SERVICE_DIR/ipfs.service" <<EOF
[Unit]
Description=IPFS Daemon
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=${IPFS_BIN} daemon --migrate=true
Restart=on-failure
RestartSec=5
Environment=IPFS_PATH=${HOME}/.ipfs

[Install]
WantedBy=default.target
EOF

# Allow the service to run without an active login session (survives logout).
# Requires sudo — skip gracefully if permission is denied.
loginctl enable-linger "$(whoami)" 2>/dev/null \
    || echo "Note: 'loginctl enable-linger' needs sudo. IPFS will start on login only."

systemctl --user daemon-reload
systemctl --user enable ipfs
systemctl --user restart ipfs

echo ""
echo "IPFS systemd service installed."
sleep 2
STATUS=$(systemctl --user is-active ipfs 2>/dev/null || echo "unknown")
echo "Status : $STATUS"
echo "Logs   : journalctl --user -u ipfs -n 20"
echo "API    : curl -s -X POST http://127.0.0.1:5001/api/v0/id | head -c 80"
