# QChain Web Gateway

The public entry point for QPortal. It lets friends and professors open **one
permanent link** and use the live portal, while the heavy backend + blockchain
stay on the university VM.

QWallet is not part of this image — it ships as a mobile install only, built
and distributed separately by the team member who owns the wallet app. See
`Dockerfile` for why a web build isn't possible (the wallet's PQC library
can't compile for web at all).

```
Tailscale Funnel  (public https://<vm>.<tailnet>.ts.net, port 443, auto-HTTPS)
        │
        ▼
  web-gateway  (one Nginx container, --network host, listens on :8090)
        ├─  /      →  QPortal web app   (UI_WebApp, built with base-href "/")
        └─  /api/  →  Go backend         (proxied to 127.0.0.1:3000, /api stripped)
```

Everything is served from **one origin**, so there are no CORS or mixed-content
problems, and there is only one container to keep alive.

## Why this design

- QPortal is a **client-side Flutter app** — the visitor's browser calls the
  backend directly, so the backend must be public and its URL must be
  **stable**. A Tailscale Funnel address never changes, so we bake it into the
  app **once** (via `--dart-define=API_BASE_URL=…`, no source edits per URL).
- The Funnel runs under the **`tailscaled` system service**, which already
  auto-restarts on crash and starts on boot and re-applies the Funnel config —
  so the public URL survives reboots with no babysitting (the problem the old
  Cloudflare quick tunnel had).
- We serve a **production static build** (cheap) — not a `flutter run` dev
  server — so the slow VM is barely loaded.

> Port **8090** is used because the IPFS gateway already occupies 8080. Visitors
> never see it — Funnel maps public 443 → localhost:8090.

## Files

| File | Purpose |
|---|---|
| `Dockerfile` | Builds the QPortal web app, assembles it behind Nginx. |
| `nginx.conf` | The path routing (`/`, `/api/`, `/gw-health`). |
| `docker-build.sh` | Builds the image; injects `API_BASE_URL` into the app. |
| `docker-run.sh` | Runs the container (`--network host --restart unless-stopped`). |
| `../.dockerignore` | Keeps the root build context small (the build runs from the repo root). |
| `../qchain-network/scripts/setup-tailscale-funnel.sh` | One-time: exposes :8090 publicly via Funnel. |

## One-time setup (on the VM)

1. **Install + connect Tailscale**, and in the admin console
   (<https://login.tailscale.com/admin/>) enable **HTTPS certificates** for your
   tailnet and **Funnel** for this node:
   ```bash
   sudo tailscale up            # gives the VM a name → https://<name>.<tailnet>.ts.net
   tailscale status             # note the machine's full *.ts.net name
   ```

2. **Make sure the backend is running** (the gateway proxies `/api` to it):
   ```bash
   bash qchain-network/scripts/start-demo.sh    # backend on :3000, IPFS, peers
   ```

## Build & run (on the VM)

```bash
git pull origin main

# Point the app at your permanent Funnel URL (replace with your real hostname):
export API_BASE_URL="https://<vm>.<tailnet>.ts.net/api"

bash web-gateway/docker-build.sh && bash web-gateway/docker-run.sh
```

The first build is slow (a Flutter web compilation); later builds are cached.
`docker-build.sh` can auto-derive `API_BASE_URL` from this node's Tailscale
name if you don't set it.

Then expose it publicly (one time):

```bash
bash qchain-network/scripts/setup-tailscale-funnel.sh
```

## Verify

```bash
# Local
curl -s http://localhost:8090/gw-health        # → ok
curl -s http://localhost:8090/api/health       # → {"status":"ok"}

# Public (replace the host)
curl -s https://<vm>.<tailnet>.ts.net/gw-health     # → ok
curl -s https://<vm>.<tailnet>.ts.net/api/health    # → {"status":"ok"}
tailscale funnel status                              # shows 443 → localhost:8090
```

Then open in a browser: `https://<vm>.<tailnet>.ts.net/`

## Reboot test (resilience)

Reboot the VM. With Docker enabled on boot (`sudo systemctl enable docker`), the
backend and gateway containers come back (`--restart unless-stopped`), and
`tailscaled` re-applies the Funnel — the link works again **unchanged**, with
no manual steps.

## Changing things

- **QPortal code changed?** Rebuild: `bash web-gateway/docker-build.sh && bash
  web-gateway/docker-run.sh`. URL unchanged.
- **Backend / chaincode / DB changed?** Rebuild the backend as usual. The
  gateway and Funnel are unaffected; the URL is unchanged — a friend's locally
  built image with your `API_BASE_URL` stays valid regardless of how often the
  backend redeploys, since the gateway just proxies to a fixed local address.
- **QWallet code changed?** Not this image's concern — rebuilt and shipped
  separately as a mobile app.
- **You almost never touch `API_BASE_URL`** — it only changes if the VM's
  Tailscale machine name or tailnet changes.
- **Take the site offline:** `tailscale funnel --bg off` (or `tailscale funnel
  reset`).

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `/api/*` returns 502 | Backend not running on :3000. Run `start-demo.sh`. |
| Funnel command fails | Needs sudo, or HTTPS/Funnel not enabled for the node in the admin console, or a different CLI syntax — see the alternatives the script prints. |
| Apps load but calls fail with the wrong host | Image built with the wrong `API_BASE_URL`. Re-run `docker-build.sh` with the correct value. |
| Port 8090 in use | Another service grabbed it; stop it or change the port in `nginx.conf` + `setup-tailscale-funnel.sh`. |

## Notes

- Access is **open** — anyone with the link can use it. The demo database is
  shared, so testers see each other's test data. `tailscale funnel --bg off`
  disables access instantly.
- The standalone `UI_WebApp/Dockerfile` + `nginx.conf` are left untouched for
  local dev; the gateway is the production-exposure path.
- Upgrade path: if you ever get a domain (or a university subdomain), a
  **Cloudflare Named Tunnel** gives a clean `api.` / `portal.` subdomain split
  with no path routing. See `~/Downloads/QChain_Public_Access_Plan.md`.
