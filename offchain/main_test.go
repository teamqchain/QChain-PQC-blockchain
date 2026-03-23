package main

import (
	"testing"

	"github.com/open-quantum-safe/liboqs-go/oqs"
)

const sigName = "ML-DSA-44"

// Key Generation Speed
func BenchmarkKeyGeneration(b *testing.B) {
	signer := oqs.Signature{}
	signer.Init(sigName, nil)
	defer signer.Clean()

	b.ResetTimer() // Only measure the actual math, not the setup
	for i := 0; i < b.N; i++ {
		_, _ = signer.GenerateKeyPair()
	}
}

// Signing Speed
func BenchmarkSigning(b *testing.B) {
	signer := oqs.Signature{}
	signer.Init(sigName, nil)
	defer signer.Clean()

	_, _ = signer.GenerateKeyPair()
	dummyCID := []byte("bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, _ = signer.Sign(dummyCID)
	}
}

// Verification Speed
func BenchmarkVerification(b *testing.B) {
	signer := oqs.Signature{}
	signer.Init(sigName, nil)
	defer signer.Clean()

	pubKey, _ := signer.GenerateKeyPair()
	dummyCID := []byte("bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")
	signature, _ := signer.Sign(dummyCID)

	verifier := oqs.Signature{}
	verifier.Init(sigName, nil)
	defer verifier.Clean()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, _ = verifier.Verify(dummyCID, signature, pubKey)
	}
}
