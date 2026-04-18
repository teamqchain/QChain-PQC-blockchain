# QChain: Post-Quantum Credentialing

This repository contains the core cryptographic logic for the QChain credentialing system. It evaluates two different implementations of the NIST ML-DSA (Dilithium) post-quantum signature scheme.

## 📁 Repository Structure

* **`/go-bindings`**: Uses `liboqs-go`, a Go wrapper around the Open Quantum Safe C-library. It offers highly optimized execution speeds but requires a containerized Docker environment to manage OS-level C dependencies.
* **`/go-native`**: Uses Cloudflare's `circl`, a 100% pure Go implementation. It runs natively without Docker or Cgo, offering maximum portability at the cost of slightly higher execution times for signing and key generation.

---

## 📊 Performance Benchmarks

Can be viewed at [results.md](results.md)

---

## 🚀 How to Run

Each implementation has its own specific setup requirements. Navigate to the respective folder and refer to its local `README.md` for specific execution and testing instructions:

* To run the Dockerized C-bindings: `cd go-bindings`
* To run the pure Go implementation: `cd go-native`
