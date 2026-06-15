# QChain Web Gateway

The single public entry point for the QChain demo. It lets friends and
professors open **two permanent links** and use the live system, while the
heavy backend + blockchain stay on the university VM.

```
Tailscale Funnel  (public https://<vm>.<tailnet>.ts.net, port 443, auto-HTTPS)
        │
        ▼
  web-gateway  (one Nginx container, --network host, listens on :8090)
        ├─  /         →  QPortal web app   (UI_WebApp, built with base-href "/")
        ├─  /wallet/  →  QWallet web app   (UI_App,    built with base-href "/wallet/")
        └─  /api/     →  Go backend         (proxied to 127.0.0.1:3000, /api stripped)
```

Everything is served from **one origin**, so there are no CORS or mixed-content
problems, and there is only one container to keep alive.

## Why this design

- Both frontends are **client-side Flutter apps** — the visitor's browser calls
  the backend directly, so the backend must be public and its URL must be
  **stable**. A Tailscale Funnel address never changes, so we bake it into the
  apps **once** (via `--dart-define=API_BASE_URL=…`, no source edits per URL).
- The Funnel runs under the **`tailscaled` system service**, which already
  auto-restarts on crash and starts on boot and re-applies the Funnel config —
  so the public URL survives reboots with no babysitting (the problem the old
  Cloudflare quick tunnel had).
- We serve **production static builds** (cheap) — not `flutter run` dev servers
  — so the slow VM is barely loaded.

> Port **8090** is used because the IPFS gateway already occupies 8080. Visitors
> never see it — Funnel maps public 443 → localhost:8090.

## Files

| File | Purpose |
|---|---|
| `Dockerfile` | Multi-stage: builds both Flutter web apps, assembles them behind Nginx. |
| `nginx.conf` | The path routing (`/`, `/wallet/`, `/api/`, `/gw-health`). |
| `docker-build.sh` | Builds the image; injects `API_BASE_URL` into the apps. |
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

# Point the apps at your permanent Funnel URL (replace with your real hostname):
export API_BASE_URL="https://<vm>.<tailnet>.ts.net/api"

bash web-gateway/docker-build.sh && bash web-gateway/docker-run.sh
```

The build compiles **both** Flutter web apps, so the first build is slow;
later builds are cached. `docker-build.sh` can auto-derive `API_BASE_URL` from
this node's Tailscale name if you don't set it.

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

Then open in a browser:
- **Portal:** `https://<vm>.<tailnet>.ts.net/`
- **Wallet:** `https://<vm>.<tailnet>.ts.net/wallet/`

## Reboot test (resilience)

Reboot the VM. With Docker enabled on boot (`sudo systemctl enable docker`), the
backend and gateway containers come back (`--restart unless-stopped`), and
`tailscaled` re-applies the Funnel — both links work again **unchanged**, with
no manual steps.

## Changing things

- **Frontend code changed?** Rebuild: `bash web-gateway/docker-build.sh && bash
  web-gateway/docker-run.sh`. URL unchanged.
- **Backend / chaincode / DB changed?** Rebuild the backend as usual. The
  gateway and Funnel are unaffected; the URL is unchanged.
- **You almost never touch `API_BASE_URL`** — it only changes if the VM's
  Tailscale machine name or tailnet changes.
- **Take the site offline:** `tailscale funnel --bg off` (or `tailscale funnel
  reset`).

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `/api/*` returns 502 | Backend not running on :3000. Run `start-demo.sh`. |
| Funnel command fails | Needs sudo, or HTTPS/Funnel not enabled for the node in the admin console, or a different CLI syntax — see the alternatives the script prints. |
| Wallet assets 404 | Image not rebuilt after a wallet change, or base-href mismatch. Rebuild. |
| Apps load but calls fail with the wrong host | Image built with the wrong `API_BASE_URL`. Re-run `docker-build.sh` with the correct value. |
| Port 8090 in use | Another service grabbed it; stop it or change the port in `nginx.conf` + `setup-tailscale-funnel.sh`. |

## Notes

- Access is **open** — anyone with the link can use it. The demo database is
  shared, so testers see each other's test data. `tailscale funnel --bg off`
  disables access instantly.
- The standalone `UI_WebApp/Dockerfile` + `nginx.conf` are left untouched for
  local dev; the gateway is the production-exposure path.
- Upgrade path: if you ever get a domain (or a university subdomain), a
  **Cloudflare Named Tunnel** gives clean `api.` / `portal.` / `wallet.`
  subdomains with no path routing. See `~/Downloads/QChain_Public_Access_Plan.md`.
