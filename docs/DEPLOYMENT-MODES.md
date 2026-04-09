# TicketBrainy — Deployment Modes

> **Your deployment topology determines your security posture.**
> Pick the mode that matches your infrastructure, then enable the
> matching security modules in Settings → Security.

## Quick matrix

| Mode | When to use | Managed by you | Managed by TicketBrainy |
|---|---|---|---|
| `none` (LAN-only) | Internal tools, air-gapped deployments | — | — |
| `behind-waf` | You have a Cloudflare, Sophos, F5, or Traefik in front | WAF rules, TLS, geoblock | App-level rate-limit + audit |
| `vps-caddy` | VPS with public IP + domain, no upstream security | DNS, firewall rules | HTTPS via Caddy + Let's Encrypt |
| `vps-naked` | Bringing your own reverse proxy, or testing | Everything upstream | App-level only (use with caution) |

## Mode `none` — LAN-only

**Pre-requisites:**
- Private network (or VPN-only access)
- No port forwarding from public Internet
- Host firewall dropping inbound from 0.0.0.0/0 on port 3000 / 80 / 443

**Recommended security toggles:**
- ✅ Audit logging
- ✅ Magic-bytes validation
- ❌ Upload rate-limit (low traffic, trusted users)
- ❌ Login anomaly detection
- ❌ Admin IP allowlist (everyone is already on the trusted network)

## Mode `behind-waf` — Behind your own WAF/firewall

**Pre-requisites:**
- Upstream WAF/firewall that terminates TLS (or passes it through)
- Trust your upstream's `X-Forwarded-For` header (configure TicketBrainy accordingly)
- Upstream handles geoblock, L7 DDoS, rate-limiting, TLS renewals

**Examples:** Cloudflare Zero Trust, Sophos XGS, F5 BIG-IP, Traefik with `middlewares`, AWS ALB + WAF.

**Recommended security toggles:**
- ✅ Audit logging
- ✅ Magic-bytes validation
- ✅ Login anomaly detection (defense in depth)
- 💡 Admin IP allowlist (optional — your WAF may already do this)
- ❌ Upload rate-limit (WAF should already rate-limit)

## Mode `vps-caddy` — VPS with managed Caddy

**Pre-requisites:**
- Public VPS with IPv4 / IPv6
- Domain name with A/AAAA record pointing at the VPS
- Ports 80 and 443 open to the Internet
- Email address for Let's Encrypt registration

**Activation:** Go to Settings → Deployment → enable Caddy → fill in domain + email → download and apply the generated Caddyfile + docker-compose override.

**Recommended security toggles:**
- ✅ Audit logging
- ✅ Magic-bytes validation
- ✅ Upload rate-limit
- ✅ Login anomaly detection
- 💡 Admin IP allowlist (strongly suggested — your app is Internet-facing)

## Mode `vps-naked` — VPS direct (advanced)

**Warning:** this mode means your TicketBrainy instance is reachable
from the Internet without TLS managed by TicketBrainy. It's intended
for:
- Proof-of-concept installs behind a custom reverse proxy
- Kubernetes deployments where TLS is handled by the Ingress
- Dev/staging installs that are about to be migrated

**DO NOT** run production traffic in this mode unless you fully understand
the implications.

**Recommended security toggles:**
- ✅ Audit logging
- ✅ Magic-bytes validation
- ✅ Upload rate-limit
- ✅ Login anomaly detection
- ⚠️ Admin IP allowlist — **strongly recommended**, configure before exposing the admin routes

## Break-glass procedure (admin IP allowlist lockout)

If you accidentally configure an allowlist that excludes your own IP:

1. SSH into the host running the web container
2. Edit `docker-compose.override.yml` and add to the `web` service:
   ```yaml
   environment:
     SECURITY_ALLOWLIST_BYPASS: "true"
   ```
3. `docker compose up -d web`
4. Open `/settings/security` — the allowlist is now bypassed
5. Fix the CIDR list
6. Remove the `SECURITY_ALLOWLIST_BYPASS` line from `docker-compose.override.yml`
7. `docker compose up -d web` again to restore enforcement

Since v1.10.0 the middleware-layer IP allowlist enforcement is deferred
to the server-actions layer (Next.js 16 nodejs middleware is still
experimental). `SECURITY_ALLOWLIST_BYPASS=true` short-circuits the check
inside `enforceAdminAccess()` so toggles and the Security page become
writable again.

## Keycloak admin client

The Security page calls the Keycloak Admin API via a dedicated read-only
OIDC client called `ticketbrainy-admin-read`. It is created idempotently
on every boot by `keycloak/apply-config.sh` with the scopes:
`view-realm`, `view-users`, `view-events`, `view-identity-providers`.

The client secret is printed in the `aidesk-keycloak-init-1` container
logs on first creation — copy it into your `.env` file:

```bash
docker logs aidesk-keycloak-init-1 2>&1 | grep KC_ADMIN_READ_CLIENT_SECRET
```

Then set in `.env`:
```
KC_ADMIN_READ_CLIENT_ID=ticketbrainy-admin-read
KC_ADMIN_READ_CLIENT_SECRET=<paste the value>
```

Without the secret, the Keycloak Posture Panel will display an amber
"Unable to reach Keycloak" card. Everything else continues to work.

## Keycloak email (password resets, execute-actions-email)

Keycloak's "Send credentials reset email", "Forgot password", and
"Send execute actions email" features all require an SMTP server
configured at the **realm** level. Out of the box, the `ticketbrainy`
realm does **not** include SMTP credentials — we can't ship a working
email relay for everybody.

**If you see** `Failed to send execute actions email: No sender
address configured in the realm settings for emails` in Keycloak
logs, you have two options:

1. **Configure SMTP in the realm** (recommended for any deploy where
   users self-reset passwords):
   - Open `http://<your-server>:8180` → realm `ticketbrainy` →
     **Realm Settings** → **Email** tab
   - Fill in `Host`, `Port`, `From`, and credentials
   - Click **Test connection** — Keycloak will send a test email to
     the admin address
   - Save

2. **Set the password manually** (quick workaround, no email needed):
   - In the Keycloak admin UI, open the user you want to configure
   - Switch to the **Credentials** tab
   - Click **Set password**, enter the password, uncheck "Temporary"
     if you want it to be permanent
   - Save — the user can now log in with that password immediately

This is a Keycloak administration concern, not a TicketBrainy bug —
the app itself never sends email via Keycloak.

## First SSO admin login (TicketBrainy-side)

On a fresh deploy you have two login paths:

- **`admin@ticketbrainy.local` + `SEED_ADMIN_PASSWORD`** — the local
  seed account created by `prisma/seed.ts` and printed by
  `install.sh` at the end of installation. Always available,
  independent of Keycloak. Use this the very first time.

- **Keycloak SSO** — once you have a user in the `ticketbrainy`
  realm, click "Single Sign-On" on the login page. The **first
  successful SSO login is auto-promoted to ADMIN + isActive=true**
  (v1.10.01+), because whoever holds Keycloak realm access is
  trusted to be the intended operator. Every subsequent SSO user
  lands as AGENT and needs manual promotion from Settings → Team.

If you are on a pre-v1.10.01 build and every SSO page throws 403 or
"User not found" — upgrade. The earlier first-admin check was broken
and left SSO users inactive with a half-constructed session.

## What's NOT in phase 1

- **Antivirus scanning of attachments** (ClamAV) — deferred to phase 2 as a premium plugin. Magic-bytes validation catches files lying about their type, but does **not** detect actual malware inside a legitimate PDF. Until the plugin ships, **do not open attachments from unknown senders**.
- **Inbound email SPF/DKIM/DMARC validation** — phase 2 plugin
- **Inbound email spam scoring** — phase 2 plugin
- **Centralised log forwarding** — out of scope (use Docker log drivers)
- **Middleware-layer IP allowlist** — enforced at the server-actions layer instead (see break-glass section). Will move to middleware once Next.js 16 `experimental.nodeMiddleware` is typed in ExperimentalConfig.
