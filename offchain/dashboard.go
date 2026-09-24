package main

// dashboard.go — aggregated stats for the Issuer/Verifier/IT-Admin dashboards,
// plus the paginated audit-log endpoint.
//
// handleGetDashboardStats reads every credential from the chain in ONE batch
// call (summary view) and derives all credential numbers from it — counts by
// effective status, issued today, expiring soon, the issued-per-day chart —
// plus the credential labels in the activity and verification feeds. MySQL
// supplies only what it alone holds: verification counts, the event and alert
// feeds, and staff/audit figures. The chart helpers guarantee fixed-length
// series (7 days) so the UI never has gaps.

import (
	"fmt"
	"net/http"
	"sort"
	"time"
)

// expiringSoonDays is the look-ahead window for expiry warnings.
const expiringSoonDays = 30

// ExpiryWarningRow drives the dashboard expiryWarnings list.
type ExpiryWarningRow struct {
	Name       string
	Credential string
	DaysLeft   int
	expiry     string
}

// credentialStats is everything the dashboard derives from the chain snapshot.
type credentialStats struct {
	TotalIssued    int
	TotalRevoked   int
	TotalSuspended int
	TotalExpired   int
	IssuedToday    int
	ExpiringSoon   int
	ExpiryWarnings []ExpiryWarningRow // soonest first, at most 50
	DailyIssued    map[string]int     // "Mon".."Sun" → issued in the last 7 days
}

// daysBetween returns the number of calendar days from date a to date b
// (both YYYY-MM-DD), like MySQL DATEDIFF(b, a).
func daysBetween(a, b string) int {
	ta, errA := time.Parse("2006-01-02", a)
	tb, errB := time.Parse("2006-01-02", b)
	if errA != nil || errB != nil {
		return 0
	}
	return int(tb.Sub(ta).Hours() / 24)
}

// credentialStatsFromSnapshot computes the dashboard's credential figures.
// All dates are UAE calendar dates.
func credentialStatsFromSnapshot(snap *ChainSnapshot, now time.Time) credentialStats {
	dubai := mustLoadLocation("Asia/Dubai")
	today := dubaiDate(now)
	nowLocal := now.In(dubai)
	weekStart := time.Date(nowLocal.Year(), nowLocal.Month(), nowLocal.Day(), 0, 0, 0, 0, dubai).AddDate(0, 0, -7)

	stats := credentialStats{DailyIssued: map[string]int{}}
	for _, c := range snap.Credentials {
		stats.TotalIssued++
		status := effectiveStatus(c, now)
		switch status {
		case "revoked":
			stats.TotalRevoked++
		case "suspended":
			stats.TotalSuspended++
		case "expired":
			stats.TotalExpired++
		}
		if issued, ok := formatChainTime(c.IssuedAt); ok {
			if dubaiDate(issued) == today {
				stats.IssuedToday++
			}
			if !issued.Before(weekStart) {
				stats.DailyIssued[issued.Format("Mon")]++
			}
		}
		if status == "active" && c.ExpiryDate != "" {
			if daysLeft := daysBetween(today, c.ExpiryDate); daysLeft >= 0 && daysLeft <= expiringSoonDays {
				stats.ExpiringSoon++
				stats.ExpiryWarnings = append(stats.ExpiryWarnings, ExpiryWarningRow{
					Name:       snap.holderOf(c).FullName(),
					Credential: c.CredentialType,
					DaysLeft:   daysLeft,
					expiry:     c.ExpiryDate,
				})
			}
		}
	}
	sort.SliceStable(stats.ExpiryWarnings, func(i, j int) bool {
		a, b := stats.ExpiryWarnings[i], stats.ExpiryWarnings[j]
		if a.expiry != b.expiry {
			return a.expiry < b.expiry
		}
		return a.Name < b.Name
	})
	if len(stats.ExpiryWarnings) > 50 {
		stats.ExpiryWarnings = stats.ExpiryWarnings[:50]
	}
	return stats
}

// credentialLabel returns the on-chain type and holder name for a Fabric ID
// ("" when the credential is not in the snapshot).
func credentialLabel(snap *ChainSnapshot, fabricCredID string) (credentialType, holderName string) {
	c := snap.Credentials[fabricCredID]
	if c == nil {
		return "", ""
	}
	return c.CredentialType, snap.holderOf(c).FullName()
}

// GET /getDashboardStats — returns all fields used by Issuer + Verifier + IT Admin variants.
// Frontend variants pick the keys they need; backend returns everything in one trip.
func handleGetDashboardStats(w http.ResponseWriter, r *http.Request) {
	refs, err := listCredentialRefs()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "DB query failed: "+err.Error())
		return
	}
	fabricIDs := make([]string, 0, len(refs))
	for _, ref := range refs {
		fabricIDs = append(fabricIDs, ref.FabricCredID)
	}
	snap, err := chainReadCredentials(fabricIDs, viewSummary)
	if err != nil {
		writeError(w, http.StatusBadGateway, "blockchain read failed: "+err.Error())
		return
	}
	stats := credentialStatsFromSnapshot(snap, time.Now())

	totalVerified, verifiedToday, err := verificationCounters()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "DB query failed: "+err.Error())
		return
	}

	// Recent activity (issuance + status changes) — formatted via Go.
	events, _ := recentCredentialEvents(5)
	recentActivity := make([]map[string]any, 0, len(events))
	for _, e := range events {
		recentActivity = append(recentActivity, map[string]any{
			"text": eventToText(e, snap),
			"time": formatHumanTime(e.CreatedAt),
			"type": e.EventType,
		})
	}

	// Expiry warnings (active creds within 30 days).
	expiryOut := make([]map[string]any, 0, len(stats.ExpiryWarnings))
	for _, ew := range stats.ExpiryWarnings {
		expiryOut = append(expiryOut, map[string]any{
			"name":       ew.Name,
			"credential": ew.Credential,
			"daysLeft":   ew.DaysLeft,
		})
	}

	// Daily issued / verified (always 7 entries, Mon → Sun).
	dailyIssuedChart := buildDailyChart(stats.DailyIssued)
	dailyMap, _ := dailyVerified()
	daily := buildDailyChart(dailyMap)

	// Recent verifications (verifier dashboard).
	recentVerifs, _ := recentVerifications(5)
	recentVerifJSON := make([]map[string]any, 0, len(recentVerifs))
	for _, v := range recentVerifs {
		credentialType, holderName := credentialLabel(snap, v.FabricCredID)
		recentVerifJSON = append(recentVerifJSON, map[string]any{
			"credential": credentialType,
			"holderName": holderName,
			"status":     v.Status,
			"time":       formatHumanTime(v.VerifiedAt),
		})
	}

	// Status alerts (verifier dashboard) — snapshots taken when each alert was raised.
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
		"totalIssued":         stats.TotalIssued,
		"totalVerified":       totalVerified,
		"totalRevoked":        stats.TotalRevoked,
		"totalSuspended":      stats.TotalSuspended,
		"totalExpired":        stats.TotalExpired,
		"issuedToday":         stats.IssuedToday,
		"verifiedToday":       verifiedToday,
		"alertsUnread":        alertsUnreadCount(),
		"expiringSoon":        stats.ExpiringSoon,
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

// eventToText renders a credential event as a human sentence for the activity
// feed, labelling the credential with its on-chain type and holder name.
func eventToText(e EventRow, snap *ChainSnapshot) string {
	subject, holderName := credentialLabel(snap, e.FabricCredID)
	if subject == "" {
		subject = "Credential"
	}
	switch e.EventType {
	case "issued":
		return fmt.Sprintf("%s issued to %s", subject, holderName)
	case "revoked":
		return fmt.Sprintf("%s revoked — %s", subject, holderName)
	case "suspended":
		return fmt.Sprintf("%s suspended — %s", subject, holderName)
	case "restored":
		return fmt.Sprintf("%s restored — %s", subject, holderName)
	}
	return fmt.Sprintf("%s %s — %s", subject, e.EventType, holderName)
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
