-- ─────────────────────────────────────────────────────────────────────────────
-- QChain — Track H (Holder-held keys and presentation signing)
-- Migration: additive columns only. MySQL-only. Does NOT touch the blockchain.
--
-- Run ONCE against the existing database:
--   mysql -u root -p qchain_db < 2026-09_trackH_holder_signing.sql
-- ─────────────────────────────────────────────────────────────────────────────

USE qchain_db;

-- Holder ML-DSA-44 public key (for presentation signature verification).
-- kem_public_key already exists from the Track B migration.
ALTER TABLE holders
    ADD COLUMN dsa_public_key TEXT NULL;

-- Store the holder's signed disclosed payload + signature on the session row.
ALTER TABLE mobile_sessions
    ADD COLUMN disclosed_payload JSON NULL;

ALTER TABLE mobile_sessions
    ADD COLUMN holder_signature TEXT NULL;
