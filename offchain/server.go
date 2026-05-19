package main

import (
	"bytes"
	"crypto/x509"
	"encoding/hex"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/hyperledger/fabric-gateway/pkg/client"
	"github.com/hyperledger/fabric-gateway/pkg/identity"
	shell "github.com/ipfs/go-ipfs-api"
	"github.com/open-quantum-safe/liboqs-go/oqs"
	"golang.org/x/crypto/sha3"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
)

// ─────────────────────────────────────────────
//  CONFIGURATION (override via environment vars)
// ─────────────────────────────────────────────

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
	issuerPrivKeyHex string
	issuerPubKeyHex  string
	issuerOrgID      string

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

func walletDir(orgLC string) string {
	return filepath.Join(networkRoot, "wallet", orgLC)
}

// ─────────────────────────────────────────────
//  REQUEST / RESPONSE TYPES
// ─────────────────────────────────────────────

// RegisterHolderRequest — setup script only; not called from any frontend.
type RegisterHolderRequest struct {
	HolderID   string `json:"holderID"`   // e.g. "H-0001"; server generates if empty
	EmiratesID string `json:"emiratesID"` // stored in MySQL holders table
	FirstName  string `json:"firstName"`
	LastName   string `json:"lastName"`
}

// IssueCredentialRequest — called by QPortal issuer screen (Step 5 button).
type IssueCredentialRequest struct {
	HolderEmiratesID string `json:"holderEmiratesID"` // lookup key into MySQL holders table
	CredentialType   string `json:"credentialType"`   // human-readable type, e.g. "BSc Computer Science"
	Info             string `json:"info"`             // JSON-encoded credential attributes string
}

// VerifyCredentialRequest — called by QPortal verifier screen.
type VerifyCredentialRequest struct {
	CredentialID string `json:"credentialID"` // display ID e.g. "CRED-0001"
}

// RevokeCredentialRequest — called by QPortal issuer revoke/suspend screen.
type RevokeCredentialRequest struct {
	CredentialID string `json:"credentialID"` // display ID e.g. "CRED-0001"
}

// SetCIDRequest — admin use only (left intact for manual correction).
type SetCIDRequest struct {
	CredID string `json:"credID"` // full fabric cred ID
	CID    string `json:"cid"`
}

type ErrorResponse struct {
	Error string `json:"error"`
}

// ─────────────────────────────────────────────
//  WALLET .id FILE PARSING
// ─────────────────────────────────────────────

type walletIDFile struct {
	Credentials struct {
		Certificate string `json:"certificate"`
		PrivateKey  string `json:"privateKey"`
	} `json:"credentials"`
	MspID   string `json:"mspId"`
	Type    string `json:"type"`
	Version int    `json:"version"`
}

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

// ─────────────────────────────────────────────
//  FABRIC GATEWAY HELPERS
// ─────────────────────────────────────────────

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

// ─────────────────────────────────────────────
//  PQC HELPERS  (ML-DSA-44 via liboqs-go)
// ─────────────────────────────────────────────

const sigName = "ML-DSA-44"

// pqcSign signs message with the provided hex-encoded private key.
// Returns hex-encoded signature.
func pqcSign(message, privateKeyHex string) (string, error) {
	privKeyBytes, err := hex.DecodeString(privateKeyHex)
	if err != nil {
		return "", fmt.Errorf("decoding private key hex: %w", err)
	}
	signer := oqs.Signature{}
	defer signer.Clean()
	if err := signer.Init(sigName, privKeyBytes); err != nil {
		return "", fmt.Errorf("init PQC signer with key: %w", err)
	}
	sig, err := signer.Sign([]byte(message))
	if err != nil {
		return "", fmt.Errorf("signing: %w", err)
	}
	return hex.EncodeToString(sig), nil
}

// pqcVerify verifies a hex-encoded signature against a message and hex-encoded public key.
func pqcVerify(message, signatureHex, publicKeyHex string) (bool, error) {
	pubKeyBytes, err := hex.DecodeString(publicKeyHex)
	if err != nil {
		return false, fmt.Errorf("decoding public key hex: %w", err)
	}
	sigBytes, err := hex.DecodeString(signatureHex)
	if err != nil {
		return false, fmt.Errorf("decoding signature hex: %w", err)
	}
	verifier := oqs.Signature{}
	defer verifier.Clean()
	if err := verifier.Init(sigName, nil); err != nil {
		return false, fmt.Errorf("init PQC verifier: %w", err)
	}
	valid, err := verifier.Verify([]byte(message), sigBytes, pubKeyBytes)
	if err != nil {
		return false, fmt.Errorf("verify: %w", err)
	}
	return valid, nil
}

// ─────────────────────────────────────────────
//  CRYPTO HELPERS
// ─────────────────────────────────────────────

// sha3Hex returns the SHA3-256 hex digest of data.
func sha3Hex(data string) string {
	digest := sha3.Sum256([]byte(data))
	return hex.EncodeToString(digest[:])
}

// credentialCanonicalJSON builds a deterministic JSON string from the credential
// payload fields. Go marshals map[string]string keys in sorted order, giving
// canonical output.
func credentialCanonicalJSON(holderID, credentialType, info, issuedAt, issuerOrgIDVal string) (string, error) {
	payload := map[string]string{
		"credentialType": credentialType,
		"holderID":       holderID,
		"info":           info,
		"issuedAt":       issuedAt,
		"issuerOrgID":    issuerOrgIDVal,
	}
	b, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}
	return string(b), nil
}

// ─────────────────────────────────────────────
//  IPFS HELPER
// ─────────────────────────────────────────────

// uploadJSONToIPFS uploads raw JSON bytes to IPFS and returns the CID.
// Returns ("", nil) if IPFS upload is skipped (host not reachable) so that
// issuance can still proceed.
func uploadJSONToIPFS(jsonBytes []byte) (string, error) {
	sh := shell.NewShell(ipfsHost)
	cid, err := sh.Add(bytes.NewReader(jsonBytes))
	if err != nil {
		return "", fmt.Errorf("IPFS upload: %w", err)
	}
	return cid, nil
}

// ─────────────────────────────────────────────
//  HTTP HELPERS
// ─────────────────────────────────────────────

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, ErrorResponse{Error: msg})
}

func decodeBody(r *http.Request, v any) error {
	return json.NewDecoder(r.Body).Decode(v)
}

// corsMiddleware sets CORS headers so Flutter Web can reach the API.
func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// ─────────────────────────────────────────────
//  ROUTE HANDLERS
// ─────────────────────────────────────────────

// POST /registerHolder — used by setup script only; not called from any frontend.
func handleRegisterHolder(w http.ResponseWriter, r *http.Request) {
	var req RegisterHolderRequest
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if req.FirstName == "" || req.LastName == "" {
		writeError(w, http.StatusBadRequest, "missing required fields: firstName, lastName")
		return
	}

	holderID := req.HolderID
	if holderID == "" {
		// Auto-generate next ID from DB counter if not provided
		var err error
		holderID, err = nextHolderID()
		if err != nil {
			writeError(w, http.StatusInternalServerError, "could not generate holder ID: "+err.Error())
			return
		}
	}

	// Register on Fabric
	contract, gw, conn, err := getContract(issuerOrgName, issuerIdentity)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer gw.Close()
	defer conn.Close()

	result, err := contract.SubmitTransaction("registerHolder", holderID, req.FirstName, req.LastName)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "chaincode registerHolder failed: "+err.Error())
		return
	}

	// Persist to MySQL (optional — logs warning if DB not configured)
	if req.EmiratesID != "" {
		if dbErr := insertHolder(holderID, req.EmiratesID, req.FirstName, req.LastName); dbErr != nil {
			log.Printf("DB insertHolder warning: %v", dbErr)
		}
	}

	var parsed any
	_ = json.Unmarshal(result, &parsed)
	writeJSON(w, http.StatusOK, map[string]any{
		"holderID": holderID,
		"result":   parsed,
	})
}

// POST /issueCredential — called by QPortal issuer screen.
func handleIssueCredential(w http.ResponseWriter, r *http.Request) {
	var req IssueCredentialRequest
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if req.HolderEmiratesID == "" || req.CredentialType == "" || req.Info == "" {
		writeError(w, http.StatusBadRequest, "missing required fields: holderEmiratesID, credentialType, info")
		return
	}

	// 1. Look up holder in MySQL
	holderID, fabricHolderID, err := holderByEmiratesID(req.HolderEmiratesID)
	if err != nil {
		writeError(w, http.StatusNotFound, "holder not found — Emirates ID not registered: "+err.Error())
		return
	}

	// 2. Build signed canonical JSON
	issuedAt := time.Now().In(mustLoadLocation("Asia/Dubai")).Format("2006-01-02T15:04:05")
	canonicalJSONStr, err := credentialCanonicalJSON(fabricHolderID, req.CredentialType, req.Info, issuedAt, issuerOrgID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "canonical JSON build failed: "+err.Error())
		return
	}

	// 3. SHA3-256 hash of the canonical JSON
	credentialHash := sha3Hex(canonicalJSONStr)

	// 4. Sign the hash with the org-level private key (never generated per-credential)
	signature, err := pqcSign(credentialHash, issuerPrivKeyHex)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "PQC sign failed: "+err.Error())
		return
	}

	// 5. Upload JSON to IPFS (non-fatal if IPFS unavailable)
	var ipfsCID string
	if cid, uploadErr := uploadJSONToIPFS([]byte(canonicalJSONStr)); uploadErr != nil {
		log.Printf("IPFS upload failed (proceeding without CID): %v", uploadErr)
	} else {
		ipfsCID = cid
	}

	// 6. Connect to Fabric and issue credential in a single transaction
	contract, gw, conn, err := getContract(issuerOrgName, issuerIdentity)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer gw.Close()
	defer conn.Close()

	result, err := contract.SubmitTransaction(
		"issueCredential",
		fabricHolderID,
		canonicalJSONStr,
		credentialHash,
		signature,
		issuerPubKeyHex,
		ipfsCID,
	)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "chaincode issueCredential failed: "+err.Error())
		return
	}

	// 7. Extract fabric cred ID from chaincode response
	var chainResp map[string]any
	_ = json.Unmarshal(result, &chainResp)
	fabricCredID := ""
	if cred, ok := chainResp["credential"].(map[string]any); ok {
		fabricCredID, _ = cred["ID"].(string)
	}

	// 8. Generate display credential ID and persist to MySQL
	displayCredID := nextDisplayCredID()
	if dbErr := insertCredential(CredentialInsert{
		CredentialID:   displayCredID,
		FabricCredID:   fabricCredID,
		HolderID:       holderID,
		CredentialType: req.CredentialType,
		CredentialHash: credentialHash,
		Signature:      signature,
		PublicKey:      issuerPubKeyHex,
		IPFSCID:        ipfsCID,
		CredentialData: req.Info,
		IssuedAt:       time.Now(),
	}); dbErr != nil {
		log.Printf("DB insertCredential warning: %v", dbErr)
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"success":        true,
		"credentialID":   displayCredID,
		"fabricCredID":   fabricCredID,
		"holderID":       holderID,
		"credentialHash": credentialHash,
		"ipfsCID":        ipfsCID,
		"issuedAt":       issuedAt,
	})
}

// POST /verifyCredential — called by QPortal verifier screen.
func handleVerifyCredential(w http.ResponseWriter, r *http.Request) {
	var req VerifyCredentialRequest
	if err := decodeBody(r, &req); err != nil || req.CredentialID == "" {
		writeError(w, http.StatusBadRequest, "missing credentialID")
		return
	}

	// 1. Look up fabric cred ID from MySQL
	fabricCredID, err := fabricCredIDByDisplay(req.CredentialID)
	if err != nil {
		writeError(w, http.StatusNotFound, "credential not found: "+err.Error())
		return
	}

	// 2. Fetch full credential from Fabric
	contract, gw, conn, err := getContract(verifierOrgName, verifierIdentity)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer gw.Close()
	defer conn.Close()

	chainResult, err := contract.EvaluateTransaction("getCredential", fabricCredID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "chaincode lookup failed: "+err.Error())
		return
	}
	var cred map[string]any
	if err := json.Unmarshal(chainResult, &cred); err != nil {
		writeError(w, http.StatusInternalServerError, "invalid chaincode response")
		return
	}

	// 3. Parse Info JSON upfront — needed by both the early-return and success paths.
	credInfoStr, _ := cred["Info"].(string)
	var infoPayload map[string]string
	_ = json.Unmarshal([]byte(credInfoStr), &infoPayload)
	holderIDFromChain := infoPayload["holderID"]
	credentialType := infoPayload["credentialType"]
	issuedAtFromInfo := infoPayload["issuedAt"]
	innerInfoStr := infoPayload["info"]

	// Parse nested credential attributes for display.
	var credData map[string]any
	if innerInfoStr != "" {
		_ = json.Unmarshal([]byte(innerInfoStr), &credData)
	}
	holderName, _ := holderNameByID(holderIDFromChain)

	// 4. Check status (active / revoked / suspended)
	status, _ := cred["Status"].(string)
	notRevoked := strings.EqualFold(status, "active")

	if !notRevoked {
		logVerificationToDB(req.CredentialID, fabricCredID, verifierIdentity,
			"failure", strings.ToUpper(status),
			true, false, false, false, status)
		writeJSON(w, http.StatusOK, map[string]any{
			"verified":       false,
			"credentialID":   req.CredentialID,
			"holderID":       holderIDFromChain,
			"holderName":     holderName,
			"credentialType": credentialType,
			"issuer":         "University of Sharjah",
			"status":         status,
			"issuedAt":       issuedAtFromInfo,
			"credentialData": credData,
			"reason":         strings.ToUpper(status),
			"checks": map[string]bool{
				"existsOnChain":  true,
				"notRevoked":     false,
				"signatureValid": false,
				"hashMatches":    false,
			},
		})
		return
	}

	// 5. Extract cryptographic fields from on-chain credential
	credHash, _ := cred["CredentialHash"].(string)
	signature, _ := cred["Signature"].(string)
	publicKey, _ := cred["PublicKey"].(string)

	// 6. PQC signature verification
	sigValid, sigErr := pqcVerify(credHash, signature, publicKey)
	if sigErr != nil {
		writeError(w, http.StatusInternalServerError, "PQC verify error: "+sigErr.Error())
		return
	}

	// 7. Tamper detection: recompute SHA3-256 of stored Info and compare to stored hash
	recomputed := sha3Hex(credInfoStr)
	hashMatches := strings.EqualFold(recomputed, credHash)

	verified := notRevoked && sigValid && hashMatches

	result := "success"
	failureReason := ""
	if !verified {
		result = "failure"
		if !sigValid {
			failureReason = "signature_invalid"
		} else if !hashMatches {
			failureReason = "hash_mismatch"
		}
	}

	logVerificationToDB(req.CredentialID, fabricCredID, verifierIdentity,
		result, failureReason,
		true, hashMatches, sigValid, notRevoked, status)

	writeJSON(w, http.StatusOK, map[string]any{
		"verified":       verified,
		"credentialID":   req.CredentialID,
		"fabricCredID":   fabricCredID,
		"holderID":       holderIDFromChain,
		"holderName":     holderName,
		"credentialType": credentialType,
		"issuer":         "University of Sharjah",
		"status":         status,
		"issuedAt":       issuedAtFromInfo,
		"credentialData": credData,
		"checks": map[string]bool{
			"existsOnChain":  true,
			"notRevoked":     notRevoked,
			"signatureValid": sigValid,
			"hashMatches":    hashMatches,
		},
	})
}

// POST /revokeCredential — called by QPortal issuer revoke screen.
func handleRevokeCredential(w http.ResponseWriter, r *http.Request) {
	var req RevokeCredentialRequest
	if err := decodeBody(r, &req); err != nil || req.CredentialID == "" {
		writeError(w, http.StatusBadRequest, "missing credentialID")
		return
	}

	fabricCredID, err := fabricCredIDByDisplay(req.CredentialID)
	if err != nil {
		writeError(w, http.StatusNotFound, "credential not found: "+err.Error())
		return
	}

	contract, gw, conn, err := getContract(issuerOrgName, issuerIdentity)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer gw.Close()
	defer conn.Close()

	result, err := contract.SubmitTransaction("revokeCredential", fabricCredID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "chaincode revokeCredential failed: "+err.Error())
		return
	}

	if dbErr := markCredentialRevoked(req.CredentialID); dbErr != nil {
		log.Printf("DB markCredentialRevoked warning: %v", dbErr)
	}

	var parsed any
	_ = json.Unmarshal(result, &parsed)
	writeJSON(w, http.StatusOK, map[string]any{
		"success":      true,
		"credentialID": req.CredentialID,
		"result":       parsed,
	})
}

// POST /setCID — admin use only (manual correction if IPFS upload was skipped during issuance).
func handleSetCID(w http.ResponseWriter, r *http.Request) {
	var req SetCIDRequest
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if req.CredID == "" || req.CID == "" {
		writeError(w, http.StatusBadRequest, "missing required fields: credID, cid")
		return
	}

	contract, gw, conn, err := getContract(issuerOrgName, issuerIdentity)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer gw.Close()
	defer conn.Close()

	result, err := contract.SubmitTransaction("setCID", req.CredID, req.CID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	var parsed any
	_ = json.Unmarshal(result, &parsed)
	writeJSON(w, http.StatusOK, parsed)
}

// GET /getCredentialsByHolder?emiratesID=784-...
// Also accepts ?holderID=H-0001 for direct fabric lookup (useful for testing without MySQL).
func handleGetCredentialsByHolder(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	emiratesID := q.Get("emiratesID")
	directHolderID := q.Get("holderID") // testing shortcut

	var fabricHolderID string

	if emiratesID != "" {
		_, fhID, err := holderByEmiratesID(emiratesID)
		if err != nil {
			writeError(w, http.StatusNotFound, "holder not found: "+err.Error())
			return
		}
		fabricHolderID = fhID
	} else if directHolderID != "" {
		fabricHolderID = directHolderID
	} else {
		writeError(w, http.StatusBadRequest, "missing query param: emiratesID (or holderID for testing)")
		return
	}

	contract, gw, conn, err := getContract(issuerOrgName, issuerIdentity)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer gw.Close()
	defer conn.Close()

	result, err := contract.EvaluateTransaction("getCredentialsByHolder", fabricHolderID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	var parsed any
	_ = json.Unmarshal(result, &parsed)
	writeJSON(w, http.StatusOK, parsed)
}

// ─────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────

func mustLoadLocation(tz string) *time.Location {
	loc, err := time.LoadLocation(tz)
	if err != nil {
		return time.UTC
	}
	return loc
}

// ─────────────────────────────────────────────
//  MAIN — router + server
// ─────────────────────────────────────────────

func main() {
	// Load org-level ML-DSA-44 key pair — must be set in .env; fatal if missing.
	issuerPrivKeyHex = os.Getenv("ISSUER_PRIVATE_KEY_HEX")
	issuerPubKeyHex = os.Getenv("ISSUER_PUBLIC_KEY_HEX")
	issuerOrgID = getEnv("ISSUER_ORG_ID", "GeneralMSP")

	if issuerPrivKeyHex == "" || issuerPubKeyHex == "" {
		log.Fatal("ISSUER_PRIVATE_KEY_HEX and ISSUER_PUBLIC_KEY_HEX must be set — run offchain/cmd/keygen/main.go once to generate them")
	}

	// Connect to MySQL (non-fatal if not configured — warnings logged per request)
	initDB()

	mux := http.NewServeMux()
	mux.HandleFunc("POST /registerHolder", handleRegisterHolder)
	mux.HandleFunc("POST /issueCredential", handleIssueCredential)
	mux.HandleFunc("POST /verifyCredential", handleVerifyCredential)
	mux.HandleFunc("POST /revokeCredential", handleRevokeCredential)
	mux.HandleFunc("POST /setCID", handleSetCID)
	mux.HandleFunc("GET /getCredentialsByHolder", handleGetCredentialsByHolder)
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	addr := ":" + serverPort
	fmt.Printf("QChain Go backend running on %s\n", addr)
	fmt.Printf("  Network root:  %s\n", networkRoot)
	fmt.Printf("  Channel:       %s\n", channelName)
	fmt.Printf("  Chaincode:     %s\n", chaincodeName)
	fmt.Printf("  IPFS host:     %s\n", ipfsHost)
	fmt.Printf("  PQC algo:      %s\n", sigName)
	fmt.Printf("  Issuer org:    %s / %s\n", issuerOrgName, issuerIdentity)
	fmt.Printf("  Verifier org:  %s / %s\n", verifierOrgName, verifierIdentity)
	fmt.Printf("  Issuer org ID: %s\n", issuerOrgID)

	log.Fatal(http.ListenAndServe(addr, corsMiddleware(mux)))
}
