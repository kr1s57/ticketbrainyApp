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
# Step 2 — get admin token
# ---------------------------------------------------------------------------
TOKEN_RESPONSE=$(curl -sf -X POST \
  "${KC_INTERNAL_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=password" \
  --data-urlencode "client_id=admin-cli" \
  --data-urlencode "username=${KC_ADMIN_USER}" \
  --data-urlencode "password=${KC_ADMIN_PASSWORD}")

TOKEN=$(echo "$TOKEN_RESPONSE" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')

if [ -z "$TOKEN" ]; then
  echo "[apply-config] FATAL: failed to obtain admin token" >&2
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
#   otpPolicyAlgorithm=HmacSHA256      ← upgrade from default HmacSHA1
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
  "otpPolicyAlgorithm": "HmacSHA256",
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
BFP=$(echo "$VERIFY" | sed -n 's/.*"bruteForceProtected":\(true\|false\).*/\1/p')

echo "[apply-config] verification: loginTheme=${LOGIN_THEME} bruteForceProtected=${BFP}"

if [ "$LOGIN_THEME" != "ticketbrainy" ] || [ "$BFP" != "true" ]; then
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

EXISTING_CLIENT_UUID=$(echo "$EXISTING_CLIENT_JSON" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p' | head -n1)

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
  EXISTING_CLIENT_UUID=$(echo "$EXISTING_CLIENT_JSON" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p' | head -n1)
  echo "[apply-config] ticketbrainy-admin-read created (uuid=${EXISTING_CLIENT_UUID})"
else
  echo "[apply-config] ticketbrainy-admin-read already exists (uuid=${EXISTING_CLIENT_UUID})"
fi

# Assign realm-management roles to the service account user.
# Pattern: find the service-account user for the client, then POST each
# role to /users/{id}/role-mappings/clients/{realmMgmtClientId}
SVC_USER_JSON=$(curl -sf -H "Authorization: Bearer ${TOKEN}" \
  "${KC_INTERNAL_URL}/admin/realms/${KC_REALM}/clients/${EXISTING_CLIENT_UUID}/service-account-user")
SVC_USER_ID=$(echo "$SVC_USER_JSON" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p' | head -n1)

REALM_MGMT_JSON=$(curl -sf -H "Authorization: Bearer ${TOKEN}" \
  "${KC_INTERNAL_URL}/admin/realms/${KC_REALM}/clients?clientId=realm-management")
REALM_MGMT_UUID=$(echo "$REALM_MGMT_JSON" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p' | head -n1)

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

echo "[apply-config] OK — Keycloak realm '${KC_REALM}' is hardened"
