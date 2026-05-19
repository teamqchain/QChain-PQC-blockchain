-- QChain MySQL Schema
-- Run once on the VM: mysql -u root -p < schema.sql
-- Column comments marked [NOW] are wired in the summer sprint.
-- Columns marked [LATER] are created now so FK constraints work; wired to the frontend later.

CREATE DATABASE IF NOT EXISTS qchain_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE qchain_db;

-- ─── ORGANISATIONS ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS government_organization (
    org_id          VARCHAR(20)  PRIMARY KEY DEFAULT 'ORG-GOV-001',
    org_name        VARCHAR(100) NOT NULL DEFAULT 'Government of UAE',
    fabric_msp_id   VARCHAR(50)  NOT NULL DEFAULT 'GovernmentMSP',
    peer_endpoint   VARCHAR(150) DEFAULT 'peer0.government.uae.com:7051',
    public_key      TEXT,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS uos_organization (
    org_id            VARCHAR(20)  PRIMARY KEY DEFAULT 'ORG-UOS-001',
    org_name          VARCHAR(100) NOT NULL DEFAULT 'University of Sharjah',
    fabric_msp_id     VARCHAR(50)  NOT NULL DEFAULT 'GeneralMSP',
    peer_endpoint     VARCHAR(150) DEFAULT 'peer0.general.uae.com:9051',
    public_key        TEXT,                                                         -- [NOW]  ML-DSA-44 hex public key
    signing_algorithm ENUM('dilithium','ecdsa') DEFAULT 'dilithium',               -- [LATER] settings page
    display_name      VARCHAR(200),                                                 -- [LATER] "University of Sharjah — Registrar Office"
    is_active         BOOLEAN DEFAULT TRUE,
    created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- ─── PEOPLE ───────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS holders (
    holder_id           VARCHAR(10)  PRIMARY KEY,                                   -- [NOW]  H-0001, H-0002
    emirates_id         VARCHAR(20)  NOT NULL UNIQUE,                               -- [NOW]  lookup key
    first_name          VARCHAR(50),                                                -- [NOW]  filled at wallet first login
    last_name           VARCHAR(50),
    email               VARCHAR(100) UNIQUE,                                        -- [LATER] used as username after setup
    password_hash       VARCHAR(255),                                               -- [LATER] bcrypt
    date_of_birth       DATE,                                                       -- [LATER]
    phone               VARCHAR(20),                                                -- [LATER]
    holder_type         ENUM('bachelor_student','master_student','phd_student','employee','medical'), -- [LATER]
    college             VARCHAR(100),                                               -- [LATER]
    wallet_address      VARCHAR(50),                                                -- [LATER] QWallet device identifier
    fabric_holder_id    VARCHAR(15)  NOT NULL UNIQUE,                              -- [NOW]  matches blockchain H-XXXX key
    is_wallet_activated BOOLEAN DEFAULT FALSE,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS issuers (
    issuer_id       VARCHAR(20)  PRIMARY KEY,                                       -- [NOW]  ISS-UOS-0001
    org_id          VARCHAR(20)  NOT NULL DEFAULT 'ORG-UOS-001',
    fabric_identity VARCHAR(100) NOT NULL,                                          -- [NOW]  wallet .id filename
    full_name       VARCHAR(100) NOT NULL,
    email           VARCHAR(100) NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    role            ENUM('admin','staff','schema_manager') NOT NULL DEFAULT 'staff',-- [LATER] IssuerRole
    status          ENUM('active','invited') NOT NULL DEFAULT 'active',             -- [LATER] StaffStatus
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS verifiers (
    verifier_id     VARCHAR(20)  PRIMARY KEY,                                       -- [NOW]  VER-UOS-0001
    org_id          VARCHAR(20)  NOT NULL DEFAULT 'ORG-UOS-001',
    full_name       VARCHAR(100) NOT NULL,
    email           VARCHAR(100) NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    role            ENUM('admin','verifier','policy_manager') NOT NULL DEFAULT 'verifier', -- [LATER] VerifierRole
    status          ENUM('active','invited') NOT NULL DEFAULT 'active',             -- [LATER] StaffStatus
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- ─── SCHEMA MANAGEMENT ────────────────────────────────────────────────────────
-- [LATER] Credential type schemas managed via the IT Admin section of QPortal.

CREATE TABLE IF NOT EXISTS `schemas` (
    schema_id          VARCHAR(20)  PRIMARY KEY,                                    -- SCH-001
    org_id             VARCHAR(20)  NOT NULL DEFAULT 'ORG-UOS-001',
    name               VARCHAR(100) NOT NULL,                                       -- 'BSc Degree'
    description        TEXT,
    category           VARCHAR(50),                                                 -- 'Academic','Medical','Professional','Corporate'
    requirements       JSON,                                                        -- list of requirement strings
    status             ENUM('active','archived') NOT NULL DEFAULT 'active',
    credentials_issued INT UNSIGNED DEFAULT 0,
    created_by         VARCHAR(20),
    created_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES issuers(issuer_id)
);

CREATE TABLE IF NOT EXISTS schema_fields (
    field_id            VARCHAR(20)  PRIMARY KEY,                                   -- FLD-001
    schema_id           VARCHAR(20)  NOT NULL,
    label               VARCHAR(100) NOT NULL,                                      -- 'Degree Title'
    field_type          ENUM('text','number','date','yes_no','dropdown') NOT NULL,
    is_required         BOOLEAN DEFAULT TRUE,
    visible_to_verifier BOOLEAN DEFAULT TRUE,
    dropdown_options    JSON,                                                        -- option strings (dropdown only)
    sort_order          TINYINT UNSIGNED DEFAULT 0,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (schema_id) REFERENCES `schemas`(schema_id)
);

-- ─── CREDENTIALS ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS credentials (
    credential_id       VARCHAR(20)  PRIMARY KEY,                                   -- [NOW]  CRED-0001 (display ID)
    fabric_cred_id      VARCHAR(200) NOT NULL UNIQUE,                              -- [NOW]  CRED-{full txID}
    holder_id           VARCHAR(10)  NOT NULL,
    issuer_id           VARCHAR(20)  NOT NULL,
    org_id              VARCHAR(20)  NOT NULL DEFAULT 'ORG-UOS-001',
    schema_id           VARCHAR(20),                                                -- [LATER] NULL until schema integration
    credential_type     VARCHAR(100) NOT NULL,                                      -- [NOW]  'BSc Computer Science'
    credential_hash     VARCHAR(128) NOT NULL,                                      -- [NOW]  SHA3-256 hex of canonical JSON
    issuer_signature    TEXT         NOT NULL,                                      -- [NOW]  hex ML-DSA-44 signature
    issuer_public_key   TEXT         NOT NULL,                                      -- [NOW]  hex org public key at issuance time
    signing_algorithm   ENUM('dilithium','ecdsa') NOT NULL DEFAULT 'dilithium',
    ipfs_cid            VARCHAR(100),                                               -- [NOW]  nullable if IPFS skipped
    status              ENUM('active','revoked','suspended','expired') NOT NULL DEFAULT 'active',
    credential_data     JSON         NOT NULL,                                      -- [NOW]  parsed attributes for display
    issued_at           TIMESTAMP    NOT NULL,
    expiry_date         TIMESTAMP    NULL,                                          -- [LATER]
    revoked_at          TIMESTAMP    NULL,                                          -- [NOW]  set on revocation
    revoked_by          VARCHAR(20),                                                -- [LATER] issuer_id who revoked
    revoked_reason      VARCHAR(500),                                               -- [LATER]
    suspended_reason    VARCHAR(500),                                               -- [LATER]
    suspended_until     TIMESTAMP    NULL,                                          -- [LATER]
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (holder_id)  REFERENCES holders(holder_id),
    FOREIGN KEY (issuer_id)  REFERENCES issuers(issuer_id),
    FOREIGN KEY (schema_id)  REFERENCES `schemas`(schema_id)
);

-- ─── VERIFICATION LOGS ────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS verification_logs (
    log_id              VARCHAR(30)  PRIMARY KEY,                                   -- VL-{timestamp_ms}
    credential_id       VARCHAR(20),                                                -- [NOW]  display ID (nullable if not found)
    fabric_cred_id      VARCHAR(200),                                               -- [NOW]  full blockchain ID
    credential_type     VARCHAR(100),                                               -- [LATER] for history display
    holder_name         VARCHAR(200),                                               -- [LATER] for history display
    issuer_name         VARCHAR(100),                                               -- [LATER] for history display
    verifier_id         VARCHAR(20),
    verify_method       ENUM('qr_scan','manual','file_upload','batch') DEFAULT 'manual', -- [LATER]
    result              ENUM('success','failure') NOT NULL,
    failure_reason      VARCHAR(200),
    chain_verified      BOOLEAN DEFAULT FALSE,
    hash_verified       BOOLEAN DEFAULT FALSE,
    signature_verified  BOOLEAN DEFAULT FALSE,
    status_at_verify    VARCHAR(20),
    verified_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (verifier_id) REFERENCES verifiers(verifier_id)
);

-- ─── POLICIES ─────────────────────────────────────────────────────────────────
-- [LATER] Verification policies — Policies section of QPortal.

CREATE TABLE IF NOT EXISTS policies (
    policy_id   VARCHAR(20)  PRIMARY KEY,                                           -- POL-001
    org_id      VARCHAR(20)  NOT NULL DEFAULT 'ORG-UOS-001',
    policy_name VARCHAR(200) NOT NULL,
    applies_to  VARCHAR(100),                                                       -- 'All Credentials', 'Academic Credentials'
    status      ENUM('active','inactive','draft') NOT NULL DEFAULT 'draft',
    created_by  VARCHAR(20),
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES verifiers(verifier_id)
);

-- ─── SUBSCRIPTIONS ────────────────────────────────────────────────────────────
-- [LATER] Verifier subscriptions to monitor credentials for status changes.

CREATE TABLE IF NOT EXISTS subscriptions (
    subscription_id VARCHAR(20) PRIMARY KEY,                                        -- SUB-001
    verifier_id     VARCHAR(20) NOT NULL,
    holder_id       VARCHAR(10),                                                    -- nullable
    credential_id   VARCHAR(20),                                                    -- nullable: specific credential
    credential_type VARCHAR(100),                                                   -- or by type
    issuer_org_id   VARCHAR(20),
    status          ENUM('active','pending','expired','rejected','unsubscribed') NOT NULL DEFAULT 'pending',
    subscribed_at   TIMESTAMP NULL,
    expiry_date     TIMESTAMP NULL,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (verifier_id)   REFERENCES verifiers(verifier_id),
    FOREIGN KEY (holder_id)     REFERENCES holders(holder_id),
    FOREIGN KEY (credential_id) REFERENCES credentials(credential_id)
);

-- ─── ALERTS ───────────────────────────────────────────────────────────────────
-- [LATER] Status-change alerts (revocation, expiry, suspension, tampering).

CREATE TABLE IF NOT EXISTS alerts (
    alert_id        VARCHAR(20) PRIMARY KEY,                                        -- ALT-001
    holder_id       VARCHAR(10),
    credential_id   VARCHAR(20),
    credential_name VARCHAR(100),                                                   -- denormalised for display
    holder_name     VARCHAR(200),                                                   -- denormalised for display
    description     TEXT NOT NULL,
    severity        ENUM('revoked','expired','suspended','tampered','renewed','reissued') NOT NULL,
    triggered_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (holder_id)     REFERENCES holders(holder_id),
    FOREIGN KEY (credential_id) REFERENCES credentials(credential_id)
);

-- ─── PORTAL AUDIT LOG ─────────────────────────────────────────────────────────
-- [LATER] Append-only record of every portal action (IT Admin section).

CREATE TABLE IF NOT EXISTS portal_audit_log (
    audit_id         VARCHAR(20) PRIMARY KEY,                                       -- AUD-001
    action           ENUM(
                         'issued','revoked','suspended','restored',
                         'verified','verification_failed',
                         'staff_added','staff_removed',
                         'settings_changed',
                         'schema_created','schema_archived',
                         'policy_created','policy_deleted',
                         'batch_issued','exported',
                         'login','logout'
                     ) NOT NULL,
    details          TEXT NOT NULL,
    performed_by_id  VARCHAR(20),
    performed_by_name VARCHAR(100),
    performed_by_role VARCHAR(50),
    ip_address       VARCHAR(45),                                                   -- IPv6 max length
    entity_type      VARCHAR(30),                                                   -- 'credential','schema','policy','staff'
    entity_id        VARCHAR(200),
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ─── BATCH JOBS ───────────────────────────────────────────────────────────────
-- [LATER] Batch issuance tracking.

CREATE TABLE IF NOT EXISTS batch_jobs (
    batch_job_id VARCHAR(20) PRIMARY KEY,                                           -- BATCH-001
    issuer_id    VARCHAR(20) NOT NULL,
    schema_id    VARCHAR(20),
    total_rows   INT UNSIGNED DEFAULT 0,
    valid_rows   INT UNSIGNED DEFAULT 0,
    warning_rows INT UNSIGNED DEFAULT 0,
    error_rows   INT UNSIGNED DEFAULT 0,
    status       ENUM('pending','processing','completed','failed') NOT NULL DEFAULT 'pending',
    started_at   TIMESTAMP NULL,
    completed_at TIMESTAMP NULL,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (issuer_id) REFERENCES issuers(issuer_id),
    FOREIGN KEY (schema_id) REFERENCES `schemas`(schema_id)
);

CREATE TABLE IF NOT EXISTS batch_job_rows (
    row_id        VARCHAR(30) PRIMARY KEY,
    batch_job_id  VARCHAR(20) NOT NULL,
    `row_number`    INT UNSIGNED NOT NULL,
    holder_id     VARCHAR(10),
    holder_name   VARCHAR(200),
    fields        JSON NOT NULL,
    field_errors  JSON,
    state         ENUM('valid','warning','error') NOT NULL DEFAULT 'valid',
    credential_id VARCHAR(20),                                                      -- NULL until issued
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (batch_job_id)  REFERENCES batch_jobs(batch_job_id),
    FOREIGN KEY (holder_id)     REFERENCES holders(holder_id),
    FOREIGN KEY (credential_id) REFERENCES credentials(credential_id)
);

-- ─── SEED DATA (demo environment) ─────────────────────────────────────────────

INSERT IGNORE INTO government_organization (org_id, org_name)
VALUES ('ORG-GOV-001', 'Government of UAE');

-- Update public_key after running keygen: UPDATE uos_organization SET public_key = '<ISSUER_PUBLIC_KEY_HEX>' WHERE org_id = 'ORG-UOS-001';
INSERT IGNORE INTO uos_organization (org_id, org_name)
VALUES ('ORG-UOS-001', 'University of Sharjah');

-- Demo issuer (password_hash: run `htpasswd -bnBC 10 "" password | tr -d ':\n'` or use bcrypt tool)
INSERT IGNORE INTO issuers (issuer_id, org_id, fabric_identity, full_name, email, password_hash, role, status)
VALUES ('ISS-UOS-0001', 'ORG-UOS-001', 'issuer1', 'Mohammed Al Issuer', 'issuer@uos.ac.ae', '$2b$10$PLACEHOLDER_HASH', 'admin', 'active');

-- Demo verifier
INSERT IGNORE INTO verifiers (verifier_id, org_id, full_name, email, password_hash, role, status)
VALUES ('VER-UOS-0001', 'ORG-UOS-001', 'Verifier Portal', 'verifier@uos.ac.ae', '$2b$10$PLACEHOLDER_HASH', 'admin', 'active');

-- Demo holders (pre-registered by "government"; wallet not yet activated)
INSERT IGNORE INTO holders (holder_id, emirates_id, first_name, last_name, fabric_holder_id, is_wallet_activated)
VALUES
    ('H-0001', '784-1990-1234567-1', 'Ahmed', 'Al Mansouri', 'H-0001', FALSE),
    ('H-0002', '784-1995-7654321-2', 'Sara',  'Al Hashimi',  'H-0002', FALSE);
