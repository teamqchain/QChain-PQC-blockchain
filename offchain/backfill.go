package main

// backfill.go — one-shot maintenance routine that encrypts EXISTING plaintext
// `credential_data` rows in place (Track B / Phase 2).
//
// Run it once, after generating the org KEM key and adding it to .env, via:
//
//	RUN_BACKFILL_ENCRYPT=1 <your normal backend start command>
//
// server.go checks that env var early in main(), calls runBackfillEncrypt(), and
// exits. This reuses all the package's crypto so there is no duplicate logic.
//
// Scope: MySQL only. It does NOT touch the blockchain and does NOT re-upload to
// IPFS (the on-chain CID still points at the old plaintext blob; see the handoff
// doc for the optional IPFS re-pin step using the existing /setCID path). Rows are
// matched by enc_version = 0 so the job is idempotent and re-runnable.

import (
	"log"
)

func runBackfillEncrypt() {
	if db == nil {
		log.Fatal("backfill: database not configured (set MYSQL_DSN)")
	}
	if orgKemPubHex == "" {
		log.Fatal("backfill: ORG_KEM_PUBLIC_KEY_HEX not set — nothing to encrypt to")
	}

	rows, err := db.Query(`SELECT credential_id, credential_hash, credential_data
	                         FROM credentials
	                        WHERE enc_version = 0`)
	if err != nil {
		log.Fatalf("backfill: query legacy rows: %v", err)
	}

	type row struct{ id, hash, data string }
	var todo []row
	for rows.Next() {
		var r row
		if err := rows.Scan(&r.id, &r.hash, &r.data); err != nil {
			rows.Close()
			log.Fatalf("backfill: scan: %v", err)
		}
		todo = append(todo, r)
	}
	rows.Close()

	log.Printf("backfill: %d legacy plaintext credential(s) to encrypt", len(todo))
	var done, skipped int
	for _, r := range todo {
		if looksLikeEnvelope([]byte(r.data)) {
			// Already an envelope but flagged v0 — just fix the flag.
			if _, err := db.Exec(`UPDATE credentials SET enc_version = 1 WHERE credential_id = ?`, r.id); err != nil {
				log.Printf("backfill: %s: fix flag failed: %v", r.id, err)
			}
			skipped++
			continue
		}
		enc, err := encryptCredentialData(r.hash, r.data)
		if err != nil {
			log.Printf("backfill: %s: encrypt failed: %v", r.id, err)
			continue
		}
		if _, err := db.Exec(`UPDATE credentials SET credential_data = ?, enc_version = 1 WHERE credential_id = ?`,
			enc, r.id); err != nil {
			log.Printf("backfill: %s: update failed: %v", r.id, err)
			continue
		}
		done++
	}
	log.Printf("backfill: done. encrypted=%d already-envelope=%d total=%d", done, skipped, len(todo))
}
