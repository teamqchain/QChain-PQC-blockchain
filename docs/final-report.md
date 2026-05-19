# QChain — Final Report

**Project:** Post-Quantum Cryptography in Blockchain Technology
**Submitted:** 27th April 2026
**Semester:** Spring 2025/2026
**Team:** Team 5M's (DESC × QChain)
**Supervisors:** Dr. Manar Abu Talib (Head), Dr. Sohail Abbas (Co-Supervisor)
**Committee:** Dr. Mian Ahmad Jan (Examiner), Dr. Ahmed Mohamed Khedr (Chair), Dr. Bouziane Brik

*A project submitted in partial fulfilment of the requirements for the degree of Bachelor of Science in Computer Science.*

---

## Team Members

| Name | Role | GitHub |
| ---  | --- | --- |
| Mohammed Bin Ali Maqqavi | Project Lead, Quantum Engineer | @M0hd-Maqqavi |
| Mohammed Abdul Haris | Frontend Developer, UI/UX Engineer | @mohammed-ah-14 |
| Muhammed Nihal Valiya Puthiyakath | Technical Lead, Software Engineer | @nihvp |
| Mohammed Hisham Obeid | Blockchain Engineer, Security Analyst | @MohammedObeid88 |

---

## Acknowledgement

We praise Allah for all the blessings He has bestowed upon us — for granting us the strength, patience, and dedication to complete this work, and for every challenge that strengthened our resolve along this journey.

We thank our families, friends, and colleagues for their unwavering support throughout the development of QChain. We extend our heartfelt appreciation to our supervisors, **Dr. Manar Abu Talib** and **Dr. Sohail Abbas**, for their continuous guidance, patience, and insightful feedback, and to **Prof. Qasim** for his invaluable support and contributions.

We are deeply grateful to the **Dubai Electronic Security Centre (DESC)** — especially **Dr. Bushra**, **Dr. Afra bin Fares**, **Hoor Arif**, and **Irine Corpuz** — for their valuable insights and constructive feedback. We also acknowledge **Ms. Omnia** for her support throughout the project.

---

## Abstract

The emergence of quantum computing poses a significant threat to classical cryptographic algorithms that underpin modern blockchain systems. Widely used schemes such as RSA and elliptic curve cryptography are expected to become vulnerable in the presence of large-scale quantum computers, compromising the security of blockchain-based applications. QChain addresses this challenge by designing and implementing a quantum-resistant blockchain framework that integrates post-quantum cryptographic (PQC) techniques into a permissioned blockchain environment.

QChain is developed on **Hyperledger Fabric** and incorporates lattice-based cryptographic algorithms — specifically **ML-DSA-44 (CRYSTALS-Dilithium)** — to provide secure digital signature mechanisms resistant to quantum attacks. The system adopts a hybrid architecture that combines on-chain storage for essential verification data with off-chain storage using the **InterPlanetary File System (IPFS)** to handle large cryptographic payloads efficiently.

The system supports three primary user roles — **issuers**, **holders**, and **verifiers** — and enables the complete lifecycle of digital credentials, including issuance, secure storage, verification, and revocation. A Go backend server manages blockchain interactions and cryptographic operations, while Flutter applications provide the user-facing experience.

The implementation was evaluated through functional testing, performance benchmarking, and security analysis. **All 13 unit and integration test cases passed successfully**, demonstrating the correctness and reliability of the system. Performance results indicate that PQC integration introduces manageable overhead, with verification operations achieving **sub-millisecond latency**. Security analysis confirms that the system effectively enforces access control and minimizes exposure of sensitive data.

Despite limitations — IPFS dependence and a fixed PQC algorithm in the current phase — the project demonstrates the practical feasibility of integrating post-quantum cryptography into blockchain systems and provides a foundational framework for future research and development in quantum-resistant distributed applications.

---

## 1. Introduction

### 1.1 Overview

The rapid advancement of quantum computing presents a significant challenge to existing cryptographic systems that secure modern digital infrastructures. Blockchain technology, which relies heavily on classical cryptographic algorithms for ensuring data integrity, authentication, and immutability, is particularly vulnerable to these emerging threats. QChain addresses this issue by integrating post-quantum cryptographic (PQC) techniques into a blockchain-based system.

QChain is designed as a quantum-resistant credential management system built on Hyperledger Fabric. It combines lattice-based cryptographic algorithms with a hybrid on-chain/off-chain storage model to ensure both security and scalability. The system supports multiple user roles — issuers, holders, and verifiers — and demonstrates a complete workflow for credential issuance, storage, and verification using PQC mechanisms.

### 1.2 Project Motivation

The primary motivation is the increasing threat posed by quantum computing to classical cryptographic algorithms such as RSA and ECC, which are widely used in blockchain systems. These algorithms are expected to become vulnerable once large-scale quantum computers become practical, compromising the security of existing blockchain networks.

Blockchain systems store long-term, immutable data, making them susceptible to the **"harvest now, decrypt later"** attack model, where data collected today can be decrypted in the future using quantum capabilities.

The key idea is to integrate lightweight lattice-based post-quantum cryptographic algorithms into a permissioned blockchain framework. Additionally, the system introduces a hybrid architecture that stores large cryptographic data off-chain using IPFS while maintaining essential verification data on-chain, addressing performance and scalability challenges.

### 1.3 Problem Statement

Current blockchain systems rely on classical cryptographic mechanisms that are not secure against quantum attacks. These vulnerabilities threaten the integrity, confidentiality, and authenticity of blockchain transactions and stored data.

Integrating post-quantum cryptography into blockchain systems introduces challenges such as increased key sizes, higher computational overhead, and scalability limitations. There is a need for a practical solution that ensures quantum resistance while maintaining system performance and usability.

### 1.4 Project Aim and Objectives

The main goal is to design, implement, and evaluate a prototype blockchain system that integrates post-quantum cryptographic algorithms to achieve quantum-resistant security.

Specific objectives:

- Implement lattice-based cryptographic algorithms (Dilithium) for secure digital signatures
- Modify Hyperledger Fabric components to support PQC-based operations
- Design a hybrid storage model using blockchain and IPFS
- Develop user applications for credential issuance, storage, and verification
- Evaluate system performance, security, and functionality through testing and benchmarking

### 1.5 Project Scope

The scope includes the design and implementation of a prototype system demonstrating the integration of PQC into a permissioned blockchain environment. The system covers:

- User applications for issuers, holders, and verifiers
- Backend server for blockchain interactions and cryptographic operations
- Integration of PQC algorithms using `liboqs`
- Modification of Hyperledger Fabric components to support PQC
- Hybrid storage using blockchain (on-chain) and IPFS (off-chain)

### 1.6 Project Software and Hardware Requirements

| Layer | Requirement |
| --- | --- |
| Blockchain | Hyperledger Fabric v2.5 |
| Backend | Go 1.23 |
| Frontend | Flutter framework |
| Containerization | Docker / Docker Compose |
| PQC Library | liboqs / liboqs-go |
| Off-Chain Storage | IPFS (Kubo) |

Hardware: a system capable of running Docker containers, supporting virtualization, and handling cryptographic computations efficiently.

### 1.7 Project Limitations

- Implemented as a prototype, not deployed in production
- Performance testing conducted in a virtualized environment (QEMU), which may not reflect real-world performance
- Current implementation uses a fixed PQC algorithm (ML-DSA-44), limiting crypto-agility
- Dependence on IPFS introduces potential data availability risks
- Private key handling currently involves server-side generation, with security implications

### 1.8 Project Expected Output

- A functional prototype of a PQC-enabled blockchain credential system
- A working integration of PQC algorithms into Hyperledger Fabric
- A hybrid storage model combining blockchain and IPFS
- Performance benchmarking and evaluation results
- Complete documentation and a structured codebase

### 1.9 Project Schedule

The project was executed following an **Agile methodology** with iterative development cycles and regular progress reviews. Tasks were organized into milestones: literature review, system design, implementation, testing, and evaluation. Weekly meetings and progress-tracking tools ensured timely completion. Full Gantt chart available in the Appendix.

### 1.10 Project, Product, and Schedule Risks

| Risk | Mitigation |
| --- | --- |
| Delays from complexity of PQC-blockchain integration | Iterative development, supervisor sync |
| Performance overhead from large PQC keys/signatures | Off-chain (IPFS) storage, AVX2 hardware |
| Dependence on external systems (IPFS) | Dedicated, pinned IPFS node |
| Learning curve for new cryptographic frameworks | Continuous coordination, pair coding sessions |

### 1.11 Success Metrics and Acceptance Criteria

**Success Metrics:**

| Metric | Description | Target | Measurement |
| --- | --- | --- | --- |
| Functional Correctness | All system features operate correctly | 100% test pass rate | Test suite execution |
| Performance | Verification latency | < 1 ms | Benchmark results |
| Security | Access control enforcement | No unauthorized access | Security tests |
| Usability | System usability | Acceptable workflow | Functional testing |

**Acceptance Criteria:**

- All core features (issuance, verification, revocation) function correctly
- All test cases pass successfully
- PQC algorithms are correctly integrated
- Documentation and implementation are complete

### 1.12 Project Governance

**Team Structure:** Project Lead (Quantum Engineer), Technical Lead (Software Engineer), Frontend Developer & UI/UX Designer, Blockchain Engineer & Security Analyst.

**Document and Version Control:** All artefacts — code and documentation — are managed using GitHub. Version control is handled through Git with structured collaboration and continuous integration practices.

---

## 2. Literature Review

Quantum computing poses an existential threat to classical public-key cryptosystems. RSA and Elliptic Curve Cryptography (ECC) derive their security from problems like integer factorization and the discrete logarithm — both solvable in polynomial time by Shor's algorithm on a sufficiently powerful quantum computer. Grover's algorithm additionally halves the effective security margin of symmetric schemes like AES and hash functions like SHA-256.

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

Twelve key papers were reviewed. The consensus is clear: classical cryptography is fatally vulnerable to quantum attacks. CRYSTALS-Dilithium offers the most balanced path forward. Storage and computational overhead remain the primary barriers to PQC adoption, pointing to off-chain mitigation and permissioned architectures as practical solutions.

A critical research gap was identified: **no existing Dilithium-based Crypto Service Provider (CSP) exists for Hyperledger Fabric** — which is the primary novel contribution of this project.

Full literature summary table with per-paper key insights and limitations is available in [`docs/literature-review.md`](./literature-review.md).

---

## 3. Architecture and Design

### 3.1 High-Level Overview

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

### 3.2 User Applications

| User Role | Application | Platform | Key Functions |
| --- | --- | --- | --- |
| Issuer | Issuer Portal | Flutter Web | Issue credentials, Revoke credentials, Manage identity |
| Holder | Holder Wallet | Flutter Mobile | Generate Dilithium keys, Receive credentials, Present credentials |
| Verifier | Verifier Portal | Flutter Web | Verify credentials, Query blockchain, Audit |

### 3.3 Backend Server (Go)

| Module | Responsibility |
| --- | --- |
| Fabric Client | Connect to Fabric network, submit transactions, query ledger |
| Identity Manager | Manage user identities, key registration |
| Credential Manager | Handle credential issuance and verification logic |
| Crypto Layer | PQC operations via liboqs-go |
| Crypto-Agility Controller | Switch between algorithms dynamically (Senior) |
| Verification Service | Verify signatures and credentials |

### 3.4 PQC Library Stack

| Layer | Technology | Purpose |
| --- | --- | --- |
| Application | Go Code | Calls crypto functions from application logic |
| Go Wrapper | liboqs-go | Provides Go bindings for liboqs |
| C Library | liboqs | Core PQC implementations (NIST standards) |
| Algorithms | Dilithium, Falcon | Signature schemes for quantum resistance |

### 3.5 Hyperledger Fabric & Custom CSP

| Component | Modification | Research Contribution |
| --- | --- | --- |
| Crypto Service Provider (CSP) | Add DilithiumCSP, FalconCSP, HybridCSP | **Primary contribution** |
| Membership Service Provider (MSP) | Extend to support PQC identities | Supporting |
| Peer Nodes | Use modified CSP for validation | Supporting |
| Orderer Nodes | Use modified CSP for consensus | Supporting |

### 3.6 Chaincode (Smart Contracts)

Smart contracts written in Go/JavaScript define the core business logic:

1. `RegisterIdentity(identityType, publicKey)` — register university or student identity
2. `IssueCredential(credentialHash, signature, studentID)` — issue credential with Dilithium signature
3. `VerifyCredential(credentialHash, signature, issuerID)` — verify credential authenticity
4. `RevokeCredential(credentialID)` — revoke an issued credential
5. `GetCredentialStatus(credentialID)` — check revocation status

### 3.7 Storage Model

| Data | Location | Rationale |
| --- | --- | --- |
| Credential hash | On-chain (Fabric) | Immutable, verifiable fingerprint |
| Issuer signature | On-chain (Fabric) | Proof of issuance |
| Student public key | On-chain (Fabric) | Identity binding for verification |
| Revocation status | On-chain (Fabric) | Fast revocation checks |
| Full credential document | Off-chain (IPFS) | Scalability, cost efficiency |
| Private keys | Client device | Self-sovereign identity principle |

### 3.8 Cryptographic Operations

Two cryptographic primitives ensure security:

- **SHA-256 Hashing** — data integrity
- **Dilithium Signatures** — quantum-resistant authentication and non-repudiation

**Cryptographic Flow:**

1. Credential document is generated
2. Document is hashed using SHA-256
3. Hash is signed using Dilithium (via custom CSP)
4. Full document stored on IPFS → returns CID
5. Hash + Signature + CID stored on Fabric ledger

---

## 4. System Analysis

### 4.1 User Roles

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

### 4.2 Use Cases (Summary)

**Issuer use cases:** Register Issuer Identity, Issue Credential to Holder, Issue Credential Batch, Revoke Credential, Suspend/Restore Credential, View Issued Credentials, Update Credential (Re-issuance), Define Credential Schema.

**Holder use cases:** Register as Holder, Receive Credential, Accept Credential Manually, Present Credential for Verification, Share via Secure Link, View Credential Details, Check Credential Status, Export/Import Credential Backup.

**Verifier use cases:** Register as Verifier, Verify by QR Code, Verify by Manual Entry, Verify by Upload, Batch Verify, Verify with Policy Checks, View Verification History, Audit Trail Export, Subscribe to Status Changes.

**Admin use cases:** Deploy Fabric Network, Install/Upgrade Chaincode, Onboard New Organizations, Monitor Network Health, Manage Cryptographic Materials, Configure Consensus.

**Researcher use cases:** Run Performance Benchmarks, Compare Algorithm Performance, Measure Scalability, Analyze Storage Impact, Generate Paper Figures and Tables.

**Total: 30+ documented use cases** covering the complete credential lifecycle.

### 4.3 Use Case Diagram

QChain is built around three core actor roles: **Issuers** (organizations that create and sign credentials), **Holders** (individuals or entities that own and control their credentials), and **Verifiers** (parties that authenticate presented credentials). Supporting these are **System Administrators** (Fabric network management) and **Researchers** (performance benchmarking and analysis).

---

## 5. UI/UX Design

The QChain platform comprises four primary user surfaces: **QWallet** (Holder mobile app) and **QPortal** (Issuer, Verifier, and IT Admin web dashboards).

### 5.1 QWallet (Holder Mobile App)

The Holder mobile wallet (Flutter) was designed with 14+ screens following human-interaction design principles.

| Screen | Purpose |
| --- | --- |
| Home Screen | Dashboard — user's name, identity status, credential states (valid/suspended/revoked/expired) |
| Wallet Screen | Categorized credential grid (Identity, Medical, Banking, Education, Government, Professional) with search |
| Document Stack | Browse all credentials in a category (stacked or list view) |
| Document Lookup | Quick summary — issuer, document number, dates, validity status |
| Document Details | Full credential detail — credential ID, digital signature, blockchain anchor reference |
| Selective Disclosure | Toggle individual fields visible/hidden before sharing |
| QR Presentation | Time-limited, single-use QR code for verification with expiry timer |
| Add Document | Request new credentials from categorized issuers (government, education, banking, healthcare) |

### 5.2 QPortal: Issuer Dashboard

The Issuer Dashboard provides the primary workspace for issuing authorities, displaying key daily metrics (credentials issued today, unread alerts, upcoming expirations) and quick actions for credential creation, batch issuing, and schema management.

**Sub-screens:**

- **Single Issue** — guided 5-step process for authorizing a digital document for an individual recipient (template selection → recipient lookup → data entry → visual draft → cryptographic signing)
- **Batch Issue** — guided process for issuing credentials to up to **1,000 recipients** simultaneously via spreadsheet upload, with automatic validation
- **All Credentials** — complete searchable repository with filtering by ID/name/type/status, batch selection, and individual review
- **Credentials Details** — in-depth view including System & Holder Information, editable fields, reissue capability, and cryptographic info (Dilithium algorithm, signature hash, transaction ID, IPFS reference)
- **Credential History** — timeline-style audit trail of every administrative action with justifications
- **Revoke / Suspend Management** — dedicated workspace to invalidate, pause, or reinstate credentials post-issuance
- **Schemas** — central management hub for credential templates with archiving and strict deletion protocols
- **Schema Details** — dedicated editor for configuring schema data structure (fields, data types, required parameters)
- **Create New Schema** — guided 5-step workflow to define and anchor a new template to the blockchain

### 5.3 QPortal: Verifier Dashboard

The Verifier Dashboard introduces the credential validation workspace with performance metrics (successful verifications today, pending alerts) and quick options to scan, manually verify, or process batches.

**Sub-screens:**

- **Manual Verify** — three authentication methods: Credential ID, OTP (6-digit time-sensitive code), and Upload Document (PDF)
- **Batch Verify** — automated process for authenticating up to **500 credential records** in a single action with downloadable status reports
- **Scan** — primary real-time QR code authentication tool with error handling and automated cryptographic policy checks
- **Verification History** — complete searchable audit log tracking date, time, holder, method, staff member, and result
- **Verification Details** — dedicated review mode to safely revisit past verification events with export function
- **Policy** — centralized management hub for custom verification rules (e.g., "must be issued after 2020")
- **Policy Details** — in-depth configuration view with toggleable rules and editability
- **Create New Policy** — builder interface to establish custom rules from scratch
- **Add Policy** — dynamic selection (max 3 policies per active verification)
- **Subscription** — consent-based mechanism to continuously track third-party credentials
- **Subscriptions Alert** — real-time notification center for status changes (suspensions, revocations, reissuances, tampering)
- **Add New Subscription** — initiates monitoring requests requiring holder consent

### 5.4 QPortal: IT Admin Dashboard

The IT Admin Dashboard provides the central control panel for system administration, displaying active staff distribution, the active cryptographic algorithm, the organization's DID, and a "Recent Audit Activity" log.

**Sub-screens:**

- **Manage Profile** — central workspace for defining the organization's digital identity (name, logo, type, country)
- **Staff & Permissions** — central access control hub categorizing personnel into Issuer/Verifier roles
- **Manage Staff & Permissions** — Invite Staff Member (organization-linked email + portal/role assignment) and Edit Staff Member (transition between portals, modify permissions, revoke access)
- **Crypto Settings** — visibility/control over signing algorithm (Dilithium); changes apply only to future issuances; displays Organization's Public Key with copy function
- **Audit Log** — append-only, read-only, tamper-evident ledger of all actions (logins, issuances, policy changes, verifications) with timestamps, identity, role, and IP
- **Request Additional Capabilities** — formal channel to apply for additional permissions (e.g., adding Verifier access for an Issuer-only org)
- **New Request** — guided 4-step application process (capability selection → category & use case → upload signed letter → summary)

---

## 6. Implementation Plan

### 6.1 Description of Implementation

The QChain system is a quantum-resistant credential verification platform built on Hyperledger Fabric, integrating **CRYSTALS-Dilithium (ML-DSA-44)** via the Open Quantum Safe (OQS) library. Implementation is organized into three principal components: the Hyperledger Fabric blockchain network, the Go-based off-chain backend server, and the IPFS integration for decentralized off-chain document storage.

The system follows a **hash-on-chain, full-data-off-chain** architectural model. When a credential is issued, the full document is uploaded to IPFS, returning a Content Identifier (CID). Only this CID — along with the ML-DSA-44 digital signature and the holder's public key — is stored on the Fabric ledger.

Implementation was carried out in iterative Agile phases: (1) Hyperledger Fabric network setup + test chaincode deployment, (2) production chaincode (JavaScript) + Go backend server with PQC integration, (3) IPFS integration + end-to-end credential workflow validation.

### 6.2 Programming Language and Technology

| Layer | Technology | Purpose |
| --- | --- | --- |
| Blockchain Network | Hyperledger Fabric v2.5 | Permissioned distributed ledger |
| Consensus Mechanism | Raft (etcdraft) | Fault-tolerant ordering service |
| State Database | CouchDB 3.3 | Rich JSON query support for credentials |
| Smart Contracts | JavaScript (Node.js) | Chaincode business logic |
| Backend Server | Go 1.23 | REST API, PQC operations, IPFS client |
| PQC Library | liboqs-go (ML-DSA-44) | Quantum-resistant signature operations |
| Off-Chain Storage | IPFS (Kubo) | Decentralized document storage |
| Containerization | Docker / Docker Compose | Environment consistency |
| Client Applications | Flutter (Dart) | Cross-platform Issuer, Holder, Verifier UIs |

**Rationale:** Go was selected for native Fabric Gateway SDK support, concurrency primitives, and CGO compatibility with liboqs-go. JavaScript (Node.js) was used for chaincode due to Fabric's first-class `fabric-contract-api` support. **ML-DSA-44** was selected for its balance of NIST Security Level 2 and performance characteristics.

### 6.3 Implementation Components

#### 6.3.1 Hyperledger Fabric Network Setup

The network was instantiated using Docker Compose with two peer organizations — **GovernmentMSP** and **GeneralMSP** — and a single Raft-based ordering service node. **CouchDB** was configured as the state database for both peer nodes to enable rich JSON queries (used by `getCredentialsByHolder`).

The network was provisioned using **Fabric CA** servers (one per organization plus one for the orderer) via the `fabric-ca-client enroll` workflow. MSP directories, TLS certificates, and identity wallet files are organized under `qchain-network/crypto-material/` and mounted into Docker containers at runtime.

Application channel `mychannel` was created using the `TwoOrgsChannel` profile, and the QChaincode was packaged, installed, approved, and committed following the Fabric v2 chaincode lifecycle. The `docker-compose.yaml` in `qchain-network/docker/` defines the complete network topology, with all services communicating via the shared `fabric_net` Docker network.

#### 6.3.2 Smart Contract (Chaincode) Implementation

On-chain business logic is implemented in `qchain-network/chaincode/QChaincode.js`. The chaincode extends Fabric's `Contract` base class and defines six transaction functions.

| Function | Access Role | Description |
| --- | --- | --- |
| `registerHolder` | None | Registers a new holder identity on the ledger |
| `issueCredential` | Issuer | Issues a credential with PQC public key |
| `verifyCredential` | Verifier | Verifies credential authenticity and status |
| `revokeCredential` | Issuer | Revokes an active credential |
| `setCID` | Issuer | Anchors IPFS CID to on-chain credential |
| `getCredentialsByHolder` | None | Retrieves all credentials for a given holder |

Access control uses Fabric's **attribute-based access control (ABAC)**, requiring `role=issuer` or `role=verifier` attributes in the invoking identity's enrollment certificate. The `verifyCredential` function performs a **dual-validation check** (public key match + active status). The `revokeCredential` function nullifies the stored public key on revocation, preventing further verification.

#### 6.3.3 Go Backend Server

The backend (`offchain/server.go`) acts as the integration layer between clients, the Fabric network, liboqs-go, and IPFS. It exposes a RESTful HTTP API on port 3000 using Go 1.22's pattern-based router.

**Configuration & Path Resolution.** Fully configurable via environment variables. Path helpers (`mspDir`, `walletDir`, `connectionProfilePath`) derive paths from `NETWORK_ROOT`, enabling Docker volume-mounting without code changes.

**Identity Loading & Fabric Gateway Connection.** `loadWalletIdentity` reads `.id` files (Fabric Node.js SDK format) containing the PEM-encoded certificate and private key. `getContract` establishes a gRPC connection to the peer with TLS, constructs an X.509 identity, derives a signing function, and connects the Fabric Gateway client.

**PQC Operations.** Three helpers — `pqcGenKeyPair`, `pqcSign`, `pqcVerify` — instantiate `oqs.Signature` with the ML-DSA-44 algorithm identifier. Keys are generated fresh per issuance; results are hex-encoded for safe JSON serialization.

**IPFS Integration.** `uploadDocumentAndSign` uploads documents to IPFS via `go-ipfs-api`, receives a CID, signs the CID with the ML-DSA-44 private key, packages document CID + signature + public key into a JSON payload, and uploads this verification payload to IPFS. The final CID is anchored on-chain via `setCID`.

**REST API Endpoints:**

| Endpoint | Method | Description |
| --- | --- | --- |
| `/registerHolder` | POST | Registers a new credential holder |
| `/issueCredential` | POST | Generates ML-DSA-44 keypair and issues credential |
| `/verifyCredential` | POST | Verifies credential on-chain and via PQC |
| `/revokeCredential` | POST | Revokes an active credential |
| `/setCID` | POST | Anchors an IPFS CID to a credential |
| `/getCredentialsByHolder` | GET | Retrieves all credentials for a holder |
| `/uploadDocument` | POST | Uploads document to IPFS and anchors CID |
| `/health` | GET | Returns server health status |

Private keys are returned at issuance only — **never stored server-side** — consistent with the self-sovereign identity principle.

#### 6.3.4 Docker Build and CGO Integration

A **multi-stage Dockerfile** (`offchain/Dockerfile`) handles compiling liboqs within a containerized Go environment. The **builder stage** installs C build tools (`cmake`, `ninja-build`, `libssl-dev`), clones liboqs from GitHub, compiles it as a shared library, generates `liboqs-go.pc` for CGO `pkg-config`, and sets `LD_LIBRARY_PATH`. The **runtime stage** uses `debian:bookworm-slim` and copies only the compiled binary + shared library, resulting in a significantly smaller final image.

#### 6.3.5 End-to-End Credential Workflow

1. Issuer sends `POST /issueCredential` with holder ID and credential info
2. Backend generates ML-DSA-44 keypair and signs the credential payload
3. Backend submits `issueCredential` transaction to Fabric, storing the credential record
4. Backend returns credential ID, public key, private key, and signature to the Issuer
5. Issuer uploads the full document via `POST /uploadDocument`; backend uploads to IPFS, signs the CID, and calls `setCID`
6. For verification, Verifier sends `POST /verifyCredential` with the credential ID, signed message, signature, and public key
7. Backend evaluates `verifyCredential` on Fabric (public key match + active status), then performs local ML-DSA-44 signature verification
8. Returns `verified: true` or `verified: false`

---

## 7. Verification, Validation, and Evaluation

### 7.1 Test Strategy

The V&V strategy is structured across two complementary layers: **unit and integration testing** of the Go backend, and **algorithmic performance benchmarking** of ML-DSA-44.

Tests live in `offchain/server_test.go` and execute inside the Docker container, ensuring tests run against the actual liboqs-go C bindings and the compiled ML-DSA-44 implementation rather than stubs.

Benchmarks live in `algo-benchmarking/`: `go-bindings/` (liboqs-go) and `go-native/` (Cloudflare CIRCL), comparing performance across NIST security levels 44, 65, and 87.

#### 7.1.1 Unit and Integration Test Suite

The test suite covers eight test groups across 13 test cases:

| Test Case | Sub-Cases | Result | Duration |
| --- | --- | --- | --- |
| `TestGetEnv` | — | PASS | 0.00s |
| `TestPathHelpers` | — | PASS | 0.00s |
| `TestLoadWalletIdentity` | success, missing file, invalid json, missing certificate, missing private key | PASS (5/5) | 0.00s |
| `TestPQCSignVerifyRoundTrip` | — | PASS | 0.00s |
| `TestPQCDecodeFailures` | — | PASS | 0.00s |
| `TestWriteHelpers` | — | PASS | 0.00s |
| `TestDecodeBody` | — | PASS | 0.00s |
| `TestHandlersValidationAndHealth` | 9 sub-cases | PASS (9/9) | 0.00s |
| **Total** | **13 test cases** | **PASS** | **0.009s** |

**All 13 test cases passed**, executed via `docker run --rm qchain-tester:latest go test -v ./...`. This confirms the container image includes all necessary dependencies, liboqs-go bindings are correctly linked, and core logic, PQC operations, and HTTP validation behave as specified.

Highlights:

- `TestPQCSignVerifyRoundTrip` validates the complete PQC workflow (keygen, sign, verify) **and includes a tamper detection check** — verifying the signature against a modified message correctly returns `false`
- `TestLoadWalletIdentity` covers five real-world failure modes encountered during Fabric Gateway integration
- `TestHandlersValidationAndHealth` is table-driven and exercises input validation for all 8 API endpoints

#### 7.1.2 Algorithm Performance Benchmarks

Benchmarks measure four operations — **Key Generation**, **Signing**, **Verification**, and **Total Workflow** — using Go's `testing.B` framework.

**Consolidated ML-DSA Performance (ms/op):**

| Implementation | Algorithm | Key Gen | Signing | Verification | Total Workflow |
| --- | --- | --- | --- | --- | --- |
| liboqs-go | ML-DSA-44 | 0.041 | 0.091 | 0.037 | 0.167 |
| liboqs-go | ML-DSA-65 | 0.071 | 0.147 | 0.064 | 0.280 |
| liboqs-go | ML-DSA-87 | 0.122 | 0.212 | 0.133 | 0.438 |
| CIRCL (go-native) | ML-DSA-44 | 0.085 | 0.196 | 0.034 | 0.321 |
| CIRCL (go-native) | ML-DSA-65 | 0.153 | 0.373 | 0.046 | 0.513 |
| CIRCL (go-native) | ML-DSA-87 | 0.228 | 0.520 | 0.065 | 0.621 |

**Key observations:**

1. **Verification is the fastest operation** across all configurations — critical for QChain since verifiers perform one verification per transaction. Sub-0.1 ms latency is well within acceptable bounds for interactive use.
2. **Signing is consistently the most expensive operation** — acceptable since issuance is infrequent relative to verification.
3. **CIRCL achieves faster signing at ML-DSA-44** but slower key generation than liboqs-go, reflecting different internal optimizations.
4. **Performance degradation across security levels (44 → 65 → 87)** is gradual and predictable — confirming ML-DSA-65 as a reasonable compromise.

The QEMU virtual CPU used during testing lacks AVX2 support; production performance on AVX2-enabled hardware would be proportionally faster.

### 7.2 Security and Privacy Checks

#### 7.2.1 Identified Risks

| Risk | Severity | Mitigation |
| --- | --- | --- |
| Private key transmission in API response | Medium | TLS-only communication; planned migration to client-side generation |
| IPFS node unavailability | Medium | Dedicated pinned IPFS infrastructure; organizational hosting |
| CA compromise enables unauthorized issuance | High | Per-organization CA isolation; Fabric MSP separation |
| Algorithm deprecation requiring credential re-issuance | Medium | Crypto-agility controller (planned for senior phase) |
| Replay attacks on credential presentation | Low | Nonce-based holder signature in QR presentation |

**Notes:**

- **Private Key Transmission Risk** — the `/issueCredential` response includes the ML-DSA-44 private key in plaintext. This is a deliberate Phase 1 design choice; the server never persists it. Mitigation: migrate key generation to the Holder's mobile device in the senior project phase.
- **Chaincode Access Control Dependency** — `issueCredential` and `revokeCredential` enforce ABAC via `role=issuer`. Compromise of the CA would enable fraudulent issuance — mitigated by per-organization CA isolation (GovernmentCA, GeneralCA).
- **Algorithm Agility Risk** — hardcoded to ML-DSA-44. A NIST deprecation (analogous to the Rainbow break) would require coordinated upgrades. Addressed by the planned crypto-agility controller.

#### 7.2.2 Data Protection Measures

- **On-Chain Data Minimization** — only credential hash, ML-DSA-44 public key, issuer signature, revocation status, and IPFS CID are stored on Fabric. Full credentials (with PII) live exclusively on IPFS.
- **Role-Based Access Control** — the `checkAccess` function is called at the start of `issueCredential`, `verifyCredential`, `revokeCredential`, and `setCID`. Unauthorized callers receive "Access denied" and the transaction is not committed.
- **Credential Revocation** — revocation permanently nullifies the stored public key (`Credential.PublicKey = null`) in addition to setting status to `revoked`, defending against cached-key attacks.
- **TLS Encryption** — all peer-to-peer and orderer communications use mutual TLS with certificates from each organization's Fabric CA. Backend connects to peers over gRPC with TLS credentials.
- **Private Key Non-Persistence** — the backend does not log or persist ML-DSA-44 private keys at any point; keys are generated, used, returned in the response, and discarded when the handler returns.

### 7.3 Evaluation Summary

**Functional Correctness.** All 13 unit and integration tests pass, covering both happy paths and common failure modes (missing wallet files, malformed JSON, invalid cryptographic inputs, missing parameters).

**Performance.** ML-DSA-44 achieves **sub-millisecond verification latency** (0.037 ms under liboqs-go, 0.034 ms under CIRCL) and a total workflow time of ~0.167 ms — well within the envelope required for interactive credential verification. Observed overhead is attributable to the QEMU virtual CPU; AVX2-enabled hardware would deliver proportionally better results.

**Security.** The system correctly enforces role-based access control on all sensitive operations, minimizes the on-chain PII footprint via hybrid storage, and implements credential revocation in a cached-key-attack-resistant manner. Residual risks (private key transmission, IPFS availability) are acknowledged design trade-offs with clear mitigation paths planned for the senior project continuation.

---

## 8. Conclusion and Results

The QChain project successfully demonstrates the feasibility of integrating post-quantum cryptography into a blockchain-based system while maintaining acceptable performance and usability.

**Functional perspective.** All 13 unit and integration test cases passed successfully, confirming that the backend logic, cryptographic operations, and API validations operate as expected.

**Performance perspective.** ML-DSA-44 achieves efficient execution, with verification latency in the sub-millisecond range and total workflow execution times suitable for real-time credential verification. The selected lattice-based algorithm is practical for enterprise blockchain applications despite the inherent overhead of post-quantum cryptography.

**Security perspective.** The system enforces strong access control mechanisms, minimizes sensitive data stored on-chain, and implements secure credential revocation. The hybrid storage model effectively reduces blockchain data size while maintaining verifiability. Certain risks remain — IPFS dependency and private key handling — acknowledged as areas for future improvement.

Overall, the project achieves its primary objective of designing and evaluating a quantum-resistant blockchain framework. The results confirm that post-quantum cryptographic integration is feasible within permissioned blockchain environments, provided that appropriate architectural and performance considerations are addressed. The project also establishes a strong foundation for future work, including the implementation of **crypto-agility**, **client-side key generation**, enhanced security mechanisms, and deployment in real-world environments.

---

## 9. Bibliography

1. J. Rubia, B. Lincy, E. Nithila, S. Shibi and R. A. (2024). A Survey about Post Quantum Cryptography Methods. *EAI Endorsed Transactions on Internet of Things*, vol. 10.
2. Y. Wang and E. Shahril Ismail (2025). A Review on the Advances, Applications, and Future Prospects of Post-Quantum Cryptography in Blockchain and IoT. *IEEE Access*, vol. 13, pp. 112962–112977.
3. C. Gidney (2025). How to factor 2048 bit RSA integers with less than a million noisy qubits. arXiv:2505.15917 [quant-ph], May 2025.
4. J. Gomes, S. Khan and D. Svetinovic (2023). Fortifying the Blockchain: A Systematic Review and Classification of Post-Quantum Consensus Solutions for Enhanced Security and Resilience. *IEEE Access*, vol. 11, pp. 74088–74100.
5. G. Alagic et al. (2025). Status Report on the Fourth Round of the NIST Post-Quantum Cryptography Standardization Process. NIST, 11 March 2025. https://www.nist.gov/publications/status-report-fourth-round-nist-post-quantum-cryptography-standardization-process
6. R. Campbell (2025). Hybrid Post-Quantum Signatures for Bitcoin and Ethereum: A Protocol-Level Integration Strategy.
7. W. Beullens (2022). Breaking Rainbow Takes a Weekend on a Laptop. *Advances in Cryptology – CRYPTO 2022*, LNCS vol. 13508.
8. I. Strugar and R. Bekić (2023). Performance and Applicability of Post-Quantum Digital Signature Algorithms in Resource-Constrained Environments. *Algorithms*, vol. 16, no. 11, p. 518.
9. E. D. Demir, B. Bilgin and M. C. Onbasli (2025). Performance Analysis and Industry Deployment of Post-Quantum Cryptography Algorithms. arXiv:2503.12952 [cs.CR], March 2025.
10. P. Zhang, L. Wang, W. Kunlun, F. Wang and Jinpeng (2021). A Blockchain System Based on Quantum-Resistant Digital Signature. *Security and Communication Networks*, pp. 1–13.
11. T. Perumal, A. Rishikhesh, J. Marceline, G. P. Joshi and Woong Cho (2023). A Quantum-Resistant Blockchain System: A Comparative Analysis. *Mathematics*, vol. 11. doi:10.3390/math11183947.
12. L. Gan and B. Yokubov (2023). A Performance Comparison of Post-Quantum Algorithms in Blockchain. *The Journal of The British Blockchain Association*, vol. 6.
13. Open Quantum Safe Library. https://openquantumsafe.org/ (Accessed 26 April 2026).

---

## 10. Appendix

### 10.1 Gantt Chart

The project Gantt chart illustrates the timeline and progression of tasks throughout the development lifecycle — planning, design, implementation, testing, and documentation phases.

### 10.2 GitHub Repository

The complete source code — backend implementation, frontend applications, blockchain configuration, and documentation — is available at:

**GitHub:** https://github.com/nihvp/QChain-PQC-blockchain

### 10.3 Notion Workspace

Project management, task tracking, meeting notes, and collaboration artefacts were maintained in Notion:

**Notion:** https://www.notion.so/Post-Quantum-Cryptography-for-Blockchain-Technology-2ff709b86769800991ffe7840fa715b0

---

**Last Updated:** 27th April 2026
