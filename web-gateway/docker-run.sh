#!/usr/bin/env bash
# Stop any existing web-gateway container and start a fresh one.
#
# Requirements:
#   - Image built:  bash web-gateway/docker-build.sh
#   - The Go backend running on the host at port 3000 (so /api works)
#
# Usage: bash web-gateway/docker-run.sh

set -euo pipefail

CONTAINER_NAME="qchain-web-gateway"
IMAGE="qchain-web-gateway:latest"

# ── Preflight ────────────────────────────────────────────────────────────────
if ! docker image inspect "$IMAGE" &>/dev/null; then
    echo "ERROR: Docker image '$IMAGE' not found. Run: bash web-gateway/docker-build.sh" >&2
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
    "$IMAGE"

# --network host  → the gateway shares the VM network stack, so its /api proxy
#   reaches the backend at 127.0.0.1:3000, and it listens on the VM's port 8090
#   (the port Tailscale Funnel forwards the public address to).

sleep 2
STATUS=$(docker inspect --format '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "unknown")
echo ""
echo "Container : $CONTAINER_NAME  ($STATUS)"
echo "Listens   : http://localhost:8090   (portal /, wallet /wallet/, api /api/)"
echo "Health    : curl -s http://localhost:8090/gw-health   # → ok"
echo "Logs      : docker logs -f $CONTAINER_NAME"
echo ""
echo "Next: expose it publicly with  bash qchain-network/scripts/setup-tailscale-funnel.sh"
