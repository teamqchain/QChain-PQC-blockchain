# QChain — Phase 2 · Track B2 & Track H: Off-Chain Credential Encryption & Holder Presentation Signing

**Status:** Implemented (Track B2 holder-held-key encryption + Track H holder presentation signing & verification). Chaincode updated with `bindHolderKeys` (with issuer access control per Audit §4.1) and `fieldHashes` on `issueCredential`. Fail-closed presentation binding implemented per Audit §4.2. Requires chaincode package upgrade on Fabric.  
**Audience:** QChain contributors — past and future. Read this before touching credential storage, presentation verification, or crypto modules.  
**Date:** 2026-09 (upgraded from B3 org-held-key phase, 2026-07)  
**Related:** `QChain_Phase2_Security_Plan.md` (gap analysis), `docs/phase2-trackB-offchain-encryption.md` (original track B specification).

---

## 1. TL;DR

Prior to Phase 2, credential attribute bodies were stored **in plaintext in three places**:
1. On-chain in the Fabric ledger world-state (`Info` field).
2. Off-chain in IPFS (addressed by content CID).
3. Off-chain in the MySQL database (`credential_data` column).

This track accomplishes two major cryptographic upgrades:

1. **Track B2 — Off-Chain At-Rest Confidentiality:** Encrypts the **two off-chain stores** (IPFS + MySQL) using a post-quantum hybrid envelope (**ML-KEM-768 + AES-256-GCM**), wrapping each attribute data key to the **holder's ML-KEM public key** (`"holder:<holderID>"`). Only the holder possesses the secret key required for decryption on their mobile device. All org KEM keys and server-side holder private key custody (`.env.holder_keys`) have been completely eradicated.
2. **Track H — On-Device Holder Presentation Signing & 5-Check Verification:** The holder generates an **ML-DSA-44** key pair on device and registers the public key via `POST /mobile/registerHolderKeys`. When presenting credentials (via QR `PRES-...` or 6-digit `OTP-...`), the holder signs a canonical JSON payload binding the `credentialID` and disclosed fields. Verifiers resolve the session via `POST /resolveSession`, which evaluates **5 cryptographic checks** including verifying field hashes and holder ML-DSA signatures.

**Audit Remediations Included:**
- **Audit §4.1 (Chaincode Access Control):** `bindHolderKeys` in `QChaincode.js` is guarded with `await this.checkAccess(ctx, "issuer")`, ensuring only authorized issuer gateway identities can bind public keys on ledger.
- **Audit §4.2 (Fail-Closed Credential ID Binding):** Both presentation creation (`handleGenerateOTP`, `handleGeneratePresentation`) and resolution (`handleResolveSession`) strictly enforce non-empty, matching `credentialID` in the signed payload. Disclosed payload tampering or mismatched credential IDs fail closed immediately with `HTTP 400` or `failureReason = "credential_id_mismatch"`.

---

## 2. Architecture & Design Context

While implementing Track B and Track H, analysis of the running codebase revealed that the original premise — *"only metadata is on-chain, so simply encrypt IPFS"* — did not match reality:
- `handleIssueCredential` (`offchain/credentials.go`) serialized the full attribute JSON into the chaincode transaction payload, and the chaincode recorded that string directly on every peer's ledger in `Info`.
- Legacy verification never fetched from IPFS; both `handleVerifyCredential` and `handleResolveSession` fetched `Info` from the chain and recomputed `SHA3-256(Info)`.

### How Track H Decouples Presentation from On-Chain Plaintext
To enable selective disclosure and prepare for eventual on-chain plaintext removal (Track A):
1. During `issueCredential`, the backend computes a map of individual field hashes: `FieldHashes[field] = SHA3-256(field + ":" + value)`. This map is written to the ledger alongside the credential.
2. When presenting, the holder shares only disclosed fields in `disclosedPayload` signed with their ML-DSA-44 private key.
3. During verification in `handleResolveSession`, each disclosed field is verified against `FieldHashes`. The verifier no longer needs to re-hash the entire plaintext `Info` field.

---

## 3. What Was Changed (File by File)

### New Files (B2 & Track H)

| File | Purpose |
|---|---|
| `qchain-network/scripts/migrations/2026-09_trackB2_holder_keys.sql` | Migration marker documenting B2 transition (`holders.kem_public_key`). |
| `qchain-network/scripts/migrations/2026-09_trackH_holder_signing.sql` | Migration adding `holders.dsa_public_key` and `holders.wallet_activated`. |

### Core Backend & Crypto Files

| File | Change |
|---|---|
| `offchain/kem.go` | Low-level primitives: ML-KEM-768 encap/decap (via `liboqs`), HKDF-SHA3-256 derivation, AES-256-GCM seal/open. Removed org KEM key generation. |
| `offchain/crypto.go` | ML-DSA-44 PQC signing (`pqcSign`) and verification (`pqcVerify`) via `liboqs-go`. Used for issuer credential signing and holder presentation verification. |
| `offchain/envelope.go` | `encryptCredentialDataToHolder(credID, attrs, holderKemPubHex)` wraps attribute keys to `"holder"`. Client on-device decryption reverses this. |
| `offchain/config.go` | Preserves issuer signing keys (`ISSUER_PRIVATE_KEY_HEX`, `ISSUER_PUBLIC_KEY_HEX`). All `ORG_KEM_*` variables removed. |
| `offchain/server.go` | Removed local `.env.holder_keys` loading, removed `GENERATE_HOLDER_KEYS` and `GENERATE_ORG_KEM` one-shot triggers, removed deprecated `/mobile/registerHolderKey` endpoint. |
| `offchain/mobile.go` | Core mobile API: `POST /mobile/registerHolderKeys` (binds KEM + DSA keys), `GET /mobile/getEnvelope` (returns encrypted ciphertext), `GET /mobile/getCredentialsByHolder` (returns ciphertext envelopes without server-side decryption), fail-closed `POST /mobile/generateOTP` & `POST /mobile/generatePresentation` (Audit §4.2), and 5-check `POST /resolveSession`. |
| `offchain/credentials.go` | `handleIssueCredential` requires `holderKemPub`, generates `fieldHashes`, encrypts body to holder key, and passes `fieldHashes` to chaincode. |
| `offchain/server_test.go` | Unit test suite with comprehensive commented-out run guide, handler input validation tests, selective disclosure tests, field hashes verification tests, presentation payload parsing tests, and ML-DSA presentation signing tests. |
| `offchain/envelope_test.go` | Unit tests for ML-KEM-768 hybrid envelope encryption, decryption, tamper detection, and holder wrapping. |
| `qchain-network/chaincode/QChaincode.js` | Added `bindHolderKeys(holderID, kemPubKey, dsaPubKey)` guarded by `await this.checkAccess(ctx, "issuer")`. Updated `issueCredential` to store `fieldHashes` map on ledger. |
| `tests/e2e_api_test.sh` | Automated end-to-end integration script testing full issuance, envelope retrieval, presentation session creation, 5-check resolution, and tamper detection tests. |

### Decommissioned Elements
- `offchain/holder_keys.go`: **Deleted.**
- `offchain/cmd/kemkeygen/`: **Deleted.**
- `.env.holder_keys`: **Eradicated.** Server never holds holder private keys.

---

## 4. Cryptographic Specifications

### 4.1 Hybrid KEM-DEM Envelope Encryption (Track B2)
Envelopes stored in MySQL `credential_data` and IPFS use quantum-safe hybrid encryption:

1. **Encapsulation:** The backend encapsulates a 32-byte shared secret `ss` to the holder's ML-KEM-768 public key (`kemPublicKey`), yielding KEM ciphertext `ct`. Recipient is marked as `"holder"`.
2. **Per-Field Data Keys:** For each attribute field `i`:
   - Generate a random 32-byte data key $K_i$.
   - Encrypt the field value with AES-256-GCM using a random 12-byte nonce: $C_i = \text{AES-GCM-Seal}(K_i, \text{nonce}_i, \text{value}_i)$.
   - Derive a key-wrapping key: $KWK_i = \text{HKDF-SHA3-256}(ss, \text{"qchain/trackB/v1|" } + \text{credID} + \text{"|" } + \text{key}_i)$.
   - Wrap $K_i$ under $KWK_i$ using AES-256-GCM with a fixed nonce (safe because every $KWK_i$ is single-use).
3. **Envelope JSON:**
   ```json
   {
     "_qc_env": "qchain-env",
     "v": 1,
     "kemAlg": "ML-KEM-768",
     "aeadAlg": "AES-256-GCM",
     "kdf": "HKDF-SHA3-256",
     "credId": "CRED-XXXX",
     "wraps": [{ "recipient": "holder", "enc": "<hex>" }],
     "fields": [
       {
         "key": "gpa",
         "wrap": { "holder": { "wkey": "<hex>", "tag": "<hex>" } },
         "nonce": "<hex>",
         "ct": "<hex>"
       }
     ]
   }
   ```
4. **On-Device Decryption (`UI_App/lib/services/crypto_service.dart`):**
   The mobile app decapsulates `ss` using its local ML-KEM-768 private key, derives $KWK_i$, unwraps $K_i$, and decrypts each field.

### 4.2 Presentation Signing & 5-Check Verification (Track H)

#### Presentation Payload Structure
The mobile app constructs a canonical JSON string:
```json
{
  "credentialID": "CRED-2026-0001",
  "disclosedFields": {
    "college": "CCI",
    "degreeTitle": "BSc Computer Science",
    "gpa": "3.8"
  },
  "timestamp": "2026-09-22T13:00:00"
}
```
The holder signs `SHA3-256(canonical JSON string)` using their **ML-DSA-44** private key stored in iOS Keychain / Android Keystore.

#### Fail-Closed Session Creation (`/mobile/generateOTP`, `/mobile/generatePresentation`)
1. Rejects if `credentialID`, `disclosedPayload`, or `holderSignature` is missing/empty (`HTTP 400`).
2. Unmarshals `disclosedPayload` JSON. Rejects if `credentialID` is missing or does not match request `credentialID` (`HTTP 400`).
3. Saves the session with 120-second TTL in Asia/Dubai local timestamp format.

#### 5-Check Verification (`/resolveSession`)
When a verifier resolves a QR code or OTP token:
```
                                 ┌──────────────────────────────────┐
                                 │  POST /resolveSession (token)    │
                                 └─────────────────┬────────────────┘
                                                   │
                ┌──────────────────────────────────┴─────────────────────────────────┐
                ▼                                                                    ▼
      1. Check Existence & Status                                           2. Check Signatures & Integrity
      • existsOnChain == true                                               • signatureValid == true (Issuer ML-DSA-44)
      • notRevoked == true (status == "active")                             • credentialIDMatches == true (Audit §4.2)
                                                                            • fieldHashesValid == true (Disclosed fields)
                                                                            • holderSignatureValid == true (Holder ML-DSA-44)
```

1. **`existsOnChain`:** Credential record retrieved from Fabric ledger.
2. **`notRevoked`:** Status on ledger equals `"active"` (returns immediately with `reason: SUSPENDED/REVOKED` if inactive).
3. **`signatureValid`:** Issuer ML-DSA-44 signature over `CredentialHash` is verified with issuer's public key.
4. **`fieldHashesValid`:** For each attribute in `disclosedFields`, checks that `SHA3-256(field + ":" + value)` matches the entry in on-chain `FieldHashes`.
5. **`holderSignatureValid`:** Verifies holder's ML-DSA-44 signature against `SHA3-256(session.DisclosedPayload)` using holder's DSA public key from database. Requires `credentialIDMatches == true`.

If verification fails, `failureReason` explicitly reports:
- `"signature_invalid"`
- `"credential_id_mismatch"` (Audit §4.2)
- `"field_hashes_invalid"`
- `"holder_signature_invalid"`

---

## 5. Deployment & Migration Procedure

### Step 1: Database Migrations
Run the migration scripts to add holder key columns:
```bash
mysql -u root -p qchain_db < qchain-network/scripts/migrations/2026-07_trackB_offchain_encryption.sql
mysql -u root -p qchain_db < qchain-network/scripts/migrations/2026-09_trackH_holder_signing.sql
```

### Step 2: Chaincode Package Upgrade
`qchain-network/chaincode/QChaincode.js` includes `bindHolderKeys` and `fieldHashes`. Upgrade the chaincode definition on the channel (increment version/sequence).

### Step 3: Backend Deployment
Rebuild and run the backend Docker container:
```bash
cd offchain
docker build -t qchain-api:latest .
./docker-run.sh
```
Verify startup log confirms:
```
KEM algo: ML-KEM-768 (off-chain encryption: holder-held keys)
```

### Step 4: Mobile Onboarding
Upon first launch, QWallet generates key pairs on device and registers them:
```bash
curl -X POST http://localhost:3000/mobile/registerHolderKeys \
  -H 'Content-Type: application/json' \
  -d '{
    "emiratesID": "784-XXXX-XXXXXXX-X",
    "kemPublicKey": "<hex>",
    "dsaPublicKey": "<hex>"
  }'
```

---

## 6. Threat Model & Security Posture

| Threat / Attack Vector | Before B2/Track H | Current State |
|---|---|---|
| Public IPFS access by CID | Plaintext credential attributes exposed | **Ciphertext only** (sealed to holder's ML-KEM-768 key) |
| Database dump / MySQL breach | Plaintext PII (Emirates ID, GPA, Degree) exposed | **Ciphertext only**; holder private keys are never in DB |
| Backend server compromise | Attacker could steal all holder private keys | **Zero holder private keys on server** (held in device Keychains) |
| Presentation field fabrication (e.g. GPA 3.8 → 4.0) | Allowed in legacy verifier | **Caught by Check 4 (`fieldHashesValid = false`)** |
| Credential ID swapping (Audit §4.2) | Session created without binding credential ID | **Rejected fast (HTTP 400 / `credential_id_mismatch`)** |
| Unauthorized key binding (Audit §4.1) | Direct peer invocation possible | **Blocked by chaincode `checkAccess("issuer")`** |
| Harvest-now-decrypt-later quantum adversary | Vulnerable | **Protected by ML-KEM-768 and ML-DSA-44** |
| Direct Fabric peer ledger read | Plaintext on-chain | Known residual gap owned by **Track A** (see §8) |

---

## 7. Test Suites & Verification

### Unit Tests (`offchain/server_test.go` & `offchain/envelope_test.go`)

#### Running in VM:
```bash
cd offchain
go test -v ./...
```

#### Running in Docker:
```bash
cd offchain
docker build -t qchain-api:latest .
docker run --rm qchain-api:latest go test -v ./...
```

#### Test Coverage Summary:
- **`TestHandlersValidationAndHealth`:** Exercises input validation across all endpoints (`/registerHolderKeys`, `/mobile/generateOTP`, `/mobile/generatePresentation`, `/resolveSession`, etc.), ensuring malformed JSON, missing fields, and mismatched IDs fail closed.
- **`TestApplySelectiveDisclosure`:** Tests selective disclosure redaction for nil inputs, empty arrays, top-level fields, and dotted nested paths.
- **`TestFieldHashesVerificationLogic`:** Tests positive and negative cases for field hashes integrity verification.
- **`TestPresentationPayloadBindingParsing`:** Validates canonical JSON presentation parsing and credential ID extraction.
- **`TestMLDSAPresentationSigning`:** Tests end-to-end ML-DSA-44 keygen, signing, verification, and tamper rejection.
- **`TestDubaiTimezoneFormat`:** Validates local Asia/Dubai timestamp format (no trailing UTC 'Z').
- **`TestEnvelopeRoundTrip`:** Validates ML-KEM-768 + AES-256-GCM encryption, decryption, and authentication tamper detection.

### Automated End-to-End Test (`tests/e2e_api_test.sh`)
```bash
./tests/e2e_api_test.sh
```
Executes full real-world flow against running Fabric network, MySQL, and IPFS:
1. Registers holder keys (`POST /mobile/registerHolderKeys`).
2. Issues credential with `fieldHashes` (`POST /issueCredential`).
3. Fetches encrypted envelope ciphertext (`GET /mobile/getEnvelope`).
4. Generates presentation session with ML-DSA signature (`POST /mobile/generatePresentation`).
5. Resolves session with 5 checks (`POST /resolveSession`).
6. Runs tamper tests (fabricating GPA, corrupting signature, presenting mismatched credential ID).
7. Tests OTP presentation flow (`POST /mobile/generateOTP` -> `POST /resolveSession`).
8. Tests lifecycle transitions (`suspendCredential` -> `restoreCredential` -> `revokeCredential`).

---

## 8. Remaining Roadmap (Next Steps)

1. **Track A (On-Chain Confidentiality):** Address on-chain plaintext `Info` field using Hyperledger Fabric Private Data Collections (PDC) or on-chain attribute encryption.
2. **Gap G7 / User Authentication:** Add UAE Pass / session authentication to gate `POST /mobile/registerHolderKeys` and `GET /mobile/getEnvelope`.
3. **Key Backup & Recovery (Gap G12):** Device key recovery mechanism for holders before full production rollout.
