package main

// db_credentials.go — MySQL access for the `credentials` table and the related
// `credential_events` log.
//
// MySQL is NOT the source of truth for anything the chain holds (type, status,
// dates, holder name, hashes, CID). Reads here only return what exists nowhere
// else — the display ID ↔ Fabric ID mapping, holder contact details, the issuing
// staff member, wallet flags, the event trail — and handlers merge in the
// on-chain fields (see chain.go). The on-chain columns are still written as a
// cache/audit copy, but no read path uses them.

import (
	"database/sql"
	"fmt"
	"log"
	"time"
)

// ─── TYPES ───────────────────────────────────────────────────────────────────

// CredentialInsert holds all fields needed to create a credential row.
type CredentialInsert struct {
	CredentialID   string // display ID: CRED-0001
	FabricCredID   string // full on-chain ID: CRED-{txID}
	HolderID       string // MySQL holder_id
	CredentialType string // human-readable type
	CredentialHash string // SHA3-256 hex
	Signature      string // hex ML-DSA-44 signature
	PublicKey      string // hex org public key
	IPFSCID        string // IPFS CID of the encrypted envelope
	CredentialData string // copy of the encrypted envelope JSON
	EncVersion     int    // envelope format version (envelopeVersion)
	IssuedAt       time.Time
	ExpiryDate     sql.NullTime // NULL when the credential has no expiry
}

// CredentialRef is the MySQL-only side of a credential: its display ID, the
// key of its on-chain record, and the holder/issuer details the chain lacks.
type CredentialRef struct {
	CredentialID string // display ID: CRED-0001
	FabricCredID string // on-chain key: CRED-{txID}
	HolderID     string // MySQL holder_id
	HolderEmail  string
	HolderEID    string
	IssuedBy     string // issuing staff member (issuers.full_name)
}

// EventRow drives the dashboard recentActivity feed (read from credential_events).
// The credential type and holder name come from the chain via FabricCredID.
type EventRow struct {
	EventType    string // 'issued' | 'revoked' | 'suspended' | 'restored'
	FabricCredID string
	Notes        string
	CreatedAt    time.Time
}

// AuditTrailRow is one entry in a credential's audit trail (a credential_events row).
type AuditTrailRow struct {
	Action      string
	PerformedBy string
	OccurredAt  time.Time
	Notes       sql.NullString
}

// ─── WRITES / STATUS CHANGES ─────────────────────────────────────────────────
// These keep MySQL's cache columns in step with the chain after a successful
// chain write. Nothing reads the cached values back.

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
		  signing_algorithm, ipfs_cid, status, credential_data, enc_version, issued_at, expiry_date)
		 VALUES (?, ?, ?, 'ISS-UOS-0001', 'ORG-UOS-001',
		         ?, ?, ?, ?,
		         'dilithium', ?, 'active', ?, ?, ?, ?)`,
		c.CredentialID, c.FabricCredID, c.HolderID,
		c.CredentialType, c.CredentialHash, c.Signature, c.PublicKey,
		c.IPFSCID, c.CredentialData, c.EncVersion, c.IssuedAt, c.ExpiryDate,
	)
	return err
}

// markCredentialRevoked updates the cached status to revoked.
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

// markCredentialSuspended updates the cached status to suspended with the reason.
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

// markCredentialRestored updates the cached status back to active.
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

// updateCredentialCommitment caches a re-signed expiry (nil clears it).
func updateCredentialCommitment(credentialID string, expiryDate *time.Time, credentialHash, signature string) error {
	if db == nil {
		return fmt.Errorf("database not configured")
	}
	_, err := db.Exec(`
		UPDATE credentials
		   SET expiry_date = ?, credential_hash = ?, issuer_signature = ?, updated_at = NOW()
		 WHERE credential_id = ?`,
		expiryDate, credentialHash, signature, credentialID)
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

// ─── CREDENTIAL EVENTS ───────────────────────────────────────────────────────

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
		       COALESCE(c.fabric_cred_id, '') AS fabric_cred_id,
		       COALESCE(ce.notes, '') AS notes,
		       ce.created_at
		  FROM credential_events ce
		  LEFT JOIN credentials c ON ce.credential_id = c.credential_id
		 ORDER BY ce.created_at DESC
		 LIMIT ?`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []EventRow{}
	for rows.Next() {
		var r EventRow
		if err := rows.Scan(&r.EventType, &r.FabricCredID, &r.Notes, &r.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// getCredentialAuditTrail returns the credential_events rows for one credential,
// oldest first. The chain only keeps the latest lifecycle state, so this trail
// is the one place a credential's full history exists.
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

// ─── ID MAPPING & REFERENCE QUERIES ──────────────────────────────────────────

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
	if err != nil {
		return "", err
	}
	if fabricID == "" {
		return "", fmt.Errorf("credential %q has no on-chain Fabric ID (blockchain issuance failed)", displayID)
	}
	return fabricID, nil
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

// credentialRefSelect is the shared SELECT for CredentialRef queries.
const credentialRefSelect = `
	SELECT c.credential_id, c.fabric_cred_id, c.holder_id,
	       COALESCE(h.email, '') AS holder_email,
	       COALESCE(h.emirates_id, '') AS holder_eid,
	       COALESCE(i.full_name, '') AS issued_by
	  FROM credentials c
	  JOIN holders h ON c.holder_id = h.holder_id
	  LEFT JOIN issuers i ON c.issuer_id = i.issuer_id`

func scanCredentialRef(sc interface{ Scan(...any) error }) (CredentialRef, error) {
	var r CredentialRef
	err := sc.Scan(&r.CredentialID, &r.FabricCredID, &r.HolderID, &r.HolderEmail, &r.HolderEID, &r.IssuedBy)
	return r, err
}

// listCredentialRefs returns every credential's MySQL-only details. Ordering,
// status filtering and pagination happen in Go on the chain values.
func listCredentialRefs() ([]CredentialRef, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(credentialRefSelect + ` WHERE c.fabric_cred_id <> ''`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []CredentialRef{}
	for rows.Next() {
		r, err := scanCredentialRef(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// credentialRefByID looks a credential up by display ID or Fabric ID.
// Returns sql.ErrNoRows when neither matches.
func credentialRefByID(id string) (CredentialRef, error) {
	if db == nil {
		return CredentialRef{}, fmt.Errorf("database not configured")
	}
	return scanCredentialRef(db.QueryRow(
		credentialRefSelect+` WHERE c.credential_id = ? OR c.fabric_cred_id = ? LIMIT 1`, id, id))
}
