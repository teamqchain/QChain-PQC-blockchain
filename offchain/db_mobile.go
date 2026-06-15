package main

// db_mobile.go — MySQL access for the QWallet features: OTP/QR `mobile_sessions`,
// the issuer/service `catalog_*` tables, the holder's in-wallet credential list
// and activity feed, the favourite toggle, and fetchDocument (which pulls
// matching credentials into the wallet).

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"time"
)

// ─── MOBILE SESSIONS ─────────────────────────────────────────────────────────

// MobileSessionRow is one OTP/QR presentation session. HiddenFields lists the
// credential attributes the holder chose not to disclose.
type MobileSessionRow struct {
	ID           string
	SessionType  string
	CredentialID string
	HolderID     string
	HiddenFields []string
	ExpiresAt    time.Time
}

// insertMobileSession stores a new OTP/QR session that expires after expiresInSeconds.
func insertMobileSession(id, sessionType, credentialID, holderID string, hiddenFields []string, expiresInSeconds int) error {
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
	_, err := db.Exec(`
		INSERT INTO mobile_sessions (id, session_type, credential_id, holder_id, hidden_fields, expires_at)
		VALUES (?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? SECOND))`,
		id, sessionType, credentialID, holderID, hiddenJSON, expiresInSeconds,
	)
	return err
}

// getMobileSession fetches a session by token, decoding its hidden-fields JSON.
func getMobileSession(id string) (MobileSessionRow, error) {
	var r MobileSessionRow
	if db == nil {
		return r, fmt.Errorf("database not configured")
	}
	var hiddenJSON sql.NullString
	err := db.QueryRow(`
		SELECT id, session_type, credential_id, holder_id, hidden_fields, expires_at
		  FROM mobile_sessions WHERE id = ? LIMIT 1`, id).Scan(
		&r.ID, &r.SessionType, &r.CredentialID, &r.HolderID, &hiddenJSON, &r.ExpiresAt,
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

// MobileCredentialRow is the wallet projection. issuedBy is the organisation name
// (catalog_issuers), not the staff member who issued it.
type MobileCredentialRow struct {
	CredentialID   string
	CredentialType string
	IssuedAt       time.Time
	ExpiryDate     sql.NullTime
	Status         string
	IsFavorite     bool
	Category       string
	CredentialData string
	Signature      string
	FabricCredID   string
	IPFSCID        string
	PublicKey      string
	IssuerName     string
	HolderName     string
	HolderEID      string
}

// getMobileCredentials returns the in-wallet credentials for a holder (newest first).
func getMobileCredentials(emiratesID string) ([]MobileCredentialRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(`
		SELECT c.credential_id, c.credential_type, c.issued_at, c.expiry_date,
		       c.status, c.is_favorite, c.category,
		       COALESCE(c.credential_data, '{}') AS credential_data,
		       COALESCE(c.issuer_signature, '') AS signature,
		       COALESCE(c.fabric_cred_id, '') AS fabric_cred_id,
		       COALESCE(c.ipfs_cid, '') AS ipfs_cid,
		       COALESCE(c.issuer_public_key, '') AS public_key,
		       COALESCE(org.name, 'Unknown Organization') AS issuer_name,
		       CONCAT_WS(' ', h.first_name, h.last_name) AS holder_name,
		       h.emirates_id
		  FROM credentials c
		  JOIN holders h ON c.holder_id = h.holder_id
		  LEFT JOIN catalog_issuers org ON c.org_id = org.id
		 WHERE h.emirates_id = ?
		   AND c.in_wallet = 1
		 ORDER BY c.issued_at DESC`, emiratesID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []MobileCredentialRow{}
	for rows.Next() {
		var r MobileCredentialRow
		var isFav int
		if err := rows.Scan(
			&r.CredentialID, &r.CredentialType, &r.IssuedAt, &r.ExpiryDate,
			&r.Status, &isFav, &r.Category, &r.CredentialData,
			&r.Signature, &r.FabricCredID, &r.IPFSCID, &r.PublicKey,
			&r.IssuerName, &r.HolderName, &r.HolderEID,
		); err != nil {
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

// MobileActivityRow is one entry in the wallet activity feed.
type MobileActivityRow struct {
	EventID        int64
	EventType      string
	CredentialID   string
	CredentialType string
	ActorName      string
	CreatedAt      time.Time
}

// getMobileActivity returns up to 100 recent credential events for a holder.
func getMobileActivity(emiratesID string) ([]MobileActivityRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(`
		SELECT ce.event_id, ce.event_type, ce.credential_id,
		       COALESCE(c.credential_type, '') AS credential_type,
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
		if err := rows.Scan(&r.EventID, &r.EventType, &r.CredentialID, &r.CredentialType, &r.ActorName, &r.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// fetchDocumentInDB checks if a credential from a given org/service exists for the holder,
// and sets in_wallet=1 if found. Returns (found, alreadyInWallet, err).
func fetchDocumentInDB(holderEID, issuerID, serviceName string) (found bool, alreadyInWallet bool, err error) {
	if db == nil {
		return false, false, fmt.Errorf("database not configured")
	}
	// Resolve the catalog service's match_pattern (a SQL LIKE pattern against
	// credential_type). The catalog service name is a friendly label
	// ("Bachelor Degree") that won't substring-match a specific credential_type
	// ("Bachelor of Science in Computer Science"), so we match on the pattern.
	// Fall back to a substring of the service name if no pattern is configured.
	var matchPattern string
	_ = db.QueryRow(`SELECT match_pattern FROM catalog_services WHERE issuer_id = ? AND name = ? LIMIT 1`,
		issuerID, serviceName).Scan(&matchPattern)
	if matchPattern == "" {
		matchPattern = "%" + serviceName + "%"
	}

	// Count ALL credentials matching this holder + org + category. A holder may
	// hold several credentials of the same category (e.g. two Bachelor degrees);
	// every one of them should land in the wallet, not just the first.
	var totalMatching int
	err = db.QueryRow(`
		SELECT COUNT(*)
		  FROM credentials c
		  JOIN holders h ON c.holder_id = h.holder_id
		  JOIN issuers iss ON c.issuer_id = iss.issuer_id
		 WHERE h.emirates_id = ?
		   AND iss.org_id = ?
		   AND c.credential_type LIKE ?`,
		holderEID, issuerID, matchPattern).Scan(&totalMatching)
	if err != nil || totalMatching == 0 {
		return false, false, err
	}

	// Batch-update every matching credential not already in the wallet.
	result, err := db.Exec(`
		UPDATE credentials c
		  JOIN holders h ON c.holder_id = h.holder_id
		  JOIN issuers iss ON c.issuer_id = iss.issuer_id
		   SET c.in_wallet = 1
		 WHERE h.emirates_id = ?
		   AND iss.org_id = ?
		   AND c.credential_type LIKE ?
		   AND c.in_wallet = 0`,
		holderEID, issuerID, matchPattern)
	if err != nil {
		return true, false, err
	}

	rowsAffected, _ := result.RowsAffected()
	// 0 rows updated means every matching credential was already in the wallet.
	if rowsAffected == 0 {
		return true, true, nil
	}
	return true, false, nil
}
