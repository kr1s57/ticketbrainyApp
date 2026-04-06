#!/bin/bash
###############################################################################
#  TicketBrainy — Interactive Installation Script
#
#  Usage:  bash install.sh
#
#  Guides you through the full setup:
#   - Generates all secrets
#   - Configures LAN access (Keycloak admin + local login form)
#   - Optional Caddy reverse proxy + Let's Encrypt HTTPS
#   - Starts all Docker services
#   - Displays admin credentials
###############################################################################

set -e

# ── Colors (using $'...' so escape codes are resolved at definition) ──
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

print_step() {
  echo -e "${CYAN}➜${NC} ${BOLD}$1${NC}"
}

print_success() {
  echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
  echo -e "${RED}✗${NC} $1"
}

# ── Sanity checks ──────────────────────────────────────────────────────
if [ ! -f "docker-compose.yml" ]; then
  print_error "docker-compose.yml not found. Run this script from the ticketbrainyApp directory."
  exit 1
fi

print_header "TicketBrainy Installation Wizard"
echo "This script will guide you through the complete deployment."
echo "You will be asked several questions — default values are shown in [brackets]."
echo ""
echo "Press Ctrl+C at any time to cancel."
echo ""
read -p "Press Enter to start..."

# ── Step 1: Check Docker ───────────────────────────────────────────────
print_header "Step 1/6 — Checking prerequisites"

if ! command -v docker &> /dev/null; then
  print_error "Docker is not installed."
  echo "Install Docker first: https://get.docker.com"
  exit 1
fi
print_success "Docker installed: $(docker --version)"

if ! docker compose version &> /dev/null; then
  print_error "Docker Compose plugin not found."
  echo "Install the Docker Compose plugin: https://docs.docker.com/compose/install/"
  exit 1
fi
print_success "Docker Compose installed: $(docker compose version)"

if ! docker info &> /dev/null; then
  print_error "Cannot connect to Docker daemon. Is it running? Are you in the docker group?"
  echo "Try: sudo systemctl start docker && sudo usermod -aG docker \$USER (then log out/in)"
  exit 1
fi
print_success "Docker daemon is running"

if ! command -v openssl &> /dev/null; then
  print_error "openssl is required to generate secrets"
  exit 1
fi
print_success "openssl available"

# ── Step 2: Gather info ────────────────────────────────────────────────
print_header "Step 2/6 — Configuration"

# Detect server LAN IP
DETECTED_IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}' || hostname -I 2>/dev/null | awk '{print $1}' || echo "")

print_step "Server LAN IP address"
echo "This is the IP your LAN users will type in their browser."
read -p "Server IP [${DETECTED_IP}]: " SERVER_IP
SERVER_IP=${SERVER_IP:-$DETECTED_IP}
if [ -z "$SERVER_IP" ]; then
  print_error "Server IP is required"
  exit 1
fi

print_step "LAN access for admin login (email + password form)"
echo "Who should see the local login form (email + password) instead of SSO only?"
echo ""
echo "  Examples:"
echo "    - A single admin PC:     192.168.1.10"
echo "    - A whole LAN subnet:    192.168.1.0/24"
echo "    - Multiple (comma-sep):  192.168.1.10,192.168.1.11"
echo ""
read -p "Allowed IPs/CIDR: " LAN_ADMIN
if [ -z "$LAN_ADMIN" ]; then
  LAN_ADMIN="$SERVER_IP"
fi
# Always include server IP and localhost
LAN_HOSTS_VALUE="${SERVER_IP},${LAN_ADMIN},localhost"

print_step "License activation email"
echo "The email address registered with your reseller."
read -p "License email: " LICENSE_EMAIL
if [ -z "$LICENSE_EMAIL" ]; then
  print_error "License email is required"
  exit 1
fi

# ── Step 3: Deployment mode ────────────────────────────────────────────
print_header "Step 3/6 — Deployment mode"

echo "How will TicketBrainy be exposed to users?"
echo ""
echo "  ${BOLD}A)${NC} Behind an existing reverse proxy / WAF"
echo "     (you already handle HTTPS, domain, certificates externally)"
echo ""
echo "  ${BOLD}B)${NC} Direct internet exposure with built-in Caddy + Let's Encrypt"
echo "     (we install and configure HTTPS automatically)"
echo ""
read -p "Choose mode [A/B]: " DEPLOY_MODE
DEPLOY_MODE=${DEPLOY_MODE:-A}
DEPLOY_MODE=$(echo "$DEPLOY_MODE" | tr '[:lower:]' '[:upper:]')

USE_CADDY=false
APP_DOMAIN=""
KEYCLOAK_DOMAIN=""
LETSENCRYPT_EMAIL=""
APP_PORT_VALUE=4000
APP_URL="http://${SERVER_IP}:${APP_PORT_VALUE}"

if [ "$DEPLOY_MODE" = "B" ]; then
  USE_CADDY=true
  print_step "Public domain for TicketBrainy"
  echo "Example: support.yourcompany.com"
  echo "This domain MUST already point to this server's public IP (A record)."
  read -p "App domain: " APP_DOMAIN
  if [ -z "$APP_DOMAIN" ]; then
    print_error "App domain is required for Mode B"
    exit 1
  fi
  APP_URL="https://${APP_DOMAIN}"

  print_step "Let's Encrypt notification email"
  echo "Used for certificate expiration warnings from Let's Encrypt."
  read -p "Email [${LICENSE_EMAIL}]: " LETSENCRYPT_EMAIL
  LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL:-$LICENSE_EMAIL}
fi

# ── Step 4: Keycloak SSO ───────────────────────────────────────────────
print_header "Step 4/6 — Keycloak SSO (optional)"

echo "Keycloak provides Single Sign-On via Active Directory, LDAP, or your"
echo "own identity provider. Users log in with their existing credentials."
echo ""
read -p "Enable Keycloak SSO? [y/N]: " ENABLE_KC
ENABLE_KC=${ENABLE_KC:-N}
ENABLE_KC=$(echo "$ENABLE_KC" | tr '[:lower:]' '[:upper:]')

KEYCLOAK_URL=""
if [ "$ENABLE_KC" = "Y" ]; then
  if [ "$USE_CADDY" = true ]; then
    print_step "Public domain for Keycloak"
    echo "Example: auth.yourcompany.com"
    echo "This domain MUST already point to this server's public IP (A record)."
    echo "Required for public SSO access from the internet."
    read -p "Keycloak domain: " KEYCLOAK_DOMAIN
    if [ -z "$KEYCLOAK_DOMAIN" ]; then
      print_error "Keycloak domain is required when using SSO with Caddy mode"
      exit 1
    fi
    KEYCLOAK_URL="https://${KEYCLOAK_DOMAIN}"
  else
    print_step "Keycloak URL"
    echo "Enter the public URL where users will access Keycloak."
    echo "Example: https://auth.yourcompany.com (behind your existing WAF)"
    read -p "Keycloak URL: " KEYCLOAK_URL
    if [ -z "$KEYCLOAK_URL" ]; then
      print_error "Keycloak URL is required when enabling SSO"
      exit 1
    fi
  fi
fi

# ── Step 5: Generate .env ──────────────────────────────────────────────
print_header "Step 5/6 — Generating configuration"

if [ -f ".env" ]; then
  print_warning ".env file already exists"
  read -p "Overwrite? [y/N]: " OVERWRITE
  OVERWRITE=${OVERWRITE:-N}
  if [ "$(echo $OVERWRITE | tr '[:lower:]' '[:upper:]')" != "Y" ]; then
    print_error "Installation cancelled"
    exit 1
  fi
  cp .env .env.backup.$(date +%s)
  print_success "Backup saved to .env.backup.*"
fi

cp .env.example .env

# Generate secrets
DB_PASSWORD=$(openssl rand -hex 16)
REDIS_PASSWORD=$(openssl rand -base64 20 | tr -d '=+/' | head -c 24)
NEXTAUTH_SECRET=$(openssl rand -base64 32)
ENCRYPTION_MASTER_KEY=$(openssl rand -hex 32)
INTERNAL_SERVICE_TOKEN=$(openssl rand -base64 32)
SEED_ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d '=+/' | head -c 16)
KEYCLOAK_CLIENT_SECRET=$(openssl rand -hex 16)
KC_ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d '=+/' | head -c 16)

# Helper to set a value in .env
set_env() {
  local key="$1"
  local value="$2"
  # Escape special sed chars in value
  local escaped=$(printf '%s\n' "$value" | sed -e 's/[\/&]/\\&/g')
  if grep -q "^${key}=" .env; then
    sed -i "s|^${key}=.*|${key}=${escaped}|" .env
  else
    echo "${key}=${value}" >> .env
  fi
}

set_env "APP_URL" "$APP_URL"
set_env "APP_PORT" "$APP_PORT_VALUE"
set_env "DB_PASSWORD" "$DB_PASSWORD"
set_env "REDIS_PASSWORD" "$REDIS_PASSWORD"
set_env "NEXTAUTH_SECRET" "$NEXTAUTH_SECRET"
set_env "ENCRYPTION_MASTER_KEY" "$ENCRYPTION_MASTER_KEY"
set_env "INTERNAL_SERVICE_TOKEN" "$INTERNAL_SERVICE_TOKEN"
set_env "SEED_ADMIN_PASSWORD" "$SEED_ADMIN_PASSWORD"
set_env "KC_ADMIN_PASSWORD" "$KC_ADMIN_PASSWORD"
set_env "KEYCLOAK_CLIENT_SECRET" "$KEYCLOAK_CLIENT_SECRET"
set_env "LAN_HOSTS" "$LAN_HOSTS_VALUE"

if [ "$ENABLE_KC" = "Y" ]; then
  set_env "KEYCLOAK_URL" "$KEYCLOAK_URL"
  set_env "KEYCLOAK_REALM" "ticketbrainy"
  set_env "KEYCLOAK_CLIENT_ID" "ticketbrainy-web"
fi

if [ "$USE_CADDY" = true ]; then
  set_env "APP_DOMAIN" "$APP_DOMAIN"
  set_env "LETSENCRYPT_EMAIL" "$LETSENCRYPT_EMAIL"
  if [ -n "$KEYCLOAK_DOMAIN" ]; then
    set_env "KEYCLOAK_DOMAIN" "$KEYCLOAK_DOMAIN"
  fi
fi

print_success ".env configuration written"

# ── Step 6: Deploy ─────────────────────────────────────────────────────
print_header "Step 6/6 — Deploying"

print_step "Pulling Docker images (this may take a few minutes)..."
if [ "$USE_CADDY" = true ]; then
  docker compose --profile with-proxy pull
else
  docker compose pull
fi
print_success "Images downloaded"

print_step "Starting services..."
if [ "$USE_CADDY" = true ]; then
  docker compose --profile with-proxy up -d
else
  docker compose up -d
fi
print_success "Services started"

print_step "Waiting for web service to be ready (up to 60s)..."
for i in $(seq 1 60); do
  if docker compose ps web 2>/dev/null | grep -q "Up\|running"; then
    sleep 3
    break
  fi
  sleep 1
done
print_success "Web service is running"

# ── Summary ────────────────────────────────────────────────────────────
print_header "Installation Complete"

echo -e "${BOLD}Access URL:${NC}          ${APP_URL}"
if [ "$USE_CADDY" = true ]; then
  echo -e "${BOLD}HTTPS:${NC}               Caddy will obtain Let's Encrypt certificates automatically"
  if [ -n "$KEYCLOAK_DOMAIN" ]; then
    echo -e "${BOLD}Keycloak public URL:${NC} https://${KEYCLOAK_DOMAIN}"
  fi
fi
echo ""
echo -e "${BOLD}${YELLOW}Admin credentials (save these!):${NC}"
echo -e "  Email:    ${CYAN}admin@ticketbrainy.local${NC}"
echo -e "  Password: ${CYAN}${SEED_ADMIN_PASSWORD}${NC}"
echo ""
if [ "$ENABLE_KC" = "Y" ]; then
  echo -e "${BOLD}${YELLOW}Keycloak admin console:${NC}"
  echo -e "  URL:      http://${SERVER_IP}:8180 (or ${KEYCLOAK_URL}/admin)"
  echo -e "  Username: admin"
  echo -e "  Password: ${CYAN}${KC_ADMIN_PASSWORD}${NC}"
  echo ""
fi
echo -e "${BOLD}Next steps:${NC}"
echo "  1. Open ${APP_URL} in your browser"
echo "  2. Enter your license email: ${LICENSE_EMAIL}"
echo "  3. Login with the admin credentials above"
echo "  4. Change your password in Settings > Team"
echo ""
echo -e "${BOLD}Useful commands:${NC}"
if [ "$USE_CADDY" = true ]; then
  echo "  docker compose --profile with-proxy logs -f    # View all logs"
  echo "  docker compose --profile with-proxy restart    # Restart all services"
  echo "  docker compose --profile with-proxy down       # Stop all services"
else
  echo "  docker compose logs -f                         # View all logs"
  echo "  docker compose restart                         # Restart all services"
  echo "  docker compose down                            # Stop all services"
fi
echo ""
echo -e "${GREEN}${BOLD}Installation successful!${NC}"
