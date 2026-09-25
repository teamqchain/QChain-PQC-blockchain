#!/usr/bin/env bash
# setup-demo.sh — seeds MySQL and registers demo holders on Fabric.
# Run ONCE after the Fabric network is up and the Go server is running.
#
# Prerequisites:
#   - Fabric network running (peer0.general.uae.com:9051 reachable)
#   - Go server running on localhost:3000 with MYSQL_DSN set
#   - MySQL schema already applied: mysql -u root -p < schema.sql
#
# Usage:  bash setup-demo.sh [server_url]
#   server_url defaults to http://localhost:3000

set -euo pipefail

SERVER="${1:-http://localhost:3000}"

echo "▶  QChain demo setup — registering holders on Fabric via $SERVER"

# ─── Health check ────────────────────────────────────────────────────────────
echo ""
echo "  Checking server health..."
curl -sf "$SERVER/health" | grep -q '"ok"' || { echo "  ERROR: server not reachable at $SERVER"; exit 1; }
echo "  Server is healthy."

# ─── Register demo holders on Fabric ────────────────────────────────────────
# holder_id is always server-generated (offchain/db.go nextHolderID) — this
# call creates the holder (MySQL row + on-chain registration) in one step.
# There's no pre-seeded row to target by id, so re-running this script mints
# NEW duplicate demo holders rather than being a no-op — matches the
# "Run ONCE" instruction at the top of this file.

echo ""
echo "  Registering demo holder Ahmed Al Mansouri on Fabric..."
RESP1=$(curl -sf -X POST "$SERVER/registerHolder" \
  -H "Content-Type: application/json" \
  -d '{
    "emiratesID": "784-1990-1234567-1",
    "firstName":  "Ahmed",
    "lastName":   "Al Mansouri",
    "email":      "ahmed.almansouri@uos.ac.ae",
    "college":    "CCI"
  }') || RESP1=""
echo "$RESP1" | python3 -m json.tool 2>/dev/null || true
HOLDER1_ID=$(printf '%s' "$RESP1" | python3 -c "import sys, json
try:
    print(json.load(sys.stdin).get('holderID', ''))
except Exception:
    pass" 2>/dev/null)

echo ""
echo "  Registering demo holder Sara Al Hashimi on Fabric..."
RESP2=$(curl -sf -X POST "$SERVER/registerHolder" \
  -H "Content-Type: application/json" \
  -d '{
    "emiratesID": "784-1995-7654321-2",
    "firstName":  "Sara",
    "lastName":   "Al Hashimi",
    "email":      "sara.alhashimi@uos.ac.ae",
    "college":    "CBA"
  }') || RESP2=""
echo "$RESP2" | python3 -m json.tool 2>/dev/null || true
HOLDER2_ID=$(printf '%s' "$RESP2" | python3 -c "import sys, json
try:
    print(json.load(sys.stdin).get('holderID', ''))
except Exception:
    pass" 2>/dev/null)

echo ""
echo "✓  Demo setup complete."
echo ""
echo "  Demo holder Emirates IDs:"
echo "    ${HOLDER1_ID:-<unknown>} → 784-1990-1234567-1  (Ahmed Al Mansouri)"
echo "    ${HOLDER2_ID:-<unknown>} → 784-1995-7654321-2  (Sara Al Hashimi)"
echo ""
echo "  Next: each holder activates QWallet (binds their ML-KEM / ML-DSA keys on-chain)."
echo "  Then, to issue a test credential:"
echo "    curl -X POST $SERVER/issueCredential \\"
echo "      -H 'Content-Type: application/json' \\"
echo "      -d '{\"holderEmiratesID\":\"784-1990-1234567-1\",\"credentialType\":\"BSc Computer Science\",\"info\":\"{\\\"Degree Title\\\":\\\"BSc Computer Science\\\",\\\"College\\\":\\\"CCI\\\",\\\"Grade\\\":\\\"Distinction\\\",\\\"expiryDate\\\":\\\"30 Jun 2030\\\"}\" }'"
echo ""
echo "  To verify: present the credential from QWallet (QR or OTP) and scan it in"
echo "  QPortal, or run the scripted holder: bash tests/e2e_api_test.sh $SERVER"
