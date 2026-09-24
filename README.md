<p align="center">
  <img src="assets/qchain_logo.jpeg" width="220" alt="QChain logo" />
</p>

<h1 align="center">QChain</h1>

<p align="center">
  <b>A post-quantum credential system on Hyperledger Fabric.</b><br/>
  Issue, hold, present and verify digital credentials signed with quantum-resistant cryptography.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Hyperledger%20Fabric-2.x-2F3134" alt="Fabric" />
  <img src="https://img.shields.io/badge/Go-1.24-00ADD8" alt="Go" />
  <img src="https://img.shields.io/badge/Flutter-3.35-027DFD" alt="Flutter" />
  <img src="https://img.shields.io/badge/PQC-ML--DSA--44-6E40C9" alt="ML-DSA-44" />
  <img src="https://img.shields.io/badge/IPFS-Kubo-65C2CB" alt="IPFS" />
  <img src="https://img.shields.io/badge/License-Proprietary-red" alt="License" />
</p>

---

## 🌐 Live Demo

The system is running on our university VM and exposed publicly via a Tailscale Funnel. Open these
links in any browser — nothing to install:

| App | What it is | Link |
|-----|-----------|------|
| **QPortal** | Issuer / Verifier / IT-Admin web portal | **https://qchain.tail4fff4b.ts.net/** |
| **QWallet** | Credential holder app (web build) | **https://qchain.tail4fff4b.ts.net/wallet/** |

> ⚠️ **It's a live demo, not production.** It runs on a single shared VM, so it may be offline at times,
> the demo database is shared by everyone, and access is open to anyone with the link. The very first
> page load can take a few seconds while the browser downloads the app's rendering engine.

---

## Overview

Today's blockchains sign data with classical cryptography (RSA, ECDSA). A sufficiently powerful quantum
computer running **Shor's algorithm** would break those signatures — and adversaries can already
**"harvest now, decrypt later"**, storing signed records today to forge or repudiate them once quantum
hardware arrives.

**QChain** replaces the classical signature on each credential with **ML-DSA-44 (CRYSTALS-Dilithium)**,
a NIST-standardised, lattice-based post-quantum signature, and anchors it on a permissioned Hyperledger
Fabric ledger. It uses a **hash-on-chain, data-off-chain** model: the credential's attributes live only
on **IPFS**, encrypted to the holder's ML-KEM-768 key (addressed by CID), while the ledger holds a small
signed record — metadata, the CID, and a salted SHA3-256 fingerprint of every field — keeping the ledger
small and free of plaintext while remaining tamper-evident.

The system has three faces:

- **QPortal** — a Flutter web app for **Issuers** (universities/authorities), **Verifiers**
  (employers), and **IT Admins** (staff, audit, settings).
- **QWallet** — a Flutter app for credential **Holders** to store credentials and present them via
  QR/OTP with selective disclosure.
- **Off-chain backend** — a Go REST API that ties together Fabric, IPFS, the post-quantum crypto, and a
  MySQL database for the data that exists nowhere else (Emirates ID mapping, contact details, sessions,
  subscriptions, history). Every field the ledger holds is read from the ledger.

---

## Architecture

```
                              Public internet (HTTPS)
                                        │
          https://qchain.tail4fff4b.ts.net   ──  Tailscale Funnel  (443, auto-HTTPS)
                                        │
                                        ▼
                          web-gateway  (Nginx container, :8090)
              /  → QPortal (web)      /wallet/ → QWallet (web)      /api/ → backend
                                        │  (same origin — no CORS, no mixed content)
                                        ▼
                            Go REST API   ·   offchain/   ·   :3000
                ┌────────────────────┬───────────────────┬────────────────────┐
                ▼                    ▼                   ▼                    ▼
        Hyperledger Fabric      IPFS (Kubo)           MySQL            ML-DSA-44 (PQC)
     peers + orderer (etcdraft)  :5001 / :8080        :3306          via liboqs-go (CGo)
     + JavaScript chaincode      encrypted         IDs/contacts/      sign & verify
     CouchDB state DB            envelopes         sessions/history   (+ ML-KEM-768)
                                 (CID on-chain)
```

- **Source of truth** — the chain for every field it holds (status, type, dates, holder name and keys,
  CID, hashes), IPFS for the credential body, MySQL only for data that exists nowhere else.
- **Authenticity** comes from the issuer's ML-DSA-44 signature over a commitment to the credential
  (holder, type, issue/expiry dates, CID and every salted field hash).
- **Integrity** — the verifier rebuilds that commitment from the ledger (never trusting a stored hash),
  checks the signature against the trusted issuer key, and checks each disclosed value + salt against
  its on-chain fingerprint; the holder's ML-DSA-44 signature binds the presentation to the credential.

---

## Technology stack

| Layer | Technology |
|-------|-----------|
| Blockchain | Hyperledger Fabric 2.x · two orgs (GovernmentMSP, GeneralMSP) + etcdraft orderer · CouchDB state DB |
| Chaincode | JavaScript (Fabric Contract API 2.5) — `qchain-network/chaincode/` |
| Post-quantum crypto | ML-DSA-44 (CRYSTALS-Dilithium, NIST FIPS 204) via **liboqs-go** (C bindings) |
| Off-chain storage | IPFS / Kubo (credential envelope encrypted to the holder, referenced on-chain by CID) |
| Backend | Go 1.24 REST API (`offchain/`) · `fabric-gateway`, `go-ipfs-api`, `go-sql-driver/mysql` |
| Database | MySQL (`qchain_db`) for ID mappings, contact details, sessions, verification logs, subscriptions, alerts, audit |
| Frontend | Flutter 3.44.x (Dart ≥ 3.10) — QPortal (web) + QWallet (mobile + web) |
| Public gateway | Nginx reverse proxy (`web-gateway/`) serving both apps + proxying the API on one origin |
| Public access | Tailscale Funnel (permanent `*.ts.net` HTTPS URL, runs as a system service) |

A separate `algo-benchmarking/` module compares **ML-DSA-44/65/87** across two implementations
(liboqs-go C bindings vs. Cloudflare CIRCL pure-Go).

---

## Repository structure

```
QChain-PQC-blockchain/
├── README.md
├── LICENSE                      # Proprietary — all rights reserved
│
├── qchain-network/             # Hyperledger Fabric network
│   ├── chaincode/              # JavaScript chaincode v2.0 (QChaincode.js, index.js, package.json)
│   │   └── test/               # node:test suite (npm test) — no Fabric needed, in-memory ledger
│   ├── config/                 # Fabric config: configtx.yaml, core.yaml, crypto-config.yaml, orderer.yaml
│   ├── docker/                 # docker-compose.yaml (peers/orderer/couchdb/ipfs) + docker-compose-ca.yaml
│   ├── scripts/                # registerEnroll.sh, env-gov.sh, env-gen.sh, schema.sql,
│   │                           # setup-demo.sh, start-demo.sh, setup-ipfs-service.sh,
│   │                           # setup-tailscale-funnel.sh, enrollAdmin.js, registerUser.js
│   ├── channel-artifacts/      # generated channel/genesis blocks   (runtime, gitignored)
│   ├── crypto-material/        # CA-issued MSP certs & keys          (runtime, gitignored)
│   ├── wallet/                 # Fabric gateway identities (.id)     (runtime, gitignored)
│   ├── connection/             # peer connection profiles            (runtime, gitignored)
│   └── fabric-ca/              # Fabric CA server configs
│
├── offchain/                   # Go backend (REST API on :3000)
│   ├── server.go               # entry point: main() + routes + CORS
│   ├── config.go  crypto.go  fabric.go  httputil.go    # config, PQC, Fabric client, helpers
│   ├── chain.go  commitment.go  envelope.go  kem.go     # on-chain reads, signed commitments, encryption
│   ├── credentials.go  verification.go  holders.go      # domain handlers
│   ├── dashboard.go  staff.go  subscriptions.go  mobile.go
│   ├── db.go  db_*.go          # MySQL access, split per domain
│   ├── bootstrap.go            # RUN_CHAIN_BOOTSTRAP=1 one-shot: re-registers holders after a ledger reset
│   ├── cmd/keygen/main.go      # org ML-DSA-44 key pair; holder key/sign/decrypt helpers for e2e testing
│   ├── Dockerfile  docker-build.sh  docker-run.sh
│   └── *_test.go               # go test ./... — chain, commitment, envelope, verification, etc.
│
├── UI_WebApp/                  # QPortal — Flutter web (issuer / verifier / IT-admin)
├── UI_App/                     # QWallet — Flutter app (holder); builds to mobile + web
├── shared/                     # Flutter package shared by both apps (certificate template/viewer, fonts)
│
├── web-gateway/                # One Nginx container: builds both web apps + proxies /api
│   ├── Dockerfile  nginx.conf  docker-build.sh  docker-run.sh  README.md
│
├── tests/
│   └── e2e_api_test.sh         # plays issuer + holder against a live stack; every registered endpoint
│
├── algo-benchmarking/          # ML-DSA performance benchmarks (liboqs-go vs CIRCL) + graphs
├── assets/                     # Logo and performance graphs
└── docs/
    ├── setup.md                # full manual setup guide
    ├── ledger-reset-v2.md      # chaincode v2.0 full-ledger-reset runbook
    └── junior/                 # progress-report-1/2, final-report, literature-review, team-charter
```

---

## Getting started (build it from scratch)

This is the full path for someone cloning the repo onto a fresh machine and standing up the whole
system. It assumes a Linux host (the project runs on an Ubuntu VM). Already on the configured VM?
Skip to [Quick start](#quick-start).

### Prerequisites

| Tool | Version | Used for |
|------|---------|----------|
| Docker + Docker Compose | latest | Running the Fabric network, IPFS, backend, gateway |
| Hyperledger Fabric binaries | 2.x (`peer`, `orderer`, `configtxgen`, `fabric-ca-client`) | Crypto, channel, chaincode lifecycle |
| MySQL | 8.x | The `qchain_db` database |
| IPFS / Kubo | latest | Off-chain credential storage |
| Go | 1.24 | Generating the PQC key pair (the backend itself builds inside Docker) |
| Flutter SDK | 3.35.x (Dart ≥ 3.9.2) | Building the apps outside Docker (optional — the gateway builds them in Docker) |
| Tailscale | latest | Optional — only to expose the apps publicly |

Get the Fabric CLI binaries with the official installer, e.g.:
```bash
curl -sSL https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh | bash -s -- binary
export PATH=$PATH:$PWD/bin
```

### 1. Clone

```bash
git clone https://github.com/nihvp/QChain-PQC-blockchain.git
cd QChain-PQC-blockchain
```

### 2. Database

```bash
# create the database + a user, then load the schema (it also seeds demo data)
mysql -u root -p -e "CREATE DATABASE qchain_db CHARACTER SET utf8mb4;"
mysql -u root -p qchain_db < qchain-network/scripts/schema.sql
```

### 3. Hyperledger Fabric network

```bash
cd qchain-network/docker

# 3a. Start the Certificate Authorities
docker compose -f docker-compose-ca.yaml up -d

# 3b. Generate all MSP crypto material via Fabric CA → crypto-material/
cd ../scripts && bash registerEnroll.sh

# 3c. Start the orderer, peers and CouchDB
cd ../docker && docker compose -f docker-compose.yaml up -d \
  orderer0.orderer.example.com peer0.government.uae.com peer0.general.uae.com couchdb0
```

**Channel + chaincode (manual — standard Fabric 2.x lifecycle).** The repo provides the configs
(`config/configtx.yaml`) and the JS chaincode (`chaincode/`) but does **not** script these steps. Use
the peer CLI with the org context helpers, then deploy:

```bash
source qchain-network/scripts/env-gov.sh        # sets CORE_PEER_* for the Government org

# create the channel genesis block from config/configtx.yaml, then create & join 'mychannel'
configtxgen -profile TwoOrgsChannel -channelID mychannel \
  -outputBlock qchain-network/channel-artifacts/mychannel.block
peer channel create -c mychannel -f ... -o orderer0.orderer.example.com:7050 ...
peer channel join  -b qchain-network/channel-artifacts/mychannel.block
source qchain-network/scripts/env-gen.sh        # repeat join for the General org

# deploy the JavaScript chaincode (package → install → approveformyorg on both orgs → commit)
peer lifecycle chaincode package qchaincode.tar.gz \
  --path qchain-network/chaincode --lang node --label qchaincode_1
peer lifecycle chaincode install qchaincode.tar.gz
# ... approveformyorg (each org) ... then:
peer lifecycle chaincode commit -C mychannel -n qchaincode ...
```

### 4. IPFS

```bash
ipfs init                                              # first time only
bash qchain-network/scripts/setup-ipfs-service.sh      # run IPFS as a systemd service (auto-restart)
```

### 5. Backend (off-chain Go API)

```bash
# 5a. Generate the organisation's ML-DSA-44 key pair (prints an env template)
go run ./offchain/cmd/keygen

# 5b. Create offchain/.env with the values below (keys from 5a):
cat > offchain/.env <<'ENV'
ISSUER_PRIVATE_KEY_HEX=<from keygen>
ISSUER_PUBLIC_KEY_HEX=<from keygen>
ISSUER_ORG_ID=GeneralMSP
ISSUER_ORG=general
ISSUER_IDENTITY=issuer1
VERIFIER_ORG=general
VERIFIER_IDENTITY=verifier1
MYSQL_DSN=qchain_user:password@tcp(127.0.0.1:3306)/qchain_db
NETWORK_ROOT=/qchain-network
CHANNEL_NAME=mychannel
CHAINCODE_NAME=qchaincode
IPFS_HOST=127.0.0.1:5001
SERVER_PORT=3000
ENV

# 5c. Build & run (first build ~20 min — it compiles liboqs from source; later builds are cached)
bash offchain/docker-build.sh && bash offchain/docker-run.sh
curl -s http://localhost:3000/health        # → {"status":"ok"}
```

### 6. Seed demo holders

```bash
bash qchain-network/scripts/setup-demo.sh http://localhost:3000
```

### 7. Frontends

**Recommended — the web gateway** builds both apps and serves them on one origin (port 8090):

```bash
export API_BASE_URL="http://localhost:3000"      # or your public Funnel URL + /api
bash web-gateway/docker-build.sh && bash web-gateway/docker-run.sh
# → portal http://localhost:8090/   ·   wallet http://localhost:8090/wallet/
```

The backend URL is **baked in at build time** via `--dart-define=API_BASE_URL=…` (both apps read
`kApiBaseUrl = String.fromEnvironment('API_BASE_URL')`), so rebuild the gateway if that URL changes.

**Or run the apps directly with Flutter** (development):

```bash
cd UI_WebApp && flutter pub get && flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:3000          # QPortal
cd ../UI_App && flutter pub get && flutter run \
  --dart-define=API_BASE_URL=http://localhost:3000          # QWallet (device/emulator)
# Build a QWallet Android APK:  flutter build apk --release --dart-define=API_BASE_URL=...
```

### 8. Public access (optional — your own tunnel)

```bash
# install + connect Tailscale, naming this machine (becomes your URL)
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --operator=$USER --hostname=qchain
# in the Tailscale admin console: enable HTTPS certificates + Funnel for this node, then:
bash qchain-network/scripts/setup-tailscale-funnel.sh        # maps public 443 → :8090
# share https://<machine>.<tailnet>.ts.net/  and  /wallet/   ·   take offline: tailscale funnel --https=443 off
```

> Because the apps bake in the API URL, build the gateway with `API_BASE_URL=https://<machine>.<tailnet>.ts.net/api`
> (the gateway's `docker-build.sh` can auto-derive this from Tailscale).

### Quick start

If the Fabric network, MySQL, IPFS and `offchain/.env` are already set up on the machine:

```bash
bash qchain-network/scripts/start-demo.sh     # starts IPFS + the backend container, checks the peers
```

---

## API reference

Base URL: `http://localhost:3000` (or `…/api` through the gateway/tunnel). All credential-related
responses include a `credentialID`, and **all timestamps are returned in UAE local time (Asia/Dubai)**.

**Credentials**
| Method | Path | Purpose |
|--------|------|---------|
| POST | `/registerHolder` | Register a credential holder on-chain |
| POST | `/issueCredential` | Issue a credential: salted field hashes + expiry on-chain, envelope encrypted to the holder on IPFS, issuer ML-DSA-44 signature over the commitment |
| POST | `/updateCredential` | Update the holder email (MySQL) and/or expiry (re-signed on-chain) |
| POST | `/revokeCredential` · `/suspendCredential` · `/restoreCredential` | Lifecycle changes (on-chain) |
| GET | `/getAllCredentials` · `/getCredentialDetail` | Read credentials (on-chain fields from the ledger) |

**Verification**
| Method | Path | Purpose |
|--------|------|---------|
| POST | `/resolveSession` | Verify a holder's QR/OTP presentation (5 checks against the chain) |
| GET | `/getVerificationHistory` · `/getVerificationDetail` | Verification logs |

**Holders / Dashboard / Audit**
| Method | Path | Purpose |
|--------|------|---------|
| GET | `/getHolders` | List holders |
| GET | `/getDashboardStats` | Dashboard widgets (counts, recent activity, status alerts) |
| GET | `/getAuditLogs` | Append-only audit log |

**Subscriptions & alerts** (verifier monitoring)
| Method | Path | Purpose |
|--------|------|---------|
| POST | `/requestSubscription` · `/deleteSubscription` · `/unsubscribe` | Manage subscriptions |
| GET | `/getSubscriptions` | List subscriptions |
| GET | `/getSubscriptionAlerts` | Alerts (raised when a monitored credential is suspended/revoked) |
| POST | `/acknowledgeAlert` | Acknowledge an alert |

**Staff & directory** (IT admin)
| Method | Path | Purpose |
|--------|------|---------|
| GET | `/getStaff` · `/getDirectory` | Staff list / org directory |
| POST | `/inviteStaff` · `/updateStaffRole` · `/deleteStaff` | Staff management |

**QWallet (mobile)** — under `/mobile/*`
| Method | Path | Purpose |
|--------|------|---------|
| GET | `/mobile/checkKeys` · `/mobile/getHolderProfile` | Holder keys / profile (keys and name from the chain) |
| POST | `/mobile/registerHolderKeys` | Bind the wallet's ML-KEM-768 + ML-DSA-44 public keys on-chain |
| GET | `/mobile/getEnvelope` | Encrypted credential envelope, fetched from IPFS by the on-chain CID |
| GET | `/mobile/getCredentialsByHolder` · `/mobile/getActivity` · `/mobile/getCatalog` · `/mobile/getSubscriptions` | Wallet reads |
| POST | `/mobile/toggleFavorite` · `/mobile/fetchDocument` | Wallet actions |
| POST | `/mobile/generateOTP` · `/mobile/generatePresentation` | Create a share session (OTP / QR) |
| POST | `/mobile/approveSubscription` · `/mobile/rejectSubscription` | Respond to verifier requests |
| GET | `/health` | Liveness probe |

---

## Recent updates

- **Chain & IPFS as the source of truth** — the ledger no longer stores the plaintext credential; it
  stores a signed commitment (metadata, CID, salted field hashes). The credential body lives only on IPFS,
  encrypted to the holder. Every read comes from the ledger/IPFS, expiry is signed on-chain (editing it
  re-signs), and presentations carry per-field salts. Chaincode v2.0 (full ledger reset).
- **Full backend integration** — issuance, verification, revocation and lifecycle wired end-to-end
  across Fabric, IPFS, the PQC signer and MySQL.
- **Subscriptions & alerts** — verifiers can monitor a credential; suspending/revoking a subscribed
  credential now raises an alert that surfaces on the dashboard and the verifier's alerts page.
- **`credentialID` in every credential-tied response**, for deep-linking from the frontends.
- **Backend refactor** — the large `server.go`/`db.go` were split into per-domain files for readability.
- **Public access** — a single Nginx `web-gateway` serves both apps + proxies the API on one origin,
  exposed via a permanent Tailscale Funnel URL.
- **UAE-local timestamps** — every time the API returns is now Asia/Dubai local time.

---

## Roadmap

**Phase 1 — Authenticity, integrity & confidentiality (complete).** A working post-quantum credential
system: ML-DSA-44 signatures over a signed commitment, a commitment-on-chain / data-off-chain (IPFS)
model with the credential body encrypted end-to-end to the holder's ML-KEM-768 key, salted per-field
hashes for selective disclosure, full issuance → presentation → verification → revocation lifecycle, the
QPortal and QWallet apps, and a publicly reachable demo.

**Phase 2 — Post-quantum Fabric identities (next).** Hyperledger Fabric's **MSP / identity layer**
(peer, orderer and client enrollment certificates) still uses classical ECDSA — credential signatures and
encryption are already post-quantum, but the network's own identities are not yet. Phase 2 replaces
those with post-quantum equivalents.

---

## Documentation

In-depth project documents live in [`docs/`](docs/):

- [Setup Guide](docs/setup.md) — full manual setup: Fabric network, chaincode, backend, IPFS, tunnel
- [web-gateway/README.md](web-gateway/README.md) — public-access gateway & tunnel runbook

Junior-year deliverables live in [`docs/junior/`](docs/junior/):

- [Progress Report 1](docs/junior/progress-report-1.md) — research & network setup
- [Progress Report 2](docs/junior/progress-report-2.md) — implementation
- [Final Report](docs/junior/final-report.md) — full system, testing & benchmarks
- [Literature Review](docs/junior/literature-review.md) — PQC & quantum-threat background
- [Team Charter](docs/junior/team-charter.md) — roles & governance

---

## Team

A University of Sharjah capstone project, supervised by **Dr. Manar Abu Talib** and **Dr. Sohail Abbas**.

| Member | Role |
|--------|------|
| Mohammed Bin Ali Maqqavi ([@M0hd-Maqqavi](https://github.com/M0hd-Maqqavi)) | Project Manager |
| Mohammed Abdul Haris ([@mohammed-ah-14](https://github.com/mohammed-ah-14)) | Technical Lead |
| Mohammed Nihal ([@nihvp](https://github.com/nihvp)) | Quality Assurance Lead |
| Mohammed Obied ([@MohammedObeid88](https://github.com/MohammedObeid88)) | Blockchain Specialist |

---

## License

**Proprietary — all rights reserved.** © 2026 QChain. This source code is proprietary and confidential;
unauthorized copying, modification, distribution, or use is prohibited without prior written permission.
See [LICENSE](LICENSE).

---

## Disclaimer

This is an academic research project, not a production system. The public demo uses seed/demo data on a
shared database, and the OTP/QR presentation flow is not yet gated behind holder authentication (tracked
for a future session/login system). One property needed for real deployment remains out of scope: the
Fabric network's own identities (peer/orderer/client enrollment) use classical ECDSA, not post-quantum
cryptography — that is the focus of Phase 2. Credential confidentiality and holder-key handling are
implemented today: attributes are encrypted end-to-end to an ML-KEM-768 key pair generated and held only
on the holder's device, never transmitted to or stored by the backend.
