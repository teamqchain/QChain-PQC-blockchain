# QChain: Post-Quantum Credentialing (Using native Go algorithms from CIRCL)

> **Recommended:** Use the centralized Docker setup for easier development.
> ```bash
> cd docker
> docker compose --profile native run --rm go-native
> ```
> See [Docker Setup Guide](../../docker/README.md) for complete documentation.

---

This repository contains the core cryptographic and storage logic for **QChain**, a decentralized academic credentialing system. It uses purely native Go implementations of Post-Quantum Cryptography (NIST ML-DSA) and IPFS for decentralized storage.

## 📄 Files Included

* **`main.go`**: The Issuer (University) application. It performs the following steps:
  1. Generates ML-DSA-44 post-quantum cryptographic keys.
  2. Uploads a local document (`transcript.pdf`) to a local IPFS node.
  3. Signs the resulting IPFS CID with the ML-DSA-44 private key.
  4. Uploads the final verification payload (Document CID + Hex Signature) to IPFS.
* **`main_test.go`**: A comprehensive benchmark suite. It measures the execution speed (nanoseconds per operation) and memory allocations for Key Generation, Signing, and Verification across all three NIST security levels (ML-DSA-44, 65, and 87).

## ⚙️ Prerequisites

* **Go 1.20+** installed on your system.
* **Docker** (used solely to run an isolated, ephemeral IPFS node).
* A sample PDF file named `transcript.pdf` placed in the root directory.

## 🚀 How to Run the Application (`main.go`)

**1. Start the Local IPFS Node**
Spin up a background IPFS container to handle file uploads without installing IPFS natively:
```bash
docker run -d --name ipfs-node -p 5001:5001 -p 8080:8080 ipfs/kubo:latest
```

**2. Initialize and Run**
Download the required pure-Go dependencies and execute the script:
```bash
go mod init qchain
go mod tidy
go run main.go
```

**3. Verify**
Check your terminal output for the `Final Verification CID`. You can view the signed payload in your browser at `http://127.0.0.1:8080/ipfs/<YOUR_FINAL_CID>`.

**4. Cleanup**
When finished, remove the isolated IPFS node:
```bash
docker rm -f ipfs-node
```

## 📊 How to Run the Benchmarks (`main_test.go`)

Because the cryptography relies on Cloudflare's `circl` (pure Go), you can run the benchmarks natively on your machine without Docker.

To run the speed and memory benchmarks for all ML-DSA security levels, use:
```bash
go test -bench=. -benchmem
```
