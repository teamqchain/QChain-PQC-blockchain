package main

// holders.go — the holder search endpoint and its enum mapping helpers.
//
// The API uses camelCase holder types ("bachelorStudent") while the database
// stores snake_case enums ("bachelor_student"); the two helpers translate
// between them so the frontend and the DB schema can each use their own style.

import (
	"net/http"
	"sort"
	"strings"
)

// GET /getHolders?search=Ahmed&type=bachelorStudent
//
// MySQL supplies the holder set plus email / Emirates ID / type / college;
// the name and wallet-activation state come from the chain. Search is a
// case-insensitive substring match over name, Emirates ID, email and holder ID.
func handleGetHolders(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	search := strings.ToLower(strings.TrimSpace(q.Get("search")))

	// Map the camelCase API value to the DB ENUM value. Unknown → no filter.
	typeDB := holderTypeAPIToDB(q.Get("type"))

	refs, err := listHolderRefs(typeDB)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "DB query failed: "+err.Error())
		return
	}
	ids := make([]string, 0, len(refs))
	for _, ref := range refs {
		ids = append(ids, ref.FabricHolderID)
	}
	chainHolders, err := chainReadHolders(ids, viewSummary)
	if err != nil {
		writeError(w, http.StatusBadGateway, "blockchain read failed: "+err.Error())
		return
	}

	type match struct {
		ref    HolderRef
		holder *ChainHolder
	}
	var missing []string
	matches := make([]match, 0, len(refs))
	for _, ref := range refs {
		h := chainHolders[ref.FabricHolderID]
		if h == nil {
			missing = append(missing, ref.HolderID)
			continue
		}
		if search != "" && !containsFold(search, h.FullName(), ref.EmiratesID, ref.Email, ref.HolderID) {
			continue
		}
		matches = append(matches, match{ref, h})
	}
	logMissingOnChain("getHolders", missing)
	sort.SliceStable(matches, func(i, j int) bool {
		a, b := matches[i].holder, matches[j].holder
		if !strings.EqualFold(a.FirstName, b.FirstName) {
			return strings.ToLower(a.FirstName) < strings.ToLower(b.FirstName)
		}
		return strings.ToLower(a.LastName) < strings.ToLower(b.LastName)
	})

	out := make([]map[string]any, 0, len(matches))
	for _, m := range matches {
		out = append(out, map[string]any{
			"holderID":          m.ref.HolderID,
			"fullName":          m.holder.FullName(),
			"email":             m.ref.Email,
			"emiratesID":        m.ref.EmiratesID,
			"type":              holderTypeDBToAPI(m.ref.HolderType),
			"college":           m.ref.College,
			"isWalletActivated": m.holder.WalletActivated(),
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"holders": out,
		"total":   len(out),
	})
}

// containsFold reports whether any value contains the lower-cased needle.
func containsFold(needleLower string, values ...string) bool {
	for _, v := range values {
		if strings.Contains(strings.ToLower(v), needleLower) {
			return true
		}
	}
	return false
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
