# Changelog

All notable releases of TicketBrainy.

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
