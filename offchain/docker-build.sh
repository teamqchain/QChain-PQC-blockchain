#!/usr/bin/env bash
# Build the QChain API Docker image.
# Run from the repo root OR from offchain/ — script handles both.
#
# Usage: bash offchain/docker-build.sh
#
# First build takes ~20 min (liboqs compiles from source).
# Subsequent builds are cached and take ~2 min.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Building qchain-api Docker image ==="
echo "    Context : $SCRIPT_DIR"
echo "    This takes ~20 min on first build (liboqs compilation)."
echo ""

docker build \
    --tag qchain-api:latest \
    "$SCRIPT_DIR"

echo ""
echo "=== Build complete ==="
echo "Image: qchain-api:latest"
echo "Run  : bash offchain/docker-run.sh"
