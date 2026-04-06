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
   - `otpPolicyAlgorithm = HmacSHA256` (upgraded from default `HmacSHA1`)
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
2. Spawns a temporary `quay.io/keycloak/keycloak:26.2` container on the same
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
docker compose up -d keycloak

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
