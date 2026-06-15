package main

// httputil.go — small helpers shared by every HTTP handler.
//
// Go's standard library models an HTTP handler as a function with the signature
// `func(w http.ResponseWriter, r *http.Request)`: you read the request from `r`
// and write the response by calling methods on `w`. The helpers below remove the
// repetitive boilerplate of writing JSON and reading query params so each handler
// stays focused on its own logic.

import (
	"encoding/json"
	"net/http"
	"strconv"
)

// ErrorResponse is the JSON body returned for any error: {"error": "..."}.
// The `json:"error"` struct tag tells Go's JSON encoder to name the field
// "error" (lowercase) in the output instead of the Go field name "Error".
type ErrorResponse struct {
	Error string `json:"error"`
}

// writeJSON sets the Content-Type, writes the HTTP status code, and encodes `v`
// (any Go value — struct, map, slice) as JSON into the response body.
func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

// writeError writes a JSON error body with the given HTTP status code.
func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, ErrorResponse{Error: msg})
}

// decodeBody parses the JSON request body into `v` (pass a pointer, e.g. &req).
func decodeBody(r *http.Request, v any) error {
	return json.NewDecoder(r.Body).Decode(v)
}

// parsePositiveInt parses a query-string value into a positive int, returning
// `fallback` when the value is empty, non-numeric, or less than 1.
func parsePositiveInt(s string, fallback int) int {
	if s == "" {
		return fallback
	}
	v, err := strconv.Atoi(s)
	if err != nil || v < 1 {
		return fallback
	}
	return v
}

// firstNonEmpty returns the first non-empty string from its arguments, or "".
// The `...string` means it accepts any number of string arguments (variadic).
func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}
