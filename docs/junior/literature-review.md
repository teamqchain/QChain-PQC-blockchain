# QChain — Literature Review

**Topic:** Post-Quantum Cryptography in Blockchain Technology  
**Compiled by:** Mohammed Bin Ali Maqqavi, Mohammed Hisham Obeid, Muhammed Nihal , Mohammed Abdul Haris  
**Supervised by:** Dr. Manar Abu Talib, Dr. Sohail Abbas
**Last Updated:** 1st March 2026

> Full interactive database: https://muhammed.me/QChain-PQC-blockchain/

---

## Overview

The rapid evolution of quantum computing introduces an existential threat to the cryptographic primitives that secure modern digital communication. Classical public-key cryptosystems — RSA and Elliptic Curve Cryptography (ECC) — derive their security from the computational intractability of integer factorization and the discrete logarithm problem. However:

- **Shor's algorithm**, when executed on a sufficiently powerful quantum computer, solves these problems in polynomial time — rendering classical asymmetric encryption obsolete.
- **Grover's algorithm** offers a quadratic speedup in unstructured search, effectively halving the security margin of symmetric schemes (AES) and hash functions (SHA-256).

Blockchain technology is especially exposed. Because blockchain ledgers are inherently immutable and transparent, historical data signed with classical algorithms remains permanently recorded and susceptible to future quantum decryption — the **"harvest now, decrypt later"** attack model.

In response, NIST initiated a comprehensive standardization process to identify quantum-resistant algorithms, collectively known as **Post-Quantum Cryptography (PQC)**.

This literature review synthesizes current research on PQC integration into distributed ledger technologies. It evaluates the performance trade-offs of NIST-standardized algorithms, examines the storage and governance challenges of their implementation, explores IPFS as a mitigation strategy, and analyzes the specific architectural pathways required to implement PQC within enterprise permissioned environments like Hyperledger Fabric.

---

## 1. The Quantum Threat to Blockchain

### 1.1 Why Blockchain is Particularly Vulnerable

Blockchain technology relies entirely on decentralized consensus mechanisms, digital signatures, and cryptographic hashing to maintain ledger immutability and asset ownership. This makes it exceptionally vulnerable to the quantum paradigm shift:

- **Digital signatures** (ECDSA, RSA) are directly broken by Shor's algorithm
- **Immutability** becomes a liability — once data is on-chain, it cannot be removed, meaning historical transactions remain permanently exposed
- **Transparency** means adversaries can collect encrypted/signed data today and decrypt it once quantum computers mature

### 1.2 Timeline Estimates

Recent research (Gidney, 2025) demonstrated a substantial reduction in the estimated number of qubits required to factor 2048-bit RSA integers — estimating that a quantum computer using under one million noisy qubits could factor RSA-2048 in less than a week. Qubit count reductions were achieved through approximate residue arithmetic, yoked surface codes, and magic state cultivation.

IBM Quantum Roadmaps and Google Quantum AI research project that logical qubits are on an exponential growth trajectory, with the RSA-2048 security threshold (~1,000 logical qubits) potentially reachable around 2033.

> **Implication:** The threat is not theoretical. Organizations must begin transitioning now to avoid retroactive compromise of data already on immutable ledgers.

---

## 2. Post-Quantum Cryptographic Families

NIST evaluated several mathematical families of quantum-resistant algorithms. For blockchain applications, the primary focus centers on lattice-based, hash-based, code-based, and multivariate cryptosystems.

### 2.1 Lattice-Based Cryptography

Lattice-based cryptography derives its security from the hardness of the **Shortest Vector Problem (SVP)** and the **Learning With Errors (LWE)** problem within multi-dimensional periodic grids. These NP-hard problems are currently considered intractable for both classical and quantum computers.

NIST has standardized two primary lattice-based signature schemes:

---

#### CRYSTALS-Dilithium (ML-DSA)

Dilithium uses the "Fiat-Shamir with Aborts" technique over module lattices.

**Advantages:**
- Implementation simplicity — relies on uniform sampling, avoids complex floating-point arithmetic
- Less prone to side-channel vulnerabilities
- Highly suitable for general-purpose applications
- Best balance of security and performance for most deployment scenarios

**Drawbacks:**
- Produces relatively large signatures (~3,293 bytes) and public keys (~1,952 bytes)
- Critical drawback for bandwidth-constrained blockchains

**Why we chose it:** Dilithium's simplicity and balanced performance profile make it the most practical choice for enterprise blockchain integration. Its resistance to side-channel attacks is especially important given that Fabric nodes run in shared infrastructure environments.

---

#### Falcon (FN-DSA)

Falcon operates over NTRU lattices using the Gentry-Peikert-Vaikuntanathan framework with fast Fourier sampling.

**Advantages:**
- Most compact signatures among lattice candidates (~666 bytes for Falcon-512)
- Exceptionally fast signature verification — theoretically ideal for high-throughput transaction processing

**Drawbacks:**
- Highly complex implementation — requires 64-bit floating-point Gaussian sampling
- Significant risk of side-channel attacks and subtle implementation flaws that could inadvertently leak the secret key
- Not recommended for general-purpose deployment without dedicated hardware

---

### 2.2 Hash-Based Cryptography

#### SPHINCS+ (SLH-DSA)

SPHINCS+ relies entirely on the well-understood security properties of cryptographic hash functions (collision and preimage resistance) rather than novel algebraic structures.

**Advantages:**
- Highly conservative and immune to future breakthroughs in lattice cryptanalysis
- Security assumptions are the most well-established of all PQC families

**Drawbacks:**
- Catastrophic performance metrics in blockchain contexts
- Generates massive signatures (~7,856 bytes for the 128s parameter set)
- Requires millions of CPU cycles for signing and verification
- Largely impractical for base-layer ledger processing

---

### 2.3 Code-Based Cryptography

#### Classic McEliece

Code-based cryptography relies on the difficulty of decoding random linear error-correcting codes.

**Advantages:**
- Highly secure and efficient in processing speed
- Security assumptions have held for decades

**Drawbacks:**
- Requires massive public keys exceeding 260 kilobytes
- Entirely unviable for blockchain applications

---

### 2.4 Multivariate Cryptography

Multivariate schemes rely on solving systems of non-linear quadratic equations over finite fields.

**Advantages:**
- Very short signatures

**Drawbacks:**
- Require enormous public keys
- **Rainbow** — a former NIST finalist — was defeated by classical cryptanalysis in 2022 (Beullens, IBM Research). Full secret key recovery for Security Level 1 parameters was achieved in approximately 53 hours on a standard laptop. This highlights the fragility of multivariate assumptions and led to Rainbow's rejection by NIST.

---

## 3. Performance Comparison of Standardized Algorithms

Vidakovic et al. (2023) benchmarked CRYSTALS-Dilithium, Falcon, and SPHINCS+ across key metrics for resource-constrained environments including IoT and blockchain.

### 3.1 Signature Scheme Comparison

| Algorithm | Security Level | Public Key Size | Signature Size | Verification Time | Notes |
| --- | --- | --- | --- | --- | --- |
| ECDSA (secp256k1) | 128-bit Classical | 33 bytes | 71 bytes | ~0.80 ms | Highly efficient; vulnerable to Shor's algorithm |
| CRYSTALS-Dilithium-3 | NIST Level 2/3 | 1,952 bytes | 3,293 bytes | ~1.50–2.4 ms | Balanced security; simple implementation; large payload |
| Falcon-512 | NIST Level 1 | 897 bytes | 666 bytes | ~0.22 ms | Compact and fast; risky floating-point implementation |
| SPHINCS+ (128s) | NIST Level 1/3 | 32 bytes | 7,856 bytes | ~12.30 ms | Conservative security; prohibitively large and slow |
| McEliece | NIST Level 3 | ~261,000 bytes | 1.3 KB | N/A | Impractically large public keys for distributed ledgers |

### 3.2 Context-Specific Findings

- **Dilithium** excels as a general-purpose algorithm for low-power and enterprise scenarios due to balanced performance
- **Falcon** offers the fastest verification and most compact signatures among lattice schemes — good for dedicated validator nodes with controlled hardware
- **SPHINCS+**, despite offering the most robust security profile, incurs massive computational costs that render it impractical for high-throughput blockchains
- **Algorithm selection must be context-dependent** — weigh hardware capabilities of nodes against network throughput requirements

### 3.3 Radar Profile Summary

Evaluated across five dimensions (Verification Speed, Signing Speed, Public Key Size, Signature Size, Implementation Ease):

- **Dilithium** — strong across all dimensions; best all-rounder
- **Falcon** — strongest on verification speed and signature size; weakest on implementation ease
- **SPHINCS+** — weakest on all performance dimensions; strongest on security conservatism

---

## 4. Blockchain Consensus in the Quantum Era

Gomes et al. (2023) conducted a systematic analysis of 29 key studies addressing the critical vulnerabilities of traditional consensus protocols (Proof of Work, PBFT, Raft) against quantum threats.

### 4.1 Classification of PQBC Solutions

Post-Quantum Blockchain Consensus (PQBC) solutions were classified into six categories:

| Category | Description |
| --- | --- |
| Quantum Random Number (QRN) based | Improves fairness in consensus randomness |
| Quantum entanglement & measurement based | Uses quantum mechanical properties for consensus |
| Quantum key distribution (QKD) based | Leverages QKD channels for secure consensus |
| Quantum distributed processing based | Distributes quantum computation across nodes |
| Lattice-based consensus | Uses lattice problems for verification — faster but high memory costs |
| Multivariate polynomial equations based | Based on systems of equations; less mature |

### 4.2 Key Findings

- QRN approaches improve fairness; lattice-based models offer faster verification but may incur exponential memory costs
- Most existing solutions prioritize security and throughput **over anonymity/privacy**
- Migrating current systems to quantum-secure architectures is logistically complex — a "quantum-empowered hard fork" is the most viable but difficult transition strategy
- Future PQBC development must integrate **quantum zero-knowledge proofs** to resolve privacy limitations while maintaining liveness and correctness

### 4.3 Membership Service Provider Implications

The paper also discusses MSP implications for permissioned blockchains — transitioning Fabric's MSP to PQC requires replacing the native ECDSA-based PKI at the identity layer, which affects every stage of the transaction lifecycle (endorsement, ordering, validation).

---

## 5. IPFS Integration & Off-Chain Storage

### 5.1 The Storage Problem

PQC signatures are 10–100x larger than their classical counterparts. Storing these directly on-chain causes:

- **Blockchain bloat** — rapidly growing ledger state
- **Reduced throughput** — larger transactions slow block processing
- **Higher storage costs** — every node must store the full ledger
- **Network propagation delays** — larger blocks take longer to propagate

### 5.2 IPFS as a Solution

IPFS (InterPlanetary File System) is a decentralized, peer-to-peer hypermedia protocol using content addressing. When data is uploaded to IPFS, it is assigned a unique, fixed-length cryptographic hash identifier (CID). Any alteration to the data fundamentally changes the hash.

**The hybrid model:**
1. Generate large PQC public key and digital signature
2. Upload these to the IPFS network
3. IPFS returns a compact 32-byte CID
4. Embed only the CID into the blockchain transaction

**Validation process:**
1. Extract the 32-byte IPFS CID from the transaction
2. Query the IPFS network to retrieve the original PQC public key and signature
3. Perform cryptographic verification locally
4. If valid, append the transaction to the ledger (containing only the 32-byte hash)

### 5.3 Results (Zhang, 2021; Perumal et al., 2023)

Integrating IPFS with SPHINCS+ or Dilithium reduces the on-chain signature footprint by **more than 99%**, compressing payloads of several kilobytes down to a uniform 32 bytes. Block mining times and transaction propagation latency are significantly reduced as a result.

**Our own test results (ML-DSA-44 + IPFS):**

| Metric | Value |
| --- | --- |
| Generated public key size | 1,312 bytes |
| Generated signature size | 2,420 bytes |
| On-chain footprint (CID) | ~46 characters |
| Footprint reduction | ~98% |

### 5.4 Trade-offs

| Benefit | Trade-off |
| --- | --- |
| 99%+ reduction in on-chain footprint | Added network latency during verification (IPFS retrieval) |
| Reduced block sizes → higher throughput | Data unavailability risk if IPFS nodes go offline |
| Cost efficiency for credential storage | Increased architectural complexity |
| Privacy-friendly (full data off-chain) | Requires reliable IPFS pinning infrastructure |

---

## 6. Implementing PQC in Hyperledger Fabric

### 6.1 Why Hyperledger Fabric

While public permissionless networks (Bitcoin, Ethereum) face catastrophic centralization risks due to PQC state bloat, enterprise-grade permissioned networks like Hyperledger Fabric present a more viable landscape for immediate integration:

- **Controlled infrastructure** — administrators can provision AVX2-enabled processors and high-capacity storage
- **Execute-Order-Validate architecture** — deterministic transaction processing with high performance and scalability
- **Membership Service Provider** — identity framework that can be modified to support PQC algorithms
- **Customizable CSP** — pluggable cryptographic service provider layer

### 6.2 The MSP Challenge

Access control and identity management in Hyperledger Fabric are governed by:
- **Membership Service Provider (MSP)** — manages identities and policies
- **Fabric Certificate Authority (Fabric CA)** — issues X.509 certificates, natively using ECDSA over NIST P-256

Transitioning Fabric to a quantum-resistant state requires **deep modifications to the MSP** to support algorithms like Dilithium and Falcon. Digital signatures must be generated and verified at multiple stages:

1. Client proposing the transaction
2. Endorser peers simulating the transaction
3. Orderer sequencing the block
4. Committing peers validating the entire payload

Each of these stages multiplies the cryptographic overhead.

### 6.3 Integration via Open Quantum Safe (OQS)

Current implementation research achieves PQC integration in Fabric by integrating the **Open Quantum Safe (OQS)** library:

- **libOQS** — open-source C library designed for prototyping quantum-resistant algorithms
- Integrated into Fabric's Go-based architecture using **CGO wrappers**
- **liboqs-go** — Go bindings that expose PQC operations to the backend server

### 6.4 Performance Impact in Fabric

| Configuration | Execution Time | Cryptographic Payload |
| --- | --- | --- |
| ECDSA (baseline) | ~4 ms/block | 96 bytes |
| Falcon-512 | ~18 ms/block | 1,563 bytes |
| Dilithium-3 | ~21 ms/block | 4,173 bytes |

These delays compound due to Fabric's multi-signature Endorser-Orderer-Committer requirements. However, permissioned networks are uniquely positioned to absorb these costs through provisioned enterprise infrastructure.

**Conclusion:** The integration of Dilithium into Hyperledger Fabric is highly practical, provided organizations are willing to provision the necessary computational overhead.

### 6.5 Identified Research Gap

After reviewing all available literature, no existing **Dilithium-based Crypto Service Provider (CSP) implementation for Hyperledger Fabric** was found. This represents the primary novel research contribution of QChain.

---

## 7. Literature Summary Table

| Ref | Paper Title | Year | Publisher | Key Insights | Limitations |
| --- | --- | --- | --- | --- | --- |
| [1] | A Survey about Post Quantum Cryptography Methods | 2024 | EAI Endorsed Transactions on IoT | Categorization of PQC families; lattice-based as most promising for constrained environments | Broad survey; lacks deep blockchain-specific benchmarking |
| [2] | A Review on the Advances, Applications, and Future Prospects of Post-Quantum Cryptography in Blockchain and IoT | 2025 | IEEE Access | NIST vs ETSI standards analysis; framework for secure transition; hybrid ECC+PQC approach | Dual-signing in hybrid frameworks significantly increases payload size |
| [3] | How to factor 2048 bit RSA integers with less than a million noisy qubits | 2025 | Quantum Journal | Substantial reduction in qubit estimates for RSA-2048 factoring; achievable in under a week | Relies on idealized hardware assumptions (0.1% gate error, 1μs cycle time) |
| [4] | Fortifying the Blockchain: A Systematic Review and Classification of Post-Quantum Consensus Solutions | 2023 | IEEE Access | Reviews PBFT and Raft in PQC context; 'Quantum-Ready' consensus protocols; MSP implications | Categorizes existing solutions but lacks novel empirical benchmarking |
| [5] | Status Report on the Fourth Round of the NIST PQC Standardization Process | 2025 | NIST | Lattice-based schemes (Kyber, Dilithium) as leading candidates; strong security guarantees | Strictly limited to four KEMs; does not cover digital signature evaluations |
| [6] | Hybrid Post-Quantum Signatures for Bitcoin and Ethereum | 2025 | The JBBA | Hybrid cryptographic frameworks; 50%+ throughput loss during transition; 'Defensive Downgrade' | Focused on permissionless chains; metrics may differ in permissioned environments |
| [7] | Breaking Rainbow Takes a Weekend on a Laptop | 2022 | IBM Research | Full secret key recovery for Rainbow SL1 in ~53 hours; defeats NIST PQC finalist | Purely classical attack; does not evaluate quantum adversary models |
| [8] | Performance and Applicability of Post-Quantum Digital Signature Algorithms in Resource-Constrained Environments | 2023 | MDPI (Algorithms) | Dilithium best balance for low-power devices; SPHINCS+ too heavy; Falcon excellent for validators | Focuses on resource-constrained environments, not high-performance enterprise nodes |
| [9] | Performance Analysis and Industry Deployment of Post-Quantum Cryptography Algorithms | 2025 | arXiv | AVX2 optimization significantly boosts PQC speed; Dilithium2/3/5 benchmarks; deployment hurdles | Hardware optimizations do not solve increased signature/key size and network transmission delays |
| [10] | A Blockchain System Based on Quantum-Resistant Digital Signature | 2021 | Hindawi (Security and Comm. Networks) | Lattice-based signatures; vulnerability of ECDSA in smart city contexts; security proofs vs quantum attacks | Uses custom lattice scheme, not finalized NIST standardization algorithms |
| [11] | A Quantum-Resistant Blockchain System: A Comparative Analysis | 2023 | MDPI (Mathematics) | IPFS integration to solve PQC key size issues; Dilithium and Falcon analysis; reduced blockchain bloat | Introduces architectural complexity; relies on external IPFS network availability and security |
| [12] | A Performance Comparison of Post-Quantum Algorithms in Blockchain | 2022 | The JBBA | Dilithium as strong 'all-rounder'; Falcon for fast verification; Rainbow vulnerabilities noted | Evaluates Rainbow, which was later found vulnerable and withdrawn from NIST consideration |

---

## 8. Conclusions

The transition to post-quantum cryptography represents a mandatory architectural evolution for blockchain technology. Key conclusions from the reviewed literature:

1. **The threat is imminent** — quantum computing timelines are accelerating faster than initially projected
2. **CRYSTALS-Dilithium is the best current choice** for enterprise blockchain — balanced performance, simple implementation, NIST standardized
3. **Storage overhead is the primary barrier** — PQC signatures are 10–100x larger than classical counterparts; IPFS off-chain storage reduces this by 99%+
4. **Permissioned architectures are better positioned** — enterprise infrastructure can absorb computational overhead; permissionless chains face centralization risks
5. **The research gap is clear** — no existing Dilithium CSP for Hyperledger Fabric exists; QChain fills this gap
6. **Crypto-agility is essential** — systems must be designed to switch algorithms as standards evolve, without architectural rework

The successful fortification of blockchain networks against quantum adversaries demands rapid technological prototyping coupled with robust, crypto-agile frameworks capable of executing critical protocol upgrades before the quantum threat materializes.

---

## References

1. Rubia J, Jency & Lincy R, Babitha et al. (2024). A Survey about Post Quantum Cryptography Methods. *EAI Endorsed Transactions on Internet of Things.* doi:10.4108/eetiot.5099.
2. Y. Wang and E. Shahril Ismail (2025). A Review on the Advances, Applications, and Future Prospects of Post-Quantum Cryptography in Blockchain and IoT. *IEEE Access*, vol. 13, pp. 112962–112977. doi:10.1109/ACCESS.2025.3584473.
3. Gidney, Craig (2025). How to factor 2048 bit RSA integers with less than a million noisy qubits. doi:10.48550/arXiv.2505.15917.
4. J. Gomes, S. Khan and D. Svetinovic (2023). Fortifying the Blockchain: A Systematic Review and Classification of Post-Quantum Consensus Solutions for Enhanced Security and Resilience. *IEEE Access*, vol. 11, pp. 74088–74100. doi:10.1109/ACCESS.2023.3296559.
5. G. Alagic et al. (2025). Status Report on the Fourth Round of the NIST Post-Quantum Cryptography Standardization Process. NIST IR 8545. doi:10.6028/NIST.IR.8545.
6. R. Campbell (2026). Hybrid Post-Quantum Signatures for Bitcoin and Ethereum: A Protocol-Level Integration Strategy. *The Journal of the British Blockchain Association*, vol. 9, no. 1. doi:10.31585/jbba-9-1-(2)2026.
7. W. Beullens (2022). Breaking Rainbow Takes a Weekend on a Laptop. IACR Cryptology ePrint Archive, Report 2022/214. https://eprint.iacr.org/2022/214.pdf
8. I. Strugar and R. Bekić (2023). Performance and Applicability of Post-Quantum Digital Signature Algorithms in Resource-Constrained Environments. *Algorithms*, vol. 16, no. 11, p. 518. doi:10.3390/a16110518.
9. E. D. Demir and S. S. Kaya (2025). Performance Analysis and Industry Deployment of Post-Quantum Cryptography Algorithms. arXiv:2503.12952.
10. Zhang, Peijun et al. (2021). A Blockchain System Based on Quantum-Resistant Digital Signature. *Security and Communication Networks.* doi:10.1155/2021/6671648.
11. Perumal, Thanalakshmi et al. (2023). A Quantum-Resistant Blockchain System: A Comparative Analysis. *Mathematics*, vol. 11. doi:10.3390/math11183947.
12. Gan, Lu & Yokubov, Bakhtiyor (2022). A Performance Comparison of Post-Quantum Algorithms in Blockchain. *The Journal of The British Blockchain Association*, vol. 6. doi:10.31585/jbba-6-1-(1)2023.
