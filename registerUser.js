'use strict';

const { Wallets } = require('fabric-network');
const FabricCAServices = require('fabric-ca-client');
const path = require('path');
const fs = require('fs');

/**
 * Registers and enrolls a user in a Hyperledger Fabric org.
 * @param {string} username - Unique Fabric username (enrollmentID)
 * @param {string} organization - Org name, e.g., "government", "university"
 * @param {string} role - User role, e.g., "holder", "issuer", "verifier"
 * @param {string} orgNumber - Optional org number (if different mapping)
 */
async function registerUser(username, organization, role, orgNumber = null) {
    try {
        if (!username || !organization || !role) {
            throw new Error('Missing parameters.');
        }

        organization = organization.toLowerCase();

        if (role !== 'holder' && role !== 'issuer' && role !== 'verifier') {
            throw new Error('Invalid role.');
        }

        // Map org names to org numbers if not provided
        if (!orgNumber) {
            switch (organization) {
                case 'government': orgNumber = '1'; break;
                case 'university': orgNumber = '2'; break;
                // Add more orgs here as needed
                default:
                    throw new Error(`Unknown organization: ${organization}`);
            }
        }

        // Load connection profile for the org
        const ccpPath = path.resolve(__dirname, '..', 'connection', `connection-org${orgNumber}.json`);
        if (!fs.existsSync(ccpPath)) {
            throw new Error(`Connection profile not found: ${ccpPath}`);
        }
        const ccp = JSON.parse(fs.readFileSync(ccpPath, 'utf8'));

        // Get CA URL
        const caURL = ccp.certificateAuthorities[`ca.org${orgNumber}.example.com`].url;
        const ca = new FabricCAServices(caURL);

        // Set up wallet for the org
        const walletPath = path.join(__dirname, '..', 'wallet', `org${orgNumber}`);
        const wallet = await Wallets.newFileSystemWallet(walletPath);
        console.log(`Using wallet at: ${walletPath}`);

        // Check if user already exists
        const userIdentity = await wallet.get(username);
        if (userIdentity) {
            console.log(`An identity for the user "${username}" already exists in the wallet`);
            return;
        }

        // Check if admin exists
        const adminIdentity = await wallet.get(`org${orgNumber}Admin`);
        if (!adminIdentity) {
            throw new Error(`Admin identity "org${orgNumber}Admin" not found in wallet. Run enrollAdmin first.`);
        }

        // Build a user object for authenticating with the CA
        const provider = wallet.getProviderRegistry().getProvider(adminIdentity.type);
        const adminUser = await provider.getUserContext(adminIdentity, `org${orgNumber}Admin`);

        // Register the user
        const secret = await ca.register(
            {
                enrollmentID: username,
                affiliation: organization,
                role: 'client',
                attrs: [{ name: `${organization}.role`, value: role, ecert: true }],
            },
            adminUser
        );

        // Enroll the user
        const enrollment = await ca.enroll({
            enrollmentID: username,
            enrollmentSecret: secret,
        });

        // Create X.509 identity
        const x509Identity = {
            credentials: {
                certificate: enrollment.certificate,
                privateKey: enrollment.key.toBytes(),
            },
            mspId: `Org${orgNumber}MSP`,
            type: 'X.509',
        };

        // Store in wallet
        await wallet.put(username, x509Identity);
        console.log(`Successfully registered and enrolled user "${username}" in org "${organization}"`);
    } catch (error) {
        console.error(`Failed to register user "${username}": ${error}`);
        process.exit(1);
    }
}

module.exports = registerUser;