'use strict';

const stringify = require('json-stringify-deterministic');
const sortKeysRecursive = require('sort-keys-recursive');
const {
    Contract
} = require('fabric-contract-api');

class PQCreddy extends Contract {
    async init(ctx) {
        return JSON.stringify("Initialization successful.");
    }

    async registerHolder(ctx, name, department, major) {
        try {
            await this.checkAccess(ctx, "Org1MSP", "issuer");

            const studentID = `S-${ctx.stub.getTxID().slice(0, 8)}`;

            const Student = {
                ID: studentID,
                Name: name,
                Department: department,
                Major: major,
            }

            await ctx.stub.putState(studentID, Buffer.from(stringify(sortKeysRecursive(Student))));

            return JSON.stringify(Student);
        } catch (error) {
            return JSON.stringify(error);
        }
    }

    async issueCredential(ctx, studentID, info, publicKey) {
        try {
            await this.checkAccess(ctx, "Org2MSP", "issuer");

            const Student = await this.getStudent(ctx, studentID);

            const credID = `CRED-${ctx.stub.getTxID().slice(0, 8)}`;

            const Credential = {
                ID: credID,
                Holder: Student.ID,
                Issuer: ctx.clientIdentity.getID(),
                Status: "active",
                Info: info,
                IssuedAt: new Date().toLocaleString('sv-SE', { timeZone: 'Asia/Dubai' }).replace(' ', 'T'),
                PublicKey: publicKey
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

    async verifyCredential(ctx, studentID, credID, publicKey) {
        try {
    
            await this.checkAccess(ctx, "Org1MSP");

            const Credential = await this.getCredential(ctx, studentID, credID);
    
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

    async revokeCredential(ctx, studentID, credID) {
        try {
            await this.checkAccess(ctx, "Org2MSP", "issuer");

            const Student = await this.getStudent(ctx, studentID);

            const Credential = await this.getCredential(ctx, studentID, credID);

            Credential.Status = "revoked";

            await ctx.stub.putState(Student.ID, Buffer.from(stringify(sortKeysRecursive(Student))));

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

    async checkAccess(ctx, org, role = null) {
        const body = org === "Org1MSP" ? "government" : "university";

        const orgID = ctx.clientIdentity.getMSPID();
        if (orgID != org) {
            throw new Error(`Access denied. Only a ${body} body may access this function.`);
        }

        if (role) {
            if (!ctx.clientIdentity.assertAttributeValue(`${body}.role`, role)) {
                throw new Error(`Access denied. Only a ${role} official may access this function.`);
            }
        }

        return true;
    }

    async getStudent(ctx, studentID) {
        const studentExists = await ctx.stub.getState(studentID);
        if (!studentExists || studentExists.length === 0) {
            throw new Error(`Student not found: ${studentID}`)
        }

        return JSON.parse(studentExists.toString('utf8'));
    }

    async getCredential(ctx, credID) {
        const credExists = await ctx.stub.getState(credID);
        if (!credExists || credExists.length === 0) {
            throw new Error(`Student not found: ${credID}`)
        }

        return JSON.parse(credExists.toString('utf8'));
    }

    async getCredentials(ctx, studentID, credID) {
        const credExists = await ctx.stub.getState(credID);
        if (!credExists || credExists.length === 0) {
            throw new Error(`Student not found: ${credID}`)
        }

        return JSON.parse(credExists.toString('utf8'));
    }

    /* async registerUniOfficial(ctx, id, name, department, position) { // Do we need to register Uni identities?
        const orgID = ctx.clientIdentity.getMSPID();
        if (orgID != "Org1MSP") {
            throw new Error("Access denied.\nOnly a University body may access this function.");
        }

        try {
            const UniOfficial = {
                ID: id,
                Name: name,
                Department: department,
                Position: position
            }

            await ctx.stub.putState(UniOfficial.ID, Buffer.from(stringify(sortKeysRecursive(UniOfficial))));

            return JSON.stringify(UniOfficial);
        } catch (error) {
            return JSON.stringify(error);
        }
    }

    async registerGovOfficial(ctx, id, name, department, position) { // Do we need to register Gov identities?
        const orgID = ctx.clientIdentity.getMSPID();
        if (orgID != "Org2MSP") {
            throw new Error("Access denied.\nOnly a Government body may access this function.");
        }

        try {
            const GovOfficial = {
                ID: id,
                Name: name,
                Position: position
            }

            await ctx.stub.putState(GovOfficial.ID, Buffer.from(stringify(sortKeysRecursive(GovOfficial))));

            return JSON.stringify(GovOfficial);
        } catch (error) {
            return JSON.stringify(error);
        }
    } */
}

module.exports = PQCreddy;