#!/bin/bash
# ============================================================================
# TicketBrainy — Keycloak admin password recovery
# ============================================================================
# Recovery toolkit for the Keycloak master-realm admin user. Three modes
# depending on whether the current admin password is known:
#
#   ./keycloak-reset-admin.sh --mode api      <NEW_PASSWORD>
#       Logs in to Keycloak's master realm with the existing
#       KC_ADMIN_PASSWORD from .env and resets the admin user's password
#       via the admin REST API.
#       Use when: admin is locked by brute force, or you simply want to
#       rotate the password while you still have valid credentials.
#
#   ./keycloak-reset-admin.sh --mode recovery <NEW_PASSWORD>
#       Spawns a temporary recovery admin via KC_BOOTSTRAP_ADMIN_* env
#       vars on a one-shot Keycloak container, then uses that account to
#       reset the real admin password and disables/deletes the temporary
#       account.
#       Use when: the .env KC_ADMIN_PASSWORD is lost or no longer accepted.
#
#   ./keycloak-reset-admin.sh --mode unlock
#       Clears brute-force lockout state for the admin user without
#       changing the password. Use when admin is locked but the password
#       is still known.
#
# Run this script from the directory containing your docker-compose.yml.
# It auto-detects the Keycloak container and Docker network — no need to
# hard-code container names.
#
# After a successful reset you MUST update KC_ADMIN_PASSWORD in your .env
# and re-run the hardening sync so the new credentials are picked up:
#   docker compose up -d --no-deps keycloak-init
# ============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

if [ ! -f docker-compose.yml ]; then
  echo -e "${RED}FATAL: docker-compose.yml not found in $PROJECT_DIR${NC}" >&2
  echo -e "${YELLOW}Run this script from your TicketBrainy install directory${NC}" >&2
  exit 1
fi

if [ ! -f .env ]; then
  echo -e "${RED}FATAL: .env not found in $PROJECT_DIR${NC}" >&2
  exit 1
fi

# shellcheck disable=SC1091
set -a; . ./.env; set +a

KC_ADMIN_USER="${KC_ADMIN_USER:-admin}"

usage() {
  sed -n '4,32p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

# ---------------------------------------------------------------------------
# Auto-detect Keycloak container + network from current compose project
# ---------------------------------------------------------------------------
KC_CONTAINER=$(docker compose ps -q keycloak 2>/dev/null || true)
if [ -z "$KC_CONTAINER" ]; then
  echo -e "${YELLOW}Warning: keycloak container not running — bringing it up${NC}"
  docker compose up -d keycloak
  sleep 5
  KC_CONTAINER=$(docker compose ps -q keycloak)
  if [ -z "$KC_CONTAINER" ]; then
    echo -e "${RED}FATAL: could not start the keycloak service${NC}" >&2
    exit 2
  fi
fi

NETWORK=$(docker inspect "$KC_CONTAINER" \
  --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{"\n"}}{{end}}' \
  | head -1)

if [ -z "$NETWORK" ]; then
  echo -e "${RED}FATAL: could not detect the keycloak Docker network${NC}" >&2
  exit 3
fi

echo -e "${GREEN}✓ Detected keycloak container: $KC_CONTAINER${NC}"
echo -e "${GREEN}✓ Detected Docker network: $NETWORK${NC}"

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
MODE=""
NEW_PASSWORD=""
while [ $# -gt 0 ]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) NEW_PASSWORD="$1"; shift ;;
  esac
done
[ -z "$MODE" ] && usage

# ---------------------------------------------------------------------------
# Helpers — all curl calls run inside an ephemeral curlimages/curl container
# attached to the keycloak network so the script has zero host dependencies.
# ---------------------------------------------------------------------------
get_token() {
  local user="$1" pass="$2"
  docker run --rm --network "$NETWORK" curlimages/curl:8.10.1 \
    -sf -X POST "http://keycloak:8080/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "grant_type=password" \
    --data-urlencode "client_id=admin-cli" \
    --data-urlencode "username=$user" \
    --data-urlencode "password=$pass" \
    | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p'
}

reset_password_via_api() {
  local token="$1" target_user="$2" new_pass="$3"
  local user_id
  user_id=$(docker run --rm --network "$NETWORK" curlimages/curl:8.10.1 \
    -sf -H "Authorization: Bearer $token" \
    "http://keycloak:8080/admin/realms/master/users?username=${target_user}&exact=true" \
    | sed -n 's/.*"id":"\([^"]*\)".*/\1/p' | head -1)

  if [ -z "$user_id" ]; then
    echo -e "${RED}FATAL: user '$target_user' not found in master realm${NC}" >&2
    return 4
  fi
  echo "  user_id=$user_id"

  docker run --rm --network "$NETWORK" curlimages/curl:8.10.1 \
    -sf -o /dev/null -w '  reset HTTP %{http_code}\n' \
    -X PUT "http://keycloak:8080/admin/realms/master/users/${user_id}/reset-password" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "{\"type\":\"password\",\"value\":\"${new_pass}\",\"temporary\":false}"

  docker run --rm --network "$NETWORK" curlimages/curl:8.10.1 \
    -sf -o /dev/null -w '  unlock HTTP %{http_code}\n' \
    -X DELETE "http://keycloak:8080/admin/realms/master/attack-detection/brute-force/users/${user_id}" \
    -H "Authorization: Bearer $token" || true
}

# ---------------------------------------------------------------------------
# Mode dispatch
# ---------------------------------------------------------------------------
case "$MODE" in

  api)
    [ -z "$NEW_PASSWORD" ] && { echo -e "${RED}--mode api requires <NEW_PASSWORD>${NC}" >&2; exit 1; }
    if [ -z "${KC_ADMIN_PASSWORD:-}" ]; then
      echo -e "${RED}FATAL: KC_ADMIN_PASSWORD not in .env — try --mode recovery${NC}" >&2
      exit 5
    fi
    echo -e "${YELLOW}→ API mode: resetting password for '$KC_ADMIN_USER'${NC}"
    TOKEN=$(get_token "$KC_ADMIN_USER" "$KC_ADMIN_PASSWORD" || true)
    if [ -z "$TOKEN" ]; then
      echo -e "${RED}FATAL: failed to authenticate with current KC_ADMIN_PASSWORD${NC}" >&2
      echo -e "${YELLOW}If brute-force locked: ./keycloak-reset-admin.sh --mode unlock${NC}" >&2
      echo -e "${YELLOW}If password lost:      ./keycloak-reset-admin.sh --mode recovery <NEW>${NC}" >&2
      exit 6
    fi
    reset_password_via_api "$TOKEN" "$KC_ADMIN_USER" "$NEW_PASSWORD"
    echo -e "${GREEN}✓ Password reset via API${NC}"
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "  1. Update KC_ADMIN_PASSWORD in $PROJECT_DIR/.env"
    echo -e "  2. docker compose up -d --no-deps keycloak-init"
    ;;

  recovery)
    [ -z "$NEW_PASSWORD" ] && { echo -e "${RED}--mode recovery requires <NEW_PASSWORD>${NC}" >&2; exit 1; }
    echo -e "${YELLOW}→ Recovery mode: spawning temporary bootstrap admin${NC}"
    TEMP_USER="recovery-$(date +%s)"
    TEMP_PASS="Recovery!$(openssl rand -base64 12 | tr -d '/+=' | head -c 16)"

    echo -e "${YELLOW}→ Stopping keycloak container${NC}"
    docker stop "$KC_CONTAINER" >/dev/null

    echo -e "${YELLOW}→ Spawning recovery instance on the same network/db${NC}"
    docker run --rm -d --name ticketbrainy-keycloak-recovery \
      --network "$NETWORK" \
      -e KC_BOOTSTRAP_ADMIN_USERNAME="$TEMP_USER" \
      -e KC_BOOTSTRAP_ADMIN_PASSWORD="$TEMP_PASS" \
      -e KC_DB=postgres \
      -e KC_DB_URL="jdbc:postgresql://db:5432/${DB_NAME:-ticketbrainy}?currentSchema=${KC_DB_SCHEMA:-keycloak}" \
      -e KC_DB_USERNAME="${DB_USER:-ticketbrainy}" \
      -e KC_DB_PASSWORD="${DB_PASSWORD}" \
      -e KC_HOSTNAME_STRICT=false \
      -e KC_HTTP_ENABLED=true \
      quay.io/keycloak/keycloak:26.2 start >/dev/null

    echo -e "${YELLOW}→ Waiting for recovery instance...${NC}"
    for i in $(seq 1 60); do
      if docker run --rm --network "$NETWORK" curlimages/curl:8.10.1 \
          -sf -o /dev/null "http://ticketbrainy-keycloak-recovery:8080/realms/master" 2>/dev/null; then
        echo "  ready after ${i}s"; break
      fi
      sleep 2
    done

    TOKEN=$(docker run --rm --network "$NETWORK" curlimages/curl:8.10.1 \
      -sf -X POST "http://ticketbrainy-keycloak-recovery:8080/realms/master/protocol/openid-connect/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      --data-urlencode "grant_type=password" \
      --data-urlencode "client_id=admin-cli" \
      --data-urlencode "username=$TEMP_USER" \
      --data-urlencode "password=$TEMP_PASS" \
      | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')

    if [ -z "$TOKEN" ]; then
      echo -e "${RED}FATAL: temp admin login failed — check container logs:${NC}" >&2
      echo "  docker logs ticketbrainy-keycloak-recovery" >&2
      docker stop ticketbrainy-keycloak-recovery >/dev/null 2>&1 || true
      docker compose up -d keycloak
      exit 7
    fi

    USER_ID=$(docker run --rm --network "$NETWORK" curlimages/curl:8.10.1 \
      -sf -H "Authorization: Bearer $TOKEN" \
      "http://ticketbrainy-keycloak-recovery:8080/admin/realms/master/users?username=${KC_ADMIN_USER}&exact=true" \
      | sed -n 's/.*"id":"\([^"]*\)".*/\1/p' | head -1)

    if [ -z "$USER_ID" ]; then
      echo -e "${RED}FATAL: real admin '$KC_ADMIN_USER' not found in master realm${NC}" >&2
      docker stop ticketbrainy-keycloak-recovery >/dev/null 2>&1 || true
      docker compose up -d keycloak
      exit 8
    fi

    docker run --rm --network "$NETWORK" curlimages/curl:8.10.1 \
      -sf -o /dev/null -w '  reset HTTP %{http_code}\n' \
      -X PUT "http://ticketbrainy-keycloak-recovery:8080/admin/realms/master/users/${USER_ID}/reset-password" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"type\":\"password\",\"value\":\"${NEW_PASSWORD}\",\"temporary\":false}"

    docker run --rm --network "$NETWORK" curlimages/curl:8.10.1 \
      -sf -o /dev/null -w '  unlock HTTP %{http_code}\n' \
      -X DELETE "http://ticketbrainy-keycloak-recovery:8080/admin/realms/master/attack-detection/brute-force/users/${USER_ID}" \
      -H "Authorization: Bearer $TOKEN" || true

    # Delete the temporary recovery account
    TEMP_USER_ID=$(docker run --rm --network "$NETWORK" curlimages/curl:8.10.1 \
      -sf -H "Authorization: Bearer $TOKEN" \
      "http://ticketbrainy-keycloak-recovery:8080/admin/realms/master/users?username=${TEMP_USER}&exact=true" \
      | sed -n 's/.*"id":"\([^"]*\)".*/\1/p' | head -1)
    if [ -n "$TEMP_USER_ID" ]; then
      docker run --rm --network "$NETWORK" curlimages/curl:8.10.1 \
        -sf -o /dev/null -w '  delete temp HTTP %{http_code}\n' \
        -X DELETE "http://ticketbrainy-keycloak-recovery:8080/admin/realms/master/users/${TEMP_USER_ID}" \
        -H "Authorization: Bearer $TOKEN" || true
    fi

    echo -e "${YELLOW}→ Tearing down recovery instance, restarting real keycloak${NC}"
    docker stop ticketbrainy-keycloak-recovery >/dev/null 2>&1 || true
    docker compose up -d keycloak

    echo -e "${GREEN}✓ Admin password reset via recovery mode${NC}"
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "  1. Update KC_ADMIN_PASSWORD in $PROJECT_DIR/.env to:"
    echo -e "     ${NEW_PASSWORD}"
    echo -e "  2. docker compose up -d --no-deps keycloak-init"
    ;;

  unlock)
    if [ -z "${KC_ADMIN_PASSWORD:-}" ]; then
      echo -e "${RED}FATAL: KC_ADMIN_PASSWORD not in .env${NC}" >&2
      exit 5
    fi
    echo -e "${YELLOW}→ Unlock mode: clearing brute-force lockout for '$KC_ADMIN_USER'${NC}"
    TOKEN=$(get_token "$KC_ADMIN_USER" "$KC_ADMIN_PASSWORD" || true)
    if [ -z "$TOKEN" ]; then
      echo -e "${RED}FATAL: cannot authenticate (account hard-locked or password lost)${NC}" >&2
      exit 6
    fi
    USER_ID=$(docker run --rm --network "$NETWORK" curlimages/curl:8.10.1 \
      -sf -H "Authorization: Bearer $TOKEN" \
      "http://keycloak:8080/admin/realms/master/users?username=${KC_ADMIN_USER}&exact=true" \
      | sed -n 's/.*"id":"\([^"]*\)".*/\1/p' | head -1)
    docker run --rm --network "$NETWORK" curlimages/curl:8.10.1 \
      -sf -o /dev/null -w '  unlock HTTP %{http_code}\n' \
      -X DELETE "http://keycloak:8080/admin/realms/master/attack-detection/brute-force/users/${USER_ID}" \
      -H "Authorization: Bearer $TOKEN"
    echo -e "${GREEN}✓ Lockout cleared for $KC_ADMIN_USER${NC}"
    ;;

  *)
    echo -e "${RED}Unknown mode: $MODE${NC}" >&2
    usage
    ;;
esac
