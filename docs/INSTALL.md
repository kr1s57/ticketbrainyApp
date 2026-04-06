# TicketBrainy — Installation Guide

Complete step-by-step guide to deploy TicketBrainy on your server, from a fresh OS to a running instance.

**Two install paths available:**
- **[Quick install](#quick-install-recommended)** — Interactive `install.sh` script (recommended)
- **[Manual install](#manual-install)** — Step-by-step below

---

## Quick Install (Recommended)

The interactive installer handles everything: Docker check, secret generation, LAN configuration, optional Caddy + Let's Encrypt HTTPS, Keycloak SSO.

```bash
# 1. Install Docker & Git (see step 2 and 3 below if needed)

# 2. Clone and run
git clone https://github.com/kr1s57/ticketbrainyApp.git
cd ticketbrainyApp
bash install.sh
```

The script will ask you:
1. Server LAN IP (auto-detected)
2. Admin PC IP or LAN subnet (CIDR) for local login access
3. License email
4. Deployment mode:
   - **A** — Behind an existing WAF / reverse proxy (you handle HTTPS)
   - **B** — Built-in Caddy + Let's Encrypt (automatic HTTPS)
5. If mode B: public domain name(s)
6. Enable Keycloak SSO? (optional)

At the end, it starts all services and displays your admin credentials.

---

## Manual Install

Follow these steps if you prefer manual configuration or need to customize anything beyond the script's defaults.

## Table of Contents

1. [Server Requirements](#1-server-requirements)
2. [Install Docker & Docker Compose](#2-install-docker--docker-compose)
3. [Install Git](#3-install-git)
4. [Download TicketBrainy](#4-download-ticketbrainy)
5. [Configure Environment](#5-configure-environment)
6. [Firewall Rules](#6-firewall-rules)
7. [Deploy](#7-deploy)
8. [Activate Your License](#8-activate-your-license)
9. [First Login](#9-first-login)
10. [Configure Claude AI (optional)](#10-configure-claude-ai-optional)
11. [Reverse Proxy & HTTPS](#11-reverse-proxy--https)
12. [Keycloak SSO (optional)](#12-keycloak-sso-optional)
13. [Email Setup](#13-email-setup)
14. [Backup & Maintenance](#14-backup--maintenance)
15. [Update TicketBrainy](#15-update-ticketbrainy)
16. [Troubleshooting](#16-troubleshooting)

---

## 1. Server Requirements

| Requirement | Minimum | Recommended |
|------------|---------|-------------|
| **OS** | Ubuntu 22.04 / Debian 12 / RHEL 9 / Rocky 9 | Ubuntu 24.04 LTS |
| **CPU** | 2 cores | 4 cores |
| **RAM** | 4 GB | 8 GB |
| **Disk** | 10 GB free | 50 GB (for email attachments) |
| **Network** | Static IP or FQDN | |
| **Outbound access** | HTTPS to `license.ticketbrainy.com` and `ghcr.io` | |
| **Inbound ports** | 4000 (app), 8180 (Keycloak, if used) | Behind a reverse proxy on 443 |

---

## 2. Install Docker & Docker Compose

Docker Compose v2 is bundled with Docker Engine. You need **Docker Engine 24.0 or newer**.

### Ubuntu / Debian

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install prerequisites
sudo apt install -y ca-certificates curl gnupg

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the Docker repository
# For Ubuntu:
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# For Debian, replace "ubuntu" with "debian" in the line above.

# Install Docker Engine + Compose plugin
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Allow your user to run Docker without sudo
sudo usermod -aG docker $USER
```

**Log out and log back in** for the group change to take effect.

### RHEL / Rocky / AlmaLinux

```bash
# Install prerequisites
sudo dnf install -y dnf-plugins-core

# Add Docker repository
sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo

# Install Docker Engine + Compose plugin
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Allow your user to run Docker without sudo
sudo usermod -aG docker $USER
```

**Log out and log back in** for the group change to take effect.

### Verify installation

```bash
docker --version
# Expected: Docker version 24.x or newer

docker compose version
# Expected: Docker Compose version v2.20.x or newer

# Quick test (should print "Hello from Docker!")
docker run --rm hello-world
```

If `docker compose version` fails, Docker Compose is not installed. Reinstall Docker following the steps above.

---

## 3. Install Git

### Ubuntu / Debian

```bash
sudo apt install -y git
```

### RHEL / Rocky / AlmaLinux

```bash
sudo dnf install -y git
```

### Verify

```bash
git --version
# Expected: git version 2.x.x
```

---

## 4. Download TicketBrainy

```bash
git clone https://github.com/kr1s57/ticketbrainyApp.git
cd ticketbrainyApp
```

Verify the files are there:

```bash
ls -la
# You should see: docker-compose.yml  .env.example  docs/  keycloak/  scripts/  README.md
```

---

## 5. Configure Environment

### 5.1 Create your environment file

```bash
cp .env.example .env
```

### 5.2 Generate all secrets automatically

```bash
bash scripts/generate-secrets.sh
```

This generates secure random values for all passwords and tokens. You will see output like:

```
Generating secure secrets for TicketBrainy...

  DB_PASSWORD          = a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6
  REDIS_PASSWORD       = xYz123AbCdEfGhIjKlMn
  NEXTAUTH_SECRET      = k8Jf2mNpQrStUv...
  ENCRYPTION_MASTER_KEY = 9f8e7d6c5b4a...
  INTERNAL_SERVICE_TOKEN = pL3mN4oP5qR6...
  SEED_ADMIN_PASSWORD  = MyR4nd0mP4ssw0rd
  KEYCLOAK_CLIENT_SECRET = 1a2b3c4d5e6f7a8b
  KC_ADMIN_PASSWORD    = Kc4dm1nP4ss

IMPORTANT: Save SEED_ADMIN_PASSWORD — you need it for first login.
```

**Write down the `SEED_ADMIN_PASSWORD`** — this is your admin login password.

### 5.3 Edit your settings

```bash
nano .env
```

Change these values:

| Variable | What to set | Example |
|----------|------------|---------|
| `APP_URL` | Your server's URL (http for now, https after proxy setup) | `http://192.168.1.50:4000` |
| `APP_PORT` | Port to expose (default 4000) | `4000` |
| `LAN_HOSTS` | Server IP + your workstation IP + localhost (comma-separated) | `192.168.1.50,192.168.1.10,localhost` |

**Important about LAN_HOSTS:**
This controls which IPs see the local login form (email + password). Clients outside this list only see the Keycloak SSO button.

Supported formats (comma-separated):
- **Exact IP:** `192.168.1.10` — a single workstation
- **CIDR subnet:** `192.168.1.0/24` — a whole LAN segment
- **Server IP:** the IP your users type in the URL (e.g., `192.168.1.50`)
- **localhost:** for local access from the server itself

Example configurations:

```env
# Single admin PC + server IP + localhost
LAN_HOSTS=192.168.1.10,192.168.1.50,localhost

# Whole LAN subnet
LAN_HOSTS=192.168.1.0/24,localhost

# Multiple subnets
LAN_HOSTS=192.168.1.0/24,10.0.0.0/16,localhost
```

The check uses the client's real IP (via `X-Forwarded-For` header from your reverse proxy). If no proxy is set, it falls back to matching the host header you typed in your browser.

Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X` in nano).

### 5.4 Verify your .env

```bash
# Check that secrets are filled in (no empty values after =)
grep "^DB_PASSWORD=\|^REDIS_PASSWORD=\|^NEXTAUTH_SECRET=\|^SEED_ADMIN_PASSWORD=" .env
```

Each line should have a value after the `=`. If any is empty, re-run `bash scripts/generate-secrets.sh`.

---

## 6. Firewall Rules

TicketBrainy needs these network rules:

### Inbound (allow from your users)

| Port | Service | Required |
|------|---------|----------|
| **4000** (or APP_PORT) | TicketBrainy web app | Yes |
| **8180** (or KC_PORT) | Keycloak SSO | Only if using SSO |

### Outbound (allow from server)

| Destination | Port | Purpose | Required |
|-------------|------|---------|----------|
| `license.ticketbrainy.com` | 443 (HTTPS) | License activation & validation | Yes |
| `ghcr.io` | 443 (HTTPS) | Docker image downloads | Yes (first install + updates) |
| Your IMAP server | 993 (IMAPS) | Email retrieval | If using email |
| Your SMTP server | 587 or 465 | Email sending | If using email |
| `api.anthropic.com` | 443 (HTTPS) | Claude AI analysis | If using AI features |

### UFW (Ubuntu)

```bash
sudo ufw allow 4000/tcp comment "TicketBrainy"
sudo ufw allow 8180/tcp comment "Keycloak SSO"  # Only if using SSO
```

### firewalld (RHEL/Rocky)

```bash
sudo firewall-cmd --permanent --add-port=4000/tcp
sudo firewall-cmd --permanent --add-port=8180/tcp  # Only if using SSO
sudo firewall-cmd --reload
```

### 6.1 Verify outbound connectivity

Before deploying, verify that your server can reach the license server:

```bash
curl -sk https://license.ticketbrainy.com/api/v1/license/fresh-deploy -X POST -H "Content-Type: application/json" -d '{"email":"test","hardware_id":"test","product":"ticketbrainy"}'
```

You should see a **JSON response** (e.g., `{"success":false,"error":"..."}` or similar).

If you see **HTML** (`<!DOCTYPE...` or `404 Not Found`), the license server is not reachable or its API paths are blocked. Contact your reseller.

If you see **connection timeout**, check your outbound firewall rules for HTTPS (port 443).

---

## 7. Deploy

### 7.1 Pull the Docker images

```bash
docker compose pull
```

This downloads all TicketBrainy images (~1.5 GB total). Wait for it to complete.

If you see "denied" or "unauthorized" errors, the images may not be public yet — contact your reseller.

### 7.2 Start all services

```bash
docker compose up -d
```

### 7.3 Watch the startup

```bash
docker compose logs -f
```

Wait until you see the web service ready:

```
web-1  | > Next.js 16.x.x
web-1  | > Ready in XXms
```

Press `Ctrl+C` to stop following logs.

### 7.4 Verify all services

```bash
docker compose ps
```

Expected output (all `Up`, except `migrate` which shows `Exited (0)`):

```
NAME                  STATUS
ticketbrainyapp-db-1          Up (healthy)
ticketbrainyapp-redis-1       Up (healthy)
ticketbrainyapp-migrate-1     Exited (0)
ticketbrainyapp-keycloak-1    Up
ticketbrainyapp-web-1         Up
ticketbrainyapp-ai-service-1  Up
ticketbrainyapp-mail-service-1 Up
ticketbrainyapp-telegram-bot-1 Up
```

If `migrate` shows `Exited (1)`, check the error:

```bash
docker compose logs migrate
```

### 7.5 Quick test

```bash
curl -s http://localhost:4000/healthz
# Should respond (or redirect to /activate)
```

Or open in your browser: `http://YOUR_SERVER_IP:4000`

---

## 8. Activate Your License

1. Open your browser: `http://YOUR_SERVER_IP:4000`
2. You'll see the **TicketBrainy Activation** page
3. Enter your **license email** (the email registered with your reseller)
4. Click **Activate TicketBrainy**
5. Wait a few seconds — the system contacts the license server
6. On success, you're redirected to the login page

Since 1.3.002, every license response is cryptographically signed. The
activation step fails fast if the license server returns an unsigned
response — that is a security feature, not a bug.

### If activation fails

| Error | Solution |
|-------|----------|
| "Connection failed" | The server cannot reach the license API. Run the connectivity test from [step 6.1](#61-verify-outbound-connectivity) |
| "Activation failed" | Your email is not registered — contact your reseller |
| "License server returned an unsigned response" | Your license server is running an older version that does not support signed envelopes. Contact your reseller to upgrade it. |
| "Signature verification failed" | The license server signed with a key that this TicketBrainy build does not recognise. Make sure you are running TicketBrainy **1.3.002 or later** (`docker compose pull` then restart) and that the license server has not been tampered with. |
| Page doesn't load | Run `docker compose logs web` and check for errors |
| Timeout | Check DNS resolution: `docker compose exec web sh -c 'nslookup license.ticketbrainy.com'` |
| HTML error instead of JSON | The license server API paths may be blocked. Contact your reseller |

### Verify activation from command line

If you want to verify the license server is reachable from inside the container:

```bash
docker compose exec web sh -c 'wget -q -O- "https://license.ticketbrainy.com/api/v1/license/fresh-deploy" 2>&1'
```

A `404 Not Found` (text, not HTML) means the server is reachable (404 is normal for GET — the endpoint expects POST). If you see HTML or a timeout, the connection is blocked.

### Verify the signed licence envelope (1.3.002+)

After activation, every licence row in the local database should carry
a signed envelope. Verify with:

```bash
docker compose exec db psql -U ticketbrainy -d ticketbrainy -c \
  'SELECT "pluginSlug", status, "signingKeyId", ("signedPayload" IS NOT NULL) AS signed FROM "PluginLicense";'
```

Every `active` row should show `signingKeyId=v1` and `signed=t`. If any
row has `signed=f`, open *Settings → Plugins* in the admin UI and click
**Sync** once to re-fetch with signatures.

---

## 9. First Login

After activation, you're on the login page.

| Field | Value |
|-------|-------|
| **Email** | `admin@ticketbrainy.local` |
| **Password** | The `SEED_ADMIN_PASSWORD` from step 5.2 |

### Login page shows only Keycloak (no email/password form)

If you only see a "Sign in with Keycloak" button and no email/password fields:

1. Edit `.env` and make sure `LAN_HOSTS` includes the **IP address you are connecting from** (your workstation IP, not just the server IP):
   ```env
   LAN_HOSTS=SERVER_IP,YOUR_WORKSTATION_IP,localhost
   ```
2. Restart: `docker compose restart web`
3. Refresh the login page

### After first login

1. Go to **Settings > Team**
2. Click on your admin account
3. **Change your password** to something you'll remember
4. Optionally change the admin email to your real email

### Create additional users

1. **Settings > Team > Add Agent**
2. Fill in name, email, password, and role
3. The user can now log in

**Core plan:** Maximum 3 active users. Upgrade to **Enterprise Pack** for unlimited users.

---

## 10. Configure Claude AI (optional)

TicketBrainy uses Claude AI for intelligent ticket analysis (auto-triage, deep analysis, smart reply). This requires the **XpertTeamIA** or **SmartReply AI** plugin and an Anthropic API account.

**Skip this step** if you don't need AI features — the rest of the application works without it.

### 10.1 Get an Anthropic API key

1. Go to [console.anthropic.com](https://console.anthropic.com)
2. Create an account and add a payment method
3. Go to **API Keys** and create a new key

### 10.2 Authenticate Claude in the container

```bash
# Enter the web container
docker compose exec -it web sh

# Run Claude login
claude login

# When prompted, paste your API key
# You should see: "Successfully authenticated"

# Exit the container
exit
```

### 10.3 Verify AI is working

1. Open any ticket in TicketBrainy
2. Click the **Analyze** button (brain icon)
3. You should see the AI analysis streaming in real-time

### 10.4 Troubleshooting AI

```bash
# Check if Claude CLI is installed
docker compose exec web claude --version

# Check AI service logs
docker compose logs ai-service

# Re-authenticate if needed
docker compose exec -it web claude login
```

---

## 11. Reverse Proxy & HTTPS

TicketBrainy runs HTTP internally on port 4000. For production, you **must** set up a reverse proxy with HTTPS.

**Three options available:**
- **Option A** — Built-in Caddy + Let's Encrypt (recommended for self-hosters)
- **Option B** — Nginx (if you already have one)
- **Option C** — Your existing WAF / reverse proxy (Sophos, F5, Cloudflare, etc.)

### Option A: Built-in Caddy (automatic HTTPS)

TicketBrainy ships with an optional Caddy service that handles HTTPS automatically. Certificates from Let's Encrypt are obtained and renewed with zero configuration.

**Prerequisites:**
- A public domain pointing to your server IP (A record)
- Ports **80** and **443** open on your firewall and forwarded to the server
- Email address for Let's Encrypt notifications

**Setup:**

1. Edit `.env` and set the Caddy variables:

```env
APP_URL=https://support.yourcompany.com
APP_DOMAIN=support.yourcompany.com
LETSENCRYPT_EMAIL=admin@yourcompany.com

# If using Keycloak SSO publicly, also set:
KEYCLOAK_URL=https://auth.yourcompany.com
KEYCLOAK_DOMAIN=auth.yourcompany.com
```

2. Start with the `with-proxy` profile:

```bash
docker compose --profile with-proxy up -d
```

Caddy will automatically:
- Obtain HTTPS certificates from Let's Encrypt on first launch
- Renew them every ~60 days before expiration
- Redirect HTTP to HTTPS
- Proxy requests to the web app and Keycloak

**Verify HTTPS:**

```bash
curl -I https://support.yourcompany.com
# Should return: HTTP/2 200 (or redirect to /login)
```

**View Caddy logs:**

```bash
docker compose --profile with-proxy logs caddy
```

### Option B: Nginx

#### Install Nginx

```bash
# Ubuntu / Debian
sudo apt install -y nginx

# RHEL / Rocky
sudo dnf install -y nginx
sudo systemctl enable nginx
```

#### Configure Nginx

```bash
sudo nano /etc/nginx/sites-available/ticketbrainy
```

Paste:

```nginx
server {
    listen 443 ssl http2;
    server_name support.yourcompany.com;

    ssl_certificate     /etc/ssl/certs/your-cert.pem;
    ssl_certificate_key /etc/ssl/private/your-key.pem;

    # Disable proxy buffering (required for AI streaming / SSE)
    proxy_buffering off;

    location / {
        proxy_pass http://127.0.0.1:4000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Timeouts for AI streaming
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    # File upload limit
    client_max_body_size 10M;
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name support.yourcompany.com;
    return 301 https://$server_name$request_uri;
}
```

Enable and restart:

```bash
sudo ln -s /etc/nginx/sites-available/ticketbrainy /etc/nginx/sites-enabled/
sudo nginx -t          # Test configuration
sudo systemctl restart nginx
```

#### Update APP_URL

```bash
nano .env
# Change: APP_URL=https://support.yourcompany.com
```

Restart TicketBrainy:

```bash
docker compose up -d
```

### Option C: Existing reverse proxy / WAF

If you already have a reverse proxy (Apache, HAProxy, Sophos, Fortinet WAF, etc.):

1. Point it to `http://YOUR_SERVER_IP:4000`
2. Enable WebSocket passthrough (for real-time updates)
3. **Disable response buffering** (required for AI streaming / SSE)
4. Set `X-Forwarded-Proto: https` header
5. Update `APP_URL` in `.env` to your HTTPS URL

### Keycloak reverse proxy (only if using SSO)

If you use Keycloak SSO, also proxy port 8180:

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

Then update `.env`:

```env
KEYCLOAK_URL=https://auth.yourcompany.com
```

---

## 12. Keycloak SSO (optional)

Keycloak enables Single Sign-On. Your users can log in with their existing Active Directory, LDAP, or other identity provider credentials.

**Skip this section** if you only need local authentication (email + password).

### Enable Keycloak

1. Edit `.env`:

```env
KEYCLOAK_URL=https://auth.yourcompany.com   # or http://YOUR_IP:8180 for testing
KEYCLOAK_REALM=ticketbrainy
KEYCLOAK_CLIENT_ID=ticketbrainy-web
# KEYCLOAK_CLIENT_SECRET was already generated by generate-secrets.sh
```

2. Restart:

```bash
docker compose up -d
```

3. Access the Keycloak admin console: `http://YOUR_SERVER:8180`
   - **Username:** `admin`
   - **Password:** The `KC_ADMIN_PASSWORD` from your `.env`

### Connect to Active Directory / LDAP

1. In Keycloak admin: **Realm settings > User Federation**
2. Add your LDAP or Active Directory provider
3. Configure the connection URL, bind DN, and user search base
4. Click **Synchronize all users**

### User management rules

- Users who log in via Keycloak for the first time are created as **inactive** agents
- An admin must activate them in **Settings > Team** before they can access TicketBrainy
- You can sync all Keycloak users at once: **Settings > Team > Sync Keycloak Users**
- **Core plan:** Max 3 active users (Keycloak + local combined). Upgrade to Enterprise Pack for unlimited.

---

## 13. Email Setup

### Add a mailbox

1. Go to **Mailboxes** in the sidebar
2. Click **Add Mailbox**
3. Fill in the fields:

| Field | Description | Example |
|-------|-------------|---------|
| **Name** | Display name | `Support` |
| **Email** | Email address to monitor | `support@yourcompany.com` |
| **IMAP Server** | Your mail server (incoming) | `imap.yourprovider.com` |
| **IMAP Port** | Usually 993 (SSL) | `993` |
| **SMTP Server** | Your mail server (outgoing) | `smtp.yourprovider.com` |
| **SMTP Port** | Usually 587 (STARTTLS) or 465 (SSL) | `587` |
| **Username** | Email account username | `support@yourcompany.com` |
| **Password** | Email account password | (your password) |

4. Click **Save**
5. TicketBrainy will start polling for emails every 30 seconds

**Core plan:** Maximum 1 mailbox. Upgrade to **Enterprise Pack** for unlimited mailboxes.

### Microsoft 365 (OAuth)

For M365 mailboxes, use OAuth instead of passwords:

1. Go to [Azure Portal](https://portal.azure.com) > **App registrations > New registration**
2. Name: `TicketBrainy`
3. Redirect URI: `https://support.yourcompany.com/api/mailbox/oauth`
4. Under **API permissions**, add:
   - `IMAP.AccessAsUser.All`
   - `SMTP.Send`
   - `offline_access`
5. Under **Certificates & secrets**, create a client secret
6. In TicketBrainy mailbox settings, switch to **OAuth** tab
7. Enter your **Client ID** and **Client Secret**
8. Click **Connect** — you'll be redirected to Microsoft to authorize

### Test email

1. Send a test email to your mailbox address from an external account
2. Wait 30 seconds (or the configured `IMAP_POLL_INTERVAL`)
3. A new ticket should appear in TicketBrainy
4. Reply to the ticket — the customer should receive your reply by email

---

## 14. Backup & Maintenance

### Database backup

```bash
# Create a backup
docker compose exec db pg_dump -U ticketbrainy ticketbrainy > backup_$(date +%Y%m%d).sql

# Restore from backup
docker compose exec -T db psql -U ticketbrainy ticketbrainy < backup_20260401.sql
```

### Application data backup (uploads, attachments)

```bash
# Copy data out of the container
docker compose cp web:/data ./data-backup-$(date +%Y%m%d)
```

### Recommended backup schedule

| What | How often | Command |
|------|-----------|---------|
| Database | Daily | `docker compose exec db pg_dump -U ticketbrainy ticketbrainy > backup.sql` |
| Uploads/attachments | Weekly | `docker compose cp web:/data ./data-backup` |
| `.env` file | After any change | `cp .env .env.backup` |

### View logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f web
docker compose logs -f ai-service
docker compose logs -f mail-service
docker compose logs -f keycloak
```

### Restart a service

```bash
docker compose restart web
docker compose restart mail-service
```

### Stop everything

```bash
docker compose down       # Stop all containers (data is preserved)
docker compose up -d      # Start again
```

---

## 15. Update TicketBrainy

```bash
cd ticketbrainyApp

# Pull latest images
docker compose pull

# Restart (migrations run automatically)
docker compose up -d

# Verify
docker compose ps
```

Updates include new features, bug fixes, and security patches. Database migrations are applied automatically by the `migrate` container.

### Updating to 1.3.002 (signed license envelopes)

1.3.002 is a **critical security update**. After `docker compose pull && docker compose up -d`, do this once:

1. Open *Settings → Plugins* in the admin UI.
2. Click **Sync**.

This re-fetches all your licenses with cryptographic signatures so
premium features stay enabled. Between the restart and your Sync click,
premium pages will temporarily show as locked — this is expected.

Verify the update:

```bash
# Check the installed version
docker compose exec web cat apps/web/package.json | grep version
# expected: "version": "1.3.002"

# Check that rows have signed envelopes
docker compose exec db psql -U ticketbrainy -d ticketbrainy -c \
  'SELECT "pluginSlug", ("signedPayload" IS NOT NULL) AS signed FROM "PluginLicense";'
# every row should show signed=t
```

If any row still shows `signed=f` after clicking Sync, see [*Troubleshooting*](#16-troubleshooting) below.

---

## 16. Troubleshooting

### Container won't start

```bash
# See which container failed
docker compose ps

# Read its logs
docker compose logs <service-name>

# Common fix: restart
docker compose restart <service-name>
```

### "Database connection refused"

The database takes ~10 seconds to initialize on first boot.

```bash
# Wait and restart
docker compose restart web
```

### "Activation failed"

1. Check outbound HTTPS: `curl -I https://license.ticketbrainy.com`
2. If blocked, configure your firewall or proxy (see [Firewall Rules](#6-firewall-rules))
3. If the URL resolves but activation fails, your email may not be registered — contact your reseller

### Web app shows blank page

```bash
# Check web logs
docker compose logs web

# Restart web
docker compose restart web
```

### AI analysis not working

```bash
# Check AI service
docker compose logs ai-service

# Verify Claude is authenticated
docker compose exec web claude --version

# Re-authenticate
docker compose exec -it web claude login
```

### Emails not sending/receiving

```bash
# Check mail service logs
docker compose logs mail-service
```

Common issues:
- Wrong IMAP/SMTP credentials — verify in mailbox settings
- Port blocked by firewall — ensure 993/587 outbound is open
- Self-signed certificate — add your CA to the container trust store

### Reset admin password

If you forgot the admin password:

```bash
docker compose exec -T db psql -U ticketbrainy ticketbrainy -c "UPDATE \"User\" SET password = '\$2a\$12\$LJ3m4ys3uz0dHjcPHFaKne0WFhPCMxVGPFqFzWEC/xXgTBkzFo9mq' WHERE email = 'admin@ticketbrainy.local';"
```

This resets the password to: `Admin123!@#` — change it immediately after login.

### Factory reset (delete ALL data)

```bash
docker compose down -v    # WARNING: This permanently deletes all data
docker compose up -d      # Fresh start — you'll need to re-activate
```

### Get support

If the issue persists, collect the logs and contact your reseller:

```bash
docker compose logs > ticketbrainy-logs-$(date +%Y%m%d).txt 2>&1
```
