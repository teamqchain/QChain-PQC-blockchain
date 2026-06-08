package main

import (
	"bytes"
	"crypto/rand"
	"crypto/x509"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"log"
	"math/big"
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
	insertAuditLog("issued", fmt.Sprintf("Credential %s issued to holder %s", displayCredID, holderID),
		"Mohammed Al Issuer", "Issuer Admin", r.RemoteAddr)

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
	insertAuditLog("revoked", fmt.Sprintf("Credential %s revoked", req.CredentialID),
		"Mohammed Al Issuer", "Issuer Admin", r.RemoteAddr)

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
	insertAuditLog("suspended", fmt.Sprintf("Credential %s suspended. Reason: %s", req.CredentialID, req.Reason),
		issuerActorName, "Issuer Admin", r.RemoteAddr)

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
	insertAuditLog("restored", fmt.Sprintf("Credential %s restored to active", req.CredentialID),
		issuerActorName, "Issuer Admin", r.RemoteAddr)

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

	// Daily issued (always 7 entries, Mon → Sun — replaces weeklyIssued).
	dailyIssuedMap, _ := dailyIssued()
	dailyIssuedChart := buildDailyChart(dailyIssuedMap)

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
	statusAlertRows, _ := statusAlerts(10)
	alertsJSON := make([]map[string]any, 0, len(statusAlertRows))
	for _, a := range statusAlertRows {
		alertsJSON = append(alertsJSON, map[string]any{
			"name":       a.Name,
			"credential": a.Credential,
			"event":      a.Event,
			"time":       formatHumanTime(a.Time),
		})
	}

	// IT Admin fields.
	issuerCount, verifierCount, _ := staffCounts()
	adminTotal, adminActive, adminInvited, _ := staffTotals()
	issuerRoles, _ := staffRoleBreakdown("issuer")
	verifierRoles, _ := staffRoleBreakdown("verifier")
	recentAudit, _ := recentAuditLogs(10)

	issuerRolesJSON := make([]map[string]any, 0, len(issuerRoles))
	for _, rc := range issuerRoles {
		issuerRolesJSON = append(issuerRolesJSON, map[string]any{"label": rc.Label, "count": rc.Count})
	}
	verifierRolesJSON := make([]map[string]any, 0, len(verifierRoles))
	for _, rc := range verifierRoles {
		verifierRolesJSON = append(verifierRolesJSON, map[string]any{"label": rc.Label, "count": rc.Count})
	}
	recentAuditJSON := make([]map[string]any, 0, len(recentAudit))
	for _, a := range recentAudit {
		recentAuditJSON = append(recentAuditJSON, map[string]any{
			"action":      a.Action,
			"details":     a.Details,
			"role":        a.Role,
			"performedBy": a.PerformedBy,
			"timestamp":   FormatISO(a.Timestamp),
		})
	}

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
		"dailyIssued":         dailyIssuedChart,
		"recentVerifications": recentVerifJSON,
		"statusAlerts":        alertsJSON,
		"dailyVerified":       daily,
		"issuerStaffCount":    issuerCount,
		"verifierStaffCount":  verifierCount,
		"adminTotalStaff":     adminTotal,
		"adminActiveStaff":    adminActive,
		"adminInvitedStaff":   adminInvited,
		"issuerRoles":         issuerRolesJSON,
		"verifierRoles":       verifierRolesJSON,
		"recentAudit":         recentAuditJSON,
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
//  PHASE C — QPORTAL PHASE 2 HANDLERS
// ─────────────────────────────────────────────────────────────────────────────

// GET /getCredentialDetail?credentialID=CRED-0001
func handleGetCredentialDetail(w http.ResponseWriter, r *http.Request) {
	credentialID := r.URL.Query().Get("credentialID")
	if credentialID == "" {
		writeError(w, http.StatusBadRequest, "missing credentialID")
		return
	}
	cred, err := getCredentialDetail(credentialID)
	if err == sql.ErrNoRows {
		writeError(w, http.StatusNotFound, "credential not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}

	trail, err := getCredentialAuditTrail(credentialID)
	if err != nil {
		log.Printf("getCredentialAuditTrail warning: %v", err)
	}
	trailJSON := make([]map[string]any, 0, len(trail))
	for _, t := range trail {
		var note any
		if t.Notes.Valid {
			note = t.Notes.String
		}
		trailJSON = append(trailJSON, map[string]any{
			"action":      t.Action,
			"performedBy": t.PerformedBy,
			"date":        FormatDateDisplay(t.OccurredAt),
			"note":        note,
		})
	}

	var expiry any
	if cred.ExpiryDate.Valid {
		expiry = FormatDateISO(cred.ExpiryDate.Time)
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"credentialID":   cred.CredentialID,
		"credentialType": cred.CredentialType,
		"holderName":     cred.HolderName,
		"holderEmail":    cred.HolderEmail,
		"holderEID":      cred.HolderEID,
		"holderID":       cred.HolderID,
		"issuedAt":       FormatISO(cred.IssuedAt),
		"issuedBy":       firstNonEmpty(cred.IssuedBy, issuerActorName),
		"status":         cred.Status,
		"expiryDate":     expiry,
		"auditTrail":     trailJSON,
	})
}

// POST /updateCredential
func handleUpdateCredential(w http.ResponseWriter, r *http.Request) {
	var req struct {
		CredentialID string  `json:"credentialID"`
		HolderEmail  *string `json:"holderEmail"`
		ExpiryDate   *string `json:"expiryDate"`
	}
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	if req.CredentialID == "" {
		writeError(w, http.StatusBadRequest, "missing credentialID")
		return
	}
	cred, err := getCredentialDetail(req.CredentialID)
	if err == sql.ErrNoRows {
		writeError(w, http.StatusNotFound, "credential not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	if cred.Status == "revoked" {
		writeError(w, http.StatusBadRequest, "cannot update a revoked credential")
		return
	}
	if req.HolderEmail != nil {
		if err := updateHolderEmail(req.CredentialID, *req.HolderEmail); err != nil {
			writeError(w, http.StatusInternalServerError, "database error")
			return
		}
	}
	if req.ExpiryDate != nil {
		if *req.ExpiryDate == "" {
			if err := updateCredentialExpiry(req.CredentialID, nil); err != nil {
				writeError(w, http.StatusInternalServerError, "database error")
				return
			}
		} else {
			t, err := time.Parse("2006-01-02", *req.ExpiryDate)
			if err != nil {
				writeError(w, http.StatusBadRequest, "invalid expiryDate format")
				return
			}
			if err := updateCredentialExpiry(req.CredentialID, &t); err != nil {
				writeError(w, http.StatusInternalServerError, "database error")
				return
			}
		}
	}
	writeJSON(w, http.StatusOK, map[string]any{"success": true, "credentialID": req.CredentialID})
}

// GET /getVerificationDetail?id=VL-...
func handleGetVerificationDetail(w http.ResponseWriter, r *http.Request) {
	logID := r.URL.Query().Get("id")
	if logID == "" {
		writeError(w, http.StatusBadRequest, "missing id")
		return
	}
	vd, err := getVerificationDetail(logID)
	if err == sql.ErrNoRows {
		writeError(w, http.StatusNotFound, "verification record not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}

	mappedResult := verifyResultDBToAPI(vd.Result, vd.FailureReason.String)
	existsOnChain := nullBoolOrDerive(vd.ChainVerified, mappedResult != "notFound")
	notRevoked := nullBoolOrDerive(vd.HashVerified, mappedResult == "valid" || mappedResult == "expired")
	sigValid := nullBoolOrDerive(vd.SigVerified, mappedResult != "tampered")
	hashMatches := nullBoolOrDerive(vd.HashVerified, mappedResult != "tampered")

	var expiry any
	if vd.ExpiryDate.Valid {
		expiry = FormatDateISO(vd.ExpiryDate.Time)
	}
	var issuedAt any
	if vd.IssuedAt.Valid {
		issuedAt = FormatISO(vd.IssuedAt.Time)
	}
	var reason any
	if vd.FailureReason.Valid && vd.FailureReason.String != "" {
		reason = vd.FailureReason.String
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"id":             vd.LogID,
		"verifiedAt":     FormatISO(vd.VerifiedAt),
		"credentialID":   vd.CredentialID,
		"credentialType": vd.CredentialType,
		"holderName":     vd.HolderName,
		"holderID":       vd.HolderID,
		"issuerName":     vd.IssuerName,
		"issuedAt":       issuedAt,
		"expiryDate":     expiry,
		"result":         mappedResult,
		"reason":         reason,
		"method":         verifyMethodDBToAPI(vd.Method),
		"verifiedBy":     vd.VerifiedBy,
		"checks": map[string]bool{
			"existsOnChain":  existsOnChain,
			"notRevoked":     notRevoked,
			"signatureValid": sigValid,
			"hashMatches":    hashMatches,
		},
	})
}

func nullBoolOrDerive(nb sql.NullBool, derived bool) bool {
	if nb.Valid {
		return nb.Bool
	}
	return derived
}

// POST /resolveSession — called by ScanToValidatePage (QR) and ManualVerifyPage (OTP).
// Frontend prepends "OTP-" to the 6-digit code before sending.
func handleResolveSession(w http.ResponseWriter, r *http.Request) {
	var req struct {
		SessionToken string `json:"sessionToken"`
	}
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	if req.SessionToken == "" {
		writeError(w, http.StatusBadRequest, "missing sessionToken")
		return
	}

	session, err := getMobileSession(req.SessionToken)
	if err == sql.ErrNoRows {
		writeError(w, http.StatusNotFound, "Session not found or invalid QR code.")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	if time.Now().After(session.ExpiresAt) {
		writeError(w, http.StatusBadRequest, "Session expired. Please generate a new QR code.")
		return
	}

	fabricCredID, err := fabricCredIDByDisplay(session.CredentialID)
	if err != nil {
		writeError(w, http.StatusNotFound, "credential not found")
		return
	}

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

	credInfoStr, _ := cred["Info"].(string)
	var infoPayload map[string]string
	_ = json.Unmarshal([]byte(credInfoStr), &infoPayload)
	holderIDFromChain := infoPayload["holderID"]
	credentialType := infoPayload["credentialType"]
	issuedAtFromInfo := infoPayload["issuedAt"]
	innerInfoStr := infoPayload["info"]

	var credData map[string]any
	if innerInfoStr != "" {
		_ = json.Unmarshal([]byte(innerInfoStr), &credData)
	}
	expiryDate := ""
	if credData != nil {
		if v, ok := credData["expiryDate"].(string); ok {
			expiryDate = v
		}
	}

	applySelectiveDisclosure(credData, session.HiddenFields)
	hiddenSet := make(map[string]bool, len(session.HiddenFields))
	for _, f := range session.HiddenFields {
		hiddenSet[f] = true
	}
	holderName, holderEmail, holderEID, _ := holderInfoByID(holderIDFromChain)
	if holderName == "" {
		holderName, _ = holderNameByID(holderIDFromChain)
	}
	if hiddenSet["holderName"] {
		holderName = ""
	}
	if hiddenSet["issuedAt"] {
		issuedAtFromInfo = ""
	}
	if hiddenSet["expiryDate"] {
		expiryDate = ""
	}

	const resolveVerifiedBy = "System Verifier"
	status, _ := cred["Status"].(string)
	notRevoked := strings.EqualFold(status, "active")

	if !notRevoked {
		logVerificationToDB(session.CredentialID, fabricCredID, "VER-UOS-0001", resolveVerifiedBy,
			"failure", strings.ToUpper(status), true, false, false, false, status)
		deleteMobileSession(req.SessionToken)
		writeJSON(w, http.StatusOK, map[string]any{
			"verified": false, "credentialID": session.CredentialID,
			"holderID": holderIDFromChain, "holderName": holderName,
			"holderEmail": holderEmail, "holderEID": holderEID,
			"credentialType": credentialType, "issuer": "University of Sharjah",
			"verifiedBy": resolveVerifiedBy, "status": status,
			"issuedAt": issuedAtFromInfo, "expiryDate": expiryDate,
			"credentialData": credData, "reason": strings.ToUpper(status),
			"checks": map[string]bool{"existsOnChain": true, "notRevoked": false, "signatureValid": false, "hashMatches": false},
		})
		return
	}

	credHash, _ := cred["CredentialHash"].(string)
	signature, _ := cred["Signature"].(string)
	publicKey, _ := cred["PublicKey"].(string)
	sigValid, _ := pqcVerify(credHash, signature, publicKey)
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
	logVerificationToDB(session.CredentialID, fabricCredID, "VER-UOS-0001", resolveVerifiedBy,
		result, failureReason, true, hashMatches, sigValid, notRevoked, status)
	deleteMobileSession(req.SessionToken)

	writeJSON(w, http.StatusOK, map[string]any{
		"verified": verified, "credentialID": session.CredentialID,
		"fabricCredID": fabricCredID, "holderID": holderIDFromChain,
		"holderName": holderName, "holderEmail": holderEmail, "holderEID": holderEID,
		"credentialType": credentialType, "issuer": "University of Sharjah",
		"verifiedBy": resolveVerifiedBy, "status": status,
		"issuedAt": issuedAtFromInfo, "expiryDate": expiryDate,
		"credentialData": credData,
		"checks": map[string]bool{
			"existsOnChain": true, "notRevoked": notRevoked,
			"signatureValid": sigValid, "hashMatches": hashMatches,
		},
	})
}

func applySelectiveDisclosure(credData map[string]any, hiddenFields []string) {
	if credData == nil {
		return
	}
	for _, field := range hiddenFields {
		if strings.Contains(field, ".") {
			parts := strings.SplitN(field, ".", 2)
			if sub, ok := credData[parts[0]].(map[string]any); ok {
				sub[parts[1]] = nil
			}
		} else {
			if _, exists := credData[field]; exists {
				credData[field] = nil
			}
		}
	}
}

// ─── SUBSCRIPTIONS ───────────────────────────────────────────────────────────

func handleRequestSubscription(w http.ResponseWriter, r *http.Request) {
	var req struct {
		CredentialID string `json:"credentialID"`
	}
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	if req.CredentialID == "" {
		writeError(w, http.StatusBadRequest, "missing credentialID")
		return
	}
	cred, err := getCredentialDetail(req.CredentialID)
	if err == sql.ErrNoRows {
		writeError(w, http.StatusNotFound, "credential not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	if cred.Status == "revoked" {
		writeError(w, http.StatusBadRequest, "cannot subscribe to a revoked credential")
		return
	}
	exists, err := activeSubscriptionExists(req.CredentialID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	if exists {
		writeError(w, http.StatusConflict, "subscription already exists for this credential")
		return
	}
	subID := generateSubscriptionID()
	if err := insertSubscription(subID, req.CredentialID, cred.HolderID); err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"success": true, "subscriptionID": subID})
}

func handleGetSubscriptions(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	page := parsePositiveInt(q.Get("page"), 1)
	limit := parsePositiveInt(q.Get("limit"), 100)
	rows, err := getSubscriptions(page, limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	out := make([]map[string]any, 0, len(rows))
	for _, s := range rows {
		out = append(out, map[string]any{
			"id":             s.SubscriptionID,
			"holderName":     s.HolderName,
			"holderID":       s.HolderID,
			"credentialType": s.CredentialType,
			"issuer":         s.Issuer,
			"subscribedDate": NullDateDisplay(s.SubscribedAt, "—"),
			"expiryDate":     NullDateDisplay(s.ExpiryDate, "—"),
			"status":         s.Status,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"subscriptions": out})
}

func handleDeleteSubscription(w http.ResponseWriter, r *http.Request) {
	var req struct {
		SubscriptionID string `json:"subscriptionID"`
	}
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	if req.SubscriptionID == "" {
		writeError(w, http.StatusBadRequest, "missing subscriptionID")
		return
	}
	status, err := getSubscriptionStatus(req.SubscriptionID)
	if err == sql.ErrNoRows {
		writeError(w, http.StatusNotFound, "subscription not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	if status != "pending" {
		writeError(w, http.StatusBadRequest, "only pending subscriptions can be deleted")
		return
	}
	if err := deleteSubscriptionRow(req.SubscriptionID); err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"success": true, "subscriptionID": req.SubscriptionID})
}

func handleUnsubscribe(w http.ResponseWriter, r *http.Request) {
	var req struct {
		SubscriptionID string `json:"subscriptionID"`
	}
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	if req.SubscriptionID == "" {
		writeError(w, http.StatusBadRequest, "missing subscriptionID")
		return
	}
	status, err := getSubscriptionStatus(req.SubscriptionID)
	if err == sql.ErrNoRows {
		writeError(w, http.StatusNotFound, "subscription not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	if status != "active" {
		writeError(w, http.StatusBadRequest, "only active subscriptions can be unsubscribed")
		return
	}
	if err := unsubscribeSubscription(req.SubscriptionID); err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"success": true, "subscriptionID": req.SubscriptionID})
}

// ─── ALERTS ──────────────────────────────────────────────────────────────────

func handleGetSubscriptionAlerts(w http.ResponseWriter, r *http.Request) {
	rows, err := getAlerts()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	out := make([]map[string]any, 0, len(rows))
	for _, a := range rows {
		out = append(out, map[string]any{
			"id":             a.AlertID,
			"holderName":     a.HolderName,
			"credentialName": a.CredentialName,
			"severity":       a.Severity,
			"description":    a.Description,
			"dateTime":       FormatDateTimeDisplay(a.TriggeredAt),
			"acknowledged":   a.Acknowledged,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"alerts": out})
}

func handleAcknowledgeAlert(w http.ResponseWriter, r *http.Request) {
	var req struct {
		AlertID string `json:"alertID"`
	}
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	if req.AlertID == "" {
		writeError(w, http.StatusBadRequest, "missing alertID")
		return
	}
	exists, err := alertExists(req.AlertID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	if !exists {
		writeError(w, http.StatusNotFound, "alert not found")
		return
	}
	if err := acknowledgeAlert(req.AlertID); err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"success": true, "alertID": req.AlertID})
}

// ─── AUDIT LOGS ──────────────────────────────────────────────────────────────

func handleGetAuditLogs(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	page := parsePositiveInt(q.Get("page"), 1)
	limit := parsePositiveInt(q.Get("limit"), 500)
	rows, err := getAuditLogs(page, limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	out := make([]map[string]any, 0, len(rows))
	for _, a := range rows {
		out = append(out, map[string]any{
			"id":              a.AuditID,
			"action":          a.Action,
			"details":         a.Details,
			"performedBy":     a.PerformedByName,
			"performedByRole": a.PerformedByRole,
			"ipAddress":       a.IPAddress,
			"timestamp":       FormatISO(a.CreatedAt),
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"records": out})
}

// ─── STAFF MANAGEMENT ────────────────────────────────────────────────────────

func handleGetStaff(w http.ResponseWriter, r *http.Request) {
	rows, err := getStaff()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	out := make([]map[string]any, 0, len(rows))
	for _, s := range rows {
		out = append(out, map[string]any{
			"id":        s.ID,
			"name":      s.Name,
			"email":     s.Email,
			"portal":    s.Portal,
			"role":      s.Role,
			"addedDate": FormatDateDisplay(s.AddedDate),
			"status":    s.Status,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"staff": out})
}

func handleInviteStaff(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Email  string `json:"email"`
		Portal string `json:"portal"`
		Role   string `json:"role"`
	}
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	if req.Email == "" {
		writeError(w, http.StatusBadRequest, "missing email")
		return
	}
	if req.Portal == "" {
		writeError(w, http.StatusBadRequest, "missing portal")
		return
	}
	if req.Role == "" {
		writeError(w, http.StatusBadRequest, "missing role")
		return
	}
	if req.Portal != "issuer" && req.Portal != "verifier" {
		writeError(w, http.StatusBadRequest, "invalid portal")
		return
	}
	if req.Role == "admin" {
		writeError(w, http.StatusBadRequest, "admin role cannot be assigned via this endpoint")
		return
	}
	if err := validateStaffRole(req.Portal, req.Role); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	exists, err := staffEmailExists(req.Email)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	if exists {
		writeError(w, http.StatusConflict, "email already invited or active")
		return
	}
	staffID := generateStaffID()
	if err := insertStaff(staffID, req.Email, req.Portal, req.Role); err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	insertAuditLog("staff_added",
		fmt.Sprintf("Staff %s invited to %s portal as %s", req.Email, req.Portal, req.Role),
		issuerActorName, "Issuer Admin", r.RemoteAddr)
	writeJSON(w, http.StatusOK, map[string]any{"success": true, "staffID": staffID})
}

func handleUpdateStaffRole(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ID     string `json:"id"`
		Portal string `json:"portal"`
		Role   string `json:"role"`
	}
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	if req.ID == "" {
		writeError(w, http.StatusBadRequest, "missing id")
		return
	}
	if req.Portal == "" {
		writeError(w, http.StatusBadRequest, "missing portal")
		return
	}
	if req.Role == "" {
		writeError(w, http.StatusBadRequest, "missing role")
		return
	}
	if req.Portal != "issuer" && req.Portal != "verifier" {
		writeError(w, http.StatusBadRequest, "invalid portal")
		return
	}
	if req.Role == "admin" {
		writeError(w, http.StatusBadRequest, "admin role cannot be modified via this endpoint")
		return
	}
	if err := validateStaffRole(req.Portal, req.Role); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if _, err := getStaffByID(req.ID); err == sql.ErrNoRows {
		writeError(w, http.StatusNotFound, "staff member not found")
		return
	} else if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	if err := updateStaffRole(req.ID, req.Portal, req.Role); err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"success": true, "staffID": req.ID})
}

func handleDeleteStaff(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ID     string `json:"id"`
		Portal string `json:"portal"`
	}
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	if req.ID == "" {
		writeError(w, http.StatusBadRequest, "missing id")
		return
	}
	if req.Portal == "" {
		writeError(w, http.StatusBadRequest, "missing portal")
		return
	}
	if req.Portal != "issuer" && req.Portal != "verifier" {
		writeError(w, http.StatusBadRequest, "invalid portal")
		return
	}
	staff, err := getStaffByID(req.ID)
	if err == sql.ErrNoRows {
		writeError(w, http.StatusNotFound, "staff member not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	if staff.Portal != req.Portal {
		writeError(w, http.StatusBadRequest, "portal mismatch")
		return
	}
	if err := softDeleteStaff(req.ID); err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	insertAuditLog("staff_removed",
		fmt.Sprintf("Staff %s removed from %s portal", staff.Email, req.Portal),
		issuerActorName, "Issuer Admin", r.RemoteAddr)
	writeJSON(w, http.StatusOK, map[string]any{"success": true, "staffID": req.ID})
}

func validateStaffRole(portal, role string) error {
	if portal == "issuer" {
		switch role {
		case "staff", "schemaManager":
			return nil
		}
		return fmt.Errorf("invalid role for portal")
	}
	switch role {
	case "verifier", "policyManager":
		return nil
	}
	return fmt.Errorf("invalid role for portal")
}

// ─────────────────────────────────────────────────────────────────────────────
//  PHASE C — QWALLET MOBILE HANDLERS (/mobile/*)
// ─────────────────────────────────────────────────────────────────────────────

func handleMobileGetCredentialsByHolder(w http.ResponseWriter, r *http.Request) {
	emiratesID := r.URL.Query().Get("emiratesID")
	if emiratesID == "" {
		writeError(w, http.StatusBadRequest, "missing emiratesID")
		return
	}
	rows, err := getMobileCredentials(emiratesID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	out := make([]map[string]any, 0, len(rows))
	for _, c := range rows {
		var expiry any
		if c.ExpiryDate.Valid {
			expiry = c.ExpiryDate.Time.UTC().Format(time.RFC3339)
		}
		var attrs map[string]any
		_ = json.Unmarshal([]byte(c.CredentialData), &attrs)
		out = append(out, map[string]any{
			"credentialID":   c.CredentialID,
			"credentialType": c.CredentialType,
			"holderName":     c.HolderName,
			"holderEID":      c.HolderEID,
			"issuedBy":       c.IssuerName,
			"issuedAt":       c.IssuedAt.UTC().Format(time.RFC3339),
			"expiryDate":     expiry,
			"status":         c.Status,
			"isFavorite":     c.IsFavorite,
			"category":       c.Category,
			"attributes":     attrs,
			"signature":      c.Signature,
			"txHash":         c.FabricCredID,
			"cid":            c.IPFSCID,
			"publicKey":      c.PublicKey,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

func handleToggleFavorite(w http.ResponseWriter, r *http.Request) {
	var req struct {
		HolderEID    string `json:"holderEID"`
		CredentialID string `json:"credentialID"`
	}
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	if req.HolderEID == "" {
		writeError(w, http.StatusBadRequest, "missing holderEID")
		return
	}
	if req.CredentialID == "" {
		writeError(w, http.StatusBadRequest, "missing credentialID")
		return
	}
	if err := toggleFavorite(req.CredentialID, req.HolderEID); err == sql.ErrNoRows {
		writeError(w, http.StatusNotFound, "credential not found")
		return
	} else if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"success": true})
}

func handleGetActivity(w http.ResponseWriter, r *http.Request) {
	emiratesID := r.URL.Query().Get("emiratesID")
	if emiratesID == "" {
		writeError(w, http.StatusBadRequest, "missing emiratesID")
		return
	}
	rows, err := getMobileActivity(emiratesID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	out := make([]map[string]any, 0, len(rows))
	for _, a := range rows {
		out = append(out, map[string]any{
			"id":             strconv.FormatInt(a.EventID, 10),
			"type":           a.EventType,
			"credentialName": a.CredentialType,
			"actor":          a.ActorName,
			"timestamp":      a.CreatedAt.UTC().Format(time.RFC3339),
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"success": true, "activity": out})
}

func handleGenerateOTP(w http.ResponseWriter, r *http.Request) {
	var req struct {
		CredentialID string   `json:"credentialID"`
		HiddenFields []string `json:"hiddenFields"`
		ExpiresIn    int      `json:"expiresIn"`
	}
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	if req.CredentialID == "" {
		writeError(w, http.StatusBadRequest, "missing credentialID")
		return
	}
	if req.ExpiresIn <= 0 {
		req.ExpiresIn = 120
	}
	holderID, err := credentialHolderID(req.CredentialID)
	if err == sql.ErrNoRows {
		writeError(w, http.StatusNotFound, "credential not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}

	var otpID string
	for i := 0; i < 3; i++ {
		n, _ := rand.Int(rand.Reader, big.NewInt(1000000))
		otpID = fmt.Sprintf("OTP-%06d", n.Int64())
		if !mobileSessionExists(otpID) {
			break
		}
		otpID = ""
	}
	if otpID == "" {
		writeError(w, http.StatusInternalServerError, "unable to generate unique OTP. Please try again.")
		return
	}
	if err := insertMobileSession(otpID, "otp", req.CredentialID, holderID, req.HiddenFields, req.ExpiresIn); err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	expiresAt := time.Now().UTC().Add(time.Duration(req.ExpiresIn) * time.Second)
	writeJSON(w, http.StatusOK, map[string]any{
		"success":   true,
		"otp":       otpID[4:],
		"expiresAt": expiresAt.Format(time.RFC3339),
	})
}

func handleGeneratePresentation(w http.ResponseWriter, r *http.Request) {
	var req struct {
		CredentialID string   `json:"credentialID"`
		HiddenFields []string `json:"hiddenFields"`
		ExpiresIn    int      `json:"expiresIn"`
	}
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	if req.CredentialID == "" {
		writeError(w, http.StatusBadRequest, "missing credentialID")
		return
	}
	if req.ExpiresIn <= 0 {
		req.ExpiresIn = 120
	}
	holderID, err := credentialHolderID(req.CredentialID)
	if err == sql.ErrNoRows {
		writeError(w, http.StatusNotFound, "credential not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}

	var presID string
	for i := 0; i < 3; i++ {
		b := make([]byte, 4)
		_, _ = rand.Read(b)
		presID = fmt.Sprintf("PRES-%x", b)
		if !mobileSessionExists(presID) {
			break
		}
		presID = ""
	}
	if presID == "" {
		writeError(w, http.StatusInternalServerError, "unable to generate unique session ID. Please try again.")
		return
	}
	if err := insertMobileSession(presID, "qr", req.CredentialID, holderID, req.HiddenFields, req.ExpiresIn); err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	expiresAt := time.Now().UTC().Add(time.Duration(req.ExpiresIn) * time.Second)
	writeJSON(w, http.StatusOK, map[string]any{
		"success":        true,
		"presentationID": presID,
		"expiresAt":      expiresAt.Format(time.RFC3339),
	})
}

func handleGetCatalog(w http.ResponseWriter, r *http.Request) {
	catalogRows, err := getCatalogRows()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}

	type serviceJSON struct {
		ID          string `json:"id"`
		Name        string `json:"name"`
		Description string `json:"description"`
	}
	type issuerJSON struct {
		ID       string        `json:"id"`
		Name     string        `json:"name"`
		Services []serviceJSON `json:"services"`
	}
	type categoryJSON struct {
		Name    string       `json:"name"`
		Issuers []issuerJSON `json:"issuers"`
	}

	categoryMap := map[string]int{}
	categories := []categoryJSON{}

	for _, row := range catalogRows {
		catIdx, exists := categoryMap[row.Category]
		if !exists {
			catIdx = len(categories)
			categoryMap[row.Category] = catIdx
			categories = append(categories, categoryJSON{Name: row.Category, Issuers: []issuerJSON{}})
		}
		cat := &categories[catIdx]

		issuerIdx := -1
		for i, iss := range cat.Issuers {
			if iss.ID == row.IssuerID {
				issuerIdx = i
				break
			}
		}
		if issuerIdx == -1 {
			cat.Issuers = append(cat.Issuers, issuerJSON{ID: row.IssuerID, Name: row.IssuerName, Services: []serviceJSON{}})
			issuerIdx = len(cat.Issuers) - 1
		}
		if row.ServiceID.Valid {
			cat.Issuers[issuerIdx].Services = append(cat.Issuers[issuerIdx].Services, serviceJSON{
				ID:          row.ServiceID.String,
				Name:        row.ServiceName.String,
				Description: row.Description.String,
			})
		}
	}

	writeJSON(w, http.StatusOK, map[string]any{"success": true, "categories": categories})
}

func handleFetchDocument(w http.ResponseWriter, r *http.Request) {
	var req struct {
		HolderEID   string `json:"holderEID"`
		IssuerID    string `json:"issuerID"`
		ServiceName string `json:"serviceName"`
	}
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	if req.HolderEID == "" {
		writeError(w, http.StatusBadRequest, "missing holderEID")
		return
	}
	if req.IssuerID == "" {
		writeError(w, http.StatusBadRequest, "missing issuerID")
		return
	}
	if req.ServiceName == "" {
		writeError(w, http.StatusBadRequest, "missing serviceName")
		return
	}
	if _, _, err := holderByEmiratesID(req.HolderEID); err != nil {
		writeError(w, http.StatusBadRequest, "holder not found")
		return
	}
	var issuerCount int
	_ = db.QueryRow(`SELECT COUNT(*) FROM catalog_issuers WHERE id = ?`, req.IssuerID).Scan(&issuerCount)
	if issuerCount == 0 {
		writeError(w, http.StatusBadRequest, "issuer not found")
		return
	}
	var serviceCount int
	_ = db.QueryRow(`SELECT COUNT(*) FROM catalog_services WHERE issuer_id = ? AND name = ?`,
		req.IssuerID, req.ServiceName).Scan(&serviceCount)
	if serviceCount == 0 {
		writeError(w, http.StatusBadRequest, "service not found")
		return
	}

	found, _, err := fetchDocumentInDB(req.HolderEID, req.IssuerID, req.ServiceName)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	if !found {
		writeJSON(w, http.StatusOK, map[string]any{
			"success": false,
			"message": "Document not yet issued. Please request from the issuer.",
		})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"success": true,
		"message": "Document retrieved successfully.",
	})
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

	// Phase 2 — QPortal
	mux.HandleFunc("GET /getCredentialDetail", handleGetCredentialDetail)
	mux.HandleFunc("POST /updateCredential", handleUpdateCredential)
	mux.HandleFunc("GET /getVerificationDetail", handleGetVerificationDetail)
	mux.HandleFunc("POST /resolveSession", handleResolveSession)
	mux.HandleFunc("POST /requestSubscription", handleRequestSubscription)
	mux.HandleFunc("GET /getSubscriptions", handleGetSubscriptions)
	mux.HandleFunc("POST /deleteSubscription", handleDeleteSubscription)
	mux.HandleFunc("POST /unsubscribe", handleUnsubscribe)
	mux.HandleFunc("GET /getSubscriptionAlerts", handleGetSubscriptionAlerts)
	mux.HandleFunc("POST /acknowledgeAlert", handleAcknowledgeAlert)
	mux.HandleFunc("GET /getAuditLogs", handleGetAuditLogs)
	mux.HandleFunc("GET /getStaff", handleGetStaff)
	mux.HandleFunc("POST /inviteStaff", handleInviteStaff)
	mux.HandleFunc("POST /updateStaffRole", handleUpdateStaffRole)
	mux.HandleFunc("POST /deleteStaff", handleDeleteStaff)

	// QWallet — mobile endpoints
	mux.HandleFunc("GET /mobile/getCredentialsByHolder", handleMobileGetCredentialsByHolder)
	mux.HandleFunc("POST /mobile/toggleFavorite", handleToggleFavorite)
	mux.HandleFunc("GET /mobile/getActivity", handleGetActivity)
	mux.HandleFunc("POST /mobile/generateOTP", handleGenerateOTP)
	mux.HandleFunc("POST /mobile/generatePresentation", handleGeneratePresentation)
	mux.HandleFunc("GET /mobile/getCatalog", handleGetCatalog)
	mux.HandleFunc("POST /mobile/fetchDocument", handleFetchDocument)

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
