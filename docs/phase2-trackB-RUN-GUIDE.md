# QChain — Track B Off-Chain Encryption · Run & Deploy Guide (Ubuntu VM + Docker)

This is the step-by-step guide to deploy the Track B off-chain-encryption changes on the
Ubuntu VM, where the Go backend runs inside the `qchain-api` Docker container.

**Nothing here touches the blockchain.** No chaincode change, no `peer`/`orderer` restart, no
channel redeploy. You only rebuild the backend container, run one additive SQL migration, and
add two lines to `.env`. Fabric, IPFS, and MySQL keep running as-is.

**Time:** ~20–25 min (most of it is the one-time liboqs compile in the Docker build).

---

## 0. Before you start — what you need on the VM

These are already true for a running Phase 1 deployment; this is just a checklist:

- Docker installed and working (`docker ps` runs without error).
- The repo present on the VM, e.g. `~/QChain-PQC-blockchain`, with `offchain/` and `qchain-network/`.
- `offchain/.env` already populated for Phase 1 (issuer ML-DSA keys, `MYSQL_DSN`, `IPFS_HOST`, etc.).
- MySQL reachable on `127.0.0.1:3306` and the IPFS daemon on `127.0.0.1:5001` (the container uses
  `--network host`, so these are localhost from inside the container too).
- Fabric network up and the `qchain-api` container currently running (Phase 1).

Confirm the current backend is healthy before changing anything:

```bash
curl -s http://localhost:3000/health          # → {"status":"ok"}
docker ps --filter name=qchain-api
```

---

## 1. Get the new code onto the VM

The changed/added files (already written into your repo by this session):

```
offchain/kem.go                    (new)   offchain/config.go             (edited)
offchain/envelope.go               (new)   offchain/server.go             (edited)
offchain/backfill.go               (new)   offchain/credentials.go        (edited)
offchain/envelope_test.go          (new)   offchain/db_credentials.go     (edited)
offchain/cmd/kemkeygen/main.go     (new)   offchain/mobile.go             (edited)
qchain-network/scripts/migrations/2026-07_trackB_offchain_encryption.sql   (new)
docs/phase2-trackB-*.md            (new docs)
```

Push these from your machine and pull on the VM (or `scp`/`rsync` them across). Typical git flow:

```bash
# on the VM, in the repo:
cd ~/QChain-PQC-blockchain
git pull            # or however you sync; ensure the files above are present
git status          # sanity check the changed files are there
```

> No `go.mod` / `go.sum` edit is required. The only new third-party import is
> `golang.org/x/crypto/hkdf`, which lives in the `golang.org/x/crypto` module already pinned in
> `go.mod`. The Dockerfile runs `go mod tidy` during the build and will resolve it automatically.

---

## 2. Run the database migration (additive, safe on a live DB)

This adds three nullable/defaulted columns. It does **not** modify or move any existing data, and
it does not require downtime.

```bash
cd ~/QChain-PQC-blockchain
mysql -u root -p qchain_db < qchain-network/scripts/migrations/2026-07_trackB_offchain_encryption.sql
```

Use whatever MySQL user your `MYSQL_DSN` uses if not `root`. Verify:

```bash
mysql -u root -p qchain_db -e "SHOW COLUMNS FROM credentials LIKE 'enc_version';"
mysql -u root -p qchain_db -e "SHOW COLUMNS FROM holders  LIKE 'kem_public_key';"
```

You should see `enc_version` (tinyint, default 0) and `kem_public_key` (text). If a column already
exists (e.g. you re-run the file), MySQL errors on just that line — comment it out and re-run, it's
harmless.

---

## 3. Rebuild the backend Docker image

The new `.go` files are picked up automatically (`COPY *.go ./` in the Dockerfile). liboqs already
provides ML-KEM in this build, so no Dockerfile change is needed.

```bash
bash offchain/docker-build.sh
```

First build recompiles liboqs (~20 min); subsequent builds are cached (~2 min). A successful build
ends with `Image: qchain-api:latest`.

---

## 4. Generate the organisation ML-KEM key (one-shot, from the image)

Because `cmd/` is **not** included in the Docker image, use the built-in one-shot mode instead —
it runs the same image and needs no extra tooling on the host:

```bash
docker run --rm -e GENERATE_ORG_KEM=1 qchain-api:latest
```

Output looks like:

```
# ─── Organisation ML-KEM Key Pair (Track B off-chain encryption) ──────────────
# Append these two lines to offchain/.env. Keep .env in .gitignore; never commit.
# Algorithm: ML-KEM-768
ORG_KEM_PUBLIC_KEY_HEX=....
ORG_KEM_PRIVATE_KEY_HEX=....
```

> Alternative (only if the host has Go + liboqs + pkg-config set up):
> `go run offchain/cmd/kemkeygen/main.go`. On the VM, the `docker run` method above is preferred.

**Append the two `ORG_KEM_*` lines to `offchain/.env`.** Treat the private key like the signing
key — it can decrypt every off-chain credential body. Keep it in `.env` only (already git-ignored),
never commit it, and back it up somewhere safe (if it is lost, existing encrypted rows can't be
read).

Verify they're set (mask the value):

```bash
grep -c ORG_KEM_PUBLIC_KEY_HEX offchain/.env     # → 1
grep -c ORG_KEM_PRIVATE_KEY_HEX offchain/.env    # → 1
```

---

## 5. Restart the backend container

```bash
bash offchain/docker-run.sh
```

Confirm it came up with encryption enabled — the startup log now prints a KEM line:

```bash
docker logs -f qchain-api
```

Look for:

```
PQC algo:      ML-DSA-44
KEM algo:      ML-KEM-768 (off-chain encryption: true)
```

`off-chain encryption: true` is the confirmation. If it says `false`, the `ORG_KEM_PUBLIC_KEY_HEX`
line didn't reach the container — re-check `.env` and that `docker-run.sh` passes `--env-file`.

Health check:

```bash
curl -s http://localhost:3000/health             # → {"status":"ok"}
```

From this point, **every new credential is issued with its off-chain body encrypted** (IPFS blob +
`credential_data`). The on-chain record is unchanged, so verification keeps working exactly as before.

---

## 6. Verify it works end to end

**A. Issue a new credential** (via the QPortal issuer screen, or your existing test call). Then
inspect the DB row:

```bash
mysql -u root -p qchain_db -e \
 "SELECT credential_id, enc_version, LEFT(credential_data,45) AS body \
    FROM credentials ORDER BY issued_at DESC LIMIT 1;"
```

Expected: `enc_version = 1` and `body` starting with `{"_qc_env":"qchain-env"...` (ciphertext, not
readable attributes).

**B. Open that holder's wallet** (QWallet). The attributes must display normally — the server
decrypts on read. If they show, the encrypt→store→read→decrypt path is working.

**C. Verify the credential** in QPortal. All four checks (existsOnChain, notRevoked, signatureValid,
hashMatches) must still pass — verification reads the unchanged on-chain copy.

**D. (Optional) Run the unit tests** inside a build container, if you want the crypto self-test:

```bash
docker run --rm -e CGO_ENABLED=1 -v "$PWD/offchain":/app -w /app golang:1.24-bookworm \
  bash -c "go test -run TestEnvelope -v ."
# (requires liboqs in that image; simplest is to trust the round-trip check in step A/B instead)
```

The reliable functional proof is A + B + C.

---

## 7. (Optional) Encrypt existing credentials

Credentials issued **before** this deploy still have plaintext `credential_data` (`enc_version = 0`)
and keep working via the legacy passthrough. To encrypt them in place, run the one-shot backfill —
it uses the same running image, needs the org key set, and exits when done:

```bash
docker run --rm \
  --network host \
  --env-file offchain/.env \
  -e RUN_BACKFILL_ENCRYPT=1 \
  qchain-api:latest
```

It logs `backfill: N legacy plaintext credential(s) to encrypt` and then `backfill: done`. It is
**idempotent** — safe to re-run; it only touches `enc_version = 0` rows. Confirm:

```bash
mysql -u root -p qchain_db -e "SELECT enc_version, COUNT(*) FROM credentials GROUP BY enc_version;"
```

You want everything on `enc_version = 1`. The main `qchain-api` container keeps serving throughout;
this is a separate short-lived container.

> Note: backfill re-encrypts the **MySQL** copy only. Old IPFS blobs uploaded before the deploy stay
> plaintext and their on-chain CID still points at them. Since nothing reads IPFS today this is
> low-risk; if you want to clean them up, re-upload the encrypted body and update the CID via the
> existing `/setCID` admin endpoint (no chaincode change needed). This is optional.

---

## 8. Rollback (if anything looks wrong)

The change is safe to back out at any time because old and new rows coexist:

- **Fast disable, keep the new image:** remove (or comment out) the two `ORG_KEM_*` lines in
  `offchain/.env` and `bash offchain/docker-run.sh`. New issuances go back to plaintext; already-
  encrypted rows will *fail to decrypt for display* while the key is absent — so prefer the next
  option if you've already issued encrypted credentials.
- **Full rollback:** redeploy the previous image tag and restart. The added DB columns are harmless
  to leave in place. Any rows already encrypted need the org key present to be read, so keep the key
  even after rolling back the code if you ran step 7.

Because of that asymmetry, the safe sequence is: deploy → validate (step 6) → only then run the
optional backfill (step 7). Don't run the backfill until you're confident the deploy is good.

---

## 9. One-page command summary

```bash
# 1. sync code on the VM
cd ~/QChain-PQC-blockchain && git pull

# 2. DB migration (additive)
mysql -u root -p qchain_db < qchain-network/scripts/migrations/2026-07_trackB_offchain_encryption.sql

# 3. build image
bash offchain/docker-build.sh

# 4. generate org KEM key, then paste the ORG_KEM_* lines into offchain/.env
docker run --rm -e GENERATE_ORG_KEM=1 qchain-api:latest
nano offchain/.env

# 5. restart backend; confirm "off-chain encryption: true"
bash offchain/docker-run.sh
docker logs --tail 20 qchain-api

# 6. validate: issue a credential, check DB shows enc_version=1 + {"_qc_env":...},
#    open wallet (decrypts), verify in portal (still passes)

# 7. (optional, only after validating) encrypt existing rows
docker run --rm --network host --env-file offchain/.env -e RUN_BACKFILL_ENCRYPT=1 qchain-api:latest
```

---

## 10. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Startup log shows `off-chain encryption: false` | `ORG_KEM_PUBLIC_KEY_HEX` not reaching the container | Check it's in `offchain/.env`; `docker-run.sh` must pass `--env-file offchain/.env`; restart |
| `GENERATE_ORG_KEM` prints `ERROR ... init ML-KEM` | liboqs build lacks ML-KEM (very old) | Rebuild image (Dockerfile clones liboqs `main`, which has ML-KEM); the code auto-falls back to `Kyber768` if that's what's enabled |
| Wallet shows empty attributes after deploy | `credential_data` encrypted but key missing/wrong at read time | Ensure `ORG_KEM_PRIVATE_KEY_HEX` is set and matches the public key used to issue; check `docker logs` for a decrypt error line |
| `go mod tidy` fails in Docker build | builder can't reach the Go proxy | Ensure the VM allows egress to `proxy.golang.org` during build (same requirement as Phase 1) |
| Migration errors "duplicate column" | migration already applied | Safe to ignore / comment those lines and re-run |
| Verification fails after deploy | should not happen — on-chain path is unchanged | Confirm you didn't modify chaincode; check the credential's `Status` is `active`; inspect `docker logs` |

---

## 11. What this deploy does and does not protect (read once)

- **Protects:** the credential body at rest in the two off-chain stores — the IPFS blob and the
  MySQL `credential_data` column (PII). These now hold ML-KEM-768 + AES-256-GCM ciphertext.
- **Does NOT protect:** the on-chain `Info` field, which still holds the plaintext credential and is
  what verification reads. Removing that requires chaincode work and is **Track A** — out of scope
  here by design (you're not authorised to change on-chain code, and the chain must not be restarted).
- **Trust model:** decryption is server-side using the org key in `.env`. The backend can still read
  every credential (same assumption as today, since it already holds the signing key and does all
  verification). Moving decryption to holders/verifiers (true end-to-end / B2) is the documented next
  phase — see `docs/phase2-trackB-offchain-encryption.md` §8 and the design plan.

For the design rationale and the future roadmap, see `docs/phase2-trackB-offchain-encryption.md`
(handoff) and `docs/phase2-trackB-implementation-plan.md` (full design).
