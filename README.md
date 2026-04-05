# TicketBrainy

Self-hosted customer support platform with AI-powered ticket analysis, multi-mailbox management, Keycloak SSO, and a plugin marketplace.

## Requirements

- **Docker** 24+ and **Docker Compose** v2+
- **2 CPU / 4 GB RAM** minimum (8 GB recommended)
- **10 GB** disk space
- A domain name with HTTPS (via reverse proxy)
- Outbound HTTPS access to `license.ticketbrainy.com`

## Quick Start

> **Full step-by-step guide with screenshots:** [docs/INSTALL.md](docs/INSTALL.md)

### 1. Install Docker & Git

```bash
# Ubuntu / Debian
sudo apt update && sudo apt install -y ca-certificates curl gnupg git
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Log out and log back in, then verify:
docker compose version
```

### 2. Download & Configure

```bash
git clone https://github.com/kr1s57/ticketbrainyApp.git
cd ticketbrainyApp
cp .env.example .env
bash scripts/generate-secrets.sh    # Generates all passwords automatically
nano .env                           # Set APP_URL to your server IP or domain
```

### 3. Deploy

```bash
docker compose pull                 # Download images (~1.5 GB)
docker compose up -d                # Start all services
docker compose logs -f web          # Wait for "Ready" message, then Ctrl+C
```

### 4. Activate & Login

1. Open `http://YOUR_SERVER_IP:3000` in your browser
2. Enter your license email and click **Activate**
3. Login with `admin@ticketbrainy.local` and the `SEED_ADMIN_PASSWORD` from step 2

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
