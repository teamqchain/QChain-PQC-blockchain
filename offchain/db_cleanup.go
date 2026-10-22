package main

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"strings"
)

// CleanupRequest defines the entity identifiers to remove after integration/performance testing.
type CleanupRequest struct {
	CredentialIDs []string `json:"credentialIDs"`
	HolderIDs     []string `json:"holderIDs"`
	EmiratesIDs   []string `json:"emiratesIDs"`
	StaffIDs      []string `json:"staffIDs"`
	StaffEmails   []string `json:"staffEmails"`
}

// sqlPlaceholders returns a string of comma-separated "?" placeholders.
func sqlPlaceholders(n int) string {
	if n <= 0 {
		return ""
	}
	return strings.Repeat("?,", n-1) + "?"
}

// stringArgs converts a slice of strings to []any for database/sql queries.
func stringArgs(items []string) []any {
	args := make([]any, len(items))
	for i, v := range items {
		args[i] = v
	}
	return args
}

// handleDevCleanupTest deletes test holders, credentials, alerts, subscriptions, and staff from MySQL.
// POST /dev/cleanupTest
func handleDevCleanupTest(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	var req CleanupRequest
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}

	if db == nil {
		writeJSON(w, http.StatusOK, map[string]any{
			"success": true,
			"warning": "database not connected, skipped MySQL cleanup",
		})
		return
	}

	tx, err := db.Begin()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to start transaction: "+err.Error())
		return
	}
	defer tx.Rollback()

	// 1. Resolve all Holder IDs from supplied holderIDs and emiratesIDs
	holderIDSet := make(map[string]struct{})
	for _, id := range req.HolderIDs {
		if trimmed := strings.TrimSpace(id); trimmed != "" {
			holderIDSet[trimmed] = struct{}{}
		}
	}
	if len(req.EmiratesIDs) > 0 {
		cleanEIDs := make([]string, 0, len(req.EmiratesIDs))
		for _, eid := range req.EmiratesIDs {
			if t := strings.TrimSpace(eid); t != "" {
				cleanEIDs = append(cleanEIDs, t)
			}
		}
		if len(cleanEIDs) > 0 {
			query := fmt.Sprintf("SELECT holder_id FROM holders WHERE emirates_id IN (%s)", sqlPlaceholders(len(cleanEIDs)))
			rows, err := tx.Query(query, stringArgs(cleanEIDs)...)
			if err == nil {
				for rows.Next() {
					var hid string
					if err := rows.Scan(&hid); err == nil && hid != "" {
						holderIDSet[hid] = struct{}{}
					}
				}
				rows.Close()
			}
		}
	}
	var allHolderIDs []string
	for hid := range holderIDSet {
		allHolderIDs = append(allHolderIDs, hid)
	}

	// 2. Resolve all Credential IDs (directly requested or belonging to the target holders)
	credIDSet := make(map[string]struct{})
	for _, cid := range req.CredentialIDs {
		if trimmed := strings.TrimSpace(cid); trimmed != "" {
			credIDSet[trimmed] = struct{}{}
		}
	}
	if len(allHolderIDs) > 0 {
		query := fmt.Sprintf("SELECT credential_id FROM credentials WHERE holder_id IN (%s)", sqlPlaceholders(len(allHolderIDs)))
		rows, err := tx.Query(query, stringArgs(allHolderIDs)...)
		if err == nil {
			for rows.Next() {
				var cid string
				if err := rows.Scan(&cid); err == nil && cid != "" {
					credIDSet[cid] = struct{}{}
				}
			}
			rows.Close()
		}
	}
	var allCredIDs []string
	for cid := range credIDSet {
		allCredIDs = append(allCredIDs, cid)
	}

	// 3. Delete dependent rows for credentials
	if len(allCredIDs) > 0 {
		ph := sqlPlaceholders(len(allCredIDs))
		args := stringArgs(allCredIDs)

		_, _ = tx.Exec(fmt.Sprintf("DELETE FROM alerts WHERE credential_id IN (%s)", ph), args...)
		_, _ = tx.Exec(fmt.Sprintf("DELETE FROM subscriptions WHERE credential_id IN (%s)", ph), args...)
		_, _ = tx.Exec(fmt.Sprintf("DELETE FROM credential_events WHERE credential_id IN (%s)", ph), args...)
		_, _ = tx.Exec(fmt.Sprintf("DELETE FROM verification_logs WHERE credential_id IN (%s)", ph), args...)
		_, _ = tx.Exec(fmt.Sprintf("DELETE FROM mobile_sessions WHERE credential_id IN (%s)", ph), args...)
		_, _ = tx.Exec(fmt.Sprintf("DELETE FROM batch_job_rows WHERE credential_id IN (%s)", ph), args...)
		_, _ = tx.Exec(fmt.Sprintf("DELETE FROM credentials WHERE credential_id IN (%s)", ph), args...)
	}

	// 4. Delete dependent rows for holders and holders themselves
	if len(allHolderIDs) > 0 {
		ph := sqlPlaceholders(len(allHolderIDs))
		args := stringArgs(allHolderIDs)

		_, _ = tx.Exec(fmt.Sprintf("DELETE FROM alerts WHERE holder_id IN (%s)", ph), args...)
		_, _ = tx.Exec(fmt.Sprintf("DELETE FROM subscriptions WHERE holder_id IN (%s)", ph), args...)
		_, _ = tx.Exec(fmt.Sprintf("DELETE FROM batch_job_rows WHERE holder_id IN (%s)", ph), args...)
		_, _ = tx.Exec(fmt.Sprintf("DELETE FROM mobile_sessions WHERE holder_id IN (%s)", ph), args...)
		_, _ = tx.Exec(fmt.Sprintf("DELETE FROM holders WHERE holder_id IN (%s)", ph), args...)
	}
	if len(req.EmiratesIDs) > 0 {
		cleanEIDs := make([]string, 0, len(req.EmiratesIDs))
		for _, eid := range req.EmiratesIDs {
			if t := strings.TrimSpace(eid); t != "" {
				cleanEIDs = append(cleanEIDs, t)
			}
		}
		if len(cleanEIDs) > 0 {
			_, _ = tx.Exec(fmt.Sprintf("DELETE FROM holders WHERE emirates_id IN (%s)", sqlPlaceholders(len(cleanEIDs))), stringArgs(cleanEIDs)...)
		}
	}

	// 5. Delete test staff
	var staffDeleted int64
	if len(req.StaffIDs) > 0 {
		res, err := tx.Exec(fmt.Sprintf("DELETE FROM staff WHERE id IN (%s)", sqlPlaceholders(len(req.StaffIDs))), stringArgs(req.StaffIDs)...)
		if err == nil {
			n, _ := res.RowsAffected()
			staffDeleted += n
		}
	}
	if len(req.StaffEmails) > 0 {
		res, err := tx.Exec(fmt.Sprintf("DELETE FROM staff WHERE email IN (%s) OR email LIKE 'e2e-staff-%%'", sqlPlaceholders(len(req.StaffEmails))), stringArgs(req.StaffEmails)...)
		if err == nil {
			n, _ := res.RowsAffected()
			staffDeleted += n
		}
	} else {
		res, err := tx.Exec("DELETE FROM staff WHERE email LIKE 'e2e-staff-%'")
		if err == nil {
			n, _ := res.RowsAffected()
			staffDeleted += n
		}
	}

	// Clean audit logs created by test staff actions
	_, _ = tx.Exec("DELETE FROM portal_audit_log WHERE details LIKE '%e2e-staff-%' OR details LIKE '%Benchmark%'")

	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to commit cleanup: "+err.Error())
		return
	}

	log.Printf("[Cleanup] Deleted %d credentials, %d holders, %d staff records", len(allCredIDs), len(allHolderIDs), staffDeleted)

	writeJSON(w, http.StatusOK, map[string]any{
		"success":            true,
		"deletedCredentials": len(allCredIDs),
		"deletedHolders":     len(allHolderIDs),
		"deletedStaff":       staffDeleted,
	})
}
