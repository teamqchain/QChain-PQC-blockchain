package main

// holder_keys.go — Track B2 (Phase 2) holder ML-KEM key management.
//
// Holder KEM key pairs enable per-holder off-chain encryption: at issuance the
// credential envelope is wrapped to the holder's ML-KEM-768 public key, so only
// the holder (or, during testing, the server with the holder's private key) can
// decrypt it.
//
// Key storage model:
//   • PUBLIC KEY  → MySQL `holders.kem_public_key` column. Persisted in DB so the
//                   issuer can look it up at issuance without any external call.
//   • PRIVATE KEY → TESTING: loaded from `offchain/.env.holder_keys` (gitignored)
//                   into the in-memory map `holderKemKeys` at startup.
//                   PRODUCTION: lives exclusively on the holder's device (QWallet
//                   secure storage). The server never sees it.
//
// This file provides:
//   • loadHolderKeysFile() — reads .env.holder_keys into holderKemKeys at startup.
//   • handleRegisterHolderKey() — POST /mobile/registerHolderKey endpoint.
//   • runGenerateHolderKeys() — one-shot backfill (GENERATE_HOLDER_KEYS=1).

import (
	"bufio"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strings"
)

// holderKeysFileName is the name of the env-style file that holds testing-only
// holder KEM private keys. It lives alongside .env and is gitignored.
const holderKeysFileName = ".env.holder_keys"

// holderKeysFilePath returns the absolute path to the holder keys file, located
// in the same directory as this source file (i.e. offchain/).
func holderKeysFilePath() string {
	// Try working directory first (Docker / normal run), fall back to source dir.
	if _, err := os.Stat(holderKeysFileName); err == nil {
		abs, _ := filepath.Abs(holderKeysFileName)
		return abs
	}
	_, src, _, _ := runtime.Caller(0)
	return filepath.Join(filepath.Dir(src), holderKeysFileName)
}

// loadHolderKeysFile reads the .env.holder_keys file into the holderKemKeys map.
// The file format is one key per line: HOLDER_ID=PRIVATE_KEY_HEX
// Lines starting with # and blank lines are ignored.
// Returns the number of keys loaded. Non-fatal if the file doesn't exist.
func loadHolderKeysFile() int {
	holderKemKeys = make(map[string]string)

	path := holderKeysFilePath()
	f, err := os.Open(path)
	if err != nil {
		if os.IsNotExist(err) {
			log.Printf("INFO: %s not found — no holder KEM private keys loaded (holder-side decryption unavailable until keys are registered)", holderKeysFileName)
			return 0
		}
		log.Printf("WARNING: could not open %s: %v", holderKeysFileName, err)
		return 0
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	count := 0
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		eq := strings.IndexByte(line, '=')
		if eq < 1 {
			continue
		}
		holderID := strings.TrimSpace(line[:eq])
		privHex := strings.TrimSpace(line[eq+1:])
		if holderID != "" && privHex != "" {
			holderKemKeys[holderID] = privHex
			count++
		}
	}
	if err := scanner.Err(); err != nil {
		log.Printf("WARNING: error reading %s: %v", holderKeysFileName, err)
	}
	return count
}

// holderKemPrivByID returns the holder's KEM private key from the in-memory map.
// Returns ("", nil) if the holder has no private key loaded.
func holderKemPrivByID(holderID string) (string, error) {
	if holderKemKeys == nil {
		return "", fmt.Errorf("holder KEM keys not loaded")
	}
	priv, ok := holderKemKeys[holderID]
	if !ok {
		return "", nil
	}
	return priv, nil
}

// POST /mobile/registerHolderKey — register a holder's ML-KEM-768 key pair.
//
// The public key is stored in the database (holders.kem_public_key). The private
// key is returned in the response for the caller to store securely — the server
// does NOT persist it in the database.
//
// Request body: { "emiratesID": "784-...", "kemPublicKeyHex": "...", "kemPrivateKeyHex": "..." }
// For testing, if kemPublicKeyHex/kemPrivateKeyHex are empty, the server generates
// a fresh key pair, stores the public key in DB, and returns both.
func handleRegisterHolderKey(w http.ResponseWriter, r *http.Request) {
	var req struct {
		EmiratesID      string `json:"emiratesID"`
		KemPublicKeyHex string `json:"kemPublicKeyHex"`
		KemPrivateKeyHex string `json:"kemPrivateKeyHex"`
	}
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if req.EmiratesID == "" {
		writeError(w, http.StatusBadRequest, "missing emiratesID")
		return
	}

	holderID, _, err := holderByEmiratesID(req.EmiratesID)
	if err != nil {
		writeError(w, http.StatusNotFound, "holder not found: "+err.Error())
		return
	}

	pubHex := req.KemPublicKeyHex
	privHex := req.KemPrivateKeyHex

	// If no key pair provided, generate one server-side (testing convenience).
	if pubHex == "" || privHex == "" {
		var genErr error
		pubHex, privHex, genErr = kemGenerateKeypair()
		if genErr != nil {
			writeError(w, http.StatusInternalServerError, "key generation failed: "+genErr.Error())
			return
		}
	}

	// Validate the key pair with a test encap/decap round-trip.
	ctHex, ssEnc, encErr := kemEncap(pubHex)
	if encErr != nil {
		writeError(w, http.StatusBadRequest, "invalid KEM public key: "+encErr.Error())
		return
	}
	ssDec, decErr := kemDecap(ctHex, privHex)
	if decErr != nil {
		writeError(w, http.StatusBadRequest, "invalid KEM private key: "+decErr.Error())
		return
	}
	if ssEnc != ssDec {
		writeError(w, http.StatusBadRequest, "KEM key pair mismatch: encap/decap shared secrets differ")
		return
	}

	// Store public key in DB.
	if dbErr := updateHolderKemPub(holderID, pubHex); dbErr != nil {
		writeError(w, http.StatusInternalServerError, "database error: "+dbErr.Error())
		return
	}

	// Cache private key in memory for this session.
	if holderKemKeys == nil {
		holderKemKeys = make(map[string]string)
	}
	holderKemKeys[holderID] = privHex

	log.Printf("Registered KEM key for holder %s (Emirates ID: %s)", holderID, req.EmiratesID)

	writeJSON(w, http.StatusOK, map[string]any{
		"success":         true,
		"holderID":        holderID,
		"kemPublicKeyHex": pubHex,
		"kemPrivateKeyHex": privHex,
		"note":            "Store the private key securely on the holder's device. The server does NOT persist it.",
	})
}

// runGenerateHolderKeys is a one-shot maintenance routine that generates ML-KEM-768
// key pairs for every holder that doesn't have one yet. Public keys go into the
// database; private keys are written to .env.holder_keys (for testing) and also
// appended to the response log.
//
// Triggered by GENERATE_HOLDER_KEYS=1 environment variable at startup.
func runGenerateHolderKeys() {
	if db == nil {
		log.Fatal("generate-holder-keys: database not configured (set MYSQL_DSN)")
	}

	rows, err := db.Query(`SELECT holder_id FROM holders WHERE kem_public_key IS NULL OR kem_public_key = ''`)
	if err != nil {
		log.Fatalf("generate-holder-keys: query holders: %v", err)
	}

	var holderIDs []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			log.Fatalf("generate-holder-keys: scan: %v", err)
		}
		holderIDs = append(holderIDs, id)
	}
	rows.Close()

	log.Printf("generate-holder-keys: %d holder(s) without KEM keys", len(holderIDs))
	if len(holderIDs) == 0 {
		log.Println("generate-holder-keys: nothing to do")
		return
	}

	// Open the env file for appending (create if not exists).
	keyFilePath := holderKeysFilePath()
	f, err := os.OpenFile(keyFilePath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0600)
	if err != nil {
		log.Fatalf("generate-holder-keys: cannot open %s: %v", keyFilePath, err)
	}
	defer f.Close()

	// Write header if file is new/empty.
	info, _ := f.Stat()
	if info.Size() == 0 {
		fmt.Fprintln(f, "# ─── QChain Track B2 — Holder KEM Private Keys ────────────────────────────────")
		fmt.Fprintln(f, "# TESTING ONLY. In production, private keys live on the holder's device (QWallet).")
		fmt.Fprintln(f, "# Format: HOLDER_ID=ML_KEM_768_PRIVATE_KEY_HEX")
		fmt.Fprintln(f, "# This file MUST be gitignored. NEVER commit private keys.")
		fmt.Fprintln(f, "# ─────────────────────────────────────────────────────────────────────────────")
		fmt.Fprintln(f)
	}

	var generated int
	for _, holderID := range holderIDs {
		pubHex, privHex, genErr := kemGenerateKeypair()
		if genErr != nil {
			log.Printf("generate-holder-keys: %s: keygen failed: %v", holderID, genErr)
			continue
		}

		// Store public key in DB.
		if dbErr := updateHolderKemPub(holderID, pubHex); dbErr != nil {
			log.Printf("generate-holder-keys: %s: DB update failed: %v", holderID, dbErr)
			continue
		}

		// Write private key to env file.
		fmt.Fprintf(f, "%s=%s\n", holderID, privHex)

		generated++
		log.Printf("generate-holder-keys: %s: key pair generated (pub stored in DB, priv in %s)", holderID, holderKeysFileName)
	}

	log.Printf("generate-holder-keys: done. generated=%d total=%d", generated, len(holderIDs))
	log.Printf("generate-holder-keys: private keys written to %s", keyFilePath)

	// Also output as JSON for easy programmatic consumption.
	keyMap := make(map[string]string)
	for _, id := range holderIDs {
		if pub, err := holderKemPubByID(id); err == nil && pub != "" {
			keyMap[id] = pub
		}
	}
	if len(keyMap) > 0 {
		j, _ := json.MarshalIndent(keyMap, "", "  ")
		log.Printf("generate-holder-keys: public keys registered:\n%s", string(j))
	}
}
