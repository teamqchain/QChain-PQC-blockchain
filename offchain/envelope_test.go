package main

// envelope_test.go — Track B round-trip tests.
//
// These exercise real ML-KEM-768 via liboqs, so they require the liboqs C library
// to be present (the Docker build already installs it). Run inside the same
// environment used to build the server:
//
//	cd offchain && go test -run TestEnvelope -v
//
// They do not need MySQL, IPFS or Fabric.

import (
	"encoding/json"
	"testing"
)

// setupKEM resolves the KEM name and generates a throwaway org key for the test.
func setupKEM(t *testing.T) {
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
	orgKemPubHex, orgKemPrivHex = pub, sec
}

func TestEnvelopeRoundTrip(t *testing.T) {
	setupKEM(t)

	plain := `{"degree":"BSc Computer Science","gpa":3.8,"expiryDate":"2030-06-30","nested":{"a":1}}`
	enc, err := encryptCredentialData("hash-abc", plain)
	if err != nil {
		t.Fatalf("encrypt: %v", err)
	}
	if !looksLikeEnvelope([]byte(enc)) {
		t.Fatal("expected an envelope, got something else")
	}
	if enc == plain {
		t.Fatal("ciphertext equals plaintext")
	}

	got, err := decryptCredentialData(enc)
	if err != nil {
		t.Fatalf("decrypt: %v", err)
	}
	// Compare as normalised JSON (field order is not preserved).
	if !sameJSON(t, plain, got) {
		t.Fatalf("round-trip mismatch:\n want %s\n got  %s", plain, got)
	}
}

func TestLegacyPlaintextPassthrough(t *testing.T) {
	setupKEM(t)
	plain := `{"a":1}`
	// A legacy (non-envelope) value must pass through decrypt untouched.
	got, err := decryptCredentialData(plain)
	if err != nil {
		t.Fatalf("decrypt legacy: %v", err)
	}
	if got != plain {
		t.Fatalf("legacy passthrough changed value: %q -> %q", plain, got)
	}
}

func TestEncryptionDisabledFallsBackToPlaintext(t *testing.T) {
	orgKemPubHex, orgKemPrivHex = "", "" // encryption disabled
	plain := `{"a":1}`
	got, err := encryptCredentialData("h", plain)
	if err != nil {
		t.Fatalf("encrypt disabled: %v", err)
	}
	if got != plain {
		t.Fatalf("expected plaintext passthrough when disabled, got %q", got)
	}
}

func TestTamperedFieldFailsAuth(t *testing.T) {
	setupKEM(t)
	enc, err := encryptCredentialData("h", `{"secret":"value"}`)
	if err != nil {
		t.Fatalf("encrypt: %v", err)
	}
	var env Envelope
	if err := json.Unmarshal([]byte(enc), &env); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	// Flip a byte in the first field ciphertext.
	ct := []byte(env.Fields[0].Ct)
	if ct[0] == 'a' {
		ct[0] = 'b'
	} else {
		ct[0] = 'a'
	}
	env.Fields[0].Ct = string(ct)
	bad, _ := json.Marshal(env)
	if _, err := decryptCredentialData(string(bad)); err == nil {
		t.Fatal("expected auth failure on tampered ciphertext, got nil error")
	}
}

func sameJSON(t *testing.T, a, b string) bool {
	t.Helper()
	var ao, bo any
	if err := json.Unmarshal([]byte(a), &ao); err != nil {
		t.Fatalf("bad json a: %v", err)
	}
	if err := json.Unmarshal([]byte(b), &bo); err != nil {
		t.Fatalf("bad json b: %v", err)
	}
	aj, _ := json.Marshal(ao)
	bj, _ := json.Marshal(bo)
	return string(aj) == string(bj)
}
