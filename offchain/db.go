package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"
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
	CredentialID   string    // display ID: CRED-0001
	FabricCredID   string    // full on-chain ID: CRED-{txID}
	HolderID       string    // MySQL holder_id
	CredentialType string    // human-readable type
	CredentialHash string    // SHA3-256 hex
	Signature      string    // hex ML-DSA-44 signature
	PublicKey      string    // hex org public key
	IPFSCID        string    // IPFS CID (may be empty)
	CredentialData string    // raw info JSON for display
	IssuedAt       time.Time
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
		  signing_algorithm, ipfs_cid, status, credential_data, issued_at)
		 VALUES (?, ?, ?, 'ISS-UOS-0001', 'ORG-UOS-001',
		         ?, ?, ?, ?,
		         'dilithium', ?, 'active', ?, ?)`,
		c.CredentialID, c.FabricCredID, c.HolderID,
		c.CredentialType, c.CredentialHash, c.Signature, c.PublicKey,
		c.IPFSCID, c.CredentialData, c.IssuedAt,
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
func logVerificationToDB(
	displayCredID, fabricCredID, verifierID,
	result, failureReason string,
	chainOK, hashOK, sigOK, notRevoked bool,
	statusAtVerify string,
) {
	if db == nil {
		return
	}
	logID := fmt.Sprintf("VL-%d", time.Now().UnixMilli())
	_, err := db.Exec(
		`INSERT INTO verification_logs
		 (log_id, credential_id, fabric_cred_id, verifier_id,
		  result, failure_reason, chain_verified, hash_verified, signature_verified, status_at_verify)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		logID, displayCredID, fabricCredID, verifierID,
		result, failureReason, chainOK, hashOK, sigOK, statusAtVerify,
	)
	if err != nil {
		log.Printf("logVerificationToDB error: %v", err)
	}
}
