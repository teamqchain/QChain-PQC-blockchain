#!/usr/bin/env bash
# Run ONCE on the VM to expose the QChain web-gateway publicly via Tailscale
# Funnel. After this, https://<vm>.<tailnet>.ts.net serves the portal (/), the
# wallet (/wallet/) and the API (/api/).
#
# Why this is "set and forget": the tailscaled system service keeps the tunnel
# alive across crashes and reboots and re-applies this Funnel config on its own.
# Unlike the old Cloudflare quick tunnel, the URL is PERMANENT and there is no
# extra background process to babysit.
#
# Prerequisites (one-time, in the Tailscale admin console at
# https://login.tailscale.com/admin/ ):
#   • Tailscale installed and logged in on this VM   →  sudo tailscale up
#   • HTTPS certificates enabled for your tailnet
#   • Funnel enabled for this node (node attributes / ACLs)
# Funnel commands may need sudo unless `tailscale up --operator=$USER` was used.
#
# Usage: bash qchain-network/scripts/setup-tailscale-funnel.sh

set -uo pipefail

GATEWAY_PORT=8090

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "  ${GRN}✓${NC}  $*"; }
warn() { echo -e "  ${YLW}!${NC}  $*"; }
fail() { echo -e "  ${RED}✗${NC}  $*"; }

echo ""
echo "=== Tailscale Funnel setup for the QChain web-gateway ==="
echo ""

# ── 1. Is tailscale installed? ───────────────────────────────────────────────
TS_BIN=$(command -v tailscale 2>/dev/null || echo "")
if [[ -z "$TS_BIN" ]]; then
    fail "tailscale binary not found. Install it first: https://tailscale.com/download"
    exit 1
fi
ok "tailscale found: $TS_BIN"

# ── 2. Is this node connected / logged in? ───────────────────────────────────
if ! tailscale status >/dev/null 2>&1; then
    fail "Tailscale is not connected. Run:  sudo tailscale up"
    exit 1
fi
ok "Tailscale is connected."

# ── 3. Is the gateway actually listening locally? ────────────────────────────
if curl -s "http://localhost:${GATEWAY_PORT}/gw-health" --max-time 3 | grep -q "ok" 2>/dev/null; then
    ok "Web-gateway responding on localhost:${GATEWAY_PORT}"
else
    warn "Web-gateway not responding on localhost:${GATEWAY_PORT} yet."
    warn "Start it first:  bash web-gateway/docker-build.sh && bash web-gateway/docker-run.sh"
fi

# ── 4. Enable Funnel: public 443 → localhost:8090 ────────────────────────────
echo ""
echo "── Enabling Funnel (public 443 → localhost:${GATEWAY_PORT}) ──"
if tailscale funnel --bg "${GATEWAY_PORT}" 2>/tmp/ts-funnel.err; then
    ok "Funnel enabled."
else
    fail "Could not enable Funnel with 'tailscale funnel --bg ${GATEWAY_PORT}'."
    [[ -s /tmp/ts-funnel.err ]] && echo "      $(cat /tmp/ts-funnel.err)"
    echo ""
    echo "  Your Tailscale version may use different syntax, or it may need sudo."
    echo "  Try one of:"
    echo "      sudo tailscale funnel --bg ${GATEWAY_PORT}"
    echo "      sudo tailscale serve --bg --https=443 localhost:${GATEWAY_PORT} && sudo tailscale funnel --bg 443 on"
    echo "  Also confirm HTTPS + Funnel are enabled for this node in the admin console:"
    echo "      https://login.tailscale.com/admin/"
    exit 1
fi

# ── 5. Print the permanent public address ────────────────────────────────────
echo ""
echo "── Public address (share these two links) ──"
SELF_HOST="$(tailscale status --json 2>/dev/null \
    | python3 -c 'import sys,json; print(json.load(sys.stdin).get("Self",{}).get("DNSName","").rstrip("."))' 2>/dev/null || true)"
if [[ -n "$SELF_HOST" ]]; then
    ok "Portal : https://${SELF_HOST}/"
    ok "Wallet : https://${SELF_HOST}/wallet/"
    echo "       (the apps call the API at https://${SELF_HOST}/api — already baked in)"
    echo ""
    echo "  Verify:  curl -s https://${SELF_HOST}/gw-health      # → ok"
    echo "           curl -s https://${SELF_HOST}/api/health     # → {\"status\":\"ok\"}"
else
    warn "Could not auto-read the hostname. Run:  tailscale funnel status"
fi

echo ""
echo "Funnel is managed by the tailscaled system service and is re-applied on reboot."
echo "Take it offline anytime with:  tailscale funnel --bg off     (or: tailscale funnel reset)"
echo ""
