package main

// config.go — process configuration and shared constants.
//
// Everything here is read once at startup from environment variables (with safe
// fallbacks) and then treated as read-only for the rest of the program. Keeping
// it in one file means there is a single place to look when you want to know
// "what knobs can the deployment turn?".
//
// In Go, every file in this folder is part of `package main`, so the variables
// and functions declared here are visible to every other file in the package
// (server.go, credentials.go, db_*.go, ...) without any import between them.

import (
	"os"
	"path/filepath"
	"time"

	// Embed the IANA timezone database in the binary so time.LoadLocation
	// ("Asia/Dubai") works even in a minimal container that has no OS tzdata.
	// Without this, mustLoadLocation below silently falls back to UTC.
	_ "time/tzdata"
)

// ─────────────────────────────────────────────
//  CONFIGURATION (override via environment vars)
// ─────────────────────────────────────────────

// getEnv returns the value of environment variable `key`, or `fallback` when
// the variable is unset/empty.
func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

var networkRoot = getEnv("NETWORK_ROOT", "/qchain-network")

var (
	ipfsHost      = getEnv("IPFS_HOST", "host.docker.internal:5001")
	serverPort    = getEnv("SERVER_PORT", "3000")
	channelName   = getEnv("CHANNEL_NAME", "mychannel")
	chaincodeName = getEnv("CHAINCODE_NAME", "qchaincode")

	// All issuances use this org/identity from Fabric wallet — never sent by client.
	issuerOrgName    = getEnv("ISSUER_ORG", "general")
	issuerIdentity   = getEnv("ISSUER_IDENTITY", "issuer1")
	verifierOrgName  = getEnv("VERIFIER_ORG", "general")
	verifierIdentity = getEnv("VERIFIER_IDENTITY", "verifier1")

	// Org-level ML-DSA-44 key pair — loaded at startup from env, never generated per-credential.
	// These are assigned in main() (server.go); declared here so the whole package can read them.
	issuerPrivKeyHex string
	issuerPubKeyHex  string
	issuerOrgID      string

	// orgConfig maps an org short-name ("general"/"government") to its Fabric peer
	// endpoint and MSP ID. `struct { ... }` here is an anonymous struct type — the
	// map's value type is defined inline because it is only used here.
	orgConfig = map[string]struct {
		PeerEndpoint string
		GatewayPeer  string
		MSPID        string
	}{
		"government": {
			PeerEndpoint: getEnv("GOV_PEER_ENDPOINT", "peer0.government.uae.com:7051"),
			GatewayPeer:  getEnv("GOV_GATEWAY_PEER", "peer0.government.uae.com"),
			MSPID:        "GovernmentMSP",
		},
		"general": {
			PeerEndpoint: getEnv("GEN_PEER_ENDPOINT", "peer0.general.uae.com:9051"),
			GatewayPeer:  getEnv("GEN_GATEWAY_PEER", "peer0.general.uae.com"),
			MSPID:        "GeneralMSP",
		},
	}
)

// issuerActorID / issuerActorName are the attribution stamped on issued/revoked/
// suspended/restored events and audit logs until real authentication is wired up.
const issuerActorID = "ISS-UOS-0001"
const issuerActorName = "Mohammed Al Issuer"

// mspDir returns the on-disk path to an org's crypto-material directory.
func mspDir(orgLC string) string {
	domainMap := map[string]string{
		"government": "government.uae.com",
		"general":    "general.uae.com",
	}
	domain, ok := domainMap[orgLC]
	if !ok {
		domain = orgLC + ".uae.com"
	}
	return filepath.Join(networkRoot, "crypto-material", "peerOrganizations", domain)
}

// walletDir returns the on-disk path to an org's Fabric wallet directory.
func walletDir(orgLC string) string {
	return filepath.Join(networkRoot, "wallet", orgLC)
}

// mustLoadLocation loads a timezone (e.g. "Asia/Dubai"), falling back to UTC if
// the zone database is unavailable. Used so issuance timestamps are local time.
func mustLoadLocation(tz string) *time.Location {
	loc, err := time.LoadLocation(tz)
	if err != nil {
		return time.UTC
	}
	return loc
}
