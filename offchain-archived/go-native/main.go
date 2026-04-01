package main

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/cloudflare/circl/sign/mldsa/mldsa44"
	shell "github.com/ipfs/go-ipfs-api"
)

// getIPFSShell creates an IPFS shell connection using environment variables
func getIPFSShell() *shell.Shell {
	host := os.Getenv("IPFS_API_HOST")
	if host == "" {
		host = "localhost"
	}
	port := os.Getenv("IPFS_API_PORT")
	if port == "" {
		port = "5001"
	}
	return shell.NewShell(fmt.Sprintf("%s:%s", host, port))
}

func main() {
	fmt.Println("[Success] Enabled Pure Go Post-Quantum Algorithm: ML-DSA-44 (CIRCL)")

	// Generate Keys natively in Go
	pubKey, privKey, err := mldsa44.GenerateKey(rand.Reader)
	if err != nil {
		log.Fatal(err)
	}

	pubBytes := pubKey.Bytes()
	privBytes := privKey.Bytes()

	fmt.Printf("[KeyGen] Generated Public Key! Size: %d bytes\n", len(pubBytes))
	fmt.Printf("[KeyGen] EXPOSED Private Key! Size: %d bytes\n", len(privBytes))

	// Upload the actual PDF to IPFS
	fmt.Println("\n[1] Uploading actual PDF Transcript to IPFS...")
	sh := getIPFSShell()

	pdfFile, err := os.Open("transcript.pdf")
	if err != nil {
		log.Fatalf("Failed to open transcript.pdf. Is it in the folder?: %v", err)
	}
	defer pdfFile.Close()

	documentCID, err := sh.Add(pdfFile)
	if err != nil {
		log.Fatalf("Failed to upload PDF to IPFS: %v", err)
	}
	fmt.Printf("📄 Transcript PDF CID: %s\n", documentCID)

	// Sign the CID using CIRCL ML-DSA-44
	fmt.Println("\n[2] Signing the Transcript CID...")
	msg := []byte(documentCID)
	signature := make([]byte, mldsa44.SignatureSize)

	// SignTo(privateKey, message, context, randomized, outputSignature)
	err = mldsa44.SignTo(privKey, msg, nil, true, signature)
	if err != nil {
		log.Fatalf("Signing failed: %v", err)
	}
	fmt.Printf("✍️ Signature created for CID! Size: %d bytes\n", len(signature))

	isValid := mldsa44.Verify(pubKey, msg, nil, signature)
	fmt.Printf("🔍 Local Verification Check: %v\n", isValid)

	// Upload the Signature data to IPFS
	fmt.Println("\n[3] Uploading Quantum Signature payload to IPFS...")
	signatureHex := hex.EncodeToString(signature)

	dataToUpload := fmt.Sprintf(`{"document_cid": "%s", "pqc_signature": "%s"}`, documentCID, signatureHex)

	finalCID, err := sh.Add(strings.NewReader(dataToUpload))
	if err != nil {
		log.Fatalf("Failed to upload signature payload: %v", err)
	}

	fmt.Printf("📦 Final Verification CID (Store this on Fabric!): %s\n", finalCID)
}
