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
	"encoding/json"
	"fmt"
	"math/big"
	"net/http"
	"strconv"
	"strings"
	"time"
)

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
		var attrs map[string]any
		_ = json.Unmarshal([]byte(c.CredentialData), &attrs)
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
	expiresAt := time.Now().Add(time.Duration(req.ExpiresIn) * time.Second)
	writeJSON(w, http.StatusOK, map[string]any{
		"success":   true,
		"otp":       otpID[4:],
		"expiresAt": expiresAt.Format(time.RFC3339),
	})
}

// POST /mobile/generatePresentation — create a short-lived QR session ("PRES-...").
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
	expiresAt := time.Now().Add(time.Duration(req.ExpiresIn) * time.Second)
	writeJSON(w, http.StatusOK, map[string]any{
		"success":        true,
		"presentationID": presID,
		"expiresAt":      expiresAt.Format(time.RFC3339),
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
