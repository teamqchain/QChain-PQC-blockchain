package main

// crypto.go — the cryptography that makes a credential trustworthy.
//
// Two independent guarantees are built here:
//   • Authenticity — every credential hash is SIGNED with the org's ML-DSA-44
//     (post-quantum) private key, so a verifier can prove the org issued it.
//   • Integrity   — SHA3-256 hashes (see commitment.go for what is hashed) detect
//     any later tampering.
// The IPFS helpers also live here: the encrypted credential envelope is stored
// on IPFS and addressed by its CID, which the chain records and the issuer signs.
//
// ML-DSA-44 comes from liboqs via CGo (Go calling a C library). That C dependency
// is why the Docker image takes longer to build the first time.

import (
	"bytes"
	"encoding/hex"
	"fmt"
	"io"
	"regexp"
	"time"

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

// ipfsTimeout bounds every IPFS call so a stalled daemon fails the request
// instead of hanging it.
const ipfsTimeout = 15 * time.Second

// maxEnvelopeBytes caps what catFromIPFS will read (a 64-field envelope is well
// under 100 KB).
const maxEnvelopeBytes = 1 << 20

// cidPattern accepts CIDv0 ("Qm…", base58) and base32 CIDv1 ("b…") strings, and
// nothing that could be read as an IPFS path or option.
var cidPattern = regexp.MustCompile(`^(Qm[1-9A-HJ-NP-Za-km-z]{44}|b[a-z2-7]{20,100})$`)

// uploadJSONToIPFS uploads raw JSON bytes to IPFS and returns the CID.
func uploadJSONToIPFS(jsonBytes []byte) (string, error) {
	sh := shell.NewShell(ipfsHost)
	sh.SetTimeout(ipfsTimeout)
	cid, err := sh.Add(bytes.NewReader(jsonBytes))
	if err != nil {
		return "", fmt.Errorf("IPFS upload: %w", err)
	}
	return cid, nil
}

// catFromIPFS reads the content stored under cid (at most maxEnvelopeBytes).
func catFromIPFS(cid string) ([]byte, error) {
	if !cidPattern.MatchString(cid) {
		return nil, fmt.Errorf("invalid IPFS CID %q", cid)
	}
	sh := shell.NewShell(ipfsHost)
	sh.SetTimeout(ipfsTimeout)
	rc, err := sh.Cat(cid)
	if err != nil {
		return nil, fmt.Errorf("IPFS cat %s: %w", cid, err)
	}
	defer rc.Close()
	data, err := io.ReadAll(io.LimitReader(rc, maxEnvelopeBytes+1))
	if err != nil {
		return nil, fmt.Errorf("IPFS read %s: %w", cid, err)
	}
	if len(data) > maxEnvelopeBytes {
		return nil, fmt.Errorf("IPFS content %s exceeds %d bytes", cid, maxEnvelopeBytes)
	}
	return data, nil
}
