# QChain — Progress Report 1

**Project:** Post Quantum Cryptography in Blockchain Technology  
**Submitted:** 27th September 2026  
**Team:** Team 5M's  
**Supervisors:** Dr. Manar Abu Talib (Head), Dr. Sohail Abbas (Co-Supervisor)

---

## Team Members

| Name | Role | GitHub |
| --- | --- | --- |
| Mohammed Bin Ali Maqqavi | Project Lead, Quantum Engineer | @M0hd-Maqqavi |
| Mohammed Abdul Haris | Frontend Developer, UI/UX Engineer | @mohammed-ah-14 |
| Muhammed Nihal Valiya Puthiyakath | Technical Lead, Software Engineer | @nihvp |
| Mohammed Hisham Obeid | Blockchain Engineer, Security Analyst | @MohammedObeid88 |

---

## 1. Introduction

This progress report documents the first phase of the Senior Project — a post-quantum credential platform for academic and government credentials in the United Arab Emirates, built on a permissioned Hyperledger Fabric network. It covers Week 1 to Week 5 of the Fall 2026 semester (24 August – 27 September 2026).

Every credential-level trust decision in QChain rests on algorithms standardised by NIST for the post-quantum era: **ML-DSA-44** for digital signatures, **ML-KEM-768** for key establishment, and **SHA3-256** for hashing. The platform consists of **QPortal** (a web application for issuing, managing and verifying credentials), **QWallet** (a native mobile wallet in which each holder generates and keeps their own post-quantum keys), a **Go backend** that implements the cryptographic protocols, a **Hyperledger Fabric network** that stores signed credential commitments, and an **IPFS node** that stores the encrypted credential contents.

### 1.1 Project Scope

This report covers:

1. **Requirements, design review and security analysis** of the credential platform
2. **Literature review** covering quantum threat timelines, post-quantum standards and migration mandates, post-quantum blockchains, verifiable credentials and post-quantum identity in Hyperledger Fabric
3. **System architecture and implementation** — the blockchain layer, the backend services and the deployment pipeline
4. **Post-quantum security mechanisms** — issuer-signed commitments, salted selective disclosure, holder-held envelope encryption and holder-signed presentations
5. **Testing** — backend unit tests, chaincode tests and an end-to-end suite covering every API endpoint
6. **UI/UX design** of QPortal and QWallet (Chapter 8)

Two activities are scheduled for the remainder of the semester and are described as planned work: the migration of Fabric's Membership Service Provider (MSP) identities from ECDSA to ML-DSA, and a systematic key-performance-indicator (KPI) benchmarking campaign of the post-quantum operations.

### 1.2 Project Objectives

- **Post-quantum authenticity** — every credential carries an ML-DSA-44 issuer signature over a canonical commitment
- **Post-quantum confidentiality** — credential attributes are stored only as ML-KEM-768/AES-256-GCM envelopes, decryptable solely on the holder's device
- **Selective disclosure** — a holder can reveal a subset of a credential's attributes without exposing the rest
- **Holder binding and non-repudiation** — every presentation is signed with the holder's ML-DSA-44 key and bound to exactly one credential
- **No plaintext credential data on the ledger** — the chain stores commitments and salted hashes, never attribute values
- **Authoritative data sources** — the ledger and IPFS are the sources of truth; the operational database never holds authoritative credential data
- **Operational resilience and automated delivery** — services recover automatically after host restarts; every backend change is tested and deployed with automatic rollback
- **Post-quantum network identities** — Fabric MSP identities migrate from ECDSA to ML-DSA, without a classical fallback
- **Performance evaluation** — the cost of the post-quantum operations is measured and compared across parameter sets and implementations

### 1.3 Expected Outcomes

All outcomes below, except the last two (explicitly planned work), are achieved and documented in this report:

- Issuer-signed, ledger-anchored credential commitments with salted SHA3-256 field hashes
- Holder-sovereign ML-KEM-768 envelope encryption of the full credential body
- Holder-signed ML-DSA-44 presentations bound to a single credential
- A two-organisation Hyperledger Fabric network with role-checked chaincode
- A Go backend exposing 39 REST endpoints, tested end to end (123/123 assertions)
- A public deployment with automatic service recovery and CI/CD with rollback
- Post-quantum MSP identities — **in progress** (research and scoping)
- A full KPI benchmark report — **planned**, Weeks 6–9

---

## 2. Literature Review

The review examines six questions: how soon a cryptographically relevant quantum computer (CRQC) may exist; which standards and migration deadlines apply; how quantum attacks affect blockchains; which post-quantum algorithms are suitable; how credential data can be kept confidential when stored on shared infrastructure; and how far existing work has taken post-quantum cryptography into Hyperledger Fabric's identity layer.

Resource estimates for breaking RSA-2048 fell by more than an order of magnitude between 2019 and 2025, hardware has crossed the quantum error-correction threshold, and industrial roadmaps target fault-tolerant systems with hundreds of logical qubits by 2029. Against this background, the most recent expert survey rates a CRQC within ten years as 28–49% likely and within fifteen years as 51–70% likely.

### 2.1 Standardisation and Migration Timelines

NIST published the first three post-quantum standards in August 2024: ML-KEM for key encapsulation (FIPS 203), ML-DSA for lattice-based signatures (FIPS 204) and SLH-DSA for stateless hash-based signatures (FIPS 205). Migration deadlines have followed quickly: NIST deprecates quantum-vulnerable algorithms from 2030 and disallows them from 2035; the UK NCSC sets milestones for 2028, 2031 and 2035; the EU's coordinated roadmap requires national plans by 2026 and high-risk systems migrated by 2030. The **United Arab Emirates approved a National Encryption Policy in November 2025** that requires government entities to adopt officially approved transition plans, and in **May 2026 the UAE Cyber Security Council began a national post-quantum transition programme** with the Advanced Technology Research Council. Because QChain targets UAE academic and government credentials, these mandates make post-quantum protection a regulatory requirement, not an optional enhancement.

### 2.2 Blockchain Security in the Quantum Era

Shor's algorithm breaks the signatures that authorise transactions and identify participants, while Grover's algorithm only halves the effective security of hash functions, so SHA3-256 remains adequate. Replacing signatures has system-wide cost: post-quantum signatures and keys are one to two orders of magnitude larger than their elliptic-curve counterparts. In a permissioned network such as Hyperledger Fabric the consensus protocol (Raft) does not rely on proof-of-work; the quantum exposure lies in the X.509 identities that endorse and order transactions, and in any application data written to the ledger.

### 2.3 Post-Quantum Cryptography Families

Lattice-based schemes (ML-KEM, ML-DSA, FN-DSA) offer the best overall balance of key size, signature size and speed, and dominate the NIST selections. Hash-based SLH-DSA rests on the most conservative assumptions but produces signatures of 8–17 KB. Multivariate schemes suffered a practical break when Rainbow was shown to be recoverable in a weekend on a laptop, and isogeny-based key exchange was broken the same year.

| Scheme | Standard | Public key (bytes) | Signature / ciphertext (bytes) |
| --- | --- | --- | --- |
| ML-DSA-44 | FIPS 204 | 1,312 | 2,420 |
| FN-DSA-512 | FIPS 206 (draft) | 897 | ≈ 666 |
| SLH-DSA-SHA2-128s | FIPS 205 | 32 | 7,856 |
| ML-KEM-768 | FIPS 203 | 1,184 | 1,088 |
| ECDSA P-256 (classical) | FIPS 186-5 | 64 | ≈ 64–72 |

On this evidence QChain uses **ML-DSA-44** for signatures and **ML-KEM-768** for key establishment. ML-DSA-44 is final, fast to sign and verify, and its 2.4 KB signature is acceptable for a ledger that stores one signature per credential; ML-KEM-768 provides NIST category 3 security for data that must remain confidential for decades.

### 2.4 Off-Chain Storage, Confidentiality and Data Protection

IPFS provides no confidentiality on its own — any node that knows or discovers a content identifier (CID) can retrieve the content, so data must be encrypted before it is added. The standard construction for encrypting data to a recipient's public key is the KEM-DEM paradigm formalised in Hybrid Public Key Encryption (RFC 9180): a key-encapsulation mechanism establishes a shared secret, a key-derivation function expands it, and an authenticated cipher encrypts the data. The European Data Protection Board's guidelines on blockchain technologies (02/2025) advise that personal data should, as a general rule, not be stored on a blockchain, and discuss off-chain storage combined with on-chain commitments as a way to reduce the personal data recorded on the ledger. QChain follows this guidance: attribute values never reach the ledger.

### 2.5 Verifiable Credentials and Selective Disclosure

The W3C Verifiable Credentials Data Model 2.0 defines the issuer–holder–verifier model that QChain follows. Selective disclosure — revealing only some attributes — is achieved in practice by salted digests: SD-JWT (RFC 9901) replaces each disclosable claim with the hash of a random salt, the claim name and its value, recommends salts of at least 128 bits, and binds presentations to the holder through a key-binding signature; ISO/IEC 18013-5 (mobile driving licences) uses the same salted-digest structure. QChain adopts this approach, instantiated entirely with post-quantum primitives.

### 2.6 Post-Quantum Cryptography in the Hyperledger Fabric Identity Layer

Fabric identifies every peer, orderer and client with an X.509 certificate issued by a Fabric certificate authority and validated by the Membership Service Provider (MSP); signatures are produced by the blockchain cryptographic service provider (BCCSP), which currently supports ECDSA. PQFabric was an early system to introduce post-quantum signatures into Fabric, using a **hybrid** design in which classical and post-quantum signatures coexist. A 2025 study integrated **lightweight** post-quantum schemes together with national cryptographic algorithms into Fabric. The ecosystem is now converging on the building blocks a pure post-quantum identity layer requires: Fabric v3.0 added Ed25519 to its MSP (showing the identity layer can accept new algorithms), RFC 9881 standardises the X.509 algorithm identifiers for ML-DSA certificates, and Go 1.27 adds ML-DSA to its standard library and X.509 package.

### 2.7 Conclusion and Research Gap

No published system combines post-quantum authenticity, holder-held post-quantum confidentiality, salted selective disclosure and holder-signed presentations on a permissioned ledger, with a path to a purely post-quantum identity layer. This is the gap QChain targets (Section 3.4).

| Ref. No. | Paper Title | Year | Publisher | Key Insights | Limitations |
| --- | --- | --- | --- | --- | --- |
| [1] | How to factor 2048 bit RSA integers with less than a million noisy qubits | 2025 | arXiv | RSA-2048 breakable with < 1M noisy qubits in < 1 week | Resource estimate; hardware not yet built |
| [2] | Quantum error correction below the surface code threshold | 2025 | Nature | Logical error falls as code distance grows | Far from CRQC scale |
| [3] | Quantum Threat Timeline Report 2025 | 2026 | Global Risk Institute | CRQC 28–49% likely within 10 years | Expert-opinion survey (26 experts) |
| [4] | PQFabric: A Permissioned Blockchain Secure from Both Classical and Quantum Attacks | 2021 | IEEE ICBC | First PQ signatures in Fabric; crypto-agile | Hybrid classical + PQ; pre-standard algorithms |
| [5] | Enhancing Hyperledger Fabric Security with Lightweight PQC and National Cryptographic Algorithms | 2025 | IEEE FRUCT | Lightweight PQC integrated in Fabric | Non-standardised lightweight schemes; no data privacy |
| [6] | Towards Post-Quantum Verifiable Credentials | 2024 | ACM ARES | Evaluates NIST signatures in VC formats | No ledger anchoring or encryption |
| [7] | Verification of Academic Records Using Hyperledger Fabric and IPFS | 2023 | IEEE ICPCSN | Fabric + IPFS academic records | Classical cryptography; unencrypted files |
| [8] | Selective Disclosure for JSON Web Tokens (RFC 9901) | 2025 | IETF | Salted digests (≥128-bit salts) and key binding | Classical signature suites |

The full 43-source bibliography is in the report's own reference manager; the eight sources above are the ones directly cited in this condensed account.

---

## 3. Problem Statement and Proposed Solution

### 3.1 The Quantum Threat to Credential Systems

Digital credential systems face four quantum-era problems: **forgery** (once ECDSA/RSA is broken, an attacker can forge credentials); **harvest-now-decrypt-later** (credential data encrypted with classical schemes and stored on replicated infrastructure can be copied today and decrypted later, and the ciphertext on a blockchain can never be deleted); **identity compromise** (the X.509 identities that authorise peers and officials are ECDSA-based); and **privacy** (storing personal data in plaintext on an immutable, multi-organisation ledger conflicts with data-protection principles).

### 3.2 Proposed Solution

QChain addresses these problems with a post-quantum credential lifecycle:

1. **Wallet activation** — the holder's wallet generates an ML-KEM-768 key pair and an ML-DSA-44 key pair on the device; only the public keys leave the device
2. **Issuance** — the backend draws a 128-bit salt per attribute, computes a salted SHA3-256 hash of each, encrypts the attributes and salts to the holder's ML-KEM-768 key, stores the envelope on IPFS, and signs a canonical commitment to the metadata, the envelope's CID and all field hashes with the issuer's ML-DSA-44 key
3. **Storage and retrieval** — the wallet retrieves and decrypts the envelope on the device; neither the backend, IPFS nor any ledger peer can decrypt it
4. **Presentation** — the holder discloses selected attributes, signs the payload with the ML-DSA-44 key, and shares it through a single-use QR code or a six-digit OTP valid for 120 seconds
5. **Verification** — five cryptographic checks run against the ledger: existence, status, the issuer signature over the recomputed commitment, the salted field hashes and the holder signature
6. **Lifecycle management** — issuers can suspend, restore, re-date and permanently revoke credentials; every change is an endorsed ledger transaction

### 3.3 Research Contribution

QChain is a **fully post-quantum verifiable-credential architecture on a permissioned ledger**, in which every credential-level trust decision rests exclusively on NIST-final post-quantum primitives (FIPS 203, FIPS 204) and SHA3-256, with no classical fallback. To the team's knowledge, no published system combines:

- **C1 — Ledger-anchored post-quantum commitments.** The issuer's ML-DSA-44 signature covers a canonical commitment binding the credential metadata, the IPFS CID and a salted SHA3-256 digest of every attribute; verifiers recompute it from ledger state rather than trusting a stored hash.
- **C2 — Holder-sovereign post-quantum confidentiality.** Every attribute is sealed in a per-field KEM-DEM envelope to an ML-KEM-768 key generated inside the holder's device.
- **C3 — Quantum-safe selective disclosure without zero-knowledge machinery.** 128-bit per-field salts travel only inside the holder-encrypted envelope.
- **C4 — Post-quantum holder binding.** Every presentation is signed with the holder's ML-DSA-44 key and bound to exactly one credential.
- **C5 — No plaintext credential data on the ledger.** Attribute values never reach the ledger; on-chain personal data is limited to the holder's name and a pseudonymous identifier.
- **C6 — A purely post-quantum identity layer (in progress).** Fabric's MSP identities are being migrated to ML-DSA without a classical fallback, in contrast to PQFabric's hybrid design and the lightweight-PQC integration of [5].

---

## 4. System Architecture

### 4.1 High-Level Overview

```
USERS
 ├── Issuer / Verifier / IT Administrator (QPortal — Flutter Web)
 └── Credential Holder (QWallet — Flutter, native Android/iOS)
        │
        ▼
ACCESS LAYER
 └── Public HTTPS endpoint → Nginx web gateway (serves QPortal, proxies /api)
        │
        ▼
QCHAIN API — Go backend, 39 REST endpoints + health check
 ├── Commitment & signing (ML-DSA-44 over SHA3-256)
 ├── Envelope sealing (ML-KEM-768 · HKDF-SHA3-256 · AES-256-GCM)
 ├── Verification engine (5 cryptographic checks)
 ├── Presentation sessions (QR / OTP, 120 s, single-use)
 ├── Credential lifecycle (issue · update · suspend · restore · revoke)
 └── Holders, subscriptions, staff, directory & audit
        │
        ├─────────────────────────────┬───────────────────────┐
        ▼                             ▼                       ▼
HYPERLEDGER FABRIC                  IPFS (Kubo)             MySQL 8
 ├── GovernmentMSP + GeneralMSP       Encrypted envelopes    Operational index:
 │   (peer0 + CouchDB each)           (content-addressed,    sessions, verification
 ├── Raft (etcdraft) orderer          pinned)                logs, subscriptions,
 ├── 3 Fabric CAs                                             staff, audit trail
 └── QChaincode (JavaScript):
     role-checked writes,
     validated inputs,
     batch reads

Authoritative for: signed credential commitments, salted field    Authoritative for:   Holds no
hashes, status and lifecycle times, holder public keys             the credential body  authoritative
                                                                     (ciphertext only)    credential data
```

### 4.2 User Applications

| Application | Platform | Users | Security role |
| --- | --- | --- | --- |
| QPortal | Flutter web, served by the Nginx gateway | Issuer, verifier, IT-administrator staff | Presents verification results; holds no keys |
| QWallet | Flutter, native Android and iOS | Credential holders | Generates and stores holder keys; decrypts envelopes; signs presentations |

The wallet is native by design: each holder has exactly one ML-KEM-768 and one ML-DSA-44 key pair, generated and stored in the device's secure storage. A browser-based wallet would create a different key pair in every browser, and its post-quantum library is accessed through native bindings that cannot compile for the web.

### 4.3 Hyperledger Fabric Network Topology

| Component | Configuration |
| --- | --- |
| Organisations | GovernmentMSP, GeneralMSP (peer organisations) and an orderer organisation |
| Peers | peer0.government.uae.com (7051) and peer0.general.uae.com (9051), each with CouchDB |
| Ordering service | Raft (etcdraft); batch timeout 2 s, at most 10 messages per block |
| Certificate authorities | GovernmentCA, GeneralCA, OrdererCA |
| Channel and chaincode | mychannel; qchaincode (JavaScript), endorsement by both peer organisations |
| Application identities | issuer1 and verifier1, enrolled with a role attribute embedded in their certificates |

### 4.4 Data Placement and Sources of Truth

A central architectural decision is to make the ledger and IPFS the authoritative sources of all credential data and to keep the operational database free of authoritative credential data. The alternative — encrypting sensitive columns in a conventional database — was rejected because it would leave the database, and whoever controls its keys, as the arbiter of what a credential says.

| Data item | Authoritative store | Protection |
| --- | --- | --- |
| Credential attribute values | IPFS (encrypted envelope) | ML-KEM-768 + AES-256-GCM |
| Salted field hashes | Ledger | SHA3-256 with 128-bit salts |
| Credential metadata, commitment hash, issuer signature | Ledger | Endorsed writes; ML-DSA-44 |
| Holder public keys | Ledger | Exact-length validation; issuer-bound |
| Holder private keys | Holder's device only | Platform secure storage |
| Emirates ID mapping, sessions, logs | MySQL | Database access control |

---

## 5. System Analysis

### 5.1 User Roles

**Issuer** — registers holders, issues credentials, manages their lifecycle. **Holder** — activates the wallet, receives and views credentials, presents selected attributes, approves or rejects verifier subscriptions. **Verifier** — verifies presentations, reviews verification history, subscribes to status changes. **System administrator** — manages staff and roles, reviews the audit log, operates the Fabric network. **Researcher** — benchmarks the post-quantum algorithms and analyses storage and scalability.

### 5.2 Use Cases

The system covers the complete credential lifecycle: wallet activation and key binding; issuance with salted field hashes and holder-encrypted envelopes; retrieval and on-device decryption; QR/OTP presentation with selective disclosure; five-check verification; and suspend/restore/revoke. Verifiers may subscribe to a credential, with holder consent, and are alerted on suspension or revocation.

---

## 6. Implementation

### 6.1 Blockchain Layer

The chaincode stores two document types, holders and credentials. A credential record contains the commitment version, the holder identifier, the issuing identity and organisation, the status, the credential type, the issue time, the expiry date, the CID, the field hashes, the commitment hash, the issuer signature and the issuer public key — no attribute values. Every write checks the caller's role attribute and throws on failure, so an invalid write fails endorsement rather than committing an error result:

```javascript
_checkAccess(ctx, role) {
    if (!ctx.clientIdentity.assertAttributeValue('role', role)) {
        throw new Error(`Access denied. Only a ${role} official may access this function.`);
    }
}

// Binds the holder's wallet keys: ML-KEM-768 (credentials are encrypted to
// it) and ML-DSA-44 (presentations are signed with it).
async bindHolderKeys(ctx, holderID, kemPublicKey, dsaPublicKey) {
    this._checkAccess(ctx, 'issuer');
    const holder = await this._getHolder(ctx, holderID);
    this._requireHex(kemPublicKey, 'kemPublicKey', KEM_PUBLIC_KEY_HEX_LENGTH);
    this._requireHex(dsaPublicKey, 'dsaPublicKey', DSA_PUBLIC_KEY_HEX_LENGTH);
    holder.KemPublicKey = kemPublicKey;
    holder.DsaPublicKey = dsaPublicKey;
    await this._put(ctx, holderID, holder);
    return JSON.stringify({ success: true, holderID });
}
```

Code is available in `qchain-network/chaincode/QChaincode.js`.

### 6.2 Backend API

The backend exposes 39 REST endpoints and a health check, grouped as follows:

| Group | Count | Purpose |
| --- | --- | --- |
| Credential lifecycle | 8 | Issue, update, suspend, restore, revoke, list, detail |
| Verification | 3 | Resolve session, verification history and detail |
| Holders, dashboard, audit | 3 | Holder listing, dashboard stats, audit logs |
| Subscriptions and alerts | 6 | Request, approve, reject, acknowledge, list |
| Staff and directory | 5 | Invite, update role, remove, directory listing |
| Mobile (QWallet) | 14 | Key registration, envelope retrieval, presentation sessions, wallet views |

Status, dates, keys, hashes and signatures are always read from the ledger. The database is used for identifiers, contact data and operational records, and is never used for trust decisions. Code is available in `offchain/`.

---

## 7. Post-Quantum Security Mechanisms

### 7.1 Issuer-Side ML-DSA-44 Signed Commitments

The issuer signs a canonical commitment, not the credential body: `{v, holderID, credentialType, issuedAt, issuerOrgID, expiryDate, cid, fieldHashes}`. The canonical form uses sorted keys, no whitespace and no HTML escaping; the hash is signed with the issuer's ML-DSA-44 key.

```go
// commitmentCanonicalJSON renders the commitment deterministically: sorted keys,
// no whitespace, no HTML escaping, and every key always present.
func commitmentCanonicalJSON(c CredentialCommitment) (string, error) {
	fieldHashes := c.FieldHashes
	if fieldHashes == nil {
		fieldHashes = map[string]string{}
	}
	payload := map[string]any{
		"v":              commitmentVersion,
		"holderID":       c.HolderID,
		"credentialType": c.CredentialType,
		"issuedAt":       c.IssuedAt,
		"issuerOrgID":    c.IssuerOrgID,
		"expiryDate":     c.ExpiryDate,
		"cid":            c.CID,
		"fieldHashes":    fieldHashes,
	}
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(payload); err != nil {
		return "", fmt.Errorf("encode commitment: %w", err)
	}
	return strings.TrimSuffix(buf.String(), "\n"), nil
}

// signCommitment hashes the commitment (SHA3-256) and signs the hash with
// the issuer's ML-DSA-44 key. Returns (credentialHash, signatureHex).
func signCommitment(c CredentialCommitment, privateKeyHex string) (string, string, error) {
	hash, err := commitmentHash(c)
	if err != nil {
		return "", "", err
	}
	sig, err := pqcSign(hash, privateKeyHex)
	if err != nil {
		return "", "", fmt.Errorf("sign commitment: %w", err)
	}
	return hash, sig, nil
}
```

During verification, the backend **rebuilds the commitment from the ledger fields** and hashes it again; it never trusts the stored hash. Changing any committed field on the ledger therefore invalidates the signature.

### 7.2 Salted Field Hashes for Selective Disclosure

For every attribute the backend draws a 16-byte (128-bit) random salt and computes `SHA3-256(salt:key:value)`. Only the hashes reach the ledger; the salts travel inside the holder's envelope.

```go
// saltedFieldHash is the per-field fingerprint committed on-chain.
func saltedFieldHash(salt, key, value string) string {
	return sha3Hex(salt + ":" + key + ":" + value)
}

// commitAttributes draws a 128-bit salt for every attribute and returns the
// salts (for the holder's envelope) and the salted field hashes (for the chain).
func commitAttributes(attrs map[string]string) (salts, fieldHashes map[string]string, err error) {
	salts = make(map[string]string, len(attrs))
	fieldHashes = make(map[string]string, len(attrs))
	for key, value := range attrs {
		salt, err := newFieldSalt() // 16 random bytes
		if err != nil {
			return nil, nil, err
		}
		salts[key] = salt
		fieldHashes[key] = saltedFieldHash(salt, key, value)
	}
	return salts, fieldHashes, nil
}

// verifyDisclosedFields checks every disclosed value against its on-chain
// salted field hash. Returns nil only if all of them match.
func verifyDisclosedFields(disclosed, salts, onChain map[string]string) error {
	if err := validateDisclosureSalts(disclosed, salts); err != nil {
		return err
	}
	for _, key := range sortedKeys(disclosed) {
		want, ok := onChain[key]
		if !ok {
			return fmt.Errorf("field %q is not part of this credential", key)
		}
		if saltedFieldHash(salts[key], key, disclosed[key]) != want {
			return fmt.Errorf("field %q does not match its on-chain hash", key)
		}
	}
	return nil
}
```

### 7.3 Holder-Side ML-KEM-768 Envelope Encryption

The credential body exists in exactly one place: an envelope on IPFS encrypted to the holder's ML-KEM-768 public key. For every field the backend draws a random 256-bit data key, encrypts the field with AES-256-GCM, and wraps the data key under a single-use key-wrapping key derived with HKDF-SHA3-256 from the shared secret, a random envelope context and the field name.

```go
// sealAttributes builds a per-field envelope over attrs, wrapped to every
// recipient (in QChain: only the holder's ML-KEM-768 public key).
func sealAttributes(contextID string, attrs map[string]json.RawMessage, recipients []Recipient) (*Envelope, error) {
	env := &Envelope{Magic: envelopeMagic, V: envelopeVersion, KemAlg: kemName,
		AeadAlg: "AES-256-GCM", Kdf: "HKDF-SHA3-256", CredID: contextID}
	ss := make(map[string]string, len(recipients)) // recipient -> shared secret
	for _, r := range recipients {
		kemCt, s, err := kemEncap(r.PubHex) // ML-KEM-768 encapsulation
		if err != nil {
			return nil, fmt.Errorf("encapsulate to %q: %w", r.Name, err)
		}
		env.Wraps = append(env.Wraps, KemWrap{Recipient: r.Name, KemCt: kemCt})
		ss[r.Name] = s
	}
	for _, key := range sortedKeys(attrs) {
		dataKey := make([]byte, 32) // fresh AES-256 data key per field
		if _, err := io.ReadFull(rand.Reader, dataKey); err != nil {
			return nil, fmt.Errorf("random data key: %w", err)
		}
		nonce, ct, err := aesSeal(hex.EncodeToString(dataKey), attrs[key])
		if err != nil {
			return nil, fmt.Errorf("encrypt field %q: %w", key, err)
		}
		f := EncField{Key: key, Nonce: nonce, Ct: ct, Wrap: map[string]string{}}
		for _, r := range recipients {
			// single-use key-wrapping key: HKDF-SHA3-256(shared secret, context | field)
			kwk, err := deriveKey(ss[r.Name], hkdfFieldInfo(contextID, key))
			if err != nil {
				return nil, err
			}
			w, err := wrapKey(kwk, dataKey)
			if err != nil {
				return nil, err
			}
			f.Wrap[r.Name] = w
		}
		env.Fields = append(env.Fields, f)
	}
	return env, nil
}
```

A key design decision was to hold the decryption keys **on the holder's device** rather than at the issuing organisation. Organisation-held keys would make the backend a single point of confidentiality failure; with holder-held keys the backend can seal an envelope but can never open it.

### 7.4 Holder-Side ML-DSA-44 Presentations

A presentation is a canonical JSON payload containing the credential identifier, the disclosed fields, their salts and a timestamp, signed with the holder's ML-DSA-44 key. The backend registers it as a session identified by a QR token or a six-digit OTP, valid for 120 seconds and redeemable once. The payload must name the credential it was created for — a presentation naming a different credential is rejected even if its signature is valid, which prevents a signed presentation of one credential from being replayed as evidence for another.

### 7.5 Verification Pipeline

Five checks run against the ledger, and all of them run even after one fails, so the verdict can report the most significant failure by a fixed precedence: `NOT_FOUND > REVOKED > SUSPENDED > EXPIRED > SIGNATURE_INVALID > HASH_MISMATCH > FIELD_HASHES_INVALID > HOLDER_SIGNATURE_INVALID`.

```go
func verifyPresentation(in VerifyInput) VerifyOutcome {
	var out VerifyOutcome
	payload, payloadErr := parseDisclosedPayload(in.RawPayload)
	if payloadErr == nil {
		out.Disclosed = payload.DisclosedFields
	}
	if in.Cred == nil {
		out.Reason = reasonNotFound
		return out
	}
	cred := in.Cred
	out.ExistsOnChain = true
	out.Status = effectiveStatus(cred, in.Now)
	out.NotRevoked = cred.Status == "active"

	// Issuer signature over the commitment rebuilt from the chain — never the
	// stored hash — and only from the trusted issuer key.
	if hash, err := commitmentHash(commitmentFromChain(cred)); err == nil {
		out.HashMatches = hash == cred.CredentialHash
		if in.TrustedIssuerKey != "" && strings.EqualFold(cred.PublicKey, in.TrustedIssuerKey) {
			out.SignatureValid, _ = pqcVerify(hash, cred.Signature, cred.PublicKey)
		}
	}

	if payloadErr == nil {
		out.FieldHashesValid = verifyDisclosedFields(payload.DisclosedFields, payload.Salts, cred.FieldHashes) == nil

		payloadID := strings.TrimSpace(payload.CredentialID)
		boundToCredential := payloadID != "" && (payloadID == in.DisplayID || payloadID == in.FabricID)
		if boundToCredential && in.Holder != nil && in.Holder.DsaPublicKey != "" && in.HolderSignature != "" {
			out.HolderSignatureValid, _ = pqcVerify(sha3Hex(in.RawPayload), in.HolderSignature, in.Holder.DsaPublicKey)
		}
	}

	switch {
	case out.Status == "revoked":
		out.Reason = reasonRevoked
	case out.Status == "suspended":
		out.Reason = reasonSuspended
	case out.Status == "expired":
		out.Reason = reasonExpired
	case !out.SignatureValid:
		out.Reason = reasonSignatureInvalid
	case !out.HashMatches:
		out.Reason = reasonHashMismatch
	case !out.FieldHashesValid:
		out.Reason = reasonFieldHashesInvalid
	case !out.HolderSignatureValid:
		out.Reason = reasonHolderSignatureInvalid
	}
	out.Verified = out.Reason == ""
	return out
}
```

### 7.6 Security Review Findings

After the mechanisms were implemented, the team reviewed them against the threat model:

| # | Finding | Severity | Status |
| --- | --- | --- | --- |
| 1 | The holder key-binding transaction did not check the caller's role | High | Fixed |
| 2 | A presentation was not bound to the credential it was presented for | Medium | Fixed |
| 3 | Residual server-side holder key generation and an organisation-level decryption key | Medium | Fixed |
| 4 | A caller-supplied holder identifier could overwrite an existing holder's record | Medium | Fixed |
| 5 | Envelope retrieval does not verify that the caller is the holder | Low | Deferred to the authentication work |

---

## 8. UI/UX Design

*(Left for the UI/UX designer to complete — see the team's Notion workspace for the current QPortal and QWallet screens.)*

---

## 9. Testing and Preliminary Results

The system is tested at three levels: backend unit tests, chaincode tests, and an end-to-end suite against the live deployment.

| Suite | Scope | Result |
| --- | --- | --- |
| Backend unit tests (Go testing) | 51 test functions, 101 including sub-tests: commitment, salts, envelopes, HKDF interoperability with the wallet, verification including ledger- and holder-side tampering | All passed (1.16 s); static analysis clean |
| Chaincode tests (node:test) | 12 tests: exposed transactions, role-based access, input validation, lifecycle, batch reads | All passed |
| End-to-end API suite | 123 assertions in 17 groups covering all 39 endpoints and the health check | 123 / 123 passed |

The end-to-end suite drives the deployed system through a complete scenario: it registers holders, generates real ML-KEM-768 and ML-DSA-44 key pairs, binds them on the ledger, issues credentials, retrieves and decrypts the envelope as the holder, creates signed presentations, verifies them, and exercises the full lifecycle, tamper detection, wallet endpoints, subscriptions, staff management and audit logs.

**Tamper and negative testing** confirms that: a disclosed value altered by the holder is rejected with `FIELD_HASHES_INVALID`, even though the holder's own signature over the altered payload is valid; a forged holder signature is rejected with `HOLDER_SIGNATURE_INVALID`; presentations without salts, with a salt for an undisclosed field, or naming a different credential are rejected; a redeemed session cannot be redeemed again; and a revoked credential cannot be restored, re-revoked or edited.

### 9.1 Cryptographic Performance

A preliminary comparison of ML-DSA at the three security levels, in two Go implementations:

| Operation | 44 (liboqs-go / CIRCL) | 65 | 87 |
| --- | --- | --- | --- |
| Key generation (ms) | 0.041 / 0.085 | 0.071 / 0.153 | 0.122 / 0.228 |
| Signing (ms) | 0.091 / 0.196 | 0.147 / 0.373 | 0.212 / 0.520 |
| Verification (ms) | 0.037 / 0.034 | 0.064 / 0.046 | 0.113 / 0.065 |

At the ML-DSA-44 level QChain uses, a complete key-generation, signing and verification cycle takes 0.167 ms with liboqs-go against 0.321 ms with CIRCL; liboqs-go signs about twice as fast and shares its library with the wallet, which justifies its selection. These results are preliminary; the KPI benchmarking described in Chapter 13 will measure end-to-end latency, throughput, ledger growth and wallet-side costs.

---

## 10. Quality Alignment and Validation

| Quality attribute | Status | Remarks |
| --- | --- | --- |
| Data access and privacy | Meets | Holder-held keys; no attribute values on the ledger |
| Data quality | Meets | Invalid writes fail endorsement |
| Algorithm transparency | Meets | Algorithms recorded in the envelope and commitment version |
| System security | Partially meets | Identity-layer migration and authenticated sessions pending |
| Functionality | Meets | 123/123 end-to-end assertions over all 39 endpoints |
| Reliability | Partially meets | Single host; backups and redundancy planned |
| Maintainability | Meets | Domain-organised modules; 101 unit tests; automated deployment |
| Usability | Not yet evaluated | User testing scheduled for Weeks 10–12 |
| Efficiency | Partially meets | Preliminary benchmarks; full KPI campaign Weeks 6–9 |
| Stakeholder engagement | Meets | Regular supervisor meetings |
| Artefact quality assurance | Meets | Code review through pull requests; CI gate |
| Project deliverables | Meets | Progress Report 1 delivered on schedule |
| Resources | Meets | Single host is a resource risk (Chapter 11) |

---

## 11. Challenges, Risks and Corrective Actions

| Challenge | Impact | Corrective action |
| --- | --- | --- |
| An unplanned host restart stopped the ledger containers, with no automatic recovery | Ledger and API unavailable until restarted manually | A systemd service now starts the Fabric services in dependency order on every boot |
| A redesign of the credential record (signed commitments, no plaintext on the ledger) was incompatible with existing ledger data | The channel ledger had to be re-initialised | Documented step-by-step procedure with backups, verified by the end-to-end suite |
| The wallet's post-quantum library uses native bindings that cannot be compiled for the web | The web build of the wallet failed | Wallet delivered as a native mobile application only, justified by the one-key-pair-per-holder model |
| A caller-supplied holder identifier could overwrite an existing holder record | Risk of silent data corruption | Server-generated identifiers only, with regression tests |

**Identified risks for the remainder of the semester:** migrating Fabric's MSP and BCCSP to ML-DSA may require deeper changes than anticipated (staged plan: a single-organisation proof of concept first); FN-DSA (FIPS 206) remains a draft (ML-DSA-44 is the primary algorithm regardless); the single-host deployment is a reliability risk (automatic recovery and rollback are in place; backups and replication are future work).

---

## 12. Planned vs Actual Progress

All activities scheduled to finish by Week 5 were completed on time, three of them added during the period in response to events (the ledger auto-recovery, ledger re-initialisation, and the CI/CD pipeline). The identity-layer research is in progress and on schedule.

| Activity | Status | Evidence |
| --- | --- | --- |
| Requirements, design review and security analysis | Completed | Supervisor meetings; design documents |
| Literature review update | Completed | Chapter 2 |
| Holder ML-KEM-768 envelope encryption | Completed | Commit history, `offchain/` |
| On-device keys and presentation signing (QWallet) | Completed | Commit history, `UI_App/` |
| Signed ledger commitments and salted disclosure | Completed | Commit history, `qchain-network/chaincode/` |
| Security review and fixes | Completed | §7.6 |
| Ledger service auto-recovery and re-initialisation | Completed (added) | systemd unit; deployment procedure |
| End-to-end API test suite | Completed | 123/123 |
| CI/CD pipeline with automatic rollback | Completed (added) | GitHub Actions workflows |
| Progress Report 1 | Completed | This report |
| MSP / BCCSP research and scoping | In progress | Research notes |

---

## 13. Next Steps and Updated Plan

For the remainder of the semester, the team will run a systematic KPI benchmarking campaign of the post-quantum operations — end-to-end latency broken down into cryptography/IPFS/endorsement/ordering, throughput under load, ledger and IPFS storage growth, wallet-side timings, and a comparison of ML-DSA-44 against ML-DSA-65/87 and ML-KEM-768 against ML-KEM-1024.

The migration of Fabric's network identities to ML-DSA, without a classical fallback, proceeds in stages: research and scoping; a single-organisation proof of concept; issuance of ML-DSA certificates (using the RFC 9881 identifiers) and reconstruction of the network on them; and a functional and performance evaluation against the ECDSA baseline.

```
TASK                                       WEEK  1  2  3  4  5  6  7  8  9 10 11 12 13 14
Requirements, design & security review      ████
Literature review                            ████
Post-quantum security mechanisms                ██████
Deployment hardening, testing, PR1                  █████
KPI benchmarking                                        ███████████
MSP research & single-org proof of concept              ████████
ML-DSA certificates & network rebuild                           ██████
Progress Report 2                                              ██
UI/UX refinement & user testing                                     ████████
Security testing & hardening                                        ██████████
Final report                                                             █████
Poster, demo & presentation                                                   ██
```

**Key milestone:** post-quantum MSP identities and a completed KPI benchmark report before Progress Report 2.

---

## Bibliography

1. C. Gidney (2025). How to factor 2048 bit RSA integers with less than a million noisy qubits. arXiv preprint arXiv:2505.15917.
2. Google Quantum AI and Collaborators (2025). Quantum error correction below the surface code threshold. *Nature*, vol. 638, no. 8052, pp. 920–926.
3. M. Mosca and M. Piani (2026). Quantum Threat Timeline Report 2025. Global Risk Institute, Toronto.
4. National Institute of Standards and Technology (2024). Module-Lattice-Based Digital Signature Standard (FIPS 204). U.S. Department of Commerce.
5. National Institute of Standards and Technology (2024). Module-Lattice-Based Key-Encapsulation Mechanism Standard (FIPS 203). U.S. Department of Commerce.
6. European Data Protection Board (2026). Guidelines 02/2025 on processing of personal data through blockchain technologies, Version 2.0. EDPB, Brussels.
7. World Wide Web Consortium (2025). Verifiable Credentials Data Model v2.0. https://www.w3.org/TR/vc-data-model-2.0/
8. D. Fett, K. Yasuda and B. Campbell (2025). Selective Disclosure for JSON Web Tokens (RFC 9901). Internet Engineering Task Force (IETF).
9. A. Holcomb, G. Pereira, B. Das and M. Mosca (2021). PQFabric: A Permissioned Blockchain Secure from Both Classical and Quantum Attacks. 2021 IEEE International Conference on Blockchain and Cryptocurrency (ICBC), Sydney, Australia.
10. V. K. Kasula, S. B. Rakki and R. Banoth (2025). Enhancing Hyperledger Fabric Security with Lightweight Post-Quantum Cryptography and National Cryptographic Algorithms. 2025 37th Conference of Open Innovations Association (FRUCT), Narvik, Norway.
11. Hyperledger Foundation (2024). What's new in Hyperledger Fabric v3.0. https://hyperledger-fabric.readthedocs.io/en/release-3.0/whatsnew.html
12. J. Massimo, P. Kampanakis, S. Turner and B. Westerbaan (2025). Internet X.509 Public Key Infrastructure — Algorithm Identifiers for the Module-Lattice-Based Digital Signature Algorithm (ML-DSA) (RFC 9881). IETF.
13. The Go Authors (2026). Go 1.27 Release Notes. https://go.dev/doc/go1.27
14. QChain Team (2026). QChain-PQC-blockchain: source code repository. https://github.com/teamqchain/QChain-PQC-blockchain

---

**Last Updated:** 27th September 2026
