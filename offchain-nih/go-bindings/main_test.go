package main

import (
	"testing"

	"github.com/open-quantum-safe/liboqs-go/oqs"
)

// levels for ML-DSA
var algorithms = []string{
	"ML-DSA-44",
	"ML-DSA-65",
	"ML-DSA-87",
}

// Key Generation Speed
func BenchmarkKeyGeneration(b *testing.B) {
	for _, alg := range algorithms {
		b.Run(alg, func(b *testing.B) {
			signer := oqs.Signature{}
			signer.Init(alg, nil)
			defer signer.Clean()

			b.ResetTimer()
			for i := 0; i < b.N; i++ {
				_, _ = signer.GenerateKeyPair()
			}
		})
	}
}

// Signing Speed
func BenchmarkSigning(b *testing.B) {
	dummyCID := []byte("bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")

	for _, alg := range algorithms {
		b.Run(alg, func(b *testing.B) {
			signer := oqs.Signature{}
			signer.Init(alg, nil)
			defer signer.Clean()

			_, _ = signer.GenerateKeyPair()

			b.ResetTimer()
			for i := 0; i < b.N; i++ {
				_, _ = signer.Sign(dummyCID)
			}
		})
	}
}

// Verification Speed
func BenchmarkVerification(b *testing.B) {
	dummyCID := []byte("bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")

	for _, alg := range algorithms {
		b.Run(alg, func(b *testing.B) {
			signer := oqs.Signature{}
			signer.Init(alg, nil)
			defer signer.Clean()

			pubKey, _ := signer.GenerateKeyPair()
			signature, _ := signer.Sign(dummyCID)

			verifier := oqs.Signature{}
			verifier.Init(alg, nil)
			defer verifier.Clean()

			b.ResetTimer()
			for i := 0; i < b.N; i++ {
				_, _ = verifier.Verify(dummyCID, signature, pubKey)
			}
		})
	}
}

// Total Workflow Speed (KeyGen -> Sign -> Verify)
func BenchmarkTotalWorkflow(b *testing.B) {
	dummyCID := []byte("bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")

	for _, alg := range algorithms {
		b.Run(alg, func(b *testing.B) {
			signer := oqs.Signature{}
			signer.Init(alg, nil)
			defer signer.Clean()

			verifier := oqs.Signature{}
			verifier.Init(alg, nil)
			defer verifier.Clean()

			b.ResetTimer()
			for i := 0; i < b.N; i++ {
				// 1. Generate Keys
				pubKey, _ := signer.GenerateKeyPair()
				// 2. Sign
				signature, _ := signer.Sign(dummyCID)
				// 3. Verify
				_, _ = verifier.Verify(dummyCID, signature, pubKey)
			}
		})
	}
}
