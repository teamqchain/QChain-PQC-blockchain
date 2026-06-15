package main

// staff.go — portal staff management and the HR directory lookup.
//
// Handlers here list staff, return the org directory used by the Invite Staff
// dialog, and invite / re-role / soft-delete staff members. Role validation
// (which roles are allowed on which portal) lives in validateStaffRole.

import (
	"database/sql"
	"fmt"
	"net/http"
)

// GET /getStaff — list all staff members for the management table.
func handleGetStaff(w http.ResponseWriter, r *http.Request) {
	rows, err := getStaff()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	out := make([]map[string]any, 0, len(rows))
	for _, s := range rows {
		out = append(out, map[string]any{
			"id":        s.ID,
			"name":      s.Name,
			"email":     s.Email,
			"portal":    s.Portal,
			"role":      s.Role,
			"addedDate": FormatDateDisplay(s.AddedDate),
			"status":    s.Status,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"staff": out})
}

// handleGetDirectory returns the org HR employee list for the Invite Staff dialog.
func handleGetDirectory(w http.ResponseWriter, r *http.Request) {
	records, err := getOrgDirectory()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	out := make([]map[string]any, 0, len(records))
	for _, rec := range records {
		out = append(out, map[string]any{
			"name":  rec.Name,
			"email": rec.Email,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"directory": out})
}

// POST /inviteStaff — invite a new staff member (status starts as "invited").
func handleInviteStaff(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Email  string `json:"email"`
		Portal string `json:"portal"`
		Role   string `json:"role"`
	}
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	if req.Email == "" {
		writeError(w, http.StatusBadRequest, "missing email")
		return
	}
	if req.Portal == "" {
		writeError(w, http.StatusBadRequest, "missing portal")
		return
	}
	if req.Role == "" {
		writeError(w, http.StatusBadRequest, "missing role")
		return
	}
	if req.Portal != "issuer" && req.Portal != "verifier" {
		writeError(w, http.StatusBadRequest, "invalid portal")
		return
	}
	if req.Role == "admin" {
		writeError(w, http.StatusBadRequest, "admin role cannot be assigned via this endpoint")
		return
	}
	if err := validateStaffRole(req.Portal, req.Role); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	exists, err := staffEmailExists(req.Email)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	if exists {
		writeError(w, http.StatusConflict, "email already invited or active")
		return
	}
	staffID := generateStaffID()
	if err := insertStaff(staffID, req.Email, req.Portal, req.Role); err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	insertAuditLog("staff_added",
		fmt.Sprintf("Staff %s invited to %s portal as %s", req.Email, req.Portal, req.Role),
		issuerActorName, "Issuer Admin", r.RemoteAddr)
	writeJSON(w, http.StatusOK, map[string]any{"success": true, "staffID": staffID})
}

// POST /updateStaffRole — change an existing staff member's role.
func handleUpdateStaffRole(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ID     string `json:"id"`
		Portal string `json:"portal"`
		Role   string `json:"role"`
	}
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	if req.ID == "" {
		writeError(w, http.StatusBadRequest, "missing id")
		return
	}
	if req.Portal == "" {
		writeError(w, http.StatusBadRequest, "missing portal")
		return
	}
	if req.Role == "" {
		writeError(w, http.StatusBadRequest, "missing role")
		return
	}
	if req.Portal != "issuer" && req.Portal != "verifier" {
		writeError(w, http.StatusBadRequest, "invalid portal")
		return
	}
	if req.Role == "admin" {
		writeError(w, http.StatusBadRequest, "admin role cannot be modified via this endpoint")
		return
	}
	if err := validateStaffRole(req.Portal, req.Role); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if _, err := getStaffByID(req.ID); err == sql.ErrNoRows {
		writeError(w, http.StatusNotFound, "staff member not found")
		return
	} else if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	if err := updateStaffRole(req.ID, req.Portal, req.Role); err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"success": true, "staffID": req.ID})
}

// POST /deleteStaff — soft-delete a staff member (marks status deleted).
func handleDeleteStaff(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ID     string `json:"id"`
		Portal string `json:"portal"`
	}
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	if req.ID == "" {
		writeError(w, http.StatusBadRequest, "missing id")
		return
	}
	if req.Portal == "" {
		writeError(w, http.StatusBadRequest, "missing portal")
		return
	}
	if req.Portal != "issuer" && req.Portal != "verifier" {
		writeError(w, http.StatusBadRequest, "invalid portal")
		return
	}
	staff, err := getStaffByID(req.ID)
	if err == sql.ErrNoRows {
		writeError(w, http.StatusNotFound, "staff member not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	if staff.Portal != req.Portal {
		writeError(w, http.StatusBadRequest, "portal mismatch")
		return
	}
	if err := softDeleteStaff(req.ID); err != nil {
		writeError(w, http.StatusInternalServerError, "database error")
		return
	}
	insertAuditLog("staff_removed",
		fmt.Sprintf("Staff %s removed from %s portal", staff.Email, req.Portal),
		issuerActorName, "Issuer Admin", r.RemoteAddr)
	writeJSON(w, http.StatusOK, map[string]any{"success": true, "staffID": req.ID})
}

// validateStaffRole returns an error if `role` is not allowed for `portal`.
// Issuer portal: staff|schemaManager. Verifier portal: verifier|policyManager.
func validateStaffRole(portal, role string) error {
	if portal == "issuer" {
		switch role {
		case "staff", "schemaManager":
			return nil
		}
		return fmt.Errorf("invalid role for portal")
	}
	switch role {
	case "verifier", "policyManager":
		return nil
	}
	return fmt.Errorf("invalid role for portal")
}
