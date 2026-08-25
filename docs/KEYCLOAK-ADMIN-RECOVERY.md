# Keycloak Admin Runbook

Operational playbook for the TicketBrainy Keycloak instance shipped with this
deployment kit. Covers recovery from common lockout scenarios, brute-force
mitigation, login-theme reapplication, and post-upgrade hardening.

> Run all commands from the directory that contains your `docker-compose.yml`
> (the same directory used for `docker compose up -d`).

---

## 1. Hardening sync — what runs automatically

A one-shot `keycloak-init` service ships with `docker-compose.yml`. On every
`docker compose up -d` it:

1. Waits for Keycloak's `master` realm to respond
2. Authenticates with the `KC_ADMIN_USER` / `KC_ADMIN_PASSWORD` from your `.env`
3. PUTs hardened defaults to `/admin/realms/ticketbrainy`:
   - `loginTheme = ticketbrainy` — custom branded login page
   - `bruteForceProtected = true` — 5 failures → 15-minute lockout
   - `passwordPolicy = length(12) + upperCase + lowerCase + digits + specialChars + notUsername + passwordHistory(5)`
   - `otpPolicyAlgorithm = HmacSHA1` — Google/MS Authenticator ignore SHA256
   - `sslRequired = external` — HTTPS required for non-localhost
   - `ssoSessionMaxLifespan = 28800` — max 8 h session
   - `accessTokenLifespan = 300` — 5-minute access tokens
4. Verifies and exits

Result: **after every Keycloak image upgrade or container recreate, the custom
login theme and brute-force protection are re-enforced automatically.**

### Inspect the latest sync run

```bash
docker compose logs keycloak-init
```

Expected last line: `[apply-config] OK — Keycloak realm 'ticketbrainy' is hardened`

### Run it manually

```bash
docker compose up -d --no-deps keycloak-init
docker compose logs keycloak-init
```

> **`--no-deps`** prevents `docker compose` from touching dependencies on a
> drifted state. Volumes are persistent so no data is lost, but for production
> always prefer `--no-deps` when running just the init.

The single source of truth is `keycloak/apply-config.sh` — edit it to change
the hardened defaults, then re-run the init.

---

## 2. Login theme — manual reapply (if sync fails)

The custom theme files live at `keycloak/themes/ticketbrainy/login/` and are
bind-mounted into the Keycloak container.

### Symptom — login page renders the default Keycloak theme (white background)

```bash
# Check whether the files are visible inside the container
docker compose exec keycloak ls /opt/keycloak/themes/ticketbrainy/login/
```

If you see "No such file or directory" or an empty result while the host
directory has content, the bind mount is pointing at a stale (deleted) inode.
This happens when the host directory was deleted and recreated **after** the
container started.

**Fix:** restart the keycloak container — Docker re-binds to the current inode,
then re-run the hardening sync.

```bash
docker compose restart keycloak
docker compose up -d --no-deps keycloak-init
```

Diagnostic command (run from the host):

```bash
KC_PID=$(docker inspect "$(docker compose ps -q keycloak)" --format '{{.State.Pid}}')
cat /proc/$KC_PID/mountinfo | grep theme
```

If you see `//deleted` in the source path, that confirms the stale-inode bug.

---

## 3. Admin password recovery (`scripts/keycloak-reset-admin.sh`)

The script auto-detects the running keycloak container and Docker network — no
configuration needed beyond running it from your install directory.

### Scenario A — Admin is brute-force locked but the password is still known

```bash
./scripts/keycloak-reset-admin.sh --mode unlock
```

Clears the brute-force lockout state for the admin user. The password is
unchanged.

### Scenario B — Rotate admin password (current password known)

```bash
./scripts/keycloak-reset-admin.sh --mode api 'NEW_STRONG_PASSWORD'
```

Logs in with the current `KC_ADMIN_PASSWORD` from `.env` and sets a new
password via the admin REST API. After a successful run:

1. Update `KC_ADMIN_PASSWORD` in your `.env` to the new value
2. Re-run the init sync so future restarts use the new credentials:
   ```bash
   docker compose up -d --no-deps keycloak-init
   ```

### Scenario C — Admin password is genuinely lost

```bash
./scripts/keycloak-reset-admin.sh --mode recovery 'NEW_STRONG_PASSWORD'
```

Procedure executed by the script:

1. Stops the running keycloak container
2. Spawns a temporary `quay.io/keycloak/keycloak:26.7.2` container on the same
   network and database, with bootstrap-admin env vars set to a randomly
   generated recovery account
3. Authenticates as the recovery account against the `master` realm
4. Resets the real admin's password via the admin API
5. **Deletes the temporary recovery account** so no orphan admins remain
6. Tears down the recovery container and restarts the real Keycloak

After the script finishes:

1. Update `KC_ADMIN_PASSWORD` in your `.env` to the value you passed
2. Run `docker compose up -d --no-deps keycloak-init` to verify the new credentials work
3. **Audit** — `docker compose logs keycloak | grep -i 'admin'` to confirm no
   suspicious account was created during the recovery window

---

## 4. End-user account lockouts

When an end user (not the admin) gets locked out by brute force after 5 failed
attempts, Keycloak holds the lockout for 15 minutes (`maxFailureWaitSeconds`).

### Manual unlock from the admin console

1. Sign in to the Keycloak admin URL (`KC_PORT` from your `.env`, default 8180)
2. Realm `ticketbrainy` → Users → search → user → tab **Credentials**
3. Status section → click **Unlock user**

---

## 5. Brute-force protection — what's enforced

| Setting                       | Value | Meaning                              |
|-------------------------------|-------|--------------------------------------|
| `bruteForceProtected`         | true  | Master switch                        |
| `failureFactor`               | 5     | Failed attempts before lockout       |
| `maxFailureWaitSeconds`       | 900   | Lockout duration ceiling (15 min)    |
| `minimumQuickLoginWaitSeconds`| 60    | Wait between rapid attempts          |
| `waitIncrementSeconds`        | 60    | Linear backoff per failure           |
| `maxDeltaTimeSeconds`         | 43200 | Failure-counter reset window (12 h)  |
| `quickLoginCheckMilliSeconds` | 1000  | Throttle threshold for fast bots     |
| `permanentLockout`            | false | Auto-unlock after wait period        |

These values are PUT by `keycloak/apply-config.sh` on every `up -d`. To change
them, edit that script — manual changes via the Keycloak admin UI will be
overridden by the next sync.

### Enable security event logging (recommended)

The hardening sync does not change the event-logging configuration. Enable it
once via the admin console:

1. Realm settings → Events → User events settings
2. Save events: ON
3. Saved types: `LOGIN`, `LOGIN_ERROR`, `LOGOUT`, `REGISTER`, `UPDATE_PASSWORD`
4. Expiration: 30 days

---

## 6. After a Keycloak image upgrade

```bash
# 1. Pull a new Keycloak image (or change tag in docker-compose.yml)
docker compose pull keycloak

# 2. Recreate keycloak (re-binds theme volume to current host inode)
#    --force-recreate is REQUIRED: without it Compose may consider the
#    service up-to-date and skip entrypoint/theme changes.
docker compose up -d --force-recreate keycloak

# 3. Wait until ready, then re-apply the hardened settings
docker compose up -d --no-deps keycloak-init
docker compose logs keycloak-init

# 4. Smoke-test the login page
docker compose exec keycloak \
  curl -sfo /dev/null -w '%{http_code}\n' \
  http://localhost:8080/realms/ticketbrainy/account || true
```

The init container is idempotent — running it after every upgrade is safe.

---

## 7. Quick reference

```bash
# Full Keycloak hard-restart with re-hardening
docker compose restart keycloak
docker compose up -d --no-deps keycloak-init

# Inspect the live realm settings
docker compose exec keycloak sh -c '
TOKEN=$(curl -sf -X POST http://localhost:8080/realms/master/protocol/openid-connect/token \
  -d grant_type=password -d client_id=admin-cli \
  -d username=$KC_BOOTSTRAP_ADMIN_USERNAME \
  --data-urlencode "password=$KC_BOOTSTRAP_ADMIN_PASSWORD" \
  | sed -n "s/.*\"access_token\":\"\([^\"]*\)\".*/\1/p")
curl -sf http://localhost:8080/admin/realms/ticketbrainy \
  -H "Authorization: Bearer $TOKEN"
' 2>/dev/null
```

---

## 8. CVE-2026-18963 — account takeover via "Forgot password"

> **Disclosed** 2026-08-19 · **CVSS 9.1 (critical)** · **Affected** Keycloak
> `26.0.0` → `26.7.1` · **Fixed** `26.7.2` (Red Hat build: `26.4.15` / `26.6.6`)

**What it is.** Keycloak's `reset-credentials` flow does not properly validate
its own state. An unauthenticated remote attacker can drive the flow to the
"set a new password" step for *any* known username or e-mail **without ever
receiving or clicking the reset e-mail**, then set credentials and take over the
account. No victim interaction is required.

**Your exposure.** Every TicketBrainy deployment kit up to and including
`1.11.52` pinned `quay.io/keycloak/keycloak:26.2`, and the `ticketbrainy` realm
allows self-service password reset on the public `auth.<domain>` frontend.
**Assume you are affected and patch.**

### 8.1 Patch

The compose file now pins `26.7.2`. From your deployment directory:

```bash
git pull
docker compose pull keycloak
docker compose up -d --force-recreate keycloak
docker compose up -d --no-deps keycloak-init     # re-apply hardened realm settings

# Confirm the running build (must NOT print 26.0–26.7.1)
docker compose exec keycloak /opt/keycloak/bin/kc.sh --version
```

Keycloak migrates its own database schema on first boot — no manual migration
step. TicketBrainy's application images are unchanged by this advisory.

### 8.2 Temporary mitigation (ONLY if you cannot patch today)

Admin console → realm `ticketbrainy` → *Realm settings* → *Login* →
**Forgot password = Off**. Repeat for the `master` realm.

This disables self-service password reset for your end users, so it is a
stopgap — switch it back `On` once you are running `26.7.2`.

### 8.3 Post-patch checklist

1. **Rotate the Keycloak admin password** (see section 3), then update
   `KC_ADMIN_PASSWORD` in your `.env` and re-run `keycloak-init`.

2. **Force everyone to log in again.** An account compromised before the patch
   may still hold a valid session or refresh token:

   ```bash
   docker compose exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
     --server http://localhost:8080 --realm master \
     --user "$KC_ADMIN_USER" --password "$KC_ADMIN_PASSWORD"
   docker compose exec keycloak /opt/keycloak/bin/kcadm.sh create \
     realms/ticketbrainy/logout-all
   ```

3. **Require a password change** on any account whose credentials were reset in
   the exposure window (see 8.4):

   ```bash
   docker compose exec keycloak /opt/keycloak/bin/kcadm.sh update \
     users/<USER_ID> -r ticketbrainy -s 'requiredActions=["UPDATE_PASSWORD"]'
   ```

### 8.4 Detection signals

Keycloak login events are the audit trail:

```bash
docker compose exec keycloak /opt/keycloak/bin/kcadm.sh get \
  'events?realm=ticketbrainy&type=UPDATE_PASSWORD&type=RESET_PASSWORD&type=SEND_RESET_PASSWORD&type=EXECUTE_ACTION_TOKEN&max=500' \
  -r ticketbrainy
```

Red flags:

- `UPDATE_PASSWORD` / `RESET_PASSWORD` with **no preceding
  `SEND_RESET_PASSWORD`** for the same `userId` — the e-mail step was skipped.
- Many `RESET_PASSWORD_ERROR` / `EXECUTE_ACTION_TOKEN_ERROR` from a single
  `ipAddress` — someone probing the flow.
- A `LOGIN` from a new `ipAddress` right after a reset the user never requested.
- Reset traffic outside business hours, or aimed at admin/agent accounts.

> Empty event list? Event storage is off. Enable it in
> *Realm settings → Sessions/Events → User events enabled*, `Expiration = 30 days`.
