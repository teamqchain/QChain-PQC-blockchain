package main

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/mlkem"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"os"
	"strings"

	shell "github.com/ipfs/go-ipfs-api"
)

// encryptWithSharedKey encrypts plaintext using AES-256-GCM keyed by the ML-KEM shared secret.
func encryptWithSharedKey(sharedKey, plaintext []byte) ([]byte, error) {
	block, err := aes.NewCipher(sharedKey)
	if err != nil {
		return nil, fmt.Errorf("aes cipher: %w", err)
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("cipher gcm: %w", err)
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, fmt.Errorf("read nonce: %w", err)
	}
	return gcm.Seal(nonce, nonce, plaintext, nil), nil
}

// decryptWithSharedKey decrypts ciphertext using AES-256-GCM keyed by the ML-KEM shared secret.
func decryptWithSharedKey(sharedKey, ciphertext []byte) ([]byte, error) {
	block, err := aes.NewCipher(sharedKey)
	if err != nil {
		return nil, fmt.Errorf("aes cipher: %w", err)
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("cipher gcm: %w", err)
	}
	nonceSize := gcm.NonceSize()
	if len(ciphertext) < nonceSize {
		return nil, fmt.Errorf("ciphertext too short")
	}
	nonce, ct := ciphertext[:nonceSize], ciphertext[nonceSize:]
	return gcm.Open(nil, nonce, ct, nil)
}

func main() {
	fmt.Println("═══════════════════════════════════════════════════════════════════")
	fmt.Println("  QChain Native Go PQC — ML-KEM-768 (NIST FIPS 203 / crypto/mlkem)")
	fmt.Println("  Standard Library Native Implementation (No CGo / liboqs required)")
	fmt.Println("═══════════════════════════════════════════════════════════════════")

	// 1. Generate Key Pair natively using Go standard library
	dk, err := mlkem.GenerateKey768()
	if err != nil {
		log.Fatalf("Failed to generate ML-KEM-768 key pair: %v", err)
	}
	ek := dk.EncapsulationKey()

	pubBytes := ek.Bytes()
	secBytes := dk.Bytes()

	fmt.Printf("\n[KeyGen] Public Encapsulation Key (ML-KEM-768) : %d bytes\n", len(pubBytes))
	fmt.Printf("[KeyGen] Private Decapsulation Seed (ML-KEM-768) : %d bytes\n", len(secBytes))

	// 2. Upload Document to IPFS (or mock if IPFS daemon is not running)
	fmt.Println("\n[1] Storing Document on IPFS...")
	sh := shell.NewShell("localhost:5001")
	var documentCID string

	pdfFile, err := os.Open("sample_transcript.pdf")
	if err == nil {
		defer pdfFile.Close()
		cid, ipfsErr := sh.Add(pdfFile)
		if ipfsErr == nil {
			documentCID = cid
			fmt.Printf("  ✓ Uploaded sample_transcript.pdf to IPFS: %s\n", documentCID)
		}
	}

	if documentCID == "" {
		// Mock document CID for standalone testing without active IPFS
		documentCID = "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
		fmt.Printf("  ℹ IPFS node offline or transcript file omitted — using test CID: %s\n", documentCID)
	}

	// 3. Post-Quantum Encapsulation (ML-KEM-768)
	fmt.Println("\n[2] Performing Post-Quantum Key Encapsulation (Sender)...")
	sharedSecretSender, ciphertext := ek.Encapsulate()
	fmt.Printf("  ✓ Encapsulated Shared Secret: %d bytes (Quantum-Resistant 256-bit symmetric key)\n", len(sharedSecretSender))
	fmt.Printf("  ✓ ML-KEM Ciphertext Size    : %d bytes\n", len(ciphertext))

	// 4. Encrypt Credential Payload with AES-256-GCM using the PQC Shared Secret
	fmt.Println("\n[3] Sealing Credential Data with AES-256-GCM...")
	payload := []byte(fmt.Sprintf(`{"documentCID":"%s","status":"active","issuedTo":"H-0001"}`, documentCID))
	encryptedEnvelope, err := encryptWithSharedKey(sharedSecretSender, payload)
	if err != nil {
		log.Fatalf("Failed to encrypt envelope payload: %v", err)
	}
	fmt.Printf("  ✓ Sealed Envelope Payload: %d bytes\n", len(encryptedEnvelope))

	// 5. Post-Quantum Decapsulation (Holder / Recipient)
	fmt.Println("\n[4] Decapsulating Shared Key & Decrypting Envelope (Recipient)...")
	sharedSecretReceiver, err := dk.Decapsulate(ciphertext)
	if err != nil {
		log.Fatalf("Failed to decapsulate shared key: %v", err)
	}

	if !bytes.Equal(sharedSecretSender, sharedSecretReceiver) {
		log.Fatal("ERROR: Decapsulated shared secret does not match sender secret!")
	}
	fmt.Println("  ✓ Decapsulation Successful: Recovered identical 256-bit symmetric key")

	decryptedPayload, err := decryptWithSharedKey(sharedSecretReceiver, encryptedEnvelope)
	if err != nil {
		log.Fatalf("Failed to decrypt envelope payload: %v", err)
	}
	fmt.Printf("  ✓ Decrypted Payload Content: %s\n", string(decryptedPayload))

	// 6. Upload Final Encrypted Payload to IPFS if available
	fmt.Println("\n[5] Packaging Post-Quantum Verification Envelope...")
	envPackage := fmt.Sprintf(`{"mlkem_ciphertext":"%s","sealed_payload":"%s"}`,
		hex.EncodeToString(ciphertext), hex.EncodeToString(encryptedEnvelope))

	finalCID, err := sh.Add(strings.NewReader(envPackage))
	if err == nil {
		fmt.Printf("  ✓ Final Verification CID on IPFS: %s\n", finalCID)
	} else {
		fmt.Println("  ✓ Post-Quantum Envelope verified successfully in native Go.")
	}

	fmt.Println("\n[Complete] Native Go Post-Quantum cryptographic pipeline executed successfully.")
}
