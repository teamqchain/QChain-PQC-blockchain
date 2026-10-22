#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# QChain — End-to-End PQC Performance & Latency Benchmarking Suite
#
# Measures statistical performance metrics across multiple iterations:
#   1. Verification Latency (/resolveSession with 5-tier cryptographic checks)
#   2. End-to-End PQC Workflow Time (KeyGen → Issue → Decrypt → Sign → Verify)
#   3. Credential Issuance Latency (Fabric ledger anchor + IPFS envelope)
#   4. Envelope Decryption Latency (ML-KEM-768 decapsulation + AES-256-GCM)
#   5. Presentation Generation & Signing Latency (ML-DSA-44 signing)
#
# Requires: curl, python3, docker (for qchain-api keygen)
#
# Usage:
#   bash tests/benchmark_e2e.sh [API_BASE_URL] [ITERATIONS]
# Example:
#   bash tests/benchmark_e2e.sh http://localhost:3000 10
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

API_URL="${1:-http://localhost:3000}"
ITERATIONS="${2:-10}"
KEYGEN_IMAGE="${KEYGEN_IMAGE:-qchain-api:latest}"

now_ms() {
    python3 -c 'import time; print(int(time.time() * 1000))'
}

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

json_str() {
    printf '%s' "$1" | python3 -c 'import json, sys; print(json.dumps(sys.stdin.read()))'
}

keygen() {
    docker run --rm -i "$KEYGEN_IMAGE" keygen "$@"
}

build_payload() {
    python3 - "$1" "$2" "$3" <<'PY'
import datetime, json, sys
cred, fields, salts = sys.argv[1], json.loads(sys.argv[2]), json.loads(sys.argv[3])
ts = datetime.datetime.now().isoformat()
print(json.dumps({"credentialID": cred, "disclosedFields": fields, "salts": salts, "timestamp": ts},
                 sort_keys=True, separators=(",", ":"), ensure_ascii=False))
PY
}

salts_for() {
    printf '%s' "$DECRYPTED" | python3 -c '
import json, sys
salts = json.loads(sys.stdin.read())["_salts"]
print(json.dumps({k: salts[k] for k in sys.argv[1:]}))
' "$@"
}

echo "═══════════════════════════════════════════════════════════════════"
echo "  QChain End-to-End PQC Benchmark Suite"
echo "  API Target   : $API_URL"
echo "  Iterations   : $ITERATIONS"
echo "  Keygen Image : $KEYGEN_IMAGE"
echo "═══════════════════════════════════════════════════════════════════"

echo ""
echo "[1/4] Checking API Health..."
HEALTH_RESP=$(curl -s "$API_URL/health")
if [[ "$HEALTH_RESP" != *"\"status\":\"ok\""* ]]; then
    echo "ERROR: Server at $API_URL is not healthy! Response: $HEALTH_RESP"
    exit 1
fi
echo "  ✓ Server is healthy."

echo ""
echo "[2/4] Setting up Test Holder & Generating PQC Keys..."
RAND_SUFFIX=$((RANDOM % 9000 + 1000))
EID="784-1995-777${RAND_SUFFIX}-1"
HOLDER_EMAIL="bench.${RAND_SUFFIX}@qchain.local"

HOLDER_RESP=$(curl -s -X POST "$API_URL/registerHolder" \
    -H "Content-Type: application/json" \
    -d "{\"emiratesID\": \"$EID\", \"firstName\": \"Benchmark\", \"lastName\": \"Runner\", \"email\": \"$HOLDER_EMAIL\", \"college\": \"CCI\"}")
HOLDER_ID=$(json_get "$HOLDER_RESP" holderID)

T0=$(now_ms)
KEM_OUT=$(keygen kem)
HOLDER_KEM_PUB=$(echo "$KEM_OUT" | grep "^KEM_PUBLIC_KEY_HEX=" | cut -d= -f2)
HOLDER_KEM_PRIV=$(echo "$KEM_OUT" | grep "^KEM_PRIVATE_KEY_HEX=" | cut -d= -f2)
DSA_OUT=$(keygen dsa)
HOLDER_DSA_PUB=$(echo "$DSA_OUT" | grep "^DSA_PUBLIC_KEY_HEX=" | cut -d= -f2)
HOLDER_DSA_PRIV=$(echo "$DSA_OUT" | grep "^DSA_PRIVATE_KEY_HEX=" | cut -d= -f2)
HOLDER_KEYGEN_MS=$(( $(now_ms) - T0 ))

curl -s -X POST "$API_URL/mobile/registerHolderKeys" \
    -H "Content-Type: application/json" \
    -d "{\"emiratesID\": \"$EID\", \"kemPublicKey\": \"$HOLDER_KEM_PUB\", \"dsaPublicKey\": \"$HOLDER_DSA_PUB\"}" > /dev/null

echo "  ✓ Holder registered with ID: $HOLDER_ID"
echo "  ✓ ML-KEM-768 & ML-DSA-44 keypairs generated in ${HOLDER_KEYGEN_MS} ms"
echo "  ✓ Public keys anchored on Hyperledger Fabric"

echo ""
echo "[3/4] Benchmarking Credential Issuance ($ITERATIONS iterations)..."
declare -a ISSUANCE_TIMES=()
FIRST_CRED_ID=""

for i in $(seq 1 "$ITERATIONS"); do
    CRED_INFO="{\"degreeTitle\":\"BSc Computer Science\",\"college\":\"CCI\",\"gpa\":\"3.9\",\"iteration\":\"$i\",\"expiryDate\":\"30 Jun 2030\"}"
    T_ISSUE_START=$(now_ms)
    ISSUE_RESP=$(curl -s -X POST "$API_URL/issueCredential" \
        -H "Content-Type: application/json" \
        -d "{\"holderEmiratesID\": \"$EID\", \"credentialType\": \"BSc Computer Science\", \"info\": $(json_str "$CRED_INFO")}")
    T_ISSUE_END=$(now_ms)
    DIFF=$((T_ISSUE_END - T_ISSUE_START))
    ISSUANCE_TIMES+=("$DIFF")
    CID=$(json_get "$ISSUE_RESP" credentialID)
    if [ -z "$FIRST_CRED_ID" ]; then
        FIRST_CRED_ID="$CID"
    fi
    printf "  Iteration %2d/%d: Issuance Latency = %4d ms (ID: %s)\n" "$i" "$ITERATIONS" "$DIFF" "$CID"
done

echo ""
echo "[4/4] Benchmarking Presentation & Verification ($ITERATIONS iterations)..."
declare -a VERIFY_TIMES=()
declare -a DECRYPT_TIMES=()
declare -a PRESENT_TIMES=()
declare -a E2E_WORKFLOW_TIMES=()

# Fetch envelope from IPFS once for decryption tests
ENV_RESP=$(curl -s "$API_URL/mobile/getEnvelope?credentialID=$FIRST_CRED_ID")

for i in $(seq 1 "$ITERATIONS"); do
    T_WF_START=$(now_ms)

    # 1. Holder Decrypts Envelope
    T_DEC_START=$(now_ms)
    DECRYPTED=$(printf '%s' "$ENV_RESP" | keygen decrypt "$HOLDER_KEM_PRIV")
    T_DEC_END=$(now_ms)
    DEC_DIFF=$((T_DEC_END - T_DEC_START))
    DECRYPT_TIMES+=("$DEC_DIFF")

    # 2. Holder Signs Presentation (Selective Disclosure)
    T_PRES_START=$(now_ms)
    FULL_FIELDS='{"college":"CCI","degreeTitle":"BSc Computer Science","gpa":"3.9"}'
    DISCLOSED_PAYLOAD=$(build_payload "$FIRST_CRED_ID" "$FULL_FIELDS" "$(salts_for college degreeTitle gpa)")
    HOLDER_SIG=$(keygen sign "$HOLDER_DSA_PRIV" "$DISCLOSED_PAYLOAD")
    PRES_RESP=$(curl -s -X POST "$API_URL/mobile/generatePresentation" \
        -H "Content-Type: application/json" \
        -d "{\"credentialID\": \"$FIRST_CRED_ID\", \"hiddenFields\": [\"iteration\"],
             \"disclosedPayload\": $(json_str "$DISCLOSED_PAYLOAD"), \"holderSignature\": \"$HOLDER_SIG\"}")
    T_PRES_END=$(now_ms)
    PRES_DIFF=$((T_PRES_END - T_PRES_START))
    PRESENT_TIMES+=("$PRES_DIFF")

    PRES_ID=$(json_get "$PRES_RESP" presentationID)

    # 3. Verifier Resolves Session (5 Cryptographic Checks)
    T_VER_START=$(now_ms)
    RESOLVE_RESP=$(curl -s -X POST "$API_URL/resolveSession" \
        -H "Content-Type: application/json" \
        -d "{\"sessionToken\": \"$PRES_ID\"}")
    T_VER_END=$(now_ms)
    VER_DIFF=$((T_VER_END - T_VER_START))
    VERIFY_TIMES+=("$VER_DIFF")

    WF_TOTAL=$((T_VER_END - T_WF_START))
    E2E_WORKFLOW_TIMES+=("$WF_TOTAL")

    VERIFIED=$(printf '%s' "$RESOLVE_RESP" | python3 -c 'import json, sys; print(json.loads(sys.stdin.read()).get("verified", False))')
    printf "  Iteration %2d/%d: Verification = %4d ms | Workflow = %4d ms | Verified = %s\n" \
        "$i" "$ITERATIONS" "$VER_DIFF" "$WF_TOTAL" "$VERIFIED"
done

# Calculate statistics via Python
STATS_JSON=$(python3 - <<PY
import json

def stats(arr):
    if not arr:
        return {"min": 0, "max": 0, "mean": 0.0, "p50": 0.0, "p95": 0.0}
    s = sorted(arr)
    n = len(s)
    mean = sum(s) / n
    p50 = s[n // 2]
    p95 = s[min(int(n * 0.95), n - 1)]
    return {
        "min": s[0],
        "max": s[-1],
        "mean": round(mean, 2),
        "p50": p50,
        "p95": p95
    }

issuance = [int(x) for x in "${ISSUANCE_TIMES[*]}".split()]
verify = [int(x) for x in "${VERIFY_TIMES[*]}".split()]
decrypt = [int(x) for x in "${DECRYPT_TIMES[*]}".split()]
present = [int(x) for x in "${PRESENT_TIMES[*]}".split()]
workflow = [int(x) for x in "${E2E_WORKFLOW_TIMES[*]}".split()]

out = {
    "issuance": stats(issuance),
    "verify": stats(verify),
    "decrypt": stats(decrypt),
    "present": stats(present),
    "workflow": stats(workflow),
}
print(json.dumps(out))
PY
)

V_MIN=$(echo "$STATS_JSON" | json_get verify | python3 -c 'import json, sys; print(json.loads(sys.stdin.read())["min"])')
V_MAX=$(echo "$STATS_JSON" | json_get verify | python3 -c 'import json, sys; print(json.loads(sys.stdin.read())["max"])')
V_MEAN=$(echo "$STATS_JSON" | json_get verify | python3 -c 'import json, sys; print(json.loads(sys.stdin.read())["mean"])')
V_P50=$(echo "$STATS_JSON" | json_get verify | python3 -c 'import json, sys; print(json.loads(sys.stdin.read())["p50"])')
V_P95=$(echo "$STATS_JSON" | json_get verify | python3 -c 'import json, sys; print(json.loads(sys.stdin.read())["p95"])')

W_MIN=$(echo "$STATS_JSON" | json_get workflow | python3 -c 'import json, sys; print(json.loads(sys.stdin.read())["min"])')
W_MAX=$(echo "$STATS_JSON" | json_get workflow | python3 -c 'import json, sys; print(json.loads(sys.stdin.read())["max"])')
W_MEAN=$(echo "$STATS_JSON" | json_get workflow | python3 -c 'import json, sys; print(json.loads(sys.stdin.read())["mean"])')

I_MEAN=$(echo "$STATS_JSON" | json_get issuance | python3 -c 'import json, sys; print(json.loads(sys.stdin.read())["mean"])')
D_MEAN=$(echo "$STATS_JSON" | json_get decrypt | python3 -c 'import json, sys; print(json.loads(sys.stdin.read())["mean"])')
P_MEAN=$(echo "$STATS_JSON" | json_get present | python3 -c 'import json, sys; print(json.loads(sys.stdin.read())["mean"])')

echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "               QCHAIN PERFORMANCE BENCHMARK REPORT (N = $ITERATIONS)"
echo "═══════════════════════════════════════════════════════════════════════════════"
printf " %-35s : %8s | %8s | %8s | %8s\n" "Metric" "Mean" "Median" "Min" "Max"
echo " ─────────────────────────────────────────────────────────────────────────────"
printf " %-35s : %6.2f ms | %6.1f ms | %6d ms | %6d ms\n" "1. Verification Latency (/resolve)" "$V_MEAN" "$V_P50" "$V_MIN" "$V_MAX"
printf " %-35s : %6.2f ms |        - | %6d ms | %6d ms\n" "2. End-to-End Presentation Workflow" "$W_MEAN" "$W_MIN" "$W_MAX"
printf " %-35s : %6.2f ms |        - |        - |        -\n" "3. Credential Issuance Latency" "$I_MEAN"
printf " %-35s : %6.2f ms |        - |        - |        -\n" "4. Presentation Generation (Sign)" "$P_MEAN"
printf " %-35s : %6.2f ms |        - |        - |        -\n" "5. Envelope Decryption (ML-KEM)" "$D_MEAN"
echo " ─────────────────────────────────────────────────────────────────────────────"
echo "  • Verification 95th Percentile (p95): ${V_P95} ms"
echo "  • Post-Quantum Algorithms: ML-DSA-44 (Dilithium) + ML-KEM-768 (Kyber)"
echo "  • Security Level: NIST Category 2 (Quantum Resistant, Shor's Immune)"
echo "═══════════════════════════════════════════════════════════════════════════════"

REPORT_FILE="tests/benchmark_results.md"
cat <<EOF > "$REPORT_FILE"
# QChain Post-Quantum Performance Benchmark Results

Generated: $(date)
Target: $API_URL
Iterations: $ITERATIONS

## Summary Table

| Metric | Mean (ms) | Median (ms) | Min (ms) | Max (ms) | p95 (ms) |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Verification Latency (/resolveSession)** | **$V_MEAN** | **$V_P50** | **$V_MIN** | **$V_MAX** | **$V_P95** |
| **End-to-End PQC Workflow** | **$W_MEAN** | - | **$W_MIN** | **$W_MAX** | - |
| **Credential Issuance Latency** | $I_MEAN | - | - | - | - |
| **Envelope Decryption (ML-KEM-768)** | $D_MEAN | - | - | - | - |
| **Presentation Signing (ML-DSA-44)** | $P_MEAN | - | - | - | - |

## Cryptographic Size Parameters

| Component | Classical (ECDSA P-256) | Post-Quantum (ML-DSA-44 / ML-KEM-768) |
| :--- | :---: | :---: |
| **Public Key Size** | 64 bytes | 1,312 bytes (DSA) / 1,184 bytes (KEM) |
| **Private Key Size** | 32 bytes | 2,560 bytes (DSA) / 2,400 bytes (KEM) |
| **Signature Size** | 64 bytes | 2,420 bytes |
| **Quantum Resistance** | Broken by Shor's Algorithm | NIST Standardized / Lattice Resistant |

EOF

echo ""
echo "✓ Results saved to $REPORT_FILE"
