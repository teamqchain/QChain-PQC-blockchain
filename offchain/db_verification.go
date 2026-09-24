package main

// db_verification.go — MySQL access for the `verification_logs` table: append a
// log row after each verify, page through history, count with filters, fetch a
// single log's detail, and the "recent verifications" widget for the dashboard.
// Rows carry the credential's Fabric ID; its type, holder name and dates are
// read from the chain by the handlers.

import (
	"database/sql"
	"fmt"
	"log"
	"time"
)

// VerificationRow is the projection used by /getVerificationHistory responses.
type VerificationRow struct {
	LogID         string
	CredentialID  string
	FabricCredID  string
	IssuerName    string
	Result        string // raw DB value (success/failure)
	FailureReason string
	Method        string // raw DB enum (qr_scan/manual/...)
	VerifiedBy    string
	VerifiedAt    time.Time
}

// VerificationDisplayRow drives the verifier dashboard's recentVerifications list.
type VerificationDisplayRow struct {
	FabricCredID string
	Status       string // UPPERCASE: VALID / REVOKED / SUSPENDED / EXPIRED / INVALID
	VerifiedAt   time.Time
}

// VerificationDetailRow is the full single-log projection for /getVerificationDetail.
// The sql.Null* fields model columns that may be NULL in older log rows.
type VerificationDetailRow struct {
	LogID          string
	VerifiedAt     time.Time
	CredentialID   string
	FabricCredID   string
	IssuerName     string
	Result         string
	FailureReason  sql.NullString
	Method         string
	VerifiedBy     string
	ChainVerified  sql.NullBool
	HashVerified   sql.NullBool
	SigVerified    sql.NullBool
	StatusAtVerify sql.NullString
}

// logVerificationToDB appends a row to verification_logs.
// Non-fatal: errors are logged but not returned.
// verifiedBy is a human-readable label (e.g. "System Verifier" or staff name) —
// distinct from verifierID which is the internal MySQL FK.
func logVerificationToDB(
	displayCredID, fabricCredID, verifierID, verifiedBy,
	result, failureReason string,
	chainOK, hashOK, sigOK bool,
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

// listVerificationHistoryPaginated returns one page of verification log rows.
// resultFilterDB is the raw DB value derived from the camelCase API filter (see verification.go mapping).
func listVerificationHistoryPaginated(resultFilterDB, failureReasonFilter string, page, limit int) ([]VerificationRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	offset := (page - 1) * limit
	if offset < 0 {
		offset = 0
	}
	query := `
		SELECT vl.log_id,
		       COALESCE(vl.credential_id, '') AS credential_id,
		       COALESCE(vl.fabric_cred_id, '') AS fabric_cred_id,
		       COALESCE(i.full_name, 'University of Sharjah') AS issuer_name,
		       vl.result, COALESCE(vl.failure_reason, '') AS failure_reason,
		       COALESCE(vl.verify_method, 'manual') AS method,
		       COALESCE(vl.verified_by, 'System Verifier') AS verified_by,
		       vl.verified_at
		  FROM verification_logs vl
		  LEFT JOIN credentials c ON vl.credential_id = c.credential_id
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
			&r.LogID, &r.CredentialID, &r.FabricCredID, &r.IssuerName,
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

// recentVerifications returns the last N verifications for the verifier dashboard.
func recentVerifications(limit int) ([]VerificationDisplayRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(`
		SELECT COALESCE(vl.fabric_cred_id, '') AS fabric_cred_id,
		       CASE
		         WHEN vl.result = 'success' THEN 'VALID'
		         WHEN vl.result = 'failure' AND vl.failure_reason = 'REVOKED'   THEN 'REVOKED'
		         WHEN vl.result = 'failure' AND vl.failure_reason = 'SUSPENDED' THEN 'SUSPENDED'
		         WHEN vl.result = 'failure' AND vl.failure_reason = 'EXPIRED'   THEN 'EXPIRED'
		         ELSE 'INVALID'
		       END AS status,
		       vl.verified_at
		  FROM verification_logs vl
		 ORDER BY vl.verified_at DESC
		 LIMIT ?`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []VerificationDisplayRow{}
	for rows.Next() {
		var r VerificationDisplayRow
		if err := rows.Scan(&r.FabricCredID, &r.Status, &r.VerifiedAt); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// getVerificationDetail returns the full detail for one verification log by ID.
func getVerificationDetail(logID string) (VerificationDetailRow, error) {
	var r VerificationDetailRow
	if db == nil {
		return r, fmt.Errorf("database not configured")
	}
	err := db.QueryRow(`
		SELECT vl.log_id, vl.verified_at,
		       COALESCE(vl.credential_id, '') AS credential_id,
		       COALESCE(vl.fabric_cred_id, '') AS fabric_cred_id,
		       COALESCE(i.full_name, '') AS issuer_name,
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
		  LEFT JOIN issuers     i ON c.issuer_id  = i.issuer_id
		 WHERE vl.log_id = ?
		 LIMIT 1`, logID).Scan(
		&r.LogID, &r.VerifiedAt, &r.CredentialID, &r.FabricCredID, &r.IssuerName,
		&r.Result, &r.FailureReason, &r.Method, &r.VerifiedBy,
		&r.ChainVerified, &r.HashVerified, &r.SigVerified, &r.StatusAtVerify,
	)
	if err == sql.ErrNoRows {
		return r, sql.ErrNoRows
	}
	return r, err
}
