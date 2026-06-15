package main

// db_subscriptions.go — MySQL access for the `subscriptions` and `alerts` tables.
// Subscriptions: a verifier monitors a credential; the holder approves/rejects.
// Alerts: raised when a monitored credential changes status. Includes both the
// portal-side and QWallet-side (mobile) subscription queries, and the alert
// reads that feed the verifier dashboard.

import (
	"database/sql"
	"fmt"
	"log"
	"time"
)

// ─── SUBSCRIPTION TYPES ──────────────────────────────────────────────────────

// SubscriptionRow is the portal projection used by /getSubscriptions.
type SubscriptionRow struct {
	SubscriptionID string
	CredentialID   string
	HolderName     string
	HolderID       string
	CredentialType string
	Issuer         string
	SubscribedAt   sql.NullTime
	ExpiryDate     sql.NullTime
	Status         string
}

// MobileSubscriptionRow holds one subscription request for the QWallet
// ManageSubscriptions screen. (Distinct from the portal SubscriptionRow above.)
type MobileSubscriptionRow struct {
	SubscriptionID string
	CredentialID   string
	CredentialType string
	VerifierName   string
	Status         string
	CreatedAt      string
}

// AlertRow is the projection used by /getSubscriptionAlerts.
type AlertRow struct {
	AlertID        string
	CredentialID   string
	HolderName     string
	CredentialName string
	Severity       string
	Description    string
	TriggeredAt    time.Time
	Acknowledged   bool
}

// StatusAlertRow drives the verifier dashboard's statusAlerts list.
type StatusAlertRow struct {
	Name       string
	Credential string
	Event      string // UPPERCASE: REVOKED / SUSPENDED / EXPIRED
	Time       time.Time
}

// ─── SUBSCRIPTION QUERIES ────────────────────────────────────────────────────

// insertSubscription creates a pending subscription for a verifier (currently a
// fixed seed verifier) to monitor a credential owned by holderID.
func insertSubscription(subscriptionID, credentialID, holderID string) error {
	if db == nil {
		return fmt.Errorf("database not configured")
	}
	_, err := db.Exec(`
		INSERT INTO subscriptions (subscription_id, verifier_id, holder_id, credential_id, status, subscribed_at)
		VALUES (?, 'VER-UOS-0001', ?, ?, 'pending', NOW())`,
		subscriptionID, holderID, credentialID,
	)
	return err
}

// activeSubscriptionExists reports whether a credential already has a pending/active subscription.
func activeSubscriptionExists(credentialID string) (bool, error) {
	if db == nil {
		return false, fmt.Errorf("database not configured")
	}
	var count int
	err := db.QueryRow(`
		SELECT COUNT(*) FROM subscriptions
		 WHERE credential_id = ? AND status IN ('active','pending')`, credentialID).Scan(&count)
	return count > 0, err
}

// getSubscriptions lists subscriptions for the portal table (credential_type and
// issuer are derived via JOIN to the credential).
func getSubscriptions(page, limit int) ([]SubscriptionRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	offset := (page - 1) * limit
	rows, err := db.Query(`
		SELECT s.subscription_id,
		       COALESCE(s.credential_id, '') AS credential_id,
		       CONCAT_WS(' ', h.first_name, h.last_name) AS holder_name,
		       h.holder_id,
		       COALESCE(c.credential_type, '') AS credential_type,
		       COALESCE(i.full_name, '') AS issuer,
		       s.subscribed_at,
		       s.expiry_date,
		       s.status
		  FROM subscriptions s
		  JOIN credentials c ON s.credential_id = c.credential_id
		  JOIN holders     h ON s.holder_id     = h.holder_id
		  LEFT JOIN issuers i ON c.issuer_id    = i.issuer_id
		 ORDER BY s.created_at DESC
		 LIMIT ? OFFSET ?`, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []SubscriptionRow{}
	for rows.Next() {
		var r SubscriptionRow
		if err := rows.Scan(&r.SubscriptionID, &r.CredentialID, &r.HolderName, &r.HolderID,
			&r.CredentialType, &r.Issuer, &r.SubscribedAt, &r.ExpiryDate, &r.Status); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// getSubscriptionStatus returns the status of one subscription, or sql.ErrNoRows.
func getSubscriptionStatus(subscriptionID string) (string, error) {
	if db == nil {
		return "", fmt.Errorf("database not configured")
	}
	var status string
	err := db.QueryRow(`SELECT status FROM subscriptions WHERE subscription_id = ? LIMIT 1`, subscriptionID).Scan(&status)
	if err == sql.ErrNoRows {
		return "", sql.ErrNoRows
	}
	return status, err
}

// deleteSubscriptionRow removes a still-pending subscription.
func deleteSubscriptionRow(subscriptionID string) error {
	if db == nil {
		return fmt.Errorf("database not configured")
	}
	_, err := db.Exec(`DELETE FROM subscriptions WHERE subscription_id = ? AND status = 'pending'`, subscriptionID)
	return err
}

// unsubscribeSubscription ends an active subscription (status -> unsubscribed).
func unsubscribeSubscription(subscriptionID string) error {
	if db == nil {
		return fmt.Errorf("database not configured")
	}
	_, err := db.Exec(`
		UPDATE subscriptions SET status = 'unsubscribed', updated_at = NOW()
		 WHERE subscription_id = ? AND status = 'active'`, subscriptionID)
	return err
}

// getMobileSubscriptions returns all subscription requests addressed to the
// holder identified by their Emirates ID. The stored status 'active' is
// reported to the wallet as 'approved' so the Flutter SubscriptionModel sees
// the value it expects.
func getMobileSubscriptions(emiratesID string) ([]MobileSubscriptionRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	// credential_type is not stored on the subscription row (insertSubscription
	// leaves it NULL), so derive it from the linked credential — same as the
	// portal getSubscriptions query. Fall back to the column, then "".
	rows, err := db.Query(`
		SELECT s.subscription_id,
		       COALESCE(s.credential_id, '') AS credential_id,
		       COALESCE(c.credential_type, s.credential_type, '') AS credential_type,
		       COALESCE(v.full_name, 'Unknown Verifier') AS verifier_name,
		       s.status,
		       s.created_at
		  FROM subscriptions s
		  JOIN holders h   ON s.holder_id   = h.holder_id
		  JOIN verifiers v ON s.verifier_id = v.verifier_id
		  LEFT JOIN credentials c ON s.credential_id = c.credential_id
		 WHERE h.emirates_id = ?
		 ORDER BY s.created_at DESC`, emiratesID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []MobileSubscriptionRow{}
	for rows.Next() {
		var r MobileSubscriptionRow
		if err := rows.Scan(&r.SubscriptionID, &r.CredentialID, &r.CredentialType, &r.VerifierName, &r.Status, &r.CreatedAt); err != nil {
			return nil, err
		}
		if r.Status == "active" {
			r.Status = "approved"
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// updateSubscriptionStatus sets a pending subscription to 'active' (approve) or
// 'rejected' (reject). It verifies the subscription belongs to the given holder
// so a holder can never act on someone else's subscription. Returns whether a
// row was actually updated.
func updateSubscriptionStatus(subscriptionID, emiratesID, newStatus string) (bool, error) {
	if db == nil {
		return false, fmt.Errorf("database not configured")
	}
	result, err := db.Exec(`
		UPDATE subscriptions s
		  JOIN holders h ON s.holder_id = h.holder_id
		   SET s.status = ?
		 WHERE s.subscription_id = ?
		   AND h.emirates_id     = ?
		   AND s.status          = 'pending'`,
		newStatus, subscriptionID, emiratesID)
	if err != nil {
		return false, err
	}
	affected, _ := result.RowsAffected()
	return affected > 0, nil
}

// ─── ALERT QUERIES ───────────────────────────────────────────────────────────

// getAlerts lists all alerts (newest first) for the verifier dashboard.
func getAlerts() ([]AlertRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(`
		SELECT alert_id,
		       COALESCE(credential_id, '') AS credential_id,
		       COALESCE(holder_name, '') AS holder_name,
		       COALESCE(credential_name, '') AS credential_name,
		       severity,
		       COALESCE(description, '') AS description,
		       triggered_at,
		       acknowledged
		  FROM alerts
		 ORDER BY triggered_at DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []AlertRow{}
	for rows.Next() {
		var r AlertRow
		var ack int
		if err := rows.Scan(&r.AlertID, &r.CredentialID, &r.HolderName, &r.CredentialName,
			&r.Severity, &r.Description, &r.TriggeredAt, &ack); err != nil {
			return nil, err
		}
		r.Acknowledged = ack == 1
		out = append(out, r)
	}
	return out, rows.Err()
}

// acknowledgeAlert marks an alert as read.
func acknowledgeAlert(alertID string) error {
	if db == nil {
		return fmt.Errorf("database not configured")
	}
	_, err := db.Exec(`UPDATE alerts SET acknowledged = 1 WHERE alert_id = ?`, alertID)
	return err
}

// alertExists reports whether an alert with the given ID exists.
func alertExists(alertID string) (bool, error) {
	if db == nil {
		return false, fmt.Errorf("database not configured")
	}
	var count int
	err := db.QueryRow(`SELECT COUNT(*) FROM alerts WHERE alert_id = ?`, alertID).Scan(&count)
	return count > 0, err
}

// insertAlertForCredential creates a status-change alert row. Non-fatal on error.
func insertAlertForCredential(credentialID, credentialName, holderID, holderName, severity, description string) {
	if db == nil {
		return
	}
	alertID := generateAlertID()
	_, err := db.Exec(`
		INSERT INTO alerts (alert_id, holder_id, credential_id, credential_name, holder_name, description, severity)
		VALUES (?, ?, ?, ?, ?, ?, ?)`,
		alertID, nullIfEmpty(holderID), nullIfEmpty(credentialID),
		credentialName, holderName, description, severity,
	)
	if err != nil {
		log.Printf("insertAlertForCredential error: %v", err)
	}
}

// statusAlerts returns the latest unacknowledged alerts for subscribed
// credentials (from the alerts table), not every non-active credential.
func statusAlerts(limit int) ([]StatusAlertRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(`
		SELECT COALESCE(holder_name, '') AS name,
		       COALESCE(credential_name, '') AS credential,
		       UPPER(severity) AS event,
		       triggered_at AS event_time
		  FROM alerts
		 WHERE acknowledged = 0
		 ORDER BY triggered_at DESC
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
