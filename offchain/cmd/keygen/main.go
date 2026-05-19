// keygen generates a single ML-DSA-44 key pair for use as the organisation-level
// signing key in QChain. Run this ONCE on the VM, then copy the output into .env.
//
// Usage:
//
//	go run offchain/cmd/keygen/main.go
package main

import (
	"encoding/hex"
	"fmt"
	"log"

	"github.com/open-quantum-safe/liboqs-go/oqs"
)

func main() {
	const sigName = "ML-DSA-44"

	signer := oqs.Signature{}
	defer signer.Clean()

	if err := signer.Init(sigName, nil); err != nil {
		log.Fatalf("init ML-DSA-44 signer: %v", err)
	}

	pubKey, err := signer.GenerateKeyPair()
	if err != nil {
		log.Fatalf("generate key pair: %v", err)
	}
	privKey := signer.ExportSecretKey()

	pubHex := hex.EncodeToString(pubKey)
	privHex := hex.EncodeToString(privKey)

	fmt.Println("# ─── ML-DSA-44 Organisation Key Pair ───────────────────────────────────────")
	fmt.Println("# Copy these lines into your .env file. Keep .env in .gitignore — NEVER commit.")
	fmt.Println("#")
	fmt.Printf("ISSUER_PRIVATE_KEY_HEX=%s\n", privHex)
	fmt.Printf("ISSUER_PUBLIC_KEY_HEX=%s\n", pubHex)
	fmt.Println("ISSUER_ORG_ID=GeneralMSP")
	fmt.Println("ISSUER_ORG=general")
	fmt.Println("ISSUER_IDENTITY=issuer1")
	fmt.Println("VERIFIER_ORG=general")
	fmt.Println("VERIFIER_IDENTITY=verifier1")
	fmt.Println("#")
	fmt.Println("# Also set:")
	fmt.Println("# MYSQL_DSN=qchain_user:password@tcp(127.0.0.1:3306)/qchain_db")
	fmt.Println("# NETWORK_ROOT=/path/to/qchain-network")
}
