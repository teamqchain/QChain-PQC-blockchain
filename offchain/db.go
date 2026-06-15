package main

// db.go — the database connection itself and the display-ID sequence counters.
//
// This file owns the package-wide `db` handle and initDB (called once from
// main). All the actual queries live in the domain files db_holders.go,
// db_credentials.go, db_verification.go, db_dashboard.go, db_audit.go,
// db_subscriptions.go, db_staff.go and db_mobile.go — they all use this `db`.
//
// Design note: every query function guards `if db == nil` and degrades to a
// warning rather than crashing, so the server still boots when MYSQL_DSN is unset.

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"strings"
	"sync/atomic"
	"time"

	// The blank import (`_`) registers the MySQL driver with database/sql for its
	// side effects; we never call it by name, so the underscore avoids an
	// "imported and not used" error.
	_ "github.com/go-sql-driver/mysql"
)

// db is the shared connection pool used by every db_*.go query function.
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
// atomic.AddUint64 increments the shared counter safely even under concurrent requests.
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
