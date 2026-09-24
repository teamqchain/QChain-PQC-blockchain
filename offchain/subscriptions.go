package main

// subscriptions.go — QPortal (verifier-side) subscription and alert endpoints.
//
// A verifier can subscribe to monitor a credential; if its status later changes,
// an alert is raised. These handlers create/list/delete subscriptions and
// list/acknowledge alerts. The QWallet (holder-side) approve/reject endpoints
// live in mobile.go.

import (
	"database/sql"
	"errors"
	"net/http"
)

// POST /requestSubscription — verifier asks to monitor a credential (status: pending).
// The revoked check uses the on-chain status.
func handleRequestSubscription(w http.ResponseWriter, r *http.Request) {
	var req struct {
		CredentialID string `json:"credentialID"`
	}
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	if req.CredentialID == "" {
		writeError(w, http.StatusBadRequest, "missing credentialID")
		return
	}
	ref, err := credentialRefByID(req.CredentialID)
	if err == sql.ErrNoRows {
		writeError(w, http.StatusNotFound, "credential not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	cred, _, err := chainReadCredential(ref.FabricCredID, viewSummary)
	if errors.Is(err, errChainNotFound) {
		writeError(w, http.StatusNotFound, "credential not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusBadGateway, "blockchain read failed: "+err.Error())
		return
	}
	if cred.Status == "revoked" {
		writeError(w, http.StatusBadRequest, "cannot subscribe to a revoked credential")
		return
	}
	exists, err := activeSubscriptionExists(ref.CredentialID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	if exists {
		writeError(w, http.StatusConflict, "subscription already exists for this credential")
		return
	}
	subID := generateSubscriptionID()
	if err := insertSubscription(subID, ref.CredentialID, ref.HolderID); err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"success": true, "subscriptionID": subID})
}

// GET /getSubscriptions?page=1&limit=100 — list subscriptions for the portal table.
// Credential type and holder name are read from the chain.
func handleGetSubscriptions(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	page := parsePositiveInt(q.Get("page"), 1)
	limit := parsePositiveInt(q.Get("limit"), 100)
	rows, err := getSubscriptions(page, limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	fabricIDs := make([]string, 0, len(rows))
	for _, s := range rows {
		fabricIDs = append(fabricIDs, s.FabricCredID)
	}
	snap, err := chainReadCredentials(fabricIDs, viewSummary)
	if err != nil {
		writeError(w, http.StatusBadGateway, "blockchain read failed: "+err.Error())
		return
	}
	out := make([]map[string]any, 0, len(rows))
	for _, s := range rows {
		credentialType, holderName := credentialLabel(snap, s.FabricCredID)
		out = append(out, map[string]any{
			"id":             s.SubscriptionID,
			"credentialID":   s.CredentialID,
			"holderName":     holderName,
			"holderID":       s.HolderID,
			"credentialType": credentialType,
			"issuer":         s.Issuer,
			"subscribedDate": NullDateDisplay(s.SubscribedAt, "—"),
			"expiryDate":     NullDateDisplay(s.ExpiryDate, "—"),
			"status":         s.Status,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"subscriptions": out})
}

// POST /deleteSubscription — remove a still-pending subscription.
func handleDeleteSubscription(w http.ResponseWriter, r *http.Request) {
	var req struct {
		SubscriptionID string `json:"subscriptionID"`
	}
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	if req.SubscriptionID == "" {
		writeError(w, http.StatusBadRequest, "missing subscriptionID")
		return
	}
	status, err := getSubscriptionStatus(req.SubscriptionID)
	if err == sql.ErrNoRows {
		writeError(w, http.StatusNotFound, "subscription not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	if status != "pending" {
		writeError(w, http.StatusBadRequest, "only pending subscriptions can be deleted")
		return
	}
	if err := deleteSubscriptionRow(req.SubscriptionID); err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"success": true, "subscriptionID": req.SubscriptionID})
}

// POST /unsubscribe — end an active subscription.
func handleUnsubscribe(w http.ResponseWriter, r *http.Request) {
	var req struct {
		SubscriptionID string `json:"subscriptionID"`
	}
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	if req.SubscriptionID == "" {
		writeError(w, http.StatusBadRequest, "missing subscriptionID")
		return
	}
	status, err := getSubscriptionStatus(req.SubscriptionID)
	if err == sql.ErrNoRows {
		writeError(w, http.StatusNotFound, "subscription not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	if status != "active" {
		writeError(w, http.StatusBadRequest, "only active subscriptions can be unsubscribed")
		return
	}
	if err := unsubscribeSubscription(req.SubscriptionID); err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"success": true, "subscriptionID": req.SubscriptionID})
}

// GET /getSubscriptionAlerts — list raised alerts for the verifier dashboard.
func handleGetSubscriptionAlerts(w http.ResponseWriter, r *http.Request) {
	rows, err := getAlerts()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	out := make([]map[string]any, 0, len(rows))
	for _, a := range rows {
		out = append(out, map[string]any{
			"id":             a.AlertID,
			"credentialID":   a.CredentialID,
			"holderName":     a.HolderName,
			"credentialName": a.CredentialName,
			"severity":       a.Severity,
			"description":    a.Description,
			"dateTime":       FormatDateTimeDisplay(a.TriggeredAt),
			"acknowledged":   a.Acknowledged,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"alerts": out})
}

// POST /acknowledgeAlert — mark an alert as read.
func handleAcknowledgeAlert(w http.ResponseWriter, r *http.Request) {
	var req struct {
		AlertID string `json:"alertID"`
	}
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	if req.AlertID == "" {
		writeError(w, http.StatusBadRequest, "missing alertID")
		return
	}
	exists, err := alertExists(req.AlertID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	if !exists {
		writeError(w, http.StatusNotFound, "alert not found")
		return
	}
	if err := acknowledgeAlert(req.AlertID); err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"success": true, "alertID": req.AlertID})
}
