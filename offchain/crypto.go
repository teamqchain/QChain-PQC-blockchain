package main

// crypto.go — the cryptography that makes a credential trustworthy.
//
// Two independent guarantees are built here:
//   • Authenticity — every credential hash is SIGNED with the org's ML-DSA-44
//     (post-quantum) private key, so a verifier can prove the org issued it.
//   • Integrity   — a SHA3-256 hash of the canonical credential JSON detects any
//     later tampering.
// The IPFS upload helper also lives here because storing the canonical JSON off
// -chain (addressed by its content hash / CID) is part of the same issuance step.
//
// ML-DSA-44 comes from liboqs via CGo (Go calling a C library). That C dependency
// is why the Docker image takes longer to build the first time.

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"fmt"

	shell "github.com/ipfs/go-ipfs-api"
	"github.com/open-quantum-safe/liboqs-go/oqs"
	"golang.org/x/crypto/sha3"
)

// sigName is the post-quantum signature algorithm used everywhere in this server.
const sigName = "ML-DSA-44"

// pqcSign signs `message` with the provided hex-encoded private key and returns
// a hex-encoded signature.
func pqcSign(message, privateKeyHex string) (string, error) {
	privKeyBytes, err := hex.DecodeString(privateKeyHex)
	if err != nil {
		return "", fmt.Errorf("decoding private key hex: %w", err)
	}
	signer := oqs.Signature{}
	// defer runs Clean() when this function returns, freeing the C-side memory
	// liboqs allocated — no matter which return path we take.
	defer signer.Clean()
	if err := signer.Init(sigName, privKeyBytes); err != nil {
		return "", fmt.Errorf("init PQC signer with key: %w", err)
	}
	sig, err := signer.Sign([]byte(message))
	if err != nil {
		return "", fmt.Errorf("signing: %w", err)
	}
	return hex.EncodeToString(sig), nil
}

// pqcVerify verifies a hex-encoded signature against a message and hex-encoded
// public key. Verification needs no private key, so Init is called with nil.
func pqcVerify(message, signatureHex, publicKeyHex string) (bool, error) {
	pubKeyBytes, err := hex.DecodeString(publicKeyHex)
	if err != nil {
		return false, fmt.Errorf("decoding public key hex: %w", err)
	}
	sigBytes, err := hex.DecodeString(signatureHex)
	if err != nil {
		return false, fmt.Errorf("decoding signature hex: %w", err)
	}
	verifier := oqs.Signature{}
	defer verifier.Clean()
	if err := verifier.Init(sigName, nil); err != nil {
		return false, fmt.Errorf("init PQC verifier: %w", err)
	}
	valid, err := verifier.Verify([]byte(message), sigBytes, pubKeyBytes)
	if err != nil {
		return false, fmt.Errorf("verify: %w", err)
	}
	return valid, nil
}

// sha3Hex returns the SHA3-256 hex digest of data.
func sha3Hex(data string) string {
	digest := sha3.Sum256([]byte(data))
	return hex.EncodeToString(digest[:])
}

// credentialCanonicalJSON builds a deterministic JSON string from the credential
// payload fields. Go marshals map[string]string keys in sorted order, giving
// canonical output (the same inputs always produce byte-identical JSON, which is
// essential for the hash to be reproducible at verification time).
func credentialCanonicalJSON(holderID, credentialType, info, issuedAt, issuerOrgIDVal string) (string, error) {
	payload := map[string]string{
		"credentialType": credentialType,
		"holderID":       holderID,
		"info":           info,
		"issuedAt":       issuedAt,
		"issuerOrgID":    issuerOrgIDVal,
	}
	b, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}
	return string(b), nil
}

// uploadJSONToIPFS uploads raw JSON bytes to IPFS and returns the CID.
// Returns ("", nil) if IPFS upload is skipped (host not reachable) so that
// issuance can still proceed.
func uploadJSONToIPFS(jsonBytes []byte) (string, error) {
	sh := shell.NewShell(ipfsHost)
	cid, err := sh.Add(bytes.NewReader(jsonBytes))
	if err != nil {
		return "", fmt.Errorf("IPFS upload: %w", err)
	}
	return cid, nil
}
