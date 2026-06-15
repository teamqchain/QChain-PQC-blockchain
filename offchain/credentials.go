package main

// credentials.go — HTTP handlers for the credential lifecycle.
//
// Covers: register a holder, issue a credential (sign + IPFS + commit to Fabric),
// revoke / suspend / restore, admin CID correction, update metadata, and the
// read endpoints that list a holder's credentials or page through all of them.
//
// Data access (MySQL) lives in db_credentials.go / db_holders.go; the crypto is
// in crypto.go; the Fabric connection is in fabric.go. This file is the "glue"
// that wires an HTTP request to those pieces.

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"
)

// ─────────────────────────────────────────────
//  REQUEST TYPES (JSON bodies the frontend POSTs)
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

// ─────────────────────────────────────────────
//  WRITE HANDLERS
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

	// Raise an alert for any verifier subscribed to this credential.
	if hasSub, _ := activeSubscriptionExists(req.CredentialID); hasSub {
		if cred, err := getCredentialDetail(req.CredentialID); err == nil {
			insertAlertForCredential(req.CredentialID, cred.CredentialType, cred.HolderID, cred.HolderName,
				"revoked", "Credential has been revoked.")
		}
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
	// Raise an alert for any verifier subscribed to this credential, so the
	// status change surfaces on the verifier's Alerts page / dashboard.
	if hasSub, _ := activeSubscriptionExists(req.CredentialID); hasSub {
		if cred, err := getCredentialDetail(req.CredentialID); err == nil {
			insertAlertForCredential(req.CredentialID, cred.CredentialType, cred.HolderID, cred.HolderName,
				"suspended", fmt.Sprintf("Credential has been suspended. Reason: %s", req.Reason))
		}
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

// POST /updateCredential — edit holder email and/or expiry on a non-revoked credential.
func handleUpdateCredential(w http.ResponseWriter, r *http.Request) {
	// *string (pointer to string) lets us tell "field omitted" (nil) apart from
	// "field set to empty string" — important because "" clears the expiry.
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

// ─────────────────────────────────────────────
//  READ HANDLERS
// ─────────────────────────────────────────────

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

// ─────────────────────────────────────────────
//  SHARED CREDENTIAL HELPERS
// ─────────────────────────────────────────────

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

// validCredentialStatus reports whether s is one of the known status filters.
func validCredentialStatus(s string) bool {
	switch s {
	case "active", "revoked", "suspended", "expired":
		return true
	}
	return false
}
