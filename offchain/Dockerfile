# =============================================================================
# QCHAIN OFFCHAIN LIBOQS GO-BINDINGS DOCKERFILE
# =============================================================================
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │  WHAT IS A DOCKERFILE?                                                  │
# ├─────────────────────────────────────────────────────────────────────────┤
# │  A Dockerfile is a "recipe" that tells Docker how to build a container. │
# │                                                                         │
# │  Think of it like a cooking recipe:                                     │
# │  1. Start with a base (FROM = start with this base image)               │
# │  2. Add ingredients (RUN = run commands to install stuff)               │
# │  3. Copy files (COPY = copy your code into the container)               │
# │  4. Set the oven (CMD = what to run when container starts)              │
# └─────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │  WHAT DOES THIS CONTAINER DO?                                           │
# ├─────────────────────────────────────────────────────────────────────────┤
# │  This container runs our Post-Quantum Cryptography code:                │
# │  → Uses liboqs-go (C library wrapper) for ML-DSA-44 signatures          │
# │  → Generates quantum-resistant key pairs                                │
# │  → Signs PDF documents                                                  │
# │  → Uploads to IPFS                                                      │
# └─────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │  MULTI-STAGE BUILD EXPLAINED                                            │
# ├─────────────────────────────────────────────────────────────────────────┤
# │  We use TWO stages to make the final image smaller:                     │
# │                                                                         │
# │  Stage 1 (builder):                                                     │
# │  → Install ALL build tools (cmake, git, compilers, etc.)                │
# │  → Compile the liboqs C library                                         │
# │  → Build our Go binary                                                  │
# │  → This stage is ~1GB+ (lots of tools!)                                 │
# │                                                                         │
# │  Stage 2 (runtime):                                                     │
# │  → Start fresh with minimal image                                       │
# │  → Copy ONLY the compiled binary and required libraries                 │
# │  → Final image is ~150MB (much smaller!)                                │
# │                                                                         │
# │  The build tools are DISCARDED - we only keep what's needed to run.     │
# └─────────────────────────────────────────────────────────────────────────┘
#
# =============================================================================

# =============================================================================
# STAGE 1: BUILD ENVIRONMENT
# =============================================================================
# This stage has all the tools needed to compile liboqs and our Go code.
# It's big (~1GB) but we throw it away after building.

# Start with official Go image based on Debian Bookworm
# "AS builder" names this stage so we can reference it later
FROM golang:1.24-bookworm AS builder

# Install build tools needed to compile the liboqs C library
# --no-install-recommends = don't install optional packages (smaller image)
# rm -rf /var/lib/apt/lists/* = delete package lists (smaller image)
RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake \
    ninja-build \
    build-essential \
    git \
    libssl-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Download and compile the liboqs library (Open Quantum Safe)
# This is the C library that provides ML-DSA-44 (Dilithium) signatures
WORKDIR /tmp
RUN git clone --branch main --single-branch --depth 1 \
    https://github.com/open-quantum-safe/liboqs.git \
    && cd liboqs \
    && mkdir build && cd build \
    && cmake -GNinja -DBUILD_SHARED_LIBS=ON .. \
    && ninja \
    && ninja install

# Create a pkg-config file so Go can find the liboqs library
# pkg-config is a helper tool that tells compilers where libraries are
RUN mkdir -p /usr/lib/pkgconfig && \
    printf "Name: liboqs-go\n\
Description: Go bindings for liboqs\n\
Version: 0.15.0\n\
Cflags: -I/usr/local/include\n\
Libs: -L/usr/local/lib -loqs\n" > /usr/lib/pkgconfig/liboqs-go.pc

# Tell the system where to find the compiled library
ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV PKG_CONFIG_PATH="/usr/lib/pkgconfig"

# Now build our Go application
WORKDIR /app

# Copy go.mod first (dependency caching optimization)
# If go.mod hasn't changed, Docker reuses cached layer = faster builds
COPY go.mod go.sum ./
# Download declared deps; go.sum may be incomplete (e.g. mysql driver added on VM).
# go mod tidy below will fetch any missing checksums.
RUN go mod download || true

# Copy our Go source code (server.go + db.go; cmd/ is excluded)
COPY *.go ./

# tidy adds any missing go.sum entries, then compile.
# CGO_ENABLED=1 is required for liboqs-go (C bindings).
RUN go mod tidy
RUN CGO_ENABLED=1 go build -o /qchain-server .

# =============================================================================
# STAGE 2: RUNTIME (Final Image)
# =============================================================================
# This stage is the actual container that runs. It's minimal and clean.

# Start with a slim Debian image (much smaller than the builder)
FROM debian:bookworm-slim AS runtime

# Install only the libraries needed to RUN (not build) the application
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy the compiled liboqs libraries from the builder stage
# --from=builder means "copy from the stage named 'builder'"
COPY --from=builder /usr/local/lib/liboqs* /usr/local/lib/
COPY --from=builder /usr/local/include/oqs /usr/local/include/oqs

# Copy our compiled Go binary from the builder stage
COPY --from=builder /qchain-server /app/qchain-server

WORKDIR /app

ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV SERVER_PORT="3000"

EXPOSE 3000
CMD ["/app/qchain-server"]
