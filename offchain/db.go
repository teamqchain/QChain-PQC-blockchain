package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"
	"sync/atomic"
	"time"

	_ "github.com/go-sql-driver/mysql"
)

var db *sql.DB

// displayCredSeq is an atomic counter for sequential display credential IDs (CRED-0001, CRED-0002...).
// Seeded from the MAX value in MySQL on startup so IDs never collide across restarts.
var displayCredSeq uint64

// displayHolderSeq is an atomic counter for sequential holder IDs (H-0001, H-0002...).
var displayHolderSeq uint64

// initDB connects to MySQL using MYSQL_DSN env var.
// Non-fatal: if MYSQL_DSN is absent or ping fails, db remains nil and all DB
// operations log warnings but don't crash the server.
func initDB() {
	dsn := os.Getenv("MYSQL_DSN")
	if dsn == "" {
		log.Println("MYSQL_DSN not set — database features disabled (holder/credential lookups will fail)")
		return
	}
	// Ensure parseTime=true so MySQL DATETIME columns scan into time.Time.
	if !strings.Contains(dsn, "parseTime") {
		if strings.Contains(dsn, "?") {
			dsn += "&parseTime=true"
		} else {
			dsn += "?parseTime=true"
		}
	}

	var err error
	db, err = sql.Open("mysql", dsn)
	if err != nil {
		log.Printf("DB open failed: %v — database features disabled", err)
		db = nil
		return
	}

	db.SetMaxOpenConns(10)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(5 * time.Minute)

	if err := db.Ping(); err != nil {
		log.Printf("DB ping failed: %v — database features disabled", err)
		db = nil
		return
	}

	// Seed the credential display ID counter from the current MAX so we never re-use a display ID.
	var maxCredSeq sql.NullInt64
	_ = db.QueryRow(
		`SELECT COALESCE(MAX(CAST(SUBSTRING(credential_id, 6) AS UNSIGNED)), 0) FROM credentials`,
	).Scan(&maxCredSeq)
	if maxCredSeq.Valid && maxCredSeq.Int64 > 0 {
		atomic.StoreUint64(&displayCredSeq, uint64(maxCredSeq.Int64))
	}

	// Seed the holder display ID counter similarly.
	var maxHolderSeq sql.NullInt64
	_ = db.QueryRow(
		`SELECT COALESCE(MAX(CAST(SUBSTRING(holder_id, 3) AS UNSIGNED)), 0) FROM holders`,
	).Scan(&maxHolderSeq)
	if maxHolderSeq.Valid && maxHolderSeq.Int64 > 0 {
		atomic.StoreUint64(&displayHolderSeq, uint64(maxHolderSeq.Int64))
	}

	log.Println("MySQL connected successfully")
}

// nextDisplayCredID returns the next sequential display credential ID (CRED-0001, CRED-0002...).
func nextDisplayCredID() string {
	n := atomic.AddUint64(&displayCredSeq, 1)
	return fmt.Sprintf("CRED-%04d", n)
}

// nextHolderID returns the next sequential holder ID (H-0001, H-0002...) and persists the
// counter via atomic increment.
func nextHolderID() (string, error) {
	n := atomic.AddUint64(&displayHolderSeq, 1)
	return fmt.Sprintf("H-%04d", n), nil
}

// ─── HOLDER QUERIES ──────────────────────────────────────────────────────────

// holderByEmiratesID looks up a holder by their UAE Emirates ID.
// Returns the MySQL display holder_id and the fabric_holder_id (blockchain key).
func holderByEmiratesID(emiratesID string) (holderID, fabricHolderID string, err error) {
	if db == nil {
		return "", "", fmt.Errorf("database not configured — set MYSQL_DSN")
	}
	row := db.QueryRow(
		`SELECT holder_id, fabric_holder_id FROM holders WHERE emirates_id = ?`,
		emiratesID,
	)
	err = row.Scan(&holderID, &fabricHolderID)
	if err == sql.ErrNoRows {
		return "", "", fmt.Errorf("Emirates ID %q not registered", emiratesID)
	}
	return
}

// insertHolder saves a new holder row into MySQL.
// Called by handleRegisterHolder (setup script path).
func insertHolder(holderID, emiratesID, firstName, lastName string) error {
	if db == nil {
		return fmt.Errorf("database not configured")
	}
	_, err := db.Exec(
		`INSERT INTO holders (holder_id, emirates_id, first_name, last_name, fabric_holder_id, is_wallet_activated)
		 VALUES (?, ?, ?, ?, ?, FALSE)
		 ON DUPLICATE KEY UPDATE first_name = VALUES(first_name), last_name = VALUES(last_name)`,
		holderID, emiratesID, firstName, lastName, holderID,
	)
	return err
}

// holderNameByID returns "FirstName LastName" for the given holder_id.
func holderNameByID(holderID string) (string, error) {
	if db == nil || holderID == "" {
		return holderID, nil
	}
	var first, last string
	row := db.QueryRow(`SELECT first_name, last_name FROM holders WHERE holder_id = ?`, holderID)
	if err := row.Scan(&first, &last); err != nil {
		return holderID, err
	}
	return fmt.Sprintf("%s %s", first, last), nil
}

// ─── CREDENTIAL QUERIES ──────────────────────────────────────────────────────

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

// ─── VERIFICATION LOG ────────────────────────────────────────────────────────

// logVerificationToDB appends a row to verification_logs.
// Non-fatal: errors are logged but not returned.
// verifiedBy is a human-readable label (e.g. "System Verifier" or staff name) —
// distinct from verifierID which is the internal MySQL FK.
func logVerificationToDB(
	displayCredID, fabricCredID, verifierID, verifiedBy,
	result, failureReason string,
	chainOK, hashOK, sigOK, notRevoked bool,
	statusAtVerify string,
) {
	if db == nil {
		return
	}
	if verifiedBy == "" {
		verifiedBy = "System Verifier"
	}
	logID := fmt.Sprintf("VL-%d", time.Now().UnixMilli())
	_, err := db.Exec(
		`INSERT INTO verification_logs
		 (log_id, credential_id, fabric_cred_id, verifier_id,
		  result, failure_reason, chain_verified, hash_verified, signature_verified, status_at_verify,
		  verified_by)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		logID, displayCredID, fabricCredID, verifierID,
		result, failureReason, chainOK, hashOK, sigOK, statusAtVerify,
		verifiedBy,
	)
	if err != nil {
		log.Printf("logVerificationToDB error: %v", err)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
//  V3 EXTENSION — row types and helpers for the new endpoints
// ─────────────────────────────────────────────────────────────────────────────

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

// HolderRow is the projection used by /getHolders responses.
type HolderRow struct {
	HolderID   string
	FullName   string
	Email      string
	EmiratesID string
	HolderType string
	College    string
}

// VerificationRow is the projection used by /getVerificationHistory responses.
type VerificationRow struct {
	LogID          string
	CredentialID   string
	CredentialType string
	HolderName     string
	IssuerName     string
	Result         string // raw DB value (success/failure)
	FailureReason  string
	Method         string // raw DB enum (qr_scan/manual/...)
	VerifiedBy     string
	VerifiedAt     time.Time
}

// DashboardCounters aggregates all of the top-level dashboard chips in one trip.
type DashboardCounters struct {
	TotalIssued    int
	TotalVerified  int
	TotalRevoked   int
	TotalSuspended int
	TotalExpired   int
	IssuedToday    int
	VerifiedToday  int
	AlertsUnread   int
	ExpiringSoon   int
}

// EventRow drives the dashboard recentActivity feed.
type EventRow struct {
	EventType      string // 'issued' | 'revoked' | 'suspended' | 'restored'
	CredentialType string
	HolderName     string
	Notes          string
	CreatedAt      time.Time
}

// ExpiryWarningRow drives the dashboard expiryWarnings list.
type ExpiryWarningRow struct {
	Name       string
	Credential string
	DaysLeft   int
}

// ChartPoint is one bar in the weeklyIssued / dailyVerified charts.
type ChartPoint struct {
	Label string
	Value int
}

// StatusAlertRow drives the verifier dashboard's statusAlerts list.
type StatusAlertRow struct {
	Name       string
	Credential string
	Event      string // UPPERCASE: REVOKED / SUSPENDED / EXPIRED
	Time       time.Time
}

// VerificationDisplayRow drives the verifier dashboard's recentVerifications list.
type VerificationDisplayRow struct {
	Credential string
	HolderName string
	Status     string // UPPERCASE: VALID / REVOKED / SUSPENDED / EXPIRED
	VerifiedAt time.Time
}

// ─── STATUS CHECKS & MUTATIONS ───────────────────────────────────────────────

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

func nullIfEmpty(s string) any {
	if s == "" {
		return nil
	}
	return s
}

// ─── LIST QUERIES ────────────────────────────────────────────────────────────

const credentialSelectCols = `
	c.credential_id, c.fabric_cred_id, c.holder_id,
	CONCAT_WS(' ', h.first_name, h.last_name) AS holder_name,
	COALESCE(h.email, '') AS holder_email,
	h.emirates_id AS holder_eid,
	c.credential_type,
	COALESCE(i.full_name, '') AS issued_by,
	c.status, c.issued_at, c.expiry_date
`

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

// searchHolders runs a LIKE search against full_name/emirates_id/email with optional type filter.
// `typeFilterDB` is the raw DB ENUM value (bachelor_student, etc.) — caller maps from camelCase.
func searchHolders(searchQuery, typeFilterDB string) ([]HolderRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	query := `
		SELECT holder_id,
		       CONCAT_WS(' ', first_name, last_name) AS full_name,
		       COALESCE(email, '') AS email,
		       emirates_id,
		       COALESCE(holder_type, '') AS holder_type,
		       COALESCE(college, '') AS college
		  FROM holders`
	conds := []string{}
	args := []any{}

	if searchQuery != "" {
		conds = append(conds, `(CONCAT_WS(' ', first_name, last_name) LIKE ?
		                       OR emirates_id LIKE ?
		                       OR email LIKE ?)`)
		like := "%" + searchQuery + "%"
		args = append(args, like, like, like)
	}
	if typeFilterDB != "" {
		conds = append(conds, `holder_type = ?`)
		args = append(args, typeFilterDB)
	}
	if len(conds) > 0 {
		query += ` WHERE ` + conds[0]
		for _, c := range conds[1:] {
			query += ` AND ` + c
		}
	}
	query += ` ORDER BY first_name, last_name ASC`

	rows, err := db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []HolderRow{}
	for rows.Next() {
		var r HolderRow
		if err := rows.Scan(&r.HolderID, &r.FullName, &r.Email, &r.EmiratesID, &r.HolderType, &r.College); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// listVerificationHistoryPaginated returns verification log rows joined with credential + holder.
// resultFilterDB is the raw DB value derived from the camelCase API filter (see server.go mapping).
func listVerificationHistoryPaginated(resultFilterDB, failureReasonFilter string, page, limit int) ([]VerificationRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	offset := (page - 1) * limit
	if offset < 0 {
		offset = 0
	}
	query := `
		SELECT vl.log_id, vl.credential_id,
		       COALESCE(c.credential_type, '') AS credential_type,
		       COALESCE(CONCAT_WS(' ', h.first_name, h.last_name), '') AS holder_name,
		       COALESCE(i.full_name, 'University of Sharjah') AS issuer_name,
		       vl.result, COALESCE(vl.failure_reason, '') AS failure_reason,
		       COALESCE(vl.verify_method, 'manual') AS method,
		       COALESCE(vl.verified_by, 'System Verifier') AS verified_by,
		       vl.verified_at
		  FROM verification_logs vl
		  LEFT JOIN credentials c ON vl.credential_id = c.credential_id
		  LEFT JOIN holders     h ON c.holder_id     = h.holder_id
		  LEFT JOIN issuers     i ON c.issuer_id     = i.issuer_id`
	conds := []string{}
	args := []any{}
	if resultFilterDB != "" {
		conds = append(conds, `vl.result = ?`)
		args = append(args, resultFilterDB)
	}
	if failureReasonFilter != "" {
		conds = append(conds, `vl.failure_reason = ?`)
		args = append(args, failureReasonFilter)
	}
	if len(conds) > 0 {
		query += ` WHERE ` + conds[0]
		for _, c := range conds[1:] {
			query += ` AND ` + c
		}
	}
	query += ` ORDER BY vl.verified_at DESC LIMIT ? OFFSET ?`
	args = append(args, limit, offset)

	rows, err := db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []VerificationRow{}
	for rows.Next() {
		var r VerificationRow
		if err := rows.Scan(
			&r.LogID, &r.CredentialID, &r.CredentialType, &r.HolderName, &r.IssuerName,
			&r.Result, &r.FailureReason, &r.Method, &r.VerifiedBy, &r.VerifiedAt,
		); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// countVerificationLogs returns the total verification log rows matching the optional filters.
func countVerificationLogs(resultFilterDB, failureReasonFilter string) (int, error) {
	if db == nil {
		return 0, fmt.Errorf("database not configured")
	}
	query := `SELECT COUNT(*) FROM verification_logs`
	conds := []string{}
	args := []any{}
	if resultFilterDB != "" {
		conds = append(conds, `result = ?`)
		args = append(args, resultFilterDB)
	}
	if failureReasonFilter != "" {
		conds = append(conds, `failure_reason = ?`)
		args = append(args, failureReasonFilter)
	}
	if len(conds) > 0 {
		query += ` WHERE ` + conds[0]
		for _, c := range conds[1:] {
			query += ` AND ` + c
		}
	}
	var n int
	err := db.QueryRow(query, args...).Scan(&n)
	return n, err
}

// ─── DASHBOARD QUERIES ───────────────────────────────────────────────────────

func dashboardCounters() (DashboardCounters, error) {
	var d DashboardCounters
	if db == nil {
		return d, fmt.Errorf("database not configured")
	}

	// Counters from credentials table.
	err := db.QueryRow(`
		SELECT
		  COUNT(*),
		  COALESCE(SUM(CASE WHEN status = 'revoked'   THEN 1 ELSE 0 END), 0),
		  COALESCE(SUM(CASE WHEN status = 'suspended' THEN 1 ELSE 0 END), 0),
		  COALESCE(SUM(CASE WHEN status = 'expired'   THEN 1 ELSE 0 END), 0),
		  COALESCE(SUM(CASE WHEN DATE(issued_at) = CURDATE() THEN 1 ELSE 0 END), 0)
		FROM credentials`).Scan(
		&d.TotalIssued, &d.TotalRevoked, &d.TotalSuspended, &d.TotalExpired, &d.IssuedToday,
	)
	if err != nil {
		return d, err
	}

	// Counters from verification_logs.
	err = db.QueryRow(`
		SELECT
		  COUNT(*),
		  COALESCE(SUM(CASE WHEN DATE(verified_at) = CURDATE() THEN 1 ELSE 0 END), 0)
		FROM verification_logs`).Scan(&d.TotalVerified, &d.VerifiedToday)
	if err != nil {
		return d, err
	}

	// Expiring within 30 days (active only).
	_ = db.QueryRow(`
		SELECT COUNT(*) FROM credentials
		 WHERE status = 'active'
		   AND expiry_date IS NOT NULL
		   AND expiry_date BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 30 DAY)`).
		Scan(&d.ExpiringSoon)

	// Alerts unread = recent non-active status events (last 7 days).
	_ = db.QueryRow(`
		SELECT COUNT(*) FROM credential_events
		 WHERE event_type IN ('revoked','suspended')
		   AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)`).
		Scan(&d.AlertsUnread)

	return d, nil
}

// recentCredentialEvents returns the latest N status-change events, newest first.
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

// expiryWarnings returns active credentials expiring within 30 days.
func expiryWarnings() ([]ExpiryWarningRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(`
		SELECT CONCAT_WS(' ', h.first_name, h.last_name) AS name,
		       c.credential_type AS credential,
		       DATEDIFF(c.expiry_date, CURDATE()) AS days_left
		  FROM credentials c
		  JOIN holders h ON c.holder_id = h.holder_id
		 WHERE c.status = 'active'
		   AND c.expiry_date IS NOT NULL
		   AND c.expiry_date BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 30 DAY)
		 ORDER BY c.expiry_date ASC
		 LIMIT 50`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []ExpiryWarningRow{}
	for rows.Next() {
		var r ExpiryWarningRow
		if err := rows.Scan(&r.Name, &r.Credential, &r.DaysLeft); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// weeklyIssued returns issuance counts grouped by week for the last 4 weeks.
// Caller pads missing weeks with value=0; we just return raw {YEARWEEK, count} rows.
func weeklyIssued() ([]ChartPoint, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(`
		SELECT YEARWEEK(issued_at, 3) AS yw, COUNT(*) AS value
		  FROM credentials
		 WHERE issued_at >= DATE_SUB(CURDATE(), INTERVAL 28 DAY)
		 GROUP BY yw
		 ORDER BY yw ASC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []ChartPoint{}
	for rows.Next() {
		var yw, value int
		if err := rows.Scan(&yw, &value); err != nil {
			return nil, err
		}
		out = append(out, ChartPoint{Label: fmt.Sprintf("%d", yw), Value: value})
	}
	return out, rows.Err()
}

// dailyVerified returns verification counts grouped by day-of-week for the last 7 days.
// Returns rows with label = "Mon"/"Tue"/... Caller pads missing days with value=0
// to always produce a 7-entry array in Mon→Sun order.
func dailyVerified() (map[string]int, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(`
		SELECT DATE_FORMAT(verified_at, '%a') AS label, COUNT(*) AS value
		  FROM verification_logs
		 WHERE verified_at >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
		 GROUP BY label`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := map[string]int{}
	for rows.Next() {
		var label string
		var value int
		if err := rows.Scan(&label, &value); err != nil {
			return nil, err
		}
		out[label] = value
	}
	return out, rows.Err()
}

// recentVerifications returns the last N verifications for the verifier dashboard.
func recentVerifications(limit int) ([]VerificationDisplayRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(`
		SELECT COALESCE(c.credential_type, '') AS credential,
		       COALESCE(CONCAT_WS(' ', h.first_name, h.last_name), '') AS holder_name,
		       CASE
		         WHEN vl.result = 'success' THEN 'VALID'
		         WHEN vl.result = 'failure' AND vl.failure_reason = 'REVOKED'   THEN 'REVOKED'
		         WHEN vl.result = 'failure' AND vl.failure_reason = 'SUSPENDED' THEN 'SUSPENDED'
		         WHEN vl.result = 'failure' AND vl.failure_reason = 'EXPIRED'   THEN 'EXPIRED'
		         ELSE 'INVALID'
		       END AS status,
		       vl.verified_at
		  FROM verification_logs vl
		  LEFT JOIN credentials c ON vl.credential_id = c.credential_id
		  LEFT JOIN holders     h ON c.holder_id     = h.holder_id
		 ORDER BY vl.verified_at DESC
		 LIMIT ?`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []VerificationDisplayRow{}
	for rows.Next() {
		var r VerificationDisplayRow
		if err := rows.Scan(&r.Credential, &r.HolderName, &r.Status, &r.VerifiedAt); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// statusAlerts returns the latest unacknowledged alerts for subscribed
// credentials (from the alerts table), not every non-active credential.
func statusAlerts(limit int) ([]StatusAlertRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(`
		SELECT COALESCE(holder_name, '') AS name,
		       COALESCE(credential_name, '') AS credential,
		       UPPER(severity) AS event,
		       triggered_at AS event_time
		  FROM alerts
		 WHERE acknowledged = 0
		 ORDER BY triggered_at DESC
		 LIMIT ?`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []StatusAlertRow{}
	for rows.Next() {
		var r StatusAlertRow
		if err := rows.Scan(&r.Name, &r.Credential, &r.Event, &r.Time); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// staffCounts returns issuer + verifier staff counts from the unified staff table.
func staffCounts() (issuers, verifiers int, err error) {
	if db == nil {
		return 0, 0, fmt.Errorf("database not configured")
	}
	_ = db.QueryRow(`SELECT COUNT(*) FROM staff WHERE portal = 'issuer'   AND status != 'deleted'`).Scan(&issuers)
	_ = db.QueryRow(`SELECT COUNT(*) FROM staff WHERE portal = 'verifier' AND status != 'deleted'`).Scan(&verifiers)
	return issuers, verifiers, nil
}

// ─── HELPERS ─────────────────────────────────────────────────────────────────

// holderInfoByID returns the holder's full name, email, and Emirates ID.
// Used to enrich verifyCredential responses with display fields.
func holderInfoByID(holderID string) (fullName, email, emiratesID string, err error) {
	if db == nil || holderID == "" {
		return "", "", "", nil
	}
	var first, last, em, eid sql.NullString
	row := db.QueryRow(
		`SELECT first_name, last_name, email, emirates_id FROM holders WHERE holder_id = ?`,
		holderID,
	)
	if err = row.Scan(&first, &last, &em, &eid); err != nil {
		return "", "", "", err
	}
	fullName = strings.TrimSpace(first.String + " " + last.String)
	email = em.String
	emiratesID = eid.String
	return
}

// formatHumanTime returns a human-readable relative time per the V3 doc:
//
//	< 60 min ago    → "X mins ago"
//	today, ≥ 60 min → "Today HH:MM"
//	yesterday       → "Yesterday"
//	older           → "DD MMM YYYY"
func formatHumanTime(t time.Time) string {
	if t.IsZero() {
		return ""
	}
	now := time.Now().In(t.Location())
	diff := now.Sub(t)

	if diff < time.Hour && diff >= 0 {
		mins := int(diff.Minutes())
		if mins < 1 {
			mins = 1
		}
		return fmt.Sprintf("%d mins ago", mins)
	}

	tDate := time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, t.Location())
	nowDate := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())

	switch nowDate.Sub(tDate) {
	case 0:
		return "Today " + t.Format("15:04")
	case 24 * time.Hour:
		return "Yesterday"
	default:
		return t.Format("02 Jan 2006")
	}
}

// ─────────────────────────────────────────────────────────────────────────────
//  PHASE B — SHARED HELPERS
// ─────────────────────────────────────────────────────────────────────────────

// ─── DATE FORMAT HELPERS ─────────────────────────────────────────────────────

var monthAbbr = []string{"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}

// FormatISO formats as "YYYY-MM-DDTHH:MM:SS" — required by Dart's DateTime.tryParse.
func FormatISO(t time.Time) string { return t.Format("2006-01-02T15:04:05") }

// FormatDateISO formats as "YYYY-MM-DD".
func FormatDateISO(t time.Time) string { return t.Format("2006-01-02") }

// FormatDateDisplay formats as "DD MMM YYYY" (e.g. "15 Jan 2025").
func FormatDateDisplay(t time.Time) string {
	return fmt.Sprintf("%02d %s %d", t.Day(), monthAbbr[t.Month()-1], t.Year())
}

// FormatDateTimeDisplay formats as "DD MMM YYYY HH:MM" (24 h).
func FormatDateTimeDisplay(t time.Time) string {
	return fmt.Sprintf("%02d %s %d %02d:%02d", t.Day(), monthAbbr[t.Month()-1], t.Year(), t.Hour(), t.Minute())
}

// NullDateDisplay returns "DD MMM YYYY" or fallback when the value is NULL.
func NullDateDisplay(nt sql.NullTime, fallback string) string {
	if !nt.Valid {
		return fallback
	}
	return FormatDateDisplay(nt.Time)
}

// ─── ID GENERATORS ───────────────────────────────────────────────────────────
// MAX-based sequential IDs — safe for single-server, low-concurrency use.

func generateAuditLogID() string {
	if db == nil {
		return "AUD-001"
	}
	var maxID sql.NullString
	_ = db.QueryRow(`SELECT MAX(audit_id) FROM portal_audit_log`).Scan(&maxID)
	if !maxID.Valid || maxID.String == "" {
		return "AUD-001"
	}
	parts := strings.Split(maxID.String, "-")
	if len(parts) != 2 {
		return "AUD-001"
	}
	n, _ := strconv.Atoi(parts[1])
	return fmt.Sprintf("AUD-%03d", n+1)
}

func generateAlertID() string {
	if db == nil {
		return "ALT-001"
	}
	var maxID sql.NullString
	_ = db.QueryRow(`SELECT MAX(alert_id) FROM alerts`).Scan(&maxID)
	if !maxID.Valid || maxID.String == "" {
		return "ALT-001"
	}
	parts := strings.Split(maxID.String, "-")
	if len(parts) != 2 {
		return "ALT-001"
	}
	n, _ := strconv.Atoi(parts[1])
	return fmt.Sprintf("ALT-%03d", n+1)
}

func generateStaffID() string {
	if db == nil {
		return "STF-0001"
	}
	var maxID sql.NullString
	_ = db.QueryRow(`SELECT MAX(id) FROM staff`).Scan(&maxID)
	if !maxID.Valid || maxID.String == "" {
		return "STF-0001"
	}
	parts := strings.Split(maxID.String, "-")
	if len(parts) != 2 {
		return "STF-0001"
	}
	n, _ := strconv.Atoi(parts[1])
	return fmt.Sprintf("STF-%04d", n+1)
}

func generateSubscriptionID() string {
	if db == nil {
		return "SUB-001"
	}
	var maxID sql.NullString
	_ = db.QueryRow(`SELECT MAX(subscription_id) FROM subscriptions`).Scan(&maxID)
	if !maxID.Valid || maxID.String == "" {
		return "SUB-001"
	}
	parts := strings.Split(maxID.String, "-")
	if len(parts) != 2 {
		return "SUB-001"
	}
	n, _ := strconv.Atoi(parts[1])
	return fmt.Sprintf("SUB-%03d", n+1)
}

// ─── AUDIT LOG ───────────────────────────────────────────────────────────────

// insertAuditLog appends a row to portal_audit_log. Non-fatal: errors are logged.
func insertAuditLog(action, details, performedBy, performedByRole, ipAddress string) {
	if db == nil {
		return
	}
	logID := generateAuditLogID()
	_, err := db.Exec(`
		INSERT INTO portal_audit_log
		  (audit_id, action, details, performed_by_name, performed_by_role, ip_address)
		VALUES (?, ?, ?, ?, ?, ?)`,
		logID, auditActionToEnum(action), details, performedBy, performedByRole, ipAddress,
	)
	if err != nil {
		log.Printf("insertAuditLog error: %v", err)
	}
}

// auditActionToEnum maps Phase 2 action strings to portal_audit_log ENUM values.
func auditActionToEnum(action string) string {
	switch action {
	case "issued", "revoked", "suspended", "restored", "verified",
		"staff_added", "staff_removed", "settings_changed",
		"schema_created", "schema_archived",
		"policy_created", "policy_deleted",
		"batch_issued", "exported", "login", "logout",
		"verification_failed":
		return action
	case "policy_changed":
		return "policy_created"
	case "system_config":
		return "settings_changed"
	}
	return "verification_failed"
}

// ─── DAILY ISSUED CHART ──────────────────────────────────────────────────────

// dailyIssued returns issuance counts grouped by day-of-week for the last 7 days.
// Caller uses buildDailyChart to pad missing days and produce 7 entries.
func dailyIssued() (map[string]int, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(`
		SELECT DATE_FORMAT(issued_at, '%a') AS label, COUNT(*) AS value
		  FROM credentials
		 WHERE issued_at >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
		 GROUP BY label`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := map[string]int{}
	for rows.Next() {
		var label string
		var value int
		if err := rows.Scan(&label, &value); err != nil {
			return nil, err
		}
		out[label] = value
	}
	return out, rows.Err()
}

// ─── IT ADMIN DASHBOARD QUERIES ──────────────────────────────────────────────

type RoleCount struct {
	Label string
	Count int
}

type AdminAuditRow struct {
	Action      string
	Details     string
	Role        string
	PerformedBy string
	Timestamp   time.Time
}

func staffTotals() (total, active, invited int, err error) {
	if db == nil {
		return 0, 0, 0, fmt.Errorf("database not configured")
	}
	_ = db.QueryRow(`SELECT COUNT(*) FROM staff WHERE status != 'deleted'`).Scan(&total)
	_ = db.QueryRow(`SELECT COUNT(*) FROM staff WHERE status = 'active'`).Scan(&active)
	_ = db.QueryRow(`SELECT COUNT(*) FROM staff WHERE status = 'invited'`).Scan(&invited)
	return total, active, invited, nil
}

func staffRoleBreakdown(portal string) ([]RoleCount, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(`
		SELECT role AS label, COUNT(*) AS count
		  FROM staff
		 WHERE portal = ? AND status != 'deleted' AND role != 'admin'
		 GROUP BY role ORDER BY count DESC`, portal)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []RoleCount{}
	for rows.Next() {
		var r RoleCount
		if err := rows.Scan(&r.Label, &r.Count); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

func recentAuditLogs(limit int) ([]AdminAuditRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(`
		SELECT action,
		       COALESCE(details, '') AS details,
		       COALESCE(performed_by_role, '') AS role,
		       COALESCE(performed_by_name, '') AS performed_by,
		       created_at
		  FROM portal_audit_log
		 ORDER BY created_at DESC
		 LIMIT ?`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []AdminAuditRow{}
	for rows.Next() {
		var r AdminAuditRow
		if err := rows.Scan(&r.Action, &r.Details, &r.Role, &r.PerformedBy, &r.Timestamp); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// ─────────────────────────────────────────────────────────────────────────────
//  PHASE C — QUERY FUNCTIONS FOR NEW ENDPOINTS
// ─────────────────────────────────────────────────────────────────────────────

// ─── CREDENTIAL DETAIL ───────────────────────────────────────────────────────

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

type AuditTrailRow struct {
	Action      string
	PerformedBy string
	OccurredAt  time.Time
	Notes       sql.NullString
}

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

func updateCredentialExpiry(credentialID string, expiryDate *time.Time) error {
	if db == nil {
		return fmt.Errorf("database not configured")
	}
	_, err := db.Exec(`UPDATE credentials SET expiry_date = ?, updated_at = NOW() WHERE credential_id = ?`,
		expiryDate, credentialID)
	return err
}

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

// ─── VERIFICATION DETAIL ─────────────────────────────────────────────────────

type VerificationDetailRow struct {
	LogID          string
	VerifiedAt     time.Time
	CredentialID   string
	CredentialType string
	HolderName     string
	HolderID       string
	IssuerName     string
	IssuedAt       sql.NullTime
	ExpiryDate     sql.NullTime
	Result         string
	FailureReason  sql.NullString
	Method         string
	VerifiedBy     string
	ChainVerified  sql.NullBool
	HashVerified   sql.NullBool
	SigVerified    sql.NullBool
	StatusAtVerify sql.NullString
}

func getVerificationDetail(logID string) (VerificationDetailRow, error) {
	var r VerificationDetailRow
	if db == nil {
		return r, fmt.Errorf("database not configured")
	}
	err := db.QueryRow(`
		SELECT vl.log_id, vl.verified_at,
		       COALESCE(vl.credential_id, '') AS credential_id,
		       COALESCE(c.credential_type, '') AS credential_type,
		       COALESCE(CONCAT_WS(' ', h.first_name, h.last_name), '') AS holder_name,
		       COALESCE(h.holder_id, '') AS holder_id,
		       COALESCE(i.full_name, '') AS issuer_name,
		       c.issued_at,
		       c.expiry_date,
		       vl.result,
		       vl.failure_reason,
		       COALESCE(vl.verify_method, 'manual') AS method,
		       COALESCE(vl.verified_by, 'System Verifier') AS verified_by,
		       vl.chain_verified,
		       vl.hash_verified,
		       vl.signature_verified,
		       vl.status_at_verify
		  FROM verification_logs vl
		  LEFT JOIN credentials c ON vl.credential_id = c.credential_id
		  LEFT JOIN holders     h ON c.holder_id = h.holder_id
		  LEFT JOIN issuers     i ON c.issuer_id  = i.issuer_id
		 WHERE vl.log_id = ?
		 LIMIT 1`, logID).Scan(
		&r.LogID, &r.VerifiedAt, &r.CredentialID, &r.CredentialType,
		&r.HolderName, &r.HolderID, &r.IssuerName, &r.IssuedAt, &r.ExpiryDate,
		&r.Result, &r.FailureReason, &r.Method, &r.VerifiedBy,
		&r.ChainVerified, &r.HashVerified, &r.SigVerified, &r.StatusAtVerify,
	)
	if err == sql.ErrNoRows {
		return r, sql.ErrNoRows
	}
	return r, err
}

// ─── SUBSCRIPTIONS ───────────────────────────────────────────────────────────

type SubscriptionRow struct {
	SubscriptionID string
	HolderName     string
	HolderID       string
	CredentialType string
	Issuer         string
	SubscribedAt   sql.NullTime
	ExpiryDate     sql.NullTime
	Status         string
}

func insertSubscription(subscriptionID, credentialID, holderID string) error {
	if db == nil {
		return fmt.Errorf("database not configured")
	}
	_, err := db.Exec(`
		INSERT INTO subscriptions (subscription_id, verifier_id, holder_id, credential_id, status, subscribed_at)
		VALUES (?, 'VER-UOS-0001', ?, ?, 'pending', NOW())`,
		subscriptionID, holderID, credentialID,
	)
	return err
}

func activeSubscriptionExists(credentialID string) (bool, error) {
	if db == nil {
		return false, fmt.Errorf("database not configured")
	}
	var count int
	err := db.QueryRow(`
		SELECT COUNT(*) FROM subscriptions
		 WHERE credential_id = ? AND status IN ('active','pending')`, credentialID).Scan(&count)
	return count > 0, err
}

func getSubscriptions(page, limit int) ([]SubscriptionRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	offset := (page - 1) * limit
	rows, err := db.Query(`
		SELECT s.subscription_id,
		       CONCAT_WS(' ', h.first_name, h.last_name) AS holder_name,
		       h.holder_id,
		       COALESCE(c.credential_type, '') AS credential_type,
		       COALESCE(i.full_name, '') AS issuer,
		       s.subscribed_at,
		       s.expiry_date,
		       s.status
		  FROM subscriptions s
		  JOIN credentials c ON s.credential_id = c.credential_id
		  JOIN holders     h ON s.holder_id     = h.holder_id
		  LEFT JOIN issuers i ON c.issuer_id    = i.issuer_id
		 ORDER BY s.created_at DESC
		 LIMIT ? OFFSET ?`, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []SubscriptionRow{}
	for rows.Next() {
		var r SubscriptionRow
		if err := rows.Scan(&r.SubscriptionID, &r.HolderName, &r.HolderID,
			&r.CredentialType, &r.Issuer, &r.SubscribedAt, &r.ExpiryDate, &r.Status); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

func getSubscriptionStatus(subscriptionID string) (string, error) {
	if db == nil {
		return "", fmt.Errorf("database not configured")
	}
	var status string
	err := db.QueryRow(`SELECT status FROM subscriptions WHERE subscription_id = ? LIMIT 1`, subscriptionID).Scan(&status)
	if err == sql.ErrNoRows {
		return "", sql.ErrNoRows
	}
	return status, err
}

func deleteSubscriptionRow(subscriptionID string) error {
	if db == nil {
		return fmt.Errorf("database not configured")
	}
	_, err := db.Exec(`DELETE FROM subscriptions WHERE subscription_id = ? AND status = 'pending'`, subscriptionID)
	return err
}

func unsubscribeSubscription(subscriptionID string) error {
	if db == nil {
		return fmt.Errorf("database not configured")
	}
	_, err := db.Exec(`
		UPDATE subscriptions SET status = 'unsubscribed', updated_at = NOW()
		 WHERE subscription_id = ? AND status = 'active'`, subscriptionID)
	return err
}

// ─── ALERTS ──────────────────────────────────────────────────────────────────

type AlertRow struct {
	AlertID        string
	HolderName     string
	CredentialName string
	Severity       string
	Description    string
	TriggeredAt    time.Time
	Acknowledged   bool
}

func getAlerts() ([]AlertRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(`
		SELECT alert_id,
		       COALESCE(holder_name, '') AS holder_name,
		       COALESCE(credential_name, '') AS credential_name,
		       severity,
		       COALESCE(description, '') AS description,
		       triggered_at,
		       acknowledged
		  FROM alerts
		 ORDER BY triggered_at DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []AlertRow{}
	for rows.Next() {
		var r AlertRow
		var ack int
		if err := rows.Scan(&r.AlertID, &r.HolderName, &r.CredentialName,
			&r.Severity, &r.Description, &r.TriggeredAt, &ack); err != nil {
			return nil, err
		}
		r.Acknowledged = ack == 1
		out = append(out, r)
	}
	return out, rows.Err()
}

func acknowledgeAlert(alertID string) error {
	if db == nil {
		return fmt.Errorf("database not configured")
	}
	_, err := db.Exec(`UPDATE alerts SET acknowledged = 1 WHERE alert_id = ?`, alertID)
	return err
}

func alertExists(alertID string) (bool, error) {
	if db == nil {
		return false, fmt.Errorf("database not configured")
	}
	var count int
	err := db.QueryRow(`SELECT COUNT(*) FROM alerts WHERE alert_id = ?`, alertID).Scan(&count)
	return count > 0, err
}

// insertAlertForCredential creates a status-change alert row. Non-fatal on error.
func insertAlertForCredential(credentialID, credentialName, holderID, holderName, severity, description string) {
	if db == nil {
		return
	}
	alertID := generateAlertID()
	_, err := db.Exec(`
		INSERT INTO alerts (alert_id, holder_id, credential_id, credential_name, holder_name, description, severity)
		VALUES (?, ?, ?, ?, ?, ?, ?)`,
		alertID, nullIfEmpty(holderID), nullIfEmpty(credentialID),
		credentialName, holderName, description, severity,
	)
	if err != nil {
		log.Printf("insertAlertForCredential error: %v", err)
	}
}

// ─── AUDIT LOGS ──────────────────────────────────────────────────────────────

type AuditLogRow struct {
	AuditID         string
	Action          string
	Details         string
	PerformedByName string
	PerformedByRole string
	IPAddress       string
	CreatedAt       time.Time
}

func getAuditLogs(page, limit int) ([]AuditLogRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	offset := (page - 1) * limit
	rows, err := db.Query(`
		SELECT audit_id, action,
		       COALESCE(details, '') AS details,
		       COALESCE(performed_by_name, '') AS performed_by_name,
		       COALESCE(performed_by_role, '') AS performed_by_role,
		       COALESCE(ip_address, '') AS ip_address,
		       created_at
		  FROM portal_audit_log
		 ORDER BY created_at DESC
		 LIMIT ? OFFSET ?`, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []AuditLogRow{}
	for rows.Next() {
		var r AuditLogRow
		if err := rows.Scan(&r.AuditID, &r.Action, &r.Details,
			&r.PerformedByName, &r.PerformedByRole, &r.IPAddress, &r.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// ─── STAFF ───────────────────────────────────────────────────────────────────

type StaffRow struct {
	ID        string
	Name      string
	Email     string
	Portal    string
	Role      string
	Status    string
	AddedDate time.Time
}

func getStaff() ([]StaffRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(`
		SELECT id, name, email, portal, role, status, added_date
		  FROM staff
		 WHERE status != 'deleted'
		 ORDER BY added_date DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []StaffRow{}
	for rows.Next() {
		var r StaffRow
		if err := rows.Scan(&r.ID, &r.Name, &r.Email, &r.Portal, &r.Role, &r.Status, &r.AddedDate); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

func staffEmailExists(email string) (bool, error) {
	if db == nil {
		return false, fmt.Errorf("database not configured")
	}
	var count int
	err := db.QueryRow(`SELECT COUNT(*) FROM staff WHERE email = ?`, email).Scan(&count)
	return count > 0, err
}

func insertStaff(id, email, portal, role string) error {
	if db == nil {
		return fmt.Errorf("database not configured")
	}
	_, err := db.Exec(`
		INSERT INTO staff (id, name, email, portal, role, status, added_date)
		VALUES (?, '', ?, ?, ?, 'invited', CURDATE())`,
		id, email, portal, role,
	)
	return err
}

func getStaffByID(id string) (StaffRow, error) {
	var r StaffRow
	if db == nil {
		return r, fmt.Errorf("database not configured")
	}
	err := db.QueryRow(`
		SELECT id, name, email, portal, role, status, added_date
		  FROM staff WHERE id = ? AND status != 'deleted' LIMIT 1`, id).Scan(
		&r.ID, &r.Name, &r.Email, &r.Portal, &r.Role, &r.Status, &r.AddedDate,
	)
	if err == sql.ErrNoRows {
		return r, sql.ErrNoRows
	}
	return r, err
}

func updateStaffRole(id, portal, role string) error {
	if db == nil {
		return fmt.Errorf("database not configured")
	}
	_, err := db.Exec(`UPDATE staff SET portal = ?, role = ? WHERE id = ?`, portal, role, id)
	return err
}

func softDeleteStaff(id string) error {
	if db == nil {
		return fmt.Errorf("database not configured")
	}
	_, err := db.Exec(`UPDATE staff SET status = 'deleted' WHERE id = ?`, id)
	return err
}

// ─── MOBILE SESSIONS ─────────────────────────────────────────────────────────

type MobileSessionRow struct {
	ID           string
	SessionType  string
	CredentialID string
	HolderID     string
	HiddenFields []string
	ExpiresAt    time.Time
}

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

func deleteMobileSession(id string) {
	if db == nil {
		return
	}
	if _, err := db.Exec(`DELETE FROM mobile_sessions WHERE id = ?`, id); err != nil {
		log.Printf("deleteMobileSession error: %v", err)
	}
}

func mobileSessionExists(id string) bool {
	if db == nil {
		return false
	}
	var count int
	_ = db.QueryRow(`SELECT COUNT(*) FROM mobile_sessions WHERE id = ?`, id).Scan(&count)
	return count > 0
}

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

// ─── CATALOG ─────────────────────────────────────────────────────────────────

type CatalogIssuerRow struct {
	IssuerID    string
	Category    string
	IssuerName  string
	ServiceID   sql.NullString
	ServiceName sql.NullString
	Description sql.NullString
}

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

type MobileActivityRow struct {
	EventID        int64
	EventType      string
	CredentialType string
	ActorName      string
	CreatedAt      time.Time
}

func getMobileActivity(emiratesID string) ([]MobileActivityRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(`
		SELECT ce.event_id, ce.event_type,
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
		if err := rows.Scan(&r.EventID, &r.EventType, &r.CredentialType, &r.ActorName, &r.CreatedAt); err != nil {
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

// OrgDirectoryRecord holds a single employee entry from the HR directory.
type OrgDirectoryRecord struct {
	Name  string
	Email string
}

// getOrgDirectory returns all active employees from the org_directory table.
// It backs the QPortal Invite Staff dialog, which only lets staff invite
// emails that exist in this directory.
func getOrgDirectory() ([]OrgDirectoryRecord, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(`
		SELECT name, email
		  FROM org_directory
		 WHERE is_active = TRUE
		 ORDER BY name ASC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []OrgDirectoryRecord{}
	for rows.Next() {
		var r OrgDirectoryRecord
		if err := rows.Scan(&r.Name, &r.Email); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// MobileSubscriptionRow holds one subscription request for the QWallet
// ManageSubscriptions screen. (Distinct from the portal SubscriptionRow above.)
type MobileSubscriptionRow struct {
	SubscriptionID string
	CredentialType string
	VerifierName   string
	Status         string
	CreatedAt      string
}

// getMobileSubscriptions returns all subscription requests addressed to the
// holder identified by their Emirates ID. The stored status 'active' is
// reported to the wallet as 'approved' so the Flutter SubscriptionModel sees
// the value it expects.
func getMobileSubscriptions(emiratesID string) ([]MobileSubscriptionRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(`
		SELECT s.subscription_id,
		       COALESCE(s.credential_type, '') AS credential_type,
		       COALESCE(v.full_name, 'Unknown Verifier') AS verifier_name,
		       s.status,
		       s.created_at
		  FROM subscriptions s
		  JOIN holders h   ON s.holder_id   = h.holder_id
		  JOIN verifiers v ON s.verifier_id = v.verifier_id
		 WHERE h.emirates_id = ?
		 ORDER BY s.created_at DESC`, emiratesID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []MobileSubscriptionRow{}
	for rows.Next() {
		var r MobileSubscriptionRow
		if err := rows.Scan(&r.SubscriptionID, &r.CredentialType, &r.VerifierName, &r.Status, &r.CreatedAt); err != nil {
			return nil, err
		}
		if r.Status == "active" {
			r.Status = "approved"
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// updateSubscriptionStatus sets a pending subscription to 'active' (approve) or
// 'rejected' (reject). It verifies the subscription belongs to the given holder
// so a holder can never act on someone else's subscription. Returns whether a
// row was actually updated.
func updateSubscriptionStatus(subscriptionID, emiratesID, newStatus string) (bool, error) {
	if db == nil {
		return false, fmt.Errorf("database not configured")
	}
	result, err := db.Exec(`
		UPDATE subscriptions s
		  JOIN holders h ON s.holder_id = h.holder_id
		   SET s.status = ?
		 WHERE s.subscription_id = ?
		   AND h.emirates_id     = ?
		   AND s.status          = 'pending'`,
		newStatus, subscriptionID, emiratesID)
	if err != nil {
		return false, err
	}
	affected, _ := result.RowsAffected()
	return affected > 0, nil
}
