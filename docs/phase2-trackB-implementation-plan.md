# QChain — Phase 2 · Track B Implementation Plan

## Post-Quantum Confidentiality of Off-Chain Credential Data

**Project:** QChain — Post-Quantum Credential System on Hyperledger Fabric
**Institution:** University of Sharjah — Graduation / Capstone Project
**Document type:** Implementation plan (design-complete, code-ready for the next working session)
**Scope:** Track B only — confidentiality of the credential *body*. Track A (PQC MSP/identity) and on-chain *metadata* confidentiality are explicitly out of scope here.
**Status:** Draft v1.0 — grounded in the actual repository at `QChain-PQC-blockchain/`, not the planning PDF's descriptions.

---

## 0. How to read this document

This plan is deliberately critical of the Phase 2 planning PDF (`QChain_Phase2_Security_Plan.md`). Section 1 corrects a factual premise that changes the whole track. Sections 2–3 lock the design decisions. Sections 4–9 are the design proper (data flows, envelope format, integrity scheme, key management, crypto primitives). Section 10 is the file-by-file change list with function signatures. Sections 11–14 cover chaincode, DB, migration, and testing. Section 15 is the phased rollout that keeps the live demo alive. Section 16 lists the residual risks and the two decisions still open. Section 17 is the "start here next session" checklist.

Per your instruction the code here is **signatures, structs, JSON schemas and pseudocode**, not full implementations — enough that the next session is mechanical.

---

## 1. Critical correction — the premise that reshapes Track B

Your framing was: *"Onchain encryption can be done when doing Track A, since only the metadata is stored onchain."* **The code does not match this.** I read the issuance path, the chaincode, and both verification paths. Here is the ground truth:

**1.1 The full credential — including every attribute — is stored on-chain in plaintext.**
`handleIssueCredential` (`offchain/credentials.go:143`) builds the canonical JSON via `credentialCanonicalJSON` (`offchain/crypto.go:84`). That payload contains an inner `info` field which is `req.Info` — *"JSON-encoded credential attributes string"* — i.e. the entire sensitive body (degree, GPA, dates, personal fields). That whole canonical JSON string is then handed to the chaincode and written to world-state verbatim:

```js
// qchain-network/chaincode/QChaincode.js:50
Info: credentialJSON,   // canonical JSON string (signed payload) — FULL credential, plaintext
```

Every peer in the channel therefore holds the complete plaintext credential in its LevelDB/CouchDB world-state and in block history. This is gap **G2** in the PDF, but the PDF's own Track B section (§8) only talks about IPFS and the executive-summary table labels Track B *"Encrypt credential data on IPFS."* That labelling is misleading given the code.

**1.2 IPFS is write-only. It is never read during verification.**
`uploadJSONToIPFS` (`offchain/crypto.go:99`) stores the JSON and returns a CID, which is persisted on-chain and in MySQL. But neither `handleVerifyCredential` (`offchain/verification.go`) nor `handleResolveSession` (`offchain/mobile.go`) ever fetches from IPFS. They call `getCredential` on the chaincode and read the plaintext `Info` field back:

```go
// offchain/verification.go:53,65,140
chainResult, _ := contract.EvaluateTransaction("getCredential", fabricCredID)
credInfoStr, _ := cred["Info"].(string)          // plaintext, straight from the ledger
recomputed := sha3Hex(credInfoStr)               // hash recomputed over on-chain plaintext
```

**Consequence:** encrypting *only* the IPFS blob (the PDF's literal Track B) would improve confidentiality by essentially **zero**. The authoritative copy that attackers and verifiers actually touch is the on-chain plaintext. The MySQL `credential_data JSON` column (`schema.sql:127`, written from `req.Info` at `credentials.go:226`) is a *third* plaintext copy.

**1.3 What this means.** "Track B = encrypt IPFS" is not a real confidentiality fix. To achieve confidentiality we must change **where the authoritative plaintext lives** and **what verification consumes**. That is exactly the decision you approved: *encrypt the body and move it off-chain*, leaving only an integrity anchor + minimal metadata on-chain. This is a larger change than the PDF's "moderate, self-contained, no Fabric fork" characterization — it touches the chaincode record shape and the verification path. It is still very achievable, but the PDF undersells it. This document plans the *real* fix.

**1.4 Second critical caveat — B2 breaks the current trust/flow model.** You chose the holder-held key (B2). Today verification is **100% server-side**: the Go backend holds the signing key, does `pqcVerify`, and for presentations the holder mints an OTP/QR session row and the *server* reads the credential and redacts fields — the holder's device is not involved at redemption time, and neither the holder nor the verifier owns any key. B2 means **only the holder can decrypt**, so the server can no longer read the credential to verify/redact it. This forces a genuine protocol redesign of issuance *and* presentation, plus new key custody in the QWallet and verifier apps. Section 7 handles this directly; Section 15 phases it so the demo never breaks. I want this cost visible up front: **B2 is the correct privacy target, but it is the most invasive of the three options — not a drop-in.**

---

## 2. Locked decisions (from review)

| # | Decision | Choice | Section |
|---|----------|--------|---------|
| D1 | Where the authoritative body lives | **Encrypted body off-chain (IPFS); on-chain keeps integrity anchor + minimal metadata only** | §4, §11 |
| D2 | Who holds the ML-KEM decryption key | **Holder-held (B2)** — issuer wraps to holder's ML-KEM public key; holder re-wraps to verifier at presentation | §7 |
| D3 | Selective disclosure | **Per-field envelope + honest scope** — each attribute encrypted under its own key; hiding a field = withholding its key; integrity of a disclosed subset via salted-Merkle signature | §6 |
| D4 | Document depth | **Detailed spec, minimal code** — signatures/structs/schemas/pseudocode | whole doc |

Fixed primitives (unchanged from Phase 1 where possible): **AES-256-GCM** for bulk/field encryption; **ML-KEM-768** (FIPS 203, Kyber) for key encapsulation; **ML-DSA-44** (FIPS 204, Dilithium) for signatures — already in the codebase (`crypto.go:28`); **SHA3-256** for hashing/Merkle leaves — already in use. One `liboqs` library, already a dependency (`go.mod:38`).

---

## 3. Design goals & non-goals

**Goals.** (a) No plaintext credential body on the ledger, on IPFS, or in MySQL. (b) Only the holder can decrypt at rest; a verifier can decrypt only the fields the holder discloses, only after the holder authorizes that verifier. (c) Integrity + authenticity survive selective disclosure — a verifier can cryptographically verify the *subset* it receives against the issuer's ML-DSA signature. (d) The four existing verification checks (existsOnChain, notRevoked, signatureValid, hashMatches) remain meaningful. (e) The live Phase 1 demo keeps working at every phase boundary (§15).

**Non-goals (Track B).** On-chain *metadata* confidentiality (holderID/type/issuedAt stay plaintext on-chain — that is Track A / Private Data Collections). API authentication (G7) — assumed as a parallel Phase 2.0 workstream; §7 notes where it plugs in. Availability/redundancy (G10). HSM key custody (G12) — noted, not built.

---

## 4. Target architecture

### 4.1 Storage layout — before vs after

```
                         BEFORE (Phase 1)                     AFTER (Track B)
 On-chain (world-state)  ID, Holder, Issuer, Status,          ID, Holder, Issuer, Status,
                         Info = FULL plaintext canonical      CredentialHash = Merkle root,
                         JSON (all attributes),               Signature (ML-DSA over root),
                         CredentialHash, Signature,           PublicKey, CID, IssuedAt,
                         PublicKey, CID, IssuedAt             MetaInfo = {holderID, type,
                                                              issuedAt, issuerOrgID} (metadata
                                                              only), EncMeta = {v, kemAlg,
                                                              aeadAlg, kdf}.  NO attribute plaintext.

 IPFS                    Plaintext canonical JSON             Encrypted envelope (per-field
                         (written, never read)                ciphertext + wrapped keys +
                                                              salts).  READ at verification.

 MySQL credential_data   Plaintext attributes JSON            The same encrypted envelope
                                                              (ciphertext) — doubles as an
                                                              availability cache; fixes G3 too.
```

Two effects worth naming: (1) verification now depends on IPFS availability (previously it did not) — see §16 risk R1, mitigated by also caching the envelope in MySQL and pinning; (2) storing the envelope in `credential_data` means the DB confidentiality gap (G3, "Track C") is closed *for free* by the same envelope — Track C's C1 "reuse Track B's envelope" becomes literally the same bytes.

### 4.2 Issuance flow (target)

```
1. Look up holder (unchanged).  REQUIRE holder ML-KEM public key is registered (§7.2); else reject/queue.
2. Flatten the credential into fields: metadata fields {credentialType, holderID, issuedAt, issuerOrgID}
   + attribute fields (the parsed req.Info map).
3. For each field i: salt_i = 16 random bytes; leaf_i = SHA3-256(salt_i || canonicalKV(key_i, value_i)).
4. Build Merkle tree over the sorted leaves -> merkleRoot.
5. signature = ML-DSA-44.Sign(merkleRoot) with issuer org private key (issuerPrivKeyHex — unchanged key).
6. Encrypt (envelope, §5): one ML-KEM encapsulation to the holder's public key -> ss -> KDF -> KWK.
   For each *attribute* field i: K_i = random 32B; ct_i = AES-256-GCM(K_i, value_i); wrap_i = AESKW(KWK, K_i).
   Metadata fields are NOT encrypted (they live plaintext on-chain in MetaInfo); their salts go on-chain too.
7. envelope = {v, kemAlg, aeadAlg, kdf, kemCtToHolder, fields:[{key, salt, nonce, ct, tag, wrap}], ...}.
8. cid = IPFS.add(envelope).  Also store envelope JSON in MySQL credential_data.
9. Chaincode issueCredential(holderID, MetaInfo, merkleRoot, signature, pubKey, cid, encMeta) — see §11.
```

Note step 5: the signature is over the **Merkle root**, not over the canonical JSON string. This is the one substantive change to the integrity model (§6) and the reason selective disclosure becomes cryptographically real.

### 4.3 Verification / presentation flow (target)

Two paths exist today and both change. The **portal full-verify** (`/verifyCredential`) discloses everything; the **mobile presentation** (`/resolveSession`) discloses a holder-chosen subset. With B2 the server cannot decrypt, so the crypto moves to the recipient. See §7.3 for the presentation protocol and §8 for who runs each check.

---

## 5. The envelope format (KEM-DEM, per-field)

A single versioned JSON object, stored on IPFS (and cached in MySQL). This is standard hybrid public-key encryption (KEM-DEM), the same shape TLS 1.3 / HPKE / `age` use, specialized to per-field DEM keys so fields can be disclosed independently.

```jsonc
{
  "v": 1,                                  // envelope schema version
  "kemAlg": "ML-KEM-768",
  "aeadAlg": "AES-256-GCM",
  "kdf": "HKDF-SHA3-256",
  "recipient": "holder",                   // "holder" at rest; "verifier:<id>" after re-wrap
  "kemCt": "<hex>",                         // ML-KEM ciphertext encapsulating ss to the recipient
  "kdfInfo": "qchain/trackB/v1|<credID>",   // context binding fed to HKDF
  "fields": [
    {
      "key": "gpa",
      "salt": "<hex,16B>",                 // Merkle leaf salt (also enables SD integrity, §6)
      "nonce": "<hex,12B>",                // AES-GCM nonce, random per field
      "ct": "<hex>",                        // AES-256-GCM ciphertext of the field value
      "tag": "<hex,16B>",                  // GCM auth tag (or fold into ct)
      "wrap": "<hex>"                       // K_i wrapped under KWK_i = HKDF(ss, credId|key_i)
    }
    // ... one entry per ATTRIBUTE field
  ],
  "meta": { "credId": "CRED-...", "issuedAt": "..." }  // non-sensitive convenience copy
}
```

**Why one KEM encapsulation + per-field derived wraps** (not one KEM per field): an ML-KEM-768 ciphertext is ~1088 bytes; per-field encapsulation would bloat the envelope enormously. Instead, one encapsulation yields a 32-byte shared secret `ss`; from `ss` we derive a **distinct per-field wrapping key** `KWK_i = HKDF-SHA3-256(ss, info="qchain/trackB/v1|"+credId+"|"+key_i)` and wrap that field's 32-byte `K_i` under `KWK_i`. Re-wrapping to a verifier (§7.3) is then just: from the verifier encapsulation's `ss'` derive `KWK'_i` the same way, unwrap the disclosed `K_i`, and re-wrap them.

**Nonce-reuse caveat (important).** Do **not** wrap all `K_i` under a *single* shared `KWK` with a fixed nonce — that is AES-GCM nonce reuse across fields under one key and is catastrophic. The per-field key derivation above makes each `KWK_i` single-use (one wrap only), so wrapping with AES-256-GCM under a fixed/zero nonce is then safe. Equivalent alternatives: RFC 3394 AES-KW (deterministic, nonce-free, purpose-built for wrapping keys under a KEK), or a single `KWK` with a **distinct random nonce stored per wrap**. Recommendation: per-field derived `KWK_i` — it also makes the re-wrap step symmetric and dependency-free.

**Nonce/salt hygiene.** `K_i` is fresh random per field, so GCM nonces cannot collide across fields even if reused; still generate a random 12-byte nonce per field via `crypto/rand`. `salt_i` is fresh random 16 bytes per field — it both randomizes Merkle leaves (prevents low-entropy-field confirmation attacks, §16 R3) and is required to recompute the leaf at verification.

---

## 6. Selective disclosure with verifiable integrity (salted-Merkle + ML-DSA)

This is the crux, and it is the part the PDF hand-waves. **A single ML-DSA signature over the whole-document hash is fundamentally incompatible with disclosing only a subset of fields** — a verifier who receives 3 of 8 fields cannot recompute the whole-document hash, so cannot check the signature. This is the classic selective-disclosure/signature problem. Two families of solutions exist: (a) multi-message signatures (BBS+) — **not available as a NIST-PQC primitive today**, so ruled out for a PQC project; (b) **hash-commitment trees** — salt each field, hash to a leaf, Merkle-tree the leaves, sign the root. We use (b): it is PQC-clean (only SHA3 + ML-DSA, both already in the repo) and is exactly how SD-JWT / mDoc-style selective disclosure achieves integrity.

**Issuance.** As §4.2 steps 3–5. `leaf_i = SHA3-256(salt_i || canonicalKV(key_i, value_i))`; Merkle root over leaves sorted by `key`; `signature = ML-DSA-44.Sign(root)`. Root + signature + pubkey go on-chain (replacing the old `CredentialHash`/`Signature` semantics — same fields, new meaning).

**Disclosure.** For the disclosed field set D, the holder reveals for each `i ∈ D`: `(key_i, value_i, salt_i)` plus a **Merkle inclusion proof** (the sibling hashes on the path to the root). Hidden fields reveal nothing (not even their salt).

**Verification of a subset.** The recipient: recomputes `leaf_i` for each disclosed field from `(salt_i, key_i, value_i)`; uses the inclusion proofs to recompute the root; checks `ML-DSA-44.Verify(root, signature, pubKey)`; checks the root equals the on-chain `CredentialHash`; checks on-chain `Status == active`. All four original checks map onto this cleanly:

| Original check | Subset-verification equivalent |
|---|---|
| existsOnChain | on-chain record fetched for credID |
| notRevoked | on-chain `Status == active` |
| signatureValid | `ML-DSA-44.Verify(onChainRoot, signature, pubKey)` |
| hashMatches | recomputed Merkle root (from disclosed leaves + proofs) == on-chain root |

**Full disclosure is the degenerate case** (D = all fields, no proofs needed — rebuild the whole tree), so `/verifyCredential` and `/resolveSession` share one verification routine. Legacy v0 credentials (single hash over canonical JSON) keep the old path, selected by the on-chain `EncMeta.v`/absence thereof (§13).

**Honest-scope note (your D3 choice).** Because you also chose B2, disclosure integrity *and* confidentiality are both recipient-verified — this is the "cryptographically real" end state, not the interim server-redaction. The interim (Phase B during rollout, §15) may still redact server-side while the wallet/verifier key plumbing is built; the doc/UI must not call that interim state "confidential."

---

## 7. Key management — holder-held (B2)

### 7.1 Keys in the system after Track B

| Key | Owner | Type | Lives where | New? |
|---|---|---|---|---|
| Org signing key | Issuer backend | ML-DSA-44 | `offchain/.env` (as today) | no |
| **Holder KEM key** | Holder (QWallet) | **ML-KEM-768** | device secure storage; **public** key registered on-chain + DB | **yes** |
| **Verifier KEM key** | Verifier app | **ML-KEM-768** | verifier app storage; public key registered | **yes** |

The org signing key is unchanged — issuance still signs the Merkle root with the existing `issuerPrivKeyHex`. The two new KEM keypairs are what B2 requires.

### 7.2 Holder key generation & registration

- **Generate** in the QWallet (Flutter) at wallet activation (`is_wallet_activated` flips true, `holders` table). ML-KEM-768 keypair; **secret key stays on device** (Android Keystore / iOS Keychain / secure enclave-backed storage). If the Flutter side cannot bind liboqs easily, generate via a new authenticated backend endpoint `POST /mobile/registerHolderKey` that accepts a device-generated public key — the secret must never transit the server.
- **Register** the public key: new column `holders.kem_public_key TEXT` + write it to the on-chain Holder record (new chaincode arg, §11) so issuance can fetch it trustlessly. Bind it to the holder identity (Emirates ID) — this binding is only as strong as the current authentication (G7); note the dependency.
- **Issuance dependency:** the issuer must have the holder's registered ML-KEM public key *before* it can wrap. If a holder has no key yet (not activated), either (i) reject issuance with a clear error, or (ii) issue in a "pending-encryption" state and encrypt on first activation. Recommend (i) for simplicity in the capstone; document (ii) as future work. **← Decision O1, §16.**

### 7.3 Presentation re-wrap protocol (the hard part)

Today (`/mobile/generateOTP`, `/mobile/generatePresentation`) the holder mints a session row containing `hidden_fields`; the verifier later redeems it and the *server* reads + redacts. With B2 the server cannot read, so the holder's key must participate. The design tension: the OTP/manual flow is **asynchronous** (holder generates a code now; an unknown verifier redeems later), but re-wrapping needs the **verifier's public key** at wrap time.

Two viable protocols — recommend **P-A** for the capstone, document **P-B**:

**P-A — Verifier-static-key, holder targets verifier (recommended).** Verifiers have a registered static ML-KEM public key (like holders). When the holder generates a presentation they select/scan the target verifier (the QR the *verifier* displays, or a verifier picker), so the holder knows the verifier's public key at generation time. The holder's wallet then, at generation time:
1. Fetches the at-rest envelope (from IPFS/DB via an endpoint), decapsulates `ss` with the holder secret, derives `KWK`, unwraps `K_i` for disclosed fields only.
2. Fresh ML-KEM encapsulation to the *verifier's* public key -> `ss'` -> `KWK'`; re-wraps each disclosed `K_i` under `KWK'`.
3. Builds a **presentation token**: `{ credId, disclosed:[{key, value?→ct, salt, nonce, wrap', merkleProof}], kemCtToVerifier, rootSignature }`. Fields stay encrypted end-to-end; only the verifier can unwrap.
4. Posts the token to the server, which stores it in `mobile_sessions` (opaque blob — server can't read it) and returns the OTP/QR handle.

At redemption, `/resolveSession` returns the opaque token to the verifier app; the verifier decapsulates with its secret, unwraps `K_i`, AES-decrypts the disclosed fields, recomputes leaves, verifies Merkle proofs + root signature + on-chain status. **Server never sees plaintext.**

**P-B — Two-round ephemeral (QR only).** The verifier's app generates an *ephemeral* ML-KEM keypair per scan and encodes its public key in a challenge QR; the holder scans it, re-wraps to the ephemeral key, returns the token. More forward-secure, no verifier key registry, but requires live holder+verifier interaction (no async OTP). Good as a "future work / QR mode" note.

**Impact on existing endpoints:** `hidden_fields JSON` in `mobile_sessions` (`schema.sql:341`) is replaced/augmented by an opaque `presentation_token JSON` (encrypted). `handleGenerateOTP`/`handleGeneratePresentation` change from "store hidden field names" to "store the holder-produced token." `handleResolveSession` changes from "fetch + decrypt + redact server-side" to "return the opaque token + the on-chain anchor for the verifier to verify." `applySelectiveDisclosure` (`mobile.go:566`) is **deleted** — redaction is no longer a server concern once P-A ships.

### 7.4 Where the current server-side model still helps (transition)

During rollout (§15), a **transitional org KEM key** (effectively B3) lets the server keep decrypting so `/verifyCredential` and the existing portal keep working while the wallet/verifier key infrastructure is built. Issuance in the transition wraps to *both* the holder key (target) and the org key (fallback), behind an `EncMeta.transitional=true` flag. The flag is removed when P-A ships. This is the mechanism that satisfies goal (e) "never break the demo."

---

## 8. Who runs each check (server vs holder vs verifier)

| Step | Phase 1 (today) | Track B end-state (B2) |
|---|---|---|
| Fetch on-chain record | server | server (relays anchor) |
| Decrypt body | n/a (plaintext) | **holder** (at rest) / **verifier** (disclosed subset) |
| Recompute hash/root | server | **verifier** (from disclosed leaves+proofs) |
| ML-DSA verify | server | **verifier** |
| Status check | server | server or verifier (on-chain, public) |
| Redact hidden fields | server (`applySelectiveDisclosure`) | **not needed** — hidden fields never leave the holder |

Implication: the verifier app gains a small crypto module (ML-KEM decap, AES-GCM, Merkle-proof verify, ML-DSA verify). ML-DSA verify already exists server-side; the client needs its own copy (liboqs binding in the verifier app, or a thin verify-only WASM/native module). **← this is real client work, flagged in §15/§16.**

---

## 9. Cryptographic primitives — liboqs specifics & correctness notes

**ML-KEM-768 via liboqs-go** (`go.mod:38`, a 2026 build — FIPS 203 names available). API mirrors the existing signature usage:

```go
kem := oqs.KeyEncapsulation{}
defer kem.Clean()
_ = kem.Init("ML-KEM-768", nil)          // verify the exact enabled name at runtime (see below)
pub, _ := kem.GenerateKeyPair()          // holder/verifier keygen
sec := kem.ExportSecretKey()

// sender side (issuer, or holder re-wrapping):
enc := oqs.KeyEncapsulation{}; _ = enc.Init("ML-KEM-768", nil)
kemCt, ss, _ := enc.EncapSecret(pub)     // ss = 32-byte shared secret

// recipient side:
dec := oqs.KeyEncapsulation{}; _ = dec.Init("ML-KEM-768", sec)
ss2, _ := dec.DecapSecret(kemCt)         // ss2 == ss
```

**Confirm the algorithm name at build time** — older liboqs exposes `"Kyber768"`, FIPS-203 builds expose `"ML-KEM-768"`. Add a startup guard: iterate `oqs.EnabledKEMs()` and pick `ML-KEM-768`, else fall back to `Kyber768`, else fatal. Put the resolved name in a `kemName` const alongside `sigName` (`crypto.go:28`).

**KEM-DEM combiner.** Do **not** use `ss` directly as a key. Run it through a KDF bound to context, deriving a **distinct wrapping key per field**: `KWK_i = HKDF-SHA3-256(ikm=ss, salt=nil, info="qchain/trackB/v1|"+credId+"|"+key_i)`. This binds each wrapping key to the credential *and* the field, versions the scheme, and guarantees each `KWK_i` is used for exactly one wrap. Go's `golang.org/x/crypto/hkdf` + `sha3` (both already vendored) suffice.

**AES-256-GCM** for both the field ciphertexts and the key wraps, via Go stdlib `crypto/aes` + `crypto/cipher`. For **field encryption**: fresh 12-byte random nonce per field (stored in the envelope), 16-byte tag. For **key wrapping**: because each `KWK_i` is single-use (per-field derivation above), wrapping `K_i` under it with a fixed nonce is safe — but if you prefer defense-in-depth, use RFC 3394 AES-KW (`github.com/NickBall/go-aes-key-wrap`) instead. Avoid the failure mode of one shared `KWK` + fixed nonce across many wraps (nonce reuse — see §5 caveat).

**Merkle tree.** SHA3-256 for leaves and internal nodes; domain-separate leaf vs node hashing (`0x00`/`0x01` prefix) to prevent second-preimage/collision between leaf and node hashes; sort leaves by field `key` for determinism; duplicate the last node on odd levels (or use a documented padding rule). ~30 lines, no dependency.

**All quantum-safe:** AES-256 and SHA3-256 are Grover-only (halved security, still ≥128-bit); ML-KEM-768 and ML-DSA-44 are the NIST PQC standards. Confirms the PDF §4.3 pattern — hybrid envelope is the right idea; this doc just makes the DEM per-field and the signature Merkle-based.

---

## 10. File-by-file change list (offchain, Go)

New and changed files. Signatures/pseudocode only.

### 10.1 New: `offchain/envelope.go`
```go
type Envelope struct { V int; KemAlg, AeadAlg, Kdf, Recipient, KemCt, KdfInfo string; Fields []EncField; Meta map[string]string }
type EncField struct { Key, Salt, Nonce, Ct, Tag, Wrap string }

// Issuance-side: build the at-rest envelope wrapped to the holder KEM public key.
func SealToHolder(credID string, fields map[string]string, holderKemPubHex string) (env Envelope, err error)

// Holder-side (QWallet mirror; also used in tests): open at rest.
func OpenAsHolder(env Envelope, holderKemSecHex string) (fields map[string]string, salts map[string]string, err error)

// Holder-side: re-wrap ONLY disclosed fields to a verifier's KEM public key -> presentation token.
func ReWrapForVerifier(env Envelope, holderKemSecHex, verifierKemPubHex string, disclose []string) (PresentationToken, error)

// Verifier-side: open the disclosed subset.
func OpenAsVerifier(tok PresentationToken, verifierKemSecHex string) (fields map[string]string, salts map[string]string, err error)
```

### 10.2 New: `offchain/merkle.go`
```go
func LeafHash(salt, key, value string) string                       // SHA3-256(0x00||salt||canonicalKV)
func BuildMerkle(fields map[string]string, salts map[string]string) (rootHex string, proofs map[string][]string)
func VerifyInclusion(rootHex, key, value, salt string, proof []string) bool
```

### 10.3 New: `offchain/kem.go`
```go
const kemName = "ML-KEM-768"                                        // resolved at startup, see §9
func kemEncap(pubHex string) (kemCtHex, ssHex string, err error)
func kemDecap(kemCtHex, secHex string) (ssHex string, err error)
func kdfWrapKey(ssHex, info string) (kwkHex string)                 // HKDF-SHA3-256
func aesWrap(kwkHex, keyHex string) (wrapHex string); func aesUnwrap(kwkHex, wrapHex string) (keyHex string, err error)
func aesSeal(keyHex, plaintext string) (nonceHex, ctHex, tagHex string, err error)
func aesOpen(keyHex, nonceHex, ctHex, tagHex string) (plaintext string, err error)
```

### 10.4 New: `offchain/cmd/kemkeygen/main.go`
Mirror `cmd/keygen/main.go` but for ML-KEM-768 — generates the **transitional org KEM keypair** (and is the reference impl the QWallet/verifier mirror). Prints `ORG_KEM_PRIVATE_KEY_HEX` / `ORG_KEM_PUBLIC_KEY_HEX` for `.env`.

### 10.5 Changed: `offchain/crypto.go`
- Add `downloadFromIPFS(cid string) ([]byte, error)` using `shell.NewShell(ipfsHost).Cat(cid)` (read path — new; verification will use it).
- Keep `pqcSign`/`pqcVerify`/`sha3Hex`. `credentialCanonicalJSON` is retained only for **legacy v0** verification.

### 10.6 Changed: `offchain/credentials.go` — `handleIssueCredential`
Replace steps 2–6 (`credentials.go:141-184`) with: flatten fields → `BuildMerkle` → sign root → `SealToHolder` (requires holder KEM pubkey lookup) → IPFS add envelope → chaincode `issueCredential(holderID, metaInfoJSON, merkleRoot, signature, pubKey, cid, encMetaJSON)`. Persist the **envelope** into `credential_data` (not `req.Info`). Reject if holder KEM key missing (O1).

### 10.7 Changed: `offchain/verification.go` — `handleVerifyCredential`
Fetch on-chain anchor (root, sig, pubkey, cid, status, metaInfo). Branch on `EncMeta.v`: v0 → old path (`sha3Hex(Info)`); v1 → transitional decrypt via org KEM key (during rollout) OR return the anchor + envelope for a client that decrypts (end-state). Recompute Merkle root over decrypted fields, `pqcVerify(root, sig, pubKey)`, compare to on-chain root, status check. Same response JSON shape (`credentialData`, `checks{...}`) so the frontend is unchanged in the transitional phase.

### 10.8 Changed: `offchain/mobile.go`
- `handleGenerateOTP` / `handleGeneratePresentation`: accept the holder-built `presentationToken` (P-A) instead of `hiddenFields`; store opaque token in `mobile_sessions`.
- `handleResolveSession`: return the opaque token + on-chain anchor; stop decrypting/redacting server-side. Delete `applySelectiveDisclosure`.
- Transitional variant retains server-side redaction behind the transitional flag so mobile keeps working until QWallet ships keys.

### 10.9 Changed: `offchain/config.go` / `server.go`
- Load `ORG_KEM_PRIVATE_KEY_HEX` / `ORG_KEM_PUBLIC_KEY_HEX` (transitional) in `main()` next to the ML-DSA keys (`server.go:42`).
- Resolve `kemName` at startup via `oqs.EnabledKEMs()` and log it next to `PQC algo`.
- New routes: `POST /mobile/registerHolderKey`, `POST /registerVerifierKey`, `GET /getEnvelope?credentialID=` (returns the at-rest envelope to an authenticated holder).

---

## 11. Chaincode changes (`qchain-network/chaincode/QChaincode.js`)

- `registerHolder(ctx, holderID, firstName, lastName, kemPublicKey)` — store `KemPublicKey` on the Holder record so issuance can fetch it on-chain.
- `issueCredential(ctx, holderID, metaInfoJSON, merkleRoot, issuerSignature, issuerPublicKey, ipfsCID, encMetaJSON)` — the stored Credential object replaces `Info: credentialJSON` with `MetaInfo: metaInfoJSON` (metadata only) + `EncMeta: encMetaJSON`; `CredentialHash` now holds the **Merkle root**. No plaintext attributes on-chain.
- `getCredential` unchanged (returns the record; it just no longer contains attribute plaintext).
- Revoke/suspend/restore unchanged.
- **Back-compat:** old records have `Info` and no `EncMeta`; the Go verifier branches on presence of `EncMeta` (§13). Chaincode upgrade is additive (new optional args) so the channel does not need a data migration to keep serving legacy credentials.

---

## 12. Database changes (`qchain-network/scripts/schema.sql`)

```sql
ALTER TABLE holders   ADD COLUMN kem_public_key TEXT NULL;              -- holder ML-KEM pubkey (B2)
ALTER TABLE verifiers ADD COLUMN kem_public_key TEXT NULL;             -- verifier ML-KEM pubkey (P-A)
ALTER TABLE credentials ADD COLUMN enc_version TINYINT NOT NULL DEFAULT 0;  -- 0=legacy plaintext, 1=envelope
-- credential_data now stores the ENVELOPE (ciphertext) for enc_version>=1 (was plaintext attributes).
ALTER TABLE mobile_sessions ADD COLUMN presentation_token JSON NULL;   -- opaque, encrypted (P-A); hidden_fields retired
```
`insertCredential` (`db_credentials.go:84`) sets `enc_version=1` and writes the envelope JSON into `credential_data`. Existing rows keep `enc_version=0`.

---

## 13. Backward compatibility & migration

**Versioning is the backbone.** Every record is tagged: on-chain `EncMeta.v` (absent ⇒ v0), DB `enc_version`, envelope `v`. Verification dispatches on it. This lets legacy plaintext credentials and new encrypted ones coexist — mandatory to avoid re-issuing the live demo's existing credentials.

**Migration of existing plaintext credentials — a clean property:** because the ML-DSA signature model changes (whole-hash → Merkle root), a *pure re-encryption without re-signing is not possible* for legacy creds if we want subset disclosure on them. Two options:
- **M1 (recommended):** leave legacy credentials as v0 (verify via the old single-hash path); only *new* issuances get v1. Zero risk, no re-signing. Selective disclosure on legacy creds stays server-redaction. Document this.
- **M2:** a one-off migration tool re-builds each legacy credential as v1 (flatten → salt → Merkle → **re-sign root** with the org key → encrypt → re-put via a chaincode `migrateCredential` tx). Requires the org signing key and a chaincode migration function; changes the on-chain hash (auditable event). Only do this if the capstone wants a uniform store. **← Decision O2, §16.**

---

## 14. Testing plan

Extends `offchain/server_test.go`. All crypto is deterministic given fixed randomness (inject a seeded reader in tests).

1. **Envelope round-trip:** `SealToHolder` → `OpenAsHolder` returns identical fields; wrong holder secret fails; tampered `ct`/`tag` fails GCM.
2. **Re-wrap:** `ReWrapForVerifier(disclose=[a,c])` → `OpenAsVerifier` yields only a,c; hidden field b unrecoverable (its `K_i`/salt absent from the token).
3. **Merkle SD:** full-disclosure root == issuance root; subset + inclusion proofs recompute the same root; a flipped disclosed value breaks inclusion; a forged proof fails.
4. **Signature over root:** `pqcVerify(root, sig, pubKey)` true for genuine, false if root/sig/pubkey altered.
5. **End-to-end verify:** issue → fetch anchor → open → verify all four checks true; revoke → notRevoked false; tamper on-chain root → hashMatches false.
6. **Legacy path:** a v0 credential still verifies via the old code path.
7. **KEM name resolution:** startup guard picks a valid enabled KEM name.
8. **Availability:** IPFS down but envelope cached in MySQL → verify still succeeds (fallback path).

Add a `docs/` note + a benchmark in `algo-benchmarking/` for ML-KEM-768 encaps/decaps and envelope build time (mirrors the existing ML-DSA benchmarks — good for the report).

---

## 15. Phased rollout (keeps the live demo alive)

| Phase | Deliverable | Demo impact | Server can decrypt? |
|---|---|---|---|
| **B0 — Foundations** | `envelope.go`, `kem.go`, `merkle.go`, `kemkeygen`, tests; startup KEM-name guard; `downloadFromIPFS`. No wiring yet. | none | n/a |
| **B1 — Encrypt at rest (transitional B3)** | Issuance encrypts to holder key **and** transitional org key; body off-chain + envelope in DB; on-chain anchor = Merkle root; verify path decrypts via org key server-side. `enc_version=1`. | none (frontend responses unchanged) | yes (transitional) |
| **B2 — Holder keys** | QWallet ML-KEM keygen + `registerHolderKey`; issuance requires holder key; holder can `OpenAsHolder`. | wallet gains key setup | yes (still, via fallback) |
| **B3 — Verifier keys + P-A presentation** | Verifier ML-KEM keys; holder-built presentation token; `resolveSession` returns opaque token; verifier app decrypts + verifies; delete `applySelectiveDisclosure`; drop the transitional org-key fallback. | verifier app gains crypto module | **no — true B2** |
| **B4 — Cleanup** | Remove transitional flag; per-field selective disclosure fully client-verified; docs/threat-model; optional M2 migration. | none | no |

Ship B0→B1 first: it already removes all plaintext from ledger/IPFS/DB (the actual confidentiality win) while the trust model is still server-side. B2→B3 then hands decryption to holder/verifier for true end-to-end. Each boundary is independently demoable and publishable.

---

## 16. Residual risks & the two open decisions

**Open decisions (need your call before/at implementation):**
- **O1 — Holder-not-yet-activated at issuance.** Reject (simple, recommended) vs pending-encryption queue. Affects `handleIssueCredential`.
- **O2 — Legacy credential migration.** M1 leave-as-v0 (recommended) vs M2 re-sign migration. Affects whether a chaincode `migrateCredential` + tool is built.

**Risks:**
- **R1 — Verification now depends on IPFS.** Mitigated by caching the envelope in `credential_data` (MySQL) and pinning; verify falls back to the DB copy. Still, single IPFS node is a SPOF (G10) — name it in the report.
- **R2 — Client crypto surface.** QWallet (Flutter) and the verifier app need ML-KEM/AES/Merkle/ML-DSA. liboqs bindings on mobile are non-trivial; budget for it, or ship a vetted native/WASM verify+decrypt module. This is the single biggest schedule risk of the B2 choice.
- **R3 — Low-entropy field confirmation.** Salting each Merkle leaf (16 random bytes) defeats "guess the GPA and confirm via hash." Keep salts secret (inside the envelope), never on-chain for attribute fields.
- **R4 — Key custody (G12).** Holder secret loss = permanent loss of that holder's credentials (no server escrow in true B2). Decide on optional social/KMS backup — out of Track B scope but must be acknowledged; the transitional org key is *not* a backup once B3 drops it.
- **R5 — Authentication prerequisite (G7).** Binding a KEM public key to a real holder/verifier identity is only as strong as the (currently absent) API auth. Registration endpoints must land on top of the Phase 2.0 auth work, or the binding is spoofable.
- **R6 — Metadata still on-chain.** holderID/type/issuedAt remain plaintext on-chain by design (Track A scope). Don't overclaim confidentiality in the report — say "credential *body* confidential; identifiers pending Track A / PDC."

---

## 17. Next-session kickoff checklist

1. Confirm O1 and O2 (§16).
2. Confirm the exact enabled KEM name in this liboqs build: run a 5-line `oqs.EnabledKEMs()` probe in the container (`go run` a scratch main) — decides `ML-KEM-768` vs `Kyber768`.
3. Build B0: `kem.go`, `merkle.go`, `envelope.go`, `cmd/kemkeygen`, and their tests. Get §14 tests 1–4, 7 green before wiring anything.
4. Wire B1 into `handleIssueCredential` + `handleVerifyCredential` behind `enc_version`; run §14 tests 5, 6, 8.
5. Apply the SQL in §12 and the chaincode changes in §11; upgrade chaincode on the demo channel (additive, legacy-safe).
6. Only then start B2/B3 (client keys) — treat as a separate sprint with the R2 client-crypto spike first.

**One-line summary of the plan:** move the credential body off-chain as a per-field ML-KEM-768 + AES-256-GCM envelope wrapped to the holder, replace the on-chain single-hash with a salted-Merkle root signed by the existing ML-DSA-44 key so a disclosed subset stays verifiable, and phase the rollout B0→B1 (removes all plaintext, server-side transitional) → B2→B3 (holder/verifier keys, true end-to-end, server blind).

---

*Grounded in: `offchain/{crypto,credentials,verification,mobile,config,fabric,server,db_credentials}.go`, `offchain/cmd/keygen/main.go`, `qchain-network/chaincode/QChaincode.js`, `qchain-network/scripts/schema.sql`, `offchain/go.mod`. Verify liboqs algorithm names and sizes against the installed release before coding.*
