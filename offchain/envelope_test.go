package main

// envelope_test.go — v2 credential envelope round-trip tests.
//
// These exercise real ML-KEM-768 via liboqs, so they require the liboqs C library
// (the Docker builder stage has it):
//
//	cd offchain && go test -run TestEnvelope -v
//
// They do not need MySQL, IPFS or Fabric.

import (
	"encoding/json"
	"strings"
	"testing"
)

func setupTestKeys(t *testing.T) (holderPub, holderPriv string) {
	t.Helper()
	if n := resolveKEMName(); n != "" {
		kemName = n
	} else {
		t.Skip("no ML-KEM mechanism enabled in this liboqs build")
	}
	pub, sec, err := kemGenerateKeypair()
	if err != nil {
		t.Fatalf("kemGenerateKeypair: %v", err)
	}
	return pub, sec
}

var envelopeTestAttrs = map[string]string{
	"Degree Title": "Bachelors in Computer Science",
	"College":      "College of Computing & Informatics",
	"GPA":          "3.8",
}

// sealTestEnvelope seals envelopeTestAttrs with fresh salts.
func sealTestEnvelope(t *testing.T, pub string) (*Envelope, []byte, map[string]string) {
	t.Helper()
	salts, _, err := commitAttributes(envelopeTestAttrs)
	if err != nil {
		t.Fatalf("commitAttributes: %v", err)
	}
	raw, err := sealCredentialEnvelope(envelopeTestAttrs, salts, pub)
	if err != nil {
		t.Fatalf("sealCredentialEnvelope: %v", err)
	}
	var env Envelope
	if err := json.Unmarshal(raw, &env); err != nil {
		t.Fatalf("envelope is not JSON: %v", err)
	}
	return &env, raw, salts
}

func TestEnvelopeRoundTripWithSalts(t *testing.T) {
	pub, priv := setupTestKeys(t)
	env, raw, salts := sealTestEnvelope(t, pub)

	if !looksLikeEnvelope(raw) {
		t.Fatal("sealed output is not recognised as an envelope")
	}
	if env.V != 2 {
		t.Fatalf("envelope version = %d, want 2", env.V)
	}
	if !strings.HasPrefix(env.CredID, "env-") || len(env.CredID) != 36 {
		t.Fatalf("credId should be env-<32 hex>, got %q", env.CredID)
	}
	if len(env.Wraps) != 1 || env.Wraps[0].Recipient != "holder" {
		t.Fatalf("expected a single holder wrap, got %+v", env.Wraps)
	}
	for _, plain := range envelopeTestAttrs {
		if strings.Contains(string(raw), plain) {
			t.Fatalf("envelope leaks plaintext %q", plain)
		}
	}

	opened, err := openAttributes(env, "holder", priv)
	if err != nil {
		t.Fatalf("openAttributes: %v", err)
	}
	if len(opened) != len(envelopeTestAttrs)+1 {
		t.Fatalf("opened %d fields, want %d attributes + _salts", len(opened), len(envelopeTestAttrs))
	}
	for key, want := range envelopeTestAttrs {
		var got string
		if err := json.Unmarshal(opened[key], &got); err != nil || got != want {
			t.Fatalf("field %q = %s, want %q", key, opened[key], want)
		}
	}
	var gotSalts map[string]string
	if err := json.Unmarshal(opened[saltsFieldKey], &gotSalts); err != nil {
		t.Fatalf("_salts is not a JSON object of strings: %v (%s)", err, opened[saltsFieldKey])
	}
	if len(gotSalts) != len(salts) {
		t.Fatalf("_salts has %d entries, want %d", len(gotSalts), len(salts))
	}
	for key, salt := range salts {
		if gotSalts[key] != salt {
			t.Fatalf("salt for %q = %q, want %q", key, gotSalts[key], salt)
		}
	}
	if _, ok := opened["expiryDate"]; ok {
		t.Fatal("expiryDate must not be inside the envelope (it is on-chain metadata)")
	}
}

func TestEnvelopeFieldsAreSortedAndContextIsRandom(t *testing.T) {
	pub, _ := setupTestKeys(t)
	a, _, _ := sealTestEnvelope(t, pub)
	b, _, _ := sealTestEnvelope(t, pub)
	if a.CredID == b.CredID {
		t.Fatal("two envelopes share an HKDF context; it must be random per credential")
	}
	var keys []string
	for _, f := range a.Fields {
		keys = append(keys, f.Key)
	}
	want := []string{"College", "Degree Title", "GPA", "_salts"}
	if strings.Join(keys, "|") != strings.Join(want, "|") {
		t.Fatalf("field order = %v, want %v", keys, want)
	}
}

func TestHKDFInfoMatchesWallet(t *testing.T) {
	// QWallet derives '$hkdfInfoPrefix|$credId|$key' with prefix 'qchain/trackB/v1'.
	if got := hkdfFieldInfo("env-abc", "Degree Title"); got != "qchain/trackB/v1|env-abc|Degree Title" {
		t.Fatalf("hkdf info = %q", got)
	}
}

func TestSealRequiresHolderKey(t *testing.T) {
	if _, err := sealCredentialEnvelope(map[string]string{"a": "1"}, map[string]string{"a": strings.Repeat("0", 32)}, ""); err == nil {
		t.Fatal("expected an error when the holder has no KEM key")
	}
}

func TestSealRejectsReservedSaltsKey(t *testing.T) {
	pub, _ := setupTestKeys(t)
	if _, err := sealCredentialEnvelope(map[string]string{saltsFieldKey: "x"}, map[string]string{}, pub); err == nil {
		t.Fatal("expected an error for an attribute named _salts")
	}
}

func TestEnvelopeWrongKeyFails(t *testing.T) {
	pub, _ := setupTestKeys(t)
	_, otherPriv := setupTestKeys(t)
	env, _, _ := sealTestEnvelope(t, pub)
	if _, err := openAttributes(env, "holder", otherPriv); err == nil {
		t.Fatal("another holder's key must not open the envelope")
	}
}

func TestTamperedFieldFailsAuth(t *testing.T) {
	pub, priv := setupTestKeys(t)
	env, _, _ := sealTestEnvelope(t, pub)
	ct := []byte(env.Fields[0].Ct)
	if ct[0] == 'a' {
		ct[0] = 'b'
	} else {
		ct[0] = 'a'
	}
	env.Fields[0].Ct = string(ct)
	if _, err := openAttributes(env, "holder", priv); err == nil {
		t.Fatal("expected auth failure on tampered ciphertext, got nil error")
	}
}
