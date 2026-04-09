#!/usr/bin/env bash
###############################################################################
#  TicketBrainy — Secure Secrets Generator
#
#  Fills every REQUIRED secret in your .env file with a freshly-generated
#  cryptographically random value. Idempotent, CRLF-safe, and verifies
#  every write before exiting.
#
#  Usage:
#    cp .env.example .env
#    bash scripts/generate-secrets.sh
###############################################################################

set -euo pipefail

ENV_FILE=".env"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE not found in current directory." >&2
  echo "       Run from the repository root after: cp .env.example .env" >&2
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "ERROR: openssl is required but not installed." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 1. Normalise line endings. Git clients with core.autocrlf=true (common on
#    Windows and some VPS images) silently convert LF → CRLF on checkout,
#    which breaks '^KEY=$' sed anchors because the trailing \r is *before*
#    end-of-line. Strip any CR so the rest of the script is deterministic.
# ---------------------------------------------------------------------------
if grep -q $'\r' "$ENV_FILE"; then
  echo "Detected CRLF line endings in $ENV_FILE — normalising to LF..."
  sed -i 's/\r$//' "$ENV_FILE"
fi

echo "Generating secure secrets for TicketBrainy..."
echo ""

# ---------------------------------------------------------------------------
# 2. Generate every secret up-front. Using -hex for values that need to
#    survive shell interpolation safely, and -base64 where length/entropy
#    matter more than character set. Stripped characters (=+/) are the ones
#    that are awkward in .env files or URLs.
# ---------------------------------------------------------------------------
# Helper: produce exactly N alphanumeric chars by generating plenty of
# base64 entropy and trimming. Using base64 over more bytes than needed
# guarantees the post-tr output is always >= N chars (each stripped char
# is replaced by reading further into the stream).
alnum() {
  local n="$1"
  openssl rand -base64 $((n * 2)) | tr -d '=+/\n' | head -c "$n"
}

DB_PASSWORD=$(openssl rand -hex 16)
REDIS_PASSWORD=$(alnum 24)
NEXTAUTH_SECRET=$(alnum 44)
ENCRYPTION_MASTER_KEY=$(openssl rand -hex 32)
INTERNAL_SERVICE_TOKEN=$(openssl rand -hex 32)
SEED_ADMIN_PASSWORD=$(alnum 16)
KEYCLOAK_CLIENT_SECRET=$(openssl rand -hex 16)
KC_ADMIN_PASSWORD=$(alnum 16)

# ---------------------------------------------------------------------------
# 3. Robust set-or-insert. Replaces the ENTIRE line for the given key, no
#    matter what placeholder or trailing comment was there. Appends the
#    line if the key is missing. Uses '@' as the sed separator — openssl
#    hex / stripped-base64 output will never contain '@'.
# ---------------------------------------------------------------------------
set_secret() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}=" "$ENV_FILE"; then
    sed -i "s@^${key}=.*@${key}=${value}@" "$ENV_FILE"
  else
    echo "${key}=${value}" >> "$ENV_FILE"
  fi
}

set_secret "DB_PASSWORD"            "$DB_PASSWORD"
set_secret "REDIS_PASSWORD"         "$REDIS_PASSWORD"
set_secret "NEXTAUTH_SECRET"        "$NEXTAUTH_SECRET"
set_secret "ENCRYPTION_MASTER_KEY"  "$ENCRYPTION_MASTER_KEY"
set_secret "INTERNAL_SERVICE_TOKEN" "$INTERNAL_SERVICE_TOKEN"
set_secret "SEED_ADMIN_PASSWORD"    "$SEED_ADMIN_PASSWORD"
set_secret "KEYCLOAK_CLIENT_SECRET" "$KEYCLOAK_CLIENT_SECRET"
set_secret "KC_ADMIN_PASSWORD"      "$KC_ADMIN_PASSWORD"

# ---------------------------------------------------------------------------
# 4. Verify every secret was actually written and is non-empty. This is the
#    critical step the previous script was missing — without it, a silent
#    sed failure left empty values that only surfaced later as mysterious
#    "invalid credentials" errors on first boot.
# ---------------------------------------------------------------------------
verify() {
  local key="$1"
  local line
  line=$(grep "^${key}=" "$ENV_FILE" || true)
  if [ -z "$line" ] || [ "$line" = "${key}=" ]; then
    echo "" >&2
    echo "ERROR: ${key} is missing or empty in ${ENV_FILE} after generation." >&2
    echo "       Please report this bug: https://github.com/kr1s57/ticketbrainyApp/issues" >&2
    exit 1
  fi
}

verify "DB_PASSWORD"
verify "REDIS_PASSWORD"
verify "NEXTAUTH_SECRET"
verify "ENCRYPTION_MASTER_KEY"
verify "INTERNAL_SERVICE_TOKEN"
verify "SEED_ADMIN_PASSWORD"
verify "KEYCLOAK_CLIENT_SECRET"
verify "KC_ADMIN_PASSWORD"

# ---------------------------------------------------------------------------
# 5. Display summary by reading values back FROM THE FILE (not from shell
#    variables). The previous script echoed shell variables, which meant
#    a silent sed failure would show the operator a "successful" summary
#    while the .env contained garbage. Reading from the file is the only
#    honest source of truth.
# ---------------------------------------------------------------------------
show() {
  local key="$1"
  local value
  value=$(grep "^${key}=" "$ENV_FILE" | cut -d= -f2-)
  local preview="${value:0:12}"
  local len=${#value}
  printf "  %-23s = %s… (%d chars)\n" "$key" "$preview" "$len"
}

echo "Secrets generated successfully (values read back from ${ENV_FILE}):"
echo ""
show "DB_PASSWORD"
show "REDIS_PASSWORD"
show "NEXTAUTH_SECRET"
show "ENCRYPTION_MASTER_KEY"
show "INTERNAL_SERVICE_TOKEN"
show "KEYCLOAK_CLIENT_SECRET"
show "KC_ADMIN_PASSWORD"
echo ""
# SEED_ADMIN_PASSWORD is shown in full because the operator must copy it
# manually to log in on first boot, and it is intentionally short.
SEED_VALUE=$(grep '^SEED_ADMIN_PASSWORD=' "$ENV_FILE" | cut -d= -f2-)
echo "  SEED_ADMIN_PASSWORD     = ${SEED_VALUE}"
echo ""
echo "==========================================================================="
echo "IMPORTANT: Save the SEED_ADMIN_PASSWORD above — you need it for first login."
echo "==========================================================================="
echo ""
echo "Next steps:"
echo "  1. Edit the remaining [EDIT] fields in .env:"
echo "       grep -n '\\[EDIT\\]' .env"
echo "  2. docker compose up -d"
echo "  3. Open http://<your-server>:4000/activate in a browser"
