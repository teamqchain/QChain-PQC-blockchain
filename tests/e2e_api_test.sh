#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# QChain — End-to-End Test Suite (curl + docker), source-of-truth backend
#
# Plays both the issuer (portal API calls) and the holder (keygen tool in the
# qchain-api image: key generation, envelope decryption, presentation signing)
# against a running stack, without any frontend:
#   1. Health check
#   2. Holder registration on-chain + MySQL
#   3. Keys before activation (/mobile/checkKeys, /getHolders, profile)
#   4. Holder key generation (ML-KEM-768 + ML-DSA-44)
#   5. Key registration (/mobile/registerHolderKeys)
#   6. Credential issuance (salted field hashes, expiry on-chain, IPFS CID)
#   7. Envelope retrieval from IPFS + holder-side decryption (_salts present)
#   8. Presentation with salts (/mobile/generatePresentation)
#   9. Session resolution — 5 checks (/resolveSession)
#  10. Tamper and malformed-presentation tests
#  11. OTP presentation flow (/mobile/generateOTP)
#  12. Lifecycle via fresh presentations: suspend, restore, expiry re-sign
#      (EXPIRED), revoke — each confirmed by /resolveSession and the chain-backed
#      /getCredentialDetail
#  13. Audit and dashboard endpoints
#
# Requires: curl, python3, docker, and the qchain-api:latest image (for keygen).
#
# Usage:
#   bash tests/e2e_api_test.sh [API_BASE_URL]
# Example:
#   bash tests/e2e_api_test.sh http://localhost:3000
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

API_URL="${1:-http://localhost:3000}"
KEYGEN_IMAGE="${KEYGEN_IMAGE:-qchain-api:latest}"
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

# assert_json JSON PY_EXPR EXPECTED DESC — evaluates PY_EXPR with `data` bound
# to the parsed JSON and compares its printed value with EXPECTED.
assert_json() {
    local json="$1" query="$2" expected="$3" desc="$4" val
    val=$(printf '%s' "$json" | QUERY="$query" EXPECTED="$expected" python3 -c '
import json, os, sys
raw = sys.stdin.read().strip()
try:
    data = json.loads(raw)
except Exception:
    print("RAW: " + raw[:160]); sys.exit()
if isinstance(data, dict) and "error" in data and os.environ["EXPECTED"] not in str(data):
    print("SERVER_ERROR: " + str(data.get("error")))
else:
    print(eval(os.environ["QUERY"]))
' 2>/dev/null || echo "QUERY_ERROR")
    if [ "$val" = "$expected" ]; then
        pass "$desc"
    else
        fail "$desc" "expected '$expected', got '$val'"
    fi
}

# assert_error JSON SUBSTRING DESC — the response is {"error": "...SUBSTRING..."}.
assert_error() {
    local json="$1" substr="$2" desc="$3" val
    val=$(printf '%s' "$json" | python3 -c '
import json, sys
try:
    print(json.loads(sys.stdin.read()).get("error", ""))
except Exception:
    print("")
')
    if [[ "$val" == *"$substr"* ]]; then
        pass "$desc"
    else
        fail "$desc" "expected an error containing '$substr', got '$val'"
    fi
}

# json_str STRING — STRING as a JSON string literal.
json_str() {
    printf '%s' "$1" | python3 -c 'import json, sys; print(json.dumps(sys.stdin.read()))'
}

# json_get JSON KEY — top-level value of KEY ("" when absent).
json_get() {
    printf '%s' "$1" | KEY="$2" python3 -c '
import json, os, sys
try:
    v = json.loads(sys.stdin.read()).get(os.environ["KEY"], "")
    print("" if v is None else v)
except Exception:
    print("")
'
}

keygen() {
    docker run --rm -i "$KEYGEN_IMAGE" keygen "$@"
}

# build_payload CRED_ID FIELDS_JSON SALTS_JSON — the presentation the wallet
# signs: sorted keys, no whitespace, UTC timestamp.
build_payload() {
    python3 - "$1" "$2" "$3" <<'PY'
import datetime, json, sys
cred, fields, salts = sys.argv[1], json.loads(sys.argv[2]), json.loads(sys.argv[3])
ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"
print(json.dumps({"credentialID": cred, "disclosedFields": fields, "salts": salts, "timestamp": ts},
                 sort_keys=True, separators=(",", ":"), ensure_ascii=False))
PY
}

# salts_for KEY... — the decrypted _salts restricted to KEYs, as JSON.
salts_for() {
    printf '%s' "$DECRYPTED" | python3 -c '
import json, sys
salts = json.loads(sys.stdin.read())["_salts"]
print(json.dumps({k: salts[k] for k in sys.argv[1:]}))
' "$@"
}

# present ENDPOINT PAYLOAD SIGNATURE [HIDDEN_JSON] — POST a presentation.
present() {
    local endpoint="$1" payload="$2" sig="$3" hidden="${4:-[]}"
    curl -s -X POST "$API_URL/mobile/$endpoint" \
        -H "Content-Type: application/json" \
        -d "{\"credentialID\": \"$CRED_ID\", \"hiddenFields\": $hidden,
             \"disclosedPayload\": $(json_str "$payload"), \"holderSignature\": \"$sig\"}"
}

resolve() {
    curl -s -X POST "$API_URL/resolveSession" -H "Content-Type: application/json" \
        -d "{\"sessionToken\": \"$1\"}"
}

# resolve_fresh — sign a new full presentation and resolve it (sessions are
# single-use), printing the /resolveSession response.
resolve_fresh() {
    local payload sig resp
    payload=$(build_payload "$CRED_ID" "$FULL_FIELDS" "$(salts_for college degreeTitle gpa)")
    sig=$(keygen sign "$HOLDER_DSA_PRIV" "$payload")
    resp=$(present generatePresentation "$payload" "$sig")
    resolve "$(json_get "$resp" presentationID)"
}

detail() {
    curl -s "$API_URL/getCredentialDetail?credentialID=$CRED_ID"
}

echo "═══════════════════════════════════════════════════════════════════"
echo "  QChain End-to-End API Test Suite (chain & IPFS as source of truth)"
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
    -d "{\"holderID\": \"$HOLDER_ID\", \"emiratesID\": \"$EID\", \"firstName\": \"Tariq\", \"lastName\": \"Al Nuaimi\"}")
assert_json "$HOLDER_RESP" "data.get('holderID')" "$HOLDER_ID" "Holder $HOLDER_ID registered"

DUP_RESP=$(curl -s -X POST "$API_URL/registerHolder" \
    -H "Content-Type: application/json" \
    -d "{\"holderID\": \"$HOLDER_ID\", \"firstName\": \"Other\", \"lastName\": \"Name\"}")
assert_error "$DUP_RESP" "already registered" "Re-registering the same holder ID is refused by the chaincode"

# ─── 3. Check Keys Before Activation ─────────────────────────────────────────
echo ""
echo "3. Checking Keys Before Activation..."
KEYS_BEFORE=$(curl -s "$API_URL/mobile/checkKeys?emiratesID=$EID")
assert_json "$KEYS_BEFORE" "data.get('hasKemKey')" "False" "Holder initially has no KEM key"
assert_json "$KEYS_BEFORE" "data.get('hasSigningKey')" "False" "Holder initially has no signing key"

HOLDERS_BEFORE=$(curl -s "$API_URL/getHolders?search=$EID")
assert_json "$HOLDERS_BEFORE" "data.get('holders', [{}])[0].get('isWalletActivated')" "False" "Holder initially has isWalletActivated = false in /getHolders"

PROFILE_RESP=$(curl -s "$API_URL/mobile/getHolderProfile?emiratesID=$EID")
assert_json "$PROFILE_RESP" "data.get('fullName')" "Tariq Al Nuaimi" "Holder profile name comes from the chain"
assert_json "$PROFILE_RESP" "data.get('emiratesID')" "$EID" "Holder profile has matching Emirates ID"

# ─── 4. Generate Holder Keypairs ─────────────────────────────────────────────
echo ""
echo "4. Generating Holder Post-Quantum Keypairs via Docker..."
KEM_OUT=$(keygen kem)
HOLDER_KEM_PUB=$(echo "$KEM_OUT" | grep "^KEM_PUBLIC_KEY_HEX=" | cut -d= -f2)
HOLDER_KEM_PRIV=$(echo "$KEM_OUT" | grep "^KEM_PRIVATE_KEY_HEX=" | cut -d= -f2)
DSA_OUT=$(keygen dsa)
HOLDER_DSA_PUB=$(echo "$DSA_OUT" | grep "^DSA_PUBLIC_KEY_HEX=" | cut -d= -f2)
HOLDER_DSA_PRIV=$(echo "$DSA_OUT" | grep "^DSA_PRIVATE_KEY_HEX=" | cut -d= -f2)

if [ -n "$HOLDER_KEM_PUB" ] && [ -n "$HOLDER_DSA_PUB" ]; then
    pass "Generated ML-KEM-768 and ML-DSA-44 holder keypairs"
else
    fail "Key generation failed" "empty public keys"
fi

# ─── 5. Register Holder Keys ─────────────────────────────────────────────────
echo ""
echo "5. Registering Holder Public Keys (/mobile/registerHolderKeys)..."
SHORT_KEY_RESP=$(curl -s -X POST "$API_URL/mobile/registerHolderKeys" \
    -H "Content-Type: application/json" \
    -d "{\"emiratesID\": \"$EID\", \"kemPublicKey\": \"aabb\", \"dsaPublicKey\": \"$HOLDER_DSA_PUB\"}")
assert_error "$SHORT_KEY_RESP" "kemPublicKey must be 2368 hex characters" "Wrong-length KEM key rejected"

REG_KEYS_RESP=$(curl -s -X POST "$API_URL/mobile/registerHolderKeys" \
    -H "Content-Type: application/json" \
    -d "{\"emiratesID\": \"$EID\", \"kemPublicKey\": \"$HOLDER_KEM_PUB\", \"dsaPublicKey\": \"$HOLDER_DSA_PUB\"}")
assert_json "$REG_KEYS_RESP" "data.get('success')" "True" "Holder public keys bound on-chain"

KEYS_AFTER=$(curl -s "$API_URL/mobile/checkKeys?emiratesID=$EID")
assert_json "$KEYS_AFTER" "data.get('hasKemKey')" "True" "Holder now has KEM key"
assert_json "$KEYS_AFTER" "data.get('hasSigningKey')" "True" "Holder now has signing key"
assert_json "$KEYS_AFTER" "data.get('kemPublicKey')" "$HOLDER_KEM_PUB" "KEM public key read back from the chain matches"
assert_json "$KEYS_AFTER" "data.get('dsaPublicKey')" "$HOLDER_DSA_PUB" "DSA public key read back from the chain matches"

HOLDERS_AFTER=$(curl -s "$API_URL/getHolders?search=$EID")
assert_json "$HOLDERS_AFTER" "data.get('holders', [{}])[0].get('isWalletActivated')" "True" "Holder now has isWalletActivated = true in /getHolders"

# ─── 6. Issue Credential to Holder ───────────────────────────────────────────
echo ""
echo "6. Issuing Credential (salted field hashes, expiry on-chain, IPFS envelope)..."
CRED_INFO='{"degreeTitle":"BSc Computer Science","college":"CCI","gpa":"3.8","graduationYear":"2025","expiryDate":"30 Jun 2030"}'
BAD_ISSUE=$(curl -s -X POST "$API_URL/issueCredential" \
    -H "Content-Type: application/json" \
    -d "{\"holderEmiratesID\": \"$EID\", \"credentialType\": \"BSc Computer Science\", \"info\": $(json_str '{"gpa":3.8}')}")
assert_error "$BAD_ISSUE" 'must be a string' "Non-string attribute value rejected"

ISSUE_RESP=$(curl -s -X POST "$API_URL/issueCredential" \
    -H "Content-Type: application/json" \
    -d "{\"holderEmiratesID\": \"$EID\", \"credentialType\": \"BSc Computer Science\", \"info\": $(json_str "$CRED_INFO")}")
CRED_ID=$(json_get "$ISSUE_RESP" credentialID)
if [ -n "$CRED_ID" ]; then
    pass "Credential issued: $CRED_ID"
else
    fail "Credential issuance" "empty credentialID in response: $ISSUE_RESP"
fi
assert_json "$ISSUE_RESP" "data.get('expiryDate')" "2030-06-30" "Portal expiry format \"30 Jun 2030\" stored as 2030-06-30"
assert_json "$ISSUE_RESP" "bool(data.get('ipfsCID'))" "True" "Envelope uploaded to IPFS (CID returned)"

DETAIL=$(detail)
assert_json "$DETAIL" "data.get('status')" "active" "Detail (chain-backed): status active"
assert_json "$DETAIL" "data.get('expiryDate')" "2030-06-30" "Detail (chain-backed): expiry 2030-06-30"
assert_json "$DETAIL" "data.get('holderName')" "Tariq Al Nuaimi" "Detail (chain-backed): holder name"

# ─── 7. Retrieve and Decrypt Envelope ────────────────────────────────────────
echo ""
echo "7. Retrieving the Envelope from IPFS and Decrypting It as the Holder..."
ENV_RESP=$(curl -s "$API_URL/mobile/getEnvelope?credentialID=$CRED_ID")
assert_json "$ENV_RESP" "data.get('_qc_env')" "qchain-env" "Valid QChain envelope returned"
assert_json "$ENV_RESP" "data.get('v')" "2" "Envelope version 2"
assert_json "$ENV_RESP" "data.get('credId', '').startswith('env-')" "True" "Envelope HKDF context is a random env- ID"
assert_json "$ENV_RESP" "data.get('wraps')[0].get('recipient')" "holder" "Envelope is sealed to 'holder'"

DECRYPTED=$(printf '%s' "$ENV_RESP" | keygen decrypt "$HOLDER_KEM_PRIV")
assert_json "$DECRYPTED" "data.get('gpa')" "3.8" "Holder decrypts the GPA"
assert_json "$DECRYPTED" "sorted(data.get('_salts', {}))" "['college', 'degreeTitle', 'gpa', 'graduationYear']" "Envelope carries one salt per field"
assert_json "$DECRYPTED" "'expiryDate' in data" "False" "expiryDate is on-chain metadata, not an encrypted field"
FULL_FIELDS='{"college":"CCI","degreeTitle":"BSc Computer Science","gpa":"3.8"}'

# ─── 8. Generate Presentation Session ────────────────────────────────────────
echo ""
echo "8. Generating Presentation Session (/mobile/generatePresentation)..."
DISCLOSED_PAYLOAD=$(build_payload "$CRED_ID" "$FULL_FIELDS" "$(salts_for college degreeTitle gpa)")
HOLDER_SIG=$(keygen sign "$HOLDER_DSA_PRIV" "$DISCLOSED_PAYLOAD")
PRES_RESP=$(present generatePresentation "$DISCLOSED_PAYLOAD" "$HOLDER_SIG" '["graduationYear"]')
assert_json "$PRES_RESP" "data.get('success')" "True" "Presentation session generated"
PRES_ID=$(json_get "$PRES_RESP" presentationID)
EXPIRES_AT=$(json_get "$PRES_RESP" expiresAt)
if [[ "$EXPIRES_AT" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
    pass "expiresAt is in Asia/Dubai local format ($EXPIRES_AT)"
else
    fail "expiresAt format" "expected YYYY-MM-DDTHH:MM:SS without Z, got $EXPIRES_AT"
fi

# ─── 9. Resolve Session (5-check Verification) ───────────────────────────────
echo ""
echo "9. Resolving Session with 5 Cryptographic Checks (/resolveSession)..."
RESOLVE_RESP=$(resolve "$PRES_ID")
assert_json "$RESOLVE_RESP" "data.get('verified')" "True" "Verification result is VERIFIED: TRUE"
assert_json "$RESOLVE_RESP" "data.get('checks', {}).get('existsOnChain')" "True" "Check 1: existsOnChain = true"
assert_json "$RESOLVE_RESP" "data.get('checks', {}).get('notRevoked')" "True" "Check 2: notRevoked = true"
assert_json "$RESOLVE_RESP" "data.get('checks', {}).get('signatureValid')" "True" "Check 3: signatureValid (issuer, recomputed commitment) = true"
assert_json "$RESOLVE_RESP" "data.get('checks', {}).get('fieldHashesValid')" "True" "Check 4: fieldHashesValid (salted) = true"
assert_json "$RESOLVE_RESP" "data.get('checks', {}).get('holderSignatureValid')" "True" "Check 5: holderSignatureValid = true"
assert_json "$RESOLVE_RESP" "data.get('credentialData', {}).get('gpa')" "3.8" "Disclosed GPA attribute matches"
assert_json "$RESOLVE_RESP" "'graduationYear' in data.get('credentialData', {})" "False" "Hidden field is not disclosed"
assert_json "$RESOLVE_RESP" "data.get('expiryDate')" "2030-06-30" "Expiry reported from the chain"
assert_json "$(resolve "$PRES_ID")" "data.get('error', '')[:17]" "Session not found" "Sessions are single-use"

# ─── 10. Tamper Detection Tests ──────────────────────────────────────────────
echo ""
echo "10. Running Tamper Detection Tests..."

# A: GPA fabrication — holder changes 3.8 -> 4.0 and re-signs.
PAYLOAD=$(build_payload "$CRED_ID" '{"college":"CCI","degreeTitle":"BSc Computer Science","gpa":"4.0"}' "$(salts_for college degreeTitle gpa)")
RESP=$(resolve "$(json_get "$(present generatePresentation "$PAYLOAD" "$(keygen sign "$HOLDER_DSA_PRIV" "$PAYLOAD")")" presentationID)")
assert_json "$RESP" "data.get('verified')" "False" "Tampered GPA rejected"
assert_json "$RESP" "data.get('reason')" "FIELD_HASHES_INVALID" "Tampered GPA → FIELD_HASHES_INVALID"
assert_json "$RESP" "data.get('checks', {}).get('holderSignatureValid')" "True" "Holder signature itself was valid on the fabricated value"

# B: Wrong salt — a well-formed salt that is not the one issued for gpa.
PAYLOAD=$(build_payload "$CRED_ID" '{"gpa":"3.8"}' '{"gpa":"0123456789abcdef0123456789abcdef"}')
RESP=$(resolve "$(json_get "$(present generatePresentation "$PAYLOAD" "$(keygen sign "$HOLDER_DSA_PRIV" "$PAYLOAD")")" presentationID)")
assert_json "$RESP" "data.get('checks', {}).get('fieldHashesValid')" "False" "Wrong salt caught by fieldHashesValid = false"

# C: Forged holder signature.
RESP=$(resolve "$(json_get "$(present generatePresentation "$DISCLOSED_PAYLOAD" "11223344556677889900aabbccddeeff")" presentationID)")
assert_json "$RESP" "data.get('verified')" "False" "Forged signature rejected"
assert_json "$RESP" "data.get('reason')" "HOLDER_SIGNATURE_INVALID" "Forged signature → HOLDER_SIGNATURE_INVALID"

# D–F: malformed presentations fail fast at generation (HTTP 400).
PAYLOAD=$(build_payload "$CRED_ID" "$FULL_FIELDS" '{}')
assert_error "$(present generatePresentation "$PAYLOAD" "$HOLDER_SIG")" "salts missing for field" "Presentation without salts rejected"
PAYLOAD=$(build_payload "$CRED_ID" '{"gpa":"3.8"}' "$(salts_for gpa graduationYear)")
assert_error "$(present generatePresentation "$PAYLOAD" "$HOLDER_SIG")" "salt provided for undisclosed field" "Salt for a hidden field rejected"
PAYLOAD=$(build_payload "CRED-9999" "$FULL_FIELDS" "$(salts_for college degreeTitle gpa)")
assert_error "$(present generatePresentation "$PAYLOAD" "$(keygen sign "$HOLDER_DSA_PRIV" "$PAYLOAD")")" "does not match" "Mismatched credentialID in disclosedPayload rejected"

# ─── 11. OTP Session Flow ───────────────────────────────────────────────────
echo ""
echo "11. Testing OTP Presentation Flow (/mobile/generateOTP)..."
OTP_RESP=$(present generateOTP "$DISCLOSED_PAYLOAD" "$HOLDER_SIG")
assert_json "$OTP_RESP" "data.get('success')" "True" "OTP generated successfully"
OTP_CODE=$(json_get "$OTP_RESP" otp)
assert_json "$(resolve "OTP-$OTP_CODE")" "data.get('verified')" "True" "OTP redeemed and verified successfully"

# ─── 12. Credential Lifecycle (verified through fresh presentations) ─────────
echo ""
echo "12. Testing Credential Lifecycle (Suspend → Restore → Expiry → Revoke)..."

SUSP_RESP=$(curl -s -X POST "$API_URL/suspendCredential" -H "Content-Type: application/json" \
    -d "{\"credentialID\": \"$CRED_ID\", \"reason\": \"Investigation pending\"}")
assert_json "$SUSP_RESP" "data.get('message')" "Credential suspended successfully" "Credential suspended"
RESP=$(resolve_fresh)
assert_json "$RESP" "data.get('reason')" "SUSPENDED" "Suspended credential → SUSPENDED"
assert_json "$(detail)" "data.get('status')" "suspended" "Detail shows suspended (from the chain)"

REST_RESP=$(curl -s -X POST "$API_URL/restoreCredential" -H "Content-Type: application/json" \
    -d "{\"credentialID\": \"$CRED_ID\"}")
assert_json "$REST_RESP" "data.get('message')" "Credential restored successfully" "Credential restored"
assert_json "$(resolve_fresh)" "data.get('verified')" "True" "Restored credential verifies again"

# Expiry is signed: moving it into the past re-signs the commitment on-chain.
UPD_RESP=$(curl -s -X POST "$API_URL/updateCredential" -H "Content-Type: application/json" \
    -d "{\"credentialID\": \"$CRED_ID\", \"expiryDate\": \"2020-01-01\"}")
assert_json "$UPD_RESP" "data.get('success')" "True" "Expiry moved to 2020-01-01 (re-signed)"
RESP=$(resolve_fresh)
assert_json "$RESP" "data.get('reason')" "EXPIRED" "Past expiry → EXPIRED"
assert_json "$RESP" "data.get('checks', {}).get('signatureValid')" "True" "Re-signed commitment still verifies"
DETAIL=$(detail)
assert_json "$DETAIL" "data.get('status')" "expired" "Detail shows expired (derived from the chain expiry)"
assert_json "$DETAIL" "data.get('expiryDate')" "2020-01-01" "Detail shows the new expiry"
assert_error "$(curl -s -X POST "$API_URL/suspendCredential" -H "Content-Type: application/json" \
    -d "{\"credentialID\": \"$CRED_ID\", \"reason\": \"x\"}")" "cannot suspend expired credential" "Expired credential cannot be suspended"
assert_error "$(curl -s -X POST "$API_URL/updateCredential" -H "Content-Type: application/json" \
    -d "{\"credentialID\": \"$CRED_ID\", \"expiryDate\": \"soon\"}")" "invalid expiryDate format" "Unparseable expiry rejected"

UPD_RESP=$(curl -s -X POST "$API_URL/updateCredential" -H "Content-Type: application/json" \
    -d "{\"credentialID\": \"$CRED_ID\", \"expiryDate\": \"30 Jun 2030\"}")
assert_json "$UPD_RESP" "data.get('success')" "True" "Expiry restored to 30 Jun 2030"
assert_json "$(resolve_fresh)" "data.get('verified')" "True" "Credential verifies again after the expiry change"

REV_RESP=$(curl -s -X POST "$API_URL/revokeCredential" -H "Content-Type: application/json" \
    -d "{\"credentialID\": \"$CRED_ID\"}")
assert_json "$REV_RESP" "data.get('message')" "Credential revoked successfully" "Credential permanently revoked"
RESP=$(resolve_fresh)
assert_json "$RESP" "data.get('reason')" "REVOKED" "Revoked credential → REVOKED"
assert_json "$RESP" "data.get('checks', {}).get('notRevoked')" "False" "notRevoked = false"
assert_json "$(detail)" "data.get('status')" "revoked" "Detail shows revoked (from the chain)"
assert_error "$(curl -s -X POST "$API_URL/revokeCredential" -H "Content-Type: application/json" \
    -d "{\"credentialID\": \"$CRED_ID\"}")" "already revoked" "Revoked credential cannot be revoked again"
assert_error "$(curl -s -X POST "$API_URL/restoreCredential" -H "Content-Type: application/json" \
    -d "{\"credentialID\": \"$CRED_ID\"}")" "cannot restore revoked credential" "Revoked credential cannot be restored"
assert_error "$(curl -s -X POST "$API_URL/updateCredential" -H "Content-Type: application/json" \
    -d "{\"credentialID\": \"$CRED_ID\", \"expiryDate\": \"2031-01-01\"}")" "cannot update a revoked credential" "Revoked credential cannot be edited"

# ─── 13. Audit & Dashboard Queries ───────────────────────────────────────────
echo ""
echo "13. Testing Audit & Dashboard Queries..."
ALL_RESP=$(curl -s "$API_URL/getAllCredentials?status=revoked&limit=100")
assert_json "$ALL_RESP" "any(c.get('credentialID') == '$CRED_ID' for c in data.get('credentials', []))" "True" "getAllCredentials?status=revoked lists the credential"

HISTORY_RESP=$(curl -s "$API_URL/getVerificationHistory?page=1&limit=5")
assert_json "$HISTORY_RESP" "'records' in data" "True" "Verification history returns records list"
assert_json "$HISTORY_RESP" "data['records'][0].get('credentialType')" "BSc Computer Science" "History labels come from the chain"

STATS_RESP=$(curl -s "$API_URL/getDashboardStats")
assert_json "$STATS_RESP" "data.get('totalIssued', 0) >= 1" "True" "Dashboard stats computed from the chain"

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
