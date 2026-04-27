#!/bin/bash
set -e

NETWORK_ROOT=$(cd "$(dirname "$0")/.." && pwd)
export PATH=$PATH:~/fabric/build/bin

echo "========== Government =========="

echo "========== Enrolling Government CA Admin =========="
mkdir -p $NETWORK_ROOT/crypto-material/peerOrganizations/government.uae.com
export FABRIC_CA_CLIENT_HOME=$NETWORK_ROOT/crypto-material/peerOrganizations/government.uae.com

fabric-ca-client enroll \
  -u https://admin:adminpw@ca.government.uae.com:7054 \
  --caname GovernmentCA \
  --tls.certfiles $NETWORK_ROOT/fabric-ca/government/ca-cert.pem

echo 'NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/ca.government.uae.com-7054-GovernmentCA.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/ca.government.uae.com-7054-GovernmentCA.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/ca.government.uae.com-7054-GovernmentCA.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/ca.government.uae.com-7054-GovernmentCA.pem
    OrganizationalUnitIdentifier: orderer' > $FABRIC_CA_CLIENT_HOME/msp/config.yaml

mkdir -p $FABRIC_CA_CLIENT_HOME/msp/tlscacerts
cp $NETWORK_ROOT/fabric-ca/government/ca-cert.pem \
   $FABRIC_CA_CLIENT_HOME/msp/tlscacerts/ca.crt

mkdir -p $FABRIC_CA_CLIENT_HOME/tlsca
cp $NETWORK_ROOT/fabric-ca/government/ca-cert.pem \
   $FABRIC_CA_CLIENT_HOME/tlsca/tlsca.government.uae.com-cert.pem

mkdir -p $FABRIC_CA_CLIENT_HOME/ca
cp $NETWORK_ROOT/fabric-ca/government/ca-cert.pem \
   $FABRIC_CA_CLIENT_HOME/ca/ca.government.uae.com-cert.pem

echo "========== Registering Government peer0 =========="
fabric-ca-client register \
  --caname GovernmentCA \
  --id.name peer0.government.uae.com \
  --id.secret peer0pw \
  --id.type peer \
  --tls.certfiles $NETWORK_ROOT/fabric-ca/government/ca-cert.pem

echo "========== Registering Government admin =========="
fabric-ca-client register \
  --caname GovernmentCA \
  --id.name org1admin \
  --id.secret org1adminpw \
  --id.type admin \
  --tls.certfiles $NETWORK_ROOT/fabric-ca/government/ca-cert.pem

echo "========== Enrolling Government peer0 =========="
mkdir -p $NETWORK_ROOT/crypto-material/peerOrganizations/government.uae.com/peers/peer0.government.uae.com
export FABRIC_CA_CLIENT_HOME=$NETWORK_ROOT/crypto-material/peerOrganizations/government.uae.com/peers/peer0.government.uae.com

fabric-ca-client enroll \
  -u https://peer0.government.uae.com:peer0pw@ca.government.uae.com:7054 \
  --caname GovernmentCA \
  --csr.hosts peer0.government.uae.com \
  --tls.certfiles $NETWORK_ROOT/fabric-ca/government/ca-cert.pem

cp $NETWORK_ROOT/crypto-material/peerOrganizations/government.uae.com/msp/config.yaml \
   $NETWORK_ROOT/crypto-material/peerOrganizations/government.uae.com/peers/peer0.government.uae.com/msp/config.yaml

fabric-ca-client enroll \
  -u https://peer0.government.uae.com:peer0pw@ca.government.uae.com:7054 \
  --caname GovernmentCA \
  --enrollment.profile tls \
  --csr.hosts peer0.government.uae.com \
  --csr.hosts localhost \
  -M $NETWORK_ROOT/crypto-material/peerOrganizations/government.uae.com/peers/peer0.government.uae.com/tls \
  --tls.certfiles $NETWORK_ROOT/fabric-ca/government/ca-cert.pem

TLS=$NETWORK_ROOT/crypto-material/peerOrganizations/government.uae.com/peers/peer0.government.uae.com/tls
cp $TLS/tlscacerts/*.pem $TLS/ca.crt
cp $TLS/signcerts/*.pem  $TLS/server.crt
cp $TLS/keystore/*_sk   $TLS/server.key

mkdir -p $NETWORK_ROOT/crypto-material/peerOrganizations/government.uae.com/tlsca
cp $TLS/ca.crt \
   $NETWORK_ROOT/crypto-material/peerOrganizations/government.uae.com/tlsca/tlsca.government.uae.com-cert.pem

echo "========== Enrolling Government Admin User =========="
mkdir -p $NETWORK_ROOT/crypto-material/peerOrganizations/government.uae.com/users/Admin@government.uae.com
export FABRIC_CA_CLIENT_HOME=$NETWORK_ROOT/crypto-material/peerOrganizations/government.uae.com/users/Admin@government.uae.com

fabric-ca-client enroll \
  -u https://org1admin:org1adminpw@ca.government.uae.com:7054 \
  --caname GovernmentCA \
  --tls.certfiles $NETWORK_ROOT/fabric-ca/government/ca-cert.pem

cp $NETWORK_ROOT/crypto-material/peerOrganizations/government.uae.com/msp/config.yaml \
   $NETWORK_ROOT/crypto-material/peerOrganizations/government.uae.com/users/Admin@government.uae.com/msp/config.yaml

echo "========== General =========="

echo "========== Enrolling General CA Admin =========="
mkdir -p $NETWORK_ROOT/crypto-material/peerOrganizations/general.uae.com
export FABRIC_CA_CLIENT_HOME=$NETWORK_ROOT/crypto-material/peerOrganizations/general.uae.com

fabric-ca-client enroll \
  -u https://admin:adminpw@ca.general.uae.com:8054 \
  --caname GeneralCA \
  --tls.certfiles $NETWORK_ROOT/fabric-ca/general/ca-cert.pem

echo 'NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/ca.general.uae.com-8054-GeneralCA.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/ca.general.uae.com-8054-GeneralCA.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/ca.general.uae.com-8054-GeneralCA.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/ca.general.uae.com-8054-GeneralCA.pem
    OrganizationalUnitIdentifier: orderer' > $FABRIC_CA_CLIENT_HOME/msp/config.yaml

mkdir -p $FABRIC_CA_CLIENT_HOME/msp/tlscacerts
cp $NETWORK_ROOT/fabric-ca/general/ca-cert.pem \
   $FABRIC_CA_CLIENT_HOME/msp/tlscacerts/ca.crt

mkdir -p $FABRIC_CA_CLIENT_HOME/tlsca
cp $NETWORK_ROOT/fabric-ca/general/ca-cert.pem \
   $FABRIC_CA_CLIENT_HOME/tlsca/tlsca.general.uae.com-cert.pem

mkdir -p $FABRIC_CA_CLIENT_HOME/ca
cp $NETWORK_ROOT/fabric-ca/general/ca-cert.pem \
   $FABRIC_CA_CLIENT_HOME/ca/ca.general.uae.com-cert.pem

echo "========== Registering General peer0 =========="
fabric-ca-client register \
  --caname GeneralCA \
  --id.name peer0.general.uae.com \
  --id.secret peer0pw \
  --id.type peer \
  --tls.certfiles $NETWORK_ROOT/fabric-ca/general/ca-cert.pem

echo "========== Registering General admin =========="
fabric-ca-client register \
  --caname GeneralCA \
  --id.name org2admin \
  --id.secret org2adminpw \
  --id.type admin \
  --tls.certfiles $NETWORK_ROOT/fabric-ca/general/ca-cert.pem

echo "========== Enrolling General peer0 =========="
mkdir -p $NETWORK_ROOT/crypto-material/peerOrganizations/general.uae.com/peers/peer0.general.uae.com
export FABRIC_CA_CLIENT_HOME=$NETWORK_ROOT/crypto-material/peerOrganizations/general.uae.com/peers/peer0.general.uae.com

fabric-ca-client enroll \
  -u https://peer0.general.uae.com:peer0pw@ca.general.uae.com:8054 \
  --caname GeneralCA \
  --csr.hosts peer0.general.uae.com \
  --tls.certfiles $NETWORK_ROOT/fabric-ca/general/ca-cert.pem

cp $NETWORK_ROOT/crypto-material/peerOrganizations/general.uae.com/msp/config.yaml \
   $NETWORK_ROOT/crypto-material/peerOrganizations/general.uae.com/peers/peer0.general.uae.com/msp/config.yaml

fabric-ca-client enroll \
  -u https://peer0.general.uae.com:peer0pw@ca.general.uae.com:8054 \
  --caname GeneralCA \
  --enrollment.profile tls \
  --csr.hosts peer0.general.uae.com \
  --csr.hosts localhost \
  -M $NETWORK_ROOT/crypto-material/peerOrganizations/general.uae.com/peers/peer0.general.uae.com/tls \
  --tls.certfiles $NETWORK_ROOT/fabric-ca/general/ca-cert.pem

TLS=$NETWORK_ROOT/crypto-material/peerOrganizations/general.uae.com/peers/peer0.general.uae.com/tls
cp $TLS/tlscacerts/*.pem $TLS/ca.crt
cp $TLS/signcerts/*.pem  $TLS/server.crt
cp $TLS/keystore/*_sk   $TLS/server.key

mkdir -p $NETWORK_ROOT/crypto-material/peerOrganizations/general.uae.com/tlsca
cp $TLS/ca.crt \
   $NETWORK_ROOT/crypto-material/peerOrganizations/general.uae.com/tlsca/tlsca.general.uae.com-cert.pem

echo "========== Enrolling General Admin User =========="
mkdir -p $NETWORK_ROOT/crypto-material/peerOrganizations/general.uae.com/users/Admin@general.uae.com
export FABRIC_CA_CLIENT_HOME=$NETWORK_ROOT/crypto-material/peerOrganizations/general.uae.com/users/Admin@general.uae.com

fabric-ca-client enroll \
  -u https://org2admin:org2adminpw@ca.general.uae.com:8054 \
  --caname GeneralCA \
  --tls.certfiles $NETWORK_ROOT/fabric-ca/general/ca-cert.pem

cp $NETWORK_ROOT/crypto-material/peerOrganizations/general.uae.com/msp/config.yaml \
   $NETWORK_ROOT/crypto-material/peerOrganizations/general.uae.com/users/Admin@general.uae.com/msp/config.yaml

echo "========== Orderer =========="

echo "========== Enrolling Orderer CA Admin =========="
mkdir -p $NETWORK_ROOT/crypto-material/ordererOrganizations/orderer.example.com
export FABRIC_CA_CLIENT_HOME=$NETWORK_ROOT/crypto-material/ordererOrganizations/orderer.example.com

fabric-ca-client enroll \
  -u https://admin:adminpw@ca.orderer.example.com:9054 \
  --caname OrdererCA \
  --tls.certfiles $NETWORK_ROOT/fabric-ca/orderer/ca-cert.pem

echo 'NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/ca.orderer.example.com-9054-OrdererCA.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/ca.orderer.example.com-9054-OrdererCA.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/ca.orderer.example.com-9054-OrdererCA.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/ca.orderer.example.com-9054-OrdererCA.pem
    OrganizationalUnitIdentifier: orderer' > $FABRIC_CA_CLIENT_HOME/msp/config.yaml

mkdir -p $FABRIC_CA_CLIENT_HOME/msp/tlscacerts
cp $NETWORK_ROOT/fabric-ca/orderer/ca-cert.pem \
   $FABRIC_CA_CLIENT_HOME/msp/tlscacerts/tlsca.orderer.example.com-cert.pem

mkdir -p $FABRIC_CA_CLIENT_HOME/tlsca
cp $NETWORK_ROOT/fabric-ca/orderer/ca-cert.pem \
   $FABRIC_CA_CLIENT_HOME/tlsca/tlsca.orderer.example.com-cert.pem

echo "========== Registering Orderer orderer0 =========="
fabric-ca-client register \
  --caname OrdererCA \
  --id.name orderer0.orderer.example.com \
  --id.secret orderer0pw \
  --id.type orderer \
  --tls.certfiles $NETWORK_ROOT/fabric-ca/orderer/ca-cert.pem

echo "========== Registering Orderer admin =========="
fabric-ca-client register \
  --caname OrdererCA \
  --id.name ordererAdmin \
  --id.secret ordererAdminpw \
  --id.type admin \
  --tls.certfiles $NETWORK_ROOT/fabric-ca/orderer/ca-cert.pem

echo "========== Enrolling Orderer orderer0 =========="
mkdir -p $NETWORK_ROOT/crypto-material/ordererOrganizations/orderer.example.com/orderers/orderer0.orderer.example.com
export FABRIC_CA_CLIENT_HOME=$NETWORK_ROOT/crypto-material/ordererOrganizations/orderer.example.com/orderers/orderer0.orderer.example.com

fabric-ca-client enroll \
  -u https://orderer0.orderer.example.com:orderer0pw@ca.orderer.example.com:9054 \
  --caname OrdererCA \
  --csr.hosts orderer0.orderer.example.com \
  --tls.certfiles $NETWORK_ROOT/fabric-ca/orderer/ca-cert.pem

cp $NETWORK_ROOT/crypto-material/ordererOrganizations/orderer.example.com/msp/config.yaml \
   $NETWORK_ROOT/crypto-material/ordererOrganizations/orderer.example.com/orderers/orderer0.orderer.example.com/msp/config.yaml

fabric-ca-client enroll \
  -u https://orderer0.orderer.example.com:orderer0pw@ca.orderer.example.com:9054 \
  --caname OrdererCA \
  --enrollment.profile tls \
  --csr.hosts orderer0.orderer.example.com \
  --csr.hosts localhost \
  -M $NETWORK_ROOT/crypto-material/ordererOrganizations/orderer.example.com/orderers/orderer0.orderer.example.com/tls \
  --tls.certfiles $NETWORK_ROOT/fabric-ca/orderer/ca-cert.pem

TLS=$NETWORK_ROOT/crypto-material/ordererOrganizations/orderer.example.com/orderers/orderer0.orderer.example.com/tls
cp $TLS/tlscacerts/*.pem $TLS/ca.crt
cp $TLS/signcerts/*.pem  $TLS/server.crt
cp $TLS/keystore/*_sk   $TLS/server.key

mkdir -p $NETWORK_ROOT/crypto-material/ordererOrganizations/orderer.example.com/tlsca
cp $TLS/ca.crt \
   $NETWORK_ROOT/crypto-material/ordererOrganizations/orderer.example.com/tlsca/tlsca.orderer.example.com-cert.pem

echo "========== Enrolling Orderer Admin User =========="
mkdir -p $NETWORK_ROOT/crypto-material/ordererOrganizations/orderer.example.com/users/Admin@orderer.example.com
export FABRIC_CA_CLIENT_HOME=$NETWORK_ROOT/crypto-material/ordererOrganizations/orderer.example.com/users/Admin@orderer.example.com

fabric-ca-client enroll \
  -u https://ordererAdmin:ordererAdminpw@ca.orderer.example.com:9054 \
  --caname OrdererCA \
  --tls.certfiles $NETWORK_ROOT/fabric-ca/orderer/ca-cert.pem

cp $NETWORK_ROOT/crypto-material/ordererOrganizations/orderer.example.com/msp/config.yaml \
   $NETWORK_ROOT/crypto-material/ordererOrganizations/orderer.example.com/users/Admin@orderer.example.com/msp/config.yaml

echo "Enrollment complete. crypto-material/ is ready."