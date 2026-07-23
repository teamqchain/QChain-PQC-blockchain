package main

// kem.go — Track B (Phase 2) low-level cryptographic primitives for OFF-CHAIN
// confidentiality of credential data.
//
// This file adds the post-quantum key-establishment + symmetric-encryption
// building blocks used by envelope.go. It deliberately does NOT touch anything
// on-chain: the Hyperledger Fabric chaincode, the ledger record, the on-chain
// signature/hash and the verification path are all unchanged. These primitives
// only protect the two OFF-CHAIN copies of the credential body (IPFS + the
// MySQL `credential_data` column).
//
// Design (hybrid KEM-DEM, the same shape TLS 1.3 / HPKE / age use):
//   • ML-KEM-768 (FIPS 203, "Kyber") establishes a 32-byte shared secret.
//   • HKDF-SHA3-256 derives a single-use, per-field key-wrapping key from it.
//   • AES-256-GCM encrypts the field bytes and wraps the per-field data key.
// AES-256 and SHA3 are already quantum-resistant; ML-KEM handles the quantum-safe
// key establishment — so nothing here is a "harvest-now-decrypt-later" weak point.
//
// liboqs-go (CGo) provides ML-KEM. It is the same library already used for
// ML-DSA-44 signing in crypto.go, so no new native dependency is introduced.

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"

	"github.com/open-quantum-safe/liboqs-go/oqs"
	"golang.org/x/crypto/hkdf"
	"golang.org/x/crypto/sha3"
)

// kemName is the ML-KEM mechanism name, resolved at startup by resolveKEMName().
// FIPS-203 liboqs builds expose "ML-KEM-768"; older builds expose "Kyber768".
var kemName = "ML-KEM-768"

// resolveKEMName picks the first ML-KEM mechanism this liboqs build actually
// supports. It probes by attempting Init (avoids depending on a specific helper
// API across liboqs-go versions). Returns "" if none is available.
func resolveKEMName() string {
	for _, n := range []string{"ML-KEM-768", "Kyber768"} {
		k := oqs.KeyEncapsulation{}
		err := k.Init(n, nil)
		k.Clean()
		if err == nil {
			return n
		}
	}
	return ""
}

// kemGenerateKeypair returns a fresh (publicHex, secretHex) ML-KEM key pair.
func kemGenerateKeypair() (pubHex, secHex string, err error) {
	k := oqs.KeyEncapsulation{}
	defer k.Clean()
	if err = k.Init(kemName, nil); err != nil {
		return "", "", fmt.Errorf("init KEM %q: %w", kemName, err)
	}
	pub, err := k.GenerateKeyPair()
	if err != nil {
		return "", "", fmt.Errorf("generate KEM key pair: %w", err)
	}
	sec := k.ExportSecretKey()
	return hex.EncodeToString(pub), hex.EncodeToString(sec), nil
}

// kemEncap encapsulates a fresh shared secret to a recipient's public key.
// Returns (kemCiphertextHex, sharedSecretHex).
func kemEncap(pubHex string) (kemCtHex, ssHex string, err error) {
	pub, err := hex.DecodeString(pubHex)
	if err != nil {
		return "", "", fmt.Errorf("decode KEM public key: %w", err)
	}
	k := oqs.KeyEncapsulation{}
	defer k.Clean()
	if err = k.Init(kemName, nil); err != nil {
		return "", "", fmt.Errorf("init KEM: %w", err)
	}
	ct, ss, err := k.EncapSecret(pub)
	if err != nil {
		return "", "", fmt.Errorf("KEM encapsulate: %w", err)
	}
	return hex.EncodeToString(ct), hex.EncodeToString(ss), nil
}

// kemDecap recovers the shared secret from a KEM ciphertext using the secret key.
func kemDecap(kemCtHex, secHex string) (ssHex string, err error) {
	ct, err := hex.DecodeString(kemCtHex)
	if err != nil {
		return "", fmt.Errorf("decode KEM ciphertext: %w", err)
	}
	sec, err := hex.DecodeString(secHex)
	if err != nil {
		return "", fmt.Errorf("decode KEM secret key: %w", err)
	}
	k := oqs.KeyEncapsulation{}
	defer k.Clean()
	if err = k.Init(kemName, sec); err != nil {
		return "", fmt.Errorf("init KEM with secret: %w", err)
	}
	ss, err := k.DecapSecret(ct)
	if err != nil {
		return "", fmt.Errorf("KEM decapsulate: %w", err)
	}
	return hex.EncodeToString(ss), nil
}

// deriveKey runs HKDF-SHA3-256 over a shared secret with a context string and
// returns a 32-byte key (hex). The context binds each derived key to the
// credential and field, so every key-wrapping key is single-use.
func deriveKey(ssHex, info string) (keyHex string, err error) {
	ss, err := hex.DecodeString(ssHex)
	if err != nil {
		return "", fmt.Errorf("decode shared secret: %w", err)
	}
	r := hkdf.New(sha3.New256, ss, nil, []byte(info))
	out := make([]byte, 32)
	if _, err := io.ReadFull(r, out); err != nil {
		return "", fmt.Errorf("hkdf read: %w", err)
	}
	return hex.EncodeToString(out), nil
}

// aesSeal encrypts plaintext with AES-256-GCM using a fresh random nonce.
// Returns (nonceHex, ciphertextHex) where the ciphertext already includes the
// 16-byte GCM tag.
func aesSeal(keyHex string, plaintext []byte) (nonceHex, ctHex string, err error) {
	gcm, err := newGCM(keyHex)
	if err != nil {
		return "", "", err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err = io.ReadFull(rand.Reader, nonce); err != nil {
		return "", "", fmt.Errorf("nonce: %w", err)
	}
	ct := gcm.Seal(nil, nonce, plaintext, nil)
	return hex.EncodeToString(nonce), hex.EncodeToString(ct), nil
}

// aesOpen reverses aesSeal.
func aesOpen(keyHex, nonceHex, ctHex string) ([]byte, error) {
	gcm, err := newGCM(keyHex)
	if err != nil {
		return nil, err
	}
	nonce, err := hex.DecodeString(nonceHex)
	if err != nil {
		return nil, fmt.Errorf("decode nonce: %w", err)
	}
	ct, err := hex.DecodeString(ctHex)
	if err != nil {
		return nil, fmt.Errorf("decode ciphertext: %w", err)
	}
	return gcm.Open(nil, nonce, ct, nil)
}

// zeroNonce is safe for key wrapping ONLY because each key-wrapping key produced
// by deriveKey is single-use (bound to credential+field via HKDF context).
var zeroNonce = make([]byte, 12)

// wrapKey encrypts a 32-byte data key under a single-use key-wrapping key.
func wrapKey(kwkHex string, keyBytes []byte) (string, error) {
	gcm, err := newGCM(kwkHex)
	if err != nil {
		return "", err
	}
	return hex.EncodeToString(gcm.Seal(nil, zeroNonce, keyBytes, nil)), nil
}

// unwrapKey reverses wrapKey.
func unwrapKey(kwkHex, wrapHex string) ([]byte, error) {
	gcm, err := newGCM(kwkHex)
	if err != nil {
		return nil, err
	}
	wrap, err := hex.DecodeString(wrapHex)
	if err != nil {
		return nil, fmt.Errorf("decode wrap: %w", err)
	}
	return gcm.Open(nil, zeroNonce, wrap, nil)
}

// generateOrgKEM prints a fresh organisation ML-KEM key pair as .env lines, then
// returns. It is invoked as a one-shot container mode (GENERATE_ORG_KEM=1) so
// operators never need cmd/ in the Docker image or liboqs installed on the host —
// the same running server image can generate the key.
func generateOrgKEM() {
	pub, sec, err := kemGenerateKeypair()
	if err != nil {
		fmt.Println("ERROR generating ML-KEM key pair:", err)
		return
	}
	fmt.Println("# ─── Organisation ML-KEM Key Pair (Track B off-chain encryption) ──────────────")
	fmt.Println("# Append these two lines to offchain/.env. Keep .env in .gitignore; never commit.")
	fmt.Printf("# Algorithm: %s\n", kemName)
	fmt.Printf("ORG_KEM_PUBLIC_KEY_HEX=%s\n", pub)
	fmt.Printf("ORG_KEM_PRIVATE_KEY_HEX=%s\n", sec)
}

// newGCM builds an AES-256-GCM AEAD from a hex key.
func newGCM(keyHex string) (cipher.AEAD, error) {
	key, err := hex.DecodeString(keyHex)
	if err != nil {
		return nil, fmt.Errorf("decode AES key: %w", err)
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, fmt.Errorf("aes cipher: %w", err)
	}
	return cipher.NewGCM(block)
}
