-- QChain — Phase 2 (QPortal) + QWallet (Mobile) migration
-- Run ONCE on the VM against the existing populated database:
--     mysql -u root -p qchain_db < qchain-network/scripts/migrations.sql
--
-- NOTE: This is a run-once script. The ALTER statements are NOT idempotent
-- (MySQL 8.0 has no "ADD COLUMN IF NOT EXISTS"). Rerunning errors on the ALTERs;
-- that is expected and harmless. The CREATE TABLE IF NOT EXISTS blocks are safe.
--
-- Design decisions baked in (agreed with PM):
--   * New unified `staff` table backs Manage-Staff UI + IT-Admin counts.
--   * Existing `alerts` and `portal_audit_log` are EXTENDED/reused (no parallel tables).
--   * Credentials enter the wallet ONLY via /mobile/fetchDocument (in_wallet defaults 0).

USE qchain_db;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. CREDENTIALS — mobile wallet fields
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE credentials
    ADD COLUMN is_favorite TINYINT(1)  NOT NULL DEFAULT 0  COMMENT '1 = favorited in wallet',
    ADD COLUMN category    VARCHAR(50)  NOT NULL DEFAULT 'General' COMMENT 'Education/Health/Government/Finance',
    ADD COLUMN in_wallet   TINYINT(1)  NOT NULL DEFAULT 0  COMMENT '0 = issued but not pulled into wallet; 1 = added via fetchDocument';

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. CREDENTIAL_EVENTS — allow verification + expiry events in the activity feed
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE credential_events
    MODIFY COLUMN event_type
    ENUM('issued','revoked','suspended','restored','verified','expired') NOT NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. ALERTS — add acknowledgement + optional subscription link (reused, not replaced)
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE alerts
    ADD COLUMN acknowledged    TINYINT(1)  NOT NULL DEFAULT 0 COMMENT '1 = acknowledged by verifier',
    ADD COLUMN subscription_id VARCHAR(20) NULL               COMMENT 'optional FK to subscriptions',
    ADD INDEX idx_alerts_acknowledged (acknowledged);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. STAFF — unified Manage-Staff table (new; seeded from issuers/verifiers)
--    Roles stored camelCase to match the frontend contract.
--    Status adds 'deleted' for soft-delete (issuers/verifiers ENUM only had active|invited).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS staff (
    id         VARCHAR(20)  PRIMARY KEY,                                    -- STF-0001
    name       VARCHAR(100) NOT NULL DEFAULT '',
    email      VARCHAR(100) NOT NULL,
    portal     ENUM('issuer','verifier') NOT NULL,
    role       VARCHAR(50)  NOT NULL,                                       -- admin|staff|schemaManager|verifier|policyManager
    status     ENUM('active','invited','deleted') NOT NULL DEFAULT 'invited',
    added_date DATE         NOT NULL DEFAULT (CURRENT_DATE),
    INDEX idx_staff_email  (email),
    INDEX idx_staff_portal (portal),
    INDEX idx_staff_status (status)
);

-- Seed from existing demo issuer/verifier so the staff list isn't empty.
INSERT IGNORE INTO staff (id, name, email, portal, role, status, added_date) VALUES
    ('STF-0001', 'Mohammed Al Issuer', 'issuer@uos.ac.ae',   'issuer',   'admin', 'active', CURRENT_DATE),
    ('STF-0002', 'Verifier Portal',    'verifier@uos.ac.ae', 'verifier', 'admin', 'active', CURRENT_DATE);

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. MOBILE_SESSIONS — OTP / QR selective-disclosure sessions
--    PK is `id` (e.g. OTP-481516 or PRES-a1b2c3d4); /resolveSession looks up by id.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS mobile_sessions (
    id            VARCHAR(50)  NOT NULL PRIMARY KEY,                         -- OTP-XXXXXX | PRES-xxxxxxxx
    session_type  ENUM('otp','qr') NOT NULL,
    credential_id VARCHAR(20)  NOT NULL,
    holder_id     VARCHAR(10)  NOT NULL,
    hidden_fields JSON         DEFAULT NULL,                                 -- ["gpa","holderName"] or NULL
    expires_at    DATETIME     NOT NULL,
    created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_mobile_sessions_cred    (credential_id),
    INDEX idx_mobile_sessions_expires (expires_at),
    FOREIGN KEY (credential_id) REFERENCES credentials(credential_id) ON DELETE CASCADE,
    FOREIGN KEY (holder_id)     REFERENCES holders(holder_id)        ON DELETE CASCADE
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. CATALOG — public issuer directory for the wallet "fetch document" flow
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS catalog_issuers (
    id         VARCHAR(50)  NOT NULL PRIMARY KEY,                            -- ORG-UOS-001
    category   VARCHAR(50)  NOT NULL,
    name       VARCHAR(100) NOT NULL,
    is_active  TINYINT(1)   NOT NULL DEFAULT 1,
    created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_catalog_issuers_category (category),
    INDEX idx_catalog_issuers_active   (is_active)
);

CREATE TABLE IF NOT EXISTS catalog_services (
    id          VARCHAR(50)  NOT NULL PRIMARY KEY,                           -- SRV-UOS-101
    issuer_id   VARCHAR(50)  NOT NULL,
    name        VARCHAR(100) NOT NULL,
    description VARCHAR(500) NOT NULL DEFAULT '',
    created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_catalog_services_issuer (issuer_id),
    FOREIGN KEY (issuer_id) REFERENCES catalog_issuers(id) ON DELETE CASCADE
);

INSERT IGNORE INTO catalog_issuers (id, category, name, is_active) VALUES
    ('ORG-UOS-001', 'Education',  'University of Sharjah',                1),
    ('ORG-AUS-001', 'Education',  'American University of Sharjah',       1),
    ('ORG-MOH-001', 'Health',     'Ministry of Health and Prevention',    1),
    ('ORG-DED-001', 'Government', 'Dubai Education Department',            1),
    ('ORG-EAD-001', 'Government', 'ENOC Authority',                       1);

INSERT IGNORE INTO catalog_services (id, issuer_id, name, description) VALUES
    ('SRV-UOS-101', 'ORG-UOS-001', 'Bachelor Degree',         'Request official transcript and degree verification.'),
    ('SRV-UOS-102', 'ORG-UOS-001', 'Graduation Certificate',  'Request official graduation certificate.'),
    ('SRV-AUS-101', 'ORG-AUS-001', 'Student ID',              'Request official student identification document.'),
    ('SRV-MOH-101', 'ORG-MOH-001', 'Health Certificate',      'Request health certification and vaccination records.'),
    ('SRV-DED-101', 'ORG-DED-001', 'Student Record',          'Request official student records and transcript.'),
    ('SRV-EAD-101', 'ORG-EAD-001', 'Employment Certificate',  'Request employment certificate and work authorization.');
