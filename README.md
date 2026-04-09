# TicketBrainy

![Version](https://img.shields.io/badge/version-1.10.08-blue) ![License](https://img.shields.io/badge/license-Proprietary-red) ![Docker](https://img.shields.io/badge/docker-ready-green)

Self-hosted customer support platform with AI-powered ticket analysis, multi-mailbox management, Keycloak SSO, and a plugin marketplace.

> **Latest version:** `1.10.08` — see [CHANGELOG.md](CHANGELOG.md) for release notes
>
> **1.10.08 adds a Keycloak admin IP allowlist managed from the UI** (Settings → Security). Separate from the TicketBrainy admin allowlist — this one is enforced by Caddy and protects `/admin/*` and `/realms/master/*` on your Keycloak domain. Saving the list re-renders the Caddyfile and hot-reloads Caddy via its admin API, with zero downtime and no container restart. Survives `docker compose down/up` (re-synced at web boot). **Rolling upgrade (IMPORTANT — includes `git pull` because this release changes the bind-mounted Caddyfile):** `git pull && docker compose --profile with-proxy pull && docker compose --profile with-proxy up -d --force-recreate caddy web migrate`.

## Requirements

### Host

- **Docker** 24+ and **Docker Compose** v2+
- **2 CPU / 4 GB RAM** minimum (8 GB recommended)
- **10 GB** disk space
- Outbound HTTPS access to `license.ticketbrainy.com` (license server)

### DNS & Ports (Caddy mode only — skip if you already have a reverse proxy)

For production exposure with managed HTTPS, you need **two DNS A records**
both pointing at the same VPS public IP:

| Record | Example | Purpose |
|---|---|---|
| `<app-domain>` | `support.example.com` | TicketBrainy UI |
| `<keycloak-domain>` | `auth.example.com` | Keycloak SSO + admin console |

Both records resolve to the same server — Caddy dispatches requests to
the right backend based on the `Host` header. You need them **separate**
because Keycloak's OIDC redirect URIs require it to live on its own
origin (trying to put both on the same hostname breaks the SSO flow).

Required open ports:

| Port | Direction | Why |
|---|---|---|
| 80 | inbound | Let's Encrypt HTTP-01 ACME challenge |
| 443 | inbound | HTTPS traffic (both UI and SSO) |

`install.sh` runs a non-blocking DNS pre-check — if either domain
doesn't resolve to the server yet, it warns you but lets you continue
(Caddy will obtain the cert as soon as DNS propagates).

## Quick Start — Interactive Installer

The fastest way to deploy: use the built-in install script.

```bash
# 1. Install Docker & Git (if not already installed)
sudo apt update && sudo apt install -y ca-certificates curl gnupg git
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Log out and log back in

# 2. Clone and run the installer
git clone https://github.com/kr1s57/ticketbrainyApp.git
cd ticketbrainyApp
bash install.sh
```

The installer will guide you through:
- Server IP and LAN access configuration
- Deployment mode: behind existing reverse proxy **OR** built-in Caddy + Let's Encrypt
- Keycloak SSO setup (optional)
- Automatic secret generation
- Docker image pull and deploy

### Rolling upgrade (existing installs)

Because TicketBrainy bind-mounts files from the repo (`proxy/Caddyfile`,
`keycloak/apply-config.sh`, `docker-compose.yml`, etc.), a plain
`docker compose pull` is **not enough** to pick up config-file
changes in a new release. Always `git pull` first, then pull
images, then recreate the affected containers:

```bash
cd ticketbrainyApp
git pull                                                       # 1. refresh bind-mounted files
docker compose --profile with-proxy pull                       # 2. fetch new images
docker compose --profile with-proxy up -d --force-recreate     # 3. recreate everything
```

If you only recreate `web` (and not `caddy` / `keycloak`), changes
to their bind mounts won't take effect because the containers
keep running with the old mount.

At the end, it prints your admin credentials and next steps.

> **Full manual install guide:** [docs/INSTALL.md](docs/INSTALL.md)
>
> **Keycloak SSO step-by-step guide:** [docs/KEYCLOAK-GUIDE.md](docs/KEYCLOAK-GUIDE.md)

## Deployment Modes

TicketBrainy supports two deployment modes:

### Mode A: Behind your own reverse proxy / WAF
You handle HTTPS, domain, and certificates externally (Nginx, HAProxy, Sophos, Cloudflare, etc.).
The app is exposed on host port **4000** by default (configurable via `APP_PORT` in `.env`). Internally the container listens on 3000.

```bash
docker compose up -d
```

### Mode B: Built-in Caddy + Let's Encrypt
TicketBrainy ships with an optional Caddy reverse proxy that handles HTTPS automatically.
Certificates are obtained and renewed from Let's Encrypt with zero configuration.

```bash
docker compose --profile with-proxy up -d
```

Requires:
- A public domain pointing to your server (A record)
- Ports 80 and 443 open on your firewall
- Email address for Let's Encrypt notifications

## Documentation

| Guide | Description |
|-------|-------------|
| [Installation Guide](docs/INSTALL.md) | Full step-by-step deployment with reverse proxy setup |
| [User Guide](docs/USER-GUIDE.md) | Features, settings, and day-to-day usage |
| [Configuration Reference](docs/CONFIGURATION.md) | All environment variables explained |

## Architecture

```
                    HTTPS
 Users ───────► Reverse Proxy (nginx / WAF)
                     │
                     ▼  HTTP
              ┌──────────────┐
              │   Web App    │ :3000  (Next.js)
              └──────┬───────┘
                     │
         ┌───────────┼───────────┐
         ▼           ▼           ▼
   ┌──────────┐ ┌─────────┐ ┌──────────┐
   │ AI Svc   │ │ Mail Svc│ │ Telegram │
   │ :3001    │ │ (IMAP)  │ │ Bot      │
   └────┬─────┘ └────┬────┘ └────┬─────┘
        │            │            │
        ▼            ▼            ▼
   ┌─────────────────────────────────┐
   │  PostgreSQL 16  │  Redis 7     │
   └─────────────────────────────────┘
              │
              ▼
   ┌──────────────┐
   │  Keycloak    │ :8180  (SSO, optional)
   └──────────────┘
```

## Support

- License & activation: contact your reseller
- Documentation: see the `docs/` folder

## License

TicketBrainy is proprietary software. See [LICENSE](LICENSE) for details.
