# =============================================================================
# QChain UI_App Dockerfile (Flutter Mobile Development Environment)
# For building Android APKs and development workflows
# =============================================================================

FROM ghcr.io/cirruslabs/flutter:3.27.0

# Set working directory
WORKDIR /app

# Copy pubspec files first for dependency caching
COPY pubspec.yaml pubspec.lock ./

# Get Flutter dependencies
RUN flutter pub get

# Pre-download Android SDK components for faster builds
RUN flutter precache --android

# Copy the rest of the application
COPY . .

# Accept Android licenses
RUN yes | flutter doctor --android-licenses 2>/dev/null || true

# Verify Flutter setup
RUN flutter doctor -v

# Default command - show available commands
CMD ["flutter", "doctor"]
