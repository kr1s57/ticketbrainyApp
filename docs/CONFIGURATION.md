# TicketBrainy — Configuration Reference

All environment variables for `.env`, with descriptions and generation commands.

---

## Configuration Table

| Variable | Required | Default | Description | Generation command |
|----------|:--------:|---------|-------------|-------------------|
| **APP_URL** | Yes | `http://localhost:3000` | Public URL (with https if behind proxy) | — |
| **APP_PORT** | No | `3000` | Host port for the web app | — |
| **DB_USER** | No | `ticketbrainy` | PostgreSQL username | — |
| **DB_NAME** | No | `ticketbrainy` | PostgreSQL database name | — |
| **DB_PASSWORD** | Yes | — | PostgreSQL password | `openssl rand -hex 16` |
| **REDIS_PASSWORD** | Yes | — | Redis auth password | `openssl rand -base64 20` |
| **NEXTAUTH_SECRET** | Yes | — | JWT signing secret (32+ bytes) | `openssl rand -base64 32` |
| **ENCRYPTION_MASTER_KEY** | Yes | — | AES-256 key for encrypting stored credentials | `openssl rand -hex 32` |
| **INTERNAL_SERVICE_TOKEN** | Yes | — | Auth token between internal services | `openssl rand -base64 32` |
| **SEED_ADMIN_PASSWORD** | Yes | — | Initial admin password (first run only) | `openssl rand -base64 12` |
| **KEYCLOAK_URL** | No | — | Public Keycloak URL (leave empty to disable SSO) | — |
| **KEYCLOAK_REALM** | No | `ticketbrainy` | Keycloak realm name | — |
| **KEYCLOAK_CLIENT_ID** | No | `ticketbrainy-web` | Keycloak OIDC client ID | — |
| **KEYCLOAK_CLIENT_SECRET** | If SSO | — | Keycloak OIDC client secret | `openssl rand -hex 16` |
| **KC_ADMIN_USER** | No | `admin` | Keycloak admin username | — |
| **KC_ADMIN_PASSWORD** | If SSO | — | Keycloak admin console password | `openssl rand -base64 12` |
| **KC_PORT** | No | `8180` | Keycloak host port | — |
| **KC_DB_SCHEMA** | No | `keycloak` | PostgreSQL schema for Keycloak | — |
| **IMAP_POLL_INTERVAL** | No | `30` | Email check frequency (seconds) | — |
| **OAUTH_REDIRECT_URL** | No | — | Microsoft 365 OAuth callback URL | — |
| **LAN_HOSTS** | No | `localhost` | LAN IPs showing local login form | — |
| **VIGILANCE_KEY_URL** | No | `https://license.ticketbrainy.com` | License server URL (do not change) | — |
| **LOG_LEVEL** | No | `info` | Logging level: `debug`, `info`, `warn`, `error` | — |

---

## Notes

### Secrets generation

All secrets can be generated automatically:

```bash
bash scripts/generate-secrets.sh
```

Or manually one at a time:

```bash
# Strong hex password (32 chars)
openssl rand -hex 16

# Base64 token (44 chars)
openssl rand -base64 32

# AES-256 key (64 hex chars)
openssl rand -hex 32
```

### ENCRYPTION_MASTER_KEY

This key encrypts all stored credentials (IMAP/SMTP passwords, OAuth tokens). **If you lose this key, all stored credentials become unrecoverable.** Back it up securely.

### SEED_ADMIN_PASSWORD

Only used on the **first boot** to create the default admin account (`admin@ticketbrainy.local`). Changing it after first boot has no effect — use the web UI to change passwords.

### Keycloak (SSO)

Leave `KEYCLOAK_URL` empty to use local authentication only. When set, TicketBrainy adds a "Sign in with Keycloak" button on the login page (visible only from LAN_HOSTS addresses).

### Reverse proxy

TicketBrainy expects HTTPS to be terminated at a reverse proxy. The app runs HTTP internally. Set `APP_URL` to your HTTPS URL so cookies and redirects work correctly.

---

## Docker Compose Overrides

To customize service settings, create a `docker-compose.override.yml`:

```yaml
services:
  web:
    # Add resource limits
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: "2"

  db:
    # Expose database port for external tools
    ports:
      - "127.0.0.1:5432:5432"
```

Then start normally — Docker Compose automatically merges the override file:

```bash
docker compose up -d
```
