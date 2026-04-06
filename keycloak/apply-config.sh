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
  "defaultLocale": "fr"
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

echo "[apply-config] OK — Keycloak realm '${KC_REALM}' is hardened"
