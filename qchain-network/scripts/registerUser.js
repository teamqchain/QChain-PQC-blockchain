'use strict';

const { Wallets } = require(`fabric-network`);
const FabricCAServices = require(`fabric-ca-client`);
const path = require(`path`);
const fs = require(`fs`);

async function main(firstName, lastName, org, role) {
    const username = `${firstName}${lastName}`;
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

        // Check to see if we've already enrolled the user
        const userIdentity = await wallet.get(`${username}`);
        if (userIdentity) {
            console.log(`An identity for the user "${username}" already exists in the wallet`);
            return;
        }

        // Check to see if we've already enrolled the admin user
        const adminIdentity = await wallet.get(`${orgLC}Admin`);
        if (!adminIdentity) {
            console.log(
                `An identity for the admin user "${orgLC}Admin" does not exist in the wallet. Run enrollAdmin.js before retrying`
            );
            return;
        }

        // Build a user object for authenticating with the CA
        const provider = wallet.getProviderRegistry().getProvider(adminIdentity.type);
        const adminUser = await provider.getUserContext(adminIdentity, `${orgLC}Admin`);

        // Register the user, enroll the user, and import the new identity into the wallet
        const secret = await ca.register(
            {
                enrollmentID: `${username}`,
                role: `client`,
                affiliation: `${orgLC}.${role}`,
                attrs: [
                    { name: `firstName`, value: `${firstName}`, ecert: true },
                    { name: `lastName`, value: `${lastName}`, ecert: true },
                    { name: `role`, value: `${role}`, ecert: true }
                ]
            },
            adminUser
        );
        const enrollment = await ca.enroll({
            enrollmentID: `${username}`,
            enrollmentSecret: secret,
        });
        const x509Identity = {
            credentials: {
                certificate: enrollment.certificate,
                privateKey: enrollment.key.toBytes(),
            },
            mspId: `${org}MSP`,
            type: `X.509`,
        };
        await wallet.put(`${username}`, x509Identity);
        console.log(`Successfully registered and enrolled user "${username}" and imported it into the wallet`);
    } catch (error) {
        console.error(`Failed to register user "${username}": ${error}`);
        process.exit(1);
    }
}

main(process.argv[2], process.argv[3], process.argv[4], process.argv[5]);