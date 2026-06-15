package main

// db_util.go — small data-layer helpers shared across the db_*.go files:
// date/time formatting for JSON responses, a NULL-coalescing helper, and the
// MAX-based ID generators (AUD-/ALT-/STF-/SUB-...).
//
// These are deliberately separate from the queries so the query files stay
// focused on SQL.

import (
	"database/sql"
	"fmt"
	"strconv"
	"strings"
	"time"
)

// nullIfEmpty returns nil for an empty string (so it is stored as SQL NULL),
// otherwise the string itself. Returns `any` because database/sql treats a nil
// `any` as NULL.
func nullIfEmpty(s string) any {
	if s == "" {
		return nil
	}
	return s
}

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
// sql.NullTime models a DB column that may be NULL: it has a .Time and a .Valid flag.
func NullDateDisplay(nt sql.NullTime, fallback string) string {
	if !nt.Valid {
		return fallback
	}
	return FormatDateDisplay(nt.Time)
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
