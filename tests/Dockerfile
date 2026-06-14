FROM golang:1.23-bookworm

# Install build dependencies for the liboqs C library
RUN apt-get update && apt-get install -y \
    cmake \
    ninja-build \
    build-essential \
    libssl-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# Clone and build liboqs (required by liboqs-go)
RUN git clone --branch main https://github.com/open-quantum-safe/liboqs.git && \
    cd liboqs && \
    mkdir build && cd build && \
    cmake -GNinja -DOQS_USE_OPENSSL=ON -DBUILD_SHARED_LIBS=ON .. && \
    ninja && ninja install

# Ensure the Go binary can find the liboqs shared library at runtime
ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

WORKDIR /app

# Download Go modules
COPY go.mod ./
# Note: If you have a go.sum file, change the line above to: COPY go.mod go.sum ./
RUN go mod download

# Copy the source code
COPY server.go ./

# Build the application
RUN go build -o qchain-server server.go

# Expose the default server port
EXPOSE 3000

# Run the binary
CMD ["./qchain-server"]