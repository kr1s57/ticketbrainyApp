# TicketBrainy

![Version](https://img.shields.io/badge/version-1.10.03-blue) ![License](https://img.shields.io/badge/license-Proprietary-red) ![Docker](https://img.shields.io/badge/docker-ready-green)

Self-hosted customer support platform with AI-powered ticket analysis, multi-mailbox management, Keycloak SSO, and a plugin marketplace.

> **Latest version:** `1.10.03` — see [CHANGELOG.md](CHANGELOG.md) for release notes
>
> **1.10.03 is the third fresh-install hotfix** on top of 1.10.0. Settings → Deployment now actually sees the Caddy / Let's Encrypt configuration on Caddy-mode installs (previously all fields showed empty because the web container wasn't receiving APP_DOMAIN / KEYCLOAK_DOMAIN / LETSENCRYPT_EMAIL), and the activation wizard step 2 now auto-detects the deployment mode from `install.sh`'s env vars so operators don't silently persist `networkExposure=none` on a Caddy deploy. **If you installed v1.10.0 → v1.10.02 and Settings → Deployment shows Caddy disabled or the Security page says "Caddy inactive" even though Caddy is running, upgrade:** `docker compose pull && docker compose up -d`. Already-activated instances with `networkExposure=none` can fix the mode in-place from Settings → Security → Deployment mode.

## Requirements

- **Docker** 24+ and **Docker Compose** v2+
- **2 CPU / 4 GB RAM** minimum (8 GB recommended)
- **10 GB** disk space
- A domain name with HTTPS (via reverse proxy)
- Outbound HTTPS access to `license.ticketbrainy.com`

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
