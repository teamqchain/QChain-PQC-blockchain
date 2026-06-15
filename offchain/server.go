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
