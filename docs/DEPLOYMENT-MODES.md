# Deployment Modes (v1.10.0+)

> **Your deployment topology determines your security posture.**
> Pick the mode that matches your infrastructure, then enable the
> matching security modules in **Settings → Security**.

TicketBrainy supports four explicit deployment modes. You choose one
during the first-run activation wizard at `/activate`, and you can
change it later at **Settings → Security**.

## Quick matrix

| Mode | When to use | Managed by you | Managed by TicketBrainy |
|---|---|---|---|
| `none` (LAN-only) | Internal tools, air-gapped deployments | — | — |
| `behind-waf` | You have a Cloudflare, Sophos, F5, or Traefik in front | WAF rules, TLS, geoblock, L7 DDoS | App-level audit logging |
| `vps-caddy` | VPS with public IP + domain, no upstream security | DNS, firewall rules | HTTPS via Caddy + Let's Encrypt, rate-limit, audit |
| `vps-naked` | You run your own reverse proxy, or testing | Everything upstream | App-level only (use with caution) |

## Mode `none` — LAN-only

**Pre-requisites:**

- Private network (or VPN-only access)
- No port forwarding from public Internet
- Host firewall dropping inbound from `0.0.0.0/0` on ports 3000, 80, 443

**Recommended security toggles:**

- ✅ Audit logging
- ✅ Magic-bytes validation
- ❌ Upload rate-limit (low traffic, trusted users)
- ❌ Login anomaly detection (noisy on small internal teams)
- ❌ Admin IP allowlist (everyone is already on the trusted network)

## Mode `behind-waf` — Behind your own WAF / firewall

**Pre-requisites:**

- Upstream WAF or firewall that terminates TLS (or passes it through)
- TicketBrainy trusts your upstream's `X-Forwarded-For` header
- Upstream handles geoblock, L7 DDoS, rate-limiting, TLS renewals

**Examples:** Cloudflare Zero Trust, Sophos XGS, F5 BIG-IP, Traefik with
middlewares, AWS ALB + WAF, Nginx + ModSecurity.

**Recommended security toggles:**

- ✅ Audit logging
- ✅ Magic-bytes validation
- ✅ Login anomaly detection (defense in depth)
- 💡 Admin IP allowlist (optional — your WAF may already do this)
- ❌ Upload rate-limit (your WAF should already rate-limit uploads)

## Mode `vps-caddy` — VPS with managed Caddy

**Pre-requisites:**

- Public VPS with IPv4 / IPv6
- Domain name with A/AAAA record pointing at the VPS
- Ports 80 and 443 open to the Internet
- Valid email address for Let's Encrypt registration

**Activation:**

```bash
docker compose --profile with-proxy up -d
```

Set the following in your `.env`:

```
APP_DOMAIN=support.your-domain.com
KEYCLOAK_DOMAIN=auth.your-domain.com
LETSENCRYPT_EMAIL=you@your-domain.com
```

Caddy will automatically issue and renew Let's Encrypt certificates
for both domains. The Security page's SSL panel will list them with
the days-until-expiry badge once they are issued.

**Recommended security toggles:**

- ✅ Audit logging
- ✅ Magic-bytes validation
- ✅ Upload rate-limit
- ✅ Login anomaly detection
- 💡 Admin IP allowlist (strongly suggested — your app is Internet-facing)

## Mode `vps-naked` — VPS direct (advanced)

**⚠️ Warning:** This mode means your TicketBrainy instance is reachable
from the Internet without TLS managed by TicketBrainy. It is intended
for:

- Proof-of-concept installs behind a custom reverse proxy (nginx,
  Traefik, HAProxy) that you manage yourself
- Kubernetes deployments where TLS is handled by the Ingress controller
- Dev / staging installs that are about to be migrated to another mode

**DO NOT** run production traffic in this mode unless you fully
understand the implications.

**Recommended security toggles:**

- ✅ Audit logging
- ✅ Magic-bytes validation
- ✅ Upload rate-limit
- ✅ Login anomaly detection
- ⚠️ **Admin IP allowlist — strongly recommended**, configure it BEFORE
  exposing the admin routes

## Break-glass procedure (IP allowlist lockout)

If you accidentally configure an allowlist that excludes your own IP
and can no longer reach `/settings/security` to fix it:

1. SSH into the host running the `web` container
2. Edit your `.env` file and add:
   ```
   SECURITY_ALLOWLIST_BYPASS=true
   ```
3. Recreate the web container:
   ```bash
   docker compose up -d --force-recreate web
   ```
4. Open `/settings/security` — the allowlist is now bypassed
5. Fix the CIDR list in the UI
6. Remove the `SECURITY_ALLOWLIST_BYPASS=true` line from `.env`
7. Recreate the web container once more to restore enforcement:
   ```bash
   docker compose up -d --force-recreate web
   ```

## Keycloak admin-read client

The Security page calls the Keycloak Admin API via a dedicated
read-only OIDC client called `ticketbrainy-admin-read`. It is created
idempotently on every boot by the `keycloak-init` service with the
minimum scopes it needs: `view-realm`, `view-users`, `view-events`,
`view-identity-providers`. No write access.

The client secret is printed **once** in the `keycloak-init` container
logs on first creation. Retrieve it with:

```bash
docker compose logs keycloak-init | grep KC_ADMIN_READ_CLIENT_SECRET
```

Then set it in your `.env`:

```
KC_ADMIN_READ_CLIENT_ID=ticketbrainy-admin-read
KC_ADMIN_READ_CLIENT_SECRET=<paste the value>
```

And recreate the web container:

```bash
docker compose up -d --force-recreate web
```

Without this secret, the **Authentication (Keycloak)** panel on the
Security page will display an amber "Unable to reach Keycloak" error.
Everything else on the page continues to work.

## What is NOT in this release

- **Antivirus scanning of attachments** — magic-bytes validation
  catches files lying about their type (e.g. a `.exe` renamed to
  `.pdf`), but it does **not** detect actual malware inside a
  legitimate PDF. As always, do not open attachments from unknown
  senders without separate virus scanning.
- **SPF / DKIM / DMARC inbound email validation** — planned for a
  future release
- **Spam scoring on inbound email** — planned for a future release
- **Centralised log forwarding** — use Docker's log driver
  (`json-file`, `journald`, `fluentd`, etc.) to ship container logs to
  your SIEM

---

*Added in v1.10.0.*
