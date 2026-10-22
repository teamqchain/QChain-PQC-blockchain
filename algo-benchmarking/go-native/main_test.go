package main

import (
	"crypto/mlkem"
	"testing"
)

// BenchmarkKeyGeneration measures the key generation latency of Go standard library ML-KEM.
func BenchmarkKeyGeneration(b *testing.B) {
	b.Run("ML-KEM-768", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			_, err := mlkem.GenerateKey768()
			if err != nil {
				b.Fatalf("GenerateKey768: %v", err)
			}
		}
	})

	b.Run("ML-KEM-1024", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			_, err := mlkem.GenerateKey1024()
			if err != nil {
				b.Fatalf("GenerateKey1024: %v", err)
			}
		}
	})
}

// BenchmarkEncapsulation measures post-quantum key encapsulation latency (producing shared secret + ciphertext).
func BenchmarkEncapsulation(b *testing.B) {
	b.Run("ML-KEM-768", func(b *testing.B) {
		dk, _ := mlkem.GenerateKey768()
		ek := dk.EncapsulationKey()
		b.ResetTimer()
		for i := 0; i < b.N; i++ {
			_, _ = ek.Encapsulate()
		}
	})

	b.Run("ML-KEM-1024", func(b *testing.B) {
		dk, _ := mlkem.GenerateKey1024()
		ek := dk.EncapsulationKey()
		b.ResetTimer()
		for i := 0; i < b.N; i++ {
			_, _ = ek.Encapsulate()
		}
	})
}

// BenchmarkDecapsulation measures post-quantum key decapsulation latency (recovering shared secret from ciphertext).
func BenchmarkDecapsulation(b *testing.B) {
	b.Run("ML-KEM-768", func(b *testing.B) {
		dk, _ := mlkem.GenerateKey768()
		ek := dk.EncapsulationKey()
		_, ct := ek.Encapsulate()
		b.ResetTimer()
		for i := 0; i < b.N; i++ {
			_, err := dk.Decapsulate(ct)
			if err != nil {
				b.Fatalf("Decapsulate768: %v", err)
			}
		}
	})

	b.Run("ML-KEM-1024", func(b *testing.B) {
		dk, _ := mlkem.GenerateKey1024()
		ek := dk.EncapsulationKey()
		_, ct := ek.Encapsulate()
		b.ResetTimer()
		for i := 0; i < b.N; i++ {
			_, err := dk.Decapsulate(ct)
			if err != nil {
				b.Fatalf("Decapsulate1024: %v", err)
			}
		}
	})
}

// BenchmarkTotalWorkflow measures the complete post-quantum key exchange pipeline:
// KeyGen -> Encapsulate -> Decapsulate.
func BenchmarkTotalWorkflow(b *testing.B) {
	b.Run("ML-KEM-768", func(b *testing.B) {
		b.ResetTimer()
		for i := 0; i < b.N; i++ {
			dk, err := mlkem.GenerateKey768()
			if err != nil {
				b.Fatalf("GenerateKey768: %v", err)
			}
			ek := dk.EncapsulationKey()
			_, ct := ek.Encapsulate()
			_, err = dk.Decapsulate(ct)
			if err != nil {
				b.Fatalf("Decapsulate768: %v", err)
			}
		}
	})

	b.Run("ML-KEM-1024", func(b *testing.B) {
		b.ResetTimer()
		for i := 0; i < b.N; i++ {
			dk, err := mlkem.GenerateKey1024()
			if err != nil {
				b.Fatalf("GenerateKey1024: %v", err)
			}
			ek := dk.EncapsulationKey()
			_, ct := ek.Encapsulate()
			_, err = dk.Decapsulate(ct)
			if err != nil {
				b.Fatalf("Decapsulate1024: %v", err)
			}
		}
	})
}

// BenchmarkAuthenticatedEnvelope measures the complete KEM-DEM envelope workflow:
// ML-KEM KeyGen -> Encapsulate -> AES-256-GCM Encrypt -> Decapsulate -> AES-256-GCM Decrypt.
func BenchmarkAuthenticatedEnvelope(b *testing.B) {
	dummyPayload := []byte(`{"credentialID":"CRED-0001","degree":"BSc Computer Science","gpa":"3.9"}`)

	b.Run("ML-KEM-768+AES-256-GCM", func(b *testing.B) {
		dk, _ := mlkem.GenerateKey768()
		ek := dk.EncapsulationKey()
		b.ResetTimer()
		for i := 0; i < b.N; i++ {
			sharedKey, ct := ek.Encapsulate()
			sealed, err := encryptWithSharedKey(sharedKey, dummyPayload)
			if err != nil {
				b.Fatalf("encrypt: %v", err)
			}
			recoveredKey, err := dk.Decapsulate(ct)
			if err != nil {
				b.Fatalf("decapsulate: %v", err)
			}
			_, err = decryptWithSharedKey(recoveredKey, sealed)
			if err != nil {
				b.Fatalf("decrypt: %v", err)
			}
		}
	})

	b.Run("ML-KEM-1024+AES-256-GCM", func(b *testing.B) {
		dk, _ := mlkem.GenerateKey1024()
		ek := dk.EncapsulationKey()
		b.ResetTimer()
		for i := 0; i < b.N; i++ {
			sharedKey, ct := ek.Encapsulate()
			sealed, err := encryptWithSharedKey(sharedKey, dummyPayload)
			if err != nil {
				b.Fatalf("encrypt: %v", err)
			}
			recoveredKey, err := dk.Decapsulate(ct)
			if err != nil {
				b.Fatalf("decapsulate: %v", err)
			}
			_, err = decryptWithSharedKey(recoveredKey, sealed)
			if err != nil {
				b.Fatalf("decrypt: %v", err)
			}
		}
	})
}
