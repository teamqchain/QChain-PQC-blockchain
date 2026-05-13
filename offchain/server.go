package main

import (
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

// networkRoot is the base path to qchain-network, relative to the binary
// (or overridden via NETWORK_ROOT env var).
// When running inside Docker the volume is mounted at /qchain-network,
// so set NETWORK_ROOT=/qchain-network in your docker-compose service.
var networkRoot = getEnv("NETWORK_ROOT", "/qchain-network")

var (
	ipfsHost      = getEnv("IPFS_HOST", "host.docker.internal:5001")
	serverPort    = getEnv("SERVER_PORT", "3000")
	channelName   = getEnv("CHANNEL_NAME", "mychannel")
	chaincodeName = getEnv("CHAINCODE_NAME", "qchaincode")

	// Org peer/TLS endpoints – keyed by lowercase org name.
	// MSPDir and WalletDir are constructed from networkRoot at runtime
	// so they automatically follow NETWORK_ROOT.
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

// mspDir returns the MSP directory for an org, rooted at networkRoot.
// e.g. ../../qchain-network/crypto-material/peerOrganizations/government.uae.com
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

// walletDir returns the wallet directory for an org, rooted at networkRoot.
// e.g. ../../qchain-network/wallet/government
func walletDir(orgLC string) string {
	return filepath.Join(networkRoot, "wallet", orgLC)
}

// connectionProfilePath returns the connection profile JSON path for an org.
// e.g. ../../qchain-network/connection/connection-gov.json
func connectionProfilePath(orgLC string) string {
	prefix := orgLC[:3] // "gov" or "gen"
	return filepath.Join(networkRoot, "connection", "connection-"+prefix+".json")
}

// ─────────────────────────────────────────────
//  REQUEST / RESPONSE TYPES
// ─────────────────────────────────────────────

type RegisterHolderRequest struct {
	Org       string `json:"org"`
	Identity  string `json:"identity"`
	FirstName string `json:"firstName"`
	LastName  string `json:"lastName"`
}

type IssueCredentialRequest struct {
	Org        string `json:"org"`
	Identity   string `json:"identity"`
	HolderID   string `json:"holderID"`
	Info       string `json:"info"`
	FilePath   string `json:"filePath"`
	PrivateKey string `json:"privateKey"` // optional
	PublicKey  string `json:"publicKey"`  // optional
}

type VerifyCredentialRequest struct {
	Org       string `json:"org"`
	Identity  string `json:"identity"`
	CredID    string `json:"credID"`
	Message   string `json:"message"`
	Signature string `json:"signature"`
	PublicKey string `json:"publicKey"`
}

type RevokeCredentialRequest struct {
	Org      string `json:"org"`
	Identity string `json:"identity"`
	CredID   string `json:"credID"`
}

type SetCIDRequest struct {
	Org      string `json:"org"`
	Identity string `json:"identity"`
	CredID   string `json:"credID"`
	CID      string `json:"cid"`
}

type ErrorResponse struct {
	Error string `json:"error"`
}

// ─────────────────────────────────────────────
//  WALLET .id FILE PARSING
// ─────────────────────────────────────────────

// walletIDFile mirrors the JSON structure that the Node.js fabric-network SDK
// writes when you call wallet.put(label, x509Identity).
// Files are stored as: wallet/<org>/<identityName>.id
type walletIDFile struct {
	Credentials struct {
		Certificate string `json:"certificate"`
		PrivateKey  string `json:"privateKey"`
	} `json:"credentials"`
	MspID   string `json:"mspId"`
	Type    string `json:"type"`
	Version int    `json:"version"`
}

// loadWalletIdentity reads a <identityName>.id file from the file-system wallet
// and returns the PEM-encoded certificate and private key as byte slices.
func loadWalletIdentity(orgLC, identityName string) (certPEM, keyPEM []byte, err error) {
	idFilePath := filepath.Join(walletDir(orgLC), identityName+".id")

	data, err := os.ReadFile(idFilePath)
	if err != nil {
		return nil, nil, fmt.Errorf(
			"wallet identity %q not found for org %q (expected at %s): %w",
			identityName, orgLC, idFilePath, err,
		)
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

// getContract connects to the Fabric Gateway and returns a Contract handle.
// Caller must call gw.Close() and conn.Close() when done.
func getContract(orgName, identityName string) (*client.Contract, *client.Gateway, *grpc.ClientConn, error) {
	orgLC := strings.ToLower(orgName)
	cfg, ok := orgConfig[orgLC]
	if !ok {
		return nil, nil, nil, fmt.Errorf("unknown org %q", orgName)
	}

	// ── TLS CA cert for the peer ──────────────────────────────────────────
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

	// ── Identity from .id wallet file ────────────────────────────────────
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
		return nil, nil, nil, fmt.Errorf("creating signer from private key: %w", err)
	}

	// ── Connect Gateway ──────────────────────────────────────────────────
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

// pqcGenKeyPair generates a fresh ML-DSA-44 key pair.
// Returns (publicKeyHex, privateKeyHex, error).
func pqcGenKeyPair() (string, string, error) {
	signer := oqs.Signature{}
	defer signer.Clean()
	if err := signer.Init(sigName, nil); err != nil {
		return "", "", fmt.Errorf("init PQC signer: %w", err)
	}
	pubKey, err := signer.GenerateKeyPair()
	if err != nil {
		return "", "", fmt.Errorf("generate key pair: %w", err)
	}
	privKey := signer.ExportSecretKey()
	return hex.EncodeToString(pubKey), hex.EncodeToString(privKey), nil
}

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
//  IPFS HELPER
// ─────────────────────────────────────────────

// uploadDocumentAndSign uploads a PDF to IPFS, and signs its CID with the provided
// ML-DSA-44 private key. If keys are omitted, a new key pair is generated.
func uploadDocumentAndSign(filePath, privateKeyHex, publicKeyHex string) (documentCID, pubKeyHexOut, privKeyHexOut, sigHex string, err error) {
	pdfFile, err := os.Open(filePath)
	if err != nil {
		return "", "", "", "", fmt.Errorf("opening document %q: %w", filePath, err)
	}
	defer pdfFile.Close()

	sh := shell.NewShell(ipfsHost)

	documentCID, err = sh.Add(pdfFile)
	if err != nil {
		return "", "", "", "", fmt.Errorf("IPFS upload document: %w", err)
	}

	if privateKeyHex == "" || publicKeyHex == "" {
		pubKeyHexOut, privKeyHexOut, err = pqcGenKeyPair()
		if err != nil {
			return "", "", "", "", err
		}
	} else {
		privKeyHexOut = privateKeyHex
		pubKeyHexOut = publicKeyHex
	}

	sigHex, err = pqcSign(documentCID, privKeyHexOut) // Signs documentCID instead of info
	if err != nil {
		return "", "", "", "", err
	}

	return documentCID, pubKeyHexOut, privKeyHexOut, sigHex, nil
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

// ─────────────────────────────────────────────
//  ROUTE HANDLERS
// ─────────────────────────────────────────────

// POST /registerHolder
func handleRegisterHolder(w http.ResponseWriter, r *http.Request) {
	var req RegisterHolderRequest
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if req.Org == "" || req.Identity == "" || req.FirstName == "" || req.LastName == "" {
		writeError(w, http.StatusBadRequest, "missing parameters: org, identity, firstName, lastName")
		return
	}

	contract, gw, conn, err := getContract(req.Org, req.Identity)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer gw.Close()
	defer conn.Close()

	result, err := contract.SubmitTransaction("registerHolder", req.FirstName, req.LastName)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	var parsed any
	_ = json.Unmarshal(result, &parsed)
	writeJSON(w, http.StatusOK, parsed)
}

// POST /issueCredential
// Handles both issuing the credential and uploading/signing the document.
func handleIssueCredential(w http.ResponseWriter, r *http.Request) {
	var req IssueCredentialRequest
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if req.Org == "" || req.Identity == "" || req.HolderID == "" || req.Info == "" || req.FilePath == "" {
		writeError(w, http.StatusBadRequest, "missing parameters: org, identity, holderID, info, filePath")
		return
	}

	// 1. Upload to IPFS, get documentCID, generate keys (if not provided), and sign the documentCID
	documentCID, pubKeyHex, privKeyHex, sigHex, err := uploadDocumentAndSign(req.FilePath, req.PrivateKey, req.PublicKey)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Document upload/sign failed: "+err.Error())
		return
	}

	// 2. Connect to the fabric gateway
	contract, gw, conn, err := getContract(req.Org, req.Identity)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer gw.Close()
	defer conn.Close()

	// 3. Issue the credential on-chain
	result, err := contract.SubmitTransaction("issueCredential", req.HolderID, req.Info, pubKeyHex)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	// 4. Parse the chaincode response to retrieve the credID and submit the setCID transaction
	var chainParsed map[string]any
	_ = json.Unmarshal(result, &chainParsed)

	// Extract the credential ID to associate the documentCID
	var credID string
	if idVal, ok := chainParsed["id"].(string); ok {
		credID = idVal
	} else if idVal, ok := chainParsed["credID"].(string); ok {
		credID = idVal
	}

	if credID != "" {
		_, err = contract.SubmitTransaction("setCID", credID, documentCID)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "setCID on-chain failed: "+err.Error())
			return
		}
	}

	// 5. Build combined response payload
	chainParsed["publicKey"] = pubKeyHex
	chainParsed["privateKey"] = privKeyHex // ⚠ transmit over TLS only
	chainParsed["signature"] = sigHex
	chainParsed["documentCID"] = documentCID
	chainParsed["message"] = "Credential issued, document uploaded, signed, and documentCID anchored on-chain"

	writeJSON(w, http.StatusOK, chainParsed)
}

// POST /verifyCredential
func handleVerifyCredential(w http.ResponseWriter, r *http.Request) {
	var req VerifyCredentialRequest
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if req.Org == "" || req.Identity == "" || req.CredID == "" ||
		req.Message == "" || req.Signature == "" || req.PublicKey == "" {
		writeError(w, http.StatusBadRequest,
			"missing parameters: org, identity, credID, message, signature, publicKey")
		return
	}
	// Comment out below to test IPFS + PQC independently without on-chain
	contract, gw, conn, err := getContract(req.Org, req.Identity)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer gw.Close()
	defer conn.Close()

	chainResult, err := contract.EvaluateTransaction("verifyCredential", req.CredID, req.PublicKey)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	var chainData map[string]any
	_ = json.Unmarshal(chainResult, &chainData)
	if verified, _ := chainData["verified"].(bool); !verified {
		writeJSON(w, http.StatusOK, map[string]any{
			"verified": false,
			"reason":   "public key mismatch or credential inactive on chain",
		})
		return
	}
	//
	valid, err := pqcVerify(req.Message, req.Signature, req.PublicKey)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "PQC verify error: "+err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"verified": valid})
}

// POST /revokeCredential
func handleRevokeCredential(w http.ResponseWriter, r *http.Request) {
	var req RevokeCredentialRequest
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if req.Org == "" || req.Identity == "" || req.CredID == "" {
		writeError(w, http.StatusBadRequest, "missing parameters: org, identity, credID")
		return
	}

	contract, gw, conn, err := getContract(req.Org, req.Identity)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer gw.Close()
	defer conn.Close()

	result, err := contract.SubmitTransaction("revokeCredential", req.CredID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	var parsed any
	_ = json.Unmarshal(result, &parsed)
	writeJSON(w, http.StatusOK, parsed)
}

// POST /setCID
func handleSetCID(w http.ResponseWriter, r *http.Request) {
	var req SetCIDRequest
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if req.Org == "" || req.Identity == "" || req.CredID == "" || req.CID == "" {
		writeError(w, http.StatusBadRequest, "missing parameters: org, identity, credID, cid")
		return
	}

	contract, gw, conn, err := getContract(req.Org, req.Identity)
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

// GET /getCredentialsByHolder?org=...&identity=...&holderID=...
func handleGetCredentialsByHolder(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	org := q.Get("org")
	identityName := q.Get("identity")
	holderID := q.Get("holderID")

	if org == "" || identityName == "" || holderID == "" {
		writeError(w, http.StatusBadRequest, "missing query params: org, identity, holderID")
		return
	}

	contract, gw, conn, err := getContract(org, identityName)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer gw.Close()
	defer conn.Close()

	result, err := contract.EvaluateTransaction("getCredentialsByHolder", holderID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	var parsed any
	_ = json.Unmarshal(result, &parsed)
	writeJSON(w, http.StatusOK, parsed)
}

// ─────────────────────────────────────────────
//  MAIN — router + server
// ─────────────────────────────────────────────

func main() {
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
	fmt.Printf("  Network root: %s\n", networkRoot)
	fmt.Printf("  Channel:      %s\n", channelName)
	fmt.Printf("  Chaincode:    %s\n", chaincodeName)
	fmt.Printf("  IPFS host:    %s\n", ipfsHost)
	fmt.Printf("  PQC algo:     %s\n", sigName)

	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatal(err)
	}
}
