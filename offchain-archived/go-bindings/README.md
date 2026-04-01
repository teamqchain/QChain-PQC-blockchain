# QChain: Post-Quantum Credentialing (Using liboqs-go bindings)

> **Recommended:** Use the centralized Docker setup for easier development.
> ```bash
> cd docker
> docker compose --profile bindings run --rm go-bindings
> ```
> See [Docker Setup Guide](../../docker/README.md) for complete documentation.

---

This repository contains the cryptographic and storage logic for **QChain**. It implements NIST ML-DSA using the `liboqs-go` wrapper (which relies on the Open Quantum Safe C-library) and uses IPFS for decentralized document storage.

Because `liboqs-go` requires OS-level C dependencies, the entire execution environment is containerized using Docker.

## 📄 Files Included

* **`main.go`**: The Issuer application. Generates ML-DSA-44 keys, uploads a `transcript.pdf` to IPFS, signs the CID, and uploads the final verification payload.
* **`main_test.go`**: The benchmark suite measuring speed and memory overhead for ML-DSA-44, 65, and 87.
* **`Dockerfile`**: The custom environment configuration that installs the underlying `liboqs` C-library and builds the Go application.

## ⚙️ Prerequisites

* **Docker** installed and running on your system.
* A sample PDF file named `transcript.pdf` placed in the root directory.

## 🚀 How to Run the Application (`main.go`)

**1. Start the Local IPFS Node**
Run an isolated IPFS node in the background:
```bash
docker run -d --name ipfs-node -p 5001:5001 -p 8080:8080 ipfs/kubo:latest
```

**2. Build the Quantum Environment**
Compile the C-libraries and your Go application into a Docker image:
```bash
docker build -t qchain-app .
```

**3. Execute the Script**
Run the containerized application. *(Note: Ensure `main.go` points to `host.docker.internal:5001` so the container can reach your host's IPFS node).*
```bash
docker run --rm qchain-app
```

**4. Verify & Cleanup**
Check your browser at `http://127.0.0.1:8080/ipfs/<YOUR_FINAL_CID>` to view the payload. When finished, kill the IPFS node:
```bash
docker rm -f ipfs-node
```

## 📊 How to Run the Benchmarks (`main_test.go`)

Because the benchmarks require the C-library, you must execute the Go test command *inside* the custom Docker image you built in Step 2.

To run the speed and memory benchmarks, execute:
```bash
docker run --rm --entrypoint go qchain-app test -bench=. -benchmem
```
