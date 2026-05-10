# TicketBrainy

![Version](https://img.shields.io/badge/version-1.10.1449-blue) ![License](https://img.shields.io/badge/license-Proprietary-red) ![Docker](https://img.shields.io/badge/docker-ready-green)

Self-hosted customer support platform with AI-powered ticket analysis, multi-mailbox management, Keycloak SSO, and a plugin marketplace.

> **Latest version:** `1.10.1449` — see [CHANGELOG.md](CHANGELOG.md) for release notes
>
> **⚠ If your VPS / Caddy install is stuck on Cloudflare 521**, it is
> because v1.10.0–v1.10.1448 shipped without a `caddy` service in the
> compose file (the `install.sh --profile with-proxy` flag was silently
> a no-op). Fix — compose-only, no rebuild needed:
> ```bash
> cd /opt/ticketbrainyApp
> git pull
> docker compose --profile with-proxy up -d
> docker compose logs -f caddy   # watch for "certificate obtained successfully"
> ```
> Let's Encrypt HTTP-01 works through Cloudflare Proxied (orange cloud),
> so you don't need to temporarily flip DNS to DNS-only. See
> [`docs/DEPLOYMENT-MODES.md`](docs/DEPLOYMENT-MODES.md) and
> [`docs/INSTALL.md#16-troubleshooting`](docs/INSTALL.md#16-troubleshooting).

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
# 1. Install Git
sudo apt update && sudo apt install -y ca-certificates curl gnupg git

# 2. Install Docker Engine from Docker's official APT repository
#    (signed with the docker.com GPG key — do NOT pipe `get.docker.com`
#    through `sh`, that runs an unsigned remote script as root).
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
# Log out and log back in (or `newgrp docker`) so group membership applies.

# 3. Clone and run the installer
git clone https://github.com/kr1s57/ticketbrainyApp.git
cd ticketbrainyApp
bash install.sh
```

> **On Debian / RHEL?** The same APT/DNF instructions live at
> [docs.docker.com/engine/install](https://docs.docker.com/engine/install/).
> We deliberately avoid the `curl … | sh` convenience script because it
> bypasses package-manager signature checks and runs as root.

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
>
> **AI CLI provider setup:** [docs/SETTINGS-AI.md](docs/SETTINGS-AI.md)

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
