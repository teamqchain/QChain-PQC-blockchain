# =============================================================================
# QChain Go-Bindings Dockerfile (liboqs-go with CGO)
# Multi-stage build for smaller production images
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Build Environment
# -----------------------------------------------------------------------------
FROM golang:1.23-bookworm AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake \
    ninja-build \
    build-essential \
    git \
    libssl-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Build liboqs from source
WORKDIR /tmp
RUN git clone --branch main --single-branch --depth 1 \
    https://github.com/open-quantum-safe/liboqs.git \
    && cd liboqs \
    && mkdir build && cd build \
    && cmake -GNinja -DBUILD_SHARED_LIBS=ON .. \
    && ninja \
    && ninja install

# Create pkg-config file for Go bindings
RUN mkdir -p /usr/lib/pkgconfig && \
    printf "Name: liboqs-go\n\
Description: Go bindings for liboqs\n\
Version: 0.15.0\n\
Cflags: -I/usr/local/include\n\
Libs: -L/usr/local/lib -loqs\n" > /usr/lib/pkgconfig/liboqs-go.pc

# Set library path
ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV PKG_CONFIG_PATH="/usr/lib/pkgconfig"

# Build Go application
WORKDIR /app

# Copy go.mod first for better layer caching
COPY go.mod ./
RUN go mod download || true

# Copy source code
COPY *.go ./

# Download dependencies and build
RUN go mod tidy
RUN CGO_ENABLED=1 go build -o /qchain-bindings .

# -----------------------------------------------------------------------------
# Stage 2: Runtime (smaller image)
# -----------------------------------------------------------------------------
FROM debian:bookworm-slim AS runtime

# Install runtime dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy liboqs libraries from builder
COPY --from=builder /usr/local/lib/liboqs* /usr/local/lib/
COPY --from=builder /usr/local/include/oqs /usr/local/include/oqs

# Copy built binary
COPY --from=builder /qchain-bindings /app/qchain-bindings

WORKDIR /app

# Set library path for runtime
ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV IPFS_API_HOST="localhost"
ENV IPFS_API_PORT="5001"

CMD ["/app/qchain-bindings"]
