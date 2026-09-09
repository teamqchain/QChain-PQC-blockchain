package main

// envelope.go — Track B2 (Phase 2) per-field envelope encryption for the
// OFF-CHAIN credential body, using HOLDER-HELD KEYS.
//
// WHAT THIS DOES (and does not do):
//   • It encrypts the credential attribute payload (the inner `info` JSON that is
//     stored in IPFS and in the MySQL `credential_data` column) so those two
//     off-chain stores no longer hold plaintext at rest.
//   • Each credential is encrypted to the HOLDER's ML-KEM-768 public key, not to
//     an organisation key. Only the holder (or, during testing, the server with
//     the holder's private key from .env.holder_keys) can decrypt it.
//   • It does NOT change anything on-chain. The chaincode, the on-chain `Info`
//     field (still plaintext), the SHA3-256 hash, the ML-DSA-44 signature, and the
//     verification flow are untouched. On-chain confidentiality is deferred to
//     Track A (see the handoff doc).
//
// The envelope is a versioned JSON object with per-field ciphertexts. The
// recipient is "holder:<holderID>" so the envelope is cryptographically bound to
// one specific holder. A future phase can add verifier re-wrapping (Track B3).
//
// Format (stored in IPFS and in credential_data):
//   {
//     "_qc_env": "qchain-env", "v": 1,
//     "kemAlg": "ML-KEM-768", "aeadAlg": "AES-256-GCM", "kdf": "HKDF-SHA3-256",
//     "credId": "<hkdf context id>",
//     "wraps":  [ { "recipient": "holder:H-0001", "kemCt": "<hex>" } ],
//     "fields": [ { "key": "gpa", "nonce": "<hex>", "ct": "<hex>",
//                   "wrap": { "holder:H-0001": "<hex wrapped per-field key>" } } ]
//   }

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"strings"
)

const (
	envelopeMagic         = "qchain-env" // marker distinguishing an envelope from legacy plaintext JSON
	envelopeVersion       = 1
	recipientHolderPrefix = "holder:" // B2: holder-held key recipient prefix
	recipientOrg          = "org"     // legacy B3 org-key recipient (for backward-compat reads only)
)

// holderRecipientName returns the envelope recipient name for a given holder ID.
func holderRecipientName(holderID string) string {
	return recipientHolderPrefix + holderID
}

// KemWrap is one recipient's ML-KEM encapsulation of the shared secret.
type KemWrap struct {
	Recipient string `json:"recipient"`
	KemCt     string `json:"kemCt"`
}

// EncField is one encrypted attribute field.
type EncField struct {
	Key   string            `json:"key"`
	Nonce string            `json:"nonce"`
	Ct    string            `json:"ct"`
	Wrap  map[string]string `json:"wrap"` // recipient -> hex-wrapped per-field data key
}

// Envelope is the full off-chain encrypted body.
type Envelope struct {
	Magic   string     `json:"_qc_env"`
	V       int        `json:"v"`
	KemAlg  string     `json:"kemAlg"`
	AeadAlg string     `json:"aeadAlg"`
	Kdf     string     `json:"kdf"`
	CredID  string     `json:"credId,omitempty"`
	Wraps   []KemWrap  `json:"wraps"`
	Fields  []EncField `json:"fields"`
}

// Recipient is a named ML-KEM public key an envelope is sealed to.
type Recipient struct {
	Name   string
	PubHex string
}

// looksLikeEnvelope reports whether stored bytes are a QChain envelope rather
// than legacy plaintext attribute JSON. Used so read paths transparently handle
// both encrypted (new) and plaintext (pre-Track-B) rows.
func looksLikeEnvelope(b []byte) bool {
	var probe struct {
		Magic string `json:"_qc_env"`
	}
	if err := json.Unmarshal(b, &probe); err != nil {
		return false
	}
	return probe.Magic == envelopeMagic
}

// sealAttributes builds a per-field envelope over attrs, wrapped to every
// recipient. credID is only an HKDF context binding (any stable per-credential
// string works; issuance passes the credential hash).
func sealAttributes(credID string, attrs map[string]json.RawMessage, recipients []Recipient) (*Envelope, error) {
	if len(recipients) == 0 {
		return nil, fmt.Errorf("sealAttributes: no recipients")
	}
	env := &Envelope{
		Magic:   envelopeMagic,
		V:       envelopeVersion,
		KemAlg:  kemName,
		AeadAlg: "AES-256-GCM",
		Kdf:     "HKDF-SHA3-256",
		CredID:  credID,
	}
	ss := make(map[string]string, len(recipients)) // recipient -> shared secret hex
	for _, r := range recipients {
		kemCt, s, err := kemEncap(r.PubHex)
		if err != nil {
			return nil, fmt.Errorf("encapsulate to %q: %w", r.Name, err)
		}
		env.Wraps = append(env.Wraps, KemWrap{Recipient: r.Name, KemCt: kemCt})
		ss[r.Name] = s
	}
	for key, val := range attrs {
		dataKey := make([]byte, 32)
		if _, err := io.ReadFull(rand.Reader, dataKey); err != nil {
			return nil, fmt.Errorf("random data key: %w", err)
		}
		nonce, ct, err := aesSeal(hex.EncodeToString(dataKey), val)
		if err != nil {
			return nil, fmt.Errorf("encrypt field %q: %w", key, err)
		}
		f := EncField{Key: key, Nonce: nonce, Ct: ct, Wrap: map[string]string{}}
		for _, r := range recipients {
			kwk, err := deriveKey(ss[r.Name], fmt.Sprintf("qchain/trackB/v1|%s|%s", credID, key))
			if err != nil {
				return nil, err
			}
			w, err := wrapKey(kwk, dataKey)
			if err != nil {
				return nil, err
			}
			f.Wrap[r.Name] = w
		}
		env.Fields = append(env.Fields, f)
	}
	return env, nil
}

// openAttributes decrypts every field of an envelope as the named recipient.
func openAttributes(env *Envelope, recipient, kemSecHex string) (map[string]json.RawMessage, error) {
	var kemCt string
	for _, w := range env.Wraps {
		if w.Recipient == recipient {
			kemCt = w.KemCt
			break
		}
	}
	if kemCt == "" {
		return nil, fmt.Errorf("envelope has no wrap for recipient %q", recipient)
	}
	ssHex, err := kemDecap(kemCt, kemSecHex)
	if err != nil {
		return nil, err
	}
	out := make(map[string]json.RawMessage, len(env.Fields))
	for _, f := range env.Fields {
		wrap, ok := f.Wrap[recipient]
		if !ok {
			return nil, fmt.Errorf("field %q has no wrap for recipient %q", f.Key, recipient)
		}
		kwk, err := deriveKey(ssHex, fmt.Sprintf("qchain/trackB/v1|%s|%s", env.CredID, f.Key))
		if err != nil {
			return nil, err
		}
		dataKey, err := unwrapKey(kwk, wrap)
		if err != nil {
			return nil, fmt.Errorf("unwrap field %q: %w", f.Key, err)
		}
		val, err := aesOpen(hex.EncodeToString(dataKey), f.Nonce, f.Ct)
		if err != nil {
			return nil, fmt.Errorf("decrypt field %q: %w", f.Key, err)
		}
		out[f.Key] = json.RawMessage(val)
	}
	return out, nil
}

// ─────────────────────────────────────────────
//  HIGH-LEVEL HELPERS used by issuance and read paths
// ─────────────────────────────────────────────

// encryptCredentialData converts a plaintext attribute JSON string into an
// envelope JSON string wrapped to the HOLDER's ML-KEM-768 public key.
//
// holderID identifies the holder (used as part of the recipient name in the
// envelope). holderKemPubHex is the holder's ML-KEM-768 public key, looked up
// from the `holders.kem_public_key` column at issuance time.
//
// If holderKemPubHex is empty, encryption fails with an error — a holder key is
// required for issuance under Track B2.
//
// credID is an HKDF context binding — issuance passes the credential hash.
func encryptCredentialData(credID, attrsJSON, holderID, holderKemPubHex string) (string, error) {
	if holderKemPubHex == "" {
		return "", fmt.Errorf("holder %q has no KEM public key — register a key before issuing", holderID)
	}
	attrs, err := splitFields(attrsJSON)
	if err != nil {
		return "", err
	}
	recipientName := holderRecipientName(holderID)
	env, err := sealAttributes(credID, attrs, []Recipient{{Name: recipientName, PubHex: holderKemPubHex}})
	if err != nil {
		return "", err
	}
	b, err := json.Marshal(env)
	if err != nil {
		return "", err
	}
	return string(b), nil
}

// decryptCredentialData reverses encryptCredentialData. Legacy plaintext rows
// (no envelope marker) pass through untouched, so old and new credentials coexist.
//
// It first looks for a "holder:<holderID>" wrap and decrypts with holderKemPrivHex.
// If no holder wrap exists, it falls back to a legacy "org" wrap using the global
// orgKemPrivHex (for credentials encrypted under the old B3 org-key scheme).
//
// holderKemPrivHex may be empty if the holder's private key is not available on
// the server (e.g. production mode where keys live on the device). In that case,
// only the legacy org-key fallback is attempted.
func decryptCredentialData(stored, holderID, holderKemPrivHex string) (string, error) {
	b := []byte(stored)
	if !looksLikeEnvelope(b) {
		return stored, nil // legacy plaintext — pass through unchanged
	}
	var env Envelope
	if err := json.Unmarshal(b, &env); err != nil {
		return "", fmt.Errorf("parse envelope: %w", err)
	}

	// Try holder-key decryption first (B2).
	holderRecip := holderRecipientName(holderID)
	if holderKemPrivHex != "" {
		for _, w := range env.Wraps {
			if w.Recipient == holderRecip {
				return decryptEnvelopeAs(&env, holderRecip, holderKemPrivHex)
			}
		}
	}

	// Fallback: try legacy org-key decryption (B3 backward compat).
	if orgKemPrivHex != "" {
		for _, w := range env.Wraps {
			if w.Recipient == recipientOrg {
				return decryptEnvelopeAs(&env, recipientOrg, orgKemPrivHex)
			}
		}
	}

	// Also try matching any holder:* wrap if the holderID didn't match exactly
	// (defensive — shouldn't happen in practice).
	if holderKemPrivHex != "" {
		for _, w := range env.Wraps {
			if strings.HasPrefix(w.Recipient, recipientHolderPrefix) {
				return decryptEnvelopeAs(&env, w.Recipient, holderKemPrivHex)
			}
		}
	}

	return "", fmt.Errorf("cannot decrypt: no matching recipient wrap (holder=%q, org-key-available=%v)", holderID, orgKemPrivHex != "")
}

// decryptEnvelopeAs decrypts an envelope using a specific recipient name and key.
func decryptEnvelopeAs(env *Envelope, recipient, kemPrivHex string) (string, error) {
	attrs, err := openAttributes(env, recipient, kemPrivHex)
	if err != nil {
		return "", err
	}
	// Single-field raw fallback (non-object payloads were wrapped under "_raw").
	if len(attrs) == 1 {
		if raw, ok := attrs["_raw"]; ok {
			var s string
			if json.Unmarshal(raw, &s) == nil {
				return s, nil
			}
		}
	}
	out, err := json.Marshal(attrs)
	if err != nil {
		return "", err
	}
	return string(out), nil
}

// splitFields parses a JSON object into per-key raw values for field-level
// encryption. If the payload is not a JSON object (e.g. an array or scalar), the
// whole thing is stored under a single "_raw" field so it still round-trips.
func splitFields(attrsJSON string) (map[string]json.RawMessage, error) {
	var attrs map[string]json.RawMessage
	if err := json.Unmarshal([]byte(attrsJSON), &attrs); err == nil {
		return attrs, nil
	}
	raw, err := json.Marshal(attrsJSON)
	if err != nil {
		return nil, err
	}
	return map[string]json.RawMessage{"_raw": raw}, nil
}
