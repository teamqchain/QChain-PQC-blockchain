package main

// commitment.go — what the issuer's ML-DSA-44 signature actually covers.
//
// The chain no longer stores the credential body. Instead each credential
// record holds a small COMMITMENT to it:
//
//	{ "v": 2, "holderID", "credentialType", "issuedAt", "issuerOrgID",
//	  "expiryDate", "cid", "fieldHashes": { "<key>": SHA3(salt:key:value) } }
//
// CredentialHash = SHA3-256(canonical JSON of that object), and the issuer signs
// the hex string of CredentialHash (the same convention pqcSign has always used).
// A verifier rebuilds the commitment from the on-chain fields and re-hashes it —
// it never trusts the stored CredentialHash — so changing ANY committed field on
// the ledger (type, holder, expiry, CID, a field hash) breaks the signature.
//
// Field hashes are salted: every field gets 16 random bytes, and only the holder
// learns the salts (they travel inside the holder-encrypted envelope under the
// reserved key "_salts"). Without a salt, a low-entropy value such as a grade or
// graduation year could be recovered from its hash by guessing.
//
// This file is shared by issuance, the expiry re-sign in /updateCredential, and
// presentation verification in /resolveSession.

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"time"
)

// commitmentVersion is the "v" inside every signed commitment. The chaincode
// stores it as CommitmentVersion; bump both if the commitment shape changes.
const commitmentVersion = 2

// saltsFieldKey is the reserved envelope field that carries the per-field salts
// to the holder. The wallet strips it before display (see the frontend handoff).
const saltsFieldKey = "_salts"

// fieldSaltBytes is the salt size; salts travel as 32 lowercase hex characters.
const fieldSaltBytes = 16

// maxCredentialFields bounds how many attributes one credential may carry.
const maxCredentialFields = 64

// reservedAttributeKeys are wallet/portal metadata names. The wallet never
// discloses a field with one of these names (presentationMetadataKeys in
// crypto_service.dart), so a credential attribute using one could never verify.
// "expiryDate" is not listed: issuance lifts it out into on-chain metadata.
var reservedAttributeKeys = map[string]bool{
	"credentialType": true,
	"credentialID":   true,
	"status":         true,
	"issuedBy":       true,
	"holderEID":      true,
	"holderName":     true,
	"issuedAt":       true,
	"issuer":         true,
	"holderId":       true,
	"holderID":       true,
}

// CredentialCommitment is the exact set of values the issuer signs.
type CredentialCommitment struct {
	HolderID       string
	CredentialType string
	IssuedAt       string // RFC3339, second precision, Asia/Dubai local (e.g. 2026-09-24T10:15:30+04:00)
	IssuerOrgID    string
	ExpiryDate     string // "" (no expiry) or YYYY-MM-DD
	CID            string
	FieldHashes    map[string]string
}

// commitmentCanonicalJSON renders the commitment deterministically: sorted keys
// (encoding/json sorts map keys at every level), no whitespace, no HTML
// escaping, and every key always present so an empty expiry is still covered.
func commitmentCanonicalJSON(c CredentialCommitment) (string, error) {
	fieldHashes := c.FieldHashes
	if fieldHashes == nil {
		fieldHashes = map[string]string{}
	}
	payload := map[string]any{
		"v":              commitmentVersion,
		"holderID":       c.HolderID,
		"credentialType": c.CredentialType,
		"issuedAt":       c.IssuedAt,
		"issuerOrgID":    c.IssuerOrgID,
		"expiryDate":     c.ExpiryDate,
		"cid":            c.CID,
		"fieldHashes":    fieldHashes,
	}
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(payload); err != nil {
		return "", fmt.Errorf("encode commitment: %w", err)
	}
	// Encoder.Encode appends a newline; it is not part of the canonical form.
	return strings.TrimSuffix(buf.String(), "\n"), nil
}

// commitmentHash returns SHA3-256(canonical commitment JSON) as lowercase hex.
func commitmentHash(c CredentialCommitment) (string, error) {
	canonical, err := commitmentCanonicalJSON(c)
	if err != nil {
		return "", err
	}
	return sha3Hex(canonical), nil
}

// signCommitment hashes the commitment and signs the hash with the issuer key.
// Returns (credentialHash, signatureHex).
func signCommitment(c CredentialCommitment, privateKeyHex string) (string, string, error) {
	hash, err := commitmentHash(c)
	if err != nil {
		return "", "", err
	}
	sig, err := pqcSign(hash, privateKeyHex)
	if err != nil {
		return "", "", fmt.Errorf("sign commitment: %w", err)
	}
	return hash, sig, nil
}

// commitmentFromChain rebuilds the signed commitment from an on-chain record.
func commitmentFromChain(c *ChainCredential) CredentialCommitment {
	return CredentialCommitment{
		HolderID:       c.Holder,
		CredentialType: c.CredentialType,
		IssuedAt:       c.IssuedAt,
		IssuerOrgID:    c.IssuerOrgID,
		ExpiryDate:     c.ExpiryDate,
		CID:            c.CID,
		FieldHashes:    c.FieldHashes,
	}
}

// ─────────────────────────────────────────────
//  SALTED FIELD HASHES
// ─────────────────────────────────────────────

// newFieldSalt returns a fresh random salt as 32 lowercase hex characters.
func newFieldSalt() (string, error) {
	b := make([]byte, fieldSaltBytes)
	if _, err := rand.Read(b); err != nil {
		return "", fmt.Errorf("random salt: %w", err)
	}
	return hex.EncodeToString(b), nil
}

// saltedFieldHash is the per-field fingerprint committed on-chain.
func saltedFieldHash(salt, key, value string) string {
	return sha3Hex(salt + ":" + key + ":" + value)
}

// isFieldSalt reports whether s is exactly 32 lowercase hex characters.
func isFieldSalt(s string) bool {
	if len(s) != 2*fieldSaltBytes {
		return false
	}
	for _, r := range s {
		if !(r >= '0' && r <= '9' || r >= 'a' && r <= 'f') {
			return false
		}
	}
	return true
}

// commitAttributes draws a salt for every attribute and returns the salts (for
// the holder's envelope) and the salted field hashes (for the chain).
func commitAttributes(attrs map[string]string) (salts, fieldHashes map[string]string, err error) {
	salts = make(map[string]string, len(attrs))
	fieldHashes = make(map[string]string, len(attrs))
	for key, value := range attrs {
		salt, err := newFieldSalt()
		if err != nil {
			return nil, nil, err
		}
		salts[key] = salt
		fieldHashes[key] = saltedFieldHash(salt, key, value)
	}
	return salts, fieldHashes, nil
}

// sortedKeys returns a map's keys in sorted order (deterministic error messages).
func sortedKeys[V any](m map[string]V) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

// validateDisclosureSalts checks the shape of a presentation: at least one
// disclosed field, a well-formed salt for every disclosed field, and no salt for
// any field that was not disclosed (sending one would leak it). The error text is
// returned to the wallet as-is.
func validateDisclosureSalts(disclosed, salts map[string]string) error {
	if len(disclosed) == 0 {
		return fmt.Errorf("disclosedFields must contain at least one field")
	}
	for _, key := range sortedKeys(disclosed) {
		salt, ok := salts[key]
		if !ok {
			return fmt.Errorf("salts missing for field %q", key)
		}
		if !isFieldSalt(salt) {
			return fmt.Errorf("invalid salt for field %q (want 32 lowercase hex characters)", key)
		}
	}
	for _, key := range sortedKeys(salts) {
		if _, ok := disclosed[key]; !ok {
			return fmt.Errorf("salt provided for undisclosed field %q", key)
		}
	}
	return nil
}

// verifyDisclosedFields checks every disclosed value against its on-chain
// salted field hash. Returns nil only if all of them match.
func verifyDisclosedFields(disclosed, salts, onChain map[string]string) error {
	if err := validateDisclosureSalts(disclosed, salts); err != nil {
		return err
	}
	for _, key := range sortedKeys(disclosed) {
		want, ok := onChain[key]
		if !ok {
			return fmt.Errorf("field %q is not part of this credential", key)
		}
		if saltedFieldHash(salts[key], key, disclosed[key]) != want {
			return fmt.Errorf("field %q does not match its on-chain hash", key)
		}
	}
	return nil
}

// ─────────────────────────────────────────────
//  ISSUANCE INPUT NORMALISATION
// ─────────────────────────────────────────────

// expiryInputLayouts are the non-RFC3339 expiry formats accepted from the
// portal: its display format ("30 Jun 2030"), plain ISO dates, and ISO
// date-times without a zone (a fractional second is accepted after the seconds
// even though the layout omits it). Values without a zone are UAE local time.
var expiryInputLayouts = []string{
	"2006-01-02",
	"02 Jan 2006",
	"2 Jan 2006",
	"2006-01-02T15:04:05",
	"2006-01-02 15:04:05",
}

// parseExpiryDate normalises an expiry input to YYYY-MM-DD (UAE calendar date),
// or "" when the input is blank (no expiry).
func parseExpiryDate(s string) (string, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return "", nil
	}
	dubai := mustLoadLocation("Asia/Dubai")
	if t, err := time.Parse(time.RFC3339, s); err == nil {
		return t.In(dubai).Format("2006-01-02"), nil
	}
	for _, layout := range expiryInputLayouts {
		if t, err := time.ParseInLocation(layout, s, dubai); err == nil {
			return t.Format("2006-01-02"), nil
		}
	}
	return "", fmt.Errorf("invalid expiryDate %q (use YYYY-MM-DD or DD Mon YYYY)", s)
}

// normalizeIssueAttributes parses the portal's `info` JSON into the attribute
// map that gets salted, hashed and encrypted, and lifts `expiryDate` out of it
// (expiry is on-chain metadata now, not an encrypted attribute).
func normalizeIssueAttributes(info string) (attrs map[string]string, expiry string, err error) {
	var raw map[string]json.RawMessage
	if err := json.Unmarshal([]byte(info), &raw); err != nil || raw == nil {
		return nil, "", fmt.Errorf("info must be a JSON object of field name to string value")
	}
	attrs = make(map[string]string, len(raw))
	for _, key := range sortedKeys(raw) {
		var value string
		if err := json.Unmarshal(raw[key], &value); err != nil || bytes.Equal(bytes.TrimSpace(raw[key]), []byte("null")) {
			return nil, "", fmt.Errorf("field %q must be a string", key)
		}
		if key == "expiryDate" {
			if expiry, err = parseExpiryDate(value); err != nil {
				return nil, "", err
			}
			continue
		}
		switch {
		case strings.TrimSpace(key) == "":
			return nil, "", fmt.Errorf("field names must not be empty")
		case strings.HasPrefix(key, "_"):
			return nil, "", fmt.Errorf("field %q: names starting with \"_\" are reserved", key)
		case reservedAttributeKeys[key]:
			return nil, "", fmt.Errorf("field %q: this name is reserved for credential metadata", key)
		}
		attrs[key] = value
	}
	if len(attrs) == 0 {
		return nil, "", fmt.Errorf("info must contain at least one credential field")
	}
	if len(attrs) > maxCredentialFields {
		return nil, "", fmt.Errorf("too many fields (%d, max %d)", len(attrs), maxCredentialFields)
	}
	return attrs, expiry, nil
}
