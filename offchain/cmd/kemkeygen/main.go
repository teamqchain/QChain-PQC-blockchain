// kemkeygen generates a single ML-KEM-768 key pair for use as the organisation-
// level OFF-CHAIN encryption key in QChain (Track B / Phase 2). Run this ONCE,
// then copy the output into offchain/.env.
//
// This key encrypts the credential body stored in IPFS and in the MySQL
// `credential_data` column. It has nothing to do with the blockchain: no chaincode
// change, no ledger change, no network restart.
//
// Usage:
//
//	go run offchain/cmd/kemkeygen/main.go
package main

import (
	"encoding/hex"
	"fmt"
	"log"

	"github.com/open-quantum-safe/liboqs-go/oqs"
)

func main() {
	// Prefer the FIPS-203 name; fall back to the older liboqs name.
	name := "ML-KEM-768"
	probe := oqs.KeyEncapsulation{}
	if err := probe.Init(name, nil); err != nil {
		probe.Clean()
		name = "Kyber768"
	} else {
		probe.Clean()
	}

	kem := oqs.KeyEncapsulation{}
	defer kem.Clean()
	if err := kem.Init(name, nil); err != nil {
		log.Fatalf("init %s (is this liboqs build compiled with ML-KEM enabled?): %v", name, err)
	}

	pubKey, err := kem.GenerateKeyPair()
	if err != nil {
		log.Fatalf("generate key pair: %v", err)
	}
	secKey := kem.ExportSecretKey()

	fmt.Println("# ─── Organisation ML-KEM Key Pair (Track B off-chain encryption) ──────────────")
	fmt.Println("# Copy these lines into your offchain/.env file. Keep .env in .gitignore.")
	fmt.Println("# NEVER commit the private key. This key can decrypt every off-chain credential body.")
	fmt.Printf("# Algorithm: %s\n", name)
	fmt.Println("#")
	fmt.Printf("ORG_KEM_PUBLIC_KEY_HEX=%s\n", hex.EncodeToString(pubKey))
	fmt.Printf("ORG_KEM_PRIVATE_KEY_HEX=%s\n", hex.EncodeToString(secKey))
	fmt.Println("#")
	fmt.Println("# After setting these, restart the Go backend. New issuances will encrypt the")
	fmt.Println("# off-chain body automatically. To encrypt existing rows, run once:")
	fmt.Println("#   RUN_BACKFILL_ENCRYPT=1 <your normal backend start command>")
}
