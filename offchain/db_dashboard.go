package main

// db_dashboard.go — cross-table aggregation queries that exist purely to build
// the dashboard: the top-line counters, the "expiring soon" list, and the
// issued/verified-per-day chart series. Queries tied to a single domain table
// (recent verifications, status alerts, staff breakdowns, audit) live in their
// own db_*.go files and are called by dashboard.go alongside these.

import "fmt"

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

// ExpiryWarningRow drives the dashboard expiryWarnings list.
type ExpiryWarningRow struct {
	Name       string
	Credential string
	DaysLeft   int
}

// ChartPoint is one bar in a chart series (label + value).
type ChartPoint struct {
	Label string
	Value int
}

// dashboardCounters computes the top-line dashboard numbers from the credentials,
// verification_logs and credential_events tables. SUM(...) is wrapped in COALESCE
// so an empty table yields 0 rather than SQL NULL (which can't scan into an int).
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
