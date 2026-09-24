# Chaincode v2.0 — Full Ledger Reset Runbook

Chaincode v2.0 changes the on-chain credential record (the plaintext `Info` is gone; each record is a
signed commitment: metadata, IPFS CID and salted field hashes) and the `issueCredential` arguments. Old
records cannot be verified by the new backend, so an existing v1.x network is **reset**: the ledger and
all credentials are deleted, while identities, keys, holders, staff and IPFS are kept.

Run this on the VM, from the repository root, **one step at a time**, checking each step's output before
moving on. It assumes the backend branch `feature/source-of-truth` and the QWallet branch
`feature/wallet-field-salts` have both been merged to `main`.

**What is kept:** `qchain-network/crypto-material/`, `wallet/`, `fabric-ca/` (identities and CA state),
`offchain/.env` (the issuer ML-DSA key does not change), the IPFS daemon and its data, MySQL holders
(with their cached names and wallet public keys), staff, catalog and the audit log.

**What is deleted:** the orderer and peer ledgers, CouchDB state, old chaincode containers/images, and
every MySQL row that refers to a credential (credentials, events, verification logs, subscriptions,
alerts, sessions, batch rows).

> **Never** run `docker compose down -v` (it would also delete the `ipfs_data` volume), never use
> `--remove-orphans` on these compose files (the CA and network files share one compose project), never
> start the `qchain-server` or `ipfs` services from `docker-compose.yaml`, and do not re-run
> `registerEnroll.sh`.

---

## 0. Update the code

```bash
git checkout main && git pull origin main
git log --oneline -3
export REPO_ROOT=$(pwd)
```

## 1. Pre-flight checks (read-only)

```bash
# 1a. Database server — MariaDB stores JSON columns verbatim; MySQL 8 does not (see step 3b)
mysql --version

# 1b. Running containers and the exact ledger volume names (expected: docker_orderer0.orderer.example.com,
#     docker_peer0.government.uae.com, docker_peer0.general.uae.com)
docker ps --format '{{.Names}}\t{{.Status}}'
docker volume ls --format '{{.Name}}' | grep -E 'orderer0|peer0'

# 1c. Backend identity settings (prints no keys). ISSUER_ORG_ID must be GeneralMSP.
grep -E '^(ISSUER_ORG_ID|ISSUER_ORG|ISSUER_IDENTITY|VERIFIER_ORG|VERIFIER_IDENTITY|IPFS_HOST)=' offchain/.env

# 1d. The issuer and verifier certificates must carry the Fabric CA "role" attribute
#     (the v2 chaincode checks role=issuer on every write).
for id in issuer1 verifier1; do
  echo "== $id"
  python3 -c "import json;print(json.load(open('qchain-network/wallet/general/$id.id'))['credentials']['certificate'])" \
    | openssl x509 -noout -text | grep -A1 '1.2.3.4.5.6.7.8.1'
done
#     Expected: a line containing "role":"issuer" for issuer1 and "role":"verifier" for verifier1.
#     If it is missing, STOP: the identity needs a targeted re-enrolment with --enrollment.attrs "role"
#     (do not re-run registerEnroll.sh).

# 1e. Migrations applied? Each query must return one row.
mysql -u root qchain_db -e "
  SHOW COLUMNS FROM credentials LIKE 'enc_version';
  SHOW COLUMNS FROM holders LIKE 'kem_public_key';
  SHOW COLUMNS FROM holders LIKE 'dsa_public_key';
  SHOW COLUMNS FROM mobile_sessions LIKE 'disclosed_payload';
  SHOW COLUMNS FROM mobile_sessions LIKE 'holder_signature';"

# 1f. Holders the bootstrap (step 11) will re-create on-chain
mysql -u root qchain_db -e "
  SELECT holder_id, fabric_holder_id, first_name, last_name,
         kem_public_key IS NOT NULL AS has_kem, dsa_public_key IS NOT NULL AS has_dsa
    FROM holders ORDER BY holder_id;"
```

## 2. Back up

```bash
BK=~/qchain-backup-$(date +%F-%H%M) && mkdir -p "$BK"
mysqldump -u root qchain_db > "$BK/qchain_db.sql"
cp offchain/.env "$BK/offchain.env"
( cd qchain-network && tar czf "$BK/runtime.tgz" $(ls -d crypto-material wallet fabric-ca channel-artifacts connection 2>/dev/null) )
ls -la "$BK"
```

## 3. MySQL schema

**3a.** Apply whichever migration statements step 1e showed as missing (only those):

```bash
mysql -u root qchain_db -e "ALTER TABLE credentials ADD COLUMN enc_version TINYINT NOT NULL DEFAULT 0 AFTER credential_data;"
mysql -u root qchain_db -e "ALTER TABLE holders ADD COLUMN kem_public_key TEXT NULL;"
mysql -u root qchain_db -e "ALTER TABLE holders ADD COLUMN dsa_public_key TEXT NULL;"
mysql -u root qchain_db -e "ALTER TABLE mobile_sessions ADD COLUMN disclosed_payload JSON NULL;"
mysql -u root qchain_db -e "ALTER TABLE mobile_sessions ADD COLUMN holder_signature TEXT NULL;"
```

**3b.** Only if step 1a printed **MySQL** (not MariaDB): MySQL 8 re-serialises JSON columns, which would
change the signed presentation text and break the holder-signature check.

```bash
mysql -u root qchain_db -e "ALTER TABLE mobile_sessions MODIFY disclosed_payload LONGTEXT NULL;"
```

## 4. Stop the backend

```bash
docker stop qchain-api
```

## 5. Remove the ledger containers (CAs keep running)

```bash
cd "$REPO_ROOT/qchain-network/docker"
docker compose -f docker-compose.yaml stop orderer0.orderer.example.com peer0.government.uae.com peer0.general.uae.com couchdb0
docker compose -f docker-compose.yaml rm -f orderer0.orderer.example.com peer0.government.uae.com peer0.general.uae.com couchdb0
cd "$REPO_ROOT"
```

`couchdb0` has no volume, so removing its container deletes the world state.

## 6. Delete the ledger volumes and old chaincode containers/images

Use the exact volume names printed in step 1b:

```bash
docker volume rm docker_orderer0.orderer.example.com docker_peer0.government.uae.com docker_peer0.general.uae.com

docker ps -a --format '{{.Names}}' | grep '^dev-peer0' | xargs -r docker rm -f
docker images --format '{{.Repository}}:{{.Tag}}' | grep '^dev-peer0' | xargs -r docker rmi
```

## 7. Start a fresh ledger

```bash
bash qchain-network/scripts/start-fabric-network.sh
docker ps --format '{{.Names}}\t{{.Status}}'
```

## 8. Re-create the channel

Run **"Create and Join Channel"** from [`docs/setup.md`](setup.md) §6 exactly as written (configtxgen,
`osnadmin channel join`, then `peer channel join` on both peers).

## 9. Deploy chaincode v2.0

Run **"Deploy Chaincode"** from [`docs/setup.md`](setup.md) §6 (label `qchaincode_2.0`, version 2.0,
sequence 1, both orgs approve, commit, then the `getHolders` smoke test).

## 10. Clear credential data from MySQL (holders, staff, catalog and audit log are kept)

```bash
mysql -u root qchain_db <<'SQL'
START TRANSACTION;
DELETE FROM mobile_sessions;
DELETE FROM alerts;
DELETE FROM subscriptions;
DELETE FROM batch_job_rows;
DELETE FROM batch_jobs;
DELETE FROM credential_events;
DELETE FROM verification_logs;
DELETE FROM credentials;
COMMIT;
SQL
mysql -u root qchain_db -e "SELECT COUNT(*) AS credentials FROM credentials; SELECT COUNT(*) AS holders FROM holders;"
```

## 11. Build the backend and bootstrap the holders

```bash
# Unit tests (builder stage), then the runtime image (go vet also runs during the build)
docker build --target builder -t qchain-api:test offchain
docker run --rm qchain-api:test go test -count=1 ./...
bash offchain/docker-build.sh

# One-shot: register every MySQL holder on the new ledger and bind their cached wallet keys.
# Idempotent — safe to re-run. It must end with "failed=0".
docker run --rm --network host \
  -v "$REPO_ROOT/qchain-network:/qchain-network:ro" \
  --env-file offchain/.env -e NETWORK_ROOT=/qchain-network -e RUN_CHAIN_BOOTSTRAP=1 \
  qchain-api:latest
```

## 12. Start the backend and check it

```bash
bash offchain/docker-run.sh
curl -s http://localhost:3000/health
curl -s "http://localhost:3000/getHolders" | python3 -m json.tool | head -40
curl -s "http://localhost:3000/mobile/checkKeys?emiratesID=784-1990-1234567-1"
```

Holders whose wallets were activated must show `isWalletActivated: true` and their keys.

## 13. End-to-end test

```bash
bash tests/e2e_api_test.sh http://localhost:3000
```

All tests must pass. (It creates one throwaway test holder and credential.)

## 14. Chain shape check

```bash
source qchain-network/scripts/env-gen.sh
FABRIC_ID=$(mysql -u root qchain_db -N -e "SELECT fabric_cred_id FROM credentials ORDER BY created_at DESC LIMIT 1")
peer chaincode query -C mychannel -n qchaincode -c "{\"Args\":[\"getCredential\",\"$FABRIC_ID\"]}"
```

The record must have `CommitmentVersion: 2`, `CID`, `FieldHashes` and `ExpiryDate`, and **no `Info`**.

## 15. Frontend

Rebuild the web-gateway so both web apps include the merged QWallet change:

```bash
export API_BASE_URL="https://qchain.tail4fff4b.ts.net/api"
bash web-gateway/docker-build.sh && bash web-gateway/docker-run.sh
```

Holders must restart QWallet (credential IDs restart at `CRED-0001`, and a restart clears the in-memory
salt cache). Natively installed wallet builds must be rebuilt and reinstalled.

## 16. Demo data and manual check

Re-issue the demo credentials from QPortal (e.g. with expiry "30 Jun 2030"), then:
QWallet fetch → open → QR and OTP presentations verify with all 5 checks → hide a field and present
again (still valid) → edit the expiry to a past date in QPortal → the next presentation shows EXPIRED.

---

**Rollback** (before step 5 nothing has been deleted): restore MySQL with
`mysql -u root qchain_db < "$BK/qchain_db.sql"` and check out the previous `main` commit. After step 6
the old ledger is gone by design; the backup keeps the MySQL copy for reference.

**Optional later clean-up:** `offchain/.env` may still contain `ORG_KEM_PUBLIC_KEY_HEX` /
`ORG_KEM_PRIVATE_KEY_HEX`, which nothing reads any more. Old credential blobs remain pinned in IPFS;
they are unreferenced after the reset.
