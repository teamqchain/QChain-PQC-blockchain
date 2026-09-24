# QChain Setup Guide (Ubuntu / Fedora · x86_64 / ARM64)

This guide provides step-by-step instructions for setting up the entire QChain backend and blockchain infrastructure on **Ubuntu** (20.04/22.04/24.04) or **Fedora** Linux, on both **x86_64 (AMD/Intel)** and **ARM64 (Apple Silicon M-series via UTM / AWS Graviton)** architectures.

---

## 1. Prerequisites

### Step 1A: For Ubuntu / Debian

```bash
# Update package lists
sudo apt update && sudo apt upgrade -y

# 1. Install system utilities
sudo apt install -y curl wget git tar build-essential ca-certificates gnupg

# 2. Install Docker & Docker Compose
sudo apt install -y docker.io docker-compose-v2
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
# (Note: log out and log back in or run 'newgrp docker' for group permissions to take effect)

# 3. Install Node.js 20.x & npm (required for Fabric Chaincode)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# 4. Install MariaDB Server
sudo apt install -y mariadb-server
sudo systemctl enable --now mariadb
```

### Step 1B: For Fedora / RHEL

```bash
# Update system
sudo dnf update -y

# 1. Install system utilities
sudo dnf install -y curl wget git tar dnf-plugins-core

# 2. Install Docker & Docker Compose
sudo dnf config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

# 3. Install Node.js & npm (required for Fabric Chaincode)
sudo dnf install -y nodejs npm

# 4. Install MariaDB Server
sudo dnf install -y mariadb-server
sudo systemctl enable --now mariadb
```

---

### Step 1C: Install IPFS (Kubo) & Fabric Binaries (Universal)

Run these commands on either OS. Architecture (`x86_64` vs `arm64`) is detected automatically:

```bash
# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    KUBO_ARCH="amd64"
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    KUBO_ARCH="arm64"
else
    echo "Unsupported architecture: $ARCH"; exit 1
fi

# 1. Install IPFS (Kubo)
wget "https://dist.ipfs.tech/kubo/v0.32.1/kubo_v0.32.1_linux-${KUBO_ARCH}.tar.gz"
tar -xvzf "kubo_v0.32.1_linux-${KUBO_ARCH}.tar.gz"
cd kubo && sudo bash install.sh && cd ..
rm -rf kubo "kubo_v0.32.1_linux-${KUBO_ARCH}.tar.gz"

# 2. Install Hyperledger Fabric Binaries (auto-detects architecture)
curl -sSL https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh | bash -s -- binary
# Add downloaded binaries to PATH
export PATH=$PATH:$PWD/bin
echo "export PATH=\$PATH:$PWD/bin" >> ~/.bashrc

# 3. Verify installations
docker ps
peer version
mariadb --version
ipfs --version
node -v
```

## 2. Clone Repository

```bash
git clone https://github.com/nihvp/QChain-PQC-blockchain.git
cd QChain-PQC-blockchain
export REPO_ROOT=$PWD
```

## 3. Configure Local Hosts Mappings (/etc/hosts)

Since the Fabric CLI scripts communicate with the CA and peer services via custom domain names on `localhost`, you must map these hostnames to `127.0.0.1` in `/etc/hosts` on your Fedora VM:

```bash
sudo tee -a /etc/hosts <<EOF

# QChain Fabric Domains
127.0.0.1 ca.government.uae.com
127.0.0.1 ca.general.uae.com
127.0.0.1 ca.orderer.example.com
127.0.0.1 peer0.government.uae.com
127.0.0.1 peer0.general.uae.com
127.0.0.1 orderer0.orderer.example.com
EOF
```

## 4. Database Initialization

We need to create the database, a specific user for the Go backend, and seed the initial schema.

```bash
# Secure MariaDB (optional but recommended)
sudo mysql_secure_installation

# Create Database and User
sudo mysql -e "CREATE DATABASE qchain_db CHARACTER SET utf8mb4;"
sudo mysql -e "CREATE USER 'qchain_user'@'%' IDENTIFIED BY 'password';"
sudo mysql -e "GRANT ALL PRIVILEGES ON qchain_db.* TO 'qchain_user'@'%';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Seed the schema (includes every column the backend needs — no separate migrations to run)
sudo mysql qchain_db < qchain-network/scripts/schema.sql
```

## 5. IPFS Setup

```bash
ipfs init
bash qchain-network/scripts/setup-ipfs-service.sh
```

## 6. Hyperledger Fabric Network Setup

This section completely replaces the incomplete manual steps in the root README.

### Start CAs and Generate Crypto Material
```bash
cd qchain-network/docker
# Start the Certificate Authorities
docker compose -f docker-compose-ca.yaml up -d
sleep 5 # Wait for CAs to start

# Generate all MSP crypto material via Fabric CA
cd ../scripts
# IMPORTANT: Before running, update the hardcoded path in env scripts
sed -i "s|NETWORK_ROOT=.*|NETWORK_ROOT=\"$REPO_ROOT/qchain-network\"|g" env-gov.sh
sed -i "s|NETWORK_ROOT=.*|NETWORK_ROOT=\"$REPO_ROOT/qchain-network\"|g" env-gen.sh
sed -i "s|NETWORK_ROOT=.*|NETWORK_ROOT=\"$REPO_ROOT/qchain-network\"|g" registerEnroll.sh

bash registerEnroll.sh
```

### Start Fabric Nodes
```bash
cd ../docker
docker compose -f docker-compose.yaml up -d orderer0.orderer.example.com peer0.government.uae.com peer0.general.uae.com couchdb0
cd ../..
```

### Create and Join Channel (Using OSNAdmin)
Since this project's orderer operates without a system channel (`ORDERER_GENERAL_BOOTSTRAPMETHOD=none`), we must use `osnadmin` instead of the deprecated `peer channel create` command.

```bash
# 1. Create channel genesis block
export FABRIC_CFG_PATH=$REPO_ROOT/qchain-network/config
configtxgen -profile TwoOrgsChannel -channelID mychannel -outputBlock $REPO_ROOT/qchain-network/channel-artifacts/mychannel.block

# 2. Join Orderer to the channel
export ORDERER_ADMIN_TLS_SIGNCLIENTCERT=$REPO_ROOT/qchain-network/crypto-material/ordererOrganizations/orderer.example.com/orderers/orderer0.orderer.example.com/tls/server.crt
export ORDERER_ADMIN_TLS_PRIVATEKEY=$REPO_ROOT/qchain-network/crypto-material/ordererOrganizations/orderer.example.com/orderers/orderer0.orderer.example.com/tls/server.key
export ORDERER_CA=$REPO_ROOT/qchain-network/crypto-material/ordererOrganizations/orderer.example.com/orderers/orderer0.orderer.example.com/tls/ca.crt

osnadmin channel join --channelID mychannel \
  --config-block $REPO_ROOT/qchain-network/channel-artifacts/mychannel.block \
  -o localhost:7053 \
  --ca-file $ORDERER_CA \
  --client-cert $ORDERER_ADMIN_TLS_SIGNCLIENTCERT \
  --client-key $ORDERER_ADMIN_TLS_PRIVATEKEY

# 3. Join Peers to the channel
# Government Peer
source $REPO_ROOT/qchain-network/scripts/env-gov.sh
peer channel join -b $REPO_ROOT/qchain-network/channel-artifacts/mychannel.block

# General Peer
source $REPO_ROOT/qchain-network/scripts/env-gen.sh
peer channel join -b $REPO_ROOT/qchain-network/channel-artifacts/mychannel.block
```

### Deploy Chaincode

> [!NOTE]
> **Chaincode v2.0 needs an empty ledger.** v2.0 stores a signed commitment per credential (no plaintext
> `Info`), takes new `issueCredential` arguments and removes `verifyCredential` / `setCID` /
> `getCredentialsByHolder`, so a network still running an earlier chaincode version needs a full ledger
> reset (back up MySQL, tear down and recreate the channel, redeploy chaincode as a fresh sequence 1)
> before following this section as version 2.0, sequence 1.

```bash
# 1. Install dependencies, run the chaincode unit tests, and package
export REPO_ROOT=$(pwd)
export ORDERER_CA=$REPO_ROOT/qchain-network/crypto-material/ordererOrganizations/orderer.example.com/orderers/orderer0.orderer.example.com/tls/ca.crt

cd $REPO_ROOT/qchain-network/chaincode
npm install
npm test            # node:test suite against an in-memory ledger (Node 18+) — all tests must pass
cd ../..

source $REPO_ROOT/qchain-network/scripts/env-gov.sh
peer lifecycle chaincode package qchaincode_2.0.tar.gz --path $REPO_ROOT/qchain-network/chaincode --lang node --label qchaincode_2.0

# 2. Install on Government peer
peer lifecycle chaincode install qchaincode_2.0.tar.gz

# Find package ID
export CC_PACKAGE_ID=$(peer lifecycle chaincode queryinstalled | grep qchaincode_2.0 | awk '{print $3}' | sed 's/,//')

# Approve for Government
peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer0.orderer.example.com --channelID mychannel --name qchaincode --version 2.0 --package-id $CC_PACKAGE_ID --sequence 1 --tls --cafile $ORDERER_CA

# 3. Install and Approve on General peer
source $REPO_ROOT/qchain-network/scripts/env-gen.sh
peer lifecycle chaincode install qchaincode_2.0.tar.gz
peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer0.orderer.example.com --channelID mychannel --name qchaincode --version 2.0 --package-id $CC_PACKAGE_ID --sequence 1 --tls --cafile $ORDERER_CA

# 4. Commit chaincode (sequence 1)
peer lifecycle chaincode commit -o localhost:7050 --ordererTLSHostnameOverride orderer0.orderer.example.com --channelID mychannel --name qchaincode --version 2.0 --sequence 1 --tls --cafile $ORDERER_CA \
  --peerAddresses localhost:7051 --tlsRootCertFiles $REPO_ROOT/qchain-network/crypto-material/peerOrganizations/government.uae.com/peers/peer0.government.uae.com/tls/ca.crt \
  --peerAddresses localhost:9051 --tlsRootCertFiles $REPO_ROOT/qchain-network/crypto-material/peerOrganizations/general.uae.com/peers/peer0.general.uae.com/tls/ca.crt

# 5. Smoke test — an empty batch read must answer {"holders":{}}
peer chaincode query -C mychannel -n qchaincode -c '{"Args":["getHolders","[]","summary"]}'
```

Future chaincode changes on this network are upgrades: re-package with a new label/version and approve +
commit with `--sequence 2`, `3`, … on both peers, exactly like steps 1–4.

## 7. Backend (off-chain Go API) Setup

Because `liboqs-go` requires compiling the C library `liboqs` with CGo, we build the Docker image first (which compiles `liboqs` inside Docker automatically), and then run `keygen` from the Docker image.

```bash
cd $REPO_ROOT

# 1. Run the Go unit tests in the image's builder stage, then build the image
#    (first build takes ~15-20 mins to compile liboqs; go vet also runs during the build)
docker build --target builder -t qchain-api:test offchain
docker run --rm qchain-api:test go test -count=1 ./...
bash offchain/docker-build.sh

# 2. Generate organisation ML-DSA-44 keys via Docker
docker run --rm qchain-api:latest keygen

# 3. Create the .env configuration file
cat > offchain/.env <<'ENV'
ISSUER_PRIVATE_KEY_HEX=<insert-private-key-hex-here>
ISSUER_PUBLIC_KEY_HEX=<insert-public-key-hex-here>
ISSUER_ORG_ID=GeneralMSP
ISSUER_ORG=general
ISSUER_IDENTITY=issuer1
VERIFIER_ORG=general
VERIFIER_IDENTITY=verifier1
MYSQL_DSN=qchain_user:password@tcp(127.0.0.1:3306)/qchain_db
NETWORK_ROOT=/qchain-network
CHANNEL_NAME=mychannel
CHAINCODE_NAME=qchaincode
IPFS_HOST=127.0.0.1:5001
SERVER_PORT=3000
ENV

# 4. Open offchain/.env in your text editor and insert the hex keys you generated in step 2

# 5. Start the backend container
bash offchain/docker-run.sh

# 6. Seed the demo holders on Fabric via the API
bash qchain-network/scripts/setup-demo.sh http://localhost:3000

# 7. (Track H) Register holder public keys (wallet activation)
# The QWallet mobile app generates keys locally on-device and binds the public keys on-chain via
# /mobile/registerHolderKeys. A credential can only be issued to a holder whose keys are bound.
# You can check if a holder has keys registered (read from the chain):
curl -s "http://localhost:3000/mobile/checkKeys?emiratesID=784-1990-1234567-1"

# 8. End-to-end check (plays issuer + holder with the keygen tool; needs IPFS, Fabric and MySQL up)
bash tests/e2e_api_test.sh http://localhost:3000
```

> **Where data lives.** The ledger is the source of truth for every field it holds (holder names and
> public keys, credential type/status/dates, CID, field hashes, issuer signature); IPFS holds the only
> copy of each credential's body, encrypted to the holder; MySQL holds only what exists nowhere else
> (Emirates ID → holder mapping, email, display IDs, sessions, subscriptions, logs). IPFS must be running
> for issuance, and Fabric for every read — there is no database fallback.

## 8. Cloudflare Tunnel Setup (Free Random URL)

To instantly share the backend API with your frontend developer without creating a Cloudflare account or buying a domain, you can use Cloudflare's free Quick Tunnel:

```bash
# 1. Download the standalone cloudflared binary (auto-detects architecture)
ARCH=$(uname -m)
CF_ARCH="amd64"
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    CF_ARCH="arm64"
fi
curl -L --output cloudflared "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}"
chmod +x cloudflared
sudo mv cloudflared /usr/local/bin/

# 2. Start the quick tunnel pointing to port 3000
cloudflared tunnel --url http://localhost:3000
```

This will print an instant, free public URL in your terminal:
```text
+--------------------------------------------------------------------------------------------+
|  Your quick Tunnel has been created! Visit it at (it may take some time to be reachable):  |
|  https://random-words-here.trycloudflare.com                                               |
+--------------------------------------------------------------------------------------------+
```

Give `https://random-words-here.trycloudflare.com` to your frontend developer to use as the `API_BASE_URL`.

## 9. Frontend Setup

The repository includes:
- **QPortal (`UI_WebApp`)**: a Flutter **web** app for Issuers, Verifiers, and IT Administrators.
- **QWallet (`UI_App`)**: a Flutter **mobile-only** app for credential holders to view, store, and
  present credentials. It cannot run in a browser — its ML-KEM-768/ML-DSA-44 key pair is generated and
  held only on-device (a browser build would mean a different key pair per browser/device, breaking the
  one-key-pair-per-holder model), and its PQC library (`liboqs`) uses `dart:ffi`, which doesn't exist in
  a browser at all. Run it on a device/emulator with `flutter run`, or build an install
  (`flutter build apk` / `flutter build ios`).

You can run QPortal either locally on your development machine using Flutter or directly via Docker.

---

### Method A: Running Locally with Flutter SDK (Development)

Ensure you have Flutter and Google Chrome installed on your machine (`flutter doctor`).

#### 1. Connected to Local Backend (`http://localhost:3000`)

If the backend is running locally on port 3000, simply run:

```bash
# Run QPortal (Issuer/Verifier/Admin Portal)
cd UI_WebApp
flutter pub get
flutter run -d chrome

# In a separate terminal, run QWallet (Holder App) on a connected device/emulator —
# QWallet cannot target chrome/web, see the note above.
cd UI_App
flutter pub get
flutter devices        # pick a device id
flutter run -d <device-id>
```

#### 2. Connected to Remote Backend (via Cloudflare Tunnel URL)

If connecting to a remote backend exposed by Cloudflare Tunnel, inject the URL at startup:

```bash
# Run QPortal
cd UI_WebApp
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=https://<your-tunnel-name>.trycloudflare.com

# Run QWallet (device/emulator)
cd UI_App
flutter pub get
flutter run -d <device-id> --dart-define=API_BASE_URL=https://<your-tunnel-name>.trycloudflare.com
```

#### 3. VS Code One-Click Launch Configuration (`launch.json`)

To run and debug directly in VS Code, create or edit `.vscode/launch.json`. QWallet's `deviceId` is
machine-specific (run `flutter devices` and use the id it prints) since it can't target `chrome`/web:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "QPortal (Local)",
      "cwd": "UI_WebApp",
      "request": "launch",
      "type": "dart",
      "deviceId": "chrome"
    },
    {
      "name": "QPortal (Cloudflare)",
      "cwd": "UI_WebApp",
      "request": "launch",
      "type": "dart",
      "deviceId": "chrome",
      "toolArgs": [
        "--dart-define=API_BASE_URL=https://<your-tunnel-name>.trycloudflare.com"
      ]
    },
    {
      "name": "QWallet (Local)",
      "cwd": "UI_App",
      "request": "launch",
      "type": "dart",
      "deviceId": "<your-device-id>"
    },
    {
      "name": "QWallet (Cloudflare)",
      "cwd": "UI_App",
      "request": "launch",
      "type": "dart",
      "deviceId": "<your-device-id>",
      "toolArgs": [
        "--dart-define=API_BASE_URL=https://<your-tunnel-name>.trycloudflare.com"
      ]
    }
  ]
}
```

---

### Method B: Running QPortal via Docker Web Gateway (Zero-Install)

If you don't have Flutter installed locally, you can compile and serve QPortal using the `web-gateway`
Docker container on the host/VM (QWallet isn't part of this image — see the note at the top of this
section; run it with Flutter directly, per Method A):

```bash
cd $REPO_ROOT

# 1. Build gateway container (builds QPortal in Docker)
# For Cloudflare Tunnel, set the public URL:
export API_BASE_URL="https://<your-tunnel-name>.trycloudflare.com/api"
bash web-gateway/docker-build.sh

# 2. Start the gateway container (binds port 8090)
bash web-gateway/docker-run.sh
```

- **QPortal URL:** `http://localhost:8090/` (or `https://<your-tunnel>.trycloudflare.com/`)
