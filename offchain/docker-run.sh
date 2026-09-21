#!/usr/bin/env bash
# Stop any existing qchain-api container and start a fresh one.
#
# Requirements:
#   - Docker image built: bash offchain/docker-build.sh
#   - offchain/.env file present with all required vars
#   - qchain-network/ directory present at NETWORK_ROOT
#
# Usage: bash offchain/docker-run.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ENV_FILE="$SCRIPT_DIR/.env"
NETWORK_DIR="$REPO_ROOT/qchain-network"
CONTAINER_NAME="qchain-api"
IMAGE="qchain-api:latest"

# ── Preflight checks ────────────────────────────────────────────────────────
if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: $ENV_FILE not found." >&2
    echo "  Copy offchain/.env.example to offchain/.env and fill in the values." >&2
    exit 1
fi

if [[ ! -d "$NETWORK_DIR" ]]; then
    echo "ERROR: $NETWORK_DIR not found." >&2
    exit 1
fi

if ! docker image inspect "$IMAGE" &>/dev/null; then
    echo "ERROR: Docker image '$IMAGE' not found. Run: bash offchain/docker-build.sh" >&2
    exit 1
fi

# ── Stop and remove old container ───────────────────────────────────────────
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Stopping old container: $CONTAINER_NAME"
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm   "$CONTAINER_NAME" 2>/dev/null || true
fi

# ── Start new container ─────────────────────────────────────────────────────
echo "Starting $CONTAINER_NAME ..."

docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --network host \
    -v "${NETWORK_DIR}:/qchain-network:ro" \
    --env-file "$ENV_FILE" \
    -e NETWORK_ROOT=/qchain-network \
    "$IMAGE"

# --network host  → container shares the host network stack:
#   • 127.0.0.1:5001 reaches the IPFS daemon
#   • 127.0.0.1:3306 reaches MySQL
#   • Fabric peer hostnames resolve via /etc/hosts

sleep 2
STATUS=$(docker inspect --format '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "unknown")
echo ""
echo "Container : $CONTAINER_NAME  ($STATUS)"
echo "Port      : http://localhost:3000"
echo "Logs      : docker logs -f $CONTAINER_NAME"
echo "Health    : curl -s http://localhost:3000/health"
