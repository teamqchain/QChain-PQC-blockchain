# =============================================================================
# QCHAIN WEB GATEWAY — DOCKERFILE
# =============================================================================
#
# Builds ONE image containing the QPortal web app plus the Nginx gateway that
# serves it and proxies the API. It is the single public-facing piece of the
# QChain demo (Tailscale Funnel points at it).
#
# QWallet is NOT built here — it ships as a mobile install only (built and
# distributed by Haris with his own tooling), never as a web app. QWallet
# generates its ML-KEM-768/ML-DSA-44 key pair on-device and keeps the private
# key there; a browser build would mean a different key pair per browser/
# device, which breaks the one-key-pair-per-holder model entirely. It's also
# not just a design choice: QWallet's liboqs dependency uses dart:ffi (native
# C bindings), which cannot compile for a web/JS target at all.
#
# IMPORTANT: build this with the build context set to the REPO ROOT, because we
# need to copy from both UI_WebApp/ and shared/:
#
#   docker build --build-arg API_BASE_URL="https://<vm>.<tailnet>.ts.net/api" \
#       -f web-gateway/Dockerfile -t qchain-web-gateway:latest .
#
# (The helper script web-gateway/docker-build.sh does this for you.)
#
# How it works:
#   Stage 1 "portal-build" → compiles UI_WebApp to static web files (root "/").
#   Stage 2 "gateway"      → tiny Nginx image that serves it + proxies /api.
# =============================================================================

# The backend URL is baked into the Flutter JS at build time (the app is
# client-side, so it must know the public API address when compiled). It is
# passed in from docker-build.sh and defaults to localhost for a plain build.
ARG API_BASE_URL=http://localhost:3000

# -----------------------------------------------------------------------------
# STAGE 1 — Build the QPortal web app (served at "/")
# -----------------------------------------------------------------------------
FROM ghcr.io/cirruslabs/flutter:3.44.0 AS portal-build
ARG API_BASE_URL
WORKDIR /app

# UI_WebApp depends on qchain_shared via a local path ("../shared" in its
# pubspec.yaml), so /shared must exist alongside /app before `flutter pub
# get` resolves it. Only the manifest is needed for resolution, so copy just
# that here (full source comes later) — same caching intent as the app copy
# below: this layer stays cached unless a pubspec actually changes.
COPY UI_WebApp/pubspec.yaml ./
COPY shared/pubspec.yaml shared/pubspec.lock /shared/
RUN flutter pub get

# Copy the rest of the portal source (and the shared package's source) and build.
COPY UI_WebApp/ ./
COPY shared/ /shared/
RUN flutter build web --release \
        --base-href="/" \
        --dart-define=API_BASE_URL="$API_BASE_URL"

# -----------------------------------------------------------------------------
# STAGE 2 — Assemble the Nginx gateway
# -----------------------------------------------------------------------------
FROM nginx:alpine AS gateway

# Clear the default Nginx welcome page.
RUN rm -rf /usr/share/nginx/html/*

COPY --from=portal-build /app/build/web        /usr/share/nginx/html

# Our routing config (replaces Nginx's default server block).
COPY web-gateway/nginx.conf /etc/nginx/conf.d/default.conf

# The gateway listens on 8090 (see nginx.conf). EXPOSE is informational because
# the container runs with --network host.
EXPOSE 8090

# Let Docker know the gateway is healthy when /gw-health answers.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:8090/gw-health || exit 1

CMD ["nginx", "-g", "daemon off;"]
