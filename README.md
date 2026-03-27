## QChain - Post-Quantum Blockchain Platform

A quantum-resistant blockchain implementation combining Hyperledger Fabric concepts with Post-Quantum Cryptography (PQC), IPFS off-chain storage, and cross-platform wallet interfaces.

### Team

- **Mohammed Bin Ali Maqqavi** - Project Manager
- **Mohammed Abdul Haris** - Technical Lead
- **Mohammed Nihal** - Quality Assurance Lead
- **Mohammed Obied** - Blockchain Specialist

**Supervisors:**
- Dr. Manar Abu Talib - Head Supervisor
- Dr. Sohail Abbas - Co-Supervisor

---

### What We Built

QChain is a quantum-resistant blockchain platform that addresses the existential threat quantum computers pose to traditional cryptographic systems. We implement **lattice-based cryptography** (ML-DSA) to protect against quantum attacks while maintaining practical performance.

**Key Features:**
- Post-quantum digital signatures using **ML-DSA-44** (formerly Dilithium)
- IPFS integration for off-chain storage of PQC signatures (2KB-17KB payload management)
- Cross-platform wallet: Flutter mobile app (iOS/Android) + web interface
- Interactive research dashboard with algorithm comparisons and performance metrics
- Dockerized Go backend with liboqs integration

---

### Architecture

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│   Wallet    │─────▶│  Go Backend  │─────▶│    IPFS     │
│  (Flutter)  │      │   (ML-DSA)   │      │   Storage   │
└─────────────┘      └──────────────┘      └─────────────┘
                             │
                             │ CID Hash
                             ▼
                     ┌──────────────┐
                     │  Blockchain  │
                     │    Ledger    │
                     └──────────────┘
```

**Hybrid Approach:**
- Heavy PQC signatures stored off-chain on IPFS
- Only content identifiers (CIDs) recorded on-chain
- Reduces blockchain bloat while maintaining quantum security

---

### Project Structure

```
QChain-PQC-blockchain/
├── UI_App/              # Flutter mobile wallet (iOS/Android)
│   ├── lib/
│   │   ├── screens/     # UI screens (wallet, transactions, etc.)
│   │   ├── components/  # Reusable UI components
│   │   ├── widgets/     # Custom widgets
│   │   └── model/       # Data models
│   └── assets/          # Images, fonts (SF Pro, Formula1)
│
├── UI_WebApp/           # Flutter web interface
│
├── offchain/            # Go backend service
│   ├── main.go          # PQC signature implementation (ML-DSA-44)
│   ├── Dockerfile       # Container configuration
│   └── transcript.pdf   # Sample document for signing
│
├── index.html           # Research dashboard
│   ├── Algorithm comparison (ML-DSA, FN-DSA, SLH-DSA)
│   ├── Performance metrics & visualizations
│   ├── Architecture diagrams
│   └── Literature review database
│
├── docs/                # Documentation
│   └── team-charter.md
│
├── tests/               # Test suite
│
└── assets/              # Project assets
    └── qchain_logo.jpeg
```

---

### Technology Stack

**Cryptography:**
- ML-DSA-44 (NIST-standardized lattice-based signatures)
- [liboqs-go](https://github.com/open-quantum-safe/liboqs-go) - Open Quantum Safe library

**Backend:**
- Go 1.x
- IPFS (InterPlanetary File System)
- Docker containerization

**Frontend:**
- Flutter/Dart (mobile + web)
- Custom UI with SF Pro and Formula1 fonts
- Responsive design for cross-platform support

**Visualization:**
- HTML5/CSS3 + TailwindCSS
- Chart.js for data visualization
- Interactive algorithm comparison

---

### UI Components

- 📱 **Mobile App (Flutter)**
  See detailed documentation: [UI_App README](./UI_App/README.md)

- 🌐 **Web App Interface**
  See detailed documentation: [UI_WebApp README](./UI_WebApp/README.md)

- 🔧 **Backend (Go + PQC)**
  See detailed documentation: [offchain README](./offchain/README.md)

- 🐳 **Docker Setup**
  See detailed documentation: [Docker README](./docker/README.md)

---

### Getting Started

#### Option 1: Using Docker (Recommended)

Docker ensures everyone has the exact same environment. Perfect for team collaboration.

```bash
# Navigate to docker folder
cd docker

# Copy environment template
cp .env.example .env

# Start IPFS (required for backend)
docker compose up -d ipfs

# Run the PQC backend demo
docker compose --profile native run --rm go-native

# Start the web app
docker compose --profile web up -d
# Open http://localhost:3000
```

See the [Docker Setup Guide](./docker/README.md) for complete documentation.

#### Option 2: Local Development

##### Prerequisites
- Go 1.18+
- Flutter SDK 3.0+
- IPFS node running locally

##### Run the Backend

```bash
cd offchain
go mod download
go run main.go
```

##### Run the Mobile App

```bash
cd UI_App
flutter pub get
flutter run
```

#### View Research Dashboard

```bash
# Serve index.html with any web server
python3 -m http.server 8000
# Open http://localhost:8000
```

---

### Research Highlights

**The Quantum Threat:**
- Shor's algorithm can break RSA/ECDSA signatures
- "Harvest now, decrypt later" attacks are already happening
- Estimated timeline: ~2033 for RSA-2048 compromise

**Our Solution:**
- Migration to NIST-approved PQC algorithms
- **ML-DSA** chosen for balanced performance/security
- Hybrid architecture mitigates 100x signature size increase

**Performance Trade-offs:**
- Traditional ECDSA: ~64 bytes, 3000 TPS
- ML-DSA: ~2420 bytes, ~1200 TPS (50-70% throughput reduction)
- Off-chain storage solves blockchain bloat

See `index.html` for detailed algorithm comparisons and 12+ research paper reviews.

---

### Implementation Status

✅ **Completed:**
- ML-DSA-44 signature implementation
- IPFS integration for document storage
- Flutter mobile wallet UI structure
- Web app interface
- Interactive research dashboard
- Dockerized backend

🚧 **In Progress:**
- Blockchain integration (Hyperledger Fabric MSP)
- End-to-end transaction flow
- Comprehensive test suite
- Performance benchmarking

---

### Project Timeline

| Phase | Weeks | Focus Area |
|-------|-------|-----------|
| Research & Planning | 1-3 | PQC algorithm evaluation |
| Cryptography Selection | 4-6 | ML-DSA implementation |
| Core Development | 7-10 | Backend + wallet interfaces |
| Testing & Optimization | 11-13 | Performance tuning |
| Final Deliverables | 14-16 | Documentation + presentation |

**Current Status:** Week 10-11 (Development/Testing Phase)

---

### License

TBD

---

**Last Updated:** March 2026
