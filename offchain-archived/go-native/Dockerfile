# =============================================================================
# QCHAIN GO-NATIVE DOCKERFILE (Pure Go with Cloudflare CIRCL)
# =============================================================================
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │  WHAT IS THIS CONTAINER?                                                │
# ├─────────────────────────────────────────────────────────────────────────┤
# │  Same functionality as go-bindings, but uses CIRCL library instead.     │
# │                                                                         │
# │  CIRCL = Cloudflare Interoperable Reusable Cryptographic Library        │
# │  → Written in pure Go (no C code!)                                      │
# │  → Implements ML-DSA-44 (Dilithium) post-quantum signatures             │
# │  → Much simpler to build and understand                                 │
# └─────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │  WHY IS THIS SIMPLER THAN GO-BINDINGS?                                  │
# ├─────────────────────────────────────────────────────────────────────────┤
# │  go-bindings (liboqs):                                                  │
# │  → Needs C library compilation (cmake, ninja, build tools)              │
# │  → CGO enabled (Go <-> C bridge, slower builds)                         │
# │  → Final image: ~150MB                                                  │
# │                                                                         │
# │  go-native (CIRCL):                                                     │
# │  → Pure Go, no C compilation needed                                     │
# │  → CGO disabled (faster builds, simpler debugging)                      │
# │  → Final image: ~20MB (7x smaller!)                                     │
# └─────────────────────────────────────────────────────────────────────────┘
#
# =============================================================================

# =============================================================================
# STAGE 1: BUILD
# =============================================================================
# Compile our Go code into a single executable binary.

# Start with Alpine-based Go image (Alpine = tiny Linux, ~5MB base)
# "AS builder" names this stage for later reference
FROM golang:1.23-alpine AS builder

# Install git (needed for "go mod download" to fetch dependencies)
# ca-certificates = SSL certificates for HTTPS connections
# --no-cache = don't save package index (smaller image)
RUN apk add --no-cache git ca-certificates

# Set working directory inside container
WORKDIR /app

# OPTIMIZATION: Copy go.mod first, separately from code
# Why? Docker caches this layer. If go.mod hasn't changed,
# Docker reuses the cached dependencies = much faster builds!
COPY go.mod ./
RUN go mod download || true

# Copy our Go source code files
COPY *.go ./

# Download any missing dependencies
RUN go mod tidy

# Build the binary with optimizations:
# CGO_ENABLED=0 = Don't use C libraries (pure Go, portable)
# GOOS=linux    = Build for Linux (even if building on Mac/Windows)
# -ldflags="-w -s" = Strip debug info (smaller binary)
# -o /qchain-native = Output file location
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o /qchain-native .

# =============================================================================
# STAGE 2: RUNTIME (Final Image)
# =============================================================================
# Minimal image with just our binary. Build tools are discarded!

# Alpine 3.19 is a tiny Linux distribution (~5MB)
# Perfect for running a single Go binary
FROM alpine:3.19 AS runtime

# Install CA certificates (needed for HTTPS connections to IPFS)
RUN apk add --no-cache ca-certificates

# SECURITY: Create a non-root user to run the application
# Running as root inside containers is a security risk
RUN addgroup -S qchain && adduser -S qchain -G qchain

WORKDIR /app

# Copy ONLY the compiled binary from the builder stage
# Everything else (source code, build tools) is discarded
COPY --from=builder /qchain-native /app/qchain-native

# Set file ownership to our non-root user
RUN chown -R qchain:qchain /app

# Switch to non-root user (more secure)
USER qchain

# Default IPFS connection settings
# These are overridden by docker-compose.yml environment variables
ENV IPFS_API_HOST="localhost"
ENV IPFS_API_PORT="5001"

# When container starts, run our application
CMD ["/app/qchain-native"]
