# Changelog

All notable releases of TicketBrainy.

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
