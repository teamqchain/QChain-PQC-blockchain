# =============================================================================
# QCHAIN UI_WEBAPP DOCKERFILE (Flutter Web + Nginx)
# =============================================================================
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │  WHAT IS THIS CONTAINER?                                                │
# ├─────────────────────────────────────────────────────────────────────────┤
# │  This builds and serves the QPortal web application:                    │
# │  → Issuer portal (universities create credentials)                      │
# │  → Verifier portal (employers verify credentials)                       │
# │  → IT Admin portal (system management)                                  │
# └─────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │  HOW DOES IT WORK?                                                      │
# ├─────────────────────────────────────────────────────────────────────────┤
# │  Stage 1: Flutter Build                                                 │
# │  → Takes your Dart/Flutter code                                         │
# │  → Compiles it to HTML, CSS, JavaScript                                 │
# │  → Output goes to build/web/ folder                                     │
# │                                                                         │
# │  Stage 2: Nginx Server                                                  │
# │  → Takes the compiled HTML/CSS/JS files                                 │
# │  → Serves them as a fast, production-ready website                      │
# │  → Nginx is like Apache - a web server                                  │
# └─────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │  AFTER BUILDING                                                         │
# ├─────────────────────────────────────────────────────────────────────────┤
# │  Access the web app at: http://localhost:3000                           │
# │                                                                         │
# │  Start with: docker compose --profile web up -d                         │
# │  Stop with:  docker compose --profile web down                          │
# └─────────────────────────────────────────────────────────────────────────┘
#
# =============================================================================

# =============================================================================
# STAGE 1: FLUTTER BUILD
# =============================================================================
# Compile Flutter/Dart code into static web files (HTML, CSS, JS)

# Use pre-built Flutter image from Cirrus Labs
# This image has Flutter SDK pre-installed (saves ~10 min build time)
FROM ghcr.io/cirruslabs/flutter:3.27.0 AS builder

WORKDIR /app

# OPTIMIZATION: Copy dependency files first
# Docker caches this layer. If pubspec.yaml hasn't changed,
# "flutter pub get" step is skipped = faster builds!
COPY pubspec.yaml pubspec.lock ./

# Download Flutter packages (like npm install for JavaScript)
RUN flutter pub get

# Copy the rest of your Flutter code
COPY . .

# Build for web in release mode (optimized, minified)
# --base-href="/" means app lives at root URL (e.g., http://localhost:3000/)
RUN flutter build web --release --base-href="/"

# =============================================================================
# STAGE 2: NGINX SERVER (Production)
# =============================================================================
# Serve the compiled website using Nginx (fast production web server)

# nginx:alpine is a tiny image (~20MB) with Nginx pre-installed
FROM nginx:alpine AS production

# Remove default Nginx welcome page
RUN rm -rf /usr/share/nginx/html/*

# Copy our compiled Flutter web app from the builder stage
# The build output is in /app/build/web/
COPY --from=builder /app/build/web /usr/share/nginx/html

# Copy our custom Nginx configuration
# This handles Flutter's SPA (Single Page Application) routing
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Nginx listens on port 80 inside the container
# docker-compose maps this to 3000 on your computer
EXPOSE 80

# Health check: verify Nginx is responding
# Docker uses this to know if the container is healthy
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

# Start Nginx in foreground mode (required for Docker)
# "daemon off" keeps Nginx running in foreground instead of background
CMD ["nginx", "-g", "daemon off;"]
