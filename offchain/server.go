package main

// server.go — the program entry point.
//
// This file is deliberately small: it wires everything together but contains no
// business logic. Responsibilities:
//   • main()          — load keys/env, connect to MySQL, register every route on
//                       an http.ServeMux, and start the HTTP server.
//   • corsMiddleware  — allow the Flutter Web frontend (a different origin) to
//                       call this API from a browser.
//
// The actual handlers live in domain files in this same package (credentials.go,
// verification.go, mobile.go, ...). Because they are all `package main`, main()
// can reference them directly — no imports between files are needed. To find a
// handler, search for its name; to see the full URL map, read the mux block below.

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

// corsMiddleware sets CORS headers so Flutter Web can reach the API. It wraps the
// real router: every request passes through here first. OPTIONS (the browser's
// pre-flight check) is answered immediately; everything else falls through to next.
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

func main() {
	// One-shot: generate an org ML-KEM key pair and exit. Container-friendly — no
	// cmd/ needed in the image, no liboqs needed on the host. Needs neither the
	// issuer keys nor the database, so it runs first.
	//   docker run --rm -e GENERATE_ORG_KEM=1 qchain-api:latest
	if os.Getenv("GENERATE_ORG_KEM") == "1" {
		if n := resolveKEMName(); n != "" {
			kemName = n
		}
		generateOrgKEM()
		return
	}

	// One-shot: generate ML-KEM key pairs for all holders without one.
	// Public keys go to the DB; private keys go to .env.holder_keys.
	//   docker run --rm -e GENERATE_HOLDER_KEYS=1 -e MYSQL_DSN=... qchain-api:latest
	if os.Getenv("GENERATE_HOLDER_KEYS") == "1" {
		if n := resolveKEMName(); n != "" {
			kemName = n
		}
		initDB()
		runGenerateHolderKeys()
		return
	}

	// Load org-level ML-DSA-44 key pair — must be set in .env; fatal if missing.
	issuerPrivKeyHex = os.Getenv("ISSUER_PRIVATE_KEY_HEX")
	issuerPubKeyHex = os.Getenv("ISSUER_PUBLIC_KEY_HEX")
	issuerOrgID = getEnv("ISSUER_ORG_ID", "GeneralMSP")

	if issuerPrivKeyHex == "" || issuerPubKeyHex == "" {
		log.Fatal("ISSUER_PRIVATE_KEY_HEX and ISSUER_PUBLIC_KEY_HEX must be set — run offchain/cmd/keygen/main.go once to generate them")
	}

	// Track B — org-level ML-KEM key pair for OFF-CHAIN credential-data encryption.
	// Optional: if unset, off-chain data is stored in plaintext exactly as before.
	if n := resolveKEMName(); n != "" {
		kemName = n
	}
	orgKemPubHex = os.Getenv("ORG_KEM_PUBLIC_KEY_HEX")
	orgKemPrivHex = os.Getenv("ORG_KEM_PRIVATE_KEY_HEX")
	if orgKemPubHex == "" {
		log.Printf("INFO: ORG_KEM_PUBLIC_KEY_HEX not set — legacy B3 org-key decryption unavailable (not needed if B3 was never deployed).")
	}

	// Connect to MySQL (non-fatal if not configured — warnings logged per request)
	initDB()

	// Track B2: load holder KEM private keys from .env.holder_keys.
	// These are for TESTING ONLY — in production, holder keys live on their devices.
	nHolderKeys := loadHolderKeysFile()
	log.Printf("Loaded %d holder KEM private key(s) from %s", nHolderKeys, holderKeysFileName)

	// One-shot maintenance mode: encrypt any legacy plaintext credential_data rows
	// in place, then exit. Run with RUN_BACKFILL_ENCRYPT=1 after setting the org KEM
	// key. Does not touch the blockchain. See backfill.go.
	if os.Getenv("RUN_BACKFILL_ENCRYPT") == "1" {
		runBackfillEncrypt()
		return
	}

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
	mux.HandleFunc("GET /getDirectory", handleGetDirectory)
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
	mux.HandleFunc("GET /mobile/getSubscriptions", handleGetMobileSubscriptions)
	mux.HandleFunc("POST /mobile/approveSubscription", handleApproveSubscription)
	mux.HandleFunc("POST /mobile/rejectSubscription", handleRejectSubscription)
	mux.HandleFunc("POST /mobile/registerHolderKey", handleRegisterHolderKey)

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
	fmt.Printf("  KEM algo:      %s (off-chain encryption: holder-key B2, holder-keys-loaded: %d)\n", kemName, len(holderKemKeys))
	fmt.Printf("  Issuer org:    %s / %s\n", issuerOrgName, issuerIdentity)
	fmt.Printf("  Verifier org:  %s / %s\n", verifierOrgName, verifierIdentity)
	fmt.Printf("  Issuer org ID: %s\n", issuerOrgID)

	log.Fatal(http.ListenAndServe(addr, corsMiddleware(mux)))
}
