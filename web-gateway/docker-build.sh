#!/usr/bin/env bash
# Build the QChain web-gateway image (both Flutter web apps + Nginx gateway).
#
# Usage:
#   export API_BASE_URL="https://<vm>.<tailnet>.ts.net/api"
#   bash web-gateway/docker-build.sh
#
# API_BASE_URL is baked into the Flutter apps at build time (they are
# client-side, so they must know the PUBLIC backend address). If you don't set
# it, the script tries to derive it from this node's Tailscale name. Rebuild
# only when the frontend code changes or the public URL changes (it won't, with
# a Tailscale Funnel address — that's the whole point).
#
# First build is slow (two Flutter web compilations); later builds are cached.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE="qchain-web-gateway:latest"

# ── Resolve API_BASE_URL ─────────────────────────────────────────────────────
# Prefer the explicit env var. Otherwise, best-effort derive it from the local
# Tailscale node's DNS name (needs tailscale + python3). If neither works, stop
# with clear instructions — building with the wrong URL would bake a dead
# address into the apps.
if [[ -z "${API_BASE_URL:-}" ]]; then
    SELF_HOST=""
    if command -v tailscale >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
        SELF_HOST="$(tailscale status --json 2>/dev/null \
            | python3 -c 'import sys,json; print(json.load(sys.stdin).get("Self",{}).get("DNSName","").rstrip("."))' 2>/dev/null || true)"
    fi
    if [[ -n "$SELF_HOST" ]]; then
        API_BASE_URL="https://${SELF_HOST}/api"
        echo "Derived API_BASE_URL from Tailscale: $API_BASE_URL"
    else
        echo "ERROR: API_BASE_URL is not set and could not be derived from Tailscale." >&2
        echo "  Set it to your Funnel URL + /api, for example:" >&2
        echo "      export API_BASE_URL=\"https://<vm>.<tailnet>.ts.net/api\"" >&2
        echo "  Find your hostname with:  tailscale status   (or the Tailscale admin console)" >&2
        exit 1
    fi
fi

echo "=== Building $IMAGE ==="
echo "    Context      : $REPO_ROOT"
echo "    API_BASE_URL : $API_BASE_URL"
echo "    Note: first build compiles BOTH Flutter web apps — this takes a while."
echo ""

docker build \
    --build-arg API_BASE_URL="$API_BASE_URL" \
    -f "$SCRIPT_DIR/Dockerfile" \
    -t "$IMAGE" \
    "$REPO_ROOT"

echo ""
echo "=== Build complete ==="
echo "Image : $IMAGE"
echo "Run   : bash web-gateway/docker-run.sh"
