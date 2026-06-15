package main

// db_credentials.go — MySQL access for the `credentials` table and the related
// `credential_events` log: insert a credential, resolve display↔fabric IDs,
// change status (revoke/suspend/restore), list/detail queries, and append/read
// the per-credential event trail that powers the activity feed.

import (
	"database/sql"
	"fmt"
	"log"
	"time"
)

// ─── TYPES ───────────────────────────────────────────────────────────────────

// CredentialInsert holds all fields needed to create a credential row.
type CredentialInsert struct {
	CredentialID   string       // display ID: CRED-0001
	FabricCredID   string       // full on-chain ID: CRED-{txID}
	HolderID       string       // MySQL holder_id
	CredentialType string       // human-readable type
	CredentialHash string       // SHA3-256 hex
	Signature      string       // hex ML-DSA-44 signature
	PublicKey      string       // hex org public key
	IPFSCID        string       // IPFS CID (may be empty)
	CredentialData string       // raw info JSON for display
	IssuedAt       time.Time
	ExpiryDate     sql.NullTime // parsed from inner info JSON; NULL if none
}

// CredentialRow is the denormalised projection used by /getAllCredentials and
// /getCredentialsByHolder responses. Built via JOIN holders + JOIN issuers.
type CredentialRow struct {
	CredentialID   string
	FabricCredID   string
	HolderID       string
	HolderName     string
	HolderEmail    string
	HolderEID      string
	CredentialType string
	IssuedBy       string
	Status         string
	IssuedAt       time.Time
	ExpiryDate     sql.NullTime
}

// EventRow drives the dashboard recentActivity feed (read from credential_events).
type EventRow struct {
	EventType      string // 'issued' | 'revoked' | 'suspended' | 'restored'
	CredentialType string
	HolderName     string
	Notes          string
	CreatedAt      time.Time
}

// CredentialDetailRow is the projection used by /getCredentialDetail.
type CredentialDetailRow struct {
	CredentialID   string
	CredentialType string
	HolderName     string
	HolderEmail    string
	HolderEID      string
	HolderID       string
	IssuedAt       time.Time
	IssuedBy       string
	Status         string
	ExpiryDate     sql.NullTime
}

// AuditTrailRow is one entry in a credential's audit trail (a credential_events row).
type AuditTrailRow struct {
	Action      string
	PerformedBy string
	OccurredAt  time.Time
	Notes       sql.NullString
}

// ─── WRITES / STATUS CHANGES ─────────────────────────────────────────────────

// insertCredential saves a new credential row into MySQL.
// issuer_id and org_id are hardcoded to the demo seed values for now;
// they'll be derived from the authenticated session once JWT auth is added.
func insertCredential(c CredentialInsert) error {
	if db == nil {
		return fmt.Errorf("database not configured")
	}
	_, err := db.Exec(
		`INSERT INTO credentials
		 (credential_id, fabric_cred_id, holder_id, issuer_id, org_id,
		  credential_type, credential_hash, issuer_signature, issuer_public_key,
		  signing_algorithm, ipfs_cid, status, credential_data, issued_at, expiry_date)
		 VALUES (?, ?, ?, 'ISS-UOS-0001', 'ORG-UOS-001',
		         ?, ?, ?, ?,
		         'dilithium', ?, 'active', ?, ?, ?)`,
		c.CredentialID, c.FabricCredID, c.HolderID,
		c.CredentialType, c.CredentialHash, c.Signature, c.PublicKey,
		c.IPFSCID, c.CredentialData, c.IssuedAt, c.ExpiryDate,
	)
	return err
}

// fabricCredIDByDisplay resolves a display credential ID (CRED-0001) to the full
// blockchain fabric_cred_id (CRED-{txID}).
func fabricCredIDByDisplay(displayID string) (string, error) {
	if db == nil {
		return "", fmt.Errorf("database not configured — set MYSQL_DSN")
	}
	var fabricID string
	err := db.QueryRow(
		`SELECT fabric_cred_id FROM credentials WHERE credential_id = ?`,
		displayID,
	).Scan(&fabricID)
	if err == sql.ErrNoRows {
		return "", fmt.Errorf("credential %q not found", displayID)
	}
	return fabricID, err
}

// markCredentialRevoked updates the credential status to revoked in MySQL.
func markCredentialRevoked(displayCredID string) error {
	if db == nil {
		return fmt.Errorf("database not configured")
	}
	_, err := db.Exec(
		`UPDATE credentials SET status = 'revoked', revoked_at = NOW() WHERE credential_id = ?`,
		displayCredID,
	)
	return err
}

// credentialStatusByDisplay returns the current status of a credential by display ID.
func credentialStatusByDisplay(displayCredID string) (string, error) {
	if db == nil {
		return "", fmt.Errorf("database not configured")
	}
	var status string
	err := db.QueryRow(
		`SELECT status FROM credentials WHERE credential_id = ?`,
		displayCredID,
	).Scan(&status)
	if err == sql.ErrNoRows {
		return "", fmt.Errorf("credential %q not found", displayCredID)
	}
	return status, err
}

// markCredentialSuspended sets a credential's status to 'suspended' and stores the reason.
func markCredentialSuspended(displayCredID, reason string) error {
	if db == nil {
		return fmt.Errorf("database not configured")
	}
	_, err := db.Exec(
		`UPDATE credentials
		   SET status = 'suspended', suspended_reason = ?
		 WHERE credential_id = ?`,
		reason, displayCredID,
	)
	return err
}

// markCredentialRestored sets a credential's status back to 'active' and clears suspend fields.
func markCredentialRestored(displayCredID string) error {
	if db == nil {
		return fmt.Errorf("database not configured")
	}
	_, err := db.Exec(
		`UPDATE credentials
		   SET status = 'active', suspended_reason = NULL, suspended_until = NULL
		 WHERE credential_id = ?`,
		displayCredID,
	)
	return err
}

// insertCredentialEvent appends a row to credential_events.
// Non-fatal: errors are logged but not returned (event log is best-effort).
func insertCredentialEvent(displayCredID, eventType, actorID, actorName, notes string) {
	if db == nil {
		return
	}
	_, err := db.Exec(
		`INSERT INTO credential_events
		   (credential_id, event_type, actor_id, actor_name, notes)
		 VALUES (?, ?, ?, ?, ?)`,
		displayCredID, eventType, nullIfEmpty(actorID), nullIfEmpty(actorName), nullIfEmpty(notes),
	)
	if err != nil {
		log.Printf("insertCredentialEvent error: %v", err)
	}
}

// recentCredentialEvents returns the latest N status-change events, newest first.
// Feeds the dashboard activity feed (see dashboard.go).
func recentCredentialEvents(limit int) ([]EventRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(`
		SELECT ce.event_type,
		       COALESCE(c.credential_type, '') AS credential_type,
		       COALESCE(CONCAT_WS(' ', h.first_name, h.last_name), '') AS holder_name,
		       COALESCE(ce.notes, '') AS notes,
		       ce.created_at
		  FROM credential_events ce
		  LEFT JOIN credentials c ON ce.credential_id = c.credential_id
		  LEFT JOIN holders     h ON c.holder_id     = h.holder_id
		 ORDER BY ce.created_at DESC
		 LIMIT ?`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []EventRow{}
	for rows.Next() {
		var r EventRow
		if err := rows.Scan(&r.EventType, &r.CredentialType, &r.HolderName, &r.Notes, &r.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// ─── LIST QUERIES ────────────────────────────────────────────────────────────

// credentialSelectCols is the shared SELECT list (and JOIN-derived columns) used
// by the paginated list and the by-holder list so they project identical rows.
const credentialSelectCols = `
	c.credential_id, c.fabric_cred_id, c.holder_id,
	CONCAT_WS(' ', h.first_name, h.last_name) AS holder_name,
	COALESCE(h.email, '') AS holder_email,
	h.emirates_id AS holder_eid,
	c.credential_type,
	COALESCE(i.full_name, '') AS issued_by,
	c.status, c.issued_at, c.expiry_date
`

// scanCredentialRow scans one *sql.Rows cursor position into a CredentialRow.
func scanCredentialRow(rows *sql.Rows) (CredentialRow, error) {
	var r CredentialRow
	err := rows.Scan(
		&r.CredentialID, &r.FabricCredID, &r.HolderID,
		&r.HolderName, &r.HolderEmail, &r.HolderEID,
		&r.CredentialType, &r.IssuedBy,
		&r.Status, &r.IssuedAt, &r.ExpiryDate,
	)
	return r, err
}

// listCredentialsPaginated lists credentials with optional status filter, paginated.
// Invalid status filter is treated as "no filter" by the caller; this function
// blindly applies whatever string is passed (use a validated value).
func listCredentialsPaginated(statusFilter string, page, limit int) ([]CredentialRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	offset := (page - 1) * limit
	if offset < 0 {
		offset = 0
	}
	query := `SELECT ` + credentialSelectCols + `
		FROM credentials c
		JOIN holders h ON c.holder_id = h.holder_id
		LEFT JOIN issuers i ON c.issuer_id = i.issuer_id`
	args := []any{}
	if statusFilter != "" {
		query += ` WHERE c.status = ?`
		args = append(args, statusFilter)
	}
	query += ` ORDER BY c.issued_at DESC LIMIT ? OFFSET ?`
	args = append(args, limit, offset)

	rows, err := db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []CredentialRow{}
	for rows.Next() {
		r, err := scanCredentialRow(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// countCredentials returns the total number of credentials matching the optional status filter.
func countCredentials(statusFilter string) (int, error) {
	if db == nil {
		return 0, fmt.Errorf("database not configured")
	}
	query := `SELECT COUNT(*) FROM credentials`
	args := []any{}
	if statusFilter != "" {
		query += ` WHERE status = ?`
		args = append(args, statusFilter)
	}
	var n int
	err := db.QueryRow(query, args...).Scan(&n)
	return n, err
}

// listCredentialsByHolder returns all credentials for a holder (sorted newest first).
func listCredentialsByHolder(holderID string) ([]CredentialRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(
		`SELECT `+credentialSelectCols+`
		   FROM credentials c
		   JOIN holders h ON c.holder_id = h.holder_id
		   LEFT JOIN issuers i ON c.issuer_id = i.issuer_id
		  WHERE c.holder_id = ?
		  ORDER BY c.issued_at DESC`,
		holderID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []CredentialRow{}
	for rows.Next() {
		r, err := scanCredentialRow(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// ─── DETAIL / UPDATE QUERIES ─────────────────────────────────────────────────

// getCredentialDetail returns the full single-credential projection for /getCredentialDetail.
func getCredentialDetail(credentialID string) (CredentialDetailRow, error) {
	var r CredentialDetailRow
	if db == nil {
		return r, fmt.Errorf("database not configured")
	}
	err := db.QueryRow(`
		SELECT c.credential_id, c.credential_type,
		       CONCAT_WS(' ', h.first_name, h.last_name) AS holder_name,
		       COALESCE(h.email, '') AS holder_email,
		       COALESCE(h.emirates_id, '') AS holder_eid,
		       h.holder_id,
		       c.issued_at,
		       COALESCE(i.full_name, '') AS issued_by,
		       c.status,
		       c.expiry_date
		  FROM credentials c
		  JOIN holders h ON c.holder_id = h.holder_id
		  LEFT JOIN issuers i ON c.issuer_id = i.issuer_id
		 WHERE c.credential_id = ?
		 LIMIT 1`, credentialID).Scan(
		&r.CredentialID, &r.CredentialType, &r.HolderName, &r.HolderEmail, &r.HolderEID,
		&r.HolderID, &r.IssuedAt, &r.IssuedBy, &r.Status, &r.ExpiryDate,
	)
	if err == sql.ErrNoRows {
		return r, sql.ErrNoRows
	}
	return r, err
}

// getCredentialAuditTrail returns the credential_events rows for one credential, oldest first.
func getCredentialAuditTrail(credentialID string) ([]AuditTrailRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(`
		SELECT event_type,
		       COALESCE(actor_name, '') AS performed_by,
		       created_at,
		       notes
		  FROM credential_events
		 WHERE credential_id = ?
		 ORDER BY created_at ASC`, credentialID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []AuditTrailRow{}
	for rows.Next() {
		var r AuditTrailRow
		if err := rows.Scan(&r.Action, &r.PerformedBy, &r.OccurredAt, &r.Notes); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// updateCredentialExpiry sets (or clears, when expiryDate is nil) a credential's expiry.
func updateCredentialExpiry(credentialID string, expiryDate *time.Time) error {
	if db == nil {
		return fmt.Errorf("database not configured")
	}
	_, err := db.Exec(`UPDATE credentials SET expiry_date = ?, updated_at = NOW() WHERE credential_id = ?`,
		expiryDate, credentialID)
	return err
}

// updateHolderEmail updates the email of the holder who owns the given credential.
func updateHolderEmail(credentialID, email string) error {
	if db == nil {
		return fmt.Errorf("database not configured")
	}
	_, err := db.Exec(`
		UPDATE holders SET email = ?
		 WHERE holder_id = (SELECT holder_id FROM credentials WHERE credential_id = ? LIMIT 1)`,
		email, credentialID)
	return err
}

// credentialHolderID returns the holder_id that owns the given credential.
func credentialHolderID(credentialID string) (string, error) {
	if db == nil {
		return "", fmt.Errorf("database not configured")
	}
	var holderID string
	err := db.QueryRow(`SELECT holder_id FROM credentials WHERE credential_id = ? LIMIT 1`, credentialID).Scan(&holderID)
	if err == sql.ErrNoRows {
		return "", sql.ErrNoRows
	}
	return holderID, err
}
