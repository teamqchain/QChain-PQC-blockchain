# Start with the official Go image (Linux based)
FROM golang:1.23-bookworm

# 1. Install Build Tools & Dependencies
# Added 'pkg-config' so Go can locate the C libraries
RUN apt-get update && apt-get install -y \
    cmake \
    ninja-build \
    build-essential \
    python3-pytest \
    python3-yaml \
    git \
    libssl-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# 2. Download & Build liboqs (The C Library)
WORKDIR /tmp
RUN git clone --branch main --single-branch https://github.com/open-quantum-safe/liboqs.git \
    && cd liboqs \
    && mkdir build \
    && cd build \
    && cmake -GNinja -DBUILD_SHARED_LIBS=ON .. \
    && ninja \
    && ninja install

# 3. Create the pkg-config file for the Go Wrapper
# We manually write the configuration file that Go is complaining about missing
RUN mkdir -p /usr/lib/pkgconfig && \
    printf "Name: liboqs-go\nDescription: Go bindings for liboqs\nVersion: 0.15.0\nCflags: -I/usr/local/include\nLibs: -L/usr/local/lib -loqs\n" > /usr/lib/pkgconfig/liboqs-go.pc

# 4. Tell Linux where the compiled libraries are
ENV LD_LIBRARY_PATH="/usr/local/lib"

# 5. Set Up Your Project Directory
WORKDIR /app
COPY . .

# 6. Initialize Go Module and get libraries
RUN go mod init qc-project || true
RUN go get github.com/open-quantum-safe/liboqs-go/oqs
RUN go get github.com/ipfs/go-ipfs-api

# 7. Run the app
CMD ["go", "run", "main.go"]