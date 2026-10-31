# QChain — Progress Report 2

**Project:** Post Quantum Cryptography in Blockchain Technology  
**Submitted:** 31st October 2026  
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

Digital credentials such as university degrees, professional licences and government-issued certificates are issued and verified electronically, and their trustworthiness rests on public-key cryptography. RSA and elliptic-curve cryptography can be broken by a cryptographically relevant quantum computer, which the most recent expert survey considers 28–49 % likely to exist within ten years [1]. A credential remains valid for decades and a blockchain cannot forget what it stores, so a credential platform has to adopt post-quantum cryptography before such a machine exists.

QChain is a post-quantum digital credential platform for academic and government credentials in the United Arab Emirates, built on a permissioned Hyperledger Fabric network. Issuers sign every credential with **ML-DSA-44** [2], the credential contents are encrypted to the holder with **ML-KEM-768** [3], and holders sign their own selective-disclosure presentations. Post-quantum algorithms have larger keys and signatures than the algorithms they replace, their running time varies more, and a credential uses several of them at once, so whether the design remains practical has to be **measured rather than assumed**.

This report presents the progress made from Week 6 to Week 10 of the Fall 2026 semester (28 September to 1 November 2026), which was devoted to a systematic key-performance-indicator (KPI) benchmarking study of QChain's post-quantum cryptography. All results come from the first of three test platforms, an Apple M1 laptop.

### 1.1 Project Scope

This report covers:

1. A **literature review** of 43 publications on the performance of post-quantum cryptography (Chapter 2)
2. The **design of the KPI study**: six research questions, 30 algorithms, 15 experiments, the statistics and the run-quality rules (Chapter 6)
3. An **independent measurement harness** that measures QChain's own production code without touching the live system (Chapter 6)
4. The **execution of all 15 experiments** on the first test platform in 115 hours of measurement runs, and the analysis of their preliminary results (Chapter 7)
5. A summary of the platform's **architecture and QPortal user interface**, both unchanged in this period (Chapters 4 and 5)

Three activities continue after this report and are described as planned work in Chapter 11: the next measurement phase on a virtualised x86 server and an x86 laptop with AVX2 instructions; the cross-platform analysis and a research paper; and the migration of the Fabric network identities to ML-DSA, whose single-organisation proof of concept is in progress.

### 1.2 Project Objectives

The project's objectives for the semester are unchanged. This report addresses the evaluation of performance, which the KPI study divides into six measurable objectives:

1. **Primitive cost** — measure the time, size and memory of every final and selected NIST post-quantum algorithm, against classical baselines
2. **Lifecycle cost** — measure the cost of QChain's complete encrypted credential lifecycle (wallet activation, issuance, retrieval, presentation and verification) for 16 curated algorithm suites and for all 176 signature–KEM pairs
3. **Integration overhead** — quantify what QChain's integration pattern (Go bindings, a new library object per call, hexadecimal encoding) adds to the C library
4. **Sensitivity** — determine how the results change with the library build and with the runtime (container or native operating system)
5. **Storage and ledger latency** — quantify the bytes each credential adds to the ledger and to IPFS, and whether post-quantum payload sizes change Fabric transaction latency
6. **Issuer–holder equivalence** — test, rather than assume, that issuer-side and holder-side ML-DSA signing cost the same

### 1.3 Expected Outcomes

| Objective | Expected outcome | Status at Week 10 |
| --- | --- | --- |
| 1. Primitive cost | Latency distributions, sizes and memory of 30 algorithms | Measured on the first platform; further platforms in progress |
| 2. Lifecycle cost | Per-stage cost for 16 suites; all 176 signature–KEM pairs | Measured on the first platform (991 settings) |
| 3. Integration overhead | Cost of every integration layer and component | Measured on the first platform |
| 4. Sensitivity | Effect of the library build and of native execution | Two builds and native execution measured; further platforms in progress |
| 5. Storage and ledger latency | Bytes per credential on the ledger and IPFS; latency against payload size | Measured: byte-exact ledger model; Fabric network rebuilt on the test platform |
| 6. Issuer–holder equivalence | Statistical equivalence test of the two signing roles | Equivalent within the pre-set margins of about 2 % (first platform) |

---

## 2. Literature Review

This chapter reviews the literature on the performance of post-quantum cryptography that informs the KPI study. It concentrates on measurements: what the post-quantum primitives cost, what they do to blockchains and credential systems, and how carefully they have been measured.

### 2.1 Scope and Search Method

The search was carried out on 4 and 5 October 2026. IEEE Xplore returned 87 records. The ACM Digital Library and Scopus could not be reached through the university's sign-on service, so the OpenAlex index (which covers ACM, Springer and Elsevier publications) was used in their place and 219 records were screened. arXiv and the publishers' pages were searched for the works found. Works were included when they report measurements of post-quantum algorithms, blockchains or credential systems, or address how such measurements should be made; **43 publications were read**.

NIST published ML-KEM (FIPS 203), ML-DSA (FIPS 204) and SLH-DSA (FIPS 205) as final standards in August 2024 [3] [2] [4]. Falcon is being standardised as FN-DSA (FIPS 206), still in preparation during the study [5], and HQC was selected in March 2025 as an additional key-encapsulation mechanism (KEM) [6]. The study covers the three final standards and the two selected schemes, with classical baselines.

### 2.2 Benchmarks of Post-Quantum Primitives

Most performance studies time the primitives in isolation. Commey et al. benchmarked KEMs and signatures on a desktop, a laptop and a Raspberry Pi 4 using liboqs 0.8.0 through Python [7]; Algar-Fernandez et al. compared five signature schemes and three KEMs on two Windows 11 laptops with ten repetitions per operation [8]; Lucaciu and Popescu compared C, Go and Python on an x86 workstation and an ESP32, the Go code using a different library from the C code [9]; and Oleksiichuk compared ML-KEM, ML-DSA and SLH-DSA across Java versions and libraries [10]. Earlier comparisons [11] [12] reach the same ranking: the lattice schemes are fast, Falcon verifies quickly and SLH-DSA signs slowly.

A second group studies platforms and protocols. Chhetri et al. measured ML-KEM and ML-DSA on an ARM Cortex-M0+ and reported coefficients of variation of **66–74 %** for ML-DSA signing, caused by rejection sampling, together with 99th percentiles [13]. Puch et al. found the container overhead negligible for the primitives on embedded ARM hardware [14]; Gillot et al. measured energy [15]; Lopez et al. evaluated BIKE, Kyber and HQC [16]; and post-quantum TLS has been evaluated in 5G [17] [18], 6G [19] and with the Open Quantum Safe provider [20]. In liboqs 0.16.0, the release used in this study, ML-KEM and ML-DSA come from the mlkem-native and mldsa-native code bases [21] [22], so results obtained with older releases describe different code.

### 2.3 Post-Quantum Signatures in Blockchains and Ledgers

Studies of post-quantum blockchains concentrate on signatures, because every transaction is signed. Schemitt et al. benchmarked 62 signature implementations on x64 and ARM and simulated their effect on a blockchain [23]; Juaristi et al. estimated the cost of integrating the NIST signatures into Ethereum-based blockchains [24]; Holmes examined block sizes and intervals [25]; Saviozzi et al. integrated ML-DSA into a Substrate-based chain [26]. Thanalakshmi et al. stored hashes of signatures and public keys on chain and their contents in IPFS [27], the principle QChain applies to whole credentials.

On Hyperledger Fabric, PQFabric redesigned the membership service around **hybrid** classical + post-quantum signatures [28], and Abbas et al. issue hybrid X.509 certificates, measured with Caliper [29]; QChain's identity-layer migration is **purely post-quantum**, with no classical fallback. The closest study is Ouadrassi et al., who signed documents with ML-DSA-65 alongside ECDSA in an external Python service, stored the signature and public key on Fabric 2.5.13, saw no significant transaction degradation and found blocks about **1.43 times larger** [30]. QChain already stores credentials off chain behind signed commitments, and this study quantifies the effect of compact encoding. Earlier Fabric studies used classical cryptography [31] or simulated a post-quantum healthcare system [32].

### 2.4 Verifiable Credentials, Identity and Encrypted Storage

The closest prior work on credentials is Arakawa's evaluation of 15 signature schemes in SD-JWT credentials through liboqs-rust 0.11.0 on one AWS instance (20 warm-up, 1,000 measured iterations; medians, CV and sizes) [33]. It did not include key encapsulation or encryption of the credential, memory, tail latency, concurrency or a ledger. Wood et al. recommended next steps for the transition of verifiable-credential schemes [34]. Other identity work concentrates on functionality: post-quantum anonymous credentials [35], hybrid credentials for IoT [36], self-sovereign identity in IOTA [37], and the cost of the transition for an academic identity federation [38]. The application-layer design closest to QChain's is PQ-FundusChain: AES-256-GCM under ML-KEM, ML-DSA-authenticated transactions, images off chain and about 4.83 KB per image on the ledger [39]; similar combinations appear in [40] and [41].

### 2.5 Integration Cost and Measurement Method

How a library is called can matter as much as the algorithm. Kotukh et al. measured a foreign-function overhead below 10 ns per call for OCaml bindings and stated, without measuring it, that Go's boundary to C costs about 50 ns [42]; Algar-Fernandez et al. showed that the integration route changes the measured times [8]. What a deployed application adds on top of the library, such as a new library object per call or text-encoded keys, has not been measured.

Measurement practice also varies. Most studies report means or medians of 10 to 10,000 repetitions on one machine. Chhetri et al. reported tail percentiles [13]; Shaw pinned the processor and reported bootstrapped 95 % confidence intervals, observing 51.5 % CV for ML-DSA-65 signing [43]; Frost proposed a reproducibility protocol with ACVP test vectors [44]. This study adds per-measurement quality control: the state of the machine is recorded during every measurement and disturbed measurements are repeated (Chapter 6).

### 2.6 Research Gap and Contribution

The literature measures the primitives well and their effect on blockchains in part, but **no study measures what post-quantum cryptography costs across the complete lifecycle of an encrypted, selectively disclosable credential, through the code of a deployed system, with the ledger and storage consequences included.** The claims this study makes against that gap, and where the evidence is:

| Claim | What is new | Evidence |
| --- | --- | --- |
| 1. Encrypted lifecycle cost model | Envelope encryption, issuer and holder signatures and selective disclosure costed together, through QChain's own code, for 16 security-matched suites and all 176 signature–KEM pairs | Section 7.3 |
| 2. Complete NIST set on current liboqs | Every FIPS 203, 204 and 205 parameter set plus Falcon and HQC on liboqs 0.16.0, with five classical baselines | Section 7.2 |
| 3. Cross-platform comparison | One software stack on ARM, on x86 with AVX2 and on a virtualised x86 server without AVX2, plus native execution | Section 7.9 (first platform); other platforms in progress |
| 4. Distributions, tails and memory | Full latency distributions with 99th percentiles; stack, C heap, Go heap and process memory | Sections 7.2 and 7.6 |
| 5. Cost of the integration pattern | C library, Go binding, re-initialisation and production pattern, component by component | Section 7.4 |
| 6. Ledger and IPFS footprint | A byte-exact model of Fabric transactions and IPFS objects for 22 signature schemes, checked on a rebuilt Fabric network | Sections 7.10 and 7.11 |
| 7. Issuer–holder equivalence | Tested statistically instead of assumed | Section 7.7 |
| 8. Cost of aligning security levels | Production suite (ML-DSA-44 with ML-KEM-768) against level-matched suites | Section 7.3 |

**Summary of the most relevant works**

| Ref. | Paper | Year | Publisher | Key insights | Limitations |
| --- | --- | --- | --- | --- | --- |
| [33] | Post-Quantum Cryptography for Verifiable Credentials | 2025 | TechRxiv | 15 signature schemes in SD-JWT credentials; medians, CV and sizes; selective disclosure works with all schemes | No KEM or encryption, memory, tails, concurrency or ledger; one server; pre-standard SPHINCS+ |
| [30] | Toward Quantum-Safe Permissioned Blockchains | 2026 | IEEE | ML-DSA-65 with ECDSA on Fabric 2.5.13; no significant transaction slowdown; blocks 1.43× larger | Hybrid; mainly one algorithm; signing in an external Python service |
| [23] | Assessing the Impact of Post-Quantum Digital Signature Algorithms on Blockchains | 2025 | arXiv | 62 signature implementations on x64 and ARM; 10,000 runs; blockchain simulation | Signatures only; Python harness; no memory or tails |
| [7] | Performance Analysis and Deployment Considerations of PQC for Consumer Electronics | 2025 | arXiv | KEMs and signatures on three platforms, classical baselines | liboqs 0.8.0 through Python; memory only as indicators |
| [28] | PQFabric | 2021 | IEEE | Hybrid classical and post-quantum signatures in Fabric's membership service | Identity layer; hybrid, not purely post-quantum |
| [29] | Quantum-Safe Blockchain in Hyperledger Fabric | 2025 | IEEE | Hybrid X.509 certificates for Fabric; Caliper measurements | Identity layer; hybrid |
| [39] | PQ-FundusChain | 2026 | Frontiers | ML-KEM, AES-GCM and ML-DSA with off-chain images; 4.83 KB on chain per image | One application; no comparison of algorithm families |
| [27] | A Quantum-Resistant Blockchain System | 2023 | MDPI | Hashes of signatures and keys on chain, contents in IPFS | Signatures only; Bitcoin-style exchange |
| [38] | Measuring the Impact of PQC on Complex Applications | 2025 | IEEE | Post-quantum transition of a large academic identity federation | Not credential-centric; no lifecycle composites |
| [8] | Benchmarking Post-Quantum Signatures and KEMs on General-Purpose CPUs | 2026 | MDPI | Integration route changes the measured times | Python harness; ten repetitions; mostly non-standard schemes |
| [9] | Cross-Platform Performance and Security Evaluation of PQC | 2026 | MDPI | C, Go and Python on an x86 workstation and an ESP32 | Different library per language |
| [13] | Benchmarking ML-KEM and ML-DSA on ARM Cortex-M0+ | 2026 | arXiv | Rejection-sampling variance and tail percentiles of ML-DSA signing | Microcontroller; reference code only |
| [14] | Benchmarking PQC in Lightweight Virtualization Environments | 2026 | arXiv | Native, container and unikernel; container overhead negligible for primitives | Embedded ARM; primitives and TLS only |
| [42] | Type Safe OCaml Bindings for Open Quantum Safe | 2026 | IEEE | Foreign-function overhead below 10 ns per call | Raw binding cost only; Go cost asserted, not measured |
| [43] | quantum-safe: a Hybrid-by-Default Python Library | 2026 | arXiv | Pinned CPU, bootstrapped confidence intervals, coefficient of variation | Hybrid ML-KEM-768 + X25519 library; Python |
| [34] | Towards Post-Quantum Verifiable Credentials | 2024 | ACM | Quantum-safety analysis of credential schemes; transition recommendations | No measurements |

---

## 3. Problem Statement and Proposed Solution

### 3.1 The Quantum Threat to Digital Credential Systems

Digital credential systems face four quantum-era problems:

- **Forgery** — once ECDSA or RSA can be broken, an attacker can derive an issuer's private key from its public key and sign counterfeit credentials that verify correctly
- **Harvest now, decrypt later** — credential data encrypted with classical public-key schemes and stored on replicated infrastructure can be copied today and decrypted later, and on a blockchain the ciphertext can never be deleted
- **Identity compromise** — the X.509 identities that authorise peers, orderers and officials in a permissioned network are ECDSA-based
- **Privacy** — personal data stored in plaintext on an immutable, multi-organisation ledger exposes more than a verifier needs

### 3.2 The Performance Question

Replacing classical cryptography has a cost. An ML-DSA-44 signature takes 2,420 bytes and its public key 1,312 bytes, against about 71 and 65 bytes for ECDSA P-256. ML-DSA signing time varies from call to call because of rejection sampling, and the conservative alternatives are much slower: SLH-DSA signs in milliseconds to seconds, and HQC needs milliseconds per operation. A credential multiplies these costs: QChain's lifecycle performs a key encapsulation, two signatures, two signature verifications and dozens of hash and symmetric operations per credential, and the ledger stores the issuer's signature and public key in every credential record, permanently and on every peer. Whether a fully post-quantum credential platform is practical is a question about the whole system rather than about one primitive. The KPI study answers it for QChain.

### 3.3 Threat Model and Security Requirements

The design considers an external attacker who records traffic and ledger data today and obtains a quantum computer later; honest-but-curious operators of a peer, the IPFS node or the database; a verifier who tries to learn undisclosed attributes; a holder who tries to alter a disclosed value; and a participant who tries to tamper with ledger records.

| Property | Mechanism in QChain | Status |
| --- | --- | --- |
| Confidentiality | Per-field ML-KEM-768 / HKDF-SHA3-256 / AES-256-GCM envelopes on IPFS; private key only on the holder's device | Met |
| Integrity | Commitment recomputed from ledger fields; salted SHA3-256 field hashes; endorsed ledger writes | Met |
| Authenticity | ML-DSA-44 issuer signature checked against the trusted issuer key | Met |
| Non-repudiation | Holder ML-DSA-44 signature bound to one credential; issuer signature and history on the ledger | Met |
| Privacy | 128-bit per-field salts; undisclosed fields and their salts never leave the wallet | Met |
| Authentication | Role attributes on Fabric identities enforced by the chaincode; portal login planned | Partially met |
| Availability | Ordered automatic start of the ledger services; deployment health checks with rollback | Partially met (single host) |
| Quantum-safe identities | Migration of the network identities to ML-DSA (proof of concept in progress) | Planned |

### 3.4 Proposed Solution

QChain protects each step of the credential lifecycle with a NIST post-quantum standard:

```
WALLET ACTIVATION   holder's device generates an ML-KEM-768 and an ML-DSA-44 key pair;
                    only the public keys leave the device
        │
ISSUANCE            backend salts + hashes every attribute (SHA3-256)
                    → encrypts attributes and salts to the holder's ML-KEM-768 key
                    → stores the envelope on IPFS
                    → signs a canonical commitment (metadata, envelope CID, field hashes)
                      with the issuer's ML-DSA-44 key → ledger
        │
RETRIEVAL           only the wallet can decrypt the envelope
        │
PRESENTATION        holder signs the disclosed values, their salts and a timestamp
                    with ML-DSA-44
        │
VERIFICATION        backend checks existence, status, issuer signature over the
                    recomputed commitment, disclosed field hashes, holder signature
```

The KPI study (Chapter 6) measures each of these steps with the code that performs it.

### 3.5 Research Contribution

QChain is a fully post-quantum verifiable-credential architecture on a permissioned ledger:

- **C1 – Ledger-anchored post-quantum commitments:** the issuer's ML-DSA-44 signature covers a canonical commitment that verifiers recompute from ledger state
- **C2 – Holder-sovereign post-quantum confidentiality:** every attribute is sealed to an ML-KEM-768 key generated in the holder's device
- **C3 – Selective disclosure without zero-knowledge machinery:** 128-bit per-field salts travel only inside the holder-encrypted envelope
- **C4 – Post-quantum holder binding:** every presentation is signed with the holder's ML-DSA-44 key and bound to one credential
- **C5 – No plaintext credential data on the ledger:** on-chain personal data is limited to the holder's name and a pseudonymous identifier
- **C6 – A purely post-quantum identity layer (in progress):** the network identities migrate to ML-DSA without a classical fallback, in contrast to hybrid designs [28]
- **C7 – A measured cost model of the whole lifecycle:** the KPI study quantifies the cost of C1–C5 for 30 algorithms through QChain's own code

---

## 4. System Architecture

The architecture is unchanged in this period and is summarised as the system under test.

### 4.1 Architecture Overview

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
QCHAIN API — Go backend, 39 REST endpoints
 ├── Commitment & signing (ML-DSA-44 over SHA3-256)
 ├── Envelope sealing (ML-KEM-768 · HKDF-SHA3-256 · AES-256-GCM)
 ├── Verification engine (5 cryptographic checks)
 ├── Presentation sessions (QR / OTP)
 └── Lifecycle · holders · subscriptions · staff · audit
        │
        ├─────────────────────────────┬───────────────────────┐
        ▼                             ▼                       ▼
HYPERLEDGER FABRIC                  IPFS (Kubo)             MySQL 8
 ├── GovernmentMSP peer ──┐          Encrypted envelopes    Operational data:
 ├── GeneralMSP peer ─────┴─ ONE     (content-addressed)     sessions, verification
 │    shared CouchDB state database                          logs, subscriptions, staff
 ├── Raft (etcdraft) orderer
 ├── 3 Fabric CAs
 └── QChaincode (JavaScript): role-checked writes, validated inputs, batch reads
```

QPortal serves issuer, verifier and IT-administrator staff; QWallet serves holders and is native by design: each holder has exactly one ML-KEM-768 and one ML-DSA-44 key pair, held in the device's secure storage, and its post-quantum library is reached through native bindings that cannot run in a browser.

### 4.2 Cryptographic Library Stack

The backend and the wallet use the same Open Quantum Safe implementation of ML-DSA-44 and ML-KEM-768, so signatures and envelopes produced on one side are accepted on the other. The production backend builds liboqs from its development branch with a minimal set of algorithms, while the KPI study pins the 0.16.0 release with all 25 post-quantum algorithms; this difference is recorded in the study's limitations.

| Primitive | Standard | Backend (Go) | Wallet (Dart) | Used for |
| --- | --- | --- | --- | --- |
| ML-DSA-44 | FIPS 204 | liboqs-go | liboqs (FFI) | Issuer commitment signatures; holder presentation signatures |
| ML-KEM-768 | FIPS 203 | liboqs-go | liboqs (FFI) | Envelope key encapsulation to the holder |
| SHA3-256 | FIPS 202 | x/crypto/sha3 | pointycastle | Commitment hash, salted field hashes, presentation hash |
| HKDF-SHA3-256 | RFC 5869 | x/crypto/hkdf | pointycastle | Per-field key-wrapping keys |
| AES-256-GCM | SP 800-38D | crypto/aes, crypto/cipher | pointycastle | Field encryption and data-key wrapping |
| ECDSA P-256 | FIPS 186-5 | Fabric CA / MSP | — | Network certificates (migration to ML-DSA in progress) |

### 4.3 Fabric Network and Chaincode

The permissioned network has two peer organisations and an ordering organisation, each with its own certificate authority. Both peers must endorse every credential transaction, and **the two peers keep their world state in one CouchDB database that they share**. The chaincode checks the caller's role, validates every input and stores the records, but performs no post-quantum cryptography itself: signatures are created and verified in the backend and the wallet, so the ledger's cost depends on the algorithms only through the sizes it stores.

| Component | Configuration |
| --- | --- |
| Organisations | GovernmentMSP and GeneralMSP (peer organisations) and an orderer organisation |
| Peers and state database | peer0.government.uae.com and peer0.general.uae.com, both using one shared CouchDB state database |
| Ordering service | Raft orderer; a block closes after 2 s, at 10 transactions or at 512 KB, whichever comes first |
| Certificate authorities | GovernmentCA, GeneralCA and OrdererCA |
| Channel and chaincode | mychannel; qchaincode (JavaScript) with endorsement by both peer organisations |
| Chaincode transactions | registerHolder, bindHolderKeys, issueCredential, updateExpiry, suspend, restore and revoke; typed and batch reads |
| Application identities | issuer1 and verifier1, enrolled with a role attribute in their certificates |

### 4.4 Data Placement and Sources of Truth

The ledger and IPFS are the authoritative sources of all credential data; the operational database holds no authoritative credential data.

| Data item | Authoritative store | Protection |
| --- | --- | --- |
| Credential attribute values and per-field salts | IPFS (encrypted envelope) | ML-KEM-768 + AES-256-GCM |
| Salted field hashes, commitment hash, issuer signature and public key | Ledger | SHA3-256 with 128-bit salts; ML-DSA-44 |
| Credential metadata and status | Ledger | Endorsed writes; covered by the signed commitment |
| Holder name, identifier and public keys | Ledger | Role-checked registration; exact-length key validation |
| Holder private keys | Holder's device only | Platform secure storage |
| Sessions, logs, subscriptions, staff, contact data | MySQL | Database access control |
| Issuer ML-DSA-44 private key | Backend host configuration | Host access control |

### 4.5 Deployment Architecture

```
Internet ──HTTPS──▶ secure tunnel ──▶ Nginx gateway ──▶ QPortal (static)
                                          │
                                          └─ /api ──▶ QChain API (Go, container)
                                                         ├─▶ Fabric Gateway ──▶ peers + orderer + shared CouchDB
                                                         ├─▶ IPFS node (Kubo, systemd user service)
                                                         └─▶ MySQL

University-hosted Ubuntu VM
 ├─ systemd service: starts the CAs, then the orderer, the shared CouchDB and the peers on every boot
 └─ self-hosted GitHub Actions runner: deploys with health checks and automatic rollback
```

During the KPI study the live system was never used for measurements: the harness copies the production code and, for the Fabric experiment, rebuilds the network on the test platform.

---

## 5. UI/UX Design

QPortal is the web interface through which issuing and verifying organisations use QChain. Its design is unchanged in this period; the screens are documented in the team's design records [45]. The interface gives each role its own workspace and keeps the cryptography behind plain actions: issuing, checking and revoking credentials. The Word report shows all 20 screenshots; this table lists the screens.

### 5.1 Issuer Dashboard

| Screen | What it does |
| --- | --- |
| Issuer dashboard [46] | Credentials issued today, unread alerts and upcoming expiries, recent activity and a four-week chart; quick actions for single issuance, batch issuance and schema management |
| Single issuance (5 steps) | Choose the template → find the recipient in the holder directory → enter the attributes the template defines → visual draft → summary and explicit confirmation before the credential is signed with the issuer's ML-DSA-44 key |
| Batch issuance | Up to 1,000 recipients from a filled-in template; a validation table lets only valid records proceed to signing; a final report lists successes and rejections |
| All credentials | Every credential of the organisation with holder, dates and status (valid, revoked, suspended, expired); search, filters, bulk export |
| Credential details | System and holder information, editable contact e-mail and expiry date, and an expandable cryptographic section: signature algorithm ML-DSA-44 (standardised from CRYSTALS-Dilithium), signature hash, ledger transaction and IPFS reference |
| Credential history | Timeline of issuance, suspension, restoration and revocation with the responsible staff member and the reason |
| Revocation and suspension | Revoke permanently, suspend temporarily, restore; each action is recorded on the ledger |
| Credential schemas | Templates that define the credential types; outdated schemas can be archived, a schema can be deleted only if never used |

### 5.2 Verifier Dashboard

| Screen | What it does |
| --- | --- |
| Verifier dashboard [47] | Verifications today, pending alerts, recent results (valid, revoked, expired); quick actions to scan a QR code, verify manually or process a batch |
| QR scan result | Valid credential with the holder's details and the outcome of the policy checks (ledger integrity, issuer authorisation) |
| Failed scan | The scanner reports the failure and invites a retry |
| Manual verification by identifier | With on-screen guidance for the holder to find it in the wallet |
| Manual verification by one-time password | The holder generates a six-digit password in the wallet and the verifier enters it |
| Tampered credential | Every method ends in the same result card; data that no longer matches its ledger record is flagged as tampered and must not be accepted |
| Batch verification | Up to 500 credentials from one file; a validation table to correct or remove incomplete rows |
| Verification history | Every check with date, holder, method, staff member and result; export for audits |
| Subscriptions and alerts | An organisation follows a credential's status after the holder approves the request; suspensions, revocations and reissues appear as alerts that move to an archive when acknowledged |

---

## 6. Benchmarking Methodology and Harness

The KPI study measures QChain's post-quantum cryptography in the way the platform uses it.

### 6.1 Research Questions

| No. | Research question | Experiments |
| --- | --- | --- |
| RQ1 | What do the primitives cost (latency distribution, size, memory) for every final and selected NIST post-quantum algorithm, compared with classical baselines? | E1, E6, E7, E8, E9 |
| RQ2 | What does a complete encrypted credential lifecycle cost for each algorithm suite and number of attributes? | E11, E12 |
| RQ3 | How much does QChain's integration pattern add to the C library? | E2, E3 |
| RQ4 | How sensitive are the results to the hardware, the runtime and the library build? | E4, E5; next measurement phase |
| RQ5 | What are the storage consequences on the ledger and IPFS, and does payload size change Fabric latency? | E13, E14 |
| RQ6 | Are issuer-side and holder-side ML-DSA signing equivalent? | E10 |

### 6.2 Algorithms Under Test

30 algorithms: every final NIST standard parameter set, the two schemes selected for standardisation, and five classical baselines. The 25 post-quantum algorithms come from liboqs 0.16.0 [22], called from Go through its binding; the five classical algorithms come from OpenSSL 3.0 and cross the same Go-to-C boundary. The two classical KEMs implement DHKEM as specified in RFC 9180 and reproduce its eight published test vectors [48]. Pre-hash SLH-DSA variants, stateful hash-based signatures, the superseded Kyber, Dilithium and SPHINCS+ and the schemes NIST did not select are excluded.

| Group | Algorithms | Count |
| --- | --- | --- |
| Signatures: final standards | ML-DSA-44, -65, -87 (FIPS 204); SLH-DSA with SHA2 and with SHAKE at 128, 192 and 256 bits, small (s) and fast (f) variants: 12 sets (FIPS 205) | 15 |
| Signatures: selected | Falcon-512, Falcon-1024 and their padded variants (2021 specification, not yet FN-DSA) | 4 |
| Signatures: classical | ECDSA P-256, Ed25519, RSA-3072 (PSS) | 3 |
| KEMs: final standard | ML-KEM-512, -768, -1024 (FIPS 203) | 3 |
| KEMs: selected | HQC-1, HQC-3, HQC-5 (reference implementation) | 3 |
| KEMs: classical | DHKEM(X25519), DHKEM(P-256) | 2 |

### 6.3 Test Platform

All results in this report come from the first of three test platforms. The benchmark ran in a container, as on the other platforms, so that the operating system inside is the same everywhere; a separate experiment (E5) ran the same measurements natively on macOS.

| Item | Configuration |
| --- | --- |
| Machine | Apple MacBook Air (M1, 2020): 4 performance and 4 efficiency cores, 8 GB memory, fanless; on mains power and a USB cooling pad |
| Operating system | macOS 27.0.1, not updated during the study |
| Container runtime | Colima with Apple's virtualisation framework: a Linux virtual machine (kernel 6.8) with 4 CPUs and 4 GiB |
| Container | Pinned to one CPU, no CPU-time quota, 3 GB memory without swap, no network |
| Software | Go 1.24.13 (the production version), liboqs 0.16.0 with liboqs-go 0.16.0, OpenSSL 3.0.22, gcc 12.2, glibc 2.36 |
| Timer | Monotonic clock: effective resolution 41 ns, cost of one reading about 41 ns |

**The results describe this machine and this harness.** The Mac is a fanless laptop, its containers run inside a Linux virtual machine, its processor uses the ARM NEON instruction set, and macOS cannot pin a process to a core type. The absolute numbers are therefore not a statement about QChain's production server; comparisons between algorithms measured under the same conditions, ratios and sizes transfer better than absolute times.

### 6.4 Measurement Harness

The harness is an independent code base that never touches the live system:

```
MAC (host)                                             CONTAINER (Linux VM, 1 CPU, no network)
┌──────────────────────────────────┐                  ┌────────────────────────────────────────┐
│ LAUNCHER                         │                  │ ORCHESTRATOR                           │
│  · pre-run checks: refuses on    │   start run      │  · runs blocks in a seeded, shuffled   │
│    battery, other apps open,     │ ───────────────▶ │    order, each in a FRESH process      │
│    auto-updates, background load │                  │  · decides after every block whether   │
│  · pauses background services,   │                  │    the measurement is valid            │
│    Wi-Fi off, keeps Mac awake    │                  │  · canary benchmark (SHA3-256) at      │
│  · after the run: copies results │   results        │    start, every 10 min, at end         │
│    out, verifies checksums,      │ ◀─────────────── │                                        │
│    privacy scan of every file    │                  │ CODE UNDER TEST: verbatim copies of    │
└──────────────────────────────────┘                  │ QChain's production functions          │
                                                      └────────────────────────────────────────┘
```

To measure QChain itself rather than an approximation, the harness contains **verbatim copies of the backend's production functions** (envelope sealing, commitment, signing, verification) and of the wallet's decryption, taken from one commit of the project repository and checked against it by a script, with only the algorithm name made selectable. QChain creates and destroys a liboqs signature object on every call and exchanges keys and signatures as hexadecimal text; experiment E2 isolates the cost of this pattern.

*QChain's production signing and verification functions, copied verbatim into the harness:*

```go
// sigName is the post-quantum signature algorithm used everywhere in this server.
const sigName = "ML-DSA-44"

// pqcSign signs `message` with the provided hex-encoded private key and returns
// a hex-encoded signature.
func pqcSign(message, privateKeyHex string) (string, error) {
	privKeyBytes, err := hex.DecodeString(privateKeyHex)
	if err != nil {
		return "", fmt.Errorf("decoding private key hex: %w", err)
	}
	signer := oqs.Signature{}
	// defer runs Clean() when this function returns, freeing the C-side memory
	// liboqs allocated — no matter which return path we take.
	defer signer.Clean()
	if err := signer.Init(sigName, privKeyBytes); err != nil {
		return "", fmt.Errorf("init PQC signer with key: %w", err)
	}
	sig, err := signer.Sign([]byte(message))
	if err != nil {
		return "", fmt.Errorf("signing: %w", err)
	}
	return hex.EncodeToString(sig), nil
}

// pqcVerify verifies a hex-encoded signature against a message and hex-encoded
// public key. Verification needs no private key, so Init is called with nil.
func pqcVerify(message, signatureHex, publicKeyHex string) (bool, error) {
	pubKeyBytes, err := hex.DecodeString(publicKeyHex)
	if err != nil {
		return false, fmt.Errorf("decoding public key hex: %w", err)
	}
	sigBytes, err := hex.DecodeString(signatureHex)
	if err != nil {
		return false, fmt.Errorf("decoding signature hex: %w", err)
	}
	verifier := oqs.Signature{}
	defer verifier.Clean()
	if err := verifier.Init(sigName, nil); err != nil {
		return false, fmt.Errorf("init PQC verifier: %w", err)
	}
	valid, err := verifier.Verify([]byte(message), sigBytes, pubKeyBytes)
	if err != nil {
		return false, fmt.Errorf("verify: %w", err)
	}
	return valid, nil
}
```

### 6.5 Experiments

E1 to E10 measure the primitives and their integration, E11 and E12 the credential lifecycle, and E13 and E14 the ledger.

| ID | Experiment | What is measured | Scope |
| --- | --- | --- | --- |
| E0 | Environment | Processor, kernel, timer, versions, library build; correctness gates | Every run |
| E1 | Primitive latency | Key generation, signing and verification, encapsulation and decapsulation | 30 algorithms |
| E2 | Integration cost | Library object reused, re-initialised per call, QChain's production pattern; its components | 30 algorithms |
| E3 | Integration layers | C timed in C, C timed from Go, Go binding; Go standard library for the classical schemes | 30 algorithms |
| E4 | Build sensitivity | Portable and natively tuned liboqs builds against the production-like build | E1's 90 cells |
| E5 | Native execution | E1's cells natively on macOS, outside the container | E1's 90 cells |
| E6 | Message size | Signing and verification of messages from 64 B to 1 MiB | 22 signature schemes |
| E7 | Rejection timing | Corrupted signatures, wrong messages and tampered ciphertexts against valid inputs | 30 algorithms |
| E8 | Sizes | Keys, signatures, ciphertexts and their length distributions | 30 algorithms |
| E9 | Memory | Stack depth, C heap, Go heap and process memory per operation | 30 algorithms, 3 routes |
| E10 | Issuer–holder equivalence | Issuer and holder signing interleaved in one process | ML-DSA-44, -65, -87 |
| E11 | Lifecycle cost | Activation, issuance, retrieval, presentation and verification through QChain's code | 16 suites at 5 attribute counts; 176 pairs; 991 settings |
| E12 | Concurrency | Throughput and latency with 1, 2 and 4 concurrent workers | 4 suites, 2 stages |
| E13 | Ledger and IPFS bytes | Transaction, block and IPFS sizes from a model calibrated on the live ledger | 22 schemes, 8 KEMs |
| E14 | Fabric latency | Commit latency against payload size on QChain's network rebuilt on the test platform | 9 payloads, 2 modes, 6,360 transactions |

### 6.6 Sampling and Statistics

Every measurement block is one fresh process for one experiment, algorithm, operation and repetition. Its inputs are prepared beforehand by a separate, untimed process, and each of the five repetitions uses its own keys, so the spread between repetitions includes key-to-key variation. Fast operations (median below 1 ms) receive 1,000 untimed warm-up calls and 10,000 timed samples; slow operations are sampled until at least 60 seconds and 30 samples have been collected; lifecycle stages use 2,000 samples or the slow rule. **Every timed sample is stored, outliers are never removed, and every output is checked for correctness outside the timed region.** Garbage collection is switched off inside the timed loops of the primitive experiments and runs normally in the lifecycle and concurrency experiments, as in production. The result of a cell is the median, over its five repetitions, of the per-repetition medians.

*The harness's sampling loop (excerpt): interleaved arms, a correctness check of every sample, and the fast and slow stopping rules:*

```go
for remaining > 0 {
	for _, k := range rng.Perm(len(arms)) {
		if done[k] {
			continue
		}
		a := arms[k]
		b := batchOf(a)
		i := idx[k]
		var nb int
		var err error
		var d int64
		if a.Timed != nil {
			// …
		} else {
			t0 := time.Now()
			for j := 0; j < b; j++ {
				if nb, err = a.Call(i + j); err != nil {
					break
				}
			}
			d = time.Since(t0).Nanoseconds()
		}
		// …
		if a.Check != nil {
			if err := a.Check(i+b-1, nb); err != nil {
				return res, fmt.Errorf("%w: arm %s sample: %v", ErrCheck, a.Name, err)
			}
		}
		idx[k] += b
		r := &res.Arms[k]
		r.PerOpNS = append(r.PerOpNS, float64(d)/float64(b))
		r.SumNS += d
		// …
		n := len(r.PerOpNS)
		switch cfg.Mode {
		case Fast:
			done[k] = n >= cfg.Samples
		case Slow:
			done[k] = r.SumNS >= cfg.TimeBox.Nanoseconds() && n >= cfg.MinSamples
		}
```

### 6.7 Run-Quality Controls

For every block the harness records the CPU use of everything else on the Mac and inside the virtual machine, the thermal pressure, the power source, any CPU-quota throttling and the core type, and it runs a fixed canary benchmark (SHA3-256 throughput) at the start of a run, every 10 minutes and at the end. Thresholds were calibrated by a 30-minute trial run and frozen before the first main run; for the Mac the drift limit is 4.16 % and the canary limit 3 %.

| Flag | Rule | Action |
| --- | --- | --- |
| Other CPU | Other processes on the Mac and in the virtual machine use more than 5 % of the capacity | Repeat |
| Thermal | macOS thermal pressure above nominal | Repeat |
| Power | On battery or in Low Power Mode | Repeat |
| Quota | Any CPU-quota throttling of the container | Repeat |
| Canary | The canary before or after the block deviates by more than 3 % from the run's first canary | Repeat |
| Core type | The canary ran at efficiency-core speed | Repeat |
| Drift | The block's median differs from its cell's reference by more than 4.16 % (or 3 bootstrap standard errors) | One diagnostic re-run; the original is kept |
| Untimed experiments | Sizes, memory and ledger bytes do not depend on machine noise | Never flagged; first attempt kept |

A block flagged for an external cause is repeated, at most three attempts in total, and its headline result is its first unflagged attempt; every attempt is kept. A block whose three attempts were all disturbed was run again inside the same run after the main session, under the same plan, thresholds and measuring code, and the extension is recorded in the run's manifest, so every run ends with a headline result for every block.

*External-flag rules applied to every measurement attempt (excerpt):*

```go
if v.Host.Throttled {
	v.External = append(v.External, "thermal")
}
if v.Host.OnBattery {
	v.External = append(v.External, "battery")
}
if v.Host.Alert {
	v.External = append(v.External, "alert")
}
if r.Quality.StealPct > in.TH.StealPct {
	v.External = append(v.External, "steal")
}
if v.CombinedOther > in.TH.OtherPct {
	v.External = append(v.External, "other")
}
if r.Quality.NrThrottled > 0 {
	v.External = append(v.External, "quota")
}
// …
canaryBad, coreBad := false, false
if before != nil {
	v.CanaryBefore, v.CoreBefore = before.Ratio, before.Core
	canaryBad = canaryBad || math.Abs(before.Ratio-1) > in.TH.CanaryFrac
	coreBad = coreBad || before.Core == "E-like"
}
if after != nil {
	v.CanaryAfter, v.CoreAfter = after.Ratio, after.Core
	canaryBad = canaryBad || math.Abs(after.Ratio-1) > in.TH.CanaryFrac
	coreBad = coreBad || after.Core == "E-like"
}
if canaryBad {
	v.External = append(v.External, "canary")
}
if coreBad {
	v.External = append(v.External, "core")
}
```

### 6.8 Fidelity to QChain

Four checks tie the measurements to the real system. **First**, every image build runs liboqs's own known-answer and ACVP tests (92 passed) before it can be used, and every measured output is checked. **Second**, a script compares the eleven copied ranges of production code with the project repository, and lifecycle tests prove that the copied code issues, decrypts, presents and verifies credentials end to end for every algorithm family. **Third**, the ledger model of E13 reproduces a read-only capture of the live ledger and IPFS store to the byte: 60 transactions from their parts, 57 QChain transactions from keys and record lengths, 61 blocks, 71 IPFS objects and 238 certificates. **Fourth**, E14 rebuilds QChain's own Fabric network from its configuration files, copied byte for byte, and its transactions match the sizes predicted by E13 within 0.02 %.

---

## 7. Testing and Preliminary Results

This chapter presents the preliminary results of the 15 experiments on the first test platform. Times are medians over the five repetitions of each block's per-call median. The results describe the Mac and the harness (Section 6.3); the Final Report will compare them with the other platforms.

### 7.1 Run Inventory and Data Quality

The 15 main runs were completed between 10 and 22 October 2026 in **114.7 hours**. Every block of every run ended with a headline result. Across the timed experiments, 584 of 10,243 attempts (5.7 %) were flagged for an external cause and repeated, nearly all for CPU activity of other processes on the Mac; 16 blocks whose three attempts were all disturbed were completed in extension sessions. The canary stayed within 4.0 % of its first value in every run, and no attempt was flagged for thermal pressure, power or core type.

| Experiment | Start (UTC) | Hours | Blocks | Attempts | Flagged | Extended |
| --- | --- | --- | --- | --- | --- | --- |
| E1 Primitive latency | 10 Oct | 6.3 | 450 | 510 | 49 | 4 |
| E10 Issuer–holder | 11 Oct | 0.1 | 15 | 16 | 0 | 0 |
| E2 Integration cost | 11 Oct | 19.7 | 900 | 1,018 | 103 | 3 |
| E8 Sizes | 12 Oct | 0.5 | 60 | 60 | N/A | 0 |
| E11 Lifecycle | 12 Oct | 26.2 | 4,955 | 5,226 | 202 | 1 |
| E13 Ledger and IPFS | 13 Oct | 0.0 | 30 | 30 | N/A | 0 |
| E6 Message size | 13 Oct | 16.5 | 1,100 | 1,212 | 98 | 5 |
| E7 Rejection timing | 14 Oct | 3.7 | 150 | 166 | 11 | 0 |
| E9 Memory | 15 Oct | 1.2 | 1,350 | 1,350 | N/A | 0 |
| E12 Concurrency | 15 Oct | 1.2 | 120 | 125 | 5 | 0 |
| E3 Integration layers | 16 Oct | 19.7 | 455 | 536 | 62 | 3 |
| E4 Portable build | 18 Oct | 6.2 | 450 | 494 | 32 | 0 |
| E4 Native build | 19 Oct | 5.5 | 450 | 478 | 15 | 0 |
| E5 Native macOS | 20 Oct | 5.2 | 450 | 462 | 7 | 0 |
| E14 Fabric latency | 21 Oct | 2.8 | 93 | 93 | N/A | 0 |

### 7.2 Primitive Cost

The lattice schemes are as fast as the classical ones or faster. **ML-DSA-44 signs in 60.2 µs and verifies in 28.4 µs**, against 19.9 µs and 54.5 µs for ECDSA P-256: its signing is about 3 times slower but its verification 1.9 times faster. It generates a key pair in 30.2 µs, whereas RSA-3072 needs 402.0 ms, about 13,000 times longer. ML-KEM-768 encapsulates in 14.0 µs and decapsulates in 16.1 µs, 4.8 times faster than DHKEM(X25519) encapsulation. Falcon verifies fastest (21.7 µs for Falcon-512) but needs 4.80 ms to generate a key pair; SLH-DSA signs in 20.7 ms to 982.1 ms, and HQC costs about 200 to 750 times as much as ML-KEM at the same level.

The medians hide the spread that matters in operation. ML-DSA signing has a coefficient of variation of **41–55 %** because of rejection sampling, and the 99th percentile of ML-DSA-44 signing is 218 µs, 3.6 times its median, whereas verification varies by only about 5 %. This agrees with the 51.5 % reported for ML-DSA-65 on a server [43] and is lower than the 66–74 % measured on a microcontroller [13]. A service that signs on demand should therefore be sized on the tail rather than the median.

| Algorithm | Key generation | Sign / encaps. | Verify / decaps. | Public key (B) | Signature / ciphertext (B) |
| --- | --- | --- | --- | --- | --- |
| ECDSA P-256 | 25.9 µs | 19.9 µs | 54.5 µs | 65 | 69–72 |
| Ed25519 | 32.1 µs | 30.3 µs | 81.6 µs | 32 | 64 |
| RSA-3072 | 402.0 ms | 1.60 ms | 33.0 µs | 422 | 384 |
| **ML-DSA-44 (QChain)** | 30.2 µs | 60.2 µs | 28.4 µs | 1,312 | 2,420 |
| ML-DSA-65 | 53.0 µs | 95.5 µs | 47.6 µs | 1,952 | 3,309 |
| ML-DSA-87 | 90.9 µs | 140 µs | 83.5 µs | 2,592 | 4,627 |
| Falcon-512 | 4.80 ms | 145 µs | 21.7 µs | 897 | 647–663 |
| SLH-DSA-SHA2-128f | 888 µs | 20.7 ms | 1.25 ms | 32 | 17,088 |
| SLH-DSA-SHA2-128s | 56.8 ms | 431.3 ms | 428 µs | 32 | 7,856 |
| DHKEM(X25519) | 31.9 µs | 67.4 µs | 37.5 µs | 32 | 32 |
| DHKEM(P-256) | 26.0 µs | 110 µs | 99.5 µs | 65 | 65 |
| ML-KEM-512 | 8.3 µs | 9.1 µs | 10.1 µs | 800 | 768 |
| **ML-KEM-768 (QChain)** | 13.3 µs | 14.0 µs | 16.1 µs | 1,184 | 1,088 |
| ML-KEM-1024 | 20.2 µs | 21.0 µs | 23.7 µs | 1,568 | 1,568 |
| HQC-1 | 894 µs | 1.79 ms | 2.73 ms | 2,241 | 4,433 |
| HQC-5 | 5.92 ms | 11.8 ms | 17.8 ms | 7,237 | 14,421 |

Every fixed size matched the specification on every item produced; unpadded Falcon and ECDSA signatures vary in length, and the table gives their ranges.

### 7.3 Credential-Lifecycle Cost

For the 16 curated suites at 10 attributes with 5 disclosed, the cost of one credential's life (issuance, retrieval, presentation and verification) plus the one-time wallet activation. These are computation times summed over all parties, **without network, database, IPFS or ledger time**. For QChain's production suite, ML-DSA-44 with ML-KEM-768, a credential costs **0.61 ms** and a wallet activation 82.5 µs. Run back to back in one process, the five stages took 0.75 ms, 8.6 % more than the sum of the separately measured stages; this difference ranges from 1.3 to 9.3 % across the 13 measured settings and will be analysed in the Final Report.

```
COMPUTATION PER CREDENTIAL (10 attributes, 5 disclosed)       1 block ≈ 0.05 ms
Production suite (ML-DSA-44 + ML-KEM-768)  ████████████ 0.61 ms
Falcon-512 suite                           ██████████████ 0.69 ms
Classical elliptic-curve suites            ██████████████▌ 0.72–0.75 ms
ML-DSA-65 + ML-KEM-768 (level-matched)     ███████████████ 0.75 ms
ML-DSA-87 + ML-KEM-1024                    ████████████████████ 0.98 ms
HQC suites                                 ───────────────────────────▶ 5.14–30.8 ms
SLH-DSA suites                             ───────────────────────────▶ 44.7–867.0 ms
```

Seven suites cost less than a millisecond per credential, among them the production suite and both elliptic-curve classical suites (0.72 ms and 0.75 ms), so moving QChain from classical to post-quantum cryptography did not make it slower **in computation**. Falcon matches the lattice suites per credential (0.69 ms for Falcon-512) but needs 4.84 ms to activate a wallet because its key generation is slow, and RSA-3072's key generation makes activation take 416.0 ms. HQC raises the cost to 5.14–30.8 ms and SLH-DSA to 44.7–867.0 ms, dominated by the issuer's and the holder's signatures.

Aligning the security levels costs little. The production suite pairs a category-2 signature with a category-3 KEM; the level-matched category-3 suite, ML-DSA-65 with ML-KEM-768, costs 0.75 ms per credential (23 % more), and the category-5 suite, ML-DSA-87 with ML-KEM-1024, 0.98 ms.

Time per stage for the production suite, by number of attributes N (k = N/2 disclosed, rounded up), in µs. Issuance and retrieval grow with N because each attribute is salted, hashed and encrypted separately, while presentation and verification depend mostly on the two signatures. With 256-byte attribute values instead of 16 bytes, the four per-credential stages at 10 attributes take 0.73 ms in total, and with 4,096-byte values 2.53 ms.

| Stage | N = 1 | N = 5 | N = 10 | N = 20 | N = 64 |
| --- | --- | --- | --- | --- | --- |
| Wallet activation (once) | 82.5 | 82.5 | 82.5 | 82.5 | 82.5 |
| Issuance | 122.7 | 161.6 | 209.7 | 309.8 | 755.1 |
| Retrieval | 57.9 | 92.1 | 136.4 | 224.2 | 621.4 |
| Presentation (k disclosed) | 102.0 | 105.0 | 112.0 | 126.9 | 193.7 |
| Verification (k disclosed) | 132.9 | 142.7 | 150.0 | 169.5 | 258.9 |
| Sum of the four per-credential stages | 415.5 | 501.3 | 608.2 | 830.4 | 1,829.0 |
| All five stages run back to back | 542.8 | 637.9 | 749.9 | 974.6 | 1,936.6 |

Across all 176 signature–KEM pairs, **the signature decides the cost**: for the ML-DSA and Falcon signatures, the choice among the ML-KEM and classical KEMs changes the cost of a credential by at most 218 µs, while HQC adds about 4.5, 12 and 30 ms at its three levels. The cheapest pair overall is ECDSA P-256 with ML-KEM-512 (0.53 ms), and the cheapest fully post-quantum pair is ML-DSA-44 with ML-KEM-512 (0.58 ms).

### 7.4 Integration Overhead

The boundary between Go and C is negligible: an empty call through cgo costs **28 ns**, below the roughly 50 ns assumed in the literature [42], and across the 46 fast operations the Go binding, boundary included, adds a median of 0.27 % to the time of the C call (under 1 % for nine operations in ten). Re-initialising the library object for every call adds about a microsecond (0.96 µs to ML-DSA-44 signing). QChain's production pattern costs more: **ML-DSA-44 signing takes 67.3 µs instead of 60.4 µs (+11 %) and ML-KEM-768 decapsulation 20.1 µs instead of 16.0 µs (+26 %)**.

The components explain the difference. Decoding the 2,560-byte ML-DSA-44 secret key from hexadecimal takes 2.5 µs and encoding the signature 2.4 µs, while creating and destroying the signature object take 0.23 and 0.21 µs. QChain's integration overhead is therefore **text encoding** rather than the boundary to C or the re-initialisation. The classical libraries behave differently: OpenSSL parses the key into a new object on every call, so re-initialisation adds 16 µs to ECDSA signing (+77 %). Go's own standard library is faster than OpenSSL for some classical operations (Ed25519 verification in 54 instead of 83 µs, DHKEM(P-256) decapsulation in 44 instead of 105 µs) and slower for others (RSA-3072 signing in 2.62 ms instead of 1.62 ms), so a classical baseline depends on the library chosen.

### 7.5 Message Size and Rejection Timing

QChain always signs a 64-character hash, but other systems sign whole documents. Up to 10 KiB the message size barely matters, because every scheme first hashes the message. At 1 MiB hashing dominates: ML-DSA-44, ML-DSA-87 and Falcon-512 take 1.7–1.9 ms to sign or verify, ECDSA P-256 about 0.45 ms (its SHA-256 can use the processor's hash instructions), and SLH-DSA-SHA2-128f signing grows only from 20.7 ms to 27.2 ms.

E7 timed the rejection of invalid inputs. For every post-quantum algorithm, rejecting a corrupted signature, a signature over a different message or a tampered ciphertext took as long as accepting a valid input (ratios 0.995 to 1.004); ML-KEM and HQC reject a tampered ciphertext implicitly by returning a different shared secret. The exception among the baselines is DHKEM(P-256), which rejects a tampered ciphertext in 13.6 µs instead of 99.8 µs, because a corrupted point is no longer on the curve; and 4,217 of 50,005 verifications of ECDSA signatures with one flipped bit failed already on the signature's encoding.

### 7.6 Memory

The deepest C stack among QChain's operations and four comparisons is used by HQC-1 decapsulation (64 KB) and ML-DSA-44 signing (49 KB), far below the 8 MiB stack of the threads that run them, against about 2.5 KB for ECDSA. The C heap per call is a few kilobytes and is released, but **QChain's production pattern leaves exactly two small heap blocks (48 bytes) unreleased per call**, because the binding's initialisation allocates two strings that it never frees; this grows by about 48 MB per million calls in a long-running backend. The production pattern also allocates more Go memory, 15,296 bytes per signing call against 2,800 with a reused object, mostly for the hexadecimal strings.

| Operation | C stack (KB) | C heap allocated (B) | Go heap, reused / production (B) | Unfreed blocks per call (production) |
| --- | --- | --- | --- | --- |
| ML-DSA-44 key generation | 31.5 | 5,760 | 4,192 / 20,336 | 2 |
| ML-DSA-44 signing | 49.0 | 8,216 | 2,800 / 15,296 | 2 |
| ML-DSA-44 verification | 29.4 | 4,544 | 96 / 4,272 | 2 |
| ML-KEM-768 key generation | 13.2 | 4,280 | 4,064 / 19,200 | 2 |
| ML-KEM-768 encapsulation | 16.3 | 4,280 | 1,280 / 7,328 | 2 |
| ML-KEM-768 decapsulation | 17.3 | 4,544 | 128 / 4,128 | 2 |
| Falcon-512 signing | 42.6 | 528 | 880 / 5,216 | 2 |
| SLH-DSA-SHA2-128f signing | 4.4 | 0 | 18,544 / 100,616 | 2 |
| HQC-1 decapsulation | 64.1 | 1,584 | 128 / 7,872 | 2 |
| ECDSA P-256 signing | 2.5 | 7,160 | 192 / 656 | 0 |

### 7.7 Issuer–Holder Equivalence

QChain's issuer signs a commitment and the holder signs a presentation payload, both as 64-character SHA3-256 hashes but with different keys and calling code. E10 interleaved the two signing roles in one process, together with a second issuer arm that measures the noise between identical arms. For all three ML-DSA levels the 90 % confidence interval of the holder-to-issuer ratio lies within ±0.7 %, well inside the equivalence margins fixed before the run, so the two roles cost the same and one measurement serves both.

| Parameter set | Issuer (µs) | Holder (µs) | Holder ÷ issuer | 90 % interval | Margin | Equivalent |
| --- | --- | --- | --- | --- | --- | --- |
| ML-DSA-44 | 60.1 | 60.1 | 0.9985 | -0.44 % to +0.15 % | ±2.0 % | Yes |
| ML-DSA-65 | 96.4 | 96.0 | 0.9989 | -0.66 % to +0.45 % | ±2.1 % | Yes |
| ML-DSA-87 | 139.1 | 138.8 | 1.0008 | -0.32 % to +0.48 % | ±2.0 % | Yes |

### 7.8 Concurrency

Verification with the production suite handles **6,427 credentials per second** with one worker, 12,075 with two and 18,994 with four (3.0 times the single-worker rate); issuance rises from 4,487 to 12,730 per second. With four workers the container occupies all four CPUs of the virtual machine, which also runs its own kernel and the container runtime, so the four-worker results are a saturated case: the 99th-percentile verification latency rises from 194 µs with one worker to 1.5 ms. Falcon-512 verifies fastest, and SLH-DSA-SHA2-128f issues only about 47 credentials per second per worker.

### 7.9 Build and Platform Sensitivity

Every E1 cell was also measured with two other liboqs builds and natively on macOS. The portable build, without hand-written vector code, makes ML-DSA about 1.37 times and ML-KEM 1.45 times slower, and Falcon signing up to 27 times slower, most likely because Falcon's floating-point arithmetic then runs without the vector unit; SLH-DSA, HQC and the classical controls are unchanged. The natively tuned build gains nothing over the production-like build (every family median within 1.4 %), because inside the Mac's virtual machine the compiler's native target resolved to a generic ARMv8 processor with cryptographic extensions. Running natively on macOS instead of in the container changes the family medians by 3.3 % or less, except that Falcon verification is 1.22–1.32 times slower natively, which points to the different compiler (Apple clang instead of gcc). **One effect remains unexplained:** HQC-1 is about 14 % faster in all three other configurations than in the production-like container build, while HQC-3 and HQC-5 are not; the three runs that measured the production-like build agree on HQC-1 within 0.3 %.

### 7.10 Ledger and IPFS Footprint

The size of one credential-issuance transaction on QChain's ledger for each signature scheme is computed by the model that reproduces the live ledger to the byte. The issuer's signature and public key are stored twice in hexadecimal, in the transaction's arguments and in the state record, so they make up **69 %** of an ML-DSA-44 transaction of **21,529 bytes**; with ECDSA the transaction would take 7,141 bytes. Block size is no constraint for the lattice and Falcon schemes, ten of whose transactions fit in a block, but the larger SLH-DSA variants reach the 512 KB preferred block size after seven to two transactions.

Per million credentials, an ML-DSA-44 ledger grows by about 22.8 GB on each peer when every credential occupies its own block, as on the live ledger, against 8.5 GB for ECDSA and 208 GB for SLH-DSA-SHA2-256f. The table shows how much of this is encoding. A projection, not a measurement, shows what ML-DSA network identities would add: the certificates and Fabric's own signatures would enlarge the same transaction to 48,055 bytes.

| Scenario (one ML-DSA-44 issuance transaction, 5 attributes) | Transaction (B) | Block holding it (B) | GB per million (per peer) | Change |
| --- | --- | --- | --- | --- |
| As deployed: hexadecimal, issuer key in every record | 21,529 | 22,847 | 22.8 | — |
| Signature and keys in base64 | 16,558 | 17,876 | 17.9 | -23 % |
| Issuer key stored as a 64-character fingerprint | 16,404 | 17,722 | 17.7 | -24 % |
| Both changes | 13,180 | 14,496 | 14.5 | -39 % |
| Projection: ML-DSA-44 network identities | 48,055 | 56,594 | 56.6 | +123 % |

On IPFS the production envelope of a credential with five 16-byte attributes holds 4,268 bytes, growing by about 336 bytes per attribute; HQC-5's large ciphertext raises it to 30,929 bytes. Every envelope measured with 16-byte values fits in a single IPFS block.

### 7.11 Fabric Latency Against Payload Size

E14 timed QChain's transaction path on its Fabric network rebuilt on the test platform, with QChain-shaped transactions whose sizes match E13's predictions. Submitted one at a time, every transaction waits for the 2-second batch timer, so the median latency to commit is **2,053.6 ms** for the smallest transaction and **2,074.6 ms** for the 206 KB SLH-DSA-SHA2-256f transaction: a payload 42 times larger adds only 21 ms. The ML-DSA-44 transaction takes 1.9 ms longer than the smallest. When 40 transactions are released together, the blocks close by count (ten transactions) or by size exactly as E13 predicted for every payload, and the median latency rises from 164 ms to 705 ms as fewer large transactions fit in a block. **Post-quantum signatures therefore cost QChain's ledger bytes, not time.**

| Payload | Size (KB) | One at a time: median (ms) | 40 at once: median (ms) | Transactions per block: measured / predicted | Conflicted burst blocks |
| --- | --- | --- | --- | --- | --- |
| Smallest transaction | 4.9 | 2,053.6 | 164 | 10 / 10 | 3 of 20 |
| ECDSA P-256 | 7.1 | 2,053.8 | 197 | 10 / 10 | 9 of 20 |
| Falcon-512 | 12.8 | 2,053.8 | 179 | 10 / 10 | 0 of 20 |
| ML-DSA-44 (QChain) | 21.5 | 2,055.5 | 195 | 10 / 10 | 6 of 20 |
| ML-DSA-65 | 27.6 | 2,057.4 | 247 | 10 / 10 | 9 of 20 |
| ML-DSA-87 | 35.5 | 2,055.8 | 253 | 10 / 10 | 9 of 20 |
| SLH-DSA-SHA2-128s | 38.2 | 2,057.7 | 240 | 10 / 10 | 5 of 20 |
| SLH-DSA-SHA2-128f | 75.1 | 2,062.1 | 336 | 6 / 6 | 0 of 35 |
| SLH-DSA-SHA2-256f | 206.2 | 2,074.6 | 705 | 2 / 2 | 0 of 100 |

The experiment also revealed a property of QChain's network. **Both peers share one CouchDB state database**, so the peer that validates a block second finds the records the first peer has just written and marks the block's transactions as conflicting (`MVCC_READ_CONFLICT`) in its own copy of the ledger, although every record was correctly stored, as reading it back from both peers confirmed. This happened to 410 of the 1,800 transactions released in bursts (22.8 %), always to whole ledger blocks (41 of 275) and only in blocks of ten transactions, and to none of the 4,560 transactions submitted one at a time. Because QChain's backend submits through one of the two peers, a credential write could be reported as failed although it took effect when several blocks follow each other closely; this is recorded as a risk in Section 9.2.

### 7.12 Summary of Findings and Limitations

The preliminary results support seven findings:

1. QChain's post-quantum production suite costs **0.61 ms of computation per credential** on the test platform, less than the classical elliptic-curve suites (0.72–0.75 ms). This is cryptographic computation only, not the time a user experiences.
2. ML-DSA-44 verifies faster than ECDSA P-256 and Ed25519 and signs about three times slower; its signing has a heavy tail (99th percentile 3.6 times the median).
3. The signature scheme decides the cost of a credential; among the KEMs only HQC adds a noticeable cost.
4. QChain's integration adds 11–26 % to the library time, mostly hexadecimal encoding; the boundary from Go to C costs tens of nanoseconds.
5. On the ledger, post-quantum signatures cost bytes, not time: an ML-DSA-44 issuance transaction is 3.0 times the ECDSA one, but commits only 2 ms later than the smallest transaction; hexadecimal encoding and repeated storage account for much of the size.
6. Issuer and holder signing are statistically equivalent, and rejecting invalid inputs takes as long as accepting valid ones.
7. The shared CouchDB of QChain's network produces spurious transaction conflicts when blocks follow each other closely.

These are preliminary results from one fanless laptop, measured in containers inside a Linux virtual machine on an ARM processor, with liboqs 0.16.0 rather than the unpinned development version that the production backend builds. They describe this machine and this harness, not QChain's production server, and their absolute values will differ on other hardware, which the next measurement phase addresses.

---

## 8. Quality Alignment and Validation

The team charter defines the product and process quality attributes against which the project is evaluated. Because this period produced measurements rather than new features, a second table adds the evidence that the measurements themselves can be trusted.

| Quality attribute | Evaluation method and evidence | Status | Remarks |
| --- | --- | --- | --- |
| Data access and privacy | The harness never touches live data; every result file passes a privacy scan before it is stored | Meets | Architecture unchanged |
| Data quality | Every measured output checked for correctness; checksums of every result file | Meets | None |
| Algorithm transparency | Every run records its algorithms, library versions, build flags and thresholds | Meets | None |
| System security | Security mechanisms unchanged; identity-layer migration in progress | Partially meets | MSP proof of concept at 50 % |
| Functionality | Production code exercised end to end by lifecycle tests in the harness | Meets | None |
| Reliability | The study found spurious transaction conflicts caused by the shared state database | Partially meets | Corrective options in Chapter 9 |
| Maintainability | Harness organised by experiment, with unit tests run in every image build | Meets | None |
| Usability | Portal and wallet unchanged in this period | Not yet evaluated | User testing in Weeks 11–12 |
| Efficiency | KPI study: 0.61 ms of computation per credential; ledger growth and latency quantified | Meets (first platform) | Other platforms pending |
| Stakeholder engagement | Supervisor meeting on the KPI plan (5 October 2026); written update with preliminary results (15 October 2026) | Meets | No comments received on the update |
| Artefact quality assurance | Copied production code checked against the repository; checksums and privacy scan of every run | Meets | None |
| Project deliverables | Progress Report 2 delivered on its due date; competition poster with KPI results | Meets | None |
| Resources | Test platform dedicated to the runs; further platforms prepared for the next phase | Meets | None |

**Evidence that the measurements can be trusted**

| Aspect | Evidence |
| --- | --- |
| Correct libraries | liboqs known-answer and ACVP tests (92 passed) in every image build; RFC 9180 test vectors for DHKEM; every output checked |
| Fidelity to QChain | Eleven copied ranges of production code verified against the repository; lifecycle tests across all algorithm families |
| Ledger model | Reproduces the captured live ledger to the byte: 60 transactions, 61 blocks, 71 IPFS objects and 238 certificates |
| Fabric experiment | Transaction sizes within 0.02 % of the model; every block cut as predicted; every conflicting record read back |
| Run quality | 584 of 10,243 timed attempts (5.7 %) repeated for external causes; every block with a headline result |
| Machine stability | Canary within 4.0 % of its first value in every run; no thermal, power or core-type flag |
| Noise floor | Two identical signing arms (E10) differ by at most 0.24 % |
| Traceability | Every run stores its manifest (environment, build, plan, seed), all raw samples and the checksums of every file |

---

## 9. Challenges, Risks and Corrective Actions

### 9.1 Challenges and Corrective Actions

| Challenge | Impact | Corrective action | Responsible | Schedule impact |
| --- | --- | --- | --- | --- |
| macOS background analysis services (indexing, photo analysis) used up to two of the eight cores whenever the Mac was idle | Four of five trial runs unusable; most blocks flagged | The launcher pauses these services and switches Wi-Fi off for every run; the next trial had 1 flagged attempt in 194 | Maqqavi, Nihal | One day |
| A CPU quota on the container paused the benchmark in 29 of 100 scheduling periods | Pauses inside timed samples | Container pinned to one CPU without a quota; any throttling flags the block | Maqqavi, Nihal | Hours |
| Short bursts of system activity disturbed some long operations in all three attempts | 16 blocks without a valid attempt | Extension sessions inside the same run, recorded in the manifest | Maqqavi, Haris | Under one hour per run |
| Some blocks ran uniformly slower than their cell without an outside cause | Possible bias in single repetitions | Kept under the pre-set rule with a diagnostic re-run; medians over five repetitions; reported | Maqqavi, Nihal | None |
| The host monitor misattributed CPU use at process boundaries in native macOS runs | First native run invalid | Native rule based on each block's own CPU reading; run repeated, invalid run discarded | Maqqavi, Haris | Six hours |
| The shared state database made one peer flag burst transactions as conflicting | Fabric experiment stopped at first | Conflicts recorded per block and every affected record verified by read-back | Haris, Nihal | Hours |
| Limited access to the other two test machines in October; runs longer than first estimated | Cross-platform results not ready for this report | Mac-only experiments kept on the Mac; launchers for the other platforms written and tested; next phase started on 25 October | Maqqavi, Haris | KPI task extended to 20 November |
| The MSP research took longer than planned | Proof of concept started in Week 10 instead of Week 6 | Re-planned: proof of concept to 7 November, certificates and rebuild from 8 to 19 November | Obeid, Maqqavi | About three weeks |
| Wallet timing on Android and iOS phones, planned in Week 5, was removed from the study's scope | No phone measurements | The wallet's cryptographic code (key generation, decryption, presentation signing) is measured in the container | Haris, Nihal | None |

### 9.2 Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Spurious transaction conflicts on the live network when several issuances arrive together | Medium | Medium | Reported to the team; options to evaluate: verify the record and retry on conflict, or one state database per peer |
| Measurements on the further platforms take longer than planned | Medium | Medium | Reduced per-platform scope, resumable runs and chained run scripts; the Final Report can use the platforms completed |
| The MSP migration is not complete before the Final Report | Medium | High | Re-planned with the proof of concept first; application-layer protection already complete |
| A concurrent publication covers the same ground | Medium | Medium | Novelty defined as a combination of claims (Section 2.6); paper drafting from 9 November |
| Results read as production performance | Low | Medium | Platform and limitations stated with every result |
| The test setup changes before all runs finish | Low | Medium | Test configuration kept unchanged until the end of the study; every change recorded for reversal |

---

## 10. Planned vs Actual Progress

The activities scheduled for Weeks 6–10 in the Gantt chart, with their actual status. The first rows cover the KPI benchmarking task, scheduled as one task for Weeks 5–9 and now split into four sub-tasks; the following rows check the metrics this task was planned to deliver. The study's design, harness and complete measurement on the first platform were finished within the scheduled weeks, the measurements on further platforms and the analysis were extended into November, and the identity-layer migration started about three weeks late.

| Activity | Owner | Scheduled | Status | Evidence | Deviation |
| --- | --- | --- | --- | --- | --- |
| MSP / BCCSP research and scoping | Obeid | Weeks 4–6 | 88 % | Research notes | Extended to Week 11 |
| Single-organisation ML-DSA MSP proof of concept | Obeid, Maqqavi | Weeks 6–7 | 50 % (started Week 10) | Proof of concept in progress | About three weeks late |
| ML-DSA certificates and network rebuild | Obeid | Weeks 7–10 | Not started | N/A | Moved to Weeks 11–13 |
| KPI: study design and literature review | Maqqavi, Nihal | Weeks 5–9 | Completed | Chapters 2 and 6 | None |
| KPI: harness and measurements on the first platform | Maqqavi, Haris | Weeks 5–9 | Completed (22 Oct) | 15 main runs (Section 7.1) | None |
| KPI: measurements on further platforms | Nihal, Haris | Weeks 5–9 | 50 % | Next measurement phase | Extended to Week 11 |
| KPI: cross-platform analysis and paper draft | Nihal, Haris | Weeks 5–9 | Not started | N/A | Moved to Weeks 12–13 |
| Metric: latency of each step (cryptography, IPFS, endorsement, ordering) | Maqqavi, Haris | Weeks 5–9 | Measured except IPFS | E11; E14 | IPFS latency not measured |
| Metric: throughput under concurrent load | Maqqavi, Haris | Weeks 5–9 | Measured | E12 | None |
| Metric: ledger and IPFS storage growth | Maqqavi, Haris | Weeks 5–9 | Measured | E13; E14 | None |
| Metric: wallet timings on Android and iOS | Maqqavi, Haris | Weeks 5–9 | Removed from scope | N/A | Not measured |
| Metric: ML-DSA-44 against -65/-87; ML-KEM-768 against -1024 | Maqqavi, Haris | Weeks 5–9 | Measured | E1; E11 | None |
| Poster competition and live demonstration | All | Added (Weeks 9–10) | Completed | Poster with KPI results; live system shown | Unplanned addition |
| Progress Report 2 | All | Weeks 9–10 | Completed | This report | Written 29–31 Oct; on its due date |

---

## 11. Next Steps and Updated Plan

### 11.1 Semester Schedule

The updated semester schedule runs from Week 1 (24 August 2026) to Week 14 (29 November 2026); `█` marks the weeks in which a task is active. The KPI task is split into its four sub-tasks, the identity-layer migration is re-planned, and the poster competition appears as an added task. The report's submission date is 31 October 2026 (Week 10).

```
TASK                                      WEEK  1  2  3  4  5  6  7  8  9 10 11 12 13 14
Requirements, design review, literature         ██ ██                                    
Threat model & confidentiality design              ██ ██                                 
Post-quantum security mechanisms                      ██ ██ ██                           
Deployment hardening, testing, PR1                       ██ ██                           
MSP research & scoping (88 %)                            ██ ██ ██ ██ ██ ██ ██ ██         
Single-org ML-DSA MSP proof of concept (50 %)                              ██ ██         
ML-DSA certificates & network rebuild                                         ██ ██ ██   
KPI study design & literature review                        ██ ██ ██                     
KPI harness & Mac measurements                                    ██ ██ ██               
KPI server & laptop measurements (50 %)                                 ██ ██ ██         
KPI analysis & paper draft                                                       ██ ██   
Poster competition & live demonstration                                 ██ ██            
Progress Report 2                                                          ██            
UI/UX refinement & user testing                                            ██ ██ ██      
Security testing & hardening                                               ██ ██ ██ ██   
Final report                                                                     ██ ██   
Poster, demo & final presentation                                                      ██
```

### 11.2 KPI Benchmarking: Next Measurement Phase and Analysis

The next measurement phase repeats the hardware-dependent experiments on two further platforms: a virtualised x86 server without AVX2 instructions and an x86 laptop with AVX2. It covers the primitive latency of all 30 algorithms, the integration cost without SLH-DSA, memory, the issuer–holder equivalence, the lifecycle of the 16 curated suites, concurrency and further liboqs builds, under the same harness, statistics and quality rules. The size, ledger, message-size, rejection and Fabric experiments are not repeated, because their results do not depend on the processor. The phase is scheduled to finish on 8 November; the cross-platform analysis and a research paper draft follow from 9 to 20 November and feed the Final Report.

### 11.3 Post-Quantum MSP Identity Migration

The migration of Fabric's network identities to ML-DSA, without a classical fallback, continues in three stages: completing the research and scoping (88 %), the single-organisation proof of concept (started in Week 10 and 50 % complete, due on 7 November), and the issuance of ML-DSA certificates and the rebuild of the network (8 to 19 November). The KPI study's ledger projection (Section 7.10) quantifies the transaction growth this migration will cause.

### 11.4 Further Work on the Platform

UI/UX refinement and user testing of QPortal and QWallet run from 1 to 14 November, and security testing and hardening from 1 to 19 November. The shared state database found in Section 7.11 will be assessed with the team, comparing a verified retry after a conflict with one state database per peer.

### 11.5 Upcoming Deliverables

| Milestone | Weeks | Deliverable | Owner |
| --- | --- | --- | --- |
| KPI measurements on further platforms | 9–11 | Results of the next measurement phase | Nihal, Haris |
| MSP proof of concept | 10–11 | Single-organisation ML-DSA identities | Obeid, Maqqavi |
| ML-DSA certificates and network rebuild | 11–13 | Post-quantum network identities | Obeid |
| UI/UX refinement and user testing | 11–12 | Usability evaluation | Abdul Haris |
| Security testing and hardening | 11–13 | Test report | Nihal |
| KPI analysis and paper draft | 12–13 | Cross-platform analysis; paper draft | Nihal, Haris |
| Final Report | 12–13 | Final Report | All |
| Poster, demonstration and presentation | 14 | Poster and live demonstration | All |

---

## Bibliography

1. M. Mosca and M. Piani (2026). Quantum Threat Timeline Report 2025. Global Risk Institute, Toronto. https://globalriskinstitute.org/publication/quantum-threat-timeline-report-2025b/
2. National Institute of Standards and Technology (2024). Module-Lattice-Based Digital Signature Standard (FIPS 204). U.S. Department of Commerce, Gaithersburg, MD. https://doi.org/10.6028/NIST.FIPS.204
3. National Institute of Standards and Technology (2024). Module-Lattice-Based Key-Encapsulation Mechanism Standard (FIPS 203). U.S. Department of Commerce, Gaithersburg, MD. https://doi.org/10.6028/NIST.FIPS.203
4. National Institute of Standards and Technology (2024). Stateless Hash-Based Digital Signature Standard (FIPS 205). U.S. Department of Commerce, Gaithersburg, MD. https://doi.org/10.6028/NIST.FIPS.205
5. R. Perlner (2025). FIPS 206 Status Update: FN-DSA (Falcon). NIST Computer Security Resource Center. https://csrc.nist.gov/csrc/media/presentations/2025/fips-206-fn-dsa-(falcon)/images-media/fips_206-perlner_2.1.pdf
6. National Institute of Standards and Technology (2025). Status Report on the Fourth Round of the NIST Post-Quantum Cryptography Standardization Process (NIST IR 8545). NIST, Gaithersburg, MD. https://doi.org/10.6028/NIST.IR.8545
7. D. Commey, B. Appiah, G. S. Klogo, W. Bagyl-Bac, J. D. Gadze, Y. Alsenani and G. V. Crosby (2025). Performance Analysis and Deployment Considerations of Post-Quantum Cryptography for Consumer Electronics. *arXiv preprint arXiv:2505.02239*. https://arxiv.org/abs/2505.02239
8. J. Algar-Fernandez, A. Villacís-Vanegas, Y. Amaro-Aular and M.-D. Cano (2026). Benchmarking Post-Quantum Signatures and KEMs on General-Purpose CPUs Using a TCP Client–Server Testbed. *Computers*, vol. 15, no. 2, pp. 116. https://doi.org/10.3390/computers15020116
9. D.-L. Lucaciu and D. E. Popescu (2026). Cross-Platform Performance and Security Evaluation of Post-Quantum Cryptographic Algorithms on Resource-Constrained Devices. *Applied Sciences*, vol. 16, no. 12, pp. 5781. https://doi.org/10.3390/app16125781
10. Y. Oleksiichuk (2026). Empirical Performance Evaluation of NIST Post-Quantum Cryptographic Algorithms ML-KEM, ML-DSA, and SLH-DSA across JDK Versions. *Cybersecurity: Education, Science, Technique*, vol. 1, no. 33, pp. 165. https://doi.org/10.28925/2663-4023.2026.33.1210
11. M. Vidaković and K. Miličević (2023). Performance and Applicability of Post-Quantum Digital Signature Algorithms in Resource-Constrained Environments. *Algorithms*, vol. 16, no. 11, pp. 518. https://doi.org/10.3390/a16110518
12. E. D. Demir, B. Bilgin and M. C. Onbasli (2025). Performance Analysis and Industry Deployment of Post-Quantum Cryptography Algorithms. *arXiv preprint arXiv:2503.12952*. https://arxiv.org/abs/2503.12952
13. R. Chhetri, S. Dhakal and A. Gautam (2026). Benchmarking NIST-Standardised ML-KEM and ML-DSA on ARM Cortex-M0+: Latency, Rejection-Sampling Variance, and Memory on the RP2040. *arXiv preprint arXiv:2603.19340*. https://arxiv.org/abs/2603.19340
14. N. Puch, C. H. Ta and M. Beckel (2026). Benchmarking Post-Quantum Cryptography in Lightweight Virtualization Environments on Embedded Hardware. *arXiv preprint arXiv:2609.23902*. https://arxiv.org/abs/2609.23902
15. O. Gillot, W. J. Buchanan and M. G. Tehrani (2026). Energy Consumption of Post-Quantum Cryptography on Constrained and General-Purpose Architectures. *Cryptography*, vol. 10, no. 4, pp. 55. https://doi.org/10.3390/cryptography10040055
16. J. Lopez, V. Cadena and M. S. Rahman (2025). Evaluating Post-Quantum Cryptographic Algorithms on Resource-Constrained Devices. *arXiv preprint arXiv:2507.08312*. https://arxiv.org/abs/2507.08312
17. S. Hoque, A. Aydeger, E. Zeydan and M. Liyanage (2025). Analysis of Post-Quantum Cryptography in User Equipment in 5G and Beyond. *arXiv preprint arXiv:2507.17074*. https://arxiv.org/abs/2507.17074
18. S. Hoque and A. Aydeger (2026). Energy-Aware System-Level Evaluation of Post-Quantum TLS on Embedded User Equipment over a Disaggregated 5G Network. *arXiv preprint arXiv:2607.03988*. https://arxiv.org/abs/2607.03988
19. A. Kudaloor and A. Aijaz (2026). Toward Quantum-Safe 6G: Experimental Evaluation of Post-Quantum Cryptography Techniques. *arXiv preprint arXiv:2605.06881*. https://arxiv.org/abs/2605.06881
20. J. A. Montenegro, R. Rios and J. Lopez-Cerezo (2026). A performance evaluation framework for post-quantum TLS. *Future Generation Computer Systems*, vol. 175, pp. 108062. https://doi.org/10.1016/j.future.2025.108062
21. M. J. Kannwischer (2025). Keynote: mlkem-native & mldsa-native: Open-Source High-Speed High-Assurance PQC. In *Proceedings of the 2025 Cloud Computing Security Workshop (CCSW)*. https://doi.org/10.1145/3733812.3765539
22. Open Quantum Safe Project (2026). liboqs 0.16.0: C library for prototyping and experimenting with quantum-resistant cryptography. GitHub. https://github.com/open-quantum-safe/liboqs/releases/tag/0.16.0
23. A. G. Schemitt, H. F. d. Silva, R. C. Lunardi, D. Kreutz, R. B. Mansilha and A. F. Zorzo (2025). Assessing the Impact of Post-Quantum Digital Signature Algorithms on Blockchains. *arXiv preprint arXiv:2510.09271*. https://arxiv.org/abs/2510.09271
24. P. Juaristi, I. Agudo, R. Rios and L. Ricci (2025). Benchmarking Post-quantum Cryptography in Ethereum-Based Blockchains. In *Lecture Notes in Computer Science*, pp. 340–353. https://doi.org/10.1007/978-3-031-82349-7_23
25. S. A. Holmes (2023). Impact of Post-Quantum Signatures on Blockchain and DLT Systems. In *Distributed Ledger Technology Workshop (DLT 2023), CEUR Workshop Proceedings*.
26. B. Saviozzi, R. Singh, A. Lele and H. Tewari (2026). Building Quantum-Resilient Blockchains with ML-DSA Digital Signature Integration. In *2026 4th International Conference on Advanced Network Technologies and Applications (APAN)*, pp. 1–6. https://doi.org/10.1109/apan70967.2026.11709608
27. P. Thanalakshmi, A. Rishikhesh, J. M. Marceline, G. P. Joshi and W. Cho (2023). A Quantum-Resistant Blockchain System: A Comparative Analysis. *Mathematics*, vol. 11, no. 18, pp. 3947. https://doi.org/10.3390/math11183947
28. A. Holcomb, G. Pereira, B. Das and M. Mosca (2021). PQFabric: A Permissioned Blockchain Secure from Both Classical and Quantum Attacks. In *2021 IEEE International Conference on Blockchain and Cryptocurrency (ICBC)*, pp. 1–9. https://doi.org/10.1109/ICBC51069.2021.9461070
29. S. Abbas, A. Sultana and G. Kaddoum (2025). Quantum-Safe Blockchain in Hyperledger Fabric. *IEEE Networking Letters*, vol. 7, no. 1, pp. 61–65. https://doi.org/10.1109/lnet.2024.3522966
30. N. L. Ouadrassi, M. Said Boukhryss, A. Azmani and K. J. Hassani (2026). Toward Quantum-Safe Permissioned Blockchains: Evaluating Hybrid ML-DSA-65/ECDSA Signatures on Hyperledger Fabric. *IEEE Access*, vol. 14, pp. 146672–146703. https://doi.org/10.1109/access.2026.3735938
31. M. Kuzlu, M. Pipattanasomporn, L. Gurses and S. Rahman (2019). Performance Analysis of a Hyperledger Fabric Blockchain Framework: Throughput, Latency and Scalability. In *2019 IEEE International Conference on Blockchain (Blockchain)*, pp. 536–540. https://doi.org/10.1109/blockchain.2019.00003
32. T. Zhukabayeva, A. u. Rehman, N. Tariq and E. Benkhelifa (2024). Hyperledger Fabric Based Post Quantum Cryptography Healthcare Application Using Discrete Event Simulation. *IEEE Access*. https://doi.org/10.1109/access.2024.3513153
33. M. Arakawa (2025). Post-Quantum Cryptography for Verifiable Credentials: Comprehensive Performance Evaluation Including Selective Disclosure. *TechRxiv preprint*. https://doi.org/10.36227/techrxiv.176118722.22701360/v1
34. T. Wood, K. Thomas, M. Dean, S. Kannan and R. Learney (2024). Towards Post-Quantum Verifiable Credentials. In *Proceedings of the 19th International Conference on Availability, Reliability and Security (ARES 2024)*, pp. 1–10. https://doi.org/10.1145/3664476.3669932
35. D. Margaria, A. Pino, A. Vesco, G. D’Alconzo, A. J. Di Scala, E. Guglielmino and C. Sanna (2025). Implementation of a Post-Quantum Anonymous Verifiable Credential Framework. In *2025 IEEE Symposium on Computers and Communications (ISCC)*, pp. 1–6. https://doi.org/10.1109/iscc65549.2025.11325782
36. A. Pino, D. Margaria and A. Vesco (2024). On PQ/T Hybrid Verifiable Credentials and Presentations to Build Trust in IoT Systems. In *2024 9th International Conference on Smart and Sustainable Technologies (SpliTech)*, pp. 1–6. https://doi.org/10.23919/splitech61897.2024.10612295
37. A. Solavagione and A. Vesco (2025). Transition of Self-Sovereign Identity to Post-Quantum Cryptography. In *2025 International Conference on Quantum Communications, Networking, and Computing (QCNC)*, pp. 174–181. https://doi.org/10.1109/qcnc64685.2025.00035
38. G. Fabrizio, A. Sperotto and R. Van Rijswijk-Deij (2025). Measuring The Impact of Post-Quantum Cryptography on Complex Applications: A Case Study on Federated Identity Management. In *2025 9th Network Traffic Measurement and Analysis Conference (TMA)*, pp. 1–10. https://doi.org/10.23919/tma66427.2025.11097002
39. M. Kirubakaran and V. Vijayarajan (2026). PQ-FundusChain: a postquantum blockchain framework for secure and privacy-preserving retinal fundus image sharing in teleophthalmology. *Frontiers in Digital Health*, vol. 8, pp. 1933562. https://doi.org/10.3389/fdgth.2026.1933562
40. A. Olushola and S. P. Meenakshi (2026). Design and implementation of an authenticated post-quantum session protocol using ML-KEM (Kyber), ML-DSA (Dilithium), and AES-256-GCM. *Frontiers in Physics*, vol. 13, pp. 1723966. https://doi.org/10.3389/fphy.2025.1723966
41. L. F. Prikutse, R. E. Turkson, A.-S. Yussiff, A.-L. Yussiff and M. G. Asante-Mensah (2026). A Commitment-Based Hybrid Post-Quantum Cryptographic Model for Multi-File Cloud Storage. *arXiv preprint arXiv:2608.13138*. https://arxiv.org/abs/2608.13138
42. Y. Kotukh, M. Korobchynskyi, M. Rudenko, A. Honcharuk, I. Kiris and V. Voitko (2026). Type Safe OCaml Bindings for the Open Quantum Safe Post-Quantum Cryptography Library. In *2026 16th International Conference on Advanced Computer Information Technologies (ACIT)*, pp. 981–985. https://doi.org/10.1109/acit69831.2026.11699949
43. A. Shaw (2026). quantum-safe: Bridging the Post-Quantum Production Gap with a Hybrid-by-Default Python Cryptography Library. *arXiv preprint arXiv:2605.17061*. https://arxiv.org/abs/2605.17061
44. C. M. Frost (2026). A Reproducibility Protocol for Cross-Implementation Evaluation of Post-Quantum ACVP Test Vectors. *arXiv preprint arXiv:2608.13784*. https://arxiv.org/abs/2608.13784
45. M. A. Haris (2026). QPortal UI/UX. Notion. https://www.notion.so/QPortal-UI-UX-323709b86769800785c0c2f2f1667091
46. M. A. Haris (2026). QPortal UI/UX: Issuer. Notion. https://www.notion.so/Issuer-323709b86769808497affae72f0c0155
47. M. A. Haris (2026). QPortal UI/UX: Verifier. Notion. https://www.notion.so/Verifier-323709b8676980cea679d977b970dbd2
48. R. Barnes, K. Bhargavan, B. Lipp and C. A. Wood (2022). Hybrid Public Key Encryption (RFC 9180). Internet Research Task Force (IRTF). https://doi.org/10.17487/RFC9180

---

**Last Updated:** 31st October 2026
