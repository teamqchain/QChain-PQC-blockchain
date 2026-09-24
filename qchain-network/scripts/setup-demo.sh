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
# These holders are already in MySQL (inserted by schema.sql seed data).
# This call registers them on the blockchain so credentials can be issued.
# The chaincode refuses to re-register an existing holder (HTTP 409), so
# re-running this script is harmless.

echo ""
echo "  Registering H-0001 (Ahmed Al Mansouri) on Fabric..."
curl -sf -X POST "$SERVER/registerHolder" \
  -H "Content-Type: application/json" \
  -d '{
    "holderID":   "H-0001",
    "emiratesID": "784-1990-1234567-1",
    "firstName":  "Ahmed",
    "lastName":   "Al Mansouri"
  }' | python3 -m json.tool || true

echo ""
echo "  Registering H-0002 (Sara Al Hashimi) on Fabric..."
curl -sf -X POST "$SERVER/registerHolder" \
  -H "Content-Type: application/json" \
  -d '{
    "holderID":   "H-0002",
    "emiratesID": "784-1995-7654321-2",
    "firstName":  "Sara",
    "lastName":   "Al Hashimi"
  }' | python3 -m json.tool || true

echo ""
echo "✓  Demo setup complete."
echo ""
echo "  Demo holder Emirates IDs:"
echo "    H-0001 → 784-1990-1234567-1  (Ahmed Al Mansouri)"
echo "    H-0002 → 784-1995-7654321-2  (Sara Al Hashimi)"
echo ""
echo "  Next: each holder activates QWallet (binds their ML-KEM / ML-DSA keys on-chain)."
echo "  Then, to issue a test credential:"
echo "    curl -X POST $SERVER/issueCredential \\"
echo "      -H 'Content-Type: application/json' \\"
echo "      -d '{\"holderEmiratesID\":\"784-1990-1234567-1\",\"credentialType\":\"BSc Computer Science\",\"info\":\"{\\\"Degree Title\\\":\\\"BSc Computer Science\\\",\\\"College\\\":\\\"CCI\\\",\\\"Grade\\\":\\\"Distinction\\\",\\\"expiryDate\\\":\\\"30 Jun 2030\\\"}\" }'"
echo ""
echo "  To verify: present the credential from QWallet (QR or OTP) and scan it in"
echo "  QPortal, or run the scripted holder: bash tests/e2e_api_test.sh $SERVER"
