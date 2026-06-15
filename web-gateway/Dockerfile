# =============================================================================
# QCHAIN WEB GATEWAY — DOCKERFILE
# =============================================================================
#
# Builds ONE image that contains BOTH Flutter web apps plus the Nginx gateway
# that serves them and proxies the API. It is the single public-facing piece
# of the QChain demo (Tailscale Funnel points at it).
#
# IMPORTANT: build this with the build context set to the REPO ROOT, because we
# need to copy from both UI_WebApp/ and UI_App/:
#
#   docker build --build-arg API_BASE_URL="https://<vm>.<tailnet>.ts.net/api" \
#       -f web-gateway/Dockerfile -t qchain-web-gateway:latest .
#
# (The helper script web-gateway/docker-build.sh does this for you.)
#
# How it works:
#   Stage 1 "portal-build" → compiles UI_WebApp to static web files (root "/").
#   Stage 2 "wallet-build" → compiles UI_App   to static web files ("/wallet/").
#   Stage 3 "gateway"      → tiny Nginx image that serves both + proxies /api.
# =============================================================================

# The backend URL is baked into the Flutter JS at build time (the apps are
# client-side, so they must know the public API address when compiled). It is
# passed in from docker-build.sh and defaults to localhost for a plain build.
ARG API_BASE_URL=http://localhost:3000

# -----------------------------------------------------------------------------
# STAGE 1 — Build the QPortal web app (served at "/")
# -----------------------------------------------------------------------------
FROM ghcr.io/cirruslabs/flutter:3.35.4 AS portal-build
ARG API_BASE_URL
WORKDIR /app

# Copy just the manifest first so `flutter pub get` is cached unless deps change.
COPY UI_WebApp/pubspec.yaml ./
RUN flutter pub get

# Copy the rest of the portal source and build.
COPY UI_WebApp/ ./
RUN flutter build web --release \
        --base-href="/" \
        --dart-define=API_BASE_URL="$API_BASE_URL"

# -----------------------------------------------------------------------------
# STAGE 2 — Build the QWallet web app (served at "/wallet/")
# -----------------------------------------------------------------------------
# Same steps, but base-href is "/wallet/" so all of the wallet's asset URLs
# resolve under the /wallet/ sub-path behind the gateway.
FROM ghcr.io/cirruslabs/flutter:3.35.4 AS wallet-build
ARG API_BASE_URL
WORKDIR /app

COPY UI_App/pubspec.yaml ./
RUN flutter pub get

COPY UI_App/ ./
RUN flutter build web --release \
        --base-href="/wallet/" \
        --dart-define=API_BASE_URL="$API_BASE_URL"

# -----------------------------------------------------------------------------
# STAGE 3 — Assemble the Nginx gateway
# -----------------------------------------------------------------------------
FROM nginx:alpine AS gateway

# Clear the default Nginx welcome page.
RUN rm -rf /usr/share/nginx/html/*

# Portal goes at the web root; wallet goes in the /wallet sub-directory.
COPY --from=portal-build /app/build/web        /usr/share/nginx/html
COPY --from=wallet-build /app/build/web         /usr/share/nginx/html/wallet

# Our routing config (replaces Nginx's default server block).
COPY web-gateway/nginx.conf /etc/nginx/conf.d/default.conf

# The gateway listens on 8090 (see nginx.conf). EXPOSE is informational because
# the container runs with --network host.
EXPOSE 8090

# Let Docker know the gateway is healthy when /gw-health answers.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:8090/gw-health || exit 1

CMD ["nginx", "-g", "daemon off;"]
