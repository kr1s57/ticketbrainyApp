# TicketBrainy — Installation Guide

Complete step-by-step guide to deploy TicketBrainy on your server.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Download](#2-download)
3. [Configuration](#3-configuration)
4. [Deploy](#4-deploy)
5. [Activate your license](#5-activate-your-license)
6. [Configure Claude AI](#6-configure-claude-ai)
7. [Reverse Proxy (HTTPS)](#7-reverse-proxy-https)
8. [Keycloak SSO (optional)](#8-keycloak-sso-optional)
9. [Email Setup](#9-email-setup)
10. [Backup & Maintenance](#10-backup--maintenance)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Prerequisites

| Requirement | Minimum | Recommended |
|------------|---------|-------------|
| OS | Ubuntu 22.04+ / Debian 12+ | Ubuntu 24.04 LTS |
| Docker | 24.0+ | Latest stable |
| Docker Compose | v2.20+ | Latest (bundled with Docker) |
| CPU | 2 cores | 4 cores |
| RAM | 4 GB | 8 GB |
| Disk | 10 GB | 50 GB (for attachments) |
| Network | Outbound HTTPS to `license.ticketbrainy.com` | |

### Install Docker (if not installed)

```bash
# Ubuntu / Debian
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Log out and back in, then verify:
docker compose version
```

---

## 2. Download

```bash
git clone https://github.com/kr1s57/ticketbrainyApp.git
cd ticketbrainyApp
```

---

## 3. Configuration

### 3.1 Create your environment file

```bash
cp .env.example .env
```

### 3.2 Generate all secrets

```bash
bash scripts/generate-secrets.sh
```

This automatically generates secure random values for all passwords and tokens:

| Variable | Description | Generation command |
|----------|-------------|-------------------|
| `DB_PASSWORD` | PostgreSQL password | `openssl rand -hex 16` |
| `REDIS_PASSWORD` | Redis auth password | `openssl rand -base64 20` |
| `NEXTAUTH_SECRET` | JWT signing secret | `openssl rand -base64 32` |
| `ENCRYPTION_MASTER_KEY` | AES-256 encryption key for stored credentials | `openssl rand -hex 32` |
| `INTERNAL_SERVICE_TOKEN` | Inter-service auth token | `openssl rand -base64 32` |
| `SEED_ADMIN_PASSWORD` | Initial admin password (first login only) | `openssl rand -base64 12` |
| `KEYCLOAK_CLIENT_SECRET` | Keycloak OIDC client secret | `openssl rand -hex 16` |
| `KC_ADMIN_PASSWORD` | Keycloak admin console password | `openssl rand -base64 12` |

**Save your `SEED_ADMIN_PASSWORD`** — you need it for first login.

### 3.3 Edit your settings

Open `.env` and configure:

```bash
nano .env
```

**Required changes:**

```env
# Your public URL (with https if behind reverse proxy)
APP_URL=https://support.yourcompany.com

# Port exposed on the host
APP_PORT=3000

# LAN IPs that show the local login form (comma-separated)
LAN_HOSTS=192.168.1.100,localhost
```

---

## 4. Deploy

```bash
# Start all services
docker compose up -d

# Watch the logs (first boot takes ~60 seconds)
docker compose logs -f web
```

Wait until you see:

```
web-1  | > Next.js 16.x.x
web-1  | > Ready in XXms
```

### Verify all services are running

```bash
docker compose ps
```

You should see all containers `Up` (except `migrate` which exits after completion).

---

## 5. Activate your license

1. Open your browser: `http://YOUR_SERVER_IP:3000`
2. You'll see the **Activation** page
3. Enter your **license email** (the one registered with your reseller)
4. Click **Activate TicketBrainy**
5. If activation succeeds, you'll be redirected to the login page

### First login

- **Email:** `admin@ticketbrainy.local`
- **Password:** The `SEED_ADMIN_PASSWORD` value from your `.env`

After login, go to **Settings > Team** to change your admin password and create additional users.

### Activation troubleshooting

| Issue | Solution |
|-------|----------|
| "Connection failed" | Ensure outbound HTTPS to `license.ticketbrainy.com` is allowed |
| "Activation failed" | Verify your email is registered — contact your reseller |
| Page not loading | Check `docker compose logs web` for errors |

---

## 6. Configure Claude AI

TicketBrainy uses Claude AI for intelligent ticket analysis. This step requires an **Anthropic API account**.

### 6.1 Install Claude CLI in the running container

```bash
# Enter the web container
docker compose exec -it web sh

# Authenticate Claude CLI
claude login

# Follow the prompts to enter your API key
# Then exit the container
exit
```

### 6.2 Verify AI is working

1. Go to any ticket in TicketBrainy
2. Click **Analyze** (brain icon)
3. The AI analysis should start streaming

If AI features are not needed, skip this step — the rest of the application works without it.

---

## 7. Reverse Proxy (HTTPS)

TicketBrainy runs on HTTP internally. You **must** use a reverse proxy for HTTPS in production.

### Nginx example

```nginx
server {
    listen 443 ssl http2;
    server_name support.yourcompany.com;

    ssl_certificate     /etc/ssl/certs/your-cert.pem;
    ssl_certificate_key /etc/ssl/private/your-key.pem;

    # Important for SSE (AI streaming)
    proxy_buffering off;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Increase timeouts for AI streaming
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    # File uploads (max 10MB)
    client_max_body_size 10M;
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name support.yourcompany.com;
    return 301 https://$server_name$request_uri;
}
```

### Keycloak reverse proxy (if using SSO)

Add a second server block for Keycloak:

```nginx
server {
    listen 443 ssl http2;
    server_name auth.yourcompany.com;

    ssl_certificate     /etc/ssl/certs/your-cert.pem;
    ssl_certificate_key /etc/ssl/private/your-key.pem;

    location / {
        proxy_pass http://127.0.0.1:8180;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
```

Then set in `.env`:

```env
KEYCLOAK_URL=https://auth.yourcompany.com
```

---

## 8. Keycloak SSO (optional)

Keycloak enables Single Sign-On via your existing identity provider (Active Directory, LDAP, etc.).

### Enable Keycloak

1. Edit `.env`:

```env
KEYCLOAK_URL=https://auth.yourcompany.com
KEYCLOAK_REALM=ticketbrainy
KEYCLOAK_CLIENT_ID=ticketbrainy-web
# KEYCLOAK_CLIENT_SECRET was already generated by generate-secrets.sh
```

2. Restart:

```bash
docker compose up -d
```

3. The Keycloak admin console is at: `http://YOUR_SERVER:8180`
   - Username: `admin`
   - Password: `KC_ADMIN_PASSWORD` from your `.env`

### Keycloak user management

- Users created in Keycloak are automatically synced to TicketBrainy on first login
- New Keycloak users require admin activation in **Settings > Team** before they can access TicketBrainy
- You can also manually sync all Keycloak users from **Settings > Team > Sync Keycloak Users**

---

## 9. Email Setup

### Add a mailbox

1. Go to **Mailboxes** in the sidebar
2. Click **Add Mailbox**
3. Fill in:
   - **Name:** Display name (e.g., "Support")
   - **Email:** The email address (e.g., support@yourcompany.com)
   - **IMAP Server:** Your email provider's IMAP server
   - **IMAP Port:** Usually 993 (SSL)
   - **SMTP Server:** Your email provider's SMTP server
   - **SMTP Port:** Usually 587 (STARTTLS) or 465 (SSL)
   - **Username/Password:** Your email credentials

### Microsoft 365 (OAuth)

For M365 mailboxes, use OAuth instead of passwords:

1. Register an app in [Azure Portal](https://portal.azure.com)
2. Set the redirect URI to: `https://support.yourcompany.com/api/mailbox/oauth`
3. In the mailbox settings, switch to **OAuth** and enter your Client ID and Client Secret
4. Click **Connect** to authorize

---

## 10. Backup & Maintenance

### Database backup

```bash
# Create a backup
docker compose exec db pg_dump -U ticketbrainy ticketbrainy > backup_$(date +%Y%m%d).sql

# Restore a backup
docker compose exec -T db psql -U ticketbrainy ticketbrainy < backup_20260401.sql
```

### Application data backup

```bash
# Back up uploads and attachments
docker compose cp web:/data ./data-backup
```

### Update TicketBrainy

```bash
# Pull latest images
docker compose pull

# Restart with new images (migrations run automatically)
docker compose up -d
```

### View logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f web
docker compose logs -f ai-service
docker compose logs -f mail-service
```

---

## 11. Troubleshooting

### Container won't start

```bash
# Check which container failed
docker compose ps

# Read its logs
docker compose logs <service-name>
```

### "Database connection refused"

The database needs ~10 seconds to initialize on first boot. Wait and retry:

```bash
docker compose restart web
```

### "Activation failed"

- Ensure outbound HTTPS to `license.ticketbrainy.com` is not blocked by your firewall
- Verify your email is registered with your reseller

### AI analysis not working

```bash
# Check Claude CLI auth
docker compose exec web claude --version

# Re-authenticate if needed
docker compose exec -it web claude login
```

### Emails not sending/receiving

```bash
# Check mail service logs
docker compose logs mail-service

# Common issues:
# - Wrong IMAP/SMTP credentials
# - Port blocked by firewall
# - Self-signed SSL on mail server (add to trust store)
```

### Reset admin password

```bash
# Enter the web container and use Prisma to reset
docker compose exec web npx prisma db execute --stdin <<'SQL'
UPDATE "User" SET password = '$2a$12$LJ3m4ys3uz0dHjcPHFaKne0WFhPCMxVGPFqFzWEC/xXgTBkzFo9mq' WHERE email = 'admin@ticketbrainy.local';
SQL
# This sets the password to: Admin123!@#
# Change it immediately after login!
```

### Factory reset (delete all data)

```bash
docker compose down -v    # WARNING: Deletes all data permanently
docker compose up -d      # Fresh start
```
