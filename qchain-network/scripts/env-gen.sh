#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export NETWORK_ROOT="${NETWORK_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
export ORDERER_CA="${ORDERER_CA:-$NETWORK_ROOT/crypto-material/ordererOrganizations/orderer.example.com/orderers/orderer0.orderer.example.com/tls/ca.crt}"
export FABRIC_LOGGING_SPEC=ERROR
export FABRIC_CFG_PATH="$NETWORK_ROOT/config"
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=GeneralMSP
export CORE_PEER_ADDRESS=peer0.general.uae.com:9051
export CORE_PEER_MSPCONFIGPATH="$NETWORK_ROOT/crypto-material/peerOrganizations/general.uae.com/users/Admin@general.uae.com/msp"
export CORE_PEER_TLS_ROOTCERT_FILE="$NETWORK_ROOT/crypto-material/peerOrganizations/general.uae.com/peers/peer0.general.uae.com/tls/ca.crt"
echo "Switched to General context — peer0.general.uae.com:9051"