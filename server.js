const express = require("express");
const app = express();
app.use(express.json());

const { Gateway, Wallets } = require('fabric-network');
const path = require('path');
const fs = require('fs');

const PQCClient = require("./pqcClient");
const pqc = new PQCClient();

async function getContract() {
    const ccpPath = path.resolve(__dirname, 'connection-profile.json');
    const ccp = JSON.parse(fs.readFileSync(ccpPath, 'utf8'));

    const walletPath = path.join(__dirname, 'wallet');
    const wallet = await Wallets.newFileSystemWallet(walletPath);

    const gateway = new Gateway();
    await gateway.connect(ccp, {
        wallet,
        identity: 'appUser',
        discovery: { enabled: true, asLocalhost: true }
    });

    const network = await gateway.getNetwork('mychannel');
    return { contract: network.getContract('pqcreddy'), gateway };
}

app.post("/registerStudent", (req, res) => {
    const { name, department, major } = req.body;
    if (!name || !department || !major) {
        return res.status(400).json({ error: "Missing parameters" });
    }

    const { contract, gateway } = await getContract();

    try {
        const result = await contract.submitTransaction(
            'registerStudent',
            name,
            department,
            major
        );

        const parsed = JSON.parse(result.toString());

        // Return secretKey to the credential holder — they must store it
        // Your system should decide whether to persist this server-side or hand it off
        return res.json({
            ...parsed,
        });
    } finally {
        gateway.disconnect();
    }
})

// -------------------------------------------------------
// POST /issueCredential
// 1. Generate PQC key pair in middleware
// 2. Sign the credential info with the private key
// 3. Send info + public key + signature to the chain
// 4. Return the private key to the caller (store it safely)
// -------------------------------------------------------
app.post("/issueCredential", (req, res) => {
    const { studentID, info } = req.body;
    if (!studentID || !info) {
        return res.status(400).json({ error: "Missing parameters" });
    }

    // Key pair never touches the ledger — only publicKey goes on-chain
    const { publicKey, privateKey } = pqc.genKeyPair();
    
    // Sign the credential content so it can be verified later
    const signature = pqc.sign(info, privateKey);

    const { contract, gateway } = await getContract();

    try {
        const result = await contract.submitTransaction(
            'issueCredential',
            studentID,
            info,
            publicKey
        );

        const parsed = JSON.parse(result.toString());

        // Return secretKey to the credential holder — they must store it
        // Your system should decide whether to persist this server-side or hand it off
        return res.json({
            ...parsed,
            publicKey,
            secretKey,   // ⚠️ transmit over TLS only, store securely
            signature
        });
    } finally {
        gateway.disconnect();
    }
})

// -------------------------------------------------------
// POST /verifyCredential
// 1. Fetch the public key from the chain for this ID
// 2. Verify the PQC signature locally in middleware
// -------------------------------------------------------
app.post("/verifyCredential", async (req, res) => {
    const { credID, message, signature, publicKey } = req.body;

    if (!credID || !message || !signature || !publicKey) {
        return res.status(400).json({ error: "id, message, signature, and publicKey are required" });
    }

    const { contract, gateway } = await getContract();
    try {
        // Step 1: confirm the public key matches what is on-chain
        const chainResult = await contract.evaluateTransaction(
            'verifyCredential',
            credID,
            publicKey
        );
        const chainData = JSON.parse(chainResult.toString());

        if (!chainData.verified) {
            return res.json({ verified: false, reason: "Public key mismatch on chain" });
        }

        // Step 2: verify the PQC signature in the middleware
        const sigValid = pqc.verify(message, signature, publicKey);

        return res.json({ verified: sigValid });
    } finally {
        gateway.disconnect();
    }
});

app.post("/revokeCredential", (req, res) => {
    const { studentID, credID } = req.body;
    if (!studentID || !credID) {
        return res.status(400).json({ error: "Missing parameters" });
    }

    const { contract, gateway } = await getContract();

    try {
        const result = await contract.submitTransaction(
            'revokeCredential',
            studentID,
            credID
        );

        const parsed = JSON.parse(result.toString());

        return res.json({
            ...parsed
        });
    } finally {
        gateway.disconnect();
    }
})

app.listen(3000, () => console.log("PQCreddy middleware running on port 3000"));