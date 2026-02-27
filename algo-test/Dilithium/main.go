package main

import (
	"encoding/hex"
	"fmt"
	"log"
	"strings"

	shell "github.com/ipfs/go-ipfs-api"
	"github.com/open-quantum-safe/liboqs-go/oqs"
)

func main() {
	sigName := "ML-DSA-44"
	signer := oqs.Signature{}
	defer signer.Clean()

	if err := signer.Init(sigName, nil); err != nil {
		log.Fatal(err)
	}
	fmt.Printf("[Success] Enabled Post-Quantum Algorithm: %s\n", sigName)

	pubKey, err := signer.GenerateKeyPair()
	if err != nil {
		log.Fatal(err)
	}

	fmt.Printf("[KeyGen] Generated Public Key! Size: %d bytes\n", len(pubKey))

	message := []byte("Student: John Doe | Degree: B.Sc. Computer Science | Year: 2026")

	signature, err := signer.Sign(message)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("[Sign] Signature created! Size: %d bytes\n", len(signature))

	// ==========================================
	// NEW IPFS PHASE: OFFLOADING THE HEAVY DATA
	// ==========================================
	fmt.Println("\n[IPFS] Connecting to local IPFS node...")

	// host.docker.internal tells our Go container to look for IPFS on your Mac's localhost
	sh := shell.NewShell("host.docker.internal:5001")

	// We convert the raw signature bytes into a readable Hex string to store it safely
	signatureHex := hex.EncodeToString(signature)

	// Create a simple JSON-like string containing the student data and the massive signature
	dataToUpload := fmt.Sprintf(`{"student_data": "%s", "pqc_signature": "%s"}`, message, signatureHex)

	// Upload it to IPFS!
	cid, err := sh.Add(strings.NewReader(dataToUpload))
	if err != nil {
		log.Fatalf("[IPFS Error] Could not upload: %v\n(Is your IPFS Docker container running?)", err)
	}

	fmt.Println("✅ [SUCCESS] Data uploaded to IPFS!")
	fmt.Printf("📦 Your CID (Content Identifier) is: %s\n", cid)
	fmt.Println("🚀 THIS tiny CID is what you will store on Hyperledger Fabric!")
}
