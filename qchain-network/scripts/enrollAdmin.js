'use strict';

const { Wallets } = require(`fabric-network`);
const FabricCAServices = require(`fabric-ca-client`);
const path = require(`path`);
const fs = require(`fs`);

async function main(org) {
    const orgLC = org.toLowerCase();
    try {
        // Load the network configuration
        const ccpPath = path.resolve(__dirname, `..`, `connection`, `connection-${orgLC.slice(0, 3)}.json`);
        const ccp = JSON.parse(fs.readFileSync(ccpPath, `utf8`));

        // Create a new CA client for interacting with the CA
        const caInfo = ccp.certificateAuthorities[`ca.${orgLC}.uae.com`];
        const caTLSCACerts = caInfo.tlsCACerts.pem;
        const ca = new FabricCAServices(
            caInfo.url,
            { trustedRoots: caTLSCACerts, verify: false },
            caInfo.caName
        );

        // Create a new file system based wallet for managing identities
        const walletPath = path.join(__dirname, `..`, `wallet`, `${orgLC}`);
        const wallet = await Wallets.newFileSystemWallet(walletPath);
        console.log(`Wallet path: ${walletPath}`);

        // Check to see if we've already enrolled the admin user
        const identity = await wallet.get(`${orgLC}Admin`);
        if (identity) {
            console.log(`An identity for the admin user "${orgLC}Admin" already exists in the wallet`);
            return;
        }

        // Enroll the admin user, and import the new identity into the wallet
        const enrollment = await ca.enroll({
            enrollmentID: `admin`,
            enrollmentSecret: `adminpw`
        });
        const x509Identity = {
            credentials: {
                certificate: enrollment.certificate,
                privateKey: enrollment.key.toBytes(),
            },
            mspId: `${org}MSP`,
            type: `X.509`,
        };
        await wallet.put(`${orgLC}Admin`, x509Identity);
        console.log(`Successfully enrolled admin user "${orgLC}Admin" and imported it into the wallet`);
    } catch (error) {
        console.error(`Failed to enroll admin user: ${error}`);
        process.exit(1);
    }
}

main(process.argv[2]);