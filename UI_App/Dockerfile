# =============================================================================
# QCHAIN UI_APP DOCKERFILE (Flutter Mobile Development Environment)
# =============================================================================
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │  WHAT IS THIS CONTAINER?                                                │
# ├─────────────────────────────────────────────────────────────────────────┤
# │  This is a DEVELOPMENT environment for the QWallet mobile app.          │
# │  It's NOT meant for production - just for building and testing.         │
# │                                                                         │
# │  QWallet is the mobile wallet where users (Holders) store and           │
# │  present their verifiable credentials.                                  │
# └─────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │  WHY USE DOCKER FOR MOBILE DEVELOPMENT?                                 │
# ├─────────────────────────────────────────────────────────────────────────┤
# │  → Everyone gets EXACT same Flutter + Android SDK versions              │
# │  → No "works on my machine" problems                                    │
# │  → New team members can start immediately (no 2-hour setup)             │
# │  → Easy to share build environment across your VM                       │
# └─────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │  HOW TO USE                                                             │
# ├─────────────────────────────────────────────────────────────────────────┤
# │  # Build Android APK:                                                   │
# │  docker compose --profile mobile-dev run --rm mobile-dev \              │
# │    flutter build apk                                                    │
# │                                                                         │
# │  # Run Flutter tests:                                                   │
# │  docker compose --profile mobile-dev run --rm mobile-dev \              │
# │    flutter test                                                         │
# │                                                                         │
# │  # Get interactive shell (to run any command):                          │
# │  docker compose --profile mobile-dev run --rm mobile-dev bash           │
# │                                                                         │
# │  # Check Flutter installation:                                          │
# │  docker compose --profile mobile-dev run --rm mobile-dev \              │
# │    flutter doctor -v                                                    │
# └─────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │  NOTE ABOUT EMULATORS                                                   │
# ├─────────────────────────────────────────────────────────────────────────┤
# │  Running Android emulator INSIDE Docker is complex and slow.            │
# │  For emulator testing, it's easier to:                                  │
# │  1. Build APK using this container                                      │
# │  2. Copy APK to host machine                                            │
# │  3. Run emulator on host (or use physical device)                       │
# │                                                                         │
# │  The APK will be in: UI_App/build/app/outputs/flutter-apk/              │
# └─────────────────────────────────────────────────────────────────────────┘
#
# =============================================================================

# Use pre-built Flutter image with Android SDK already installed
# This saves HOURS of setup time (Android SDK is ~8GB!)
FROM ghcr.io/cirruslabs/flutter:3.27.0

# Set working directory inside container
WORKDIR /app

# OPTIMIZATION: Copy dependency files first for Docker layer caching
# If pubspec.yaml hasn't changed, this layer is reused = faster builds
COPY pubspec.yaml pubspec.lock ./

# Download Flutter packages (Dart dependencies)
RUN flutter pub get

# Pre-download Android build tools for faster builds later
# This caches SDK components inside the image
RUN flutter precache --android

# Copy the rest of your Flutter application code
COPY . .

# Accept Android SDK licenses (required for building)
# "2>/dev/null || true" suppresses errors if already accepted
RUN yes | flutter doctor --android-licenses 2>/dev/null || true

# Verify everything is set up correctly
# This prints a detailed report of Flutter installation status
RUN flutter doctor -v

# Default command when container starts
# Just runs flutter doctor - override with your actual command
CMD ["flutter", "doctor"]
