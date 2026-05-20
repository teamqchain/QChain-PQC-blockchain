'use strict';

const stringify = require('json-stringify-deterministic');
const sortKeysRecursive = require('sort-keys-recursive');
const {
    Contract
} = require('fabric-contract-api');

class QChaincode extends Contract {
    async init(ctx) {
        return JSON.stringify("Initialization successful.");
    }

    // Fix 9: holderID is now supplied by the Go server so MySQL and the blockchain
    // share the same identifier (H-0001, H-0002 …).
    async registerHolder(ctx, holderID, firstName, lastName) {
        try {
            const Holder = {
                ID: holderID,
                FirstName: firstName,
                LastName: lastName
            };

            await ctx.stub.putState(holderID, Buffer.from(stringify(sortKeysRecursive(Holder))));

            return JSON.stringify(Holder);
        } catch (error) {
            return JSON.stringify({ success: false, error: error.message });
        }
    }

    // Fix 5: accepts the canonical JSON, its SHA3-256 hash, the ML-DSA-44 signature,
    // the org public key, and the IPFS CID — all computed by the Go server before
    // calling this transaction. CID is passed here so issuance is atomic (no
    // separate setCID call needed).
    async issueCredential(ctx, holderID, credentialJSON, credentialHash, issuerSignature, issuerPublicKey, ipfsCID) {
        try {
            await this.checkAccess(ctx, "issuer");

            const Holder = await this.getHolder(ctx, holderID);

            // Use full transaction ID to eliminate the 8-char collision risk.
            const credID = `CRED-${ctx.stub.getTxID()}`;

            const Credential = {
                ID:             credID,
                Holder:         Holder.ID,
                Issuer:         ctx.clientIdentity.getID(),
                Status:         "active",
                Info:           credentialJSON,    // canonical JSON string (signed payload)
                CredentialHash: credentialHash,    // SHA3-256 hex of Info
                Signature:      issuerSignature,   // hex ML-DSA-44 signature over CredentialHash
                PublicKey:      issuerPublicKey,   // hex org public key at issuance time
                CID:            ipfsCID,           // IPFS CID of the JSON (may be "" if upload skipped)
                IssuedAt:       new Date().toLocaleString('sv-SE', { timeZone: 'Asia/Dubai' }).replace(' ', 'T')
            };

            await ctx.stub.putState(credID, Buffer.from(stringify(sortKeysRecursive(Credential))));

            console.log(`Credential ${credID} issued to holder ${holderID}`);
            return JSON.stringify({
                success: true,
                credential: Credential
            });
        } catch (error) {
            console.error(error);
            return JSON.stringify({ success: false, error: error.message });
        }
    }

    // Fix 7: publicKey is no longer accepted from the client — it is read from the
    // stored credential. PQC signature verification happens in the Go server (it has
    // liboqs); this function simply returns the full credential record.
    async verifyCredential(ctx, credID) {
        try {
            await this.checkAccess(ctx, "verifier");

            const Credential = await this.getCredential(ctx, credID);

            console.log(`Credential ${credID} fetched for verification (Status: ${Credential.Status})`);

            return JSON.stringify({
                verified: Credential.Status === "active",
                credential: Credential
            });
        } catch (error) {
            return JSON.stringify({ success: false, error: error.message });
        }
    }

    async revokeCredential(ctx, credID) {
        try {
            await this.checkAccess(ctx, "issuer");

            const Credential = await this.getCredential(ctx, credID);

            Credential.Status = "revoked";
            // Fix 8: PublicKey and Signature are preserved for historical audit.
            // A RevokedAt timestamp is added instead of nulling the key.
            Credential.RevokedAt = new Date().toISOString();

            await ctx.stub.putState(credID, Buffer.from(stringify(sortKeysRecursive(Credential))));

            return JSON.stringify({ message: "Credential revoked successfully" });
        } catch (error) {
            return JSON.stringify({ success: false, error: error.message });
        }
    }

    // suspendCredential — temporary, reversible status change. Use restoreCredential
    // to bring an active suspended credential back. Cannot suspend a revoked or
    // expired credential.
    async suspendCredential(ctx, credID, reason) {
        try {
            await this.checkAccess(ctx, "issuer");

            const Credential = await this.getCredential(ctx, credID);

            if (Credential.Status === "suspended") {
                throw new Error(`Credential ${credID} is already suspended`);
            }
            if (Credential.Status === "revoked") {
                throw new Error(`Cannot suspend a revoked credential`);
            }
            if (Credential.Status === "expired") {
                throw new Error(`Cannot suspend an expired credential`);
            }

            Credential.Status = "suspended";
            Credential.SuspendedAt = new Date().toISOString();
            Credential.SuspendedReason = reason || "";

            await ctx.stub.putState(credID, Buffer.from(stringify(sortKeysRecursive(Credential))));

            return JSON.stringify({ message: "Credential suspended successfully", credentialID: credID });
        } catch (error) {
            return JSON.stringify({ success: false, error: error.message });
        }
    }

    // restoreCredential — only restores from "suspended" back to "active".
    // Revoked credentials cannot be restored (revocation is permanent for audit).
    async restoreCredential(ctx, credID) {
        try {
            await this.checkAccess(ctx, "issuer");

            const Credential = await this.getCredential(ctx, credID);

            if (Credential.Status === "active") {
                throw new Error(`Credential ${credID} is already active`);
            }
            if (Credential.Status !== "suspended") {
                throw new Error(`Cannot restore credential with status ${Credential.Status}`);
            }

            Credential.Status = "active";
            delete Credential.SuspendedAt;
            delete Credential.SuspendedReason;
            Credential.RestoredAt = new Date().toISOString();

            await ctx.stub.putState(credID, Buffer.from(stringify(sortKeysRecursive(Credential))));

            return JSON.stringify({ message: "Credential restored successfully", credentialID: credID });
        } catch (error) {
            return JSON.stringify({ success: false, error: error.message });
        }
    }

    // setCID is retained for administrative use (manual correction if IPFS upload
    // failed after issuance). Normal issuances pass CID directly to issueCredential.
    async setCID(ctx, credID, cid) {
        try {
            await this.checkAccess(ctx, "issuer");

            const Credential = await this.getCredential(ctx, credID);

            Credential.CID = cid;

            await ctx.stub.putState(credID, Buffer.from(stringify(sortKeysRecursive(Credential))));

            return JSON.stringify({ message: "Credential CID set successfully" });
        } catch (error) {
            return JSON.stringify({ success: false, error: error.message });
        }
    }

    async checkAccess(ctx, role) {
        if (!ctx.clientIdentity.assertAttributeValue('role', role)) {
            throw new Error(`Access denied. Only a ${role} official may access this function.`);
        }
        return true;
    }

    async getHolder(ctx, holderID) {
        const holderExists = await ctx.stub.getState(holderID);
        if (!holderExists || holderExists.length === 0) {
            throw new Error(`Holder not found: ${holderID}`);
        }
        return JSON.parse(holderExists.toString('utf8'));
    }

    async getCredential(ctx, credID) {
        const credExists = await ctx.stub.getState(credID);
        if (!credExists || credExists.length === 0) {
            throw new Error(`Credential not found: ${credID}`);
        }
        return JSON.parse(credExists.toString('utf8'));
    }

    async getCredentialsByHolder(ctx, holderID) {
        try {
            const query = {
                selector: { Holder: holderID },
                sort: [{ IssuedAt: 'desc' }]
            };

            const iterator = await ctx.stub.getQueryResult(JSON.stringify(query));
            const credentials = [];

            while (true) {
                const result = await iterator.next();
                if (result.done) {
                    await iterator.close();
                    break;
                }
                const credential = JSON.parse(result.value.value.toString('utf8'));
                credentials.push(credential);
            }

            return JSON.stringify({
                holderID: holderID,
                count: credentials.length,
                credentials: credentials
            });
        } catch (error) {
            return JSON.stringify({ success: false, error: error.message });
        }
    }
}

module.exports = QChaincode;
