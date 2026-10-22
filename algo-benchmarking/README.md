# QChain: Post-Quantum Cryptographic Benchmarking

This directory contains the benchmarking and evaluation suites for post-quantum cryptographic algorithms in QChain.

## 📁 Repository Structure

* **`/go-bindings`**: **Production Implementation** using `liboqs-go`, a Go wrapper around the Open Quantum Safe C-library. It implements **ML-DSA** (NIST FIPS 204 Dilithium signatures) and **ML-KEM** (NIST FIPS 203 Kyber key encapsulation). Runs in Docker to manage OS-level C dependencies.
* **`/go-native`**: Uses Go's native standard library post-quantum cryptography package (**`crypto/mlkem`**, introduced in Go 1.24) for ML-KEM-768 and ML-KEM-1024. Runs natively on Go 1.24+ without Docker, CGo, or external third-party dependencies.

---

## 📊 Performance Benchmarks

Can be viewed at [results.md](results.md)

---

## 🚀 How to Run

Each implementation has its own specific setup requirements. Navigate to the respective folder and refer to its local `README.md` for specific execution and testing instructions:

* To run the Dockerized C-bindings: `cd go-bindings`
* To run the pure Go implementation: `cd go-native`
