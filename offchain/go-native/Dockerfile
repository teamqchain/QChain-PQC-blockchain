# =============================================================================
# QChain Go-Native Dockerfile (Cloudflare CIRCL - Pure Go)
# Lightweight Alpine-based image, no CGO required
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Build
# -----------------------------------------------------------------------------
FROM golang:1.23-alpine AS builder

# Install git (needed for go mod download)
RUN apk add --no-cache git ca-certificates

WORKDIR /app

# Copy go.mod first for better layer caching
COPY go.mod ./
RUN go mod download || true

# Copy source code
COPY *.go ./

# Download dependencies and build static binary
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o /qchain-native .

# -----------------------------------------------------------------------------
# Stage 2: Minimal Runtime
# -----------------------------------------------------------------------------
FROM alpine:3.19 AS runtime

# Install CA certificates for HTTPS
RUN apk add --no-cache ca-certificates

# Create non-root user for security
RUN addgroup -S qchain && adduser -S qchain -G qchain

WORKDIR /app

# Copy binary from builder
COPY --from=builder /qchain-native /app/qchain-native

# Change ownership
RUN chown -R qchain:qchain /app

USER qchain

ENV IPFS_API_HOST="localhost"
ENV IPFS_API_PORT="5001"

CMD ["/app/qchain-native"]
