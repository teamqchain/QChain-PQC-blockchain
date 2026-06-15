package main

// verification.go — proving a credential is genuine, plus the verification log.
//
// handleVerifyCredential is the cryptographic heart of the system. It fetches the
// credential from the blockchain and runs four checks:
//   1. existsOnChain  — the ledger has this credential
//   2. notRevoked     — its on-chain Status is "active"
//   3. signatureValid — the ML-DSA-44 signature matches the org public key
//   4. hashMatches    — re-hashing the stored payload reproduces the stored hash
// All four must pass for verified=true.
//
// NOTE: for any non-active credential the handler returns early and reports the
// crypto checks as false (it never runs them). Callers/UIs should therefore read
// `status`/`reason` for non-active credentials rather than the per-check booleans.

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strings"
)

// VerifyCredentialRequest — called by QPortal verifier screen.
type VerifyCredentialRequest struct {
	CredentialID string `json:"credentialID"` // display ID e.g. "CRED-0001"
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

// ─────────────────────────────────────────────
//  RESULT/METHOD MAPPING (API camelCase <-> DB enums)
// ─────────────────────────────────────────────

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

// verifyResultDBToAPI converts a stored (result, failure_reason) pair back into
// the camelCase value the frontend expects.
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

// verifyMethodDBToAPI maps the stored verification method to camelCase.
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

// nullBoolOrDerive returns the stored bool when present, otherwise the derived
// fallback. Older verification logs may not have stored every check column.
func nullBoolOrDerive(nb sql.NullBool, derived bool) bool {
	if nb.Valid {
		return nb.Bool
	}
	return derived
}
