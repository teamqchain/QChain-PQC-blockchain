# QChain — Phase 2 · Track B: Off-Chain Credential-Data Encryption

**Status:** Implemented (org-held-key phase). Backend-only. No chaincode change, no ledger change, no network restart.
**Audience:** QChain contributors — past and future. Read this before touching credential storage or the crypto files.
**Date:** 2026-07
**Related:** `QChain_Phase2_Security_Plan.md` (gap analysis), `QChain_Phase2_TrackB_Implementation_Plan.md` (full design incl. the future holder-held-key phase).

---

## 1. TL;DR

The credential *body* (the attribute JSON) used to be stored **in plaintext in three places**: on-chain in the `Info` field, in IPFS, and in the MySQL `credential_data` column. This change encrypts the **two off-chain copies** (IPFS + MySQL) using a post-quantum hybrid envelope (ML-KEM-768 + AES-256-GCM). 

The **on-chain copy is deliberately left untouched** — we are not authorised to modify the chaincode, and the blockchain must not be restarted. On-chain confidentiality remains a known, documented gap owned by **Track A**. See §7 for exactly what is and isn't protected.

Everything is **backward compatible and safe-by-default**: with no key configured, the server behaves exactly as before. Old plaintext rows keep working alongside new encrypted ones.

---

## 2. Why this shape (the important context)

While implementing, we verified against the actual code (not the README) and found that the Phase 2 plan's framing — *"only metadata is stored on-chain, so just encrypt IPFS"* — **does not match reality**:

- `handleIssueCredential` (`offchain/credentials.go`) builds the full canonical JSON, **including every credential attribute**, and the chaincode writes that whole string to world-state in the `Info` field (`QChaincode.js`, `Info: credentialJSON`). So the complete plaintext credential lives on **every peer's ledger**.
- **Verification never reads IPFS.** Both `handleVerifyCredential` and `handleResolveSession` fetch the credential from the **chain** (`getCredential`) and recompute the hash over the on-chain `Info`. The IPFS CID is written at issuance and never read back.

**Consequence for this work:** encrypting the off-chain stores does **not** by itself make verification confidential, because verification uses the on-chain plaintext. What it *does* achieve is removing plaintext from the two off-chain stores (IPFS, which is content-addressed and reachable by CID; and the MySQL DB, which holds PII) — a real at-rest / "harvest-now-decrypt-later" improvement for those stores, and it closes the DB-plaintext gap (G3) at the same time. Full confidentiality additionally requires the on-chain plaintext to be addressed, which is **Track A** (see §8).

This limitation is intentional and bounded by the "don't touch on-chain / don't restart the chain" constraint. **Do not remove the on-chain plaintext without doing Track A** — verification depends on it today.

---

## 3. What was changed (file by file)

### New files

| File | Purpose |
|---|---|
| `offchain/kem.go` | Low-level primitives: ML-KEM-768 encap/decap (via liboqs), HKDF-SHA3-256 key derivation, AES-256-GCM seal/open, single-use key wrapping. |
| `offchain/envelope.go` | The per-field envelope format + `sealAttributes`/`openAttributes`, and the high-level `encryptCredentialData` / `decryptCredentialData` helpers (with legacy passthrough). |
| `offchain/backfill.go` | One-shot `runBackfillEncrypt()` that encrypts existing plaintext rows in place. Triggered by `RUN_BACKFILL_ENCRYPT=1`. |
| `offchain/envelope_test.go` | Round-trip, tamper-detection, legacy-passthrough and disabled-mode tests. Needs liboqs to run. |
| `offchain/cmd/kemkeygen/main.go` | Generates the org ML-KEM-768 key pair for `.env` (mirrors the existing `cmd/keygen`). |
| `qchain-network/scripts/migrations/2026-07_trackB_offchain_encryption.sql` | Additive columns: `credentials.enc_version`, `holders.kem_public_key`, `verifiers.kem_public_key`. MySQL-only. |

### Edited files

| File | Change |
|---|---|
| `offchain/config.go` | Declares `orgKemPubHex` / `orgKemPrivHex` package globals. |
| `offchain/server.go` | `main()` resolves the KEM mechanism name, loads the org KEM key from env (optional; warns if unset), and runs the backfill mode when `RUN_BACKFILL_ENCRYPT=1`. Adds a startup log line. |
| `offchain/credentials.go` | In `handleIssueCredential`: builds `encBody = encryptCredentialData(hash, req.Info)` and uses it for **both** the IPFS upload and the DB insert. **The on-chain `SubmitTransaction("issueCredential", canonicalJSONStr, hash, signature, …)` call is unchanged** — same plaintext, same hash, same signature. |
| `offchain/db_credentials.go` | `CredentialInsert` gains `EncVersion`; `insertCredential` writes the new `enc_version` column. |
| `offchain/mobile.go` | `handleMobileGetCredentialsByHolder` now calls `decryptCredentialData(...)` before displaying attributes (transparent for legacy rows). |

**Nothing else was touched.** No file under `qchain-network/chaincode/` was modified. No `configtx`, `core.yaml`, docker, or channel artifact was modified.

---

## 4. How it works (crypto)

Standard hybrid KEM-DEM (the pattern used by TLS 1.3, HPKE, `age`), specialised to per-field keys so future selective disclosure is possible:

1. **One ML-KEM-768 encapsulation** to the recipient's public key → a 32-byte shared secret `ss` (+ a KEM ciphertext stored in the envelope). Recipient today = the org (`"org"`).
2. For **each attribute field**: a random 32-byte data key `K_i` encrypts the field value with **AES-256-GCM** (random nonce).
3. `K_i` is wrapped under `KWK_i = HKDF-SHA3-256(ss, "qchain/trackB/v1|"+credId+"|"+key_i)`. Because the HKDF context includes the field name, **every wrapping key is single-use**, so wrapping with a fixed nonce is safe.
4. The envelope `{ _qc_env, v, kemAlg, aeadAlg, kdf, credId, wraps[], fields[] }` is stored as JSON in IPFS and in `credential_data`.

Decryption reverses this: decapsulate `ss` from the KEM ciphertext with the org secret key, re-derive each `KWK_i`, unwrap `K_i`, AES-open the field. All algorithms are quantum-safe (AES-256 and SHA3 are Grover-only; ML-KEM is the NIST PQC KEM standard).

**Envelope detection / backward compatibility:** stored values carry a `"_qc_env": "qchain-env"` marker. `decryptCredentialData` returns non-envelope values untouched, so pre-Track-B plaintext rows and post-Track-B encrypted rows coexist. `enc_version` (0/1) records which is which.

---

## 5. Deploying this change

Order matters, but every step is safe on a live system and none touches the blockchain.

1. **Run the DB migration** (adds columns; no data change):
   ```
   mysql -u root -p qchain_db < qchain-network/scripts/migrations/2026-07_trackB_offchain_encryption.sql
   ```
2. **Generate the org KEM key** and add the two lines it prints to `offchain/.env`:
   ```
   go run offchain/cmd/kemkeygen/main.go
   # → ORG_KEM_PUBLIC_KEY_HEX=... / ORG_KEM_PRIVATE_KEY_HEX=...
   ```
   Keep `.env` out of git (it already is). This private key can decrypt every off-chain body — treat it like the signing key.
3. **Restart the Go backend.** From now on, new issuances encrypt the off-chain body automatically. Verify the startup log shows `off-chain encryption: true`.
4. **(Optional) Encrypt existing rows** — one-shot, idempotent, re-runnable:
   ```
   RUN_BACKFILL_ENCRYPT=1 <your normal backend start command>
   ```
   This encrypts `credential_data` for all `enc_version = 0` rows and exits. It does **not** re-upload to IPFS (see §6).

**If you skip step 2**, the server logs a warning and stores plaintext exactly as before — nothing breaks. This is the safe default.

---

## 6. Known limitations & deliberate scope cuts

- **On-chain plaintext remains.** By design (no chaincode change / no restart). Verification still reads it. This is the biggest residual exposure and is **Track A's** responsibility. Do not advertise the system as fully confidential yet.
- **IPFS backfill of legacy blobs is not automated.** New issuances put ciphertext on IPFS. Existing IPFS blobs (uploaded before this change) remain plaintext; the on-chain CID points at them. Since nothing reads IPFS, this is low-risk, but to clean it up you can re-upload the encrypted body and update the CID via the existing `/setCID` admin endpoint + chaincode function (which already exists — no new chaincode needed).
- **Decryption is server-side (org key), not holder-side.** This is the *org-held-key* phase, not the full *holder-held-key* (B2) target from the design doc. The server can still read every credential. That matches today's fully server-side verification trust model, and it's what's deployable without frontend/mobile changes. The DB columns `holders.kem_public_key` / `verifiers.kem_public_key` are already in place for the next phase.
- **Selective disclosure is still server-side redaction** (`applySelectiveDisclosure` in `mobile.go`, unchanged). The envelope is *structured* per-field so real cryptographic selective disclosure can be built later, but it isn't wired yet.

---

## 7. Threat model — what is and isn't protected now

| Adversary / exposure | Before | After this change |
|---|---|---|
| Reads the IPFS blob by CID (content is public/addressable) | sees full plaintext | sees ciphertext only |
| Steals / reads the MySQL DB (PII: Emirates ID, email, attributes) | sees full plaintext | sees ciphertext only (org key not in DB) |
| Has read access to the Fabric ledger / a peer | sees full plaintext on-chain | **still sees full plaintext on-chain** (Track A) |
| Compromises the backend host (gets `.env`) | — | can decrypt everything (holds org KEM + signing keys) — unchanged trust assumption |
| Future quantum adversary harvesting off-chain data now | plaintext, trivially exposed | protected by ML-KEM-768 + AES-256 |

Net: closes the off-chain at-rest exposure (IPFS + DB / PII, gaps G1 & G3); does **not** close the on-chain exposure (G2 — Track A).

---

## 8. What's left to do (roadmap for the next contributor)

In rough priority order. The design doc (`QChain_Phase2_TrackB_Implementation_Plan.md`) has the detail.

1. **Holder-held keys (true B2).** Generate an ML-KEM key pair in the QWallet (Flutter), register the public key (columns already exist), and add a second recipient wrap at issuance so the holder can decrypt without the server. Biggest client-side effort (mobile liboqs binding) — spike it first.
2. **Verifier keys + presentation re-wrap.** Let the holder re-wrap disclosed fields to a verifier at presentation, so the server never sees plaintext. Reworks `/resolveSession`. See design doc §7.3 (protocol P-A).
3. **Real cryptographic selective disclosure.** Salted-Merkle commitments signed by the org key so a disclosed *subset* stays verifiable; replaces server-side redaction. Requires changing what the signature covers — coordinate with Track A since it borders on-chain data. Design doc §6.
4. **IPFS as a real verification source.** Add `downloadFromIPFS` + verify-from-IPFS so the encrypted off-chain body becomes load-bearing (prerequisite for eventually shrinking the on-chain copy under Track A).
5. **Track A** — on-chain metadata/body confidentiality (Private Data Collections or on-chain encryption) + PQC MSP. Removes the residual on-chain plaintext.
6. **Key custody (G12).** The org KEM key currently sits in `.env`. Move to a KMS/HSM; define holder-key backup/recovery before B2 ships (losing a holder key = losing that holder's data).

---

## 9. Testing

```
cd offchain && go test -run TestEnvelope -v      # round-trip, tamper, legacy, disabled
```
Tests use real ML-KEM-768 via liboqs, so run them in the Docker build environment (the image already installs liboqs). They need neither MySQL, IPFS, nor Fabric.

Manual smoke test after deploy: issue a credential, then inspect the DB — `SELECT enc_version, LEFT(credential_data, 40) FROM credentials ORDER BY issued_at DESC LIMIT 1;` should show `enc_version = 1` and a value starting `{"_qc_env":"qchain-env"...`. Open the QWallet for that holder — attributes should display normally (server decrypts on read). Verify the credential in QPortal — verification is unchanged (reads on-chain) and should still pass all four checks.

---

## 10. Quick reference — key entry points

- Enable/disable: presence of `ORG_KEM_PUBLIC_KEY_HEX` in `.env`.
- Encrypt on write: `encryptCredentialData(credentialHash, req.Info)` in `credentials.go`.
- Decrypt on read: `decryptCredentialData(stored)` in `mobile.go` (add the same call anywhere else `credential_data` is ever read in future).
- Envelope format & crypto: `envelope.go`, `kem.go`.
- Backfill: `RUN_BACKFILL_ENCRYPT=1`.
- The on-chain path (do not change without Track A): `SubmitTransaction("issueCredential", …)` in `credentials.go`, and the verification reads in `verification.go` / `mobile.go`.
