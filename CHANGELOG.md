# Changelog

All notable releases of TicketBrainy.

## [1.10.1443] — 2026-04-11

### Added — Ticket Notifications

- **Toast alerts** — when a new ticket arrives or a customer replies, a
  toast notification appears in the top-right corner with the ticket title
  and a "Voir" button to jump straight to the ticket.
- **Bell badge** — the notification bell in the header now shows real-time
  unread count that updates every 30 seconds (aligned with IMAP polling).
- **Smart routing** — new tickets notify all admins and supervisors;
  customer replies notify the assigned agent (or admins if unassigned).

### Upgrade

```bash
cd /opt/ticketbrainyApp
git pull
docker compose pull
docker compose up -d --force-recreate
```

## [1.10.1442] — 2026-04-11

### Added — Email Authentication Badges + Attachment Warning

- **SPF / DKIM / DMARC badges** — every inbound email message now displays
  3 small colour-coded badges showing the authentication status of the
  sender's email server. Green = pass, red = fail, grey = not available.
  Tooltips explain what each protocol checks. Visible to all roles.
- **Attachment warning badge** — if the magic-bytes scan detects that a
  file's content does not match its declared extension (e.g., an `.exe`
  disguised as `.pdf`), an orange "Suspect" badge appears next to the
  attachment filename with the detection reason in a tooltip.
- **Purely informational** — no emails are blocked, no attachments are
  rejected. The badges help agents assess email legitimacy at a glance.

### Upgrade

```bash
cd /opt/ticketbrainyApp
git pull
docker compose pull
docker compose up -d --force-recreate
```

## [1.10.144] — 2026-04-11

### Added — Multilanguage Support (Spanish, Italian, German)

TicketBrainy now supports 5 languages: English, French, Spanish, Italian,
and German. Users choose their language in Settings → Language.

- **i18n architecture refactored** — the monolithic 137 KB translations
  file is now split into per-language files (`locales/{en,fr,es,it,de}.ts`),
  improving maintainability and git diff readability
- **1358 keys translated** into each new language via AI, with automatic
  English fallback for any approximate translations
- **Date formatting localised** — all dates throughout the application
  (analytics charts, reports, ticket timestamps) now format in the user's
  chosen language instead of hardcoded French/English
- **Default language:** English (unchanged). Each operator can switch in
  Settings → Language

### Upgrade

```bash
cd /opt/ticketbrainyApp
git pull
docker compose pull
docker compose up -d --force-recreate
```

No schema migration — locale is stored client-side in localStorage.

## [1.10.143] — 2026-04-11

### Added — System Clock Diagnostic

New card in Settings → General showing real-time system clock status:
server time, timezone, UTC offset, database time, and clock drift
between Node.js and PostgreSQL. Drift alerts at 2s (warning) and
5s (critical) — important for Keycloak token validation.

New CLI script `scripts/configure-time.sh` for interactive timezone
and NTP management via SSH (show status, change timezone, force NTP
sync, configure NTP server).

### Upgrade

```bash
cd /opt/ticketbrainyApp
git pull
docker compose pull
docker compose up -d --force-recreate
```

## [1.10.142] — 2026-04-11

### Added — Rate-Limit UI + Analytics Deltas + Telegram Security Alerts + Draft Cleanup

#### Rate-Limit Configuration UI

New page under Settings → Deploy & Security → Rate Limits. Operators can
now adjust the 6 rate-limit presets (login, AI, CSAT, upload, activate)
from the UI instead of hardcoded values. Each preset can be enabled/disabled,
with configurable max requests and window duration. Changes stored in
`SecuritySettings.rateLimitConfig` JSON with 60-second cache.

#### Analytics Period Comparison

KPI cards on the Overview and SLA tabs now show comparison deltas (▲/▼)
against the previous period. For example, if viewing 30 days, the delta
compares against the 30 days before that. Response time deltas use
inverted colors (green when faster). CSAT already had this feature.

#### Telegram Security Alerts

Real-time security event notifications via Telegram. The bot now
subscribes to a `security:alert` Redis channel and sends formatted
alerts for: honeypot hits, IP auto-blocks, geo-blocks, and auth
failures (3+ in 5min from same IP). Each alert includes inline
keyboard buttons to mute by event type (1h/6h/24h/permanent) or
by IP. Mute configuration stored in the Setting table. Four new
routing toggles added to Settings → Telegram.

#### Draft Cleanup Scheduler

New scheduler in the mail-service that runs every 6 hours and
hard-deletes draft messages (`isDraft=true`) older than 48 hours.
Prevents abandoned drafts from accumulating in the database.

### Upgrade

```bash
cd /opt/ticketbrainyApp
git pull
docker compose pull
docker compose up -d --force-recreate
```

No schema migration — all features use existing tables.

## [1.10.141] — 2026-04-11

### Added — Security Dashboard + Reports v2

#### Security Dashboard

New page under Settings → Deploy & Security → Dashboard showing real-time
security metrics:

- **KPI row:** Events (24h), Blocked IPs, Blocked Countries, Honeypot Hits
- **Event timeline:** Stacked area chart showing security events by hour
  (auth failures, geo blocks, honeypot hits, IP auto-blocks)
- **Top blocked IPs:** Table with reason, hit count, expiration, country
- **Top blocked countries:** Horizontal bar chart (requires Geo Block)
- **Critical events feed:** Last 20 danger-severity events

No license required — operational security feature available to all.

#### Reports v2 — Statistiques refondues

The sidebar is consolidated: a single "Statistiques" item replaces the
former "Statistiques" + "Rapports" entries. The analytics section now
uses internal tab navigation with four tabs:

- **Vue d'ensemble** — existing dashboard with a new period selector
  (7 days / 30 days / 90 days) replacing the hardcoded 30-day view
- **SLA** — new tab with SLA compliance metrics: compliance by priority,
  breach trend, response time distribution histogram, resolution time
  distribution histogram, and tickets-in-breach table
- **Satisfaction** — new tab with CSAT analytics: average score, star
  distribution, trend over time, top agents by satisfaction, and
  lowest-rated tickets
- **Rapports** — existing reports table, now integrated as a tab

All analytics tabs require Enterprise Pack license.

#### Feature gating fix

The reports page now checks `analytics_reports` (not `analytics_dashboard`)
for its feature gate, matching the Enterprise Pack feature registry.

### Upgrade

```bash
cd /opt/ticketbrainyApp
git pull
docker compose pull
docker compose up -d --force-recreate
```

No schema migration in this release — all features use existing tables
(AuditLog, IpBlocklist, SecuritySettings, Ticket, SlaPolicy, CsatResponse).

## [1.10.14] — 2026-04-10

### Added — Settings restructure + Geo Block + security hardening Phase 2

This release reorganises the Settings menu around a new top-level
"Deploy & Security" section, introduces the **Geo Block** feature
that lets operators block or allow access by country at the
application layer, and ships several Phase 2 security hardenings
recommended by the v1.10.131 pentest follow-up.

#### Settings menu restructure

The "General" tab no longer mixes deployment + security with the
unrelated configuration items (language, notifications, tags, …).
A new top-level tab **Deploy & Security** sits between General and
Workspace and groups the security-relevant pages:

- **Mode** — network exposure mode + Keycloak posture + rate-limit
  posture + SSL certificate panel + the Caddy/HTTPS deployment form
  (former /settings/deployment + the top section of /settings/security)
- **Whitelist** — admin and Keycloak admin IP allowlists, each with
  its own form and audit trail
- **Audit** — the four security toggles (audit log, upload rate
  limit, magic bytes, login anomaly) and the live audit log feed
- **Geo Block** — new feature, see below

The legacy `/settings/deployment` and `/settings/security` URLs
continue to work — they redirect to `/settings/deploy-security/mode`
to preserve operator bookmarks.

#### Geo Block — country-based access control

A new feature under `/settings/deploy-security/geo-block` lets the
operator block or allow visitors based on their country of origin.
The lookup is powered by the `CF-IPCountry` header injected by
Cloudflare on every proxied request (~99.9% accuracy). Cloudflare
free plan is sufficient. The policy is hot-reloadable from the UI
without restarting any container.

> **Cloudflare (free plan) is required** for Geo Block to work.
> See [docs/cloudflare-setup.md](docs/cloudflare-setup.md) for
> step-by-step instructions (3 scenarios: VPS+Caddy, behind WAF,
> WAF without Cloudflare via `X-Country-Code` header).
>
> The previous GeoLite2 MMDB approach was removed — the free MaxMind
> database misclassified too many European IPs (Luxembourg resolved
> as FR/DE/US), making the feature unreliable in production.

Two modes:
- **Denylist** — allow everyone except listed countries (e.g. block
  RU, KP, IR but accept the rest of the world)
- **Allowlist** — block everyone except listed countries (e.g.
  accept only FR, BE, CH, LU, MC for a French-speaking SaaS)

Self-lockout protection: when the operator enables Geo Block from
the UI, the server detects their own country from the request IP
and automatically adjusts the lists so they don't block themselves
on the next page load. The "Test" widget on the same page lets
them simulate access from any country before saving.

Always-exempt paths (cannot be geo-blocked):
- Health check endpoints
- OIDC callback URLs (/api/auth/*)
- Stripe webhooks (/api/stripe/webhook — Stripe IPs are global)
- Public CSAT surveys (/api/csat/public/* — customer feedback
  must remain reachable from anywhere)

Every blocked request emits an `AuditLog` event of type `GEO_BLOCK`,
with the country, IP, and path stored in the metadata for forensic
review. The Geo Block page surfaces a 24-hour stats widget with the
top blocked countries.

Tech notes for operators upgrading:
- Geo Block requires Cloudflare proxy (orange cloud) enabled on your
  DNS records. Without the `CF-IPCountry` header, the feature is
  disabled and the UI shows a red "Cloudflare requis" banner.
- Operators behind a WAF without Cloudflare can configure their WAF
  to inject `X-Country-Code` as an alternative (see cloudflare-setup.md).
- Schema migration adds `geoBlockEnabled`, `geoBlockMode`,
  `geoBlockCountries`, `geoBlockSetAt`, `geoBlockSetBy` to
  `SecuritySettings`. Default `geoBlockEnabled=false`, so the
  feature is opt-in and existing installs see no behaviour change
  until they activate it from the UI.

#### Honeypot routes + auto-blocklist (Phase 2 hardening)

Real TicketBrainy users never access `/wp-admin`, `/wp-login.php`,
`/.env`, `/.git/HEAD`, `/phpmyadmin`, `/administrator`, `/admin.php`,
or other common scanner paths — those are exclusively probed by
automated attack tools.

Each hit on one of these paths now:
1. Returns a generic 404 (so the attacker doesn't know they
   tripped a trap)
2. Records an `AuditLog` event of type `HONEYPOT_HIT` with the
   probed path, source IP, and User-Agent
3. Adds the source IP to a new `IpBlocklist` table with reason
   `honeypot`, expiring after `honeypotBlockDurationHours`
   (default 24h, configurable in `SecuritySettings`)

Subsequent requests from the same IP are then rejected by
`enforceAccess()` — the dashboard layout check that runs before
any other authorization. This means a single hit on `/wp-admin`
shuts the attacker out of the entire instance for 24 hours.

Schema migration adds the `IpBlocklist` table and the
`honeypotEnabled` + `honeypotBlockDurationHours` columns to
`SecuritySettings`. Honeypots are enabled by default — there's
no downside.

#### CSP nonce strict (Phase 2 hardening)

The previous Content-Security-Policy header included
`'unsafe-inline'` on `script-src`, which the v1.10.131 pentest
correctly flagged as a regression vector for any XSS that might
land in a future code change. v1.10.14 replaces it with a strict
nonce-based policy.

The middleware now:
1. Generates a fresh 16-byte random nonce for every HTML request
2. Sets it on a request header (`x-nonce`) so Server Components
   can read it via `headers().get('x-nonce')`
3. Emits a Content-Security-Policy header with
   `'nonce-XXXX' 'strict-dynamic'` on `script-src`

`'unsafe-inline'` is kept as a legacy fallback for browsers that
don't support `'strict-dynamic'` (Chrome ≤59, Firefox ≤58, Safari
≤15.4 — every modern browser ignores it when a valid nonce is
present, per the W3C CSP3 spec).

`style-src` keeps `'unsafe-inline'` because Tailwind and shadcn
inject style attributes at runtime that can't be nonced.

#### `/.well-known/security.txt` (RFC 9116)

A standard `security.txt` file is now served at
`https://your-instance.example/.well-known/security.txt` with the
TicketBrainy security contact email and disclosure policy URL.
This is a small but well-documented signal to security researchers
that you have a coordinated disclosure process — and it's expected
by most bug bounty platforms and audit checklists.

#### Plugins page — license fingerprint for support

The license display on the Plugins page now shows the first and
last 4 characters of both the license key and the hardware ID
(middle masked with `…`). Allows support to identify the active
license without leaking enough material to clone it. The full key
never leaves the server.

### Schema migration

```sql
-- New columns on SecuritySettings
ALTER TABLE "SecuritySettings"
  ADD COLUMN "geoBlockEnabled"            BOOLEAN  DEFAULT false NOT NULL,
  ADD COLUMN "geoBlockMode"               TEXT     DEFAULT 'denylist' NOT NULL,
  ADD COLUMN "geoBlockCountries"          TEXT[]   DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN "geoBlockSetAt"              TIMESTAMP(3),
  ADD COLUMN "geoBlockSetBy"              TEXT,
  ADD COLUMN "honeypotEnabled"            BOOLEAN  DEFAULT true NOT NULL,
  ADD COLUMN "honeypotBlockDurationHours" INTEGER  DEFAULT 24 NOT NULL,
  ADD COLUMN "rateLimitConfig"            JSONB;

-- New table
CREATE TABLE "IpBlocklist" (
  id        TEXT PRIMARY KEY,
  ip        TEXT NOT NULL UNIQUE,
  reason    TEXT NOT NULL,
  source    TEXT,
  "expiresAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) DEFAULT NOW() NOT NULL,
  metadata  JSONB
);
CREATE INDEX "IpBlocklist_expiresAt_idx" ON "IpBlocklist"("expiresAt");
CREATE INDEX "IpBlocklist_reason_createdAt_idx" ON "IpBlocklist"("reason", "createdAt");
```

The `migrate` container runs this automatically on first boot of
the new image — no manual migration needed.

### Upgrade

```bash
cd /opt/ticketbrainyApp
git pull
docker compose pull
docker compose up -d --force-recreate
```

The `--force-recreate` flag is mandatory — without it, the `caddy`
and `keycloak-init` containers (whose images haven't changed in
this release) won't pick up the bind-mounted file updates from the
git pull. See `docs/deployment-modes.md` for the rationale.

After restart, visit Settings → Deploy & Security → Geo Block to
configure the new feature, and Settings → Deploy & Security →
Audit to verify all four security toggles are still active.

### Reported in v1.10.141 (next release)

- Security Dashboard widgets (24h events graph, top blocked IPs,
  top blocked countries, alert center)
- Configurable rate-limit thresholds via UI (the limits are
  hardcoded today; the `rateLimitConfig` JSON column on
  `SecuritySettings` is the storage backbone for the upcoming UI)

## [1.10.1312] — 2026-04-10

### Docs — upgrade gotcha + Keycloak admin posture guidance

Doc-only patch. Surfaces two learnings from the v1.10.131 rollout
on a production VPS that would have silently broken the hardening
otherwise.

#### Upgrade must use `--force-recreate`

The v1.10.131 fixes live in two bind-mounted files:
`proxy/Caddyfile` (Caddy reverse proxy config) and
`keycloak/apply-config.sh` (Keycloak realm hardener). When you
run `git pull && docker compose pull && docker compose up -d`,
Compose **only recreates services whose image changed**. The
`caddy:2` and `curlimages/curl` images used by `caddy` and
`keycloak-init` are stable, so **those two containers keep
running with their previous in-memory config**, silently
ignoring the updated bind-mounted files.

**Symptom:** your pentest shows the hardening isn't active
(admin console still reachable, CORS still wildcard, BFP still
off on the master realm), even though the files on disk are
up to date and the web container is running the new version.

**Fix:** always upgrade with:

```bash
docker compose up -d --force-recreate
```

Or restart the two bind-mount consumers explicitly:

```bash
docker compose restart caddy keycloak-init
```

`docs/deployment-modes.md` now opens with a prominent
"Upgrading from a previous version — READ FIRST" section that
calls this out explicitly.

#### Keycloak admin posture — by order of preference

The v1.10.131 hardening left the Keycloak admin console
reachable for allowlisted IPs so that self-hosted operators
without a VPN or bastion can still access `/admin/master/console/`
from their office network. This is a deliberate trade-off and
`docs/deployment-modes.md §Keycloak admin IP allowlist` now
documents the preferred order:

1. **VPN / bastion / LAN** — best. The admin console should
   ideally never be reachable from the public Internet.
2. **Allowlist IP** — pragmatic fallback. `/admin/*` and
   `/realms/master/*` return 404 for non-allowlisted IPs
   (masks the existence of the console from scanners).
3. **Neither** — acceptable only if paired with strong
   `KC_ADMIN_PASSWORD` + Brute Force Protection (which v1.10.131
   applies automatically on the master realm).

No code changes — pure documentation patch. Images rebuilt
through `release-lockstep.sh` for lockstep discipline.

## [1.10.131] — 2026-04-10

### Security — blackbox pentest hardening (6 fixes)

A black-box external pentest conducted on a v1.10.13 VPS install
surfaced 1 critical + 4 high-severity findings in the infrastructure
configuration (the application code itself — Next.js Server Actions,
NextAuth middleware, SQL access paths — was found clean: no SQLi,
XSS, SSRF, IDOR, SSTI, or path traversal). This release closes all
critical/high findings and two of the medium findings.

#### C-01 (CRITICAL) — Next.js port exposed in cleartext HTTP

The `web` service in `docker-compose.yml` published `${APP_PORT}:3000`
on all interfaces (`0.0.0.0`), making the Next.js HTTP port directly
reachable from the internet without TLS. Cookies (CSRF, callback,
session) were emitted over cleartext on this port, bypassing Caddy
entirely and exposing them to MitM interception.

**Fix**: the port mapping now defaults to `127.0.0.1:${APP_PORT}:3000`
(loopback only). Caddy reaches the container through the internal
Docker network (`web:3000`), which is unaffected. Operators who
genuinely run without a reverse proxy can opt back in by setting
`WEB_BIND=0.0.0.0` in their `.env`.

- Reproducer before fix: `curl http://vps.example:4000/api/auth/session` → 200 OK
- Reproducer after fix: `curl http://vps.example:4000/api/auth/session` → Connection refused

#### H-01 (HIGH) — NextAuth cookies missing `Secure` flag

`useSecureCookies` was hard-coded to `false` in `auth/index.ts`, so
all NextAuth cookies (`next-auth.session-token`,
`next-auth.callback-url`, `next-auth.csrf-token`) were emitted
without `Secure`, allowing them to travel over plain HTTP. The
rationale in the previous comment (`SSL is terminated at the reverse
proxy, so the app always receives HTTP`) was correct for the
internal socket but had the wrong conclusion: the cookies are
emitted into the browser, which speaks HTTPS to the reverse proxy,
so `Secure` is the correct flag.

**Fix**: `useSecureCookies` is now derived from `NEXTAUTH_URL`
(`true` if it starts with `https://`). In HTTPS mode, cookies are
renamed with the `__Secure-` prefix (session, callback) and `__Host-`
prefix (csrf) so browsers refuse them if ever served over HTTP. Dev
mode (local HTTP) is unaffected.

#### H-02 (HIGH) — Keycloak master admin console publicly exposed

The Keycloak admin console at `/admin/master/console/` was
reachable without any restriction, and the master realm
authentication endpoints had no rate-limit. A combination that
enabled credential stuffing and made the entire IAM one working
exploit away from a pre-auth Keycloak CVE.

**Fix**: the proxy `Caddyfile` now blocks `/admin/*`, `/admin`, and
`/realms/master/*` with a hard `404` in the default (no-allowlist)
case, masking the very existence of the admin console from
scanners. If the operator configures an admin IP allowlist via
Settings → Security, the web container re-renders the Caddyfile and
switches that block to `403` for non-allowlisted IPs (historical
behavior preserved for admin access use cases). The Keycloak user
login flow (`/realms/ticketbrainy/*`, `/resources/*`, `/js/*`)
remains fully open.

#### H-03 (HIGH) — Keycloak reflects arbitrary CORS `Origin` with credentials

All Keycloak OIDC endpoints (`/token`, `/userinfo`, `/logout`,
`/certs`, `.well-known/openid-configuration`) reflected any
`Origin` header back in `Access-Control-Allow-Origin` with
`Access-Control-Allow-Credentials: true`. Tested origins:
`https://evil.example`, `null`, `http://attacker.internal` — all
accepted. Root cause: a client with `Web Origins: *` or `+`
upstream.

**Fix**: two levels of defense. Level 1: the `ticketbrainy` realm
JSON is already clean (explicit `webOrigins` per client). Level 2
(defense-in-depth): Caddy now strips all `Access-Control-Allow-*`
headers emitted by Keycloak and re-emits them conditionally only
when the request `Origin` matches exactly `https://${KEYCLOAK_DOMAIN}`.
Any other origin — including `null` and future regressions in the
realm JSON — is silently blocked at the proxy layer.

#### M-01 (MEDIUM) — no rate-limit on master realm login

8 consecutive failed `grant_type=password` attempts against
`/realms/master/.../token` returned 8 × 401 with no 429, no
`Retry-After`, no slow-down. The master realm is the administrative
realm of Keycloak and had Brute Force Protection disabled by
default.

**Fix**: `apply-config.sh` now applies Brute Force Protection to the
`master` realm in addition to `ticketbrainy`: `failureFactor=5`,
`maxFailureWaitSeconds=900` (15-minute lockout),
`minimumQuickLoginWaitSeconds=60`, password policy upgraded to
`length(14)` (vs 12 on the user realm) because master is
admin-only.

#### M-02 (MEDIUM) — Direct Access Grants (ROPC) on `admin-cli`

The `admin-cli` public client in the master realm accepted
`grant_type=password`, and `team.actions.ts` (the Keycloak user
sync action) was the last applicative consumer of this
flow — using the global admin credentials kept in Node process
memory. Both facts made the flow vulnerable to credential stuffing
(mitigated by M-01 above) and violated the OAuth 2.1 / OAuth
Security BCP recommendation against ROPC.

**Fix**: `apply-config.sh` now provisions a dedicated confidential
client `ticketbrainy-admin-write` in the `ticketbrainy` realm
with `serviceAccountsEnabled: true`,
`directAccessGrantsEnabled: false`, and the minimal realm-management
roles `manage-users` + `view-users` + `query-users` (no
`manage-realm`, no `manage-clients`, no `view-events` — principle
of least privilege). The client secret is published through the
same `kc-secrets` volume pattern as `admin-read`, and
`team.actions.ts` now authenticates with `grant_type=client_credentials`
via a new helper at
`apps/web/src/lib/security/keycloak-admin-write.ts`. The global
admin credentials are no longer needed by the web process.

`admin-cli` remains enabled for the bootstrap-only consumers that
still need it: `apply-config.sh` itself (which runs before the new
client exists) and `scripts/keycloak-reset-admin.sh` (break-glass).
Both run in contexts where credential-stuffing is not a realistic
vector, and are now mitigated by the master realm's Brute Force
Protection.

### Hardening details — headers and TLS

- Strict-Transport-Security now includes `preload` on both vhosts
- New headers on the app vhost: `X-Frame-Options: DENY`,
  `Cross-Origin-Opener-Policy: same-origin`,
  `Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=()`
- Referrer-Policy now explicit on the Keycloak vhost
  (`strict-origin-when-cross-origin`)

### Upgrade instructions

Bind-mounted installs (most self-hosted users) **must** force
recreate the web container so the new `Caddyfile` takes effect:

```
cd /opt/ticketbrainyApp
git pull
docker compose pull
docker compose up -d --force-recreate
```

After restart, check:

```
# C-01 verification — port 4000 should refuse connections
curl --connect-timeout 5 http://your-vps.example:4000/api/auth/session
# Expected: Connection refused

# H-02 verification — Keycloak admin should 404
curl -I https://vpskey.example/admin/master/console/
# Expected: HTTP/2 404

# H-03 verification — CORS from evil origin should not emit ACAO
curl -I -H "Origin: https://evil.example" \
  https://vpskey.example/realms/ticketbrainy/.well-known/openid-configuration \
  | grep -i access-control
# Expected: (empty output)

# M-01/M-02 verification — check keycloak-init logs
docker logs aidesk-keycloak-init-1 2>&1 | grep -E "(admin-write|master realm)"
# Expected: "ticketbrainy-admin-write" creation + "master realm hardened"
```

## [1.10.13] — 2026-04-10

### Fixed — KC_ADMIN_READ_CLIENT_SECRET auto-wired on fresh install

Reported on a clean v1.10.11 VPS install. Settings → Security →
Authentication panel showed:

> Unable to reach Keycloak — check ticketbrainy-admin-read
> client credentials. KC_ADMIN_READ_CLIENT_SECRET is not set

Before v1.10.13, the fresh-install flow for this panel required
a **3-step manual dance** no operator actually does:

1. `keycloak-init` creates the `ticketbrainy-admin-read` client
   on first boot and prints the client secret in its logs.
2. Operator reads the logs, finds the secret, copies it into
   `.env` as `KC_ADMIN_READ_CLIENT_SECRET=...`.
3. Operator restarts the web container to pick up the new env.

Step 2 never happened on real installs — the Security page just
stayed broken indefinitely.

#### Fix — shared volume bridge

`keycloak-init` now writes the secret atomically to a new docker
named volume (`kc-secrets`) that the web container mounts
read-only at `/data/keycloak-secrets`. `keycloak-admin.ts`
lazy-reads the secret from the file when the env var is empty,
so fresh installs work out of the box.

Touched files:

- **`keycloak/apply-config.sh`** — after fetching the secret
  from Keycloak, atomically writes it to
  `/opt/keycloak-init/secrets/admin-read-secret` (tmp file +
  rename, 644 perms so `uid 1001 (nextjs)` can read).
- **`docker-compose.yml`** — new `kc-secrets` volume.
  `keycloak-init` now runs as `user: "0:0"` (root) and mounts
  it `:rw`; `web` mounts it `:ro`.
- **`apps/web/src/lib/security/keycloak-admin.ts`** *(private
  repo)* — new `loadClientSecret()` helper that prefers the env
  var and falls back to the file, caches on first success.

#### Backward compatible

Operators who already set `KC_ADMIN_READ_CLIENT_SECRET` in their
`.env` keep their workflow — the env var takes precedence over
the file. The fallback only fires when the env var is
unset/empty.

### Upgrade from v1.10.12

```bash
cd ticketbrainyApp
git pull
docker compose --profile with-proxy pull
docker compose --profile with-proxy up -d --force-recreate keycloak-init web
```

`--force-recreate keycloak-init` is required so it picks up the
new `apply-config.sh` logic, the root user override, and the
`kc-secrets` mount. `web` recreate picks up the new volume
mount and the updated `keycloak-admin.ts`.

### Release mechanics

- All 5 service images re-tagged + pushed at `v1.10.13` AND
  `:latest` (lockstep release)
- 6 version source files bumped 1.10.12 → 1.10.13
- Public repo changes: `docker-compose.yml` +
  `keycloak/apply-config.sh`

---

## [1.10.12] — 2026-04-09

### Improved — Deployment banner UX (per-field drift + revert)

Follow-up polish to the v1.10.11 drift-detection fix. The banner
now tells the operator **which** fields diverge and offers a
one-click escape hatch.

#### Per-field drift diff

When the saved DB config differs from the running env vars, the
banner now lists each changed field with:

- the human-readable label (e.g. "LAN hosts", "App domain")
- the value saved in the DB (what *would* apply)
- the value currently running on the instance (what *is* live)

Before, the operator had to reverse-engineer the divergence by
comparing their `.env` against the form field-by-field.

#### "Revert to running config" button

A new one-click undo button inside the drift banner. Clicking it:

1. Resets the form to the values currently running in the
   container (env vars at page-load time).
2. Saves — the DB goes back in sync with live, `hasDrift` becomes
   `false`, and the banner disappears **without a docker restart**.

Useful when the operator tested a field change, saved it, then
wanted out of the half-committed state.

### Upgrade from v1.10.11

Web-only update — Caddy config and bootstrap Caddyfile unchanged:

```bash
cd ticketbrainyApp
git pull
docker compose --profile with-proxy pull
docker compose --profile with-proxy up -d --force-recreate web
```

### Release mechanics

- All 5 service images re-tagged + pushed at `v1.10.12` AND
  `:latest` (lockstep release)
- 6 version source files bumped 1.10.11 → 1.10.12
- No changes to `docker-compose.yml`, `proxy/Caddyfile`, or
  `proxy/caddy-entrypoint.sh`

---

## [1.10.11] — 2026-04-09

### Fixed — 4 fresh-install polish issues from VPS walkthrough

Four independent bugs reported on a clean v1.10.10 VPS install.
All shipped in a single lockstep release.

#### 1. Initial Setup checklist — "Add your first customer" was always complete

`db.customer.count()` in the checklist also counted the seeded
system customer (the catch-all for public-domain emails), so the
step was auto-completed before the operator had added anyone.
The query now excludes `isSystem: true` rows.

#### 2. Renamed the catch-all from "AutresClients" to "Other"

The catch-all for orphan tickets from public email domains
(gmail/hotmail/outlook/…) was named "AutresClients", a
French-only label that confused non-French operators. It's now
called "Other" — universally readable across the languages we
support.

The seed upsert force-renames existing rows on every `up -d`
(`update: { isSystem: true, name: "Other" }`), so upgrading
installs rename automatically. No manual SQL needed.

The ticket table previously decided the red system-badge avatar
via a brittle string comparison `customer.name === "AutresClients"`
— now switched to `customer.isSystem` which is rename-safe.

#### 3. Deployment pending banner stuck after save

Settings → Deployment → *Save* used to hard-code the client-side
drift to `true` after every save, so:

- Clicking Save with no actual changes raised a false
  "Modifications en attente d'application" banner.
- Even after the operator ran the suggested
  `docker compose down && up -d`, the banner never cleared
  without a page refresh.

`saveDeploymentConfig` now re-computes the real drift against
live env vars post-save and returns it. The form uses that value
directly — no-op saves no longer raise a false banner, and saves
that bring the DB back in sync with live env clear an existing
banner instantly.

#### 4. SSL certificates panel — "No Caddy certificates detected" despite a live cert

Settings → Security → SSL certificates displayed "No Caddy
certificates detected" even when Caddy was actively serving a
Let's Encrypt certificate. Root cause:

- Caddy writes every file it creates in 600 mode
  (`-rw-------` root:root).
- The web container mounts `caddy-data:/data/caddy:ro` and
  runs Node.js as `uid 1001 (nextjs)`.
- `listCaddyCerts()` hit `Permission denied` on every
  `readdir` under `/data/caddy/caddy/certificates/...` even
  though the files were right there.

Fix: wrap the caddy container with a small entrypoint shim
(`proxy/caddy-entrypoint.sh`) that runs a background loop every
60 seconds and widens perms on PUBLIC cert files only:

```sh
find /data/caddy/certificates -type d -exec chmod o+rx {} +
find /data/caddy/certificates -type f -name '*.crt' -exec chmod o+r {} +
```

Private keys (`*.key`) and ACME metadata (`*.json`) stay 600
and are never exposed outside the caddy container. The 60s loop
catches cert renewals too — Caddy re-writes renewed certs in
600, and the next sweep re-widens them.

### Upgrade from v1.10.10

```bash
cd ticketbrainyApp
git pull
docker compose --profile with-proxy pull
docker compose --profile with-proxy up -d --force-recreate caddy web
```

`--force-recreate caddy` is required because `caddy-entrypoint.sh`
is a new bind mount (the running caddy container must restart to
pick it up). The seed re-runs automatically via the `migrate`
service and force-renames "AutresClients" → "Other".

### Release mechanics

- All 5 service images re-tagged + pushed at `v1.10.11` AND
  `:latest` (lockstep release)
- 6 version source files bumped 1.10.10 → 1.10.11
- Public repo additions: `proxy/caddy-entrypoint.sh`,
  `docker-compose.yml` caddy service now mounts the entrypoint

---

## [1.10.10] — 2026-04-09

### Fixed — Keycloak allowlist hot-reload regression loop

The v1.10.09 fix for the Caddy admin API origin validation covered
two of the three code paths that need the `origins` allowlist, but
missed the third: the `renderCaddyfile()` function in the web
container that re-generates a Caddyfile from DB state on every
"Save & reload Caddy" click.

**Symptom on the VPS after v1.10.09**: after the very first
successful save the UI started showing

```
Saved to database, but Caddy reload failed:
{"error":"client is not allowed to access from origin 'http://caddy:2019'"}
```

on every subsequent save. The hot-reload silently died even though
the bootstrap `proxy/Caddyfile` and the web container both had the
v1.10.09 fixes.

**Cause**: `renderCaddyfile()` emitted `admin 0.0.0.0:2019`
*without* an `origins` block. The first successful save — which
passed the origin check against the bootstrap config still in
memory — replaced the running Caddy config with the rendered one,
wiping the origins allowlist in-process. Every later POST /load
was then rejected. Verified live on VPS 212.47.64.102:

```
$ docker exec caddy wget -qO- http://localhost:2019/config/admin
{"listen":"0.0.0.0:2019"}   ← no "origins" field
```

**Fix**: `apps/web/src/lib/security/caddy-reload.ts` —
`renderCaddyfile()` now emits the same admin block as the bootstrap
`proxy/Caddyfile`:

```
admin 0.0.0.0:2019 {
    origins caddy:2019 localhost:2019 127.0.0.1:2019
}
```

A comment on the block explicitly warns that this must stay in
lockstep with `proxy/Caddyfile` in this repo.

### Upgrade from v1.10.09

Standard rolling upgrade. `proxy/Caddyfile` is unchanged, so no
`--force-recreate caddy` is required this time — only the web
image needs to be refreshed:

```bash
cd ticketbrainyApp
git pull
docker compose --profile with-proxy pull
docker compose --profile with-proxy up -d --force-recreate web
```

If the operator already hit the bug on v1.10.09 and the running
Caddy config lost its origins, one additional restart of Caddy
will reload the bootstrap Caddyfile from disk and re-seed the
origins:

```bash
docker compose --profile with-proxy up -d --force-recreate caddy
```

### Release mechanics

- All 5 service images re-tagged + pushed at `v1.10.10` AND
  `:latest` (lockstep release per the release-lockstep.sh script)
- 6 version source files bumped 1.10.09 → 1.10.10
- `proxy/Caddyfile` unchanged (already correct since v1.10.09)

---

## [1.10.09] — 2026-04-09

### Fixed — Caddy admin API origin validation

The v1.10.08 Keycloak admin IP allowlist hot-reload was rejected
by Caddy with `client is not allowed to access from origin ''` on
every save. Two missing pieces:

**Cause**: when Caddy's admin API listens on a non-loopback
address (`admin 0.0.0.0:2019`), the default origin validation
refuses every request unless an explicit `origins` directive is
specified. The v1.10.08 Caddyfile had none, so the allowed list
was empty and every POST /load from the web container was
dropped. On top of that, server-to-server Node fetch sends an
empty `Origin` header by default, which also confuses Caddy's
origin parsing.

**Fix**:

- `proxy/Caddyfile` — the admin block now declares the allowed
  origins explicitly:

  ```
  admin 0.0.0.0:2019 {
      origins caddy:2019 localhost:2019 127.0.0.1:2019
  }
  ```

  `caddy:2019` matches the docker DNS hostname the web container
  uses to reach Caddy. The loopback variants are kept for local
  debugging via SSH port-forward.

- `apps/web/src/lib/security/caddy-reload.ts` — the fetch call
  now sets an explicit `Origin: http://caddy:2019` header. Caddy
  parses this as a URL, extracts the Host part, and matches it
  against the origins list.

### Upgrade from v1.10.08

Standard rolling upgrade, with `git pull` to refresh the
bind-mounted Caddyfile:

```bash
cd ticketbrainyApp
git pull
docker compose --profile with-proxy pull
docker compose --profile with-proxy up -d --force-recreate caddy web
```

The `--force-recreate caddy` is required because the Caddyfile
is a bind mount — the running container keeps the old config
until the process restarts.

### Release mechanics

- `web` image rebuilt (new digest sha256:44f605c56cae…)
- 4 other images re-tagged from the matching v1.10.08 builds
  for lockstep parity
- 6 version source files bumped 1.10.08 → 1.10.09

## [1.10.08] — 2026-04-09

### Added — Keycloak admin IP allowlist, managed from the UI

The `Settings → Security` page gets a new **"Keycloak admin IP
allowlist"** panel next to the existing TicketBrainy admin
allowlist. It restricts `/admin/*`, `/admin`, and
`/realms/master/*` on the Keycloak domain to specific CIDRs,
enforced by the Caddy reverse proxy **before** the request
reaches Keycloak.

This is a separate list from the TicketBrainy admin allowlist
because they protect different things:

| Allowlist | Enforced by | What it protects |
|---|---|---|
| TicketBrainy admin | Next.js server actions | Security mutation routes |
| Keycloak admin | Caddy reverse proxy | Keycloak admin console + master realm |

The two are complementary — the first protects app-level admin
actions, the second protects the identity provider admin console.
Both default to "no restriction" on fresh installs.

**Zero-downtime hot reload**: saving the list from the UI
triggers a server action that:

1. Validates CIDRs and self-lockout (your current IP must be in
   the list before it's saved)
2. Persists to `SecuritySettings.keycloakAdminIpAllowlist`
3. Re-renders the entire Caddyfile from a TypeScript template
4. POSTs the rendered config to `http://caddy:2019/load` (Caddy's
   admin API, exposed only on the internal docker network)
5. Caddy validates the new config, switches in-flight requests
   over, and drops the old config — no container restart, no
   dropped connections

**Survives container restarts**: because Caddy boots with a bare
Caddyfile (no matcher), a full `docker compose down/up` would
silently drop the restriction. The web container's Next.js
instrumentation hook re-pushes the current DB value to Caddy
two seconds after boot, so the restriction is re-applied
automatically. This also makes the restriction survive image
upgrades.

**What stays open** — the public SSO flow for regular ticket
users (`/realms/ticketbrainy/*`) and the shared Keycloak
`/resources/*` (CSS/JS for login pages) are not blocked. Only
the admin surface is restricted.

**Break-glass**: if you lock yourself out (e.g. ISP rotated your
IP), SSH to the server and clear the DB list, then restart
Caddy — see `docs/DEPLOYMENT-MODES.md` for the exact commands.

### Schema changes

New Prisma column on `SecuritySettings`:

    keycloakAdminIpAllowlist String[] @default([])

Applied automatically by the migrate container on the next boot
via `prisma db push`. No data migration needed; existing rows
get the default empty array, matching pre-v1.10.08 behaviour
(no restriction).

### Release mechanics

- `web` + `migrate` images rebuilt (schema change triggers
  the migrate rebuild)
- 3 other images re-tagged from the matching v1.10.07 builds
  for lockstep parity
- All 5 images at `ghcr.io/kr1s57/ticketbrainy-*:v1.10.08` +
  `:latest`, digest parity verified
- 6 version source files bumped 1.10.07 → 1.10.08

## [1.10.07] — 2026-04-09

### Fixed — Bootstrap banner readable in light theme

The bootstrap-mode banner on the `/login` page used `text-amber-200`
with no `dark:` variant, which made the text almost invisible on
a light-theme background (pale yellow on near-white). Dark theme
was fine.

Now uses a proper light/dark colour pair:

- `bg-amber-100/70 text-amber-900` in light mode
- `dark:bg-amber-500/5 dark:text-amber-100` in dark mode

And the inline `<code>` elements get a matching split
(`bg-amber-500/20` / `dark:bg-amber-500/10`).

### Release mechanics

- 5 images at `ghcr.io/kr1s57/ticketbrainy-*:v1.10.07` + `:latest`
- Only `web` has source changes; the other 4 are re-tagged from
  the matching v1.10.06 builds for lockstep parity
- 6 version source files bumped 1.10.06 → 1.10.07

## [1.10.06] — 2026-04-09

### Fixed — Initial Setup checklist polish

Two small fixes to the dashboard checklist introduced in v1.10.04,
caught during the first operator walkthrough.

**Keycloak users step lands on admin login, not a deep link**
— the step opened
`https://KEYCLOAK_DOMAIN/admin/ticketbrainy/console/#/ticketbrainy/users`
directly. That URL bypasses the master realm's admin login flow and
lands on a blank/broken state because Keycloak can't reconcile the
requested page with the missing admin session. Changed to just the
root `https://KEYCLOAK_DOMAIN/` so operators go through the normal
admin login flow, then navigate to the `ticketbrainy` realm from the
dropdown (which matches the walkthrough in the step description).

**Mailbox step copy explains multi-mailbox + default SMTP** — the
step description conflated "ticket reception" and "system
notifications" without explaining how multiple mailboxes are handled.
Rewrote to explicitly say:

- You can add several mailboxes
- The **first mailbox you add** becomes the default SMTP used by the
  ticketing system for outbound notifications (user invites, password
  resets, new-ticket alerts)

Both EN and FR copy updated.

### Release mechanics

- 5 images at `ghcr.io/kr1s57/ticketbrainy-*:v1.10.06` + `:latest`
- Only `web` has source changes; the other 4 are re-tagged from the
  matching v1.10.05 builds for lockstep parity
- 6 version source files bumped 1.10.05 → 1.10.06

## [1.10.05] — 2026-04-09

### Added

**DNS prerequisites spelled out + pre-check** — `install.sh` now
explicitly lists the two DNS A records required for Caddy mode
(one for the app, one for Keycloak) in the mode B description,
and runs a non-blocking DNS resolution check after both domains
are captured. If either domain doesn't resolve or points somewhere
else, you get a clear warning and a confirmation prompt — you can
continue the install and fix DNS afterwards (Caddy keeps trying
the ACME challenge in the background). `docs/DEPLOYMENT-MODES.md`
has a new prerequisites table explaining why two records are
needed (Keycloak's OIDC redirect URIs require its own origin).

**Activation wizard pre-fills from install.sh** — the license
email you typed at the terminal is now persisted to `.env`,
passed to the web container via docker-compose, and read by the
server component of `/activate` so step 1 renders with the email
pre-populated. You still confirm before clicking "Activate" —
we don't auto-submit, you stay in control — but there's no more
retyping the same address in the browser. Prevents the typo-driven
"two fresh-deploy devices" issue on VigilanceKey.

**Admin IP allowlist panel — inline help + current-IP quick-insert**
The Settings → Security → Admin IP allowlist panel has three new
UX improvements:

1. An inline help block at the top explaining the format (one
   IP/CIDR per line), concrete examples (`/32` for a single
   workstation, `/24` for an office subnet), and that an empty
   list is a valid first-run setting (auth still protects the
   pages).

2. The server component now reads `x-forwarded-for` from the
   current request and passes your current IP to the form. A
   blue banner displays the detected IP and a one-click "Add /32"
   button inserts it into the textarea. Prevents self-lockout.

3. A break-glass procedure block documents
   `SECURITY_ALLOWLIST_BYPASS=true` as the documented emergency
   recovery path, with the exact 2-command sequence to run on
   the server.

`docs/DEPLOYMENT-MODES.md` has a new "Admin IP allowlist — what
to put there" section with guidance for residential ISPs with
dynamic IPs (don't enable it; use WAF-level restrictions at your
upstream firewall instead).

### Upgrade notes

Standard rolling upgrade:

```bash
docker compose pull
docker compose up -d
```

If you're upgrading from v1.10.02 or earlier and want to take
advantage of the wizard pre-fill on an already-activated instance,
there's nothing to do — the feature only kicks in on fresh
installs, your existing `.env` is untouched.

### Release mechanics

- 5 images at `ghcr.io/kr1s57/ticketbrainy-*:v1.10.05` + `:latest`
- Only `web` has source changes; the other 4 are re-tagged from
  the matching v1.10.04 builds for lockstep parity
- 6 version source files bumped 1.10.04 → 1.10.05

## [1.10.04] — 2026-04-09

### Added — Initial Setup checklist on the dashboard

Fresh installs now get a dashboard widget that walks operators
through the 5 must-do steps before the instance is production-ready:

1. **Add your first mailbox** — IMAP + SMTP, used for both ticket
   reception AND system notifications (password reset, invites)
2. **Create your first Keycloak users** — opens the Keycloak admin
   console (URL auto-resolved from KEYCLOAK_DOMAIN in Caddy mode,
   or IP:8180 in LAN mode)
3. **Choose your interface language** → Settings → Language
4. **Add your first customers** → Settings → Customers
5. **Customise your personal theme** → Settings → Appearance

Each step shows a green check when done (auto-detected from real DB
state OR manually dismissed via click), a progress bar counts the
completed items, and the whole widget auto-hides when everything is
done or when the operator clicks the dismiss `X`. Preference-only
steps (language, theme) can be manually toggled; real-infra steps
(mailbox, Keycloak users, customers) are detected from Prisma counts
and cannot be faked.

Auto-detection queries run in parallel with the existing dashboard
queries — no added latency beyond ~5-10ms.

### Fixed — Analytics / Reports "Analytics Pro" lock screen

Both `/analytics` and `/analytics/reports` still referenced the
decommissioned `analytics_pro` plugin in their `<FeatureGate>`
lock screen. The feature flag check (`hasFeature("analytics_dashboard")`)
already resolved correctly against the current `enterprise_pack`
plugin, but the "Requires …" CTA text pointed users to a plugin
that no longer exists in the marketplace. Updated both pages to
`pluginName="Enterprise Pack"` with the correct slug, so clicking
the lock now takes operators to the right plugin detail page.

### Release mechanics

- 5 images at `ghcr.io/kr1s57/ticketbrainy-*:v1.10.04` + `:latest`
- Only `web` has source changes; the other 4 are re-tagged from
  v1.10.03 builds for lockstep parity
- 6 version source files bumped 1.10.03 → 1.10.04
- Rolling upgrade: `docker compose pull && docker compose up -d`

## [1.10.03] — 2026-04-09

### Fixed — Settings/Deployment sees Caddy + wizard auto-detects mode

Three related fixes that surfaced on the fresh VPS deploy path once
v1.10.02 unblocked the SSO bootstrap. The operator could successfully
log in but `Settings → Deployment` reported "Caddy disabled, no
domains, no Let's Encrypt certs" even while Caddy was running and
serving real certs from the front.

**Web container never received deployment env vars**

`docker-compose.yml` referenced `APP_DOMAIN`, `APP_URL`, `APP_PORT`,
`KEYCLOAK_DOMAIN`, `LETSENCRYPT_EMAIL` for Caddy variable substitution
and for deriving `NEXTAUTH_URL`, but NEVER passed them into the web
container's environment. `getLiveConfig()` in `deployment.actions.ts`
reads directly from `process.env`, so on the web side every one of
those values came back empty. The Settings → Deployment panel
correctly rendered the resulting config as "Caddy disabled".

Added all five vars to the web service environment block so the live
config reflects what's actually running.

**Caddy cert detection defeated by Caddy's 700 perms**

`deployment-detector.ts` used `fs.readdirSync("/data/caddy/caddy/
certificates")` which throws EACCES inside the web container. Caddy
creates `acme/`, `certificates/` and `locks/` as `root:root mode 700`,
while the web container runs as a non-root `nextjs` user. The
sticky-bit `1777` on the parent `/data/caddy/caddy/` dir lets us
STAT children but not READ them.

The detection code swallowed the EACCES in try/catch and returned
false → every Caddy deploy was reported as "Caddy inactive, no
certs" on the Security page, greying out the entire HTTPS/Caddy/
Let's Encrypt section.

New heuristic: check for `/data/caddy/caddy/last_clean.json` via
`existsSync`. Caddy writes this file on every cert maintenance cycle
(the first one runs at container startup). `existsSync` calls
`stat()` internally, which only needs execute on the parent dir
(`1777` grants that) and NOT read on the file contents (which we
don't need).

**Activation wizard step 2 always defaulted to LAN-only**

The `/activate` step 2 React component initialised state with
`useState<NetworkExposure>("none")`. On a VPS deploy where install.sh
just configured Caddy, the wizard showed "LAN-only" pre-selected and
operators who clicked through quickly ended up persisting
`networkExposure="none"` into `SecuritySettings`. From that point on
the Security page said "LAN-only, Caddy disabled" — matching the DB
but not reality.

The server component now auto-detects the mode from install.sh's
env vars and passes it as `initialMode` to the form:

- `APP_DOMAIN` set → **vps-caddy** (install.sh only writes `APP_DOMAIN`
  in Caddy mode)
- `APP_URL` starts with `https://` and no `APP_DOMAIN` → **behind-waf**
- otherwise → **none** (LAN)

Step 2 opens with the best-guess option selected and a green banner:

> Detected from your install.sh configuration: VPS with managed
> Caddy. Click any other option above to override.

The operator can still override before submitting.

### Upgrade notes from v1.10.0 – v1.10.02

Standard rolling upgrade:

```bash
docker compose pull
docker compose up -d
```

If your SecuritySettings row already has `networkExposure=none`
from an earlier broken activation, fix it in-place from the UI:
**Settings → Security → Deployment mode panel** → click the
correct mode. No reinstall needed.

### Release mechanics

- 5 images at `ghcr.io/kr1s57/ticketbrainy-*:v1.10.03` + `:latest`
- Only `web` has source changes; the other 4 are re-tagged from the
  matching v1.10.02 builds for lockstep parity
- 6 version source files bumped 1.10.02 → 1.10.03

## [1.10.02] — 2026-04-09

### Fixed — Bootstrap login flow + Keycloak public exposure

Two fixes that complete the fresh-install story started in 1.10.01.
That release fixed the SSO first-user auto-promotion server-side, but
on a real Caddy VPS deploy the operator could never actually REACH
the point where that code runs because of two chicken-and-egg issues.

**Bootstrap mode on the login page (critical)**

Until now, the `/login` page showed the local email+password form
only to client IPs that matched `LAN_HOSTS`. On a VPS deploy, every
operator is "public" from the server's perspective — no LAN exists —
so the local seed account `admin@ticketbrainy.local` was effectively
invisible from the outside, and the SSO button was the only option.
But SSO has no admin users yet on a fresh install, so there's no way
to log in at all.

New behaviour: the login page now checks the database for any
active Keycloak ADMIN user. If none exists, it enters "bootstrap
mode": the local form is shown regardless of client IP, with a small
amber banner explaining why. As soon as someone logs in via SSO and
gets auto-promoted (the "first SSO admin" rule from v1.10.01), the
bootstrap flag flips off and the local form is hidden from public
IPs again.

This cleanly solves the chicken-and-egg: bootstrap with the local
account, create the Keycloak user, SSO in, the bootstrap door closes
automatically.

**Keycloak host port bound to localhost in Caddy mode**

The `keycloak` service used `"${KC_PORT:-8180}:8080"` which binds
to 0.0.0.0 — exposing the admin console on `http://<public-ip>:8180`.
Keycloak 26 then rejects every non-localhost HTTP hit with
"HTTPS required", which is a dead end but still looks like the right
URL, confusing operators. Worse, Keycloak's admin console client has
relative `redirectUris` which get resolved against the request URL,
so a single HTTP hit on :8180 would sometimes poison the session
with an HTTP redirect_uri that then fails against the HTTPS endpoint.

Change:

```yaml
ports:
  - "${KC_BIND:-0.0.0.0}:${KC_PORT:-8180}:8080"
```

`install.sh` in Caddy mode now writes `KC_BIND=127.0.0.1` to `.env`,
so the port is only reachable from localhost on the server itself.
Caddy still reaches Keycloak via the internal docker network
(`keycloak:8080`), so `https://<kc-domain>/admin` remains the
working entry point. LAN deployments (non-Caddy mode) are untouched
— `KC_BIND` defaults to `0.0.0.0` so admins on the LAN can still
hit `http://<server-ip>:8180` as before.

**install.sh — final summary + bootstrap sequence**

Updated the "Access URLs" and "Next steps" sections to:

- Display the correct Keycloak admin URL per mode (Caddy: HTTPS
  domain, Direct: IP:8180)
- In Caddy mode, explicitly warn that `http://<ip>:8180` is bound to
  localhost only, with a tip to configure DNS if not ready
- Walk through the 5-step bootstrap sequence: activate license →
  log in with `admin@ticketbrainy.local` (bootstrap mode) → create
  user in Keycloak admin console → set password manually in the
  Credentials tab → log out and SSO in (auto-promoted to ADMIN) →
  change the seed admin password

### Upgrade notes from v1.10.0 or v1.10.01

The cleanest fix is to wipe and reinstall:

```bash
docker compose down -v
cd ..
rm -rf ticketbrainyApp
git clone https://github.com/kr1s57/ticketbrainyApp.git
cd ticketbrainyApp
bash install.sh
```

If you cannot drop the database but are on v1.10.0/v1.10.01 and
stuck, add this to your `.env` in Caddy mode and recreate Keycloak:

```
KC_BIND=127.0.0.1
```

Then `docker compose up -d --force-recreate keycloak`.

### Release mechanics

- 5 images at `ghcr.io/kr1s57/ticketbrainy-*:v1.10.02` + `:latest`,
  digest parity verified (only `web` has source changes; the other
  four are re-tagged from the matching v1.10.01 builds)
- 6 version source files bumped 1.10.01 → 1.10.02

## [1.10.01] — 2026-04-09

### Fixed — Fresh install / SSO first-login UX

Four fixes that unblock the first-time deploy experience on a fresh
VPS. A real end-to-end test install on v1.10.0 hit every single one
of these in sequence — the hardest one left the app entirely unusable
after a successful Keycloak SSO login.

**SSO first-admin auto-promotion (critical)**

The jwt callback in `apps/web/src/lib/auth/index.ts` used
`userCount === 0 ? "ADMIN" : "AGENT"` to decide whether a fresh
Keycloak user should be auto-promoted. On every real install
`prisma/seed.ts` has already created the seed local account
`admin@ticketbrainy.local` *before* anyone logs in via SSO, so
userCount is always ≥ 1 and every SSO user landed as AGENT with
`isActive=false`.

Worse: the next branch (`if (!dbUser.isActive)`) returned the token
without setting `token.userId` or `token.role`. Every downstream
`db.user.findUnique({ where: { id: session.userId } })` then threw
`User not found` with a cryptic 500, and every admin endpoint
returned 403 because `session.user.role` was undefined. The user
was left with an apparently-working login that crashed on every
page.

New logic: the first user with `keycloakId IS NOT NULL AND
role='ADMIN' AND isActive=true` is the "first SSO admin" — the
seed local account does not block this check because it has no
keycloakId. Additionally, `token.userId` and `token.role` are
always set, even for inactive users, so downstream code can render
a proper "account pending approval" screen instead of crashing.
`token.error='inactive'` is now an *additional* marker, not a
replacement.

Security model: whoever holds access to the Keycloak realm is
trusted to be the first TicketBrainy admin. This is already the
trust boundary in practice — Keycloak realm access is what gates
who can reach the app at all.

**Telegram bot crash loop**

`process.exit(1)` on missing `TELEGRAM_BOT_TOKEN` combined with
Docker's `restart: unless-stopped` caused a crash-loop that flooded
logs on every fresh install that did not use Telegram notifications.
Replaced with a silent poll-wait loop that re-checks env + DB every
60s. When the operator eventually configures a token in Settings
→ Telegram, the bot picks it up on the next poll and starts
normally. No more log noise, no more manual `docker compose stop
telegram-bot` workaround.

**install.sh — Caddy-mode final summary**

In Caddy mode, `APP_URL` (and `NEXTAUTH_URL` inside the container)
is set to `https://<domain>`. The CSRF check in `/api/activate` and
every server action requires the browser's `Origin` header to match
that exact URL. Hitting `http://<server-ip>:4000` in Caddy mode
gets rejected with **403 Forbidden** because origins don't match.

The installer now:
- Displays ONLY the HTTPS domain URL in Caddy mode (never the LAN IP)
- Shows a prominent warning box explaining why `http://<ip>:4000`
  must NOT be used in Caddy mode
- Includes quick troubleshooting pointers (DNS resolution, Caddy
  logs, firewall ports 80/443)
- Updates the Next steps block to point at the right URL per mode
- Adds a "Keycloak SSO as admin" section documenting the auto-promotion
  rule from the fix above

**docs/DEPLOYMENT-MODES.md — Keycloak email + first SSO admin**

Added two new sections:

- **Keycloak email** — explains that "No sender address configured
  in the realm settings for emails" comes from a missing realm-level
  SMTP config in Keycloak. Documents both paths to unblock user
  provisioning (configure realm SMTP OR use `Credentials → Set
  password` instead of the email-based reset flow).
- **First SSO admin login** — documents the auto-promotion rule from
  v1.10.01 and the interaction with the seed local account.

### Upgrade notes from v1.10.0

**If you already installed v1.10.0 and your SSO user is stuck:**

The cleanest fix is to wipe and re-install — same outcome, zero
manual surgery:

```bash
docker compose down -v
cd ..
rm -rf ticketbrainyApp
git clone https://github.com/kr1s57/ticketbrainyApp.git
cd ticketbrainyApp
bash install.sh
```

For operators who cannot drop the database, the SQL fix is:

```sql
UPDATE "User"
SET "isActive" = true, "role" = 'ADMIN'
WHERE email = '<your-email>' AND "keycloakId" IS NOT NULL;
```

Followed by `docker compose pull && docker compose up -d --force-recreate web`.

### Release mechanics

- 5 images rebuilt and pushed to `ghcr.io/kr1s57/ticketbrainy-*`
  at BOTH `v1.10.01` AND `:latest`, digest parity verified
- 6 version source files bumped 1.10.0 → 1.10.01

## [1.10.0] — 2026-04-09

### New — Security Settings page

A new **Settings → Security** section gives operators a single place to
inspect and configure the platform's security posture. It covers nine
modules, grouped into read-only posture panels at the top and
togglable enforcement modules below.

**Read-only posture panels**

1. **Deployment mode** — current mode (LAN / behind-WAF / VPS+Caddy /
   VPS direct) plus live runtime signals that flag mismatches between
   the declared mode and the detected topology (Caddy presence,
   upstream proxy type via `CF-Ray` / `X-Forwarded-For`, etc.)
2. **Authentication (Keycloak)** — realm name, brute-force config,
   MFA policy, password policy, session timeouts, user count, and
   24-hour login-failure count. Data comes from the Keycloak Admin
   API via a dedicated read-only client `ticketbrainy-admin-read`
   created idempotently on every boot by `keycloak-init`.
3. **Rate limiting** — 6 known rules (`login:ip`, `login:user`,
   `activate:ip`, `csat:ip`, `ai:user`, `upload:user`) with live
   active-bucket counts read directly from Redis
4. **SSL certificates** — lists Let's Encrypt certificates persisted
   by Caddy with per-domain expiry (empty when Caddy is not used)

**Togglable enforcement modules**

5. **Audit logging** — records 17 security-sensitive event types
   (login success/failure, user created/deleted, role changed,
   mailbox OAuth, plugin enable/disable, license activation, upload
   rejected, rate-limit hit, etc.) to a new `AuditLog` table. Runtime
   toggle + configurable retention window (default 90 days) + daily
   background purge job. Comes with a paginated feed, event-type
   filter, and CSV export on the same Security page.
6. **Upload rate-limit** — throttles `/api/attachments/upload` to 20
   uploads per 5 minutes per user when enabled. Rejections are
   logged as `RATE_LIMIT_HIT` audit events.
7. **Magic-bytes validation** — rejects uploads whose content does
   not match the claimed extension (e.g. a `.exe` renamed to
   `.pdf`). Runs on the web upload path AND on incoming email
   attachments (advisory-only on the mail side — attachments are
   stored but flagged with a reason).
8. **Login anomaly detection** — when enabled, tracks a per-user
   failure counter in Redis with a 10-minute sliding window and
   emits `AUTH_LOGIN_SUSPICIOUS` audit events after 5 failures.
9. **Admin IP allowlist** — restricts `/settings/**` and
   `/api/admin/**` to specific CIDR blocks (IPv4 or IPv6). Includes
   triple self-lockout protection (client-side CIDR validation,
   server-side current-IP-in-list check, and a
   `SECURITY_ALLOWLIST_BYPASS=true` break-glass env var — see
   `docs/DEPLOYMENT-MODES.md §break-glass` for the recovery
   procedure).

### New — Activation wizard, step 2

`/activate` now has a second step where the operator chooses their
deployment mode from the four options above. The choice is persisted
in the database and drives the default toggle values for the Security
page (e.g. VPS modes enable rate-limit and anomaly detection by
default; LAN mode leaves them off). You can always change the mode
later at **Settings → Security**.

### New — `docs/DEPLOYMENT-MODES.md`

Full reference guide for the four modes, with pre-requisites,
recommended toggles per mode, the break-glass recovery procedure, and
how to retrieve the Keycloak `ticketbrainy-admin-read` client secret
from the init container logs.

### Database — schema changes

Two new tables and two new columns are added automatically by
`migrate` on the next `docker compose up -d`:

- `SecuritySettings` — singleton row holding every toggle state and
  the admin IP allowlist. Seeded with safe defaults so upgrades from
  v1.3.x–v1.9.x land in a known state.
- `AuditLog` — indexed on `eventType+createdAt`, `userId+createdAt`,
  `ip+createdAt`, and `createdAt` for fast filtering and pagination.
- `Attachment.flagged` (boolean) and `Attachment.flagReason` (text)
  — set by the magic-bytes validator on the upload path and by
  `mail-service` on incoming email attachments. Used to surface a
  flag badge in the UI (future release).

### Config — new environment variables

Add the following to your `.env` (see `.env.example` for the exact
format and the new section "Security Settings v1.10.0"):

```
KC_ADMIN_READ_CLIENT_ID=ticketbrainy-admin-read
KC_ADMIN_READ_CLIENT_SECRET=
SECURITY_ALLOWLIST_BYPASS=
```

After the first `docker compose up -d` retrieve the Keycloak secret
from the init container logs:

```bash
docker compose logs keycloak-init | grep KC_ADMIN_READ_CLIENT_SECRET
```

Paste it into `.env` as `KC_ADMIN_READ_CLIENT_SECRET=...` and then:

```bash
docker compose up -d --force-recreate web
```

The Security page will now show the full Keycloak posture panel
instead of an amber error card.

### Upgrade notes from v1.3.x

**Upgrading from a v1.3.x install is a straightforward
`docker compose pull && docker compose up -d`** — the `migrate`
service applies the new schema, and the `keycloak-init` service
creates the new admin-read client on first boot. After that, follow
the new-env-vars procedure above to wire the Keycloak secret into
`.env`.

Everything between v1.3.202 and v1.10.0 was an internal rolling
update — the `:latest` tag always reflected the current state. If
you want to pin to a specific version, use `:v1.10.0` in
`docker-compose.yml` instead of `:latest`.

### Deferred to future releases

- Antivirus scanning for attachments (ClamAV) — out of scope for
  v1.10.0 to keep the shipping surface small
- SPF / DKIM / DMARC validation on incoming email
- Spam scoring on incoming email
- Middleware-layer IP allowlist enforcement — currently implemented
  at the server-action layer because Next.js 16 node middleware is
  still experimental. The UI and enforcement are fully functional;
  this is an internal architectural note only.

---

## [1.3.202] — 2026-04-06

### Security — Image hardening

This patch strips build-time artifacts from the `web` Docker image so
the customer-facing container no longer carries raw TypeScript source,
build configuration, or source maps. Also scrubs a few leftover code
comments and one user-facing error message that named internal
infrastructure.

**What the image no longer ships**

- Raw `.ts` / `.tsx` source tree under `/app/apps/web/src/` — Next.js 16
  + Turbopack was over-inclusive in its standalone file tracing and was
  shipping the full application source into every image. This release
  deletes the source tree from the standalone output at build time.
- Server route source maps (`.next/server/**/*.map`)
- Build-time config files (Dockerfile, tsconfig.json, components.json,
  tailwind.config.ts, postcss.config.js, next.config.ts, prisma.config.ts)
- Internal dev scripts (`scripts/check-feature-gates.mjs`)
- Turbopack cache/log from the host build context

**Other scrubs**

- `allowedDevOrigins` is no longer in `next.config.ts` (it used to bake a
  LAN-only workstation IP into the production bundle).
- The activation screen hint and the fresh-deploy error message no
  longer name the internal license server hostname — they now reference
  the configured `VIGILANCE_KEY_URL` env var instead.

No functional change for end users. Upgrade is a plain image pull.

```bash
docker compose pull
docker compose up -d
```

Image size is unchanged (334 MB). The stripped files were < 1 % of the
total — the fix addresses the content of the image, not its weight.

---

## [1.3.201] — 2026-04-06

### Added — Mailbox inbound filter rules

Every mailbox now has a configurable set of **exclusion rules** that are
checked before any incoming IMAP message becomes a ticket. Use them to
silently drop noisy automated notifications (deploy summaries, cron
reports, monitoring heartbeats) or to block entire sender domains.

Each rule has three fields:

- **Field**: `Objet`, `Corps du message`, `Email expéditeur`, or
  `Domaine expéditeur`
- **Operator**: `contient`, `est égal à`, `commence par`, or
  `correspond à (regex)`
- **Value**: the text/pattern to match against

A message that matches **any active rule** is marked as read on IMAP but
**never creates a ticket and never touches the database** — the filter
runs before deduplication so noisy senders cost essentially zero.

Regex patterns are validated server-side at save time — invalid patterns
are rejected with a clear error message instead of crashing the poll
cycle later.

**Where to configure**: Settings → Mailboxes → Edit a mailbox → scroll to
the "Règles d'exclusion (filtre inbound)" section (only visible on
already-saved mailboxes).

### Added — Multi-select delete on ticket lists

The ticket list selection toolbar (previously showing only the "Merge"
button when 2+ tickets are selected) now also surfaces a destructive
**"Supprimer la sélection"** button as soon as at least one ticket is
checked. Confirmation prompt tells you how many tickets will be affected,
then they are moved to the "Supprimés" folder where they can be restored.

Under the hood it's a single transaction that soft-deletes every target
and writes one activity entry per ticket — fast and idempotent even for
large selections (capped at 500 per call).

### Database migration

This release adds a `MailboxExclusion` table with a foreign key cascade
from `Mailbox`. No manual action required — the schema is applied
automatically by the `migrate` init container on the first `up -d` after
pulling.

### Upgrade

```bash
docker compose pull
docker compose up -d
```

The new features are available immediately after the containers restart.

---

## [1.3.200] — 2026-04-06

### Dashboard & Statistics — full redesign with Recharts

Both the main **Dashboard** and the **Statistics** page have been rebuilt on
top of Recharts (wrapped by the shadcn `ChartContainer`). Hand-rolled div
bars and list-with-dots are gone; replaced by proper accessible charts that
follow the active theme automatically.

**What's new on the Statistics page**

- **Volumes & Résolutions** section with a grouped bar chart (opened vs
  resolved per day) and a radial resolution-rate gauge with target line.
- **Performances Équipe** section with a ranked agent leaderboard
  (progress-bar visualization) and a priority distribution with colored
  semantic bars.
- **Analyse de Tendance** section with a weekly 3-series line chart
  (opened / in progress / resolved) and a status distribution donut with
  legend.
- Modernized KPI row with accent-tinted icons and background accents.

**What's new on the Dashboard**

- Full 7-day activity bar chart (opened vs resolved) — right next to
  "My workload" — driven by a new data query.
- Modernized KPI cards with accent icons.
- Refined mailbox grid with hover-lift animation, connection dot, and
  agent badge overflow.
- Recent tickets list with French relative timestamps.

**Technical notes**

- All charts use semantic CSS tokens (`--chart-tb-*`) that cascade through
  the 4 existing themes (light default, light pro, dark default, dark pro),
  so no JS theme switch is needed.
- Dates are pre-formatted server-side in `fr-FR`, avoiding any hydration
  mismatch between SSR and client.
- Chart components live at `apps/web/src/components/charts/` in the source
  and are tree-shaken into the right pages at build time.

No migration is required — the new UI is bundled into the updated
`ghcr.io/kr1s57/ticketbrainy-web:v1.3.200` image and ships automatically
when you pull and restart.

### Security — Keycloak hardening sync + admin recovery toolkit

This release also ships an idempotent post-start configuration sync for
Keycloak and a self-contained admin recovery toolkit. After every
`docker compose up -d` the security defaults are re-enforced automatically,
so accidental UI changes or future Keycloak image upgrades cannot quietly
weaken the realm.

### Added

- **`keycloak-init` one-shot service** in `docker-compose.yml`. Runs after
  Keycloak is up, applies our hardened defaults via the admin REST API, then
  exits. Idempotent and safe to re-run.
- **`keycloak/apply-config.sh`** — single source of truth for the realm
  defaults. Edit it to change them.
- **`scripts/keycloak-reset-admin.sh`** — admin recovery toolkit with three
  modes:
  - `--mode unlock` — clear brute-force lockout for the admin user
  - `--mode api <NEW>` — rotate password while current credentials still work
  - `--mode recovery <NEW>` — full bootstrap recovery when the password is lost
  Auto-detects the keycloak container and Docker network — no configuration.
- **`docs/KEYCLOAK-ADMIN-RECOVERY.md`** — complete operational runbook
  covering hardening sync, login-theme reapplication after upgrade, all three
  recovery modes, end-user lockouts, brute-force settings, and the
  post-upgrade checklist.

### Changed

- **Realm template** (`keycloak/ticketbrainy-realm.json`) — strengthened for
  fresh installs:
  - `passwordPolicy`: `length(8) and notUsername`
    → `length(12) and upperCase(1) and lowerCase(1) and digits(1) and specialChars(1) and notUsername and passwordHistory(5)`
  - `otpPolicyAlgorithm`: `HmacSHA1` → `HmacSHA256`
  - `ssoSessionMaxLifespan`: 36 000 s (10 h) → 28 800 s (8 h)
- These same hardened settings are also re-applied on every `up -d` to existing
  installs by the `keycloak-init` service — no manual migration needed.

### Brute-force protection — what's enforced

| Setting                  | Value | Meaning                          |
|--------------------------|-------|----------------------------------|
| `bruteForceProtected`    | true  | Master switch                    |
| `failureFactor`          | 5     | Failed attempts before lockout   |
| `maxFailureWaitSeconds`  | 900   | 15-minute lockout                |
| `permanentLockout`       | false | Auto-unlock after wait           |
| `passwordHistory`        | 5     | Block last 5 passwords on reuse  |

### What this means for you

After pulling the new images and `docker compose up -d`:

1. The new `keycloak-init` container runs once, applies the hardened settings
   to your existing realm, and exits with `OK — Keycloak realm 'ticketbrainy'
   is hardened`. Check with `docker compose logs keycloak-init`.
2. The custom branded login theme is **automatically re-applied after every
   Keycloak upgrade** — no more manual API patching.
3. If you ever lose the admin password, run
   `./scripts/keycloak-reset-admin.sh --mode recovery 'NewStrongPassword!'`
   from your install directory.

See [docs/KEYCLOAK-ADMIN-RECOVERY.md](docs/KEYCLOAK-ADMIN-RECOVERY.md) for
the full operational runbook.

---

## [1.3.002] — 2026-04-06

### Security — Critical license server hardening

Every response from the TicketBrainy license server is now cryptographically
signed with **Ed25519** and verified by the client on every permission check.
This closes an attack path where a modified `VIGILANCE_KEY_URL` could be
redirected to a local mock server to activate premium plugins without a
valid license.

### What changed under the hood
- The license server signs every `sync` / `fresh-deploy` response with an
  Ed25519 key. The public key is compiled into the TicketBrainy web image.
- The web app refuses any unsigned response or any response whose
  signature does not verify against the embedded public key.
- The `PluginLicense` table has four new nullable columns
  (`signedPayload`, `signature`, `signingKeyId`, `issuedAt`). The database
  migration runs automatically at startup.
- `hasFeature()` re-verifies the stored envelope on every call — a row
  hand-inserted into the database with no envelope no longer grants access.

### What this means for you
**Nothing to configure.** Pull the new images, restart, and click
**Sync** once in *Settings → Plugins* to re-fetch your licenses with
signed envelopes. During the ~10 seconds between the restart and your
first Sync click, premium plugin pages will temporarily show as locked.

See the [update instructions](#update-instructions) below.

---

## [1.3.001] — 2026-04-06

### Added
- **Interactive installer** (`install.sh`) — guided wizard for first-time deployment
- **Built-in Caddy reverse proxy** with automatic Let's Encrypt HTTPS (Mode B)
- **Settings > Deployment** UI — manage domain, HTTPS, and LAN access from the web UI
- **Enterprise Pack** plugin — unlimited users and unlimited mailboxes
- **CIDR support** in `LAN_HOSTS` — allow whole subnets (e.g., `192.168.1.0/24`)
- **Step-by-step Keycloak guide** for users new to SSO ([docs/KEYCLOAK-GUIDE.md](docs/KEYCLOAK-GUIDE.md))
- **Delete deployment** button on the license server admin (cleanup test installations)

### Changed
- **Default port changed from 3000 to 4000** to avoid conflicts with other apps
- **Activation flow simplified** — license check now happens server-side, no more cookie issues
- **Core plan limits enforced** — 3 active users max, 1 mailbox max (upgrade to Enterprise Pack for unlimited)
- **Login page** — local form visibility now based on real client IP (not just URL)
- **Settings menu** — Enterprise Pack moved to "Core" section, CSAT moved to "Productivity"
- All Docker images upgraded to **Node 22** (required for Prisma 7.6)

### Fixed
- Activation infinite loop on fresh installs
- `LAN_HOSTS` not detecting workstation IPs correctly
- Install script ANSI color codes not rendering on some terminals
- Webhook URL validation now blocks internal Docker hostnames
- Keycloak users created via auto-sync are now inactive by default (require admin approval)
- Email notifications now properly escape HTML in customer names and subjects
- File uploads use the validated MIME type to determine the file extension (no client trust)

### Security
- Comprehensive security audit applied
- Stricter role-based access control on admin actions
- Multiple privilege escalation paths fixed
- Content Security Policy (CSP) and Strict Transport Security (HSTS) headers added
- AI service refuses to start if its internal token is missing (fail-closed)

### Removed
- Old `Analytics Pro` plugin renamed to **Enterprise Pack** (now includes unlimited users + mailboxes)
- Legacy cookie-based activation gate

---

## [1.2.001] — 2026-04-05

- Keycloak theme customization
- Mailbox table redesign with status badges
- User invitation flow improvements
- CSAT single-use survey tokens
- Stripe plugin marketplace integration
- Email CC/BCC support

## [1.1.030] — 2026-04-04

- Auto-close inactive tickets workflow
- Email branding and signature customization
- 9 new premium plugins (MVP)
- Plugin feature gating system
- Customer logo upload

## [1.1.020] — 2026-04-04

- Full French i18n
- CSAT manual and automatic surveys
- Service monitor dashboard

---

## Update instructions

To update an existing TicketBrainy installation:

```bash
cd ticketbrainyApp
git pull
docker compose pull
docker compose --profile with-proxy up -d   # If using Caddy
# or
docker compose up -d                        # If behind your own proxy
```

Database migrations run automatically on startup.

### After updating to 1.3.200

The new `keycloak-init` service runs automatically after `up -d`. Verify it
succeeded:

```bash
docker compose logs keycloak-init
# Expected last line:
# [apply-config] OK — Keycloak realm 'ticketbrainy' is hardened
```

If you ever need to re-apply the hardening (e.g. after editing the script):

```bash
docker compose up -d --no-deps keycloak-init
```

### After updating to 1.3.002

Open `Settings → Plugins` in the admin UI and click **Sync** once.
This re-fetches all your licenses with cryptographic signatures so
premium features stay enabled. If you skip this step, premium pages
will show as locked until the next automatic sync.

### Verifying the update

```bash
# Check the installed version
docker compose exec web cat apps/web/package.json | grep '"version"'
# should show: "version": "1.3.200"

# Check that the keycloak hardening sync ran
docker compose logs keycloak-init | tail -5
```
