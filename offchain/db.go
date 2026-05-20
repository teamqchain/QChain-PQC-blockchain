package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"
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

// statusAlerts returns the latest credentials in non-active states.
func statusAlerts(limit int) ([]StatusAlertRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(`
		SELECT CONCAT_WS(' ', h.first_name, h.last_name) AS name,
		       c.credential_type AS credential,
		       UPPER(c.status) AS event,
		       c.updated_at AS event_time
		  FROM credentials c
		  JOIN holders h ON c.holder_id = h.holder_id
		 WHERE c.status IN ('revoked','suspended','expired')
		 ORDER BY c.updated_at DESC
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

// staffCounts returns active issuer + verifier counts for the IT Admin dashboard.
func staffCounts() (issuers, verifiers int, err error) {
	if db == nil {
		return 0, 0, fmt.Errorf("database not configured")
	}
	_ = db.QueryRow(`SELECT COUNT(*) FROM issuers   WHERE status = 'active'`).Scan(&issuers)
	_ = db.QueryRow(`SELECT COUNT(*) FROM verifiers WHERE status = 'active'`).Scan(&verifiers)
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
