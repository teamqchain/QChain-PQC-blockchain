package main

// envelope_test.go — Track B2 round-trip tests.
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

// Test holder key pair — generated once per test file run.
var testHolderID = "H-TEST-001"
var testHolderPub, testHolderPriv string

// setupKEM resolves the KEM name and generates a throwaway holder key for the test.
func setupKEM(t *testing.T) {
	t.Helper()
	if n := resolveKEMName(); n != "" {
		kemName = n
	} else {
		t.Skip("no ML-KEM mechanism enabled in this liboqs build")
	}
	if testHolderPub == "" {
		pub, sec, err := kemGenerateKeypair()
		if err != nil {
			t.Fatalf("kemGenerateKeypair: %v", err)
		}
		testHolderPub, testHolderPriv = pub, sec
	}
	// Make holder priv available to decryptCredentialData via the in-memory map.
	holderKemKeys = map[string]string{testHolderID: testHolderPriv}
}

func TestEnvelopeRoundTrip(t *testing.T) {
	setupKEM(t)

	plain := `{"degree":"BSc Computer Science","gpa":3.8,"expiryDate":"2030-06-30","nested":{"a":1}}`
	enc, err := encryptCredentialData("hash-abc", plain, testHolderID, testHolderPub)
	if err != nil {
		t.Fatalf("encrypt: %v", err)
	}
	if !looksLikeEnvelope([]byte(enc)) {
		t.Fatal("expected an envelope, got something else")
	}
	if enc == plain {
		t.Fatal("ciphertext equals plaintext")
	}

	got, err := decryptCredentialData(enc, testHolderID, testHolderPriv)
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
	got, err := decryptCredentialData(plain, testHolderID, testHolderPriv)
	if err != nil {
		t.Fatalf("decrypt legacy: %v", err)
	}
	if got != plain {
		t.Fatalf("legacy passthrough changed value: %q -> %q", plain, got)
	}
}

func TestEncryptionRequiresHolderKey(t *testing.T) {
	setupKEM(t)
	// Encryption must fail when holder key is empty — no silent fallback to plaintext.
	_, err := encryptCredentialData("h", `{"a":1}`, testHolderID, "")
	if err == nil {
		t.Fatal("expected error when holder KEM public key is empty, got nil")
	}
}

func TestTamperedFieldFailsAuth(t *testing.T) {
	setupKEM(t)
	enc, err := encryptCredentialData("h", `{"secret":"value"}`, testHolderID, testHolderPub)
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
	if _, err := decryptCredentialData(string(bad), testHolderID, testHolderPriv); err == nil {
		t.Fatal("expected auth failure on tampered ciphertext, got nil error")
	}
}

func TestEnvelopeRecipientIsHolder(t *testing.T) {
	setupKEM(t)
	enc, err := encryptCredentialData("h", `{"gpa":3.5}`, testHolderID, testHolderPub)
	if err != nil {
		t.Fatalf("encrypt: %v", err)
	}
	var env Envelope
	if err := json.Unmarshal([]byte(enc), &env); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	// Verify the recipient is "holder:<holderID>", not "org".
	if len(env.Wraps) != 1 {
		t.Fatalf("expected 1 wrap, got %d", len(env.Wraps))
	}
	wantRecip := holderRecipientName(testHolderID)
	if env.Wraps[0].Recipient != wantRecip {
		t.Fatalf("expected recipient %q, got %q", wantRecip, env.Wraps[0].Recipient)
	}
	// Also verify field wraps use the holder recipient.
	for _, f := range env.Fields {
		if _, ok := f.Wrap[wantRecip]; !ok {
			t.Fatalf("field %q missing wrap for %q", f.Key, wantRecip)
		}
		if _, ok := f.Wrap["org"]; ok {
			t.Fatalf("field %q still has an 'org' wrap — should use holder only", f.Key)
		}
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
