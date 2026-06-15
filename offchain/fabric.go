package main

// fabric.go — connecting to the Hyperledger Fabric blockchain.
//
// To talk to the ledger we must present a signed identity (an X.509 certificate
// + private key) that belongs to one of the network's organizations. Those
// identities live in the Fabric "wallet" as .id files. getContract loads an
// identity, opens a mutually-authenticated TLS gRPC connection to that org's
// peer, and hands back a Contract object the handlers use to evaluate (read) or
// submit (write) chaincode transactions.

import (
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/hyperledger/fabric-gateway/pkg/client"
	"github.com/hyperledger/fabric-gateway/pkg/identity"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
)

// walletIDFile mirrors the JSON shape of a Fabric wallet ".id" file. The nested
// `Credentials` field is an anonymous struct because it is only used here.
type walletIDFile struct {
	Credentials struct {
		Certificate string `json:"certificate"`
		PrivateKey  string `json:"privateKey"`
	} `json:"credentials"`
	MspID   string `json:"mspId"`
	Type    string `json:"type"`
	Version int    `json:"version"`
}

// loadWalletIdentity reads the certificate and private key PEM bytes for the
// named identity (e.g. "issuer1") in the given org's wallet.
func loadWalletIdentity(orgLC, identityName string) (certPEM, keyPEM []byte, err error) {
	idFilePath := filepath.Join(walletDir(orgLC), identityName+".id")
	data, err := os.ReadFile(idFilePath)
	if err != nil {
		return nil, nil, fmt.Errorf("wallet identity %q not found for org %q (expected at %s): %w",
			identityName, orgLC, idFilePath, err)
	}
	var idFile walletIDFile
	if err := json.Unmarshal(data, &idFile); err != nil {
		return nil, nil, fmt.Errorf("parsing wallet .id file %s: %w", idFilePath, err)
	}
	if idFile.Credentials.Certificate == "" {
		return nil, nil, fmt.Errorf("wallet .id file %s has no certificate", idFilePath)
	}
	if idFile.Credentials.PrivateKey == "" {
		return nil, nil, fmt.Errorf("wallet .id file %s has no privateKey", idFilePath)
	}
	return []byte(idFile.Credentials.Certificate), []byte(idFile.Credentials.PrivateKey), nil
}

// getContract connects to a peer as the given org/identity and returns the
// chaincode Contract plus the Gateway and gRPC connection. The caller is
// responsible for closing the Gateway and connection (typically via `defer`).
func getContract(orgName, identityName string) (*client.Contract, *client.Gateway, *grpc.ClientConn, error) {
	orgLC := strings.ToLower(orgName)
	cfg, ok := orgConfig[orgLC]
	if !ok {
		return nil, nil, nil, fmt.Errorf("unknown org %q", orgName)
	}

	peerHostname := strings.Split(cfg.PeerEndpoint, ":")[0]
	tlsCACertPath := filepath.Join(mspDir(orgLC), "peers", peerHostname, "tls", "ca.crt")
	tlsCACert, err := os.ReadFile(tlsCACertPath)
	if err != nil {
		return nil, nil, nil, fmt.Errorf("reading TLS CA cert at %s: %w", tlsCACertPath, err)
	}
	certPool := x509.NewCertPool()
	certPool.AppendCertsFromPEM(tlsCACert)
	tlsCreds := credentials.NewClientTLSFromCert(certPool, cfg.GatewayPeer)

	conn, err := grpc.Dial(cfg.PeerEndpoint, grpc.WithTransportCredentials(tlsCreds))
	if err != nil {
		return nil, nil, nil, fmt.Errorf("grpc dial to %s: %w", cfg.PeerEndpoint, err)
	}

	certPEM, keyPEM, err := loadWalletIdentity(orgLC, identityName)
	if err != nil {
		conn.Close()
		return nil, nil, nil, err
	}

	block, _ := pem.Decode(certPEM)
	if block == nil {
		conn.Close()
		return nil, nil, nil, fmt.Errorf("failed to PEM-decode certificate for identity %q", identityName)
	}
	cert, err := x509.ParseCertificate(block.Bytes)
	if err != nil {
		conn.Close()
		return nil, nil, nil, fmt.Errorf("parsing certificate: %w", err)
	}

	id, err := identity.NewX509Identity(cfg.MSPID, cert)
	if err != nil {
		conn.Close()
		return nil, nil, nil, fmt.Errorf("creating X509 identity: %w", err)
	}

	privateKey, err := identity.PrivateKeyFromPEM(keyPEM)
	if err != nil {
		conn.Close()
		return nil, nil, nil, fmt.Errorf("parsing private key: %w", err)
	}

	sign, err := identity.NewPrivateKeySign(privateKey)
	if err != nil {
		conn.Close()
		return nil, nil, nil, fmt.Errorf("creating signer: %w", err)
	}

	gw, err := client.Connect(id,
		client.WithSign(sign),
		client.WithClientConnection(conn),
		client.WithEvaluateTimeout(30*time.Second),
		client.WithEndorseTimeout(30*time.Second),
		client.WithSubmitTimeout(30*time.Second),
		client.WithCommitStatusTimeout(60*time.Second),
	)
	if err != nil {
		conn.Close()
		return nil, nil, nil, fmt.Errorf("gateway connect: %w", err)
	}

	network := gw.GetNetwork(channelName)
	contract := network.GetContract(chaincodeName)
	return contract, gw, conn, nil
}
