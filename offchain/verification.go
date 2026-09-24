package main

// verification.go — proving a presented credential is genuine, plus the
// verification-log endpoints.
//
// verifyPresentation is the cryptographic heart of the system. Given the
// on-chain credential and holder records and the holder's signed presentation,
// it runs the checks the portal shows:
//   1. existsOnChain        — the ledger has this credential
//   2. notRevoked           — its stored status is "active" (not revoked/suspended)
//   3. signatureValid       — the credential's issuer key is the trusted key from
//                             .env, and its ML-DSA-44 signature verifies over the
//                             commitment RECOMPUTED from the on-chain fields
//   4. fieldHashesValid     — every disclosed value, with its salt, hashes to its
//                             on-chain field hash
//   5. holderSignatureValid — the presentation names this credential and is
//                             signed with the holder's on-chain ML-DSA-44 key
// plus hashMatches (the stored CredentialHash equals the recomputed one) and
// the expiry date. It does no I/O, so it is unit-tested directly
// (verification_test.go); handleResolveSession (mobile.go) supplies the inputs.

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"
)

// Failure reasons: returned as `reason` by /resolveSession and stored in
// verification_logs.failure_reason. The portal maps each of them.
const (
	reasonNotFound               = "NOT_FOUND"
	reasonRevoked                = "REVOKED"
	reasonSuspended              = "SUSPENDED"
	reasonExpired                = "EXPIRED"
	reasonSignatureInvalid       = "SIGNATURE_INVALID"
	reasonHashMismatch           = "HASH_MISMATCH"
	reasonFieldHashesInvalid     = "FIELD_HASHES_INVALID"
	reasonHolderSignatureInvalid = "HOLDER_SIGNATURE_INVALID"
)

// DisclosedPayload is the presentation the holder's wallet signs:
// {"credentialID","disclosedFields":{key:value},"salts":{key:salt},"timestamp"}.
type DisclosedPayload struct {
	CredentialID    string
	DisclosedFields map[string]string
	Salts           map[string]string
	Timestamp       string
}

// stringMap decodes a JSON object whose values must all be strings.
func stringMap(name string, raw map[string]json.RawMessage) (map[string]string, error) {
	out := make(map[string]string, len(raw))
	for _, key := range sortedKeys(raw) {
		var v string
		if err := json.Unmarshal(raw[key], &v); err != nil || bytes.Equal(bytes.TrimSpace(raw[key]), []byte("null")) {
			return nil, fmt.Errorf("%s[%q] must be a string", name, key)
		}
		out[key] = v
	}
	return out, nil
}

// parseDisclosedPayload parses a signed presentation. Values in
// disclosedFields and salts must be strings (every issued value is one).
func parseDisclosedPayload(raw string) (DisclosedPayload, error) {
	var loose struct {
		CredentialID    string                     `json:"credentialID"`
		DisclosedFields map[string]json.RawMessage `json:"disclosedFields"`
		Salts           map[string]json.RawMessage `json:"salts"`
		Timestamp       string                     `json:"timestamp"`
	}
	if err := json.Unmarshal([]byte(raw), &loose); err != nil {
		return DisclosedPayload{}, fmt.Errorf("invalid JSON in disclosedPayload: %v", err)
	}
	fields, err := stringMap("disclosedFields", loose.DisclosedFields)
	if err != nil {
		return DisclosedPayload{}, err
	}
	salts, err := stringMap("salts", loose.Salts)
	if err != nil {
		return DisclosedPayload{}, err
	}
	return DisclosedPayload{
		CredentialID:    loose.CredentialID,
		DisclosedFields: fields,
		Salts:           salts,
		Timestamp:       loose.Timestamp,
	}, nil
}

// VerifyInput is everything verifyPresentation needs, already fetched.
type VerifyInput struct {
	DisplayID        string           // credential ID the session was created for (CRED-0001)
	FabricID         string           // its on-chain key
	Cred             *ChainCredential // nil when the credential is not on-chain
	Holder           *ChainHolder     // the credential's on-chain holder (full view)
	RawPayload       string           // disclosedPayload exactly as the wallet signed it
	HolderSignature  string           // hex ML-DSA-44 signature over sha3Hex(RawPayload)
	TrustedIssuerKey string           // ISSUER_PUBLIC_KEY_HEX from .env
	Now              time.Time
}

// VerifyOutcome is the result of every check plus the overall verdict.
type VerifyOutcome struct {
	Verified             bool
	Reason               string // "" when verified
	Status               string // effective status (active/revoked/suspended/expired)
	ExistsOnChain        bool
	NotRevoked           bool
	SignatureValid       bool
	HashMatches          bool
	FieldHashesValid     bool
	HolderSignatureValid bool
	Disclosed            map[string]string // disclosed fields (no salts); nil if unparseable
}

// verifyPresentation runs every check. All checks run even after one fails,
// so the portal can show each result; Reason reports the most important
// failure: NOT_FOUND > REVOKED > SUSPENDED > EXPIRED > SIGNATURE_INVALID >
// HASH_MISMATCH > FIELD_HASHES_INVALID > HOLDER_SIGNATURE_INVALID.
func verifyPresentation(in VerifyInput) VerifyOutcome {
	var out VerifyOutcome
	payload, payloadErr := parseDisclosedPayload(in.RawPayload)
	if payloadErr == nil {
		out.Disclosed = payload.DisclosedFields
	}
	if in.Cred == nil {
		out.Reason = reasonNotFound
		return out
	}
	cred := in.Cred
	out.ExistsOnChain = true
	out.Status = effectiveStatus(cred, in.Now)
	out.NotRevoked = cred.Status == "active"

	// Issuer signature over the commitment rebuilt from the chain — never the
	// stored hash — and only from the trusted issuer key.
	if hash, err := commitmentHash(commitmentFromChain(cred)); err == nil {
		out.HashMatches = hash == cred.CredentialHash
		if in.TrustedIssuerKey != "" && strings.EqualFold(cred.PublicKey, in.TrustedIssuerKey) {
			out.SignatureValid, _ = pqcVerify(hash, cred.Signature, cred.PublicKey)
		}
	}

	if payloadErr == nil {
		out.FieldHashesValid = verifyDisclosedFields(payload.DisclosedFields, payload.Salts, cred.FieldHashes) == nil

		payloadID := strings.TrimSpace(payload.CredentialID)
		boundToCredential := payloadID != "" && (payloadID == in.DisplayID || payloadID == in.FabricID)
		if boundToCredential && in.Holder != nil && in.Holder.DsaPublicKey != "" && in.HolderSignature != "" {
			out.HolderSignatureValid, _ = pqcVerify(sha3Hex(in.RawPayload), in.HolderSignature, in.Holder.DsaPublicKey)
		}
	}

	switch {
	case out.Status == "revoked":
		out.Reason = reasonRevoked
	case out.Status == "suspended":
		out.Reason = reasonSuspended
	case out.Status == "expired":
		out.Reason = reasonExpired
	case !out.SignatureValid:
		out.Reason = reasonSignatureInvalid
	case !out.HashMatches:
		out.Reason = reasonHashMismatch
	case !out.FieldHashesValid:
		out.Reason = reasonFieldHashesInvalid
	case !out.HolderSignatureValid:
		out.Reason = reasonHolderSignatureInvalid
	}
	out.Verified = out.Reason == ""
	return out
}

// presentationRequest is the body of /mobile/generateOTP and
// /mobile/generatePresentation.
type presentationRequest struct {
	CredentialID     string   `json:"credentialID"`
	HiddenFields     []string `json:"hiddenFields"`
	DisclosedPayload string   `json:"disclosedPayload"`
	HolderSignature  string   `json:"holderSignature"`
}

// validatePresentationRequest decodes and checks a presentation request before
// any database access. The returned error text is sent to the wallet as-is.
func validatePresentationRequest(r *http.Request) (presentationRequest, error) {
	var req presentationRequest
	if err := decodeBody(r, &req); err != nil {
		return req, errors.New("invalid JSON")
	}
	req.CredentialID = strings.TrimSpace(req.CredentialID)
	if req.CredentialID == "" {
		return req, errors.New("missing credentialID")
	}
	if strings.TrimSpace(req.DisclosedPayload) == "" {
		return req, errors.New("missing disclosedPayload")
	}
	if strings.TrimSpace(req.HolderSignature) == "" {
		return req, errors.New("missing holderSignature")
	}
	payload, err := parseDisclosedPayload(req.DisclosedPayload)
	if err != nil {
		return req, err
	}
	payloadCredID := strings.TrimSpace(payload.CredentialID)
	if payloadCredID == "" {
		return req, errors.New("disclosedPayload missing credentialID")
	}
	if payloadCredID != req.CredentialID {
		return req, fmt.Errorf("disclosedPayload credentialID %q does not match request credentialID %q", payloadCredID, req.CredentialID)
	}
	if err := validateDisclosureSalts(payload.DisclosedFields, payload.Salts); err != nil {
		return req, err
	}
	return req, nil
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

	// Credential type and holder name come from the chain. A log row for a
	// credential that is not on-chain (e.g. a NOT_FOUND attempt) keeps empty labels.
	fabricIDs := make([]string, 0, len(rows))
	for _, r := range rows {
		fabricIDs = append(fabricIDs, r.FabricCredID)
	}
	snap, err := chainReadCredentials(fabricIDs, viewSummary)
	if err != nil {
		writeError(w, http.StatusBadGateway, "blockchain read failed: "+err.Error())
		return
	}

	out := make([]map[string]any, 0, len(rows))
	for _, r := range rows {
		credentialType, holderName := credentialLabel(snap, r.FabricCredID)
		out = append(out, map[string]any{
			"id":             r.LogID,
			"verifiedAt":     r.VerifiedAt.Format("2006-01-02T15:04:05"),
			"credentialType": credentialType,
			"credentialID":   r.CredentialID,
			"holderName":     holderName,
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
	// notRevoked is not stored as its own column; derive it from the status
	// recorded at verification time ("expired" credentials are not revoked).
	notRevoked := mappedResult == "valid" || mappedResult == "expired"
	if vd.StatusAtVerify.Valid && vd.StatusAtVerify.String != "" {
		st := strings.ToLower(vd.StatusAtVerify.String)
		notRevoked = st == "active" || st == "expired"
	}
	sigValid := nullBoolOrDerive(vd.SigVerified, mappedResult != "tampered")
	hashMatches := nullBoolOrDerive(vd.HashVerified, mappedResult != "tampered")

	// Credential type, holder and dates come from the chain.
	var credentialType, holderName, holderID string
	var issuedAt, expiry any
	if vd.FabricCredID != "" {
		cred, holder, err := chainReadCredential(vd.FabricCredID, viewSummary)
		switch {
		case err == nil:
			credentialType = cred.CredentialType
			holderName = holder.FullName()
			holderID = cred.Holder
			if t, ok := formatChainTime(cred.IssuedAt); ok {
				issuedAt = FormatISO(t)
			}
			expiry = expiryOrNil(cred.ExpiryDate)
		case !errors.Is(err, errChainNotFound):
			writeError(w, http.StatusBadGateway, "blockchain read failed: "+err.Error())
			return
		}
	}
	var reason any
	if vd.FailureReason.Valid && vd.FailureReason.String != "" {
		reason = vd.FailureReason.String
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"id":             vd.LogID,
		"verifiedAt":     FormatISO(vd.VerifiedAt),
		"credentialID":   vd.CredentialID,
		"credentialType": credentialType,
		"holderName":     holderName,
		"holderID":       holderID,
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
	case "SIGNATURE_INVALID", "HASH_MISMATCH", "FIELD_HASHES_INVALID", "HOLDER_SIGNATURE_INVALID", "TAMPERED":
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
