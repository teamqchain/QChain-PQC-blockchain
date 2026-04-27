#!/bin/bash
NETWORK_ROOT="$HOME/Desktop/QChain/QChain-PQC-blockchain/qchain-network"
export NETWORK_ROOT="$HOME/Desktop/QChain/QChain-PQC-blockchain/qchain-network"
export FABRIC_LOGGING_SPEC=ERROR
export FABRIC_CFG_PATH="$NETWORK_ROOT/config"
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=GovernmentMSP
export CORE_PEER_ADDRESS=peer0.government.uae.com:7051
export CORE_PEER_MSPCONFIGPATH="$NETWORK_ROOT/crypto-material/peerOrganizations/government.uae.com/users/Admin@government.uae.com/msp"
export CORE_PEER_TLS_ROOTCERT_FILE="$NETWORK_ROOT/crypto-material/peerOrganizations/government.uae.com/peers/peer0.government.uae.com/tls/ca.crt"
echo "Switched to Government context — peer0.government.uae.com:7051"