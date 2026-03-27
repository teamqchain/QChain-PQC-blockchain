# QPortal - Web Application

> The administrative web interface for the QChain platform.

---

## What is QPortal?

QPortal is the **web-based dashboard** for managing verifiable credentials in the QChain ecosystem. It serves three user roles:

| Role | What They Do |
|------|-------------|
| **Issuer** | Universities/organizations that create and sign credentials |
| **Verifier** | Employers/institutions that verify credential authenticity |
| **IT Admin** | System administrators who manage the platform |

All operations use **post-quantum cryptographic signatures** (ML-DSA-44/Dilithium), ensuring security against future quantum computer attacks.

---

## Project Structure

```
UI_WebApp/
├── lib/
│   ├── main.dart              # App entry point
│   ├── routes/                # Navigation and routing
│   ├── screens/               # UI screens
│   │   ├── issuer/            # Issuer dashboard
│   │   ├── verifier/          # Verifier dashboard
│   │   └── it_admin/          # Admin dashboard
│   ├── components/            # Reusable UI components
│   │   ├── dashboard/         # Dashboard widgets
│   │   ├── sidebar/           # Navigation sidebar
│   │   └── topbar/            # Top navigation bar
│   └── models/                # Data models
├── assets/
│   ├── images/                # Logos and images
│   └── fonts/                 # Custom fonts
├── web/                       # Web platform files
├── pubspec.yaml               # Dependencies
├── Dockerfile                 # Docker build configuration
└── nginx.conf                 # Nginx server configuration
```

---

## Development Setup

### Option 1: Docker Production Build (Recommended for Testing)

Build and serve the optimized production version:

```bash
# Navigate to docker folder
cd ../docker

# Build and start the web app
docker compose --profile web up -d

# Access at http://localhost:3000
```

### Option 2: Docker Development Mode (Hot Reload)

See your code changes instantly without rebuilding:

```bash
cd ../docker

# Start IPFS first (if needed by your changes)
docker compose up -d ipfs

# Start web app with hot reload
docker compose -f docker-compose.yml -f docker-compose.dev.yml \
  --profile web-dev up

# Access at http://localhost:8081
# Edit code in UI_WebApp/lib/ - changes appear automatically!
```

### Option 3: Local Flutter Installation

1. Install Flutter SDK: https://docs.flutter.dev/get-started/install
2. Run setup:

```bash
cd UI_WebApp
flutter pub get
flutter run -d chrome
```

---

## Docker Commands

All commands assume you're in the `docker/` folder.

### Production Mode

```bash
# Build and start (background)
docker compose --profile web up -d

# View logs
docker compose logs -f webapp

# Stop
docker compose --profile web down

# Rebuild after code changes
docker compose --profile web up -d --build
```

### Development Mode (Hot Reload)

```bash
# Start with hot reload
docker compose -f docker-compose.yml -f docker-compose.dev.yml \
  --profile web-dev up

# Stop (Ctrl+C or)
docker compose -f docker-compose.yml -f docker-compose.dev.yml \
  --profile web-dev down
```

---

## Accessing the App

| Mode | URL | When to Use |
|------|-----|-------------|
| Production | http://localhost:3000 | Testing final build |
| Development | http://localhost:8081 | Active development |

> **Note:** Port numbers can be changed in `docker/.env` file.

---

## Key Screens by Role

### Issuer Screens (`lib/screens/issuer/`)

| Screen | Purpose |
|--------|---------|
| Dashboard | Overview of issued credentials |
| Issue Credential | Create and sign new credentials |
| Templates | Manage credential templates |
| Recipients | View credential holders |

### Verifier Screens (`lib/screens/verifier/`)

| Screen | Purpose |
|--------|---------|
| Dashboard | Overview of verifications |
| Verify | Scan QR or enter CID to verify |
| History | Past verification records |

### IT Admin Screens (`lib/screens/it_admin/`)

| Screen | Purpose |
|--------|---------|
| Dashboard | System overview |
| Users | Manage Issuer/Verifier accounts |
| Blockchain | Monitor Hyperledger Fabric |
| Settings | System configuration |

---

## Dependencies

Key packages used (see `pubspec.yaml` for full list):

| Package | Purpose |
|---------|---------|
| `get` | State management and navigation |
| `flutter_web_plugins` | Web platform support |
| `font_awesome_flutter` | Icon library |

---

## State Management

This app uses **GetX** for state management:

- Controllers manage business logic
- Screens observe state with `Obx()`
- Navigation via `Get.to()`, `Get.off()`, `Get.back()`

---

## Building for Production

### Using Docker (Recommended)

```bash
cd docker
docker compose --profile web build webapp
docker compose --profile web up -d
```

The production build:
- Compiles Flutter to optimized JavaScript
- Serves via Nginx (fast, production-ready)
- Enables gzip compression
- Sets proper caching headers

### Manual Build

```bash
cd UI_WebApp
flutter build web --release

# Output in build/web/
# Deploy to any static hosting
```

---

## Nginx Configuration

The `nginx.conf` file handles:

- **SPA Routing**: All routes redirect to `index.html` (Flutter handles routing)
- **Compression**: Gzip enabled for faster loading
- **Caching**: Static assets cached for performance
- **Security**: Basic security headers set

---

## More Documentation

| Topic | Location |
|-------|----------|
| Docker Setup | `../docker/README.md` |
| Mobile App (QWallet) | `../UI_App/README.md` |
| Backend (PQC) | `../offchain/README.md` |
| Project Overview | `../README.md` |
