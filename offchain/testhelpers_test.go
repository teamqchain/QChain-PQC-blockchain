package main

// testhelpers_test.go — shared fixtures for the package tests.
//
// The server never generates ML-DSA key pairs itself (the issuer key comes from
// .env and holder keys are generated on the phone), so tests create their own
// through liboqs directly.

import (
	"encoding/hex"
	"testing"

	"github.com/open-quantum-safe/liboqs-go/oqs"
)

// testDSAKeyPair returns a fresh ML-DSA-44 key pair as (publicHex, secretHex).
func testDSAKeyPair(t *testing.T) (pubHex, secHex string) {
	t.Helper()
	signer := oqs.Signature{}
	defer signer.Clean()
	if err := signer.Init(sigName, nil); err != nil {
		t.Fatalf("init %s: %v", sigName, err)
	}
	pub, err := signer.GenerateKeyPair()
	if err != nil {
		t.Fatalf("generate %s key pair: %v", sigName, err)
	}
	return hex.EncodeToString(pub), hex.EncodeToString(signer.ExportSecretKey())
}
