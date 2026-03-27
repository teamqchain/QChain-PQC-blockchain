# QChain Docker Setup

> **For team members with zero Docker experience** - this guide will get you up and running in 5 minutes.

---

## 📦 What's in This Folder?

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Main configuration - defines all services |
| `docker-compose.dev.yml` | Development mode with hot reload |
| `.env.example` | Template for environment variables |
| `nginx/default.conf` | Web server configuration template |

---

## 🚀 Quick Start (5 Minutes)

### First-Time Setup

```bash
# 1. Navigate to the docker folder
cd docker

# 2. Create your environment file (copy the template)
cp .env.example .env

# 3. Build all Docker images (takes 5-10 minutes first time)
docker compose build

# 4. Start IPFS (needed by backend services)
docker compose up -d ipfs

# 5. Verify IPFS is running
curl http://localhost:5001/api/v0/id
```

### Run the Backend (Post-Quantum Crypto Demo)

```bash
# Run go-native (pure Go, recommended)
docker compose --profile native run --rm go-native

# OR run go-bindings (C library version)
docker compose --profile bindings run --rm go-bindings
```

### Run the Web App

```bash
# Production mode (compiled, fast)
docker compose --profile web up -d

# Open in browser
open http://localhost:3000
```

---

## 🎯 Profiles Explained

Profiles let you start only what you need. Use `--profile <name>`:

| Profile | What It Starts | When to Use |
|---------|---------------|-------------|
| `native` | IPFS + go-native | Testing PQC signatures (recommended) |
| `bindings` | IPFS + go-bindings | Testing PQC with C library |
| `web` | Web app (QPortal) | Working on Issuer/Verifier UI |
| `mobile-dev` | Flutter mobile env | Building Android APK |
| `web-dev` | Web app + hot reload | Developing web UI (see changes live) |
| `native-dev` | Go backend + hot reload | Developing Go backend (requires dev compose file) |
| `full` | Everything | Running complete stack |

---

## 📋 Common Commands Cheat Sheet

### Starting Services

```bash
# Start IPFS only (shared by all services)
docker compose up -d ipfs

# Start web app in background
docker compose --profile web up -d

# Start with logs visible (no -d)
docker compose --profile native up
```

### Stopping Services

```bash
# Stop specific service
docker compose stop webapp

# Stop all services (keeps data)
docker compose down

# Stop and DELETE all data (careful!)
docker compose down -v
```

### Viewing Logs

```bash
# View all logs
docker compose logs

# Follow logs in real-time (Ctrl+C to exit)
docker compose logs -f

# Logs for specific service
docker compose logs -f ipfs
```

### Building & Rebuilding

```bash
# Build all images
docker compose build

# Rebuild specific service (after code changes)
docker compose build go-native

# Rebuild and start
docker compose --profile native up --build
```

### Running One-Off Commands

```bash
# Run tests in go-native
docker compose --profile native run --rm go-native go test -v ./...

# Get interactive shell in mobile dev
docker compose --profile mobile-dev run --rm mobile-dev bash

# Build Android APK
docker compose --profile mobile-dev run --rm mobile-dev flutter build apk
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Your Computer (Host Machine)                     │
│                                                                     │
│   localhost:3000 ─────┐      localhost:5001 ─────┐                  │
│   (Web App)           │      (IPFS API)          │                  │
│                       ▼                          ▼                  │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                 Docker Network (qchain-network)             │    │
│  │                                                             │    │
│  │  ┌──────────┐    ┌──────────┐    ┌──────────┐               │    │
│  │  │  webapp  │    │   ipfs   │    │go-native │               │    │
│  │  │  :80     │    │  :5001   │◄───│(connects)│               │    │
│  │  │ (Nginx)  │    │  :8080   │    │          │               │    │
│  │  └──────────┘    └──────────┘    └──────────┘               │    │
│  │       │               ▲                                     │    │
│  │       │               │                                     │    │
│  │       │          ┌──────────┐                               │    │
│  │       │          │go-bindings                               │    │
│  │       │          │(connects)│                               │    │
│  │       │          └──────────┘                               │    │
│  │       │                                                     │    │
│  │       ▼                                                     │    │
│  │  ┌──────────────────────────────────────────────────────┐   │    │
│  │  │              ipfs_data (Volume)                      │   │    │
│  │  │         Persists uploaded files & signatures         │   │    │
│  │  └──────────────────────────────────────────────────────┘   │    │
│  │                                                             │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🆕 For New Team Members

### Complete Setup Walkthrough

1. **Install Docker Desktop** (if not already installed)
   - macOS: https://docs.docker.com/desktop/install/mac-install/
   - Linux: https://docs.docker.com/engine/install/

2. **Clone the Repository**
   ```bash
   git clone <repo-url>
   cd QChain-PQC-blockchain
   ```

3. **Navigate to Docker Folder**
   ```bash
   cd docker
   ```

4. **Create Your Environment File**
   ```bash
   cp .env.example .env
   ```

5. **Build Everything** (takes 5-10 minutes first time)
   ```bash
   docker compose build
   ```

6. **Start IPFS** (shared service)
   ```bash
   docker compose up -d ipfs
   ```

7. **Test the Backend**
   ```bash
   docker compose --profile native run --rm go-native
   ```
   You should see output about key generation and a CID.

8. **Test the Web App**
   ```bash
   docker compose --profile web up -d
   ```
   Open http://localhost:3000 in your browser.

---

## 👥 Multiple Developers on Same VM

If 4 team members share the university VM, you can either:

### Option A: Share IPFS, Take Turns with Other Services

```bash
# Everyone shares the same IPFS (one person starts it)
docker compose up -d ipfs

# Take turns running other services
docker compose --profile web up -d
```

### Option B: Use Different Ports

Edit your `.env` file:
```bash
# Developer 1
WEBAPP_PORT=3000

# Developer 2 (edit .env)
WEBAPP_PORT=3001

# Developer 3
WEBAPP_PORT=3002

# Developer 4
WEBAPP_PORT=3003
```

---

## 🔧 Troubleshooting

### "Cannot connect to Docker daemon"
Docker Desktop isn't running. Start it and try again.

### "Port already in use"
Another service is using that port. Either:
- Stop the other service
- Change the port in `.env`

```bash
# Find what's using port 3000
lsof -i :3000

# Or change port in .env
WEBAPP_PORT=3001
```

### "IPFS connection refused" in go-native/go-bindings
IPFS isn't running. Start it first:
```bash
docker compose up -d ipfs
# Wait 10 seconds for it to start
docker compose --profile native run --rm go-native
```

### "Image not found"
You need to build first:
```bash
docker compose build
```

### "Out of disk space"
Docker images can be large. Clean up:
```bash
# Remove unused images
docker image prune

# Nuclear option - remove EVERYTHING (careful!)
docker system prune -a
```

### Build is taking forever
First build downloads ~3GB of images. Subsequent builds are much faster due to caching.

---

## 📚 More Documentation

| Topic | Location |
|-------|----------|
| Go Backend (PQC) | `../offchain/README.md` |
| Mobile App (QWallet) | `../UI_App/README.md` |
| Web App (QPortal) | `../UI_WebApp/README.md` |
| Project Overview | `../README.md` |
