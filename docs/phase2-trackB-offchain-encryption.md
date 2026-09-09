# QChain — Phase 2 · Track B2: Off-Chain Credential-Data Encryption (Holder-Held Keys)

**Status:** Implemented (holder-held-key phase / B2). Backend-only. No chaincode change, no ledger change, no network restart.
**Audience:** QChain contributors — past and future. Read this before touching credential storage or the crypto files.
**Date:** 2026-09 (upgraded from B3 org-held-key phase, 2026-07)
**Related:** `QChain_Phase2_Security_Plan.md` (gap analysis), `QChain_Phase2_TrackB_Implementation_Plan.md` (full design incl. Merkle-root selective disclosure and presentation re-wrap phases).

---

## 1. TL;DR

The credential *body* (the attribute JSON) used to be stored **in plaintext in three places**: on-chain in the `Info` field, in IPFS, and in the MySQL `credential_data` column. This change encrypts the **two off-chain copies** (IPFS + MySQL) using a post-quantum hybrid envelope (ML-KEM-768 + AES-256-GCM), **wrapping to the holder's ML-KEM public key** so only the holder can decrypt.

The **on-chain copy is deliberately left untouched** — we are not authorised to modify the chaincode, and the blockchain must not be restarted. On-chain confidentiality remains a known, documented gap owned by **Track A**. See §7 for exactly what is and isn't protected.

**Key change from B3 (org-held-key phase):** Encryption recipients changed from `"org"` → `"holder:<holderID>"`. Each credential is encrypted to its specific holder's public key. The org key is no longer used for new issuances (kept only as a legacy fallback for reading old B3 envelopes, if any exist).

---

## 2. Why this shape (the important context)

While implementing, we verified against the actual code (not the README) and found that the Phase 2 plan's framing — *"only metadata is stored on-chain, so just encrypt IPFS"* — **does not match reality**:

- `handleIssueCredential` (`offchain/credentials.go`) builds the full canonical JSON, **including every credential attribute**, and the chaincode writes that whole string to world-state in the `Info` field (`QChaincode.js`, `Info: credentialJSON`). So the complete plaintext credential lives on **every peer's ledger**.
- **Verification never reads IPFS.** Both `handleVerifyCredential` and `handleResolveSession` fetch the credential from the **chain** (`getCredential`) and recompute the hash over the on-chain `Info`. The IPFS CID is written at issuance and never read back.

**Consequence for this work:** encrypting the off-chain stores does **not** by itself make verification confidential, because verification uses the on-chain plaintext. What it *does* achieve is removing plaintext from the two off-chain stores (IPFS, which is content-addressed and reachable by CID; and the MySQL DB, which holds PII) — a real at-rest / "harvest-now-decrypt-later" improvement for those stores, and it closes the DB-plaintext gap (G3) at the same time. Full confidentiality additionally requires the on-chain plaintext to be addressed, which is **Track A** (see §8).

This limitation is intentional and bounded by the "don't touch on-chain / don't restart the chain" constraint. **Do not remove the on-chain plaintext without doing Track A** — verification depends on it today.

---

## 3. What was changed (file by file)

### New files (B2)

| File | Purpose |
|---|---|
| `offchain/holder_keys.go` | Holder KEM key management: `loadHolderKeysFile()` loads `.env.holder_keys` at startup; `handleRegisterHolderKey` (`POST /mobile/registerHolderKey`) registers a holder's key pair; `runGenerateHolderKeys()` one-shot backfill for existing holders. |
| `qchain-network/scripts/migrations/2026-09_trackB2_holder_keys.sql` | Migration marker documenting the B2 transition (no schema changes needed — `holders.kem_public_key` was already added in the B1 migration). |

### Files from B1 (unchanged by B2)

| File | Purpose |
|---|---|
| `offchain/kem.go` | Low-level primitives: ML-KEM-768 encap/decap (via liboqs), HKDF-SHA3-256 key derivation, AES-256-GCM seal/open, single-use key wrapping. Recipient-agnostic. |
| `offchain/cmd/kemkeygen/main.go` | Generates the org ML-KEM-768 key pair for `.env` (legacy). |
| `qchain-network/scripts/migrations/2026-07_trackB_offchain_encryption.sql` | Additive columns: `credentials.enc_version`, `holders.kem_public_key`, `verifiers.kem_public_key`. MySQL-only. |

### Edited files (B2)

| File | Change |
|---|---|
| `offchain/config.go` | `orgKemPubHex` / `orgKemPrivHex` are now documented as **legacy fallback**. Added `holderKemKeys map[string]string` — in-memory map of holderID → private key hex, loaded from `.env.holder_keys`. Testing only — production keys live on the holder's device. |
| `offchain/server.go` | `main()` loads holder keys from `.env.holder_keys`, adds `GENERATE_HOLDER_KEYS=1` one-shot mode, registers `POST /mobile/registerHolderKey`, and updates the startup log to show B2 status. Org KEM key warning downgraded to INFO. |
| `offchain/envelope.go` | **Core B2 change:** `encryptCredentialData(credID, attrs, holderID, holderKemPubHex)` wraps to `"holder:<holderID>"` instead of `"org"`. `decryptCredentialData(stored, holderID, holderKemPrivHex)` decrypts with holder key (falls back to org key for legacy envelopes). |
| `offchain/credentials.go` | `handleIssueCredential` now looks up the holder's KEM public key and **requires it** — issuance fails with a clear error if the holder has no key. Passes holderID + holderKemPub to `encryptCredentialData`. |
| `offchain/mobile.go` | `handleMobileGetCredentialsByHolder` looks up the holder's KEM private key and passes it to `decryptCredentialData` for server-side decryption. |
| `offchain/backfill.go` | `runBackfillEncrypt()` now encrypts each credential to its **holder's** KEM public key (looked up from DB), not to a single org key. Skips credentials whose holder has no key. |
| `offchain/db_holders.go` | Added `holderKemPubByID`, `holderKemPubByEmiratesID`, `updateHolderKemPub` functions. |
| `offchain/envelope_test.go` | Tests updated for holder-key model: round-trip, tamper detection, holder key required, recipient verification. |

**Nothing else was touched.** No file under `qchain-network/chaincode/` was modified. No `configtx`, `core.yaml`, docker, or channel artifact was modified.

---

## 4. How it works (crypto)

Standard hybrid KEM-DEM (the pattern used by TLS 1.3, HPKE, `age`), specialised to per-field keys so future selective disclosure is possible:

1. **One ML-KEM-768 encapsulation** to the **holder's** public key → a 32-byte shared secret `ss` (+ a KEM ciphertext stored in the envelope). Recipient = `"holder:<holderID>"`.
2. For **each attribute field**: a random 32-byte data key `K_i` encrypts the field value with **AES-256-GCM** (random nonce).
3. `K_i` is wrapped under `KWK_i = HKDF-SHA3-256(ss, "qchain/trackB/v1|"+credId+"|"+key_i)`. Because the HKDF context includes the field name, **every wrapping key is single-use**, so wrapping with a fixed nonce is safe.
4. The envelope `{ _qc_env, v, kemAlg, aeadAlg, kdf, credId, wraps[], fields[] }` is stored as JSON in IPFS and in `credential_data`.

Decryption reverses this: decapsulate `ss` from the KEM ciphertext with the holder's secret key, re-derive each `KWK_i`, unwrap `K_i`, AES-open the field. All algorithms are quantum-safe (AES-256 and SHA3 are Grover-only; ML-KEM is the NIST PQC KEM standard).

**Envelope detection / backward compatibility:** stored values carry a `"_qc_env": "qchain-env"` marker. `decryptCredentialData` returns non-envelope values untouched, so pre-Track-B plaintext rows and post-Track-B encrypted rows coexist. `enc_version` (0/1) records which is which.

---

## 5. Deploying this change

Order matters, but every step is safe on a live system and none touches the blockchain.

1. **Run the DB migration** (adds columns; no data change — skip if already done for B1):
   ```
   mysql -u root -p qchain_db < qchain-network/scripts/migrations/2026-07_trackB_offchain_encryption.sql
   ```

2. **Generate holder KEM keys** for all existing holders (one-shot, writes public keys to DB and private keys to `.env.holder_keys`):
   ```
   GENERATE_HOLDER_KEYS=1 MYSQL_DSN=<dsn> <your normal backend start command>
   ```
   This generates an ML-KEM-768 key pair for every holder without one. Public keys go to `holders.kem_public_key` in MySQL; private keys go to `offchain/.env.holder_keys`. The server then exits.
   
   **Keep `.env.holder_keys` out of git** (already gitignored). Private keys are for **testing only** — in production they live on the holder's device.

3. **(Optional) Set org KEM keys for legacy B3 support.** If you have credentials encrypted under the old B3 org key, add `ORG_KEM_PUBLIC_KEY_HEX` and `ORG_KEM_PRIVATE_KEY_HEX` to `.env`. If B3 was never deployed, skip this.

4. **Restart the Go backend.** From now on, new issuances encrypt to the holder's key. Verify the startup log shows:
   ```
   KEM algo: ML-KEM-768 (off-chain encryption: holder-key B2, holder-keys-loaded: N)
   Loaded N holder KEM private key(s) from .env.holder_keys
   ```

5. **(Optional) Encrypt existing plaintext rows** — one-shot, idempotent, re-runnable:
   ```
   RUN_BACKFILL_ENCRYPT=1 <your normal backend start command>
   ```
   This encrypts `credential_data` for all `enc_version = 0` rows using each credential's holder key, then exits. Credentials whose holder has no key are skipped. It does **not** re-upload to IPFS (see §6).

6. **(Optional) Register individual holder keys** via the API:
   ```bash
   curl -X POST http://localhost:3000/mobile/registerHolderKey \
     -H 'Content-Type: application/json' \
     -d '{"emiratesID":"784-XXXX-XXXXXXX-X"}'
   ```
   If `kemPublicKeyHex`/`kemPrivateKeyHex` are omitted, the server generates a fresh pair. The response includes both keys — store the private key securely.

---

## 6. Known limitations & deliberate scope cuts

- **On-chain plaintext remains.** By design (no chaincode change / no restart). Verification still reads it. This is the biggest residual exposure and is **Track A's** responsibility. Do not advertise the system as fully confidential yet.
- **IPFS backfill of legacy blobs is not automated.** New issuances put ciphertext on IPFS. Existing IPFS blobs (uploaded before this change) remain plaintext. Since nothing reads IPFS, this is low-risk, but to clean it up you can re-upload the encrypted body and update the CID via the existing `/setCID` admin endpoint.
- **Server-side decryption (testing only).** The server loads holder private keys from `.env.holder_keys` to decrypt on behalf of holders during testing. In production, the holder's device (QWallet) will decrypt locally once Flutter liboqs bindings are available. The `.env.holder_keys` file is gitignored and should **never** be committed.
- **Selective disclosure is still server-side redaction** (`applySelectiveDisclosure` in `mobile.go`, unchanged). The envelope is *structured* per-field so real cryptographic selective disclosure can be built later (Track B3 + Merkle root).
- **Holder key is REQUIRED for issuance.** If a holder has no `kem_public_key` registered, issuance fails with a clear error. Run `GENERATE_HOLDER_KEYS=1` to bootstrap keys.

---

## 7. Threat model — what is and isn't protected now

| Adversary / exposure | Before | After this change |
|---|---|---|
| Reads the IPFS blob by CID (content is public/addressable) | sees full plaintext | sees ciphertext only |
| Steals / reads the MySQL DB (PII: Emirates ID, email, attributes) | sees full plaintext | sees ciphertext only (holder keys not in DB) |
| Has read access to the Fabric ledger / a peer | sees full plaintext on-chain | **still sees full plaintext on-chain** (Track A) |
| Compromises the backend host (gets `.env.holder_keys`) | — | can decrypt all holders' credentials — but **only during the testing phase** when private keys are server-side. In production, holder keys live on devices. |
| Future quantum adversary harvesting off-chain data now | plaintext, trivially exposed | protected by ML-KEM-768 + AES-256 |

Net: closes the off-chain at-rest exposure (IPFS + DB / PII, gaps G1 & G3); does **not** close the on-chain exposure (G2 — Track A).

---

## 8. What's left to do (roadmap for the next contributor)

In rough priority order. The design doc (`QChain_Phase2_TrackB_Implementation_Plan.md`) has the detail.

1. **Client-side decryption in QWallet.** Build Flutter liboqs bindings so the QWallet app can generate ML-KEM keys on-device and decrypt credentials locally, removing the need for `.env.holder_keys` entirely. This is the true end-state of B2.
2. **Verifier keys + presentation re-wrap (B3).** Let the holder re-wrap disclosed fields to a verifier at presentation, so the server never sees plaintext. Reworks `/resolveSession`. See design doc §7.3 (protocol P-A).
3. **Real cryptographic selective disclosure.** Salted-Merkle commitments signed by the org key so a disclosed *subset* stays verifiable; replaces server-side redaction. Requires changing what the signature covers — coordinate with Track A since it borders on-chain data. Design doc §6.
4. **IPFS as a real verification source.** Add `downloadFromIPFS` + verify-from-IPFS so the encrypted off-chain body becomes load-bearing (prerequisite for eventually shrinking the on-chain copy under Track A).
5. **Track A** — on-chain metadata/body confidentiality (Private Data Collections or on-chain encryption) + PQC MSP. Removes the residual on-chain plaintext.
6. **Key custody (G12).** Holder key backup/recovery before B2 ships to production (losing a holder key = losing that holder's data).

---

## 9. Testing

```
cd offchain && go test -run TestEnvelope -v
```

Tests use real ML-KEM-768 via liboqs, so run them in the Docker build environment (the image already installs liboqs). They need neither MySQL, IPFS, nor Fabric.

**Test cases:**
- `TestEnvelopeRoundTrip` — encrypt with holder key, decrypt with holder key, verify JSON equivalence.
- `TestLegacyPlaintextPassthrough` — non-envelope values pass through `decryptCredentialData` untouched.
- `TestEncryptionRequiresHolderKey` — encrypting with empty holder key returns error (no silent plaintext fallback).
- `TestTamperedFieldFailsAuth` — flipping ciphertext bytes triggers AES-GCM authentication failure.
- `TestEnvelopeRecipientIsHolder` — verifies envelope wraps use `"holder:<holderID>"` not `"org"`.

**Manual smoke test after deploy:**
```sql
SELECT enc_version, LEFT(credential_data, 60) FROM credentials ORDER BY issued_at DESC LIMIT 1;
```
Should show `enc_version = 1` and a value starting `{"_qc_env":"qchain-env"...` with `"holder:H-..."` in the wraps. Open the QWallet for that holder — attributes should display normally (server decrypts on read via `.env.holder_keys`). Verify the credential in QPortal — verification is unchanged (reads on-chain) and should still pass all four checks.

---

## 10. Quick reference — key entry points

- **Holder key registration:** `POST /mobile/registerHolderKey` or `GENERATE_HOLDER_KEYS=1` one-shot mode.
- **Holder key storage:** Public key in DB (`holders.kem_public_key`). Private key in `offchain/.env.holder_keys` (testing only, gitignored).
- **Encrypt on write:** `encryptCredentialData(credentialHash, req.Info, holderID, holderKemPub)` in `credentials.go`.
- **Decrypt on read:** `decryptCredentialData(stored, holderID, holderKemPriv)` in `mobile.go` (add the same call anywhere else `credential_data` is ever read in future).
- **Envelope format & crypto:** `envelope.go`, `kem.go`.
- **Backfill encryption:** `RUN_BACKFILL_ENCRYPT=1`.
- **Legacy org key (B3):** Optional. Set `ORG_KEM_PUBLIC_KEY_HEX` / `ORG_KEM_PRIVATE_KEY_HEX` only if B3 envelopes exist.
- **The on-chain path (do not change without Track A):** `SubmitTransaction("issueCredential", …)` in `credentials.go`, and the verification reads in `verification.go` / `mobile.go`.
