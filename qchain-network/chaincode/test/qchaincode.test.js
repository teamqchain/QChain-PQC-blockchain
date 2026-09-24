'use strict';

// Unit tests for QChaincode v2 against an in-memory ledger. Uses only Node's
// built-in test runner, so no extra dependencies are needed:
//
//   cd qchain-network/chaincode && npm install && npm test

const test = require('node:test');
const assert = require('node:assert/strict');
const QChaincode = require('../QChaincode');

const KEM = 'ab'.repeat(1184);
const DSA = 'cd'.repeat(1312);
const HASH = 'e'.repeat(64);
const SIG = 'f0'.repeat(1210);
const CID = 'QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG';
const NOW = new Date('2026-09-24T06:00:00.456Z');
const ISSUED_AT = '2026-09-24T06:00:00Z';

class MockStub {
    constructor() {
        this.state = new Map();
        this.txID = 'tx0001';
        this.now = NOW;
    }
    async getState(key) {
        return this.state.has(key) ? Buffer.from(this.state.get(key)) : Buffer.alloc(0);
    }
    async putState(key, value) {
        this.state.set(key, value.toString());
    }
    getTxID() {
        return this.txID;
    }
    getDateTimestamp() {
        return new Date(this.now.getTime());
    }
}

function makeCtx(stub, { role = 'issuer', msp = 'GeneralMSP' } = {}) {
    return {
        stub,
        clientIdentity: {
            assertAttributeValue: (name, value) => name === 'role' && value === role,
            getMSPID: () => msp,
            getID: () => 'x509::/OU=client/CN=issuer1::/CN=ca',
        },
    };
}

async function setup() {
    const cc = new QChaincode();
    const stub = new MockStub();
    const ctx = makeCtx(stub);
    await cc.registerHolder(ctx, 'H-0001', 'Fatima', 'Al Mansoori');
    await cc.bindHolderKeys(ctx, 'H-0001', KEM, DSA);
    return { cc, stub, ctx };
}

function issueArgs(overrides = {}) {
    const a = Object.assign({
        holderID: 'H-0001',
        credentialType: 'BSc Computer Science',
        issuedAt: ISSUED_AT,
        expiryDate: '2030-06-30',
        issuerOrgID: 'GeneralMSP',
        cid: CID,
        fieldHashes: JSON.stringify({ College: HASH }),
        hash: HASH,
        sig: SIG,
        pub: DSA,
    }, overrides);
    return [a.holderID, a.credentialType, a.issuedAt, a.expiryDate, a.issuerOrgID, a.cid,
        a.fieldHashes, a.hash, a.sig, a.pub];
}

async function issue(cc, ctx, overrides) {
    return JSON.parse(await cc.issueCredential(ctx, ...issueArgs(overrides)));
}

test('only the intended transactions are exposed', () => {
    const exposed = Object.getOwnPropertyNames(QChaincode.prototype)
        .filter((n) => n !== 'constructor' && !n.startsWith('_'))
        .sort();
    assert.deepEqual(exposed, [
        'bindHolderKeys', 'getCredential', 'getCredentials', 'getHolder', 'getHolders',
        'init', 'issueCredential', 'registerHolder', 'restoreCredential', 'revokeCredential',
        'suspendCredential', 'updateExpiry',
    ]);
});

test('registerHolder is issuer-only and refuses re-registration', async () => {
    const { cc, stub, ctx } = await setup();
    await assert.rejects(cc.registerHolder(makeCtx(stub, { role: 'verifier' }), 'H-0002', 'A', 'B'), /Access denied/);
    await assert.rejects(cc.registerHolder(ctx, 'H-0001', 'Other', 'Name'), /already registered/);
    const holder = JSON.parse(await cc.getHolder(ctx, 'H-0001'));
    assert.equal(holder.KemPublicKey, KEM, 're-registration must not wipe bound keys');
});

test('bindHolderKeys validates key lengths', async () => {
    const { cc, ctx } = await setup();
    await assert.rejects(cc.bindHolderKeys(ctx, 'H-0001', 'abcd', DSA), /kemPublicKey must be 2368/);
    await assert.rejects(cc.bindHolderKeys(ctx, 'H-0001', KEM, 'zz'), /dsaPublicKey must be hex/);
    await assert.rejects(cc.bindHolderKeys(ctx, 'H-0404', KEM, DSA), /Holder not found/);
});

test('issueCredential accepts a local-offset issuedAt (not just Z)', async () => {
    const { cc, ctx } = await setup();
    // 10:00:00+04:00 is the same instant as NOW (2026-09-24T06:00:00.456Z),
    // well inside the 300s skew window — Dubai local time must be accepted.
    const res = await issue(cc, ctx, { issuedAt: '2026-09-24T10:00:00+04:00' });
    assert.equal(res.success, true);
    const rec = JSON.parse(await cc.getCredential(ctx, res.credentialID));
    assert.equal(rec.IssuedAt, '2026-09-24T10:00:00+04:00');
});

test('issueCredential stores a v2 record with no credential body', async () => {
    const { cc, ctx } = await setup();
    const res = await issue(cc, ctx);
    assert.equal(res.success, true);
    assert.equal(res.credentialID, 'CRED-tx0001');
    const rec = JSON.parse(await cc.getCredential(ctx, 'CRED-tx0001'));
    assert.equal(rec.DocType, 'credential');
    assert.equal(rec.CommitmentVersion, 2);
    assert.equal(rec.Info, undefined);
    assert.equal(rec.Status, 'active');
    assert.equal(rec.IssuedAt, ISSUED_AT);
    assert.equal(rec.ExpiryDate, '2030-06-30');
    assert.equal(rec.IssuerOrgID, 'GeneralMSP');
    assert.equal(rec.CID, CID);
    assert.deepEqual(rec.FieldHashes, { College: HASH });
});

test('issueCredential rejects bad input', async () => {
    const { cc, stub, ctx } = await setup();
    const cases = [
        [{ holderID: 'H-0404' }, /Holder not found/],
        [{ credentialType: ' ' }, /credentialType/],
        [{ issuedAt: '2026-09-24 06:00:00Z' }, /issuedAt must be RFC3339/],
        [{ issuedAt: '2026-09-24T05:50:00Z' }, /away from the transaction time/],
        [{ issuedAt: '2026-09-24T09:50:00+04:00' }, /away from the transaction time/], // same instant as 05:50Z, still >300s away
        [{ expiryDate: '30 Jun 2030' }, /expiryDate must be/],
        [{ expiryDate: '2030-02-30' }, /not a valid date/],
        [{ issuerOrgID: 'GovernmentMSP' }, /does not match/],
        [{ cid: '' }, /ipfsCID/],
        [{ fieldHashes: '{}' }, /between 1 and 64/],
        [{ fieldHashes: JSON.stringify({ _salts: HASH }) }, /invalid field name/],
        [{ fieldHashes: JSON.stringify({ College: 'abc' }) }, /64 lowercase hex/],
        [{ hash: HASH.toUpperCase() }, /credentialHash/],
        [{ pub: 'ab' }, /issuerPublicKey must be 2624/],
    ];
    for (const [overrides, pattern] of cases) {
        await assert.rejects(issue(cc, ctx, overrides), pattern, JSON.stringify(overrides));
    }
    await assert.rejects(issue(cc, makeCtx(stub, { role: 'verifier' })), /Access denied/);
    assert.equal(stub.state.has('CRED-tx0001'), false, 'nothing may be written by a rejected issue');
});

test('issueCredential requires a bound KEM key and accepts an empty expiry', async () => {
    const cc = new QChaincode();
    const stub = new MockStub();
    const ctx = makeCtx(stub);
    await cc.registerHolder(ctx, 'H-0002', 'No', 'Keys');
    await assert.rejects(issue(cc, ctx, { holderID: 'H-0002' }), /ML-KEM/);
    await cc.bindHolderKeys(ctx, 'H-0002', KEM, DSA);
    const res = await issue(cc, ctx, { holderID: 'H-0002', expiryDate: '' });
    assert.equal(JSON.parse(await cc.getCredential(ctx, res.credentialID)).ExpiryDate, '');
});

test('lifecycle: suspend, restore, updateExpiry, revoke', async () => {
    const { cc, stub, ctx } = await setup();
    const { credentialID: id } = await issue(cc, ctx);

    await assert.rejects(cc.restoreCredential(ctx, id), /already active/);
    await cc.suspendCredential(ctx, id, 'investigation');
    let rec = JSON.parse(await cc.getCredential(ctx, id));
    assert.equal(rec.Status, 'suspended');
    assert.equal(rec.SuspendedReason, 'investigation');
    assert.equal(rec.SuspendedAt, '2026-09-24T06:00:00Z');
    await assert.rejects(cc.suspendCredential(ctx, id, 'again'), /already suspended/);

    stub.now = new Date('2026-09-25T08:30:00Z');
    await cc.restoreCredential(ctx, id);
    rec = JSON.parse(await cc.getCredential(ctx, id));
    assert.equal(rec.Status, 'active');
    assert.equal(rec.SuspendedAt, undefined);
    assert.equal(rec.RestoredAt, '2026-09-25T08:30:00Z');

    const newHash = '1'.repeat(64);
    await cc.updateExpiry(ctx, id, '2020-01-01', newHash, SIG, DSA);
    rec = JSON.parse(await cc.getCredential(ctx, id));
    assert.equal(rec.ExpiryDate, '2020-01-01');
    assert.equal(rec.CredentialHash, newHash);
    assert.equal(rec.ExpiryUpdatedAt, '2026-09-25T08:30:00Z');
    await assert.rejects(cc.updateExpiry(ctx, id, 'soon', newHash, SIG, DSA), /expiryDate/);

    await cc.revokeCredential(ctx, id);
    rec = JSON.parse(await cc.getCredential(ctx, id));
    assert.equal(rec.Status, 'revoked');
    assert.equal(rec.PublicKey, DSA, 'revocation keeps the key for audit');
    await assert.rejects(cc.revokeCredential(ctx, id), /already revoked/);
    await assert.rejects(cc.suspendCredential(ctx, id, 'x'), /Cannot suspend a revoked/);
    await assert.rejects(cc.restoreCredential(ctx, id), /Cannot restore/);
    await assert.rejects(cc.updateExpiry(ctx, id, '', newHash, SIG, DSA), /revoked/);
});

test('writes are issuer-only', async () => {
    const { cc, stub, ctx } = await setup();
    const { credentialID: id } = await issue(cc, ctx);
    const verifier = makeCtx(stub, { role: 'verifier' });
    await assert.rejects(cc.revokeCredential(verifier, id), /Access denied/);
    await assert.rejects(cc.suspendCredential(verifier, id, 'x'), /Access denied/);
    await assert.rejects(cc.restoreCredential(verifier, id), /Access denied/);
    await assert.rejects(cc.updateExpiry(verifier, id, '', HASH, SIG, DSA), /Access denied/);
    await assert.rejects(cc.bindHolderKeys(verifier, 'H-0001', KEM, DSA), /Access denied/);
});

test('holder and credential keys are not interchangeable', async () => {
    const { cc, ctx } = await setup();
    const { credentialID: id } = await issue(cc, ctx);
    await assert.rejects(cc.getHolder(ctx, id), /Holder not found/);
    await assert.rejects(cc.getCredential(ctx, 'H-0001'), /Credential not found/);
    await assert.rejects(cc.revokeCredential(ctx, 'H-0001'), /Credential not found/);
});

test('getCredentials batch read: views, holders, unknown ids', async () => {
    const { cc, stub, ctx } = await setup();
    const { credentialID: a } = await issue(cc, ctx);
    stub.txID = 'tx0002';
    const { credentialID: b } = await issue(cc, ctx, { expiryDate: '' });

    const full = JSON.parse(await cc.getCredentials(ctx, JSON.stringify([a, b, 'CRED-missing', a]), 'full'));
    assert.deepEqual(Object.keys(full.credentials).sort(), [a, b]);
    assert.equal(full.credentials[a].Signature, SIG);
    assert.equal(full.holders['H-0001'].DsaPublicKey, DSA);

    const summary = JSON.parse(await cc.getCredentials(ctx, JSON.stringify([a]), 'summary'));
    const rec = summary.credentials[a];
    for (const heavy of ['FieldHashes', 'CredentialHash', 'Signature', 'PublicKey']) {
        assert.equal(rec[heavy], undefined, heavy);
    }
    assert.equal(rec.CredentialType, 'BSc Computer Science');
    assert.deepEqual(summary.holders['H-0001'], {
        DocType: 'holder', ID: 'H-0001', FirstName: 'Fatima', LastName: 'Al Mansoori',
        KemBound: true, DsaBound: true,
    });

    const empty = JSON.parse(await cc.getCredentials(ctx, '[]', 'summary'));
    assert.deepEqual(empty, { credentials: {}, holders: {} });
    await assert.rejects(cc.getCredentials(ctx, '{"a":1}', 'full'), /JSON array/);
    await assert.rejects(cc.getCredentials(ctx, '[1]', 'full'), /non-empty string/);
    await assert.rejects(cc.getCredentials(ctx, '[]', 'everything'), /view must be/);
    const tooMany = JSON.stringify(Array.from({ length: 1001 }, (_, i) => `CRED-${i}`));
    await assert.rejects(cc.getCredentials(ctx, tooMany, 'summary'), /at most 1000/);
});

test('getHolders batch read', async () => {
    const { cc, ctx } = await setup();
    await cc.registerHolder(ctx, 'H-0002', 'Rashid', 'Khan');
    const res = JSON.parse(await cc.getHolders(ctx, JSON.stringify(['H-0001', 'H-0002', 'H-0404']), 'summary'));
    assert.deepEqual(Object.keys(res.holders).sort(), ['H-0001', 'H-0002']);
    assert.equal(res.holders['H-0002'].KemBound, false);
    const full = JSON.parse(await cc.getHolders(ctx, JSON.stringify(['H-0001']), 'full'));
    assert.equal(full.holders['H-0001'].KemPublicKey, KEM);
});
