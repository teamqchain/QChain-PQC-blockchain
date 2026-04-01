package main

import (
	"encoding/hex"
	"fmt"
	"log"
	"os"
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

	// Displaying private key just for demonstration (Will update during final implementation to not expose it)
	privateKey := signer.ExportSecretKey()
	fmt.Printf("[KeyGen] EXPOSED Private Key! Size: %d bytes\n", len(privateKey))

	// 1. Upload the actual PDF to IPFS
	fmt.Println("\n[1] Uploading document(s) to IPFS...")
	sh := shell.NewShell("host.docker.internal:5001")

	// Open document stored within the same folder
	pdfFile, err := os.Open("../sample_transcript.pdf")
	if err != nil {
		log.Fatalf("Failed to open transcript.pdf. Is it in the folder?: %v", err)
	}
	defer pdfFile.Close()

	documentCID, err := sh.Add(pdfFile)
	if err != nil {
		log.Fatalf("Failed to upload PDF to IPFS: %v", err)
	}
	fmt.Printf("📄 Transcript PDF CID: %s\n", documentCID)

	// 2. Sign the CID
	fmt.Println("\n[2] Signing the Transcript CID...")
	signature, err := signer.Sign([]byte(documentCID))
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("✍️ Signature created for CID! Size: %d bytes\n", len(signature))

	// 3. Upload the Signature data to IPFS
	fmt.Println("\n[3] Uploading Quantum Signature payload to IPFS...")
	signatureHex := hex.EncodeToString(signature)

	// Link the document CID and the signature together
	dataToUpload := fmt.Sprintf(`{"document_cid": "%s", "pqc_signature": "%s"}`, documentCID, signatureHex)

	finalCID, err := sh.Add(strings.NewReader(dataToUpload))
	if err != nil {
		log.Fatalf("Failed to upload signature payload: %v", err)
	}

	fmt.Printf("📦 Final Verification CID (Store this on Fabric!): %s\n", finalCID)
}
