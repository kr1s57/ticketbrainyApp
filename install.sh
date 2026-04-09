#!/usr/bin/env bash
###############################################################################
#  TicketBrainy — All-in-one Installer
#
#  A single command that takes you from a fresh clone to a running stack:
#   - Checks prerequisites (docker, docker compose, openssl)
#   - Prompts for the handful of values we cannot auto-detect
#   - Delegates secret generation to scripts/generate-secrets.sh
#   - Writes the final .env with robust, CRLF-safe logic
#   - Pulls images, brings the stack up, waits for web to be ready
#   - Prints a clear credentials + URLs block at the end
#
#  Usage:
#    git clone https://github.com/kr1s57/ticketbrainyApp.git
#    cd ticketbrainyApp
#    bash install.sh
###############################################################################

set -euo pipefail

# ── Colours ────────────────────────────────────────────────────────────
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
NC=$'\033[0m'

print_header() {
  echo ""
  echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${BLUE}  $1${NC}"
  echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════════${NC}"
  echo ""
}
print_step()    { echo -e "${CYAN}➜${NC} ${BOLD}$1${NC}"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error()   { echo -e "${RED}✗${NC} $1" >&2; }

# ── Sanity checks ──────────────────────────────────────────────────────
if [ ! -f "docker-compose.yml" ]; then
  print_error "docker-compose.yml not found. Run this script from the repository root."
  exit 1
fi
if [ ! -f ".env.example" ]; then
  print_error ".env.example not found. This repository appears to be incomplete."
  exit 1
fi
if [ ! -f "scripts/generate-secrets.sh" ]; then
  print_error "scripts/generate-secrets.sh not found. This repository appears to be incomplete."
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  print_error "Docker is not installed. Install Docker: https://get.docker.com"
  exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
  print_error "Docker Compose v2 plugin not available."
  echo "  Install: https://docs.docker.com/compose/install/linux/"
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  print_error "Cannot connect to the Docker daemon."
  echo "  Try: sudo systemctl start docker"
  echo "  Or:  sudo usermod -aG docker \$USER  (then log out + in)"
  exit 1
fi
if ! command -v openssl >/dev/null 2>&1; then
  print_error "openssl is required but not installed."
  exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
  print_warning "curl not installed — health checks will fall back to container state only."
fi

# ── Welcome ────────────────────────────────────────────────────────────
print_header "TicketBrainy Installation Wizard"
echo "This will deploy the full TicketBrainy stack on this server."
echo "You will be asked a few questions. Defaults are shown in [brackets]."
echo ""
echo "Press Ctrl+C at any time to cancel."
echo ""

# ── Step 1 — Server address ────────────────────────────────────────────
print_header "Step 1/5 — Server identity"

DETECTED_IP=""
if command -v ip >/dev/null 2>&1; then
  DETECTED_IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}' || true)
fi
if [ -z "$DETECTED_IP" ] && command -v hostname >/dev/null 2>&1; then
  DETECTED_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
fi

print_step "Server IP address"
echo "The IP users will use to reach TicketBrainy from your LAN."
read -rp "Server IP [${DETECTED_IP}]: " SERVER_IP
SERVER_IP=${SERVER_IP:-$DETECTED_IP}
if [ -z "$SERVER_IP" ]; then
  print_error "Server IP is required."
  exit 1
fi
print_success "Server IP: ${SERVER_IP}"

# ── Step 2 — License ───────────────────────────────────────────────────
print_header "Step 2/5 — License"

print_step "License activation email"
echo "The email address registered with your TicketBrainy license."
echo "You will use this email to activate the product in the web wizard."
read -rp "License email: " LICENSE_EMAIL
if [ -z "$LICENSE_EMAIL" ]; then
  print_error "License email is required."
  exit 1
fi
print_success "License email: ${LICENSE_EMAIL}"

# ── Step 3 — Deployment mode ───────────────────────────────────────────
print_header "Step 3/5 — Deployment mode"

echo "How will TicketBrainy be exposed to users?"
echo ""
echo -e "  ${BOLD}A)${NC} Direct — expose TicketBrainy on port 4000"
echo "     Good for LAN deployments, development, or behind an existing"
echo "     reverse proxy / WAF (you handle HTTPS externally)."
echo ""
echo -e "  ${BOLD}B)${NC} Caddy — built-in reverse proxy with automatic Let's Encrypt HTTPS"
echo "     Your server must have ports 80/443 open and your domain must"
echo "     already resolve to this server via a DNS A record."
echo ""
read -rp "Mode [A/B] (default A): " MODE
MODE=${MODE:-A}
MODE=$(echo "$MODE" | tr '[:lower:]' '[:upper:]')

USE_CADDY=false
APP_DOMAIN=""
KEYCLOAK_DOMAIN=""
LETSENCRYPT_EMAIL=""
APP_URL="http://${SERVER_IP}:4000"

if [ "$MODE" = "B" ]; then
  USE_CADDY=true
  print_step "Public domain for TicketBrainy"
  echo "Example: support.yourcompany.com"
  read -rp "App domain: " APP_DOMAIN
  if [ -z "$APP_DOMAIN" ]; then
    print_error "App domain is required for Caddy mode."
    exit 1
  fi
  APP_URL="https://${APP_DOMAIN}"

  print_step "Let's Encrypt notification email"
  echo "Used by Let's Encrypt for certificate-expiration warnings."
  read -rp "Email [${LICENSE_EMAIL}]: " LETSENCRYPT_EMAIL
  LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL:-$LICENSE_EMAIL}
fi
print_success "Mode: $([ "$USE_CADDY" = true ] && echo "Caddy + Let's Encrypt (${APP_DOMAIN})" || echo "Direct (http://${SERVER_IP}:4000)")"

# ── Step 4 — LAN access ────────────────────────────────────────────────
print_header "Step 4/5 — LAN access control"

print_step "Local login form (email + password)"
echo "Which IPs or CIDR ranges should see the local email+password login"
echo "form on the /login page? Everyone outside this list sees SSO only."
echo ""
echo "  Examples:"
echo "    - Single admin PC:      192.168.1.10"
echo "    - Whole LAN subnet:     192.168.1.0/24"
echo "    - Multiple:             192.168.1.10,192.168.1.11"
echo ""
read -rp "LAN hosts [${SERVER_IP}]: " LAN_INPUT
LAN_INPUT=${LAN_INPUT:-$SERVER_IP}
LAN_HOSTS_VALUE="localhost,${SERVER_IP}"
if [ "$LAN_INPUT" != "$SERVER_IP" ]; then
  LAN_HOSTS_VALUE="${LAN_HOSTS_VALUE},${LAN_INPUT}"
fi
print_success "LAN hosts: ${LAN_HOSTS_VALUE}"

# ── Step 5 — Keycloak SSO ──────────────────────────────────────────────
print_header "Step 5/5 — Keycloak SSO (optional)"

echo "Keycloak provides Single Sign-On against Active Directory, LDAP,"
echo "or your own identity provider. You can leave it disabled now and"
echo "enable it later in Settings → Security."
echo ""
read -rp "Enable Keycloak SSO now? [y/N]: " ENABLE_KC
ENABLE_KC=${ENABLE_KC:-N}
ENABLE_KC=$(echo "$ENABLE_KC" | tr '[:lower:]' '[:upper:]')

KEYCLOAK_URL_VALUE=""
if [ "$ENABLE_KC" = "Y" ]; then
  if [ "$USE_CADDY" = true ]; then
    print_step "Public domain for Keycloak"
    echo "Example: auth.yourcompany.com — must resolve to this server."
    read -rp "Keycloak domain: " KEYCLOAK_DOMAIN
    if [ -z "$KEYCLOAK_DOMAIN" ]; then
      print_error "Keycloak domain is required when combining SSO with Caddy mode."
      exit 1
    fi
    KEYCLOAK_URL_VALUE="https://${KEYCLOAK_DOMAIN}"
  else
    print_step "Keycloak public URL"
    echo "The URL users will hit for SSO (typically through your existing WAF)."
    read -rp "Keycloak URL (e.g. https://auth.example.com): " KEYCLOAK_URL_VALUE
    if [ -z "$KEYCLOAK_URL_VALUE" ]; then
      print_error "Keycloak URL is required when SSO is enabled."
      exit 1
    fi
  fi
  print_success "Keycloak SSO: ${KEYCLOAK_URL_VALUE}"
else
  print_success "Keycloak SSO: disabled (local accounts only)"
fi

# ── Write .env ─────────────────────────────────────────────────────────
print_header "Writing configuration"

if [ -f .env ]; then
  TS=$(date +%s)
  cp .env ".env.backup.${TS}"
  print_warning "Existing .env backed up to .env.backup.${TS}"
fi
cp .env.example .env

# Delegate secret generation to the dedicated, tested, CRLF-safe script.
# This is the single source of truth for secret generation — install.sh
# used to duplicate that logic and the two drifted. Never again.
print_step "Generating cryptographic secrets"
bash scripts/generate-secrets.sh > /dev/null
print_success "Secrets generated and verified"

# Robust set-or-insert helper for the remaining [EDIT] fields. Uses grep
# to detect the key then sed to replace the whole line (matches even if
# the placeholder has a trailing comment or CRLF). Escapes sed metachars
# in the value, uses @ as the sed separator.
set_env() {
  local key="$1"
  local value="$2"
  local escaped
  escaped=$(printf '%s' "$value" | sed -e 's/[@&]/\\&/g')
  if grep -q "^${key}=" .env; then
    sed -i "s@^${key}=.*@${key}=${escaped}@" .env
  else
    echo "${key}=${value}" >> .env
  fi
}

print_step "Writing configuration values"
set_env "APP_URL"   "$APP_URL"
set_env "APP_PORT"  "4000"
set_env "LAN_HOSTS" "$LAN_HOSTS_VALUE"

if [ "$ENABLE_KC" = "Y" ]; then
  set_env "KEYCLOAK_URL" "$KEYCLOAK_URL_VALUE"
fi

if [ "$USE_CADDY" = true ]; then
  set_env "APP_DOMAIN"        "$APP_DOMAIN"
  set_env "LETSENCRYPT_EMAIL" "$LETSENCRYPT_EMAIL"
  if [ -n "$KEYCLOAK_DOMAIN" ]; then
    set_env "KEYCLOAK_DOMAIN" "$KEYCLOAK_DOMAIN"
  fi
fi
print_success ".env written"

# ── Pull + up ──────────────────────────────────────────────────────────
print_header "Deploying the stack"

COMPOSE_PROFILE_ARGS=()
if [ "$USE_CADDY" = true ]; then
  COMPOSE_PROFILE_ARGS=(--profile with-proxy)
fi

print_step "Pulling Docker images (this can take a few minutes on first run)"
docker compose "${COMPOSE_PROFILE_ARGS[@]}" pull
print_success "Images pulled"

print_step "Starting services"
docker compose "${COMPOSE_PROFILE_ARGS[@]}" up -d
print_success "Services started"

print_step "Waiting for web service to become ready (up to 180s)"
READY=false
for i in $(seq 1 90); do
  # 1. Is the web container running?
  STATE=$(docker compose ps -q web 2>/dev/null | xargs -r docker inspect -f '{{.State.Running}}' 2>/dev/null || echo "false")
  if [ "$STATE" = "true" ]; then
    # 2. Does it respond on the mapped port? (curl is optional)
    if command -v curl >/dev/null 2>&1; then
      if curl -sf -o /dev/null -m 2 "http://127.0.0.1:4000/api/health" 2>/dev/null \
         || curl -sf -o /dev/null -m 2 "http://127.0.0.1:4000/" 2>/dev/null; then
        READY=true
        break
      fi
    else
      READY=true
      break
    fi
  fi
  sleep 2
done

if [ "$READY" = true ]; then
  print_success "Web service is up"
else
  print_warning "Web service did not respond within 180s — continuing anyway."
  echo "         Inspect with:  docker compose logs -f web"
fi

# ── Read back credentials for display ──────────────────────────────────
# CRITICAL: we read the ACTUAL values from .env, not from shell vars.
# If any step above silently failed, this reveals it instead of printing
# a lie about what is really stored on disk.
SEED_PASS=$(grep '^SEED_ADMIN_PASSWORD=' .env | cut -d= -f2-)
KC_ADMIN_PASS=$(grep '^KC_ADMIN_PASSWORD=' .env | cut -d= -f2-)

# ── Final summary ──────────────────────────────────────────────────────
print_header "Installation Complete"

LAN_URL="http://${SERVER_IP}:4000"
KC_ADMIN_LAN_URL="http://${SERVER_IP}:8180"

echo -e "${BOLD}${CYAN}═════ Access URLs ═════${NC}"
if [ "$USE_CADDY" = true ]; then
  # In Caddy mode APP_URL is https://${APP_DOMAIN}, which is what
  # NEXTAUTH_URL inside the container is set to. The browser's Origin
  # header MUST match this exact URL for CSRF-protected endpoints
  # (activation, server actions) to accept requests. Hitting
  # http://${SERVER_IP}:4000 directly gets rejected with 403 because
  # origins do not match. So we intentionally do NOT display the LAN
  # IP URL here — the only working entry point is the HTTPS domain.
  echo -e "  ${BOLD}Web UI:${NC}              ${GREEN}${APP_URL}${NC}"
  echo -e "  ${BOLD}Activation wizard:${NC}   ${GREEN}${APP_URL}/activate${NC}"
  echo ""
  echo -e "  ${YELLOW}${BOLD}⚠  Caddy mode — the HTTPS URL above is your ONLY access point.${NC}"
  echo -e "  ${YELLOW}   Do NOT open http://${SERVER_IP}:4000 — CSRF checks will reject it.${NC}"
  echo -e "  ${YELLOW}   If the URL above doesn't load yet, verify:${NC}"
  echo -e "  ${YELLOW}     • DNS:  getent hosts ${APP_DOMAIN}${NC}"
  echo -e "  ${YELLOW}     • Cert: docker compose logs caddy | tail -20${NC}"
  echo -e "  ${YELLOW}     • Firewall: ports 80/443 open on your provider${NC}"
else
  echo -e "  ${BOLD}Web UI:${NC}              ${GREEN}${LAN_URL}${NC}"
  echo -e "  ${BOLD}Activation wizard:${NC}   ${GREEN}${LAN_URL}/activate${NC}"
fi
echo ""
echo -e "  ${BOLD}Keycloak admin:${NC}      ${GREEN}${KC_ADMIN_LAN_URL}${NC}"
if [ "$ENABLE_KC" = "Y" ] && [ -n "$KEYCLOAK_URL_VALUE" ]; then
  echo -e "  ${BOLD}Keycloak (SSO):${NC}      ${GREEN}${KEYCLOAK_URL_VALUE}${NC}"
fi
echo ""

echo -e "${BOLD}${YELLOW}═════ TicketBrainy admin (SAVE THIS PASSWORD) ═════${NC}"
echo -e "  Email:      ${CYAN}admin@ticketbrainy.local${NC}"
echo -e "  Password:   ${CYAN}${SEED_PASS}${NC}"
echo ""

echo -e "${BOLD}${YELLOW}═════ Keycloak admin console ═════${NC}"
echo -e "  URL:        ${CYAN}${KC_ADMIN_LAN_URL}${NC}"
echo -e "  Username:   ${CYAN}admin${NC}"
echo -e "  Password:   ${CYAN}${KC_ADMIN_PASS}${NC}"
echo ""

echo -e "${BOLD}═════ Next steps ═════${NC}"
if [ "$USE_CADDY" = true ]; then
  echo "  1. Open ${BOLD}${APP_URL}/activate${NC} in your browser (NOT the IP URL)"
else
  echo "  1. Open ${BOLD}${LAN_URL}/activate${NC} in your browser"
fi
echo "  2. Enter your license email:  ${LICENSE_EMAIL}"
echo "  3. Pick your deployment mode in the wizard (step 2)"
echo "  4. Log in with  admin@ticketbrainy.local  /  (password above)"
echo "  5. Change the admin password in Settings → Team"
echo ""
echo "  To use Keycloak SSO instead of the local admin account:"
echo "   a. Log in once with admin@ticketbrainy.local (above)"
echo "   b. Open ${KC_ADMIN_LAN_URL} — realm 'ticketbrainy' — create your user"
echo "   c. Log out, click 'Single Sign-On' — your first SSO login auto-promotes to ADMIN"
echo ""

echo -e "${BOLD}═════ Useful commands ═════${NC}"
if [ "$USE_CADDY" = true ]; then
  echo "  docker compose --profile with-proxy logs -f    # All logs"
  echo "  docker compose --profile with-proxy restart    # Restart all services"
  echo "  docker compose --profile with-proxy down       # Stop everything"
else
  echo "  docker compose logs -f                         # All logs"
  echo "  docker compose logs -f web                     # Web service only"
  echo "  docker compose restart web                     # Restart the web service"
  echo "  docker compose down                            # Stop everything"
fi
echo ""
echo -e "${GREEN}${BOLD}✓ TicketBrainy is ready.${NC}"
