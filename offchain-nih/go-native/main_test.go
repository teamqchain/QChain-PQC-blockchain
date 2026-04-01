package main

import (
	"crypto/rand"
	"testing"

	"github.com/cloudflare/circl/sign/mldsa/mldsa44"
	"github.com/cloudflare/circl/sign/mldsa/mldsa65"
	"github.com/cloudflare/circl/sign/mldsa/mldsa87"
)

// Key Generation Speed
func BenchmarkKeyGeneration(b *testing.B) {
	b.Run("ML-DSA-44", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			_, _, _ = mldsa44.GenerateKey(rand.Reader)
		}
	})
	b.Run("ML-DSA-65", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			_, _, _ = mldsa65.GenerateKey(rand.Reader)
		}
	})
	b.Run("ML-DSA-87", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			_, _, _ = mldsa87.GenerateKey(rand.Reader)
		}
	})
}

// Signing Speed
func BenchmarkSigning(b *testing.B) {
	dummyCID := []byte("bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")

	b.Run("ML-DSA-44", func(b *testing.B) {
		_, priv, _ := mldsa44.GenerateKey(rand.Reader)
		sig := make([]byte, mldsa44.SignatureSize)
		b.ResetTimer()
		for i := 0; i < b.N; i++ {
			_ = mldsa44.SignTo(priv, dummyCID, nil, false, sig)
		}
	})
	b.Run("ML-DSA-65", func(b *testing.B) {
		_, priv, _ := mldsa65.GenerateKey(rand.Reader)
		sig := make([]byte, mldsa65.SignatureSize)
		b.ResetTimer()
		for i := 0; i < b.N; i++ {
			_ = mldsa65.SignTo(priv, dummyCID, nil, false, sig)
		}
	})
	b.Run("ML-DSA-87", func(b *testing.B) {
		_, priv, _ := mldsa87.GenerateKey(rand.Reader)
		sig := make([]byte, mldsa87.SignatureSize)
		b.ResetTimer()
		for i := 0; i < b.N; i++ {
			_ = mldsa87.SignTo(priv, dummyCID, nil, false, sig)
		}
	})
}

// Verification Speed
func BenchmarkVerification(b *testing.B) {
	dummyCID := []byte("bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")

	b.Run("ML-DSA-44", func(b *testing.B) {
		pub, priv, _ := mldsa44.GenerateKey(rand.Reader)
		sig := make([]byte, mldsa44.SignatureSize)
		_ = mldsa44.SignTo(priv, dummyCID, nil, false, sig)
		b.ResetTimer()
		for i := 0; i < b.N; i++ {
			_ = mldsa44.Verify(pub, dummyCID, nil, sig)
		}
	})
	b.Run("ML-DSA-65", func(b *testing.B) {
		pub, priv, _ := mldsa65.GenerateKey(rand.Reader)
		sig := make([]byte, mldsa65.SignatureSize)
		_ = mldsa65.SignTo(priv, dummyCID, nil, false, sig)
		b.ResetTimer()
		for i := 0; i < b.N; i++ {
			_ = mldsa65.Verify(pub, dummyCID, nil, sig)
		}
	})
	b.Run("ML-DSA-87", func(b *testing.B) {
		pub, priv, _ := mldsa87.GenerateKey(rand.Reader)
		sig := make([]byte, mldsa87.SignatureSize)
		_ = mldsa87.SignTo(priv, dummyCID, nil, false, sig)
		b.ResetTimer()
		for i := 0; i < b.N; i++ {
			_ = mldsa87.Verify(pub, dummyCID, nil, sig)
		}
	})
}

// Total Workflow Speed (KeyGen -> Sign -> Verify)
func BenchmarkTotalWorkflow(b *testing.B) {
	dummyCID := []byte("bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")

	b.Run("ML-DSA-44", func(b *testing.B) {
		b.ResetTimer()
		for i := 0; i < b.N; i++ {
			// 1. Generate Keys
			pub, priv, _ := mldsa44.GenerateKey(rand.Reader)
			// 2. Sign
			sig := make([]byte, mldsa44.SignatureSize)
			_ = mldsa44.SignTo(priv, dummyCID, nil, false, sig)
			// 3. Verify
			_ = mldsa44.Verify(pub, dummyCID, nil, sig)
		}
	})

	b.Run("ML-DSA-65", func(b *testing.B) {
		b.ResetTimer()
		for i := 0; i < b.N; i++ {
			pub, priv, _ := mldsa65.GenerateKey(rand.Reader)
			sig := make([]byte, mldsa65.SignatureSize)
			_ = mldsa65.SignTo(priv, dummyCID, nil, false, sig)
			_ = mldsa65.Verify(pub, dummyCID, nil, sig)
		}
	})

	b.Run("ML-DSA-87", func(b *testing.B) {
		b.ResetTimer()
		for i := 0; i < b.N; i++ {
			pub, priv, _ := mldsa87.GenerateKey(rand.Reader)
			sig := make([]byte, mldsa87.SignatureSize)
			_ = mldsa87.SignTo(priv, dummyCID, nil, false, sig)
			_ = mldsa87.Verify(pub, dummyCID, nil, sig)
		}
	})
}
