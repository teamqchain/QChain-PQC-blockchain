#!/usr/bin/env bash
# One-time setup: installs a systemd service that brings the QChain Fabric
# network (CA servers + orderer + peers + CouchDB) back up automatically
# whenever this machine boots — e.g. after the university lab power-cycles
# the VM. Run this ONCE per machine, with sudo.
#
# It wraps start-fabric-network.sh (which does the actual, correctly-ordered
# `docker compose up -d` calls) in a systemd unit, so we get the same
# depends_on/health-check ordering guarantees as running it by hand — unlike
# a bare `restart: unless-stopped` on each container, which restarts them
# independently with no ordering guarantee.
#
# Usage:
#   sudo bash qchain-network/scripts/setup-fabric-autostart.sh

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: run this with sudo (it installs a systemd unit)." >&2
    echo "  sudo bash qchain-network/scripts/setup-fabric-autostart.sh" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUN_AS_USER="${SUDO_USER:-$(logname)}"
UNIT_PATH="/etc/systemd/system/qchain-fabric.service"

echo "=== Installing $UNIT_PATH ==="
echo "    Runs as user : $RUN_AS_USER"
echo "    Repo root    : $REPO_ROOT"

cat > "$UNIT_PATH" <<EOF
[Unit]
Description=QChain Hyperledger Fabric network (CA servers + orderer + peers + CouchDB)
After=docker.service network-online.target
Requires=docker.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=$RUN_AS_USER
WorkingDirectory=$REPO_ROOT/qchain-network/docker
ExecStart=/usr/bin/bash $REPO_ROOT/qchain-network/scripts/start-fabric-network.sh

[Install]
WantedBy=multi-user.target
EOF

echo "=== Reloading systemd + enabling the service ==="
systemctl daemon-reload
systemctl enable qchain-fabric.service

echo ""
echo "=== Done ==="
echo "The Fabric network will now start automatically on every future boot, as user '$RUN_AS_USER'."
echo ""
echo "Test it right now WITHOUT rebooting:"
echo "    sudo systemctl start qchain-fabric.service"
echo "    systemctl status qchain-fabric.service --no-pager"
echo ""
echo "View its boot-time logs any time with:"
echo "    journalctl -u qchain-fabric.service --no-pager"
