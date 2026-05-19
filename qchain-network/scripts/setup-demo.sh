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
echo "  To issue a test credential:"
echo "    curl -X POST $SERVER/issueCredential \\"
echo "      -H 'Content-Type: application/json' \\"
echo "      -d '{\"holderEmiratesID\":\"784-1990-1234567-1\",\"credentialType\":\"BSc Computer Science\",\"info\":\"{\\\"degreeTitle\\\":\\\"BSc Computer Science\\\",\\\"college\\\":\\\"CCI\\\",\\\"grade\\\":\\\"Distinction\\\",\\\"graduationYear\\\":\\\"2025\\\"}\" }'"
echo ""
echo "  To verify a credential (replace CRED-0001 with the returned credentialID):"
echo "    curl -X POST $SERVER/verifyCredential \\"
echo "      -H 'Content-Type: application/json' \\"
echo "      -d '{\"credentialID\":\"CRED-0001\"}'"
