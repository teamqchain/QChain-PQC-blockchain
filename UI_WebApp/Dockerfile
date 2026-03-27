# =============================================================================
# QChain UI_WebApp Dockerfile (Flutter Web + Nginx)
# Multi-stage build: Flutter compile -> Nginx serve
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Flutter Build
# -----------------------------------------------------------------------------
FROM ghcr.io/cirruslabs/flutter:3.27.0 AS builder

WORKDIR /app

# Copy pubspec files first for dependency caching
COPY pubspec.yaml pubspec.lock ./

# Get dependencies
RUN flutter pub get

# Copy the rest of the application
COPY . .

# Build for web (release mode)
RUN flutter build web --release --base-href="/"

# -----------------------------------------------------------------------------
# Stage 2: Production Nginx Server
# -----------------------------------------------------------------------------
FROM nginx:alpine AS production

# Remove default nginx content
RUN rm -rf /usr/share/nginx/html/*

# Copy built web app from builder
COPY --from=builder /app/build/web /usr/share/nginx/html

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
