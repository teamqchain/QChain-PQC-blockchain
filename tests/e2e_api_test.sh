#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# QChain Track H — End-to-End Test Suite (curl + docker)
#
# Tests the full end-to-end flow without running the frontend:
#   1. Health check
#   2. Holder registration on-chain + MySQL
#   3. Key generation & registration (ML-KEM-768 + ML-DSA-44)
#   4. Key check endpoint (/mobile/checkKeys)
#   5. Credential issuance with on-chain per-field hashes
#   6. Envelope retrieval (/mobile/getEnvelope)
#   7. Presentation generation (/mobile/generatePresentation)
#   8. Session resolution & 5-check cryptographic verification (/resolveSession)
#   9. Tamper detection tests (GPA fabrication & signature forgery)
#  10. OTP generation & resolution (/mobile/generateOTP)
#  11. Credential lifecycle management (suspend -> restore -> revoke)
#  12. Audit and history endpoints
#
# Usage:
#   bash tests/e2e_api_test.sh [API_BASE_URL]
# Example:
#   bash tests/e2e_api_test.sh http://localhost:3000
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

API_URL="${1:-http://localhost:3000}"
PASS="✓"
FAIL="✗"
TESTS_RUN=0
TESTS_PASSED=0

pass() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  $PASS $1"
}

fail() {
    TESTS_RUN=$((TESTS_RUN + 1))
    echo "  $FAIL $1: $2"
}

assert_json() {
    local json="$1"
    local query="$2"
    local expected="$3"
    local desc="$4"
    local val
    val=$(echo "$json" | python3 -c "
import sys, json
try:
    raw = sys.stdin.read().strip()
    data = json.loads(raw)
    if isinstance(data, dict) and 'error' in data and not '$expected' in str(data):
        print('SERVER_ERROR: ' + str(data.get('error')))
    else:
        print($query)
except Exception:
    print('RAW: ' + raw[:120])
" 2>/dev/null || echo "QUERY_ERROR")
    if [ "$val" = "$expected" ]; then
        pass "$desc"
    else
        fail "$desc" "expected '$expected', got '$val'"
    fi
}

echo "═══════════════════════════════════════════════════════════════════"
echo "  QChain Track H End-to-End API Test Suite"
echo "  Target: $API_URL"
echo "═══════════════════════════════════════════════════════════════════"

# ─── 1. Health Check ─────────────────────────────────────────────────────────
echo ""
echo "1. Checking API Health..."
HEALTH_RESP=$(curl -s "$API_URL/health")
assert_json "$HEALTH_RESP" "data.get('status')" "ok" "Server reports healthy"

# ─── 2. Register Holder on Fabric & DB ───────────────────────────────────────
echo ""
RAND_SUFFIX=$((RANDOM % 9000 + 1000))
HOLDER_ID="H-${RAND_SUFFIX}"
EID="784-1990-888${RAND_SUFFIX}-1"
echo "2. Registering Holder ($HOLDER_ID / $EID)..."
HOLDER_RESP=$(curl -s -X POST "$API_URL/registerHolder" \
    -H "Content-Type: application/json" \
    -d "{
        \"holderID\":   \"$HOLDER_ID\",
        \"emiratesID\": \"$EID\",
        \"firstName\":  \"Tariq\",
        \"lastName\":   \"Al Nuaimi\"
    }")
assert_json "$HOLDER_RESP" "data.get('holderID')" "$HOLDER_ID" "Holder $HOLDER_ID registered"

# ─── 3. Check Keys Before Activation ─────────────────────────────────────────
echo ""
echo "3. Checking Keys Before Activation..."
KEYS_BEFORE=$(curl -s "$API_URL/mobile/checkKeys?emiratesID=$EID")
assert_json "$KEYS_BEFORE" "data.get('hasKemKey')" "False" "Holder initially has no KEM key"
assert_json "$KEYS_BEFORE" "data.get('hasSigningKey')" "False" "Holder initially has no signing key"

HOLDERS_BEFORE=$(curl -s "$API_URL/getHolders?search=$EID")
assert_json "$HOLDERS_BEFORE" "data.get('holders', [{}])[0].get('isWalletActivated')" "False" "Holder initially has isWalletActivated = false in /getHolders"

# Check holder profile before any credential is issued
PROFILE_RESP=$(curl -s "$API_URL/mobile/getHolderProfile?emiratesID=$EID")
assert_json "$PROFILE_RESP" "data.get('fullName')" "Tariq Al Nuaimi" "Holder profile fetched before issuance (name: Tariq Al Nuaimi)"
assert_json "$PROFILE_RESP" "data.get('emiratesID')" "$EID" "Holder profile has matching Emirates ID"

# ─── 4. Generate Holder Keypairs ─────────────────────────────────────────────
echo ""
echo "4. Generating Holder Post-Quantum Keypairs via Docker..."
KEM_OUT=$(docker run --rm qchain-api:latest keygen kem)
HOLDER_KEM_PUB=$(echo "$KEM_OUT" | grep "^KEM_PUBLIC_KEY_HEX=" | cut -d= -f2)
HOLDER_KEM_PRIV=$(echo "$KEM_OUT" | grep "^KEM_PRIVATE_KEY_HEX=" | cut -d= -f2)

DSA_OUT=$(docker run --rm qchain-api:latest keygen dsa)
HOLDER_DSA_PUB=$(echo "$DSA_OUT" | grep "^DSA_PUBLIC_KEY_HEX=" | cut -d= -f2)
HOLDER_DSA_PRIV=$(echo "$DSA_OUT" | grep "^DSA_PRIVATE_KEY_HEX=" | cut -d= -f2)

if [ -n "$HOLDER_KEM_PUB" ] && [ -n "$HOLDER_DSA_PUB" ]; then
    pass "Generated valid ML-KEM-768 and ML-DSA-44 holder keypairs"
else
    fail "Key generation failed" "empty public keys"
fi

# ─── 5. Register Holder Keys ─────────────────────────────────────────────────
echo ""
echo "5. Registering Holder Public Keys (/mobile/registerHolderKeys)..."
REG_KEYS_RESP=$(curl -s -X POST "$API_URL/mobile/registerHolderKeys" \
    -H "Content-Type: application/json" \
    -d "{
        \"emiratesID\": \"$EID\",
        \"kemPublicKey\": \"$HOLDER_KEM_PUB\",
        \"dsaPublicKey\": \"$HOLDER_DSA_PUB\"
    }")
assert_json "$REG_KEYS_RESP" "data.get('success')" "True" "Holder public keys bound successfully"

# Check keys after activation
KEYS_AFTER=$(curl -s "$API_URL/mobile/checkKeys?emiratesID=$EID")
assert_json "$KEYS_AFTER" "data.get('hasKemKey')" "True" "Holder now has KEM key"
assert_json "$KEYS_AFTER" "data.get('hasSigningKey')" "True" "Holder now has signing key"

HOLDERS_AFTER=$(curl -s "$API_URL/getHolders?search=$EID")
assert_json "$HOLDERS_AFTER" "data.get('holders', [{}])[0].get('isWalletActivated')" "True" "Holder now has isWalletActivated = true in /getHolders"

# ─── 6. Issue Credential to Holder ───────────────────────────────────────────
echo ""
echo "6. Issuing Credential (wrapped to holder key, commits FieldHashes)..."
CRED_INFO='{"degreeTitle":"BSc Computer Science","college":"CCI","gpa":"3.8","graduationYear":"2025"}'
ISSUE_RESP=$(curl -s -X POST "$API_URL/issueCredential" \
    -H "Content-Type: application/json" \
    -d "{
        \"holderEmiratesID\": \"$EID\",
        \"credentialType\": \"BSc Computer Science\",
        \"info\": $(echo "$CRED_INFO" | python3 -c 'import sys, json; print(json.dumps(sys.stdin.read().strip()))')
    }")
CRED_ID=$(echo "$ISSUE_RESP" | python3 -c "import sys, json; print(json.load(sys.stdin).get('credentialID', ''))")
if [ -n "$CRED_ID" ]; then
    pass "Credential issued: $CRED_ID"
else
    fail "Credential issuance" "empty credentialID in response"
fi

# ─── 7. Retrieve Envelope ────────────────────────────────────────────────────
echo ""
echo "7. Retrieving Envelope Ciphertext (/mobile/getEnvelope)..."
ENV_RESP=$(curl -s "$API_URL/mobile/getEnvelope?credentialID=$CRED_ID")
assert_json "$ENV_RESP" "data.get('_qc_env')" "qchain-env" "Valid QChain envelope returned"
assert_json "$ENV_RESP" "data.get('wraps')[0].get('recipient')" "holder" "Recipient is sealed to 'holder'"

# ─── 8. Generate Presentation Session ────────────────────────────────────────
echo ""
echo "8. Generating Presentation Session (/mobile/generatePresentation)..."
DISCLOSED_PAYLOAD='{"disclosedFields":{"college":"CCI","degreeTitle":"BSc Computer Science","gpa":"3.8"}}'

# Sign the disclosed payload with the holder's ML-DSA-44 private key
HOLDER_SIG=$(docker run --rm qchain-api:latest keygen sign "$HOLDER_DSA_PRIV" "$DISCLOSED_PAYLOAD")

PRES_RESP=$(curl -s -X POST "$API_URL/mobile/generatePresentation" \
    -H "Content-Type: application/json" \
    -d "{
        \"credentialID\": \"$CRED_ID\",
        \"hiddenFields\": [\"graduationYear\"],
        \"disclosedPayload\": $(echo "$DISCLOSED_PAYLOAD" | python3 -c 'import sys, json; print(json.dumps(sys.stdin.read().strip()))'),
        \"holderSignature\": \"$HOLDER_SIG\"
    }")
assert_json "$PRES_RESP" "data.get('success')" "True" "Presentation session generated"
PRES_ID=$(echo "$PRES_RESP" | python3 -c "import sys, json; print(json.load(sys.stdin).get('presentationID', ''))")
EXPIRES_AT=$(echo "$PRES_RESP" | python3 -c "import sys, json; print(json.load(sys.stdin).get('expiresAt', ''))")

# Verify Dubai timezone format (no trailing 'Z')
if [[ "$EXPIRES_AT" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
    pass "expiresAt is in Asia/Dubai local format ($EXPIRES_AT)"
else
    fail "expiresAt format" "expected YYYY-MM-DDTHH:MM:SS without Z, got $EXPIRES_AT"
fi

# ─── 9. Resolve Session (5-check Verification) ───────────────────────────────
echo ""
echo "9. Resolving Session with 5 Cryptographic Checks (/resolveSession)..."
RESOLVE_RESP=$(curl -s -X POST "$API_URL/resolveSession" \
    -H "Content-Type: application/json" \
    -d "{\"sessionToken\": \"$PRES_ID\"}")

assert_json "$RESOLVE_RESP" "data.get('verified')" "True" "Verification result is VERIFIED: TRUE"
assert_json "$RESOLVE_RESP" "data.get('checks', {}).get('existsOnChain')" "True" "Check 1: existsOnChain = true"
assert_json "$RESOLVE_RESP" "data.get('checks', {}).get('notRevoked')" "True" "Check 2: notRevoked = true"
assert_json "$RESOLVE_RESP" "data.get('checks', {}).get('signatureValid')" "True" "Check 3: signatureValid (issuer) = true"
assert_json "$RESOLVE_RESP" "data.get('checks', {}).get('fieldHashesValid')" "True" "Check 4: fieldHashesValid (integrity) = true"
assert_json "$RESOLVE_RESP" "data.get('checks', {}).get('holderSignatureValid')" "True" "Check 5: holderSignatureValid (presentation) = true"
assert_json "$RESOLVE_RESP" "data.get('credentialData', {}).get('gpa')" "3.8" "Disclosed GPA attribute matches"

# ─── 10. Tamper Detection Tests ──────────────────────────────────────────────
echo ""
echo "10. Running Tamper Detection Tests..."

# Test A: GPA fabrication (holder tampers 3.8 -> 4.0 and re-signs)
TAMPERED_PAYLOAD='{"disclosedFields":{"college":"CCI","degreeTitle":"BSc Computer Science","gpa":"4.0"}}'
TAMPERED_SIG=$(docker run --rm qchain-api:latest keygen sign "$HOLDER_DSA_PRIV" "$TAMPERED_PAYLOAD")

TAMPER_PRES_RESP=$(curl -s -X POST "$API_URL/mobile/generatePresentation" \
    -H "Content-Type: application/json" \
    -d "{
        \"credentialID\": \"$CRED_ID\",
        \"hiddenFields\": [],
        \"disclosedPayload\": $(echo "$TAMPERED_PAYLOAD" | python3 -c 'import sys, json; print(json.dumps(sys.stdin.read().strip()))'),
        \"holderSignature\": \"$TAMPERED_SIG\"
    }")
TAMPER_PRES_ID=$(echo "$TAMPER_PRES_RESP" | python3 -c "import sys, json; print(json.load(sys.stdin).get('presentationID', ''))")

TAMPER_RESOLVE=$(curl -s -X POST "$API_URL/resolveSession" \
    -H "Content-Type: application/json" \
    -d "{\"sessionToken\": \"$TAMPER_PRES_ID\"}")

assert_json "$TAMPER_RESOLVE" "data.get('verified')" "False" "Tampered GPA rejected (verified = false)"
assert_json "$TAMPER_RESOLVE" "data.get('checks', {}).get('fieldHashesValid')" "False" "Tampered GPA caught by fieldHashesValid = false"
assert_json "$TAMPER_RESOLVE" "data.get('checks', {}).get('holderSignatureValid')" "True" "Holder signature was mathematically valid on fabricated value"

# Test B: Signature forgery (signature corrupted)
FORGED_PRES_RESP=$(curl -s -X POST "$API_URL/mobile/generatePresentation" \
    -H "Content-Type: application/json" \
    -d "{
        \"credentialID\": \"$CRED_ID\",
        \"hiddenFields\": [],
        \"disclosedPayload\": $(echo "$DISCLOSED_PAYLOAD" | python3 -c 'import sys, json; print(json.dumps(sys.stdin.read().strip()))'),
        \"holderSignature\": \"11223344556677889900aabbccddeeff\"
    }")
FORGED_PRES_ID=$(echo "$FORGED_PRES_RESP" | python3 -c "import sys, json; print(json.load(sys.stdin).get('presentationID', ''))")

FORGED_RESOLVE=$(curl -s -X POST "$API_URL/resolveSession" \
    -H "Content-Type: application/json" \
    -d "{\"sessionToken\": \"$FORGED_PRES_ID\"}")

assert_json "$FORGED_RESOLVE" "data.get('verified')" "False" "Forged signature rejected (verified = false)"
assert_json "$FORGED_RESOLVE" "data.get('checks', {}).get('holderSignatureValid')" "False" "Caught by holderSignatureValid = false"

# ─── 11. OTP Session Flow ───────────────────────────────────────────────────
echo ""
echo "11. Testing OTP Presentation Flow (/mobile/generateOTP)..."
OTP_RESP=$(curl -s -X POST "$API_URL/mobile/generateOTP" \
    -H "Content-Type: application/json" \
    -d "{
        \"credentialID\": \"$CRED_ID\",
        \"hiddenFields\": [],
        \"disclosedPayload\": $(echo "$DISCLOSED_PAYLOAD" | python3 -c 'import sys, json; print(json.dumps(sys.stdin.read().strip()))'),
        \"holderSignature\": \"$HOLDER_SIG\"
    }")
assert_json "$OTP_RESP" "data.get('success')" "True" "OTP generated successfully"
OTP_CODE=$(echo "$OTP_RESP" | python3 -c "import sys, json; print(json.load(sys.stdin).get('otp', ''))")

# Redeem OTP (frontend prepends 'OTP-')
OTP_RESOLVE=$(curl -s -X POST "$API_URL/resolveSession" \
    -H "Content-Type: application/json" \
    -d "{\"sessionToken\": \"OTP-$OTP_CODE\"}")
assert_json "$OTP_RESOLVE" "data.get('verified')" "True" "OTP redeemed and verified successfully"

# ─── 12. Credential Lifecycle Management ─────────────────────────────────────
echo ""
echo "12. Testing Credential Lifecycle (Suspend -> Restore -> Revoke)..."

# Direct portal verify (active)
PORTAL_VERIFY_1=$(curl -s -X POST "$API_URL/verifyCredential" \
    -H "Content-Type: application/json" \
    -d "{\"credentialID\": \"$CRED_ID\"}")
assert_json "$PORTAL_VERIFY_1" "data.get('verified')" "True" "Portal verify: initial status is active/valid"

# Suspend
SUSP_RESP=$(curl -s -X POST "$API_URL/suspendCredential" \
    -H "Content-Type: application/json" \
    -d "{\"credentialID\": \"$CRED_ID\", \"reason\": \"Investigation pending\"}")
assert_json "$SUSP_RESP" "data.get('message')" "Credential suspended successfully" "Credential suspended"

PORTAL_VERIFY_2=$(curl -s -X POST "$API_URL/verifyCredential" \
    -H "Content-Type: application/json" \
    -d "{\"credentialID\": \"$CRED_ID\"}")
assert_json "$PORTAL_VERIFY_2" "data.get('verified')" "False" "Portal verify: suspended credential is not verified"
assert_json "$PORTAL_VERIFY_2" "data.get('status')" "suspended" "Status is suspended"

# Restore
REST_RESP=$(curl -s -X POST "$API_URL/restoreCredential" \
    -H "Content-Type: application/json" \
    -d "{\"credentialID\": \"$CRED_ID\"}")
assert_json "$REST_RESP" "data.get('message')" "Credential restored successfully" "Credential restored"

PORTAL_VERIFY_3=$(curl -s -X POST "$API_URL/verifyCredential" \
    -H "Content-Type: application/json" \
    -d "{\"credentialID\": \"$CRED_ID\"}")
assert_json "$PORTAL_VERIFY_3" "data.get('verified')" "True" "Portal verify: restored credential is active again"

# Revoke
REV_RESP=$(curl -s -X POST "$API_URL/revokeCredential" \
    -H "Content-Type: application/json" \
    -d "{\"credentialID\": \"$CRED_ID\"}")
assert_json "$REV_RESP" "data.get('message')" "Credential revoked successfully" "Credential permanently revoked"

PORTAL_VERIFY_4=$(curl -s -X POST "$API_URL/verifyCredential" \
    -H "Content-Type: application/json" \
    -d "{\"credentialID\": \"$CRED_ID\"}")
assert_json "$PORTAL_VERIFY_4" "data.get('verified')" "False" "Portal verify: revoked credential is not verified"
assert_json "$PORTAL_VERIFY_4" "data.get('status')" "revoked" "Status is revoked"

# ─── 13. Audit & Dashboard Queries ───────────────────────────────────────────
echo ""
echo "13. Testing Audit & Dashboard Queries..."
HISTORY_RESP=$(curl -s "$API_URL/getVerificationHistory?page=1&limit=5")
assert_json "$HISTORY_RESP" "'records' in data" "True" "Verification history returns records list"

STATS_RESP=$(curl -s "$API_URL/getDashboardStats")
assert_json "$STATS_RESP" "'totalIssued' in data" "True" "Dashboard stats endpoint accessible"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  Test Summary: $TESTS_PASSED / $TESTS_RUN tests passed"
echo "═══════════════════════════════════════════════════════════════════"

if [ "$TESTS_PASSED" -eq "$TESTS_RUN" ]; then
    echo "  ALL TESTS PASSED SUCCESSFULLY!"
    exit 0
else
    echo "  SOME TESTS FAILED!"
    exit 1
fi
