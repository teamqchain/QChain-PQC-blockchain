'use strict';

// QChaincode v2.0 — the ledger half of QChain's hybrid storage.
//
// The chain holds a small, verifiable record per credential; the credential
// body lives only on IPFS, encrypted to the holder. A credential record carries:
//   • metadata: holder, type, issue time, expiry, status (+ lifecycle times)
//   • the IPFS CID of the encrypted envelope
//   • FieldHashes: { field: SHA3-256(salt + ":" + field + ":" + value) }
//   • the issuer's ML-DSA-44 signature over SHA3-256 of the canonical commitment
//     { v, holderID, credentialType, issuedAt, issuerOrgID, expiryDate, cid,
//       fieldHashes } (built and verified by the Go backend, which has liboqs).
//
// Every write validates its inputs and THROWS on failure, so a rejected write
// fails endorsement instead of committing a "{success:false}" result.
// Methods whose names start with "_" are helpers: fabric-contract-api never
// exposes them as transactions.

const stringify = require('json-stringify-deterministic');
const sortKeysRecursive = require('sort-keys-recursive');
const {
    Contract
} = require('fabric-contract-api');

const COMMITMENT_VERSION = 2;
const MAX_BATCH_IDS = 1000;
const MAX_FIELDS = 64;
const MAX_ID_LENGTH = 256;
const ISSUED_AT_SKEW_SECONDS = 300;
const KEM_PUBLIC_KEY_HEX_LENGTH = 2368; // ML-KEM-768 public key, 1184 bytes
const DSA_PUBLIC_KEY_HEX_LENGTH = 2624; // ML-DSA-44 public key, 1312 bytes

const HEX = /^[0-9a-fA-F]+$/;
const HASH_HEX = /^[0-9a-f]{64}$/;
const DATE = /^\d{4}-\d{2}-\d{2}$/;
const ISSUED_AT = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/;
const CID = /^[A-Za-z0-9]{10,128}$/;

class QChaincode extends Contract {
    async init(ctx) {
        return JSON.stringify('Initialization successful.');
    }

    // ─── Holders ────────────────────────────────────────────────────────────

    // holderID is supplied by the Go server so MySQL and the chain share the
    // same identifier (H-0001, …). Re-registering is refused: it would silently
    // wipe the holder's bound public keys.
    async registerHolder(ctx, holderID, firstName, lastName) {
        this._checkAccess(ctx, 'issuer');
        this._requireID(holderID, 'holderID');
        this._requireText(firstName, 'firstName');
        this._requireText(lastName, 'lastName');
        if (await this._exists(ctx, holderID)) {
            throw new Error(`Holder already registered: ${holderID}`);
        }
        const holder = {
            DocType: 'holder',
            ID: holderID,
            FirstName: firstName,
            LastName: lastName,
        };
        await this._put(ctx, holderID, holder);
        return JSON.stringify(holder);
    }

    // Binds the holder's wallet keys: ML-KEM-768 (credentials are encrypted to
    // it) and ML-DSA-44 (presentations are signed with it).
    async bindHolderKeys(ctx, holderID, kemPublicKey, dsaPublicKey) {
        this._checkAccess(ctx, 'issuer');
        const holder = await this._getHolder(ctx, holderID);
        this._requireHex(kemPublicKey, 'kemPublicKey', KEM_PUBLIC_KEY_HEX_LENGTH);
        this._requireHex(dsaPublicKey, 'dsaPublicKey', DSA_PUBLIC_KEY_HEX_LENGTH);
        holder.KemPublicKey = kemPublicKey;
        holder.DsaPublicKey = dsaPublicKey;
        await this._put(ctx, holderID, holder);
        return JSON.stringify({ success: true, holderID });
    }

    // ─── Credentials: writes ────────────────────────────────────────────────

    async issueCredential(ctx, holderID, credentialType, issuedAt, expiryDate, issuerOrgID,
        ipfsCID, fieldHashesJSON, credentialHash, issuerSignature, issuerPublicKey) {
        this._checkAccess(ctx, 'issuer');

        const holder = await this._getHolder(ctx, holderID);
        if (!holder.KemPublicKey) {
            throw new Error(`Holder ${holderID} has not bound an ML-KEM public key`);
        }
        this._requireText(credentialType, 'credentialType');
        this._requireIssuedAt(ctx, issuedAt);
        this._requireExpiry(expiryDate);
        const mspID = ctx.clientIdentity.getMSPID();
        if (issuerOrgID !== mspID) {
            throw new Error(`issuerOrgID ${issuerOrgID} does not match the submitting organisation ${mspID}`);
        }
        if (typeof ipfsCID !== 'string' || !CID.test(ipfsCID)) {
            throw new Error('ipfsCID must be a non-empty IPFS CID');
        }
        const fieldHashes = this._parseFieldHashes(fieldHashesJSON);
        this._requireSignature(credentialHash, issuerSignature, issuerPublicKey);

        const credID = `CRED-${ctx.stub.getTxID()}`;
        if (await this._exists(ctx, credID)) {
            throw new Error(`Credential already exists: ${credID}`);
        }
        const credential = {
            DocType: 'credential',
            CommitmentVersion: COMMITMENT_VERSION,
            ID: credID,
            Holder: holderID,
            Issuer: ctx.clientIdentity.getID(),
            IssuerOrgID: issuerOrgID,
            Status: 'active',
            CredentialType: credentialType,
            IssuedAt: issuedAt,
            ExpiryDate: expiryDate,
            CID: ipfsCID,
            FieldHashes: fieldHashes,
            CredentialHash: credentialHash,
            Signature: issuerSignature,
            PublicKey: issuerPublicKey,
        };
        await this._put(ctx, credID, credential);
        return JSON.stringify({ success: true, credentialID: credID });
    }

    // Expiry is part of the signed commitment, so changing it requires a new
    // hash and signature from the issuer (computed by the Go backend).
    async updateExpiry(ctx, credID, expiryDate, credentialHash, issuerSignature, issuerPublicKey) {
        this._checkAccess(ctx, 'issuer');
        const credential = await this._getCredential(ctx, credID);
        if (credential.Status === 'revoked') {
            throw new Error('Cannot update a revoked credential');
        }
        this._requireExpiry(expiryDate);
        this._requireSignature(credentialHash, issuerSignature, issuerPublicKey);
        credential.ExpiryDate = expiryDate;
        credential.CredentialHash = credentialHash;
        credential.Signature = issuerSignature;
        credential.PublicKey = issuerPublicKey;
        credential.ExpiryUpdatedAt = this._txISO(ctx);
        await this._put(ctx, credID, credential);
        return JSON.stringify({ success: true, credentialID: credID });
    }

    // Revocation is permanent. PublicKey and Signature are kept for audit.
    async revokeCredential(ctx, credID) {
        this._checkAccess(ctx, 'issuer');
        const credential = await this._getCredential(ctx, credID);
        if (credential.Status === 'revoked') {
            throw new Error(`Credential ${credID} is already revoked`);
        }
        credential.Status = 'revoked';
        credential.RevokedAt = this._txISO(ctx);
        await this._put(ctx, credID, credential);
        return JSON.stringify({ success: true, credentialID: credID });
    }

    // Temporary, reversible. Only an active credential can be suspended (the Go
    // backend additionally refuses credentials whose expiry has passed).
    async suspendCredential(ctx, credID, reason) {
        this._checkAccess(ctx, 'issuer');
        const credential = await this._getCredential(ctx, credID);
        if (credential.Status === 'suspended') {
            throw new Error(`Credential ${credID} is already suspended`);
        }
        if (credential.Status !== 'active') {
            throw new Error(`Cannot suspend a ${credential.Status} credential`);
        }
        credential.Status = 'suspended';
        credential.SuspendedAt = this._txISO(ctx);
        credential.SuspendedReason = reason || '';
        await this._put(ctx, credID, credential);
        return JSON.stringify({ success: true, credentialID: credID });
    }

    // Only a suspended credential can be restored; revocation is permanent.
    async restoreCredential(ctx, credID) {
        this._checkAccess(ctx, 'issuer');
        const credential = await this._getCredential(ctx, credID);
        if (credential.Status === 'active') {
            throw new Error(`Credential ${credID} is already active`);
        }
        if (credential.Status !== 'suspended') {
            throw new Error(`Cannot restore credential with status ${credential.Status}`);
        }
        credential.Status = 'active';
        delete credential.SuspendedAt;
        delete credential.SuspendedReason;
        credential.RestoredAt = this._txISO(ctx);
        await this._put(ctx, credID, credential);
        return JSON.stringify({ success: true, credentialID: credID });
    }

    // ─── Reads ──────────────────────────────────────────────────────────────

    async getCredential(ctx, credID) {
        return JSON.stringify(await this._getCredential(ctx, credID));
    }

    async getHolder(ctx, holderID) {
        return JSON.stringify(await this._getHolder(ctx, holderID));
    }

    // Batch read: idsJSON is a JSON array of credential IDs. Returns
    // { credentials: {id: record}, holders: {holderID: record} } with the
    // holders those credentials reference. Unknown IDs are simply absent.
    // view "summary" omits FieldHashes/CredentialHash/Signature/PublicKey and
    // replaces holder keys with KemBound/DsaBound flags.
    async getCredentials(ctx, idsJSON, view) {
        const ids = this._parseIDs(idsJSON);
        const full = this._parseView(view);
        const credentials = {};
        const holderIDs = new Set();
        for (const id of ids) {
            const credential = await this._getRecord(ctx, id, 'credential');
            if (!credential) {
                continue;
            }
            credentials[id] = full ? credential : this._credentialSummary(credential);
            holderIDs.add(credential.Holder);
        }
        const holders = {};
        for (const holderID of holderIDs) {
            const holder = await this._getRecord(ctx, holderID, 'holder');
            if (holder) {
                holders[holderID] = full ? holder : this._holderSummary(holder);
            }
        }
        return JSON.stringify({ credentials, holders });
    }

    // Batch read of holder records: { holders: {holderID: record} }.
    async getHolders(ctx, idsJSON, view) {
        const ids = this._parseIDs(idsJSON);
        const full = this._parseView(view);
        const holders = {};
        for (const id of ids) {
            const holder = await this._getRecord(ctx, id, 'holder');
            if (holder) {
                holders[id] = full ? holder : this._holderSummary(holder);
            }
        }
        return JSON.stringify({ holders });
    }

    // ─── Helpers (not transactions) ─────────────────────────────────────────

    _checkAccess(ctx, role) {
        if (!ctx.clientIdentity.assertAttributeValue('role', role)) {
            throw new Error(`Access denied. Only a ${role} official may access this function.`);
        }
    }

    // Transaction time (identical on every endorser), second precision, UTC.
    _txISO(ctx) {
        return ctx.stub.getDateTimestamp().toISOString().replace(/\.\d{3}Z$/, 'Z');
    }

    async _put(ctx, key, value) {
        await ctx.stub.putState(key, Buffer.from(stringify(sortKeysRecursive(value))));
    }

    async _exists(ctx, key) {
        const data = await ctx.stub.getState(key);
        return !!data && data.length > 0;
    }

    // Returns the record stored under key if it is of the given DocType, else null.
    async _getRecord(ctx, key, docType) {
        const data = await ctx.stub.getState(key);
        if (!data || data.length === 0) {
            return null;
        }
        const record = JSON.parse(data.toString('utf8'));
        return record.DocType === docType ? record : null;
    }

    async _getHolder(ctx, holderID) {
        const holder = await this._getRecord(ctx, holderID, 'holder');
        if (!holder) {
            throw new Error(`Holder not found: ${holderID}`);
        }
        return holder;
    }

    async _getCredential(ctx, credID) {
        const credential = await this._getRecord(ctx, credID, 'credential');
        if (!credential) {
            throw new Error(`Credential not found: ${credID}`);
        }
        return credential;
    }

    _credentialSummary(credential) {
        const summary = Object.assign({}, credential);
        delete summary.FieldHashes;
        delete summary.CredentialHash;
        delete summary.Signature;
        delete summary.PublicKey;
        return summary;
    }

    _holderSummary(holder) {
        return {
            DocType: holder.DocType,
            ID: holder.ID,
            FirstName: holder.FirstName,
            LastName: holder.LastName,
            KemBound: !!holder.KemPublicKey,
            DsaBound: !!holder.DsaPublicKey,
        };
    }

    _parseIDs(idsJSON) {
        let ids;
        try {
            ids = JSON.parse(idsJSON);
        } catch (e) {
            throw new Error('ids must be a JSON array of strings');
        }
        if (!Array.isArray(ids)) {
            throw new Error('ids must be a JSON array of strings');
        }
        const unique = [...new Set(ids)];
        if (unique.length > MAX_BATCH_IDS) {
            throw new Error(`at most ${MAX_BATCH_IDS} ids per call`);
        }
        for (const id of unique) {
            this._requireID(id, 'id');
        }
        return unique;
    }

    _parseView(view) {
        if (view === 'full') {
            return true;
        }
        if (view === 'summary') {
            return false;
        }
        throw new Error('view must be "full" or "summary"');
    }

    _requireID(value, name) {
        if (typeof value !== 'string' || value.trim() === '' || value.length > MAX_ID_LENGTH) {
            throw new Error(`${name} must be a non-empty string of at most ${MAX_ID_LENGTH} characters`);
        }
    }

    _requireText(value, name) {
        if (typeof value !== 'string' || value.trim() === '') {
            throw new Error(`${name} must not be empty`);
        }
    }

    _requireHex(value, name, exactLength) {
        if (typeof value !== 'string' || !HEX.test(value) || value.length % 2 !== 0) {
            throw new Error(`${name} must be hex`);
        }
        if (exactLength && value.length !== exactLength) {
            throw new Error(`${name} must be ${exactLength} hex characters, got ${value.length}`);
        }
    }

    _requireSignature(credentialHash, issuerSignature, issuerPublicKey) {
        if (typeof credentialHash !== 'string' || !HASH_HEX.test(credentialHash)) {
            throw new Error('credentialHash must be 64 lowercase hex characters');
        }
        this._requireHex(issuerSignature, 'issuerSignature');
        this._requireHex(issuerPublicKey, 'issuerPublicKey', DSA_PUBLIC_KEY_HEX_LENGTH);
    }

    // issuedAt is chosen by the backend (it is signed), so it must be close to
    // the transaction time rather than computed here with new Date(), which
    // would differ between the two endorsing peers.
    _requireIssuedAt(ctx, issuedAt) {
        if (typeof issuedAt !== 'string' || !ISSUED_AT.test(issuedAt)) {
            throw new Error('issuedAt must be RFC3339 UTC with second precision (YYYY-MM-DDTHH:MM:SSZ)');
        }
        const issuedMs = Date.parse(issuedAt);
        if (Number.isNaN(issuedMs)) {
            throw new Error(`issuedAt is not a valid time: ${issuedAt}`);
        }
        const skewSeconds = Math.abs(issuedMs - ctx.stub.getDateTimestamp().getTime()) / 1000;
        if (skewSeconds > ISSUED_AT_SKEW_SECONDS) {
            throw new Error(`issuedAt is ${Math.round(skewSeconds)}s away from the transaction time (max ${ISSUED_AT_SKEW_SECONDS}s)`);
        }
    }

    // "" (no expiry) or a real calendar date YYYY-MM-DD.
    _requireExpiry(expiryDate) {
        if (expiryDate === '') {
            return;
        }
        if (typeof expiryDate !== 'string' || !DATE.test(expiryDate)) {
            throw new Error('expiryDate must be "" or YYYY-MM-DD');
        }
        const parsed = new Date(`${expiryDate}T00:00:00Z`);
        if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== expiryDate) {
            throw new Error(`expiryDate is not a valid date: ${expiryDate}`);
        }
    }

    _parseFieldHashes(fieldHashesJSON) {
        let fieldHashes;
        try {
            fieldHashes = JSON.parse(fieldHashesJSON);
        } catch (e) {
            throw new Error('fieldHashes must be a JSON object');
        }
        if (!fieldHashes || typeof fieldHashes !== 'object' || Array.isArray(fieldHashes)) {
            throw new Error('fieldHashes must be a JSON object');
        }
        const keys = Object.keys(fieldHashes);
        if (keys.length === 0 || keys.length > MAX_FIELDS) {
            throw new Error(`fieldHashes must have between 1 and ${MAX_FIELDS} fields`);
        }
        for (const key of keys) {
            if (key.trim() === '' || key.startsWith('_')) {
                throw new Error(`invalid field name in fieldHashes: "${key}"`);
            }
            if (typeof fieldHashes[key] !== 'string' || !HASH_HEX.test(fieldHashes[key])) {
                throw new Error(`fieldHashes["${key}"] must be 64 lowercase hex characters`);
            }
        }
        return fieldHashes;
    }
}

module.exports = QChaincode;
