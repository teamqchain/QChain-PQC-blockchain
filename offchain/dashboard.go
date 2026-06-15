package main

// dashboard.go — aggregated stats for the Issuer/Verifier/IT-Admin dashboards,
// plus the paginated audit-log endpoint.
//
// handleGetDashboardStats runs many small DB queries (counts, charts, recent
// activity, alerts, staff breakdowns) and assembles them into one JSON object so
// the frontend can populate an entire dashboard in a single request. The chart
// helpers guarantee fixed-length series (7 days) so the UI never has gaps.

import (
	"fmt"
	"net/http"
)

// GET /getDashboardStats — returns all fields used by Issuer + Verifier + IT Admin variants.
// Frontend variants pick the keys they need; backend returns everything in one trip.
func handleGetDashboardStats(w http.ResponseWriter, r *http.Request) {
	counters, err := dashboardCounters()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "DB query failed: "+err.Error())
		return
	}

	// Recent activity (issuance + status changes) — formatted via Go.
	events, _ := recentCredentialEvents(5)
	recentActivity := make([]map[string]any, 0, len(events))
	for _, e := range events {
		recentActivity = append(recentActivity, map[string]any{
			"text": eventToText(e),
			"time": formatHumanTime(e.CreatedAt),
			"type": e.EventType,
		})
	}

	// Expiry warnings (active creds within 30 days).
	warns, _ := expiryWarnings()
	expiryOut := make([]map[string]any, 0, len(warns))
	for _, w := range warns {
		expiryOut = append(expiryOut, map[string]any{
			"name":       w.Name,
			"credential": w.Credential,
			"daysLeft":   w.DaysLeft,
		})
	}

	// Daily issued (always 7 entries, Mon → Sun — replaces weeklyIssued).
	dailyIssuedMap, _ := dailyIssued()
	dailyIssuedChart := buildDailyChart(dailyIssuedMap)

	// Daily verified (always 7 entries, Mon → Sun).
	dailyMap, _ := dailyVerified()
	daily := buildDailyChart(dailyMap)

	// Recent verifications (verifier dashboard).
	recentVerifs, _ := recentVerifications(5)
	recentVerifJSON := make([]map[string]any, 0, len(recentVerifs))
	for _, v := range recentVerifs {
		recentVerifJSON = append(recentVerifJSON, map[string]any{
			"credential": v.Credential,
			"holderName": v.HolderName,
			"status":     v.Status,
			"time":       formatHumanTime(v.VerifiedAt),
		})
	}

	// Status alerts (verifier dashboard).
	statusAlertRows, _ := statusAlerts(10)
	alertsJSON := make([]map[string]any, 0, len(statusAlertRows))
	for _, a := range statusAlertRows {
		alertsJSON = append(alertsJSON, map[string]any{
			"name":       a.Name,
			"credential": a.Credential,
			"event":      a.Event,
			"time":       formatHumanTime(a.Time),
		})
	}

	// IT Admin fields.
	issuerCount, verifierCount, _ := staffCounts()
	adminTotal, adminActive, adminInvited, _ := staffTotals()
	issuerRoles, _ := staffRoleBreakdown("issuer")
	verifierRoles, _ := staffRoleBreakdown("verifier")
	recentAudit, _ := recentAuditLogs(10)

	issuerRolesJSON := make([]map[string]any, 0, len(issuerRoles))
	for _, rc := range issuerRoles {
		issuerRolesJSON = append(issuerRolesJSON, map[string]any{"label": rc.Label, "count": rc.Count})
	}
	verifierRolesJSON := make([]map[string]any, 0, len(verifierRoles))
	for _, rc := range verifierRoles {
		verifierRolesJSON = append(verifierRolesJSON, map[string]any{"label": rc.Label, "count": rc.Count})
	}
	recentAuditJSON := make([]map[string]any, 0, len(recentAudit))
	for _, a := range recentAudit {
		recentAuditJSON = append(recentAuditJSON, map[string]any{
			"action":      a.Action,
			"details":     a.Details,
			"role":        a.Role,
			"performedBy": a.PerformedBy,
			"timestamp":   FormatISO(a.Timestamp),
		})
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"totalIssued":         counters.TotalIssued,
		"totalVerified":       counters.TotalVerified,
		"totalRevoked":        counters.TotalRevoked,
		"totalSuspended":      counters.TotalSuspended,
		"totalExpired":        counters.TotalExpired,
		"issuedToday":         counters.IssuedToday,
		"verifiedToday":       counters.VerifiedToday,
		"alertsUnread":        counters.AlertsUnread,
		"expiringSoon":        counters.ExpiringSoon,
		"recentActivity":      recentActivity,
		"expiryWarnings":      expiryOut,
		"dailyIssued":         dailyIssuedChart,
		"recentVerifications": recentVerifJSON,
		"statusAlerts":        alertsJSON,
		"dailyVerified":       daily,
		"issuerStaffCount":    issuerCount,
		"verifierStaffCount":  verifierCount,
		"adminTotalStaff":     adminTotal,
		"adminActiveStaff":    adminActive,
		"adminInvitedStaff":   adminInvited,
		"issuerRoles":         issuerRolesJSON,
		"verifierRoles":       verifierRolesJSON,
		"recentAudit":         recentAuditJSON,
	})
}

// GET /getAuditLogs?page=1&limit=500 — full audit trail for the IT-Admin screen.
func handleGetAuditLogs(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	page := parsePositiveInt(q.Get("page"), 1)
	limit := parsePositiveInt(q.Get("limit"), 500)
	rows, err := getAuditLogs(page, limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	out := make([]map[string]any, 0, len(rows))
	for _, a := range rows {
		out = append(out, map[string]any{
			"id":              a.AuditID,
			"action":          a.Action,
			"details":         a.Details,
			"performedBy":     a.PerformedByName,
			"performedByRole": a.PerformedByRole,
			"ipAddress":       a.IPAddress,
			"timestamp":       FormatISO(a.CreatedAt),
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"records": out})
}

// ─────────────────────────────────────────────
//  DASHBOARD FORMATTING HELPERS
// ─────────────────────────────────────────────

// eventToText renders a credential event as a human sentence for the activity feed.
func eventToText(e EventRow) string {
	subject := e.CredentialType
	if subject == "" {
		subject = "Credential"
	}
	switch e.EventType {
	case "issued":
		return fmt.Sprintf("%s issued to %s", subject, e.HolderName)
	case "revoked":
		return fmt.Sprintf("%s revoked — %s", subject, e.HolderName)
	case "suspended":
		return fmt.Sprintf("%s suspended — %s", subject, e.HolderName)
	case "restored":
		return fmt.Sprintf("%s restored — %s", subject, e.HolderName)
	}
	return fmt.Sprintf("%s %s — %s", subject, e.EventType, e.HolderName)
}

// buildWeeklyChart converts raw YEARWEEK rows into the doc's 4-entry "Wk 1"..."Wk 4"
// shape. Oldest week becomes "Wk 1". If fewer than 4 weeks have data, missing entries
// are padded with value=0 at the START (so the newest week stays as "Wk 4").
func buildWeeklyChart(raw []ChartPoint) []map[string]any {
	// Order raw oldest → newest (already ordered by SQL).
	values := make([]int, 4)
	// Take last up-to-4 entries.
	start := len(raw) - 4
	if start < 0 {
		start = 0
	}
	rawWindow := raw[start:]
	// Right-align into the 4-slot array so the newest week is in slot 3.
	offset := 4 - len(rawWindow)
	for i, p := range rawWindow {
		values[offset+i] = p.Value
	}
	out := make([]map[string]any, 4)
	for i := 0; i < 4; i++ {
		out[i] = map[string]any{
			"label": fmt.Sprintf("Wk %d", i+1),
			"value": values[i],
		}
	}
	return out
}

// buildDailyChart returns exactly 7 entries Mon→Sun, padding missing days with value=0.
func buildDailyChart(counts map[string]int) []map[string]any {
	order := []string{"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"}
	out := make([]map[string]any, 0, 7)
	for _, day := range order {
		out = append(out, map[string]any{
			"label": day,
			"value": counts[day],
		})
	}
	return out
}
