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

    async registerHolder(ctx, firstName, lastName) {
        try {
            const holderID = `H-${ctx.stub.getTxID().slice(0, 8)}`;

            const Holder = {
                ID: holderID,
                FirstName: firstName,
                LastName: lastName
            }

            await ctx.stub.putState(holderID, Buffer.from(stringify(sortKeysRecursive(Holder))));

            return JSON.stringify(Holder);
        } catch (error) {
            return JSON.stringify(error);
        }
    }

    async issueCredential(ctx, holderID, info, publicKey) {
        try {
            await this.checkAccess(ctx, "issuer");

            const Holder = await this.getHolder(ctx, holderID);

            const credID = `CRED-${ctx.stub.getTxID().slice(0, 8)}`;

            const Credential = {
                ID: credID,
                Holder: Holder.ID,
                Issuer: ctx.clientIdentity.getID(),
                Status: "active",
                Info: info,
                IssuedAt: new Date().toLocaleString('sv-SE', { timeZone: 'Asia/Dubai' }).replace(' ', 'T'),
                PublicKey: publicKey,
                CID: null
            }

            await ctx.stub.putState(credID, Buffer.from(stringify(sortKeysRecursive(Credential))));

            console.log("Credential created successfully");
            return JSON.stringify({
                success: true,
                credential: Credential
            });
        } catch (error) {
            console.error(error);
            return JSON.stringify({
                success: false,
                error: error.message
            });
        }
    }

    async verifyCredential(ctx, credID, publicKey) {
        try {
    
            await this.checkAccess(ctx, "verifier");

            const Credential = await this.getCredential(ctx, credID);
    
            const isValid = Credential.PublicKey === publicKey && Credential.Status === "active";
    
            console.log(`Credential ${isValid ? '' : 'NOT '}verified for ${credID}`);
    
            return JSON.stringify({
                verified: isValid,
                credential: Credential
            });
        } catch (error) {
            return JSON.stringify({
                success: false,
                error: error.message
            });
        }
    }

    async revokeCredential(ctx, credID) {
        try {
            await this.checkAccess(ctx, "issuer");

            const Credential = await this.getCredential(ctx, credID);

            Credential.Status = "revoked";
            Credential.PublicKey = null;

            await ctx.stub.putState(credID, Buffer.from(stringify(sortKeysRecursive(Credential))));

            return JSON.stringify({
                message: "Credential revoked successfully"
            });
        } catch (error) {
            return JSON.stringify({
                success: false,
                error: error.message
            });
        }
    }

    async setCID(ctx, credID, cid) {
        try {
            await this.checkAccess(ctx, "issuer");

            const Credential = await this.getCredential(ctx, credID);

            Credential.CID = cid;

            await ctx.stub.putState(credID, Buffer.from(stringify(sortKeysRecursive(Credential))));

            return JSON.stringify({
                message: "Credential CID set successfully"
            });
        } catch (error) {
            return JSON.stringify({
                success: false,
                error: error.message
            });
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
            throw new Error(`Holder not found: ${holderID}`)
        }

        return JSON.parse(holderExists.toString('utf8'));
    }

    async getCredential(ctx, credID) {
        const credExists = await ctx.stub.getState(credID);
        if (!credExists || credExists.length === 0) {
            throw new Error(`Credential not found: ${credID}`)
        }

        return JSON.parse(credExists.toString('utf8'));
    }

    async getCredentialsByHolder(ctx, holderID) {
        try {
            const query = {
                selector: {
                    Holder: holderID
                },
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
            return JSON.stringify({
                success: false,
                error: error.message
            });
        }
    }
}

module.exports = QChaincode;