package main

// envelope.go — per-field envelope encryption of the credential body.
//
// The credential body (its attributes) exists in exactly one place: an envelope
// on IPFS, encrypted to the HOLDER's ML-KEM-768 public key. The chain stores
// only the envelope's CID plus salted hashes of each field (see commitment.go),
// and the server can never decrypt it — QWallet decrypts on the phone.
//
// Format (v2):
//   {
//     "_qc_env": "qchain-env", "v": 2,
//     "kemAlg": "ML-KEM-768", "aeadAlg": "AES-256-GCM", "kdf": "HKDF-SHA3-256",
//     "credId": "env-<random hex>",          // HKDF context, not a credential ID
//     "wraps":  [ { "recipient": "holder", "kemCt": "<hex>" } ],
//     "fields": [ { "key": "College", "nonce": "<hex>", "ct": "<hex>",
//                   "wrap": { "holder": "<hex wrapped per-field key>" } },
//                 { "key": "_salts", ... } ]  // {"<field>": "<32-hex salt>"}
//   }
//
// Each field's plaintext is its JSON value (a string for every attribute; an
// object for "_salts"). Each field has its own random AES-256-GCM data key,
// wrapped under a key derived with HKDF-SHA3-256 from the ML-KEM shared secret
// and "qchain/trackB/v1|<credId>|<field key>". The wallet mirrors this exactly
// (CryptoService.decryptEnvelope), so the HKDF info string must not change.
//
// credId is random rather than the credential hash: the credential hash now
// covers the envelope's CID, so the envelope cannot depend on the hash.

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
)

const (
	envelopeMagic   = "qchain-env" // marker distinguishing an envelope from other JSON
	envelopeVersion = 2
)

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

// looksLikeEnvelope reports whether bytes are a QChain envelope.
func looksLikeEnvelope(b []byte) bool {
	var probe struct {
		Magic string `json:"_qc_env"`
	}
	if err := json.Unmarshal(b, &probe); err != nil {
		return false
	}
	return probe.Magic == envelopeMagic
}

// hkdfFieldInfo is the HKDF context for one field's key-wrapping key. It must
// stay byte-identical to the wallet's '$hkdfInfoPrefix|$credId|$key'.
func hkdfFieldInfo(contextID, key string) string {
	return fmt.Sprintf("qchain/trackB/v1|%s|%s", contextID, key)
}

// sealAttributes builds a per-field envelope over attrs, wrapped to every
// recipient. contextID is the HKDF context binding stored as the envelope's
// credId. Fields are emitted in sorted key order.
func sealAttributes(contextID string, attrs map[string]json.RawMessage, recipients []Recipient) (*Envelope, error) {
	if len(recipients) == 0 {
		return nil, fmt.Errorf("sealAttributes: no recipients")
	}
	env := &Envelope{
		Magic:   envelopeMagic,
		V:       envelopeVersion,
		KemAlg:  kemName,
		AeadAlg: "AES-256-GCM",
		Kdf:     "HKDF-SHA3-256",
		CredID:  contextID,
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
	for _, key := range sortedKeys(attrs) {
		dataKey := make([]byte, 32)
		if _, err := io.ReadFull(rand.Reader, dataKey); err != nil {
			return nil, fmt.Errorf("random data key: %w", err)
		}
		nonce, ct, err := aesSeal(hex.EncodeToString(dataKey), attrs[key])
		if err != nil {
			return nil, fmt.Errorf("encrypt field %q: %w", key, err)
		}
		f := EncField{Key: key, Nonce: nonce, Ct: ct, Wrap: map[string]string{}}
		for _, r := range recipients {
			kwk, err := deriveKey(ss[r.Name], hkdfFieldInfo(contextID, key))
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
// The server never holds a holder's secret key; this is the reference
// implementation used by the tests and the keygen decrypt tool.
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
		kwk, err := deriveKey(ssHex, hkdfFieldInfo(env.CredID, f.Key))
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

// newEnvelopeContextID returns a fresh random HKDF context ("env-<32 hex>").
func newEnvelopeContextID() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", fmt.Errorf("random envelope context: %w", err)
	}
	return "env-" + hex.EncodeToString(b), nil
}

// sealCredentialEnvelope encrypts a credential's attributes plus their salts
// (under the reserved "_salts" field) to the holder's ML-KEM public key and
// returns the envelope JSON that is uploaded to IPFS.
func sealCredentialEnvelope(attrs, salts map[string]string, holderKemPubHex string) ([]byte, error) {
	if holderKemPubHex == "" {
		return nil, fmt.Errorf("holder has no registered ML-KEM public key")
	}
	if _, clash := attrs[saltsFieldKey]; clash {
		return nil, fmt.Errorf("attribute name %q is reserved", saltsFieldKey)
	}
	fields := make(map[string]json.RawMessage, len(attrs)+1)
	for key, value := range attrs {
		b, err := json.Marshal(value)
		if err != nil {
			return nil, err
		}
		fields[key] = b
	}
	saltsJSON, err := json.Marshal(salts)
	if err != nil {
		return nil, err
	}
	fields[saltsFieldKey] = saltsJSON

	contextID, err := newEnvelopeContextID()
	if err != nil {
		return nil, err
	}
	env, err := sealAttributes(contextID, fields, []Recipient{{Name: "holder", PubHex: holderKemPubHex}})
	if err != nil {
		return nil, err
	}
	return json.Marshal(env)
}
