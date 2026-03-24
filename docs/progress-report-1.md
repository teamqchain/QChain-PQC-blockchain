# QChain — Progress Report 1

**Project:** Post-Quantum Cryptography in Blockchain Technology  
**Submitted:** 1st March 2026  
**Team:** Team 5M's  
**Supervisors:** Dr. Manar Abu Talib (Head), Dr. Sohail Abbas (Co-Supervisor)

---

## Team Members

| Name | Role | GitHub |
| ---  | --- | --- |
| Mohammed Bin Ali Maqqavi | Project Lead, Quantum Engineer | @M0hd-Maqqavi |
| Mohammed Abdul Haris | Technical Lead, Software Engineer | @mohammed-ah-14 |
| Muhammed Nihal | UI/UX Designer, Quality Assurance Lead | @nihvp 
| Mohammed Hisham Obeid | Blockchain Engineer, Security Analyst | @MohammedObeid88 |

---

## 1. Introduction

This progress report documents the first phase of the QChain project — a quantum-resistant credential system built on Hyperledger Fabric. It covers the period from project initiation to March 1st, 2026, and presents the foundational research, architectural design, and initial technical implementations completed by the team.

The work documented here establishes the basis for a crypto-agile, post-quantum secure identity and credential verification platform. The platform enables organizations to issue quantum-resistant digital credentials and entities to verify them.

### 1.1 Project Scope

This report covers three primary areas:

1. **Literature Review** — comprehensive survey of post-quantum cryptography and its blockchain applications
2. **System Analysis & Architecture** — user roles, use cases, and system design
3. **Foundational Technical Setup** — Hyperledger Fabric network configuration, PQC algorithm integration testing with Dilithium, and IPFS off-chain storage implementation

### 1.2 Project Objectives

The primary objective of QChain is to design, implement, and evaluate a post-quantum secure identity and credential verification platform on Hyperledger Fabric. The project addresses the existential threat that quantum computing poses to classical cryptographic algorithms like RSA and ECDSA.

Specific objectives:

- **Quantum-Resistant Architecture** — implement a hash-on-chain, full-data-off-chain model using Hyperledger Fabric and IPFS to resolve the storage bloat challenge inherent to PQC algorithms
- **Dilithium CSP** — implement a custom Crypto Service Provider (CSP) for Hyperledger Fabric by integrating the Open Quantum Safe (OQS) library and liboqs-go, enabling post-quantum digital signatures within Fabric's identity framework
- **W3C Verifiable Credential System** — create dedicated applications for Issuers (web portal), Holders (mobile wallet), and Verifiers (web portal) covering the full credential lifecycle
- **Research Foundation** — document the implementation methodology, performance trade-offs, and practical considerations for integrating PQC into enterprise blockchain systems

### 1.3 Expected Outcomes (Phase 1)

All outcomes listed below have been achieved and are documented in this report:

- Comprehensive literature review synthesizing research on PQC, blockchain integration challenges, and performance characteristics of NIST-standardized algorithms (Dilithium, Falcon, SPHINCS+)
- Complete system architecture design with defined user roles and 30+ documented use cases
- Fully configured Hyperledger Fabric development environment (docker-compose.yaml, crypto-config.yaml, operational network)
- Successful Dilithium algorithm integration testing via liboqs-go (key generation, signing, verification)
- IPFS configuration for off-chain storage reducing on-chain footprint to 32-byte content identifiers
- Initial UI/UX wireframes — 14+ screens for the Holder wallet, with selective disclosure and privacy-preserving features
- Documented research foundation with 17+ cited sources and identified research gap (no existing Dilithium CSP for Hyperledger Fabric)

---

## 2. Literature Review

Quantum computing poses an existential threat to classical public-key cryptosystems. Algorithms like RSA and Elliptic Curve Cryptography (ECC) derive their security from problems like integer factorization and the discrete logarithm — both solvable in polynomial time by Shor's algorithm on a sufficiently powerful quantum computer. Grover's algorithm additionally halves the effective security margin of symmetric schemes like AES and hash functions like SHA-256.

Blockchain technology is especially vulnerable due to its immutable ledger — historical data signed with classical algorithms remains permanently susceptible to future quantum decryption ("harvest now, decrypt later" attack model).

NIST responded with a standardization process for Post-Quantum Cryptography (PQC), resulting in CRYSTALS-Dilithium (ML-DSA), Falcon (FN-DSA), and SPHINCS+ (SLH-DSA) as approved signature schemes.

The full literature review database is hosted at: https://muhammed.me/QChain-PQC-blockchain/home.html

### 2.1 Blockchain Consensus in the Quantum Era

Gomes et al. classified Post-Quantum Blockchain Consensus (PQBC) solutions into six categories: quantum random number based, quantum entanglement based, quantum key distribution based, quantum distributed processing based, lattice-based, and multivariate polynomial based. Key finding: most solutions prioritize security and throughput over anonymity, and future PQBC development must integrate quantum zero-knowledge proofs to resolve privacy limitations.

### 2.2 Post-Quantum Cryptographic Families

**Lattice-Based (primary focus):**

- *CRYSTALS-Dilithium* — uses "Fiat-Shamir with Aborts" over module lattices. Advantages: implementation simplicity, no complex floating-point arithmetic, less prone to side-channel vulnerabilities. Drawback: relatively large signatures and public keys (~3.3KB signature).
- *Falcon* — operates over NTRU lattices. Produces the most compact signatures among lattice candidates with very fast verification. Drawback: requires 64-bit floating-point Gaussian sampling, introducing significant side-channel risks.

**Hash-Based:**

- *SPHINCS+* — relies entirely on cryptographic hash function security. Highly conservative but suffers catastrophic performance metrics in blockchain contexts (massive signatures, millions of CPU cycles per operation).

**Code-Based & Multivariate:**

- *Classic McEliece* — highly secure but requires ~260KB public keys, making it entirely unviable for blockchain.
- *Rainbow (multivariate)* — a former NIST finalist defeated by classical cryptanalysis in 2022, demonstrating the fragility of multivariate assumptions.

### 2.3 Performance Comparison

| Algorithm | Security Level | Public Key | Signature | Verification Time |
| --- | --- | --- | --- | --- |
| ECDSA (secp256k1) | 128-bit Classical | 33 bytes | 71 bytes | ~0.80 ms |
| CRYSTALS-Dilithium-3 | NIST Level 2/3 | 1,952 bytes | 3,293 bytes | ~1.50–2.4 ms |
| Falcon-512 | NIST Level 1 | 897 bytes | 666 bytes | ~0.22 ms |
| SPHINCS+ (128s) | NIST Level 1/3 | 32 bytes | 7,856 bytes | ~12.30 ms |
| McEliece | NIST Level 3 | ~261,000 bytes | 1.3 KB | N/A |

Key finding: algorithm selection for blockchain must be context-dependent. Dilithium offers the best balance for general-purpose use; Falcon offers fastest verification but risky implementation; SPHINCS+ is impractical for high-throughput systems.

### 2.4 IPFS Off-Chain Storage as a Mitigation Strategy

IPFS (InterPlanetary File System) is a decentralized, peer-to-peer content-addressed storage protocol. In a PQC blockchain context, large signatures and public keys are uploaded to IPFS, which returns a compact 32-byte Content Identifier (CID). Only this CID is stored on-chain.

Experimental results show that integrating IPFS with Dilithium or SPHINCS+ reduces the on-chain signature footprint by more than 99%, compressing several-kilobyte payloads down to a uniform 32 bytes. Trade-off: added network latency when retrieving data from IPFS during verification, and data unavailability risk if IPFS nodes go offline.

### 2.5 PQC in Hyperledger Fabric

Hyperledger Fabric's identity and access control relies on a Membership Service Provider (MSP) and Fabric Certificate Authority (Fabric CA), natively using ECDSA over the NIST P-256 curve. Transitioning to a quantum-resistant state requires deep modifications to the MSP to support algorithms like Dilithium and Falcon.

Current research achieves this by integrating the Open Quantum Safe (OQS) library — specifically libOQS (a C library) — into Fabric's Go-based architecture via CGO wrappers.

Performance benchmarks in PQC-integrated Fabric:

| Configuration | Execution Time | Payload |
| --- | --- | --- |
| ECDSA (baseline) | ~4 ms/block | 96 bytes |
| Falcon-512 | ~18 ms/block | 1,563 bytes |
| Dilithium-3 | ~21 ms/block | 4,173 bytes |

Permissioned networks like Fabric are uniquely positioned to absorb these costs — enterprise infrastructure can be provisioned with AVX2-enabled processors and high-capacity storage to mitigate performance degradation.

### 2.6 Summary

Twelve key papers were reviewed. The consensus across academic and standards communities is clear: classical cryptography is fatally vulnerable to quantum attacks. CRYSTALS-Dilithium offers the most balanced path forward. Storage and computational overhead remain the primary barriers to PQC adoption, pointing to off-chain mitigation and permissioned architectures as practical solutions.

A critical research gap was identified: **no existing Dilithium-based Crypto Service Provider (CSP) exists for Hyperledger Fabric** — which is the primary novel contribution of this project.

Full literature summary table with per-paper key insights and limitations is available in [`docs/literature-review.md`](./literature-review.md).

---

## 3. Problem Statement & Proposed Solution

### 3.1 The Quantum Threat

Modern digital identity systems rely on RSA and ECDSA for digital signatures. Quantum computers running Shor's algorithm can break these in polynomial time. For blockchain systems, this is compounded by the "harvest now, decrypt later" attack — because blockchain ledgers are immutable and transparent, all historically signed transactions become permanently susceptible to future quantum decryption.

### 3.2 How PQC Addresses the Risk

Post-Quantum Cryptography refers to algorithms believed to be secure against both classical and quantum computers. Unlike quantum key distribution (which requires specialized hardware), PQC runs on existing infrastructure. NIST has standardized CRYSTALS-Dilithium for digital signatures — a lattice-based scheme offering strong security guarantees with practical implementation characteristics.

### 3.3 Our Solution

QChain integrates CRYSTALS-Dilithium as the primary signature algorithm through a **custom Crypto Service Provider (CSP)** — the first implementation of Dilithium in Hyperledger Fabric's cryptographic framework.

The system follows a **hash-on-chain, full-data-off-chain** architecture:
- Credential hashes and issuer signatures → stored on Fabric ledger (immutability)
- Full credential documents → stored on IPFS (scalability)
- On-chain footprint per credential → 32 bytes (IPFS CID)

This combination — custom CSP implementation, hybrid storage architecture, and crypto-agility — positions QChain as a publishable research contribution with practical enterprise applicability.

---

## 4. System Architecture

### 4.1 High-Level Overview

QChain follows a hash-on-chain, full-data-off-chain architecture consisting of:

- Three user-facing Flutter applications (Issuer Portal, Holder Wallet, Verifier Portal)
- A Go backend server
- A Hyperledger Fabric network with custom PQC integration
- IPFS for off-chain storage

```
USERS
 ├── Issuer (Web - Flutter)
 ├── Holder (Mobile - Flutter)
 └── Verifier (Web - Flutter)
        │
        ▼
BACKEND SERVER (Go)
 ├── Fabric Client
 ├── Identity Manager
 ├── Credential Manager
 ├── Crypto Layer (liboqs-go)
 ├── Crypto-Agility Controller
 └── Verification Service
        │
        ├──────────────────────────────────┐
        ▼                                  ▼
HYPERLEDGER FABRIC NETWORK           IPFS (Off-Chain)
 ├── Custom CSP (DilithiumCSP)         ├── Full Credential Documents
 ├── Peers / Orderers / Fabric CA      ├── Degree Certificate PDFs
 └── Chaincode (Smart Contracts)       └── Supporting Documents
        │
        ▼
ON-CHAIN (Fabric Ledger)
 ├── Credential Hash
 ├── Issuer Signature
 ├── Student Public Key
 └── Revocation Status
```

### 4.2 User Applications

| User Role | Application | Platform | Key Functions |
| --- | --- | --- | --- |
| Issuer | Issuer Portal | Flutter Web | Issue credentials, Revoke credentials, Manage identity |
| Holder | Holder Wallet | Flutter Mobile | Generate Dilithium keys, Receive credentials, Present credentials |
| Verifier | Verifier Portal | Flutter Web | Verify credentials, Query blockchain, Audit |

### 4.3 Backend Server (Go)

| Module | Responsibility |
| --- | --- |
| Fabric Client | Connect to Fabric network, submit transactions, query ledger |
| Identity Manager | Manage user identities, key registration |
| Credential Manager | Handle credential issuance and verification logic |
| Crypto Layer | PQC operations via liboqs-go |
| Crypto-Agility Controller | Switch between algorithms dynamically (Senior) |
| Verification Service | Verify signatures and credentials |

### 4.4 PQC Library Stack

| Layer | Technology | Purpose |
| --- | --- | --- |
| Application | Go Code | Calls crypto functions from application logic |
| Go Wrapper | liboqs-go | Provides Go bindings for liboqs |
| C Library | liboqs | Core PQC implementations (NIST standards) |
| Algorithms | Dilithium, Falcon | Signature schemes for quantum resistance |

### 4.5 Hyperledger Fabric & Custom CSP

The core research contribution is the implementation of custom Crypto Service Providers (CSPs) for Hyperledger Fabric:

| Component | Modification | Research Contribution |
| --- | --- | --- |
| Crypto Service Provider (CSP) | Add DilithiumCSP, FalconCSP, HybridCSP | **Primary contribution** |
| Membership Service Provider (MSP) | Extend to support PQC identities | Supporting |
| Peer Nodes | Use modified CSP for validation | Supporting |
| Orderer Nodes | Use modified CSP for consensus | Supporting |

### 4.6 Chaincode (Smart Contracts)

Smart contracts written in Go define the core business logic:

1. `RegisterIdentity(identityType, publicKey)` — register university or student identity
2. `IssueCredential(credentialHash, signature, studentID)` — issue credential with Dilithium signature
3. `VerifyCredential(credentialHash, signature, issuerID)` — verify credential authenticity
4. `RevokeCredential(credentialID)` — revoke an issued credential
5. `GetCredentialStatus(credentialID)` — check revocation status

### 4.7 Storage Model

| Data | Location | Rationale |
| --- | --- | --- |
| Credential hash | On-chain (Fabric) | Immutable, verifiable fingerprint |
| Issuer signature | On-chain (Fabric) | Proof of issuance |
| Student public key | On-chain (Fabric) | Identity binding for verification |
| Revocation status | On-chain (Fabric) | Fast revocation checks |
| Full credential document | Off-chain (IPFS) | Scalability, cost efficiency |
| Private keys | Client device | Self-sovereign identity principle |

### 4.8 Cryptographic Flow

1. Credential document is generated
2. Document is hashed using SHA-256
3. Hash is signed using Dilithium (via custom CSP)
4. Full document stored on IPFS → returns CID
5. Hash + Signature + CID stored on Fabric ledger

---

## 5. System Analysis

### 5.1 User Roles

**Issuer** — trusted organizations that create and sign credentials (e.g., universities, government agencies). Responsible for generating Dilithium keypairs, defining credential schemas, issuing/revoking credentials, and maintaining system trust.

**Holder** — subjects of credentials and owners of their digital identities (e.g., students, citizens). Interact primarily through the mobile wallet. Responsible for key management, receiving/storing credentials, presenting them to verifiers, and controlling selective disclosure.

**Verifier** — entities that authenticate credentials presented by holders (e.g., employers, border control, banks). Responsible for cryptographically verifying issuer signatures, checking revocation status on-chain, and maintaining audit logs.

**System Administrator** — manages the underlying Hyperledger Fabric infrastructure (network deployment, chaincode installation, organization onboarding, health monitoring).

**Researcher** — team members who analyze system performance and validate research hypotheses. Run benchmarks, compare algorithms, measure scalability, and generate publication-quality data.

| Role | Definition | Real-World Examples | Application | Trust Level |
| --- | --- | --- | --- | --- |
| Issuer | Creates and digitally signs credentials | Universities, Government Agencies | Web Portal (Flutter Web) | Highly Trusted |
| Holder | Owns and controls their credentials | Students, Citizens, Employees | Mobile App (Flutter) | Self-Sovereign |
| Verifier | Checks authenticity of a presented credential | Employers, Banks, Border Control | Web Portal (Flutter Web) | Trusted but Auditable |

### 5.2 Use Cases (Summary)

**Issuer use cases:** Register Issuer Identity, Issue Credential to Holder, Issue Credential Batch, Revoke Credential, Suspend/Restore Credential, View Issued Credentials, Update Credential (Re-issuance), Define Credential Schema.

**Holder use cases:** Register as Holder, Receive Credential, Accept Credential Manually, Present Credential for Verification, Share via Secure Link, View Credential Details, Check Credential Status, Export/Import Credential Backup.

**Verifier use cases:** Register as Verifier, Verify by QR Code, Verify by Manual Entry, Verify by Upload, Batch Verify, Verify with Policy Checks, View Verification History, Audit Trail Export, Subscribe to Status Changes.

**Admin use cases:** Deploy Fabric Network, Install/Upgrade Chaincode, Onboard New Organizations, Monitor Network Health, Manage Cryptographic Materials, Configure Consensus.

**Researcher use cases:** Run Performance Benchmarks, Compare Algorithm Performance, Measure Scalability, Analyze Storage Impact, Generate Paper Figures and Tables.

**Total: 30+ documented use cases** covering the complete credential lifecycle.

---

## 6. Technical Setup

### 6.1 Hyperledger Fabric Network

A full multi-organization Hyperledger Fabric network was configured from scratch. The network topology consists of:

- 1 Orderer node (`orderer.example.com`) — handles consensus and transaction ordering via Raft
- 4 Peer nodes across 2 organizations:
  - `peer0.org1.example.com` (port 7051)
  - `peer1.org1.example.com` (port 8051)
  - `peer0.org2.example.com` (port 9051)
  - `peer1.org2.example.com` (port 10051)
- 1 CLI container — administrative gateway for channel creation, chaincode deployment, and ledger queries

Key configuration files:

- `docker-compose.yaml` — defines all node containers with environment variables, volume mounts, TLS paths, and port mappings
- `crypto-config.yaml` — defines the organizational structure (2 peer orgs, 2 peers each, 1 admin user each) for the `cryptogen` tool
- `configtx.yaml` — defines the system genesis block (TwoOrgsOrdererGenesis profile) and application channel (TwoOrgsChannel profile)

Network was successfully launched and verified with `docker-compose up -d` and log inspection confirming all components operational.

### 6.2 Sample Chaincode Deployment

A sample chaincode (`PQCreddy`) was deployed to confirm the network is functional. It consists of three files:

- `PQCreddy.js` (chaincode) — implements `createCredential`, `accreditIssuer`, `getCredential`, `getCredentialHistory`, `verifyAccreditation`, `getAccredited`
- `pqcClient.js` (PQC logic) — wraps `liboqs-node` to expose `genKeyPair()`, `sign()`, `verify()` for Dilithium3
- `server.js` (middleware) — Express.js REST API that bridges frontend requests with the Fabric network and PQC client

Since PQC algorithms cannot be integrated directly into chaincode, a middleware layer handles the PQC operations before submitting transactions to the Fabric network.

### 6.3 PQC Algorithm & IPFS Integration

ML-DSA-44 (CRYSTALS-Dilithium) was tested end-to-end using `liboqs-go` bindings in a Dockerized Go environment. The Docker setup required compiling the underlying `liboqs` C library from source and configuring CGO with `pkg-config` to bridge Go and C.

**Execution flow tested:**

1. Initialize ML-DSA-44 signer via `liboqs-go`
2. Generate keypair → **1,312 bytes** public key
3. Sign a credential payload → **2,420 bytes** signature
4. Convert signature to hex, package with credential data as JSON
5. Upload to local IPFS node → returns CID (e.g., `QmSdJ1SK7ptTPJxs37NMdfecAEs42d2aQEcagpRXGGoawt`)
6. Store only the CID on-chain

**Result:** Signature payload reduced from 2,420 bytes to a 46-character CID — a 98%+ reduction in on-chain footprint.

Code is available in `offchain/`.

---

## 7. UI/UX Design

The Holder mobile wallet (Flutter) was designed with 14+ screens following human-interaction design principles. Key screens:

| Screen | Purpose |
| --- | --- |
| Splash Screen | App entry point, "Get Started" CTA |
| Onboard 1–3 | Explain app concept, confirm quantum-resistant keypair generation |
| Home | Dashboard — credential status overview (valid/suspended/revoked/expired), favourites, recent activity |
| Wallet | Categorized credential grid (Identity, Medical, Banking, Education, Government, Professional) |
| Document Stack | Browse all credentials in a category (stacked or list view) |
| Document Lookup | Quick summary — issuer, document number, dates, validity status |
| QR Presentation | Time-limited, single-use QR code for verification |
| Document Details | Full credential detail — credential ID, digital signature, blockchain anchor, CRYSTALS-Dilithium3 signature info |
| Selective Disclosure | Toggle individual fields visible/hidden before sharing |
| Add Document | Request new credentials from categorized issuers |
| Activity | Full interaction history |
| Settings | Security (biometric, PIN), backup/restore, theme, public key viewer |

---

## 8. Quality Alignment

Quality assurance overseen by Muhammed Nihal. All Phase 1 quality attributes from the Team Charter have been addressed:

| Attribute | Status | Notes |
| --- | --- | --- |
| Security | ✅ Met | NIST-standardized Dilithium selected; hash-on-chain architecture protects sensitive data |
| Functionality | ✅ Met | All Phase 1 deliverables complete; Dilithium operations demonstrated; 30+ use cases defined |
| Reliability | ✅ Met | GitHub CI/CD pipelines and Docker containers ensure consistent environments; cross-OS tested |
| Usability | ✅ Met | 14+ screens designed; heuristic evaluation conducted; supervisor-reviewed wireframes |
| Maintainability | ✅ Met | Modular design (middleware, PQC client, chaincode separation); version-controlled on GitHub |
| Transparency | ✅ Met | Cryptographic choices documented; all code publicly accessible; supervisor-reviewed |

---

## 9. Planned vs Actual Progress

As of March 1st, 2026 — 12 of 13 planned tasks are fully completed, 1 is 50% complete.

| Task | Status | Notes |
| --- | --- | --- |
| Literature Review & Planning (Jan 12–Feb 1) | ✅ Complete | On schedule; 12+ papers reviewed; core research gap identified |
| System Architecture (Feb 2–12) | ✅ Complete | 3 days late — supervisor refinement sessions |
| Users & Use Cases (Feb 6–18) | ✅ Complete | 2 days late — scope expanded to include Admin and Researcher roles |
| UI/UX Design (Feb 13–22) | ✅ Complete | 3 days late — extra screens added from stakeholder feedback; 14 screens finalized |
| Blockchain Server Setup (Feb 23–Mar 1) | ✅ Complete | On schedule; docker-compose.yaml and crypto-config.yaml operational |
| PQC Algorithm Setup | ✅ Complete | **Ahead of schedule** — started Feb 23, completed Mar 1; Dilithium + IPFS demonstrated |
| Transaction Structure Modification | 🔄 50% | Sample chaincode implemented; full modification continues in Phase 2 |
| Report 1 | ✅ Complete | Submitted March 1st as scheduled |

---

## 10. Next Steps (Phase 2: March 2 – March 29, 2026)

| Task | Owner | Target | Deliverable |
| --- | --- | --- | --- |
| Complete transaction structure modifications | Mohammed Obeid | March 8 | Updated transaction format + modified chaincode templates |
| Smart contract coding (Go) | Mohammed Obeid | March 22 | Full chaincode with unit tests |
| Frontend implementation (Flutter apps) | Mohammed Abdul Haris | March 22 | Functional Issuer Portal, Holder Wallet, Verifier Portal |
| PQC backend integration (custom CSP) | Mohammed Maqqavi | April 5 | Custom DilithiumCSP for Hyperledger Fabric |
| Backend integration (REST API) | Muhammed Nihal | March 29 | API endpoints for issuance, verification, revocation, status |
| Report 2 draft | All | March 29 | Draft ready for supervisor review |

**Key milestone:** First working prototype with PQC-integrated Fabric network by **April 5th**.

---

## 11. Bibliography

1. Rubia J, Jency & Lincy R, Babitha et al. (2024). A Survey about Post Quantum Cryptography Methods. *EAI Endorsed Transactions on Internet of Things.* doi:10.4108/eetiot.5099.
2. Y. Wang and E. Shahril Ismail (2025). A Review on the Advances, Applications, and Future Prospects of Post-Quantum Cryptography in Blockchain and IoT. *IEEE Access*, vol. 13, pp. 112962–112977. doi:10.1109/ACCESS.2025.3584473.
3. Gidney, Craig. (2025). How to factor 2048 bit RSA integers with less than a million noisy qubits. doi:10.48550/arXiv.2505.15917.
4. J. Gomes, S. Khan and D. Svetinovic (2023). Fortifying the Blockchain: A Systematic Review and Classification of Post-Quantum Consensus Solutions. *IEEE Access*, vol. 11, pp. 74088–74100. doi:10.1109/ACCESS.2023.3296559.
5. G. Alagic et al. (2025). Status Report on the Fourth Round of the NIST Post-Quantum Cryptography Standardization Process. NIST IR 8545. doi:10.6028/NIST.IR.8545.
6. R. Campbell (2026). Hybrid Post-Quantum Signatures for Bitcoin and Ethereum. *The Journal of the British Blockchain Association*, vol. 9, no. 1. doi:10.31585/jbba-9-1-(2)2026.
7. W. Beullens (2022). Breaking Rainbow Takes a Weekend on a Laptop. IACR Cryptology ePrint Archive, Report 2022/214. https://eprint.iacr.org/2022/214.pdf
8. I. Strugar and R. Bekić (2023). Performance and Applicability of Post-Quantum Digital Signature Algorithms in Resource-Constrained Environments. *Algorithms*, vol. 16, no. 11, p. 518. doi:10.3390/a16110518.
9. E. D. Demir and S. S. Kaya (2025). Performance Analysis and Industry Deployment of Post-Quantum Cryptography Algorithms. arXiv:2503.12952.
10. Zhang, Peijun et al. (2021). A Blockchain System Based on Quantum-Resistant Digital Signature. *Security and Communication Networks.* doi:10.1155/2021/6671648.
11. Perumal, Thanalakshmi et al. (2023). A Quantum-Resistant Blockchain System: A Comparative Analysis. *Mathematics*, vol. 11. doi:10.3390/math11183947.
12. Gan, Lu & Yokubov, Bakhtiyor (2022). A Performance Comparison of Post-Quantum Algorithms in Blockchain. *The Journal of The British Blockchain Association*, vol. 6. doi:10.31585/jbba-6-1-(1)2023.
13. QChain System Architecture — Notion. https://www.notion.so/QChain-System-Architecture-30a709b8676980468ab8c441faef1667
14. Open Quantum Safe Library. https://openquantumsafe.org/
15. QChain Users & Use Cases — Notion. https://www.notion.so/QChain-Users-Use-Cases-30a709b867698052a858d7f8a862ade1
16. Use Case Diagram — Draw.io. https://app.diagrams.net/#G1UV6ZiOiBkgWlOha7uwYbUUHMfO2Mf0f
17. GitHub Repository. https://github.com/nihvp/QChain-PQC-blockchain

---

**Last Updated:** 1st March 2026
