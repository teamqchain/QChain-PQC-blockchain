# QChain: Post-Quantum Cryptography (Native Go `crypto/mlkem`)

This directory benchmarks and demonstrates post-quantum cryptography using Go's official standard library package **`crypto/mlkem`** (introduced natively in Go 1.24). It implements **NIST FIPS 203 (ML-KEM)** without any external third-party dependencies or CGo bindings.

## 📄 Files Included

* **`main.go`**: Demonstrates the native post-quantum confidential envelope flow:
  1. Generates an ML-KEM-768 key pair using standard library `crypto/mlkem`.
  2. Stores a credential document on IPFS.
  3. Encapsulates a shared secret key via `ek.Encapsulate()`.
  4. Encrypts the credential payload using AES-256-GCM keyed with the quantum-safe shared secret.
  5. Decapsulates the shared secret using `dk.Decapsulate()` and decrypts the credential payload.
  6. Packages the post-quantum envelope for IPFS storage.
* **`main_test.go`**: Benchmark suite measuring execution speed and memory allocations for:
  - Key Generation (`ML-KEM-768` and `ML-KEM-1024`)
  - Key Encapsulation (`ML-KEM-768` and `ML-KEM-1024`)
  - Key Decapsulation (`ML-KEM-768` and `ML-KEM-1024`)
  - Total Key Exchange Workflow
  - Full Authenticated Envelope Pipeline (ML-KEM + AES-256-GCM)

## ⚙️ Prerequisites

* **Go 1.24+** (includes native `crypto/mlkem`).
* *(Optional)* **Docker** if running a local IPFS daemon.

## 🚀 How to Run the Application (`main.go`)

```bash
cd algo-benchmarking/go-native
go run main.go
```

## 📊 How to Run the Benchmarks (`main_test.go`)

Run the micro-benchmarks natively with:

```bash
go test -bench=. -benchmem
```
