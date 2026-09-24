package main

// db_mobile.go — MySQL access for the QWallet features: OTP/QR `mobile_sessions`,
// the issuer/service `catalog_*` tables, the holder's in-wallet credential refs
// and activity feed, the favourite toggle, and the fetchDocument helpers (the
// credential-type match itself runs in Go on the on-chain type).

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"time"
)

// ─── MOBILE SESSIONS ─────────────────────────────────────────────────────────

// MobileSessionRow is one OTP/QR presentation session. HiddenFields lists the
// credential attributes the holder chose not to disclose. DisclosedPayload and
// HolderSignature store the phone's signed presentation (Track H).
type MobileSessionRow struct {
	ID               string
	SessionType      string
	CredentialID     string
	HolderID         string
	HiddenFields     []string
	DisclosedPayload string
	HolderSignature  string
	ExpiresAt        time.Time
}

// insertMobileSession stores a new OTP/QR session that expires after expiresInSeconds.
func insertMobileSession(id, sessionType, credentialID, holderID string, hiddenFields []string, disclosedPayload, holderSignature string, expiresInSeconds int) error {
	if db == nil {
		return fmt.Errorf("database not configured")
	}
	var hiddenJSON []byte
	if len(hiddenFields) > 0 {
		var err error
		hiddenJSON, err = json.Marshal(hiddenFields)
		if err != nil {
			return err
		}
	}
	var payloadVal any = nil
	if disclosedPayload != "" {
		payloadVal = disclosedPayload
	}
	var sigVal any = nil
	if holderSignature != "" {
		sigVal = holderSignature
	}
	_, err := db.Exec(`
		INSERT INTO mobile_sessions (id, session_type, credential_id, holder_id, hidden_fields, disclosed_payload, holder_signature, expires_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? SECOND))`,
		id, sessionType, credentialID, holderID, hiddenJSON, payloadVal, sigVal, expiresInSeconds,
	)
	return err
}

// getMobileSession fetches a session by token, decoding its hidden-fields JSON, disclosed_payload, and holder_signature.
func getMobileSession(id string) (MobileSessionRow, error) {
	var r MobileSessionRow
	if db == nil {
		return r, fmt.Errorf("database not configured")
	}
	var hiddenJSON, payloadVal, sigVal sql.NullString
	err := db.QueryRow(`
		SELECT id, session_type, credential_id, holder_id, hidden_fields, disclosed_payload, holder_signature, expires_at
		  FROM mobile_sessions WHERE id = ? LIMIT 1`, id).Scan(
		&r.ID, &r.SessionType, &r.CredentialID, &r.HolderID, &hiddenJSON, &payloadVal, &sigVal, &r.ExpiresAt,
	)
	if err == sql.ErrNoRows {
		return r, sql.ErrNoRows
	}
	if err != nil {
		return r, err
	}
	if hiddenJSON.Valid && hiddenJSON.String != "" {
		_ = json.Unmarshal([]byte(hiddenJSON.String), &r.HiddenFields)
	}
	if payloadVal.Valid {
		r.DisclosedPayload = payloadVal.String
	}
	if sigVal.Valid {
		r.HolderSignature = sigVal.String
	}
	return r, nil
}

// deleteMobileSession removes a session (called after it is redeemed). Non-fatal on error.
func deleteMobileSession(id string) {
	if db == nil {
		return
	}
	if _, err := db.Exec(`DELETE FROM mobile_sessions WHERE id = ?`, id); err != nil {
		log.Printf("deleteMobileSession error: %v", err)
	}
}

// mobileSessionExists reports whether a session token is already in use (for uniqueness checks).
func mobileSessionExists(id string) bool {
	if db == nil {
		return false
	}
	var count int
	_ = db.QueryRow(`SELECT COUNT(*) FROM mobile_sessions WHERE id = ?`, id).Scan(&count)
	return count > 0
}

// ─── CATALOG ─────────────────────────────────────────────────────────────────

// CatalogIssuerRow is one issuer×service row (service columns are NULL for an
// issuer with no services). getCatalogRows returns the flattened join; the
// handler groups it into category → issuer → service.
type CatalogIssuerRow struct {
	IssuerID    string
	Category    string
	IssuerName  string
	ServiceID   sql.NullString
	ServiceName sql.NullString
	Description sql.NullString
}

// getCatalogRows returns active issuers left-joined with their services.
func getCatalogRows() ([]CatalogIssuerRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(`
		SELECT i.id AS issuer_id, i.category, i.name AS issuer_name,
		       s.id AS service_id, s.name AS service_name, s.description
		  FROM catalog_issuers i
		  LEFT JOIN catalog_services s ON i.id = s.issuer_id
		 WHERE i.is_active = 1
		 ORDER BY i.category ASC, i.name ASC, s.name ASC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []CatalogIssuerRow{}
	for rows.Next() {
		var r CatalogIssuerRow
		if err := rows.Scan(&r.IssuerID, &r.Category, &r.IssuerName,
			&r.ServiceID, &r.ServiceName, &r.Description); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// ─── MOBILE CREDENTIAL QUERIES ───────────────────────────────────────────────

// MobileCredentialRef is the MySQL-only side of a wallet credential. Type,
// status, dates, holder name and CID come from the chain (see mobile.go).
// IssuerName is the organisation name (catalog_issuers), not a staff member.
type MobileCredentialRef struct {
	CredentialID string
	FabricCredID string
	IsFavorite   bool
	Category     string
	IssuerName   string
	HolderEID    string
}

// getMobileCredentialRefs returns the holder's in-wallet credentials.
func getMobileCredentialRefs(emiratesID string) ([]MobileCredentialRef, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(`
		SELECT c.credential_id, c.fabric_cred_id, c.is_favorite, c.category,
		       COALESCE(org.name, 'Unknown Organization') AS issuer_name,
		       h.emirates_id
		  FROM credentials c
		  JOIN holders h ON c.holder_id = h.holder_id
		  LEFT JOIN catalog_issuers org ON c.org_id = org.id
		 WHERE h.emirates_id = ?
		   AND c.in_wallet = 1`, emiratesID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []MobileCredentialRef{}
	for rows.Next() {
		var r MobileCredentialRef
		var isFav int
		if err := rows.Scan(&r.CredentialID, &r.FabricCredID, &isFav, &r.Category, &r.IssuerName, &r.HolderEID); err != nil {
			return nil, err
		}
		r.IsFavorite = isFav == 1
		out = append(out, r)
	}
	return out, rows.Err()
}

// toggleFavorite flips the is_favorite flag for a credential owned by holderEID.
// Returns sql.ErrNoRows when no matching credential exists for that holder.
func toggleFavorite(credentialID, holderEID string) error {
	if db == nil {
		return fmt.Errorf("database not configured")
	}
	result, err := db.Exec(`
		UPDATE credentials c
		  JOIN holders h ON c.holder_id = h.holder_id
		   SET c.is_favorite = NOT c.is_favorite
		 WHERE c.credential_id = ? AND h.emirates_id = ?`,
		credentialID, holderEID,
	)
	if err != nil {
		return err
	}
	n, _ := result.RowsAffected()
	if n == 0 {
		return sql.ErrNoRows
	}
	return nil
}

// MobileActivityRow is one entry in the wallet activity feed. The credential
// name comes from the chain via FabricCredID.
type MobileActivityRow struct {
	EventID      int64
	EventType    string
	CredentialID string
	FabricCredID string
	ActorName    string
	CreatedAt    time.Time
}

// getMobileActivity returns up to 100 recent credential events for a holder.
func getMobileActivity(emiratesID string) ([]MobileActivityRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(`
		SELECT ce.event_id, ce.event_type, ce.credential_id,
		       c.fabric_cred_id,
		       COALESCE(ce.actor_name, '') AS actor_name,
		       ce.created_at
		  FROM credential_events ce
		  JOIN credentials c ON ce.credential_id = c.credential_id
		  JOIN holders h ON c.holder_id = h.holder_id
		 WHERE h.emirates_id = ?
		 ORDER BY ce.created_at DESC
		 LIMIT 100`, emiratesID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []MobileActivityRow{}
	for rows.Next() {
		var r MobileActivityRow
		if err := rows.Scan(&r.EventID, &r.EventType, &r.CredentialID, &r.FabricCredID, &r.ActorName, &r.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// serviceMatchPattern returns the catalog service's match_pattern: a SQL LIKE
// pattern matched against the credential type. The service name is a friendly
// label ("Bachelor Degree") that won't substring-match a specific credential
// type ("Bachelor of Science in Computer Science"), so the pattern is used;
// without one, the service name itself is matched as a substring.
func serviceMatchPattern(issuerID, serviceName string) string {
	var pattern string
	if db != nil {
		_ = db.QueryRow(`SELECT match_pattern FROM catalog_services WHERE issuer_id = ? AND name = ? LIMIT 1`,
			issuerID, serviceName).Scan(&pattern)
	}
	if pattern == "" {
		pattern = "%" + serviceName + "%"
	}
	return pattern
}

// WalletCandidateRef is one of a holder's credentials from a given organisation.
type WalletCandidateRef struct {
	CredentialID string
	FabricCredID string
	InWallet     bool
}

// holderCredentialRefsForOrg lists a holder's credentials issued by staff of
// the given catalog organisation.
func holderCredentialRefsForOrg(holderEID, issuerID string) ([]WalletCandidateRef, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(`
		SELECT c.credential_id, c.fabric_cred_id, c.in_wallet
		  FROM credentials c
		  JOIN holders h ON c.holder_id = h.holder_id
		  JOIN issuers iss ON c.issuer_id = iss.issuer_id
		 WHERE h.emirates_id = ?
		   AND iss.org_id = ?`,
		holderEID, issuerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []WalletCandidateRef{}
	for rows.Next() {
		var r WalletCandidateRef
		var inWallet int
		if err := rows.Scan(&r.CredentialID, &r.FabricCredID, &inWallet); err != nil {
			return nil, err
		}
		r.InWallet = inWallet == 1
		out = append(out, r)
	}
	return out, rows.Err()
}

// markInWallet sets in_wallet=1 for the given display credential IDs.
func markInWallet(credentialIDs []string) error {
	if db == nil {
		return fmt.Errorf("database not configured")
	}
	for _, id := range credentialIDs {
		if _, err := db.Exec(`UPDATE credentials SET in_wallet = 1 WHERE credential_id = ?`, id); err != nil {
			return err
		}
	}
	return nil
}
