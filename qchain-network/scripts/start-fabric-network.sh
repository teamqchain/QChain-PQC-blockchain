#!/usr/bin/env bash
# Brings up the full QChain Hyperledger Fabric network (3 CA servers, orderer,
# 2 peers, CouchDB) in the correct order. Safe to re-run — docker compose
# just (re)starts already-existing containers if nothing changed.
#
# Deliberately does NOT touch the `ipfs` or `qchain-server` services defined
# in docker-compose.yaml:
#   - `ipfs` would port-conflict with the systemd IPFS daemon that's the one
#     actually in use (ports 5001/8080) — that daemon is managed separately
#     and already survives a reboot on its own.
#   - `qchain-server` is a stale, broken legacy service definition (points at
#     a now-nonexistent offchain/go-bindings build path) unrelated to the
#     current backend, which runs as its own standalone `offchain/` container
#     started via offchain/docker-run.sh.
#
# Called automatically at boot by the qchain-fabric.service systemd unit
# (installed by setup-fabric-autostart.sh). Can also be run manually any time
# the Fabric containers need to be brought back up after being stopped.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(cd "$SCRIPT_DIR/../docker" && pwd)"

echo "=== Starting QChain Fabric CA servers ==="
docker compose -f "$DOCKER_DIR/docker-compose-ca.yaml" up -d

echo "=== Starting QChain Fabric network (orderer, peers, CouchDB) ==="
docker compose -f "$DOCKER_DIR/docker-compose.yaml" up -d \
    orderer0.orderer.example.com \
    couchdb0 \
    peer0.government.uae.com \
    peer0.general.uae.com

echo "=== QChain Fabric network started ==="
