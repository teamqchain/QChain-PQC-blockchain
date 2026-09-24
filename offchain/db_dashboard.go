package main

// db_dashboard.go — the dashboard's MySQL-only aggregates: verification counts
// and the verified-per-day series (verification_logs), and the unread-alerts
// counter (credential_events). Credential counts, expiry warnings and the
// issued-per-day series are computed from the chain in dashboard.go.

import "fmt"

// verificationCounters returns the total number of verifications and how many
// happened today.
func verificationCounters() (total, today int, err error) {
	if db == nil {
		return 0, 0, fmt.Errorf("database not configured")
	}
	// SUM(...) is wrapped in COALESCE so an empty table yields 0, not NULL.
	err = db.QueryRow(`
		SELECT
		  COUNT(*),
		  COALESCE(SUM(CASE WHEN DATE(verified_at) = CURDATE() THEN 1 ELSE 0 END), 0)
		FROM verification_logs`).Scan(&total, &today)
	return total, today, err
}

// alertsUnreadCount counts recent non-active status events (last 7 days).
func alertsUnreadCount() int {
	if db == nil {
		return 0
	}
	var n int
	_ = db.QueryRow(`
		SELECT COUNT(*) FROM credential_events
		 WHERE event_type IN ('revoked','suspended')
		   AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)`).Scan(&n)
	return n
}

// dailyVerified returns verification counts grouped by day-of-week for the last 7 days.
// Returns a map of "Mon"/"Tue"/... → count; caller (buildDailyChart) pads missing
// days to always produce a 7-entry array in Mon→Sun order.
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
