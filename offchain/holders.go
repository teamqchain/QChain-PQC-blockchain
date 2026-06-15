package main

// holders.go — the holder search endpoint and its enum mapping helpers.
//
// The API uses camelCase holder types ("bachelorStudent") while the database
// stores snake_case enums ("bachelor_student"); the two helpers translate
// between them so the frontend and the DB schema can each use their own style.

import "net/http"

// GET /getHolders?search=Ahmed&type=bachelorStudent
func handleGetHolders(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	search := q.Get("search")

	// Map the camelCase API value to the DB ENUM value. Unknown → no filter.
	typeAPI := q.Get("type")
	typeDB := holderTypeAPIToDB(typeAPI)

	rows, err := searchHolders(search, typeDB)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "DB query failed: "+err.Error())
		return
	}

	out := make([]map[string]any, 0, len(rows))
	for _, r := range rows {
		out = append(out, map[string]any{
			"holderID":   r.HolderID,
			"fullName":   r.FullName,
			"email":      r.Email,
			"emiratesID": r.EmiratesID,
			"type":       holderTypeDBToAPI(r.HolderType),
			"college":    r.College,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"holders": out,
		"total":   len(out),
	})
}

// holderTypeAPIToDB maps a camelCase API holder type to the DB ENUM value,
// returning "" (no filter) for unknown values.
func holderTypeAPIToDB(api string) string {
	switch api {
	case "bachelorStudent":
		return "bachelor_student"
	case "masterStudent":
		return "master_student"
	case "phdStudent":
		return "phd_student"
	case "employee":
		return "employee"
	case "medical":
		return "medical"
	}
	return ""
}

// holderTypeDBToAPI maps a DB ENUM holder type back to camelCase, defaulting to
// "bachelorStudent" per the V3 doc when the value is missing/unknown.
func holderTypeDBToAPI(db string) string {
	switch db {
	case "bachelor_student":
		return "bachelorStudent"
	case "master_student":
		return "masterStudent"
	case "phd_student":
		return "phdStudent"
	case "employee":
		return "employee"
	case "medical":
		return "medical"
	}
	return "bachelorStudent" // fallback per V3 doc
}
