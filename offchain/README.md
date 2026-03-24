# QChain: Post-Quantum Credentialing

This repository contains the core cryptographic logic for the QChain credentialing system. It evaluates two different implementations of the NIST ML-DSA (Dilithium) post-quantum signature scheme.

## 📁 Repository Structure

* **`/go-bindings`**: Uses `liboqs-go`, a Go wrapper around the Open Quantum Safe C-library. It offers highly optimized execution speeds but requires a containerized Docker environment to manage OS-level C dependencies.
* **`/go-native`**: Uses Cloudflare's `circl`, a 100% pure Go implementation. It runs natively without Docker or Cgo, offering maximum portability at the cost of slightly higher execution times for signing and key generation.

---

## 📊 Performance Benchmarks

The following benchmarks compare the speed and memory allocations across all three ML-DSA security levels for both implementations.

### 1. `go-bindings` (liboqs-go)
*Optimized C-bindings. Requires Docker.*

| Operation | Security Level | Speed (ns/op) | Memory (B/op) |
| :--- | :--- | :--- | :--- |
| **Key Generation** | ML-DSA-44 | 41,311 | 4,096 |
| | ML-DSA-65 | 71,154 | 6,144 |
| | ML-DSA-87 | 122,651 | 8,064 |
| **Signing** | ML-DSA-44 | 90,695 | 2,696 |
| | ML-DSA-65 | 146,539 | 3,464 |
| | ML-DSA-87 | 211,655 | 4,872 |
| **Verification** | ML-DSA-44 | 36,832 | 0 |
| | ML-DSA-65 | 64,047 | 0 |
| | ML-DSA-87 | 113,143 | 0 |

### 2. `go-native` (Cloudflare CIRCL)
*Pure Go. Runs natively anywhere.*

| Operation | Security Level | Speed (ns/op) | Memory (B/op) |
| :--- | :--- | :--- | :--- |
| **Key Generation** | ML-DSA-44 | 85,017 | 55,328 |
| | ML-DSA-65 | 153,110 | 81,952 |
| | ML-DSA-87 | 227,999 | 117,408 |
| **Signing** | ML-DSA-44 | 373,203 | 450 |
| | ML-DSA-65 | 196,093 | 450 |
| | ML-DSA-87 | 520,406 | 450 |
| **Verification** | ML-DSA-44 | 34,263 | 450 |
| | ML-DSA-65 | 46,362 | 450 |
| | ML-DSA-87 | 64,789 | 450 |

*(Note: While `go-native` uses more memory during Key Generation, its verification speed is highly competitive and uses minimal memory allocations).*

---

## 🚀 How to Run

Each implementation has its own specific setup requirements. Navigate to the respective folder and refer to its local `README.md` for specific execution and testing instructions:

* To run the Dockerized C-bindings: `cd go-bindings`
* To run the pure Go implementation: `cd go-native`
