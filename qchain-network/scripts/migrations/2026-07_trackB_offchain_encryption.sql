-- ─────────────────────────────────────────────────────────────────────────────
-- QChain — Phase 2 · Track B  (Off-chain credential-data encryption)
-- Migration: additive columns only. MySQL-only. Does NOT touch the blockchain.
--
-- Run ONCE against the existing database (no data loss, no downtime required):
--   mysql -u root -p qchain_db < 2026-07_trackB_offchain_encryption.sql
--
-- Safe to run on a live DB. If a column already exists, MySQL will error on that
-- single ALTER — comment it out and re-run, or use a version that guards with
-- INFORMATION_SCHEMA (kept simple here on purpose).
-- ─────────────────────────────────────────────────────────────────────────────

USE qchain_db;

-- Marks how the credential body in `credential_data` is stored:
--   0 = legacy plaintext attributes JSON (pre-Track-B)
--   1 = Track B encrypted envelope JSON
-- Existing rows default to 0; the backfill tool flips them to 1 after encrypting.
ALTER TABLE credentials
    ADD COLUMN enc_version TINYINT NOT NULL DEFAULT 0 AFTER credential_data;

-- Reserved for the FUTURE holder-held-key phase (true B2, end-to-end). Unused by
-- the current org-key implementation, added now so the later phase needs no
-- second migration. Holder/verifier ML-KEM PUBLIC keys only — secrets never touch
-- the server.
ALTER TABLE holders
    ADD COLUMN kem_public_key TEXT NULL;

ALTER TABLE verifiers
    ADD COLUMN kem_public_key TEXT NULL;
