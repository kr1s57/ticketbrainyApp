# TicketBrainy

Self-hosted customer support platform with AI-powered ticket analysis, multi-mailbox management, Keycloak SSO, and a plugin marketplace.

## Requirements

- **Docker** 24+ and **Docker Compose** v2+
- **2 CPU / 4 GB RAM** minimum (8 GB recommended)
- **10 GB** disk space
- A domain name with HTTPS (via reverse proxy)
- Outbound HTTPS access to `license.ticketbrainy.com`

## Quick Start

```bash
git clone https://github.com/kr1s57/ticketbrainyApp.git
cd ticketbrainyApp

# 1. Create your environment file
cp .env.example .env

# 2. Generate all secrets automatically
bash scripts/generate-secrets.sh

# 3. Edit your domain and port
nano .env   # Set APP_URL to your public URL

# 4. Launch
docker compose up -d

# 5. Open your browser → http://localhost:3000 (or your APP_URL)
```

On first launch, you'll be prompted to **activate your instance** with your license email.

Default admin login: `admin@ticketbrainy.local` / (password from SEED_ADMIN_PASSWORD in .env)

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
