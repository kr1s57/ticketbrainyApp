# Changelog

All notable releases of TicketBrainy.

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
