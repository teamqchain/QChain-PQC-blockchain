# QWallet - Mobile Wallet App

> The credential holder's mobile wallet for the QChain platform.

---

## What is QWallet?

QWallet is the **Holder application** in the QChain ecosystem. It allows users (students, employees, etc.) to:

- **Store** verifiable credentials issued by universities/organizations
- **Present** credentials via QR code for verification
- **Manage** multiple credentials in one secure wallet
- **Control** which credential attributes to share (selective disclosure)

All credentials are protected by **post-quantum cryptographic signatures** (ML-DSA-44/Dilithium), making them secure against future quantum computer attacks.

---

## Project Structure

```
UI_App/
├── lib/
│   ├── main.dart              # App entry point
│   ├── routes/                # Navigation and routing
│   ├── screens/               # UI screens
│   │   ├── onboarding/        # First-time user flow
│   │   ├── home/              # Dashboard
│   │   ├── wallet/            # Credential management
│   │   ├── documents/         # Document viewer
│   │   ├── activity/          # Activity history
│   │   └── settings/          # App settings
│   ├── components/            # Reusable UI components
│   ├── widgets/               # Custom widgets
│   └── model/                 # Data models
├── assets/
│   ├── images/                # App images and logos
│   └── fonts/                 # Custom fonts
├── android/                   # Android-specific code
├── ios/                       # iOS-specific code
├── web/                       # Web platform support
├── pubspec.yaml               # Dependencies
└── Dockerfile                 # Docker build configuration
```

---

## Development Setup

### Option 1: Docker (Recommended)

Docker ensures everyone has the exact same Flutter + Android SDK versions.

```bash
# Navigate to docker folder
cd ../docker

# Build the mobile dev environment (first time only)
docker compose build mobile-dev

# Run Flutter commands inside Docker
docker compose --profile mobile-dev run --rm mobile-dev flutter doctor
```

### Option 2: Local Flutter Installation

1. Install Flutter SDK: https://docs.flutter.dev/get-started/install
2. Install Android Studio (for Android SDK)
3. Run setup:

```bash
cd UI_App
flutter pub get
flutter doctor
```

---

## Docker Commands

All commands assume you're in the `docker/` folder.

### Check Flutter Setup
```bash
docker compose --profile mobile-dev run --rm mobile-dev flutter doctor -v
```

### Get Dependencies
```bash
docker compose --profile mobile-dev run --rm mobile-dev flutter pub get
```

### Run Tests
```bash
docker compose --profile mobile-dev run --rm mobile-dev flutter test
```

### Build Debug APK
```bash
docker compose --profile mobile-dev run --rm mobile-dev flutter build apk --debug
```

### Build Release APK
```bash
docker compose --profile mobile-dev run --rm mobile-dev flutter build apk --release
```

### Interactive Shell (for any command)
```bash
docker compose --profile mobile-dev run --rm mobile-dev bash
```

### Where to Find the APK
After building, the APK is located at:
```
UI_App/build/app/outputs/flutter-apk/app-release.apk
```

---

## Running on Emulator/Device

> **Note:** Running emulators inside Docker is complex. We recommend building the APK in Docker, then installing on a local emulator or physical device.

### Using Physical Device
1. Build APK using Docker (see above)
2. Transfer APK to your phone
3. Install and test

### Using Local Emulator
1. Build APK using Docker
2. Start Android emulator on your computer (not in Docker)
3. Install APK:
   ```bash
   adb install UI_App/build/app/outputs/flutter-apk/app-debug.apk
   ```

---

## Key Screens

| Screen | Path | Purpose |
|--------|------|---------|
| Onboarding | `lib/screens/onboarding/` | First-time user setup |
| Home | `lib/screens/home/` | Main dashboard |
| Wallet | `lib/screens/wallet/` | View all credentials |
| Add Credential | `lib/screens/wallet/` | Scan/import new credentials |
| Present | `lib/screens/wallet/` | Generate QR for verification |
| Documents | `lib/screens/documents/` | View credential details |
| Activity | `lib/screens/activity/` | History of presentations |
| Settings | `lib/screens/settings/` | App preferences |

---

## Dependencies

Key packages used (see `pubspec.yaml` for full list):

| Package | Purpose |
|---------|---------|
| `get` | State management and navigation |
| `flutter_card_swiper` | Credential card swiping UI |
| `phosphor_flutter` | Icon library |

---

## State Management

This app uses **GetX** for state management. Key concepts:

- Controllers in `lib/` manage business logic
- Screens observe controller state with `Obx()`
- Navigation via `Get.to()`, `Get.off()`, `Get.back()`

---

## More Documentation

| Topic | Location |
|-------|----------|
| Docker Setup | `../docker/README.md` |
| Web App (QPortal) | `../UI_WebApp/README.md` |
| Backend (PQC) | `../offchain/README.md` |
| Project Overview | `../README.md` |
