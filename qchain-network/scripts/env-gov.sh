#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export NETWORK_ROOT="${NETWORK_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
export ORDERER_CA="${ORDERER_CA:-$NETWORK_ROOT/crypto-material/ordererOrganizations/orderer.example.com/orderers/orderer0.orderer.example.com/tls/ca.crt}"
export FABRIC_LOGGING_SPEC=ERROR
export FABRIC_CFG_PATH="$NETWORK_ROOT/config"
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=GovernmentMSP
export CORE_PEER_ADDRESS=peer0.government.uae.com:7051
export CORE_PEER_MSPCONFIGPATH="$NETWORK_ROOT/crypto-material/peerOrganizations/government.uae.com/users/Admin@government.uae.com/msp"
export CORE_PEER_TLS_ROOTCERT_FILE="$NETWORK_ROOT/crypto-material/peerOrganizations/government.uae.com/peers/peer0.government.uae.com/tls/ca.crt"
echo "Switched to Government context — peer0.government.uae.com:7051"