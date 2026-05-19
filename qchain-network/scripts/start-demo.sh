#!/usr/bin/env bash
# One-command demo startup.
# Run this whenever the VM reboots or you need to verify everything is up.
#
# Usage: bash qchain-network/scripts/start-demo.sh
#
# Checks / starts:
#   1. IPFS daemon (via systemd user service)
#   2. QChain API Docker container
#   3. Fabric peers (Docker containers, started by the network)
#
# Does NOT start the Fabric network itself — that is assumed to already be
# running. If peers are down, run the network bring-up scripts first.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "  ${GRN}✓${NC}  $*"; }
warn() { echo -e "  ${YLW}!${NC}  $*"; }
fail() { echo -e "  ${RED}✗${NC}  $*"; }

echo ""
echo "=== QChain Demo Startup ==="
echo ""

# ── 1. IPFS ─────────────────────────────────────────────────────────────────
echo "── IPFS ──"

if systemctl --user is-active --quiet ipfs 2>/dev/null; then
    ok "IPFS systemd service is running."
else
    warn "IPFS service not active — attempting to start ..."
    # Try systemd first; fall back to background process.
    if systemctl --user start ipfs 2>/dev/null; then
        sleep 3
        if systemctl --user is-active --quiet ipfs 2>/dev/null; then
            ok "IPFS started via systemd."
        else
            warn "systemd start failed. Launching ipfs daemon in background ..."
            nohup ipfs daemon --migrate=true > /tmp/ipfs.log 2>&1 &
            sleep 5
        fi
    else
        warn "systemd not available. Launching ipfs daemon in background ..."
        nohup ipfs daemon --migrate=true > /tmp/ipfs.log 2>&1 &
        sleep 5
    fi
fi

# Verify IPFS API responds
if curl -s -X POST http://127.0.0.1:5001/api/v0/id --max-time 3 | grep -q "ID" 2>/dev/null; then
    ok "IPFS API responding at 127.0.0.1:5001"
else
    fail "IPFS API not responding — credential IPFS uploads will be skipped."
fi

echo ""

# ── 2. QChain API container ──────────────────────────────────────────────────
echo "── QChain API ──"

CONTAINER="qchain-api"

if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$" 2>/dev/null; then
    ok "Container '$CONTAINER' is running."
else
    warn "Container '$CONTAINER' is not running — starting ..."

    if ! docker image inspect qchain-api:latest &>/dev/null; then
        fail "Docker image 'qchain-api:latest' not found."
        echo "       Build it first: bash offchain/docker-build.sh"
    else
        bash "$REPO_ROOT/offchain/docker-run.sh"
        sleep 2
        if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
            ok "Container started."
        else
            fail "Container failed to start. Check: docker logs $CONTAINER"
        fi
    fi
fi

# Verify HTTP health
if curl -s http://localhost:3000/health --max-time 3 | grep -q "ok" 2>/dev/null; then
    ok "API responding at http://localhost:3000"
else
    fail "API not responding on port 3000."
    echo "       Check: docker logs $CONTAINER"
fi

echo ""

# ── 3. Fabric peers (informational) ─────────────────────────────────────────
echo "── Fabric Peers ──"

for PEER_CONTAINER in peer0.general.uae.com peer0.government.uae.com orderer.uae.com; do
    if docker ps --format '{{.Names}}' | grep -q "$PEER_CONTAINER" 2>/dev/null; then
        ok "$PEER_CONTAINER"
    else
        fail "$PEER_CONTAINER not running — Fabric network may be down."
    fi
done

echo ""
echo "=== Ready ==="
echo ""
echo "  Issue    : curl -s -X POST http://localhost:3000/issueCredential \\"
echo "               -H 'Content-Type: application/json' \\"
echo "               -d '{\"holderEmiratesID\":\"784-1990-1234567-1\",\"credentialType\":\"BSc CS\",\"info\":\"{}\"}'"
echo "  Verify   : curl -s -X POST http://localhost:3000/verifyCredential \\"
echo "               -H 'Content-Type: application/json' -d '{\"credentialID\":\"CRED-0001\"}'"
echo "  API logs : docker logs -f qchain-api"
echo ""
