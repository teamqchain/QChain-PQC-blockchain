package main

// mobile.go — the QWallet (holder phone app) endpoints, all under /mobile/*,
// plus /resolveSession which the verifier calls to redeem a QR/OTP token.
//
// Flow these handlers support: a holder views their wallet, marks favourites,
// fetches a document into the wallet, and approves/rejects verifier subscription
// requests. For sharing, the holder generates a short-lived OTP or QR session
// (generateOTP / generatePresentation); a verifier then submits that token to
// /resolveSession, which runs the same on-chain verification as the portal and
// applies "selective disclosure" (blanking out fields the holder chose to hide).

import (
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"math/big"
	"net/http"
	"strconv"
	"strings"
	"time"
)

// GET /mobile/checkKeys?emiratesID=XXX — check if a holder has registered public keys and return them.
func handleCheckKeys(w http.ResponseWriter, r *http.Request) {
	emiratesID := r.URL.Query().Get("emiratesID")
	if emiratesID == "" {
		writeError(w, http.StatusBadRequest, "missing emiratesID")
		return
	}

	type checkKeysResponse struct {
		HasKemKey     bool   `json:"hasKemKey"`
		HasSigningKey bool   `json:"hasSigningKey"`
		KemPublicKey  string `json:"kemPublicKey"`
		DsaPublicKey  string `json:"dsaPublicKey"`
	}

	holderID, _, err := holderByEmiratesID(emiratesID)
	if err != nil {
		writeJSON(w, http.StatusOK, checkKeysResponse{
			HasKemKey:     false,
			HasSigningKey: false,
			KemPublicKey:  "",
			DsaPublicKey:  "",
		})
		return
	}
	var kemPub, dsaPub sql.NullString
	_ = db.QueryRow(
		`SELECT kem_public_key, dsa_public_key FROM holders WHERE holder_id = ?`,
		holderID,
	).Scan(&kemPub, &dsaPub)

	var resp checkKeysResponse
	if kemPub.Valid && kemPub.String != "" {
		resp.HasKemKey = true
		resp.KemPublicKey = kemPub.String
	}
	if dsaPub.Valid && dsaPub.String != "" {
		resp.HasSigningKey = true
		resp.DsaPublicKey = dsaPub.String
	}

	writeJSON(w, http.StatusOK, resp)
}

// POST /mobile/registerHolderKeys — registers holder ML-KEM and ML-DSA public keys.
// The backend never receives or persists private keys.
func handleRegisterHolderKeys(w http.ResponseWriter, r *http.Request) {
	var req struct {
		EmiratesID    string `json:"emiratesID"`
		KemPublicKey  string `json:"kemPublicKey"`
		DsaPublicKey  string `json:"dsaPublicKey"`
		KemPrivateKey string `json:"kemPrivateKey"`
		DsaPrivateKey string `json:"dsaPrivateKey"`
	}
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if req.KemPrivateKey != "" || req.DsaPrivateKey != "" {
		log.Printf("SECURITY WARNING: received private key in registerHolderKeys for Emirates ID %s — ignoring", req.EmiratesID)
	}
	if req.EmiratesID == "" {
		writeError(w, http.StatusBadRequest, "missing emiratesID")
		return
	}
	if req.KemPublicKey == "" || req.DsaPublicKey == "" {
		writeError(w, http.StatusBadRequest, "missing kemPublicKey or dsaPublicKey")
		return
	}
	if _, err := hex.DecodeString(req.KemPublicKey); err != nil {
		writeError(w, http.StatusBadRequest, "invalid hex for kemPublicKey: "+err.Error())
		return
	}
	if _, err := hex.DecodeString(req.DsaPublicKey); err != nil {
		writeError(w, http.StatusBadRequest, "invalid hex for dsaPublicKey: "+err.Error())
		return
	}

	holderID, fabricHolderID, err := holderByEmiratesID(req.EmiratesID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "holder not found: "+err.Error())
		return
	}

	// 1. Update MySQL
	if err := updateHolderKeys(holderID, req.KemPublicKey, req.DsaPublicKey); err != nil {
		writeError(w, http.StatusInternalServerError, "database error: "+err.Error())
		return
	}

	// 2. Call chaincode bindHolderKeys via Fabric gateway
	contract, gw, conn, err := getContract(issuerOrgName, issuerIdentity)
	if err != nil {
		log.Printf("WARNING: Fabric connect failed for bindHolderKeys: %v", err)
		writeError(w, http.StatusInternalServerError, "blockchain gateway error: "+err.Error())
		return
	}
	defer gw.Close()
	defer conn.Close()

	result, err := contract.SubmitTransaction("bindHolderKeys", fabricHolderID, req.KemPublicKey, req.DsaPublicKey)
	if err != nil {
		log.Printf("ERROR: chaincode bindHolderKeys failed: %v", err)
		writeError(w, http.StatusInternalServerError, "chaincode bindHolderKeys failed: "+err.Error())
		return
	}
	var resp struct {
		Success bool   `json:"success"`
		Error   string `json:"error,omitempty"`
	}
	_ = json.Unmarshal(result, &resp)
	if !resp.Success && resp.Error != "" {
		writeError(w, http.StatusInternalServerError, "chaincode bindHolderKeys error: "+resp.Error)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"success": true})
}

// GET /mobile/getEnvelope?credentialID=CRED-XXXX — returns raw encrypted envelope JSON.
func handleGetEnvelope(w http.ResponseWriter, r *http.Request) {
	credentialID := r.URL.Query().Get("credentialID")
	if credentialID == "" {
		writeError(w, http.StatusBadRequest, "missing credentialID")
		return
	}
	credData, err := getCredentialDataByID(credentialID)
	if err != nil {
		writeError(w, http.StatusNotFound, "credential envelope not found: "+err.Error())
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(credData))
}

// GET /mobile/getHolderProfile?emiratesID=XXX — basic demographic info for a
// holder (full name, email, Emirates ID, holder type, college). Works even when
// the holder has no credentials yet.
func handleMobileGetHolderProfile(w http.ResponseWriter, r *http.Request) {
	emiratesID := r.URL.Query().Get("emiratesID")
	if emiratesID == "" {
		writeError(w, http.StatusBadRequest, "missing emiratesID")
		return
	}
	profile, err := holderProfileByEmiratesID(emiratesID)
	if err != nil {
		if strings.Contains(err.Error(), "not registered") {
			writeError(w, http.StatusNotFound, err.Error())
		} else {
			writeError(w, http.StatusInternalServerError, "database error")
		}
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"success":    true,
		"fullName":   profile.FullName,
		"email":      profile.Email,
		"emiratesID": profile.EmiratesID,
		"holderType": holderTypeDBToAPI(profile.HolderType),
		"college":    profile.College,
	})
}

// GET /mobile/getCredentialsByHolder?emiratesID=XXX — credentials in a holder's wallet.
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
			expiry = c.ExpiryDate.Time.Format(time.RFC3339)
		}

		// Track H: Stop server-side decryption. The server is zero-knowledge and sends
		// ciphertext envelope directly to the phone for local on-device decryption.
		var attrs any = nil
		if !looksLikeEnvelope([]byte(c.CredentialData)) {
			// Legacy plaintext credential
			var parsedAttrs map[string]any
			if err := json.Unmarshal([]byte(c.CredentialData), &parsedAttrs); err == nil {
				attrs = parsedAttrs
			}
		}

		out = append(out, map[string]any{
			"credentialID":   c.CredentialID,
			"credentialType": c.CredentialType,
			"holderName":     c.HolderName,
			"holderEID":      c.HolderEID,
			"issuedBy":       c.IssuerName,
			"issuedAt":       c.IssuedAt.Format(time.RFC3339),
			"expiryDate":     expiry,
			"status":         c.Status,
			"isFavorite":     c.IsFavorite,
			"category":       c.Category,
			"attributes":     attrs,
			"envelope":       c.CredentialData, // 🔒 PRODUCTION ENCRYPTED ENVELOPE (Decrypted on-device)
			"signature":      c.Signature,
			"txHash":         c.FabricCredID,
			"cid":            c.IPFSCID,
			"publicKey":      c.PublicKey,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

// POST /mobile/toggleFavorite — pin/unpin a credential in the wallet.
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

// GET /mobile/getActivity?emiratesID=XXX — the holder's activity feed.
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
			"credentialID":   a.CredentialID,
			"credentialName": a.CredentialType,
			"actor":          a.ActorName,
			"timestamp":      a.CreatedAt.Format(time.RFC3339),
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"success": true, "activity": out})
}

// handleGetMobileSubscriptions returns subscription requests addressed to a
// holder for the QWallet ManageSubscriptions screen.
// GET /mobile/getSubscriptions?emiratesID=XXX
func handleGetMobileSubscriptions(w http.ResponseWriter, r *http.Request) {
	emiratesID := r.URL.Query().Get("emiratesID")
	if emiratesID == "" {
		writeError(w, http.StatusBadRequest, "emiratesID is required")
		return
	}
	subs, err := getMobileSubscriptions(emiratesID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	out := make([]map[string]any, 0, len(subs))
	for _, s := range subs {
		out = append(out, map[string]any{
			"subscriptionID": s.SubscriptionID,
			"credentialID":   s.CredentialID,
			"credentialType": s.CredentialType,
			"verifierName":   s.VerifierName,
			"status":         s.Status,
			"createdAt":      s.CreatedAt,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"success":       true,
		"subscriptions": out,
	})
}

// handleApproveSubscription approves a pending subscription (status -> active).
// POST /mobile/approveSubscription  Body: { subscriptionID, emiratesID }
func handleApproveSubscription(w http.ResponseWriter, r *http.Request) {
	var body struct {
		SubscriptionID string `json:"subscriptionID"`
		EmiratesID     string `json:"emiratesID"`
	}
	if err := decodeBody(r, &body); err != nil || body.SubscriptionID == "" || body.EmiratesID == "" {
		writeError(w, http.StatusBadRequest, "subscriptionID and emiratesID are required")
		return
	}
	ok, err := updateSubscriptionStatus(body.SubscriptionID, body.EmiratesID, "active")
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"success": ok})
}

// handleRejectSubscription rejects a pending subscription (status -> rejected).
// POST /mobile/rejectSubscription  Body: { subscriptionID, emiratesID }
func handleRejectSubscription(w http.ResponseWriter, r *http.Request) {
	var body struct {
		SubscriptionID string `json:"subscriptionID"`
		EmiratesID     string `json:"emiratesID"`
	}
	if err := decodeBody(r, &body); err != nil || body.SubscriptionID == "" || body.EmiratesID == "" {
		writeError(w, http.StatusBadRequest, "subscriptionID and emiratesID are required")
		return
	}
	ok, err := updateSubscriptionStatus(body.SubscriptionID, body.EmiratesID, "rejected")
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"success": ok})
}

// POST /mobile/generateOTP — create a short-lived 6-digit OTP session for manual verify.
func handleGenerateOTP(w http.ResponseWriter, r *http.Request) {
	var req struct {
		CredentialID     string   `json:"credentialID"`
		HiddenFields     []string `json:"hiddenFields"`
		DisclosedPayload string   `json:"disclosedPayload"`
		HolderSignature  string   `json:"holderSignature"`
	}
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	if req.CredentialID == "" {
		writeError(w, http.StatusBadRequest, "missing credentialID")
		return
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

	const sessionExpiresInSeconds = 120
	if err := insertMobileSession(otpID, "otp", req.CredentialID, holderID, req.HiddenFields, req.DisclosedPayload, req.HolderSignature, sessionExpiresInSeconds); err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	expiresAt := time.Now().In(mustLoadLocation("Asia/Dubai")).Add(time.Duration(sessionExpiresInSeconds) * time.Second)
	writeJSON(w, http.StatusOK, map[string]any{
		"success":   true,
		"otp":       otpID[4:],
		"expiresAt": expiresAt.Format("2006-01-02T15:04:05"),
	})
}

// POST /mobile/generatePresentation — create a short-lived QR session ("PRES-...").
func handleGeneratePresentation(w http.ResponseWriter, r *http.Request) {
	var req struct {
		CredentialID     string   `json:"credentialID"`
		HiddenFields     []string `json:"hiddenFields"`
		DisclosedPayload string   `json:"disclosedPayload"`
		HolderSignature  string   `json:"holderSignature"`
	}
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	if req.CredentialID == "" {
		writeError(w, http.StatusBadRequest, "missing credentialID")
		return
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

	const sessionExpiresInSeconds = 120
	if err := insertMobileSession(presID, "qr", req.CredentialID, holderID, req.HiddenFields, req.DisclosedPayload, req.HolderSignature, sessionExpiresInSeconds); err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	expiresAt := time.Now().In(mustLoadLocation("Asia/Dubai")).Add(time.Duration(sessionExpiresInSeconds) * time.Second)
	writeJSON(w, http.StatusOK, map[string]any{
		"success":        true,
		"presentationID": presID,
		"expiresAt":      expiresAt.Format("2006-01-02T15:04:05"),
	})
}

// GET /mobile/getCatalog — the issuer/service catalog, grouped category → issuer → service.
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

// POST /mobile/fetchDocument — pull all of a holder's credentials matching an
// issuer/service into the wallet (sets in_wallet=1). See fetchDocumentInDB.
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

	found, alreadyInWallet, err := fetchDocumentInDB(req.HolderEID, req.IssuerID, req.ServiceName)
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
	if alreadyInWallet {
		writeJSON(w, http.StatusOK, map[string]any{
			"success":         false,
			"alreadyInWallet": true,
			"message":         "This document is already in your wallet.",
		})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"success":         true,
		"alreadyInWallet": false,
		"message":         "Document retrieved successfully.",
	})
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

	// Track H: If disclosedPayload was provided in the session, parse disclosedFields
	var disclosedFields map[string]any
	if session.DisclosedPayload != "" {
		var disclosedPayload map[string]any
		if err := json.Unmarshal([]byte(session.DisclosedPayload), &disclosedPayload); err == nil {
			if df, ok := disclosedPayload["disclosedFields"].(map[string]any); ok {
				disclosedFields = df
			}
		}
	}
	if len(disclosedFields) > 0 {
		credData = disclosedFields
	} else {
		applySelectiveDisclosure(credData, session.HiddenFields)
	}

	expiryDate = ""
	if credData != nil {
		if v, ok := credData["expiryDate"].(string); ok {
			expiryDate = v
		}
	}

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
			"checks": map[string]bool{
				"existsOnChain":        true,
				"notRevoked":           false,
				"signatureValid":       false,
				"fieldHashesValid":     false,
				"holderSignatureValid": false,
				"hashMatches":          false,
			},
		})
		return
	}

	// --- ISSUER SIGNATURE CHECK (unchanged) ---
	credHash, _ := cred["CredentialHash"].(string)
	signature, _ := cred["Signature"].(string)
	publicKey, _ := cred["PublicKey"].(string)
	sigValid, _ := pqcVerify(credHash, signature, publicKey)

	// --- FIELD HASHES CHECK (REPLACES the old hashMatches) ---
	// Old code: recomputed := sha3Hex(credInfoStr); hashMatches := recomputed == credHash
	// That re-hashed the plaintext Info field — impossible once Info is encrypted/removed.
	// New code: verify each DISCLOSED field's hash against the on-chain FieldHashes map.
	fieldHashesStr, _ := cred["FieldHashes"].(string)
	var fieldHashes map[string]string
	if fieldHashesStr != "" {
		_ = json.Unmarshal([]byte(fieldHashesStr), &fieldHashes)
	}

	legacyHashMatches := false
	if credInfoStr != "" {
		recomputed := sha3Hex(credInfoStr)
		legacyHashMatches = strings.EqualFold(recomputed, credHash)
	}

	fieldHashesValid := true
	if len(fieldHashes) == 0 {
		// Legacy credential without FieldHashes — fall back to old hashMatches for A/B period.
		fieldHashesValid = legacyHashMatches
	} else {
		// Parse the disclosedPayload the holder signed (stored on the session row).
		if len(disclosedFields) == 0 {
			fieldHashesValid = false
		} else {
			for field, value := range disclosedFields {
				expectedHash, exists := fieldHashes[field]
				if !exists {
					fieldHashesValid = false
					break
				}
				computed := sha3Hex(field + ":" + fmt.Sprintf("%v", value))
				if !strings.EqualFold(computed, expectedHash) {
					fieldHashesValid = false
					break
				}
			}
		}
	}

	// --- HOLDER SIGNATURE CHECK (NEW — 5th check) ---
	// Fetch the holder's DSA public key from the DB (NOT from the request).
	var holderDsaPub string
	_ = db.QueryRow(
		`SELECT dsa_public_key FROM holders WHERE holder_id = ?`,
		session.HolderID,
	).Scan(&holderDsaPub)

	holderSigValid := false
	if holderDsaPub != "" && session.DisclosedPayload != "" && session.HolderSignature != "" {
		payloadHash := sha3Hex(session.DisclosedPayload)
		holderSigValid, _ = pqcVerify(payloadHash, session.HolderSignature, holderDsaPub)
	}

	// --- FINAL VERDICT ---
	verified := notRevoked && sigValid && fieldHashesValid && holderSigValid

	result := "success"
	failureReason := ""
	if !verified {
		result = "failure"
		if !sigValid {
			failureReason = "signature_invalid"
		} else if !fieldHashesValid {
			failureReason = "field_hashes_invalid"
		} else if !holderSigValid {
			failureReason = "holder_signature_invalid"
		}
	}
	logVerificationToDB(session.CredentialID, fabricCredID, "VER-UOS-0001", resolveVerifiedBy,
		result, failureReason, true, fieldHashesValid, sigValid, notRevoked, status)
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
			"existsOnChain":        true,
			"notRevoked":           notRevoked,
			"signatureValid":       sigValid,
			"fieldHashesValid":     fieldHashesValid,
			"holderSignatureValid": holderSigValid,
			"hashMatches":          legacyHashMatches,
		},
	})
}

// applySelectiveDisclosure blanks (sets to nil) any fields the holder chose to
// hide. Supports dotted paths like "parent.child" for one level of nesting.
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
