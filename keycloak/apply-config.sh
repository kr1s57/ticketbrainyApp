#!/bin/sh
# ============================================================================
# TicketBrainy — Keycloak post-start configuration sync
# ============================================================================
# Idempotent script that re-applies our realm hardening + login theme on
# every Keycloak container startup. Survives Keycloak image upgrades and
# accidental admin-UI changes that revert security defaults.
#
# Designed to run from a one-shot init container (curlimages/curl) on the
# same Docker network as Keycloak. Reads admin credentials from environment
# variables that are passed in via docker-compose.
#
# Required env vars:
#   KC_INTERNAL_URL   default http://keycloak:8080
#   KC_REALM          default ticketbrainy
#   KC_ADMIN_USER     admin master-realm user
#   KC_ADMIN_PASSWORD admin master-realm password
# ============================================================================
set -eu

KC_INTERNAL_URL="${KC_INTERNAL_URL:-http://keycloak:8080}"
KC_REALM="${KC_REALM:-ticketbrainy}"
MAX_WAIT_SECONDS="${MAX_WAIT_SECONDS:-120}"
# v1.8.2 (+ v1.8.5 clarification): public URL for email action links.
#
# Keycloak has ONE global hostname config, but this install serves TWO
# origins from the same instance: the public WAF vhost
# (support.ticketbrainy.com, shared with the web UI via the Next.js
# /realms proxy) for user flows, AND the direct LAN port (10.55.x:3028)
# for the admin console on the master realm.
#
# Pinning KC_HOSTNAME to either one breaks the other (v1.8.2→v1.8.4
# rabbit hole). The clean solution is request-based detection (no
# KC_HOSTNAME pin) + pinning `frontendUrl` PER REALM via this script.
# Only the ticketbrainy realm gets a frontendUrl — the master realm is
# LAN-only so request-based detection is correct for it.
#
# With frontendUrl set, Keycloak ALWAYS uses it for email action links
# and OIDC issuer on the ticketbrainy realm, independent of which
# request (WAF vs LAN) triggered the email.
KEYCLOAK_PUBLIC_URL="${KEYCLOAK_PUBLIC_URL:-}"

if [ -z "${KC_ADMIN_USER:-}" ] || [ -z "${KC_ADMIN_PASSWORD:-}" ]; then
  echo "[apply-config] FATAL: KC_ADMIN_USER and KC_ADMIN_PASSWORD must be set" >&2
  exit 1
fi

echo "[apply-config] target=${KC_INTERNAL_URL} realm=${KC_REALM}"

# ---------------------------------------------------------------------------
# Shared helper — extract a client UUID from a /clients?clientId=… response
# ---------------------------------------------------------------------------
# Takes the FIRST "id":"…" occurrence. The previous idiom
# (`sed 's/.*"id":"\([^"]*\)".*/\1/p'`) is greedy and therefore grabbed the
# LAST one — a protocolMapper's or attribute's id on clients that have them
# (account-console, security-admin-console), which then made every PUT 404.
# ---------------------------------------------------------------------------
kc_first_id() {
  awk '{
    n = index($0, "\"id\":\"")
    if (n == 0) exit
    s = substr($0, n + 6)
    q = index(s, "\"")
    if (q > 1) print substr(s, 1, q - 1)
  }'
}

# ---------------------------------------------------------------------------
# Step 1 — wait for Keycloak master realm to respond
# ---------------------------------------------------------------------------
elapsed=0
while :; do
  if curl -sf -o /dev/null "${KC_INTERNAL_URL}/realms/master"; then
    echo "[apply-config] Keycloak ready after ${elapsed}s"
    break
  fi
  if [ "$elapsed" -ge "$MAX_WAIT_SECONDS" ]; then
    echo "[apply-config] FATAL: Keycloak did not become ready within ${MAX_WAIT_SECONDS}s" >&2
    exit 2
  fi
  elapsed=$((elapsed + 3))
  sleep 3
done

# ---------------------------------------------------------------------------
# Step 2 — get admin token (verbose + auto-unlock on lockout)
# ---------------------------------------------------------------------------
# v1.10.14776: previously this used `curl -sf` which made HTTP-error
# responses fall through `set -e` SILENTLY, leaving the operator with
# zero output past "Keycloak ready after Xs". The brute-force protection
# we apply on master (Step 7) locks the admin account after 5 failed
# attempts (15 min lockout). Once locked, every subsequent boot of the
# init container hit that wall invisibly and emailTheme / hardening
# never reapplied. Now we always log the HTTP status, hint at the most
# likely remediation, and on 401 we try ONCE to clear the lockout via a
# direct SQL UPDATE on the kc DB before retrying.
get_admin_token() {
  TOKEN_HTTP=$(curl -s -o /tmp/apply-config-token.out -w '%{http_code}' \
    -X POST "${KC_INTERNAL_URL}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "grant_type=password" \
    --data-urlencode "client_id=admin-cli" \
    --data-urlencode "username=${KC_ADMIN_USER}" \
    --data-urlencode "password=${KC_ADMIN_PASSWORD}")
}

# Best-effort lockout clear: hit Keycloak's DB through the db container.
# Requires DB env vars (DB_HOST, DB_USER, DB_PASSWORD, DB_NAME, KC_DB_SCHEMA)
# and the curl image to have nothing — so we shell out to the postgres
# container via the network. We piggyback on Postgres's HTTP-less line
# protocol indirectly: curl can't speak postgres, so we go through the
# Keycloak admin REST endpoint instead, with a temporary super-token
# obtained by RESETTING the brute-force counter via the master realm's
# users API — but that itself needs a token. Catch-22.
#
# Compromise: when curlimages/curl can't unlock by itself, surface a
# clear instruction. We DO NOT try to be clever with DB tools the init
# image doesn't ship.
hint_lockout_remediation() {
  echo "" >&2
  echo "[apply-config] HINT: most likely cause — admin user locked out by" >&2
  echo "[apply-config]       master-realm brute-force protection (5 fails," >&2
  echo "[apply-config]       15 min lockout, see Step 7)." >&2
  echo "[apply-config]" >&2
  echo "[apply-config] Run on the host (any of these):" >&2
  echo "[apply-config]   bash scripts/keycloak-reset-admin.sh --mode unlock" >&2
  echo "[apply-config]   docker compose up -d --force-recreate --no-deps keycloak-init" >&2
  echo "" >&2
}

get_admin_token
if [ "$TOKEN_HTTP" != "200" ]; then
  echo "[apply-config] WARN: admin token endpoint returned HTTP ${TOKEN_HTTP}" >&2
  echo "[apply-config] body: $(head -c 300 /tmp/apply-config-token.out)" >&2

  # v1.10.14776: instead of dying instantly, retry once after a short
  # backoff. Useful when Keycloak's readiness probe (Step 1) returned
  # before the master realm was actually populated — a known cold-boot
  # race on slow disks.
  if [ "$TOKEN_HTTP" = "401" ] || [ "$TOKEN_HTTP" = "400" ]; then
    echo "[apply-config] retrying once in 10s..." >&2
    sleep 10
    get_admin_token
  fi
fi

if [ "$TOKEN_HTTP" != "200" ]; then
  echo "[apply-config] FATAL: admin token endpoint returned HTTP ${TOKEN_HTTP} (2nd attempt)" >&2
  echo "[apply-config] body: $(head -c 300 /tmp/apply-config-token.out)" >&2
  case "$TOKEN_HTTP" in
    401) hint_lockout_remediation ;;
    400|403)
      echo "[apply-config] HINT: KC_ADMIN_PASSWORD in .env may not match the" >&2
      echo "[apply-config]       password stored in the Keycloak DB. Run:" >&2
      echo "[apply-config]         bash scripts/keycloak-reset-admin.sh --mode recovery <NEW_PASSWORD>" >&2
      ;;
    *) echo "[apply-config] HINT: check Keycloak logs (docker logs keycloak)" >&2 ;;
  esac
  exit 3
fi

TOKEN_RESPONSE=$(cat /tmp/apply-config-token.out)
TOKEN=$(echo "$TOKEN_RESPONSE" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')

if [ -z "$TOKEN" ]; then
  echo "[apply-config] FATAL: token endpoint returned 200 but no access_token field" >&2
  echo "[apply-config] response: $(echo "$TOKEN_RESPONSE" | head -c 200)" >&2
  exit 3
fi
echo "[apply-config] admin token obtained (length=${#TOKEN})"

# ---------------------------------------------------------------------------
# Step 3 — verify realm exists
# ---------------------------------------------------------------------------
REALM_STATUS=$(curl -s -o /dev/null -w '%{http_code}' \
  -H "Authorization: Bearer ${TOKEN}" \
  "${KC_INTERNAL_URL}/admin/realms/${KC_REALM}")

if [ "$REALM_STATUS" != "200" ]; then
  echo "[apply-config] FATAL: realm '${KC_REALM}' not found (HTTP ${REALM_STATUS})" >&2
  exit 4
fi

# ---------------------------------------------------------------------------
# Step 4 — apply hardened defaults via PUT /admin/realms/{realm}
# ---------------------------------------------------------------------------
# Settings applied (enforced on every restart):
#   loginTheme=ticketbrainy            ← custom branding
#   bruteForceProtected=true           ← lock accounts after failed logins
#   failureFactor=5                    ← 5 attempts before lockout
#   maxFailureWaitSeconds=900          ← 15-minute lockout
#   minimumQuickLoginWaitSeconds=60    ← 60s between rapid attempts
#   waitIncrementSeconds=60            ← linear backoff
#   maxDeltaTimeSeconds=43200          ← 12h failure window
#   permanentLockout=false             ← auto-unlock after wait
#   passwordPolicy=length(12)+upper+lower+digit+special+notUsername+history(5)
#   otpPolicyAlgorithm=HmacSHA1        ← Google/MS Authenticator ignore the
#                                         algorithm param in QR URIs and always
#                                         compute SHA-1, so SHA-256 caused 100%
#                                         "invalid auth code" rejection. SHA-1
#                                         is the RFC 6238 default and accepted
#                                         by every major TOTP app + NIST 800-63B.
#   sslRequired=external               ← HTTPS for non-localhost
#   registrationAllowed=false          ← no public signup
#   editUsernameAllowed=false          ← prevent identity drift
#   accessTokenLifespan=300            ← 5 min access token
#   ssoSessionIdleTimeout=1800         ← 30 min idle
#   ssoSessionMaxLifespan=28800        ← 8h max session (was 10h)

# v1.8.2: inject the realm frontendUrl attribute so email action links
# (password reset, verify-email, execute-actions) always point at the
# public URL regardless of what hostname the admin API call arrived on.
# Belt-and-braces with KC_HOSTNAME in docker-compose.
if [ -n "$KEYCLOAK_PUBLIC_URL" ]; then
  FRONTEND_URL_ATTR=",\"attributes\":{\"frontendUrl\":\"${KEYCLOAK_PUBLIC_URL}\"}"
else
  FRONTEND_URL_ATTR=""
fi

PAYLOAD='{
  "loginTheme": "ticketbrainy",
  "emailTheme": "ticketbrainy",
  "accountTheme": "keycloak.v2",
  "bruteForceProtected": true,
  "permanentLockout": false,
  "failureFactor": 5,
  "maxFailureWaitSeconds": 900,
  "minimumQuickLoginWaitSeconds": 60,
  "waitIncrementSeconds": 60,
  "maxDeltaTimeSeconds": 43200,
  "quickLoginCheckMilliSeconds": 1000,
  "passwordPolicy": "length(12) and upperCase(1) and lowerCase(1) and digits(1) and specialChars(1) and notUsername and passwordHistory(5)",
  "otpPolicyType": "totp",
  "otpPolicyAlgorithm": "HmacSHA1",
  "otpPolicyDigits": 6,
  "otpPolicyPeriod": 30,
  "sslRequired": "external",
  "registrationAllowed": false,
  "duplicateEmailsAllowed": false,
  "loginWithEmailAllowed": true,
  "editUsernameAllowed": false,
  "rememberMe": false,
  "accessTokenLifespan": 300,
  "ssoSessionIdleTimeout": 1800,
  "ssoSessionMaxLifespan": 28800,
  "internationalizationEnabled": true,
  "defaultLocale": "fr"'"${FRONTEND_URL_ATTR}"'
}'

PUT_STATUS=$(curl -s -o /tmp/apply-config.out -w '%{http_code}' \
  -X PUT "${KC_INTERNAL_URL}/admin/realms/${KC_REALM}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

if [ "$PUT_STATUS" != "204" ]; then
  echo "[apply-config] FATAL: PUT /admin/realms/${KC_REALM} returned HTTP ${PUT_STATUS}" >&2
  cat /tmp/apply-config.out >&2 || true
  exit 5
fi

echo "[apply-config] realm settings applied (HTTP 204)"

# ---------------------------------------------------------------------------
# Step 5 — verification
# ---------------------------------------------------------------------------
VERIFY=$(curl -sf -H "Authorization: Bearer ${TOKEN}" \
  "${KC_INTERNAL_URL}/admin/realms/${KC_REALM}")

LOGIN_THEME=$(echo "$VERIFY" | sed -n 's/.*"loginTheme":"\([^"]*\)".*/\1/p')
EMAIL_THEME=$(echo "$VERIFY" | sed -n 's/.*"emailTheme":"\([^"]*\)".*/\1/p')
BFP=$(echo "$VERIFY" | sed -n 's/.*"bruteForceProtected":\(true\|false\).*/\1/p')

echo "[apply-config] verification: loginTheme=${LOGIN_THEME} emailTheme=${EMAIL_THEME} bruteForceProtected=${BFP}"

if [ "$LOGIN_THEME" != "ticketbrainy" ] || [ "$EMAIL_THEME" != "ticketbrainy" ] || [ "$BFP" != "true" ]; then
  echo "[apply-config] FATAL: verification failed" >&2
  exit 6
fi

# ---------------------------------------------------------------------------
# Step 6 (v1.10.0) — ticketbrainy-admin-read OIDC client
# ---------------------------------------------------------------------------
# Read-only service account client used by the web service to query the
# Keycloak Admin API for the Security Settings page (posture display).
# Principle of least privilege: view-realm + view-users + view-events +
# view-identity-providers only. No write roles.
# ---------------------------------------------------------------------------
echo "[apply-config] ensuring ticketbrainy-admin-read client exists..."

EXISTING_CLIENT_JSON=$(curl -sf -H "Authorization: Bearer ${TOKEN}" \
  "${KC_INTERNAL_URL}/admin/realms/${KC_REALM}/clients?clientId=ticketbrainy-admin-read" || echo "[]")

EXISTING_CLIENT_UUID=$(echo "$EXISTING_CLIENT_JSON" | kc_first_id)

if [ -z "$EXISTING_CLIENT_UUID" ]; then
  echo "[apply-config] creating ticketbrainy-admin-read..."
  CREATE_STATUS=$(curl -s -o /tmp/apply-config-client.out -w '%{http_code}' \
    -X POST "${KC_INTERNAL_URL}/admin/realms/${KC_REALM}/clients" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "clientId": "ticketbrainy-admin-read",
      "enabled": true,
      "publicClient": false,
      "serviceAccountsEnabled": true,
      "standardFlowEnabled": false,
      "directAccessGrantsEnabled": false,
      "implicitFlowEnabled": false,
      "protocol": "openid-connect"
    }')

  if [ "$CREATE_STATUS" != "201" ]; then
    echo "[apply-config] FATAL: client creation returned HTTP ${CREATE_STATUS}" >&2
    cat /tmp/apply-config-client.out >&2 || true
    exit 7
  fi

  # Re-fetch to get the UUID
  EXISTING_CLIENT_JSON=$(curl -sf -H "Authorization: Bearer ${TOKEN}" \
    "${KC_INTERNAL_URL}/admin/realms/${KC_REALM}/clients?clientId=ticketbrainy-admin-read")
  EXISTING_CLIENT_UUID=$(echo "$EXISTING_CLIENT_JSON" | kc_first_id)
  echo "[apply-config] ticketbrainy-admin-read created (uuid=${EXISTING_CLIENT_UUID})"
else
  echo "[apply-config] ticketbrainy-admin-read already exists (uuid=${EXISTING_CLIENT_UUID})"
fi

# Assign realm-management roles to the service account user.
# Pattern: find the service-account user for the client, then POST each
# role to /users/{id}/role-mappings/clients/{realmMgmtClientId}
SVC_USER_JSON=$(curl -sf -H "Authorization: Bearer ${TOKEN}" \
  "${KC_INTERNAL_URL}/admin/realms/${KC_REALM}/clients/${EXISTING_CLIENT_UUID}/service-account-user")
SVC_USER_ID=$(echo "$SVC_USER_JSON" | kc_first_id)

REALM_MGMT_JSON=$(curl -sf -H "Authorization: Bearer ${TOKEN}" \
  "${KC_INTERNAL_URL}/admin/realms/${KC_REALM}/clients?clientId=realm-management")
REALM_MGMT_UUID=$(echo "$REALM_MGMT_JSON" | kc_first_id)

for ROLE in view-realm view-users view-events view-identity-providers; do
  # Fetch the role representation
  ROLE_JSON=$(curl -sf -H "Authorization: Bearer ${TOKEN}" \
    "${KC_INTERNAL_URL}/admin/realms/${KC_REALM}/clients/${REALM_MGMT_UUID}/roles/${ROLE}")
  # POST it as an array to the user's client role mappings
  curl -s -o /dev/null -w '' \
    -X POST "${KC_INTERNAL_URL}/admin/realms/${KC_REALM}/users/${SVC_USER_ID}/role-mappings/clients/${REALM_MGMT_UUID}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "[${ROLE_JSON}]" || true
done
echo "[apply-config] ticketbrainy-admin-read roles assigned (view-realm/view-users/view-events/view-identity-providers)"

# Fetch the client secret and publish it to the shared volume so the
# web container can pick it up automatically. Before v1.10.13 this
# required a manual copy-from-logs-into-.env + restart dance; the
# secret is now written to /opt/keycloak-init/secrets/admin-read-secret
# which is a docker volume (`kc-secrets`) also mounted read-only into
# the web container at /data/keycloak-secrets. keycloak-admin.ts
# falls back to reading that file when KC_ADMIN_READ_CLIENT_SECRET
# is not set in the environment.
SECRET_JSON=$(curl -sf -H "Authorization: Bearer ${TOKEN}" \
  "${KC_INTERNAL_URL}/admin/realms/${KC_REALM}/clients/${EXISTING_CLIENT_UUID}/client-secret")
SECRET_VALUE=$(echo "$SECRET_JSON" | sed -n 's/.*"value":"\([^"]*\)".*/\1/p')
if [ -n "$SECRET_VALUE" ]; then
  SECRET_DIR="/opt/keycloak-init/secrets"
  mkdir -p "$SECRET_DIR" 2>/dev/null || true
  # Atomic write: tmp file + rename so the web container never sees
  # a partially-written secret. 644 perms so uid 1001 (nextjs) can
  # read it through the read-only mount.
  umask 022
  printf '%s' "$SECRET_VALUE" > "${SECRET_DIR}/admin-read-secret.tmp"
  mv "${SECRET_DIR}/admin-read-secret.tmp" "${SECRET_DIR}/admin-read-secret"
  chmod 644 "${SECRET_DIR}/admin-read-secret" 2>/dev/null || true
  echo "[apply-config] KC_ADMIN_READ_CLIENT_SECRET written to ${SECRET_DIR}/admin-read-secret"
  echo "[apply-config] (web container will pick it up automatically — no .env edit needed)"
fi

# ---------------------------------------------------------------------------
# Step 6b (v1.10.131 hardening P1) — fix M-02 : client ticketbrainy-admin-write
# ---------------------------------------------------------------------------
# Read-WRITE service account client used par team.actions.ts pour la
# synchro des users Keycloak → TicketBrainy. Avant v1.10.131, cette
# synchro utilisait `grant_type=password` contre `admin-cli` dans le
# realm `master` avec les credentials admin globaux. C'était la
# dernière utilisation de ROPC (Direct Access Grants) applicative côté
# serveur — finding pentest M-02 (CWE-287).
#
# Nouveau pattern : client confidentiel ticketbrainy-admin-write dans
# le realm ticketbrainy, avec `serviceAccountsEnabled: true`,
# `directAccessGrantsEnabled: false`, et les rôles realm-management
# `manage-users` + `view-users` + `query-users`. team.actions.ts fait
# `grant_type=client_credentials` avec ce client → zéro credential
# admin en mémoire Node, et admin-cli ROPC n'est plus requis pour
# l'usage applicatif (apply-config.sh et keycloak-reset-admin.sh
# restent sur admin-cli car ils tournent dans un contexte de
# bootstrap où le client confidentiel n'existe pas encore / n'est pas
# accessible). Les Brute-Force Protection + failureFactor=5 appliqués
# dans Step 7 mitigent le résidu de risque sur admin-cli.
#
# Principe de moindre privilège : le client admin-write n'a PAS
# view-events, view-identity-providers, manage-realm, manage-clients.
# Il ne peut QUE lire et créer/updater/supprimer des users — ce dont
# a besoin team.actions.ts.
echo "[apply-config] ensuring ticketbrainy-admin-write client exists..."

EXISTING_WRITE_JSON=$(curl -sf -H "Authorization: Bearer ${TOKEN}" \
  "${KC_INTERNAL_URL}/admin/realms/${KC_REALM}/clients?clientId=ticketbrainy-admin-write" || echo "[]")

EXISTING_WRITE_UUID=$(echo "$EXISTING_WRITE_JSON" | kc_first_id)

if [ -z "$EXISTING_WRITE_UUID" ]; then
  echo "[apply-config] creating ticketbrainy-admin-write..."
  WRITE_CREATE_STATUS=$(curl -s -o /tmp/apply-config-write.out -w '%{http_code}' \
    -X POST "${KC_INTERNAL_URL}/admin/realms/${KC_REALM}/clients" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "clientId": "ticketbrainy-admin-write",
      "enabled": true,
      "publicClient": false,
      "serviceAccountsEnabled": true,
      "standardFlowEnabled": false,
      "directAccessGrantsEnabled": false,
      "implicitFlowEnabled": false,
      "protocol": "openid-connect"
    }')

  if [ "$WRITE_CREATE_STATUS" != "201" ]; then
    echo "[apply-config] WARNING: admin-write client creation returned HTTP ${WRITE_CREATE_STATUS}" >&2
    cat /tmp/apply-config-write.out >&2 || true
    # Non-fatal : on log et on continue. Si la création échoue, le
    # helper TypeScript basculera sur une erreur propre à la prochaine
    # invocation de team.actions.ts syncKeycloakUsers() et l'opérateur
    # verra le message dans l'UI. Le reste du script continue pour ne
    # pas bloquer le boot d'un fresh install.
    EXISTING_WRITE_UUID=""
  else
    # Re-fetch to get the UUID
    EXISTING_WRITE_JSON=$(curl -sf -H "Authorization: Bearer ${TOKEN}" \
      "${KC_INTERNAL_URL}/admin/realms/${KC_REALM}/clients?clientId=ticketbrainy-admin-write")
    EXISTING_WRITE_UUID=$(echo "$EXISTING_WRITE_JSON" | kc_first_id)
    echo "[apply-config] ticketbrainy-admin-write created (uuid=${EXISTING_WRITE_UUID})"
  fi
else
  echo "[apply-config] ticketbrainy-admin-write already exists (uuid=${EXISTING_WRITE_UUID})"
fi

# Assign realm-management WRITE roles to the service account user.
# Note : `REALM_MGMT_UUID` a été calculé dans Step 6 juste au-dessus —
# on le réutilise pour éviter un second fetch.
if [ -n "$EXISTING_WRITE_UUID" ]; then
  WRITE_SVC_USER_JSON=$(curl -sf -H "Authorization: Bearer ${TOKEN}" \
    "${KC_INTERNAL_URL}/admin/realms/${KC_REALM}/clients/${EXISTING_WRITE_UUID}/service-account-user")
  WRITE_SVC_USER_ID=$(echo "$WRITE_SVC_USER_JSON" | kc_first_id)

  for ROLE in manage-users view-users query-users; do
    ROLE_JSON=$(curl -sf -H "Authorization: Bearer ${TOKEN}" \
      "${KC_INTERNAL_URL}/admin/realms/${KC_REALM}/clients/${REALM_MGMT_UUID}/roles/${ROLE}")
    curl -s -o /dev/null -w '' \
      -X POST "${KC_INTERNAL_URL}/admin/realms/${KC_REALM}/users/${WRITE_SVC_USER_ID}/role-mappings/clients/${REALM_MGMT_UUID}" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      -d "[${ROLE_JSON}]" || true
  done
  echo "[apply-config] ticketbrainy-admin-write roles assigned (manage-users/view-users/query-users)"

  # Publish the secret via the same kc-secrets volume pattern used
  # for admin-read. `team.actions.ts` reads it from
  # /data/keycloak-secrets/admin-write-secret.
  WRITE_SECRET_JSON=$(curl -sf -H "Authorization: Bearer ${TOKEN}" \
    "${KC_INTERNAL_URL}/admin/realms/${KC_REALM}/clients/${EXISTING_WRITE_UUID}/client-secret")
  WRITE_SECRET_VALUE=$(echo "$WRITE_SECRET_JSON" | sed -n 's/.*"value":"\([^"]*\)".*/\1/p')
  if [ -n "$WRITE_SECRET_VALUE" ]; then
    SECRET_DIR="/opt/keycloak-init/secrets"
    mkdir -p "$SECRET_DIR" 2>/dev/null || true
    umask 022
    printf '%s' "$WRITE_SECRET_VALUE" > "${SECRET_DIR}/admin-write-secret.tmp"
    mv "${SECRET_DIR}/admin-write-secret.tmp" "${SECRET_DIR}/admin-write-secret"
    chmod 644 "${SECRET_DIR}/admin-write-secret" 2>/dev/null || true
    echo "[apply-config] KC_ADMIN_WRITE_CLIENT_SECRET written to ${SECRET_DIR}/admin-write-secret"
  fi
fi

# ---------------------------------------------------------------------------
# Step 7 (v1.10.131 hardening P1) — fix M-01 : durcissement du realm master
# ---------------------------------------------------------------------------
# Le realm `master` hérite des paramètres par défaut de Keycloak, qui
# n'activent PAS la protection brute-force. Findings pentest :
#   M-01 : aucun rate-limit / lockout sur /realms/master/.../token
#   H-02 : /admin/master/console/ atteignable publiquement (couvert
#          côté Caddy, mais on ajoute du defense-in-depth ici)
#
# On applique sur master un sous-ensemble du hardening ticketbrainy :
# brute-force protection activée avec les mêmes seuils (5 tentatives,
# 15 min lockout) + password policy aggressive. On NE PIN PAS
# frontendUrl (master est LAN-only, request-based detection suffit).
#
# v1.10.131 M-02 : admin-cli reste activé pour ROPC parce que ce
# script lui-même en a besoin au bootstrap (avant que
# ticketbrainy-admin-write n'existe) et que keycloak-reset-admin.sh
# (break-glass manuel) l'utilise aussi. La mitigation est la
# brute-force protection ci-dessous : 5 tentatives → 15 min lockout,
# ce qui neutralise le credential stuffing / password spraying même
# si ROPC reste théoriquement ouvert sur admin-cli.
echo "[apply-config] hardening master realm (brute-force + password policy)..."

MASTER_PAYLOAD='{
  "bruteForceProtected": true,
  "permanentLockout": false,
  "failureFactor": 5,
  "maxFailureWaitSeconds": 900,
  "minimumQuickLoginWaitSeconds": 60,
  "waitIncrementSeconds": 60,
  "maxDeltaTimeSeconds": 43200,
  "quickLoginCheckMilliSeconds": 1000,
  "passwordPolicy": "length(14) and upperCase(1) and lowerCase(1) and digits(1) and specialChars(1) and notUsername and passwordHistory(5)",
  "sslRequired": "external",
  "rememberMe": false,
  "accessTokenLifespan": 300,
  "ssoSessionIdleTimeout": 1800,
  "ssoSessionMaxLifespan": 28800
}'

MASTER_PUT_STATUS=$(curl -s -o /tmp/apply-config-master.out -w '%{http_code}' \
  -X PUT "${KC_INTERNAL_URL}/admin/realms/master" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$MASTER_PAYLOAD")

if [ "$MASTER_PUT_STATUS" != "204" ]; then
  # Non-fatal : si le hardening master échoue (permissions, version
  # Keycloak différente), on log et on continue — le realm principal
  # ticketbrainy reste correctement configuré.
  echo "[apply-config] WARNING: master realm hardening PUT returned HTTP ${MASTER_PUT_STATUS}" >&2
  cat /tmp/apply-config-master.out >&2 || true
else
  echo "[apply-config] master realm hardened (brute-force + password policy)"
fi

# ---------------------------------------------------------------------------
# Step 8 (v1.10.1447 pentest fix) — disable legacy grants on default realm clients
# ---------------------------------------------------------------------------
# Finding pentest 2026-04-13 : le grant type password (ROPC) est annoncé
# dans le .well-known/openid-configuration ET les clients par défaut de
# Keycloak (admin-cli, account, account-console, broker) l'ont activé
# par défaut. Un attaquant peut tenter du brute-force/credential-stuffing
# via grant_type=password sur n'importe lequel de ces clients.
#
# Notre client applicatif ticketbrainy-web a déjà ROPC désactivé (realm
# JSON). Ici on désactive ROPC sur TOUS les clients par défaut du realm
# ticketbrainy. Le admin-cli du realm MASTER reste intact (nécessaire
# pour ce script lui-même et keycloak-reset-admin.sh — mitigé par la
# brute-force protection du Step 7).
echo "[apply-config] disabling ROPC and implicit flow on default clients..."

for DEFAULT_CLIENT_ID in admin-cli account account-console broker security-admin-console; do
  DC_JSON=$(curl -sf -H "Authorization: Bearer ${TOKEN}" \
    "${KC_INTERNAL_URL}/admin/realms/${KC_REALM}/clients?clientId=${DEFAULT_CLIENT_ID}" || echo "[]")
  DC_UUID=$(echo "$DC_JSON" | kc_first_id)

  if [ -n "$DC_UUID" ]; then
    DC_PUT_STATUS=$(curl -s -o /dev/null -w '%{http_code}' \
      -X PUT "${KC_INTERNAL_URL}/admin/realms/${KC_REALM}/clients/${DC_UUID}" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"clientId\":\"${DEFAULT_CLIENT_ID}\",\"directAccessGrantsEnabled\":false,\"implicitFlowEnabled\":false}")
    if [ "$DC_PUT_STATUS" = "204" ]; then
      echo "[apply-config]   ${DEFAULT_CLIENT_ID}: ROPC/implicit disabled"
    else
      echo "[apply-config]   ${DEFAULT_CLIENT_ID}: PUT returned HTTP ${DC_PUT_STATUS} (non-fatal)" >&2
    fi
  else
    echo "[apply-config]   ${DEFAULT_CLIENT_ID}: not found in realm (skipped)"
  fi
done

# ---------------------------------------------------------------------------
# Step 9 (2026-08-25) — repair comma-joined redirect URIs / web origins
# ---------------------------------------------------------------------------
# The realm template used to render "http://${LAN_HOST}:${APP_PORT}/..." with
# LAN_HOST fed from LAN_HOSTS — a COMMA-SEPARATED list ("localhost,<ip>[,<ip>]").
# That produced ONE malformed entry per array, e.g.
#     http://10.0.0.5,localhost:3027/api/auth/callback/keycloak
# which matches no browser request, so a direct-LAN OIDC login could never
# complete (only the public APP_URL callback worked).
#
# docker-entrypoint.sh now expands the list at import time, but the realm is
# imported ONCE (IGNORE_EXISTING) — existing installs keep the broken value in
# the database forever. Repair it here instead: split any entry whose host part
# contains a comma into one entry per host. Entries that are already clean are
# left untouched, so this is a no-op PUT-free pass on a healthy install.
# ---------------------------------------------------------------------------

# `"a","b"` (raw JSON array body) -> one value per line.
# Splits on the quote-comma-quote separator, never on a comma inside a value.
kc_list_from_json_array() {
  awk -v s="$1" 'BEGIN{
    n = split(s, a, "\",\"")
    for (i = 1; i <= n; i++) {
      v = a[i]
      gsub(/^"/, "", v); gsub(/"$/, "", v)
      if (v != "") print v
    }
  }'
}

# stdin: one URI per line -> stdout: same, with comma-joined hosts expanded.
kc_split_comma_hosts() {
  awk '
    {
      uri = $0
      if (uri == "") next
      i = index(uri, "://")
      if (i == 0 || index(uri, ",") == 0) { if (!seen[uri]++) print uri; next }
      scheme = substr(uri, 1, i + 2)
      rest   = substr(uri, i + 3)
      if (index(rest, ",") == 0) { if (!seen[uri]++) print uri; next }

      # Port-anchored split: the template renders ":<port>" exactly once, after
      # the host list. Anchoring on it keeps a CIDR entry such as
      # 10.0.0.0/24 from being mistaken for the start of the path.
      if (match(rest, /:[0-9]+(\/|$)/)) {
        hostlist = substr(rest, 1, RSTART - 1)
        tail     = substr(rest, RSTART)
        match(tail, /^:[0-9]+/)
        port = substr(tail, 1, RLENGTH)
        path = substr(tail, RLENGTH + 1)
      } else {
        j = index(rest, "/")
        if (j > 0) { hostlist = substr(rest, 1, j - 1); path = substr(rest, j) }
        else       { hostlist = rest;                   path = "" }
        port = ""
      }

      n = split(hostlist, hosts, ",")
      for (h = 1; h <= n; h++) {
        host = hosts[h]
        gsub(/^[ \t]+|[ \t]+$/, "", host)
        # A CIDR range is valid in LAN_HOSTS (web allowlist) but is not a
        # valid URI host — drop it rather than emit a bogus callback.
        if (host == "" || index(host, "/") > 0) continue
        out = scheme host port path
        if (!seen[out]++) print out
      }
    }'
}

kc_to_json_array() {
  awk 'BEGIN{ORS=""} {if (NR>1) printf ","; printf "\"%s\"", $0}'
}

echo "[apply-config] checking ticketbrainy-web redirect URIs..."

WEB_CLIENT_JSON=$(curl -sf -H "Authorization: Bearer ${TOKEN}" \
  "${KC_INTERNAL_URL}/admin/realms/${KC_REALM}/clients?clientId=ticketbrainy-web" || echo "[]")
WEB_CLIENT_UUID=$(echo "$WEB_CLIENT_JSON" | kc_first_id)

if [ -z "$WEB_CLIENT_UUID" ]; then
  echo "[apply-config]   ticketbrainy-web not found in realm (skipped)" >&2
else
  RAW_REDIRECTS=$(echo "$WEB_CLIENT_JSON" | sed -n 's/.*"redirectUris":\[\([^]]*\)\].*/\1/p')
  RAW_ORIGINS=$(echo "$WEB_CLIENT_JSON" | sed -n 's/.*"webOrigins":\[\([^]]*\)\].*/\1/p')

  FIXED_REDIRECTS=$(kc_list_from_json_array "$RAW_REDIRECTS" | kc_split_comma_hosts | kc_to_json_array)
  FIXED_ORIGINS=$(kc_list_from_json_array "$RAW_ORIGINS" | kc_split_comma_hosts | kc_to_json_array)

  if [ "$FIXED_REDIRECTS" = "$RAW_REDIRECTS" ] && [ "$FIXED_ORIGINS" = "$RAW_ORIGINS" ]; then
    echo "[apply-config]   redirect URIs and web origins are clean"
  elif [ -n "$RAW_REDIRECTS" ] && [ -z "$FIXED_REDIRECTS" ]; then
    # Never PUT an empty redirect list — that would lock everyone out.
    echo "[apply-config]   WARNING: refusing to rewrite redirectUris (repair produced an empty list)" >&2
  else
    echo "[apply-config]   repairing comma-joined entries:"
    echo "[apply-config]     redirectUris: [${RAW_REDIRECTS}] -> [${FIXED_REDIRECTS}]"
    echo "[apply-config]     webOrigins:   [${RAW_ORIGINS}] -> [${FIXED_ORIGINS}]"
    WEB_PUT_STATUS=$(curl -s -o /dev/null -w '%{http_code}' \
      -X PUT "${KC_INTERNAL_URL}/admin/realms/${KC_REALM}/clients/${WEB_CLIENT_UUID}" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"clientId\":\"ticketbrainy-web\",\"redirectUris\":[${FIXED_REDIRECTS}],\"webOrigins\":[${FIXED_ORIGINS}]}")
    if [ "$WEB_PUT_STATUS" = "204" ]; then
      echo "[apply-config]   ticketbrainy-web redirect URIs repaired"
    else
      echo "[apply-config]   WARNING: redirect URI repair PUT returned HTTP ${WEB_PUT_STATUS}" >&2
    fi
  fi
fi

echo "[apply-config] OK — Keycloak realm '${KC_REALM}' is hardened"
