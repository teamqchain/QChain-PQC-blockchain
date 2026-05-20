package main

import (
	"bytes"
	"crypto/x509"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
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

// SuspendCredentialRequest — temporary, reversible status change.
type SuspendCredentialRequest struct {
	CredentialID string `json:"credentialID"`
	Reason       string `json:"reason"`
}

// RestoreCredentialRequest — restore a suspended credential back to active.
type RestoreCredentialRequest struct {
	CredentialID string `json:"credentialID"`
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

	// Parse expiryDate out of the inner info JSON so it can be stored as a
	// proper DATE column (used for dashboard "expiringSoon" / expiry warnings).
	var expiryDate sql.NullTime
	var infoFields map[string]any
	if err := json.Unmarshal([]byte(req.Info), &infoFields); err == nil {
		if v, ok := infoFields["expiryDate"].(string); ok && v != "" {
			// Accept both "2030-06-30" and "2030-06-30T00:00:00(.SSS)" forms.
			for _, layout := range []string{time.RFC3339, "2006-01-02T15:04:05.000", "2006-01-02T15:04:05", "2006-01-02"} {
				if t, err := time.Parse(layout, v); err == nil {
					expiryDate = sql.NullTime{Time: t, Valid: true}
					break
				}
			}
		}
	}

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
		ExpiryDate:     expiryDate,
	}); dbErr != nil {
		log.Printf("DB insertCredential warning: %v", dbErr)
	}

	// Record the issuance event for the dashboard activity feed.
	insertCredentialEvent(displayCredID, "issued", "ISS-UOS-0001", "Mohammed Al Issuer", "")

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
	// expiryDate lives inside the nested attributes (set at issue time).
	expiryDate := ""
	if credData != nil {
		if v, ok := credData["expiryDate"].(string); ok {
			expiryDate = v
		}
	}

	// Holder display fields (full name, email, Emirates ID) — for the response,
	// not for the cryptographic check (which is entirely on-chain).
	holderName, holderEmail, holderEID, _ := holderInfoByID(holderIDFromChain)
	if holderName == "" {
		holderName, _ = holderNameByID(holderIDFromChain)
	}
	const verifiedBy = "System Verifier"

	// 4. Check status (active / revoked / suspended)
	status, _ := cred["Status"].(string)
	notRevoked := strings.EqualFold(status, "active")

	if !notRevoked {
		logVerificationToDB(req.CredentialID, fabricCredID, "VER-UOS-0001", verifiedBy,
			"failure", strings.ToUpper(status),
			true, false, false, false, status)
		writeJSON(w, http.StatusOK, map[string]any{
			"verified":       false,
			"credentialID":   req.CredentialID,
			"holderID":       holderIDFromChain,
			"holderName":     holderName,
			"holderEmail":    holderEmail,
			"holderEID":      holderEID,
			"credentialType": credentialType,
			"issuer":         "University of Sharjah",
			"verifiedBy":     verifiedBy,
			"status":         status,
			"issuedAt":       issuedAtFromInfo,
			"expiryDate":     expiryDate,
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

	logVerificationToDB(req.CredentialID, fabricCredID, "VER-UOS-0001", verifiedBy,
		result, failureReason,
		true, hashMatches, sigValid, notRevoked, status)

	writeJSON(w, http.StatusOK, map[string]any{
		"verified":       verified,
		"credentialID":   req.CredentialID,
		"fabricCredID":   fabricCredID,
		"holderID":       holderIDFromChain,
		"holderName":     holderName,
		"holderEmail":    holderEmail,
		"holderEID":      holderEID,
		"credentialType": credentialType,
		"issuer":         "University of Sharjah",
		"verifiedBy":     verifiedBy,
		"status":         status,
		"issuedAt":       issuedAtFromInfo,
		"expiryDate":     expiryDate,
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

	insertCredentialEvent(req.CredentialID, "revoked", "ISS-UOS-0001", "Mohammed Al Issuer", "")

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
// Returns a flat array of credential objects (V3 doc shape). Sources from MySQL,
// not Fabric — this endpoint is for display, verification still hits the chain.
// Also accepts ?holderID=H-0001 for direct lookup (useful for testing).
func handleGetCredentialsByHolder(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	emiratesID := q.Get("emiratesID")
	directHolderID := q.Get("holderID")

	var holderID string
	if emiratesID != "" {
		hid, _, err := holderByEmiratesID(emiratesID)
		if err != nil {
			// V3 doc: invalid/unknown emiratesID returns 200 + empty array.
			writeJSON(w, http.StatusOK, []any{})
			return
		}
		holderID = hid
	} else if directHolderID != "" {
		holderID = directHolderID
	} else {
		writeError(w, http.StatusBadRequest, "missing query param: emiratesID (or holderID)")
		return
	}

	rows, err := listCredentialsByHolder(holderID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "DB query failed: "+err.Error())
		return
	}

	out := make([]map[string]any, 0, len(rows))
	for _, r := range rows {
		out = append(out, credentialRowToJSON(r))
	}
	writeJSON(w, http.StatusOK, out)
}

// ─────────────────────────────────────────────────────────────────────────────
//  V3 EXTENSION — new endpoints (suspend/restore + lists + dashboard)
// ─────────────────────────────────────────────────────────────────────────────

const issuerActorID = "ISS-UOS-0001"
const issuerActorName = "Mohammed Al Issuer"

// credentialRowToJSON shapes a CredentialRow into the V3 credential object.
// Used by /getAllCredentials and /getCredentialsByHolder responses.
func credentialRowToJSON(r CredentialRow) map[string]any {
	var expiry any
	if r.ExpiryDate.Valid {
		expiry = r.ExpiryDate.Time.Format("2006-01-02")
	} else {
		expiry = nil
	}
	issuedISO := r.IssuedAt.Format("2006-01-02T15:04:05")
	return map[string]any{
		"credentialID":   r.CredentialID,
		"credentialType": r.CredentialType,
		"holderName":     r.HolderName,
		"holderEmail":    r.HolderEmail,
		"holderEID":      r.HolderEID,
		"holderID":       r.HolderID,
		"issueDate":      issuedISO,
		"issuedAt":       issuedISO,
		"issuedBy":       firstNonEmpty(r.IssuedBy, issuerActorName),
		"status":         r.Status,
		"expiryDate":     expiry,
		"blockchainTxId": r.FabricCredID,
	}
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}

// ─── SUSPEND ─────────────────────────────────────────────────────────────────

// POST /suspendCredential
func handleSuspendCredential(w http.ResponseWriter, r *http.Request) {
	var req SuspendCredentialRequest
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if req.CredentialID == "" {
		writeError(w, http.StatusBadRequest, "missing credentialID")
		return
	}

	fabricCredID, err := fabricCredIDByDisplay(req.CredentialID)
	if err != nil {
		writeError(w, http.StatusNotFound, "credential not found")
		return
	}

	currentStatus, err := credentialStatusByDisplay(req.CredentialID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not read credential status: "+err.Error())
		return
	}
	switch strings.ToLower(currentStatus) {
	case "suspended":
		writeError(w, http.StatusBadRequest, "credential already suspended")
		return
	case "revoked":
		writeError(w, http.StatusBadRequest, "cannot suspend revoked credential")
		return
	case "expired":
		writeError(w, http.StatusBadRequest, "cannot suspend expired credential")
		return
	}

	contract, gw, conn, err := getContract(issuerOrgName, issuerIdentity)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer gw.Close()
	defer conn.Close()

	if _, err := contract.SubmitTransaction("suspendCredential", fabricCredID, req.Reason); err != nil {
		writeError(w, http.StatusInternalServerError, "chaincode error: "+err.Error())
		return
	}

	if dbErr := markCredentialSuspended(req.CredentialID, req.Reason); dbErr != nil {
		log.Printf("DB markCredentialSuspended warning: %v", dbErr)
	}
	insertCredentialEvent(req.CredentialID, "suspended", issuerActorID, issuerActorName, req.Reason)

	writeJSON(w, http.StatusOK, map[string]any{
		"success":      true,
		"credentialID": req.CredentialID,
	})
}

// ─── RESTORE ─────────────────────────────────────────────────────────────────

// POST /restoreCredential — DEVIATION from V3 doc: only restores from "suspended".
// Revoked credentials are permanent (security policy).
func handleRestoreCredential(w http.ResponseWriter, r *http.Request) {
	var req RestoreCredentialRequest
	if err := decodeBody(r, &req); err != nil || req.CredentialID == "" {
		writeError(w, http.StatusBadRequest, "missing credentialID")
		return
	}

	fabricCredID, err := fabricCredIDByDisplay(req.CredentialID)
	if err != nil {
		writeError(w, http.StatusNotFound, "credential not found")
		return
	}

	currentStatus, err := credentialStatusByDisplay(req.CredentialID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not read credential status: "+err.Error())
		return
	}
	switch strings.ToLower(currentStatus) {
	case "active":
		writeError(w, http.StatusBadRequest, "credential already active")
		return
	case "revoked":
		writeError(w, http.StatusBadRequest, "cannot restore revoked credential")
		return
	case "expired":
		writeError(w, http.StatusBadRequest, "cannot restore expired credential")
		return
	}

	contract, gw, conn, err := getContract(issuerOrgName, issuerIdentity)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer gw.Close()
	defer conn.Close()

	if _, err := contract.SubmitTransaction("restoreCredential", fabricCredID); err != nil {
		writeError(w, http.StatusInternalServerError, "chaincode error: "+err.Error())
		return
	}

	if dbErr := markCredentialRestored(req.CredentialID); dbErr != nil {
		log.Printf("DB markCredentialRestored warning: %v", dbErr)
	}
	insertCredentialEvent(req.CredentialID, "restored", issuerActorID, issuerActorName, "")

	writeJSON(w, http.StatusOK, map[string]any{
		"success":      true,
		"credentialID": req.CredentialID,
	})
}

// ─── LIST ALL CREDENTIALS ────────────────────────────────────────────────────

// GET /getAllCredentials?status=active&page=1&limit=25
func handleGetAllCredentials(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	page := parsePositiveInt(q.Get("page"), 1)
	limitStr := q.Get("limit")
	limit := 25
	if limitStr != "" {
		v, err := strconv.Atoi(limitStr)
		if err == nil {
			if v == 0 {
				writeError(w, http.StatusBadRequest, "limit must be >= 1")
				return
			}
			if v < 0 {
				v = 25
			}
			if v > 100 {
				v = 100
			}
			limit = v
		}
	}

	status := q.Get("status")
	if !validCredentialStatus(status) {
		status = ""
	}

	rows, err := listCredentialsPaginated(status, page, limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "DB query failed: "+err.Error())
		return
	}
	total, _ := countCredentials(status)

	out := make([]map[string]any, 0, len(rows))
	for _, r := range rows {
		out = append(out, credentialRowToJSON(r))
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"credentials": out,
		"total":       total,
		"page":        page,
		"limit":       limit,
	})
}

func validCredentialStatus(s string) bool {
	switch s {
	case "active", "revoked", "suspended", "expired":
		return true
	}
	return false
}

func parsePositiveInt(s string, fallback int) int {
	if s == "" {
		return fallback
	}
	v, err := strconv.Atoi(s)
	if err != nil || v < 1 {
		return fallback
	}
	return v
}

// ─── LIST HOLDERS (searchable) ───────────────────────────────────────────────

// GET /getHolders?search=Ahmed&type=bachelorStudent
func handleGetHolders(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	search := q.Get("search")

	// Map the camelCase API value to the DB ENUM value. Unknown → no filter.
	typeAPI := q.Get("type")
	typeDB := holderTypeAPIToDB(typeAPI)

	rows, err := searchHolders(search, typeDB)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "DB query failed: "+err.Error())
		return
	}

	out := make([]map[string]any, 0, len(rows))
	for _, r := range rows {
		out = append(out, map[string]any{
			"holderID":   r.HolderID,
			"fullName":   r.FullName,
			"email":      r.Email,
			"emiratesID": r.EmiratesID,
			"type":       holderTypeDBToAPI(r.HolderType),
			"college":    r.College,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"holders": out,
		"total":   len(out),
	})
}

func holderTypeAPIToDB(api string) string {
	switch api {
	case "bachelorStudent":
		return "bachelor_student"
	case "masterStudent":
		return "master_student"
	case "phdStudent":
		return "phd_student"
	case "employee":
		return "employee"
	case "medical":
		return "medical"
	}
	return ""
}

func holderTypeDBToAPI(db string) string {
	switch db {
	case "bachelor_student":
		return "bachelorStudent"
	case "master_student":
		return "masterStudent"
	case "phd_student":
		return "phdStudent"
	case "employee":
		return "employee"
	case "medical":
		return "medical"
	}
	return "bachelorStudent" // fallback per V3 doc
}

// ─── VERIFICATION HISTORY ────────────────────────────────────────────────────

// GET /getVerificationHistory?result=valid&page=1&limit=25
func handleGetVerificationHistory(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	page := parsePositiveInt(q.Get("page"), 1)
	limit := parsePositiveInt(q.Get("limit"), 25)
	if limit > 100 {
		limit = 100
	}

	// Translate the API "result" filter to the DB (result, failure_reason) pair.
	resultDB, reasonFilter := verifyResultAPIToDB(q.Get("result"))

	rows, err := listVerificationHistoryPaginated(resultDB, reasonFilter, page, limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "DB query failed: "+err.Error())
		return
	}
	total, _ := countVerificationLogs(resultDB, reasonFilter)

	out := make([]map[string]any, 0, len(rows))
	for _, r := range rows {
		out = append(out, map[string]any{
			"id":             r.LogID,
			"verifiedAt":     r.VerifiedAt.Format("2006-01-02T15:04:05"),
			"credentialType": r.CredentialType,
			"credentialID":   r.CredentialID,
			"holderName":     r.HolderName,
			"issuerName":     r.IssuerName,
			"result":         verifyResultDBToAPI(r.Result, r.FailureReason),
			"method":         verifyMethodDBToAPI(r.Method),
			"verifiedBy":     r.VerifiedBy,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"records": out,
		"total":   total,
		"page":    page,
		"limit":   limit,
	})
}

// verifyResultAPIToDB maps the camelCase API filter to (db_result, db_failure_reason).
// Empty strings mean "no filter on this column".
func verifyResultAPIToDB(api string) (string, string) {
	switch api {
	case "valid":
		return "success", ""
	case "revoked":
		return "failure", "REVOKED"
	case "suspended":
		return "failure", "SUSPENDED"
	case "expired":
		return "failure", "EXPIRED"
	case "tampered":
		return "failure", "signature_invalid"
		// note: hash_mismatch also maps to tampered; we filter on signature_invalid
		// because we can't OR-filter neatly; minor limitation, acceptable for prototype.
	case "notFound":
		return "failure", "NOT_FOUND"
	}
	return "", ""
}

func verifyResultDBToAPI(dbResult, failureReason string) string {
	if dbResult == "success" {
		return "valid"
	}
	switch strings.ToUpper(failureReason) {
	case "REVOKED":
		return "revoked"
	case "SUSPENDED":
		return "suspended"
	case "EXPIRED":
		return "expired"
	case "SIGNATURE_INVALID", "HASH_MISMATCH", "TAMPERED":
		return "tampered"
	case "NOT_FOUND":
		return "notFound"
	}
	return "tampered"
}

func verifyMethodDBToAPI(dbMethod string) string {
	switch dbMethod {
	case "qr_scan", "qrScan", "qr":
		return "qrScan"
	case "file_upload", "fileUpload", "upload":
		return "fileUpload"
	case "batch":
		return "batch"
	}
	return "manual"
}

// ─── DASHBOARD STATS ─────────────────────────────────────────────────────────

// GET /getDashboardStats — returns all fields used by Issuer + Verifier + IT Admin variants.
// Frontend variants pick the keys they need; backend returns everything in one trip.
func handleGetDashboardStats(w http.ResponseWriter, r *http.Request) {
	counters, err := dashboardCounters()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "DB query failed: "+err.Error())
		return
	}

	// Recent activity (issuance + status changes) — formatted via Go.
	events, _ := recentCredentialEvents(5)
	recentActivity := make([]map[string]any, 0, len(events))
	for _, e := range events {
		recentActivity = append(recentActivity, map[string]any{
			"text": eventToText(e),
			"time": formatHumanTime(e.CreatedAt),
			"type": e.EventType,
		})
	}

	// Expiry warnings (active creds within 30 days).
	warns, _ := expiryWarnings()
	expiryOut := make([]map[string]any, 0, len(warns))
	for _, w := range warns {
		expiryOut = append(expiryOut, map[string]any{
			"name":       w.Name,
			"credential": w.Credential,
			"daysLeft":   w.DaysLeft,
		})
	}

	// Weekly issued (always 4 entries, oldest → newest, labelled "Wk 1"–"Wk 4").
	weeklyRaw, _ := weeklyIssued()
	weekly := buildWeeklyChart(weeklyRaw)

	// Daily verified (always 7 entries, Mon → Sun).
	dailyMap, _ := dailyVerified()
	daily := buildDailyChart(dailyMap)

	// Recent verifications (verifier dashboard).
	recentVerifs, _ := recentVerifications(5)
	recentVerifJSON := make([]map[string]any, 0, len(recentVerifs))
	for _, v := range recentVerifs {
		recentVerifJSON = append(recentVerifJSON, map[string]any{
			"credential": v.Credential,
			"holderName": v.HolderName,
			"status":     v.Status,
			"time":       formatHumanTime(v.VerifiedAt),
		})
	}

	// Status alerts (verifier dashboard).
	alerts, _ := statusAlerts(10)
	alertsJSON := make([]map[string]any, 0, len(alerts))
	for _, a := range alerts {
		alertsJSON = append(alertsJSON, map[string]any{
			"name":       a.Name,
			"credential": a.Credential,
			"event":      a.Event,
			"time":       formatHumanTime(a.Time),
		})
	}

	issuerCount, verifierCount, _ := staffCounts()

	writeJSON(w, http.StatusOK, map[string]any{
		"totalIssued":         counters.TotalIssued,
		"totalVerified":       counters.TotalVerified,
		"totalRevoked":        counters.TotalRevoked,
		"totalSuspended":      counters.TotalSuspended,
		"totalExpired":        counters.TotalExpired,
		"issuedToday":         counters.IssuedToday,
		"verifiedToday":       counters.VerifiedToday,
		"alertsUnread":        counters.AlertsUnread,
		"expiringSoon":        counters.ExpiringSoon,
		"recentActivity":      recentActivity,
		"expiryWarnings":      expiryOut,
		"weeklyIssued":        weekly,
		"recentVerifications": recentVerifJSON,
		"statusAlerts":        alertsJSON,
		"dailyVerified":       daily,
		"issuerStaffCount":    issuerCount,
		"verifierStaffCount":  verifierCount,
	})
}

func eventToText(e EventRow) string {
	subject := e.CredentialType
	if subject == "" {
		subject = "Credential"
	}
	switch e.EventType {
	case "issued":
		return fmt.Sprintf("%s issued to %s", subject, e.HolderName)
	case "revoked":
		return fmt.Sprintf("%s revoked — %s", subject, e.HolderName)
	case "suspended":
		return fmt.Sprintf("%s suspended — %s", subject, e.HolderName)
	case "restored":
		return fmt.Sprintf("%s restored — %s", subject, e.HolderName)
	}
	return fmt.Sprintf("%s %s — %s", subject, e.EventType, e.HolderName)
}

// buildWeeklyChart converts raw YEARWEEK rows into the doc's 4-entry "Wk 1"..."Wk 4"
// shape. Oldest week becomes "Wk 1". If fewer than 4 weeks have data, missing entries
// are padded with value=0 at the START (so the newest week stays as "Wk 4").
func buildWeeklyChart(raw []ChartPoint) []map[string]any {
	// Order raw oldest → newest (already ordered by SQL).
	values := make([]int, 4)
	// Take last up-to-4 entries.
	start := len(raw) - 4
	if start < 0 {
		start = 0
	}
	rawWindow := raw[start:]
	// Right-align into the 4-slot array so the newest week is in slot 3.
	offset := 4 - len(rawWindow)
	for i, p := range rawWindow {
		values[offset+i] = p.Value
	}
	out := make([]map[string]any, 4)
	for i := 0; i < 4; i++ {
		out[i] = map[string]any{
			"label": fmt.Sprintf("Wk %d", i+1),
			"value": values[i],
		}
	}
	return out
}

// buildDailyChart returns exactly 7 entries Mon→Sun, padding missing days with value=0.
func buildDailyChart(counts map[string]int) []map[string]any {
	order := []string{"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"}
	out := make([]map[string]any, 0, 7)
	for _, day := range order {
		out = append(out, map[string]any{
			"label": day,
			"value": counts[day],
		})
	}
	return out
}

// ─────────────────────────────────────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────────────────────────────────────

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
	mux.HandleFunc("POST /suspendCredential", handleSuspendCredential)
	mux.HandleFunc("POST /restoreCredential", handleRestoreCredential)
	mux.HandleFunc("POST /setCID", handleSetCID)
	mux.HandleFunc("GET /getCredentialsByHolder", handleGetCredentialsByHolder)
	mux.HandleFunc("GET /getAllCredentials", handleGetAllCredentials)
	mux.HandleFunc("GET /getHolders", handleGetHolders)
	mux.HandleFunc("GET /getVerificationHistory", handleGetVerificationHistory)
	mux.HandleFunc("GET /getDashboardStats", handleGetDashboardStats)
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
