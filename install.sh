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

# v1.10.1448: Defensive input handling for the wizard prompts.
#
# `read` captures terminal escape sequences literally when the user edits
# the prompt with Del / arrow keys in a TTY that doesn't translate them
# (common when SSHing with a misconfigured TERM). Those bytes used to
# end up straight in .env and later poisoned docker-compose env vars —
# Keycloak would then crashloop on realm import with "Illegal unquoted
# character CTRL-CHAR code 27". `sanitize_input` strips every ASCII
# control character except LF/CR from whatever `read` captured.
sanitize_input() {
  printf '%s' "$1" | tr -d '\000-\011\013-\037\177'
}

is_valid_ipv4() {
  local ip="$1"
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  local IFS='.' octet
  for octet in $ip; do
    [ "$octet" -ge 0 ] && [ "$octet" -le 255 ] || return 1
  done
  return 0
}

is_valid_email() {
  [[ "$1" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]
}

is_valid_domain() {
  [[ "$1" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]
}

is_valid_url() {
  [[ "$1" =~ ^https?://[a-zA-Z0-9.-]+(:[0-9]+)?(/.*)?$ ]]
}

is_valid_mode() {
  case "${1^^}" in A|B) return 0 ;; *) return 1 ;; esac
}

is_valid_yn() {
  case "${1^^}" in Y|N|YES|NO) return 0 ;; *) return 1 ;; esac
}

# prompt_validated PROMPT DEFAULT VALIDATOR ERROR
# Writes prompt to stderr, reads from stdin, strips ctrl chars, applies
# DEFAULT if empty, re-prompts on validator failure. Returns the clean
# value on stdout so callers can capture it with `$(…)`.
prompt_validated() {
  local prompt="$1" default="$2" validator="$3" error="$4"
  local value
  while true; do
    printf '%s' "$prompt" >&2
    read -r value || value=""
    value=$(sanitize_input "$value")
    value=${value:-$default}
    if [ -z "$value" ]; then
      print_error "This field is required."
      continue
    fi
    if $validator "$value"; then
      printf '%s' "$value"
      return 0
    fi
    print_error "$error"
  done
}

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
echo "This wizard deploys the full TicketBrainy stack on this server."
echo ""
echo "You will go through 4 short steps. For every question:"
echo ""
echo "  • A hint in [brackets] shows the suggested default."
echo "  • Press ${BOLD}[Enter]${NC} without typing anything to accept the default."
echo "  • Type a new value to override."
echo ""
echo "Invalid input (empty value, bad IP, bad email, control keys) is"
echo "rejected and the question is asked again — nothing breaks silently."
echo ""
echo "Press Ctrl+C at any time to cancel."
echo ""

# ── Step 1 — Network identity (server + admin) ─────────────────────────
print_header "Step 1/4 — Network identity"

DETECTED_IP=""
if command -v ip >/dev/null 2>&1; then
  DETECTED_IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}' || true)
fi
if [ -z "$DETECTED_IP" ] && command -v hostname >/dev/null 2>&1; then
  DETECTED_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
fi

# --- Q1a — Server IP ---
print_step "Server IP address (1 of 2)"
cat <<EOF
The network address where TicketBrainy runs. It is used to build
the URLs users will open in their browser (and the post-install
summary).

  - On-premise install    : private LAN IP of this server
                            Example: 192.168.1.50
  - VPS / remote server   : public IP of this server
                            Example: 37.59.115.12

We auto-detected the value below — in most cases you can just press
[Enter] to accept it.

EOF
SERVER_IP=$(prompt_validated "Server IP [${DETECTED_IP}]: " "$DETECTED_IP" is_valid_ipv4 "Invalid IPv4 address. Expected something like 192.168.1.50 or 37.59.115.12.")
print_success "Server IP: ${SERVER_IP}"
echo ""

# --- Q1b — Admin IP ---
print_step "Administrator IP address (2 of 2)"
cat <<EOF
The IP address from which YOU — the administrator — will connect to
TicketBrainy's admin pages and to the Keycloak admin console.

This IP (plus localhost and the server IP) will be allowed to:
  * See the local email+password form on the /login page
  * Open the admin pages and the Keycloak admin UI
Every other visitor sees the public site and SSO login only.

  - On-premise install    : the same as the server IP above.
                            Just press [Enter] to accept the default.
  - VPS / remote server   : the PUBLIC IP of YOUR OWN workstation
                            (the IP your browser goes out with).
                            Tip: run \`curl ifconfig.me\` on your workstation
                            to find it.
                            Example: 87.240.204.21

More IPs and CIDR ranges can be added later by editing .env (LAN_HOSTS
accepts comma lists and CIDRs like 192.168.1.0/24).

EOF
ADMIN_IP=$(prompt_validated "Administrator IP [${SERVER_IP}]: " "$SERVER_IP" is_valid_ipv4 "Invalid IPv4 address. Expected something like 192.168.1.10 or 87.240.204.21.")
print_success "Administrator IP: ${ADMIN_IP}"

# Build LAN_HOSTS: always localhost + server IP, plus admin IP if different.
LAN_HOSTS_VALUE="localhost,${SERVER_IP}"
if [ "$ADMIN_IP" != "$SERVER_IP" ]; then
  LAN_HOSTS_VALUE="${LAN_HOSTS_VALUE},${ADMIN_IP}"
fi

# ── Step 2 — License ───────────────────────────────────────────────────
print_header "Step 2/4 — License"

print_step "License activation email"
cat <<EOF
The email address registered with your TicketBrainy purchase.

You will re-enter this email in the web wizard at /activate right
after the install finishes — that is how the instance activates
against the license server.

If you choose Caddy mode in the next step, this email is also
reused by default for Let's Encrypt certificate-expiration alerts.

EOF
LICENSE_EMAIL=$(prompt_validated "License email: " "" is_valid_email "Invalid email. Expected something like you@yourcompany.com.")
print_success "License email: ${LICENSE_EMAIL}"

# ── Step 3 — Deployment mode ───────────────────────────────────────────
print_header "Step 3/4 — Deployment mode"

print_step "How will users reach TicketBrainy?"
cat <<EOF

  A) Direct
     TicketBrainy listens on port 4000 without any built-in proxy.
     Pick this if:
       * You are on a LAN — users type http://${SERVER_IP}:4000
       * You already run a reverse proxy or WAF in front (Cloudflare
         Tunnel, nginx, Traefik, Sophos, pfSense) that handles HTTPS.

  B) Caddy (recommended for VPS / public install)
     Built-in Caddy reverse proxy — obtains free Let's Encrypt TLS
     certificates automatically. Pick this if:
       * The server is reachable on the public internet
       * Ports 80 AND 443 are open on its firewall
       * You own TWO domain names, both with an A record pointing at
         this server's public IP (${SERVER_IP}):
             1. <app-domain>       e.g. support.yourcompany.com
             2. <keycloak-domain>  e.g. auth.yourcompany.com
         (both domains share the same server IP — Caddy routes by Host)

EOF
MODE=$(prompt_validated "Mode [A/B] (Enter = A): " "A" is_valid_mode "Please type A or B.")
MODE="${MODE^^}"

USE_CADDY=false
APP_DOMAIN=""
KEYCLOAK_DOMAIN=""
LETSENCRYPT_EMAIL=""
APP_URL="http://${SERVER_IP}:4000"

if [ "$MODE" = "B" ]; then
  USE_CADDY=true
  echo ""
  print_step "App domain — the public hostname users will type"
  cat <<EOF
Example: support.yourcompany.com

This domain MUST resolve to ${SERVER_IP} BEFORE you continue, or
Let's Encrypt will fail to issue the certificate. A DNS pre-check
runs at the end of this wizard and warns you if the record is
missing or wrong.

EOF
  APP_DOMAIN=$(prompt_validated "App domain: " "" is_valid_domain "Invalid domain. Expected something like support.yourcompany.com.")
  APP_URL="https://${APP_DOMAIN}"
  print_success "App domain: ${APP_DOMAIN}"

  echo ""
  print_step "Let's Encrypt notification email"
  cat <<EOF
Let's Encrypt uses this address to email you BEFORE a certificate
expires (they never spam it for anything else). It is not shared
with third parties.

We default to your license email — press [Enter] to accept.

EOF
  LETSENCRYPT_EMAIL=$(prompt_validated "Notification email [${LICENSE_EMAIL}]: " "$LICENSE_EMAIL" is_valid_email "Invalid email.")
  print_success "Notification email: ${LETSENCRYPT_EMAIL}"
fi
print_success "Mode: $([ "$USE_CADDY" = true ] && echo "Caddy + Let's Encrypt (${APP_DOMAIN})" || echo "Direct (http://${SERVER_IP}:4000)")"

# v1.10.05: DNS pre-check (non-blocking) — if the operator entered a
# domain that doesn't resolve to this server yet, print a clear warning
# and give them a chance to abort. Caddy would still try to obtain the
# certificate but the first few minutes post-install would look broken.
check_dns_match() {
  local domain="$1"
  local label="$2"
  local resolved
  resolved=$(getent hosts "$domain" 2>/dev/null | awk '{print $1; exit}' || true)
  if [ -z "$resolved" ]; then
    print_warning "${label} (${domain}) does not resolve — Let's Encrypt will fail until you add a DNS A record pointing at ${SERVER_IP}"
    return 1
  fi
  if [ "$resolved" != "$SERVER_IP" ]; then
    print_warning "${label} (${domain}) resolves to ${resolved}, not this server (${SERVER_IP}) — Let's Encrypt may fail the HTTP-01 challenge"
    return 1
  fi
  print_success "${label} (${domain}) → ${resolved} ✓"
  return 0
}

# ── Step 4 — Keycloak SSO (optional) ───────────────────────────────────
# v1.10.1448: the old Step 4 "LAN access control" was removed — its
# single question about who can see the local login form is now covered
# by the Administrator IP in Step 1 (feeds the same LAN_HOSTS env var).
# Operators can still add more IPs or CIDR ranges post-install by
# editing LAN_HOSTS in .env.
print_header "Step 4/4 — Keycloak SSO (optional)"

print_step "Enable Single Sign-On via Keycloak?"
cat <<EOF
Keycloak adds a "Sign in with SSO" button to the /login page and lets
you plug in Active Directory, LDAP, Google Workspace, Microsoft Entra,
or any OIDC identity provider.

If you do not need SSO today, leave it off — you can enable it later
from Settings -> Security without reinstalling.

EOF
ENABLE_KC=$(prompt_validated "Enable Keycloak SSO now? [y/N] (Enter = N): " "N" is_valid_yn "Please type y or n.")
ENABLE_KC="${ENABLE_KC^^}"
case "$ENABLE_KC" in YES) ENABLE_KC="Y" ;; NO) ENABLE_KC="N" ;; esac

KEYCLOAK_URL_VALUE=""
if [ "$ENABLE_KC" = "Y" ]; then
  if [ "$USE_CADDY" = true ]; then
    echo ""
    print_step "Keycloak public domain"
    cat <<EOF
A second domain, distinct from your App domain, that serves the
Keycloak login pages and admin console.
Example: auth.yourcompany.com (when app is support.yourcompany.com)

It must also have a DNS A record pointing at ${SERVER_IP}.

EOF
    KEYCLOAK_DOMAIN=$(prompt_validated "Keycloak domain: " "" is_valid_domain "Invalid domain.")
    KEYCLOAK_URL_VALUE="https://${KEYCLOAK_DOMAIN}"
    print_success "Keycloak domain: ${KEYCLOAK_DOMAIN}"
  else
    echo ""
    print_step "Keycloak public URL"
    cat <<EOF
The full URL at which Keycloak will be reachable by end users.

  * If you have a reverse proxy / WAF in front (Cloudflare, nginx,
    Sophos, Traefik…) serving HTTPS, enter its public URL.
      Example: https://auth.yourcompany.com
  * If users will hit Keycloak directly on this server, enter:
      http://${SERVER_IP}:8180

EOF
    KEYCLOAK_URL_VALUE=$(prompt_validated "Keycloak URL: " "" is_valid_url "Invalid URL — must start with http:// or https:// and include a hostname.")
    print_success "Keycloak URL: ${KEYCLOAK_URL_VALUE}"
  fi
  print_success "Keycloak SSO: enabled (${KEYCLOAK_URL_VALUE})"
else
  print_success "Keycloak SSO: disabled (local accounts only)"
fi
# v1.10.08: The Keycloak admin IP allowlist is managed from the
# TicketBrainy UI (Settings → Security) instead of the installer —
# that way operators can adjust it later without touching .env or
# restarting containers. Default on fresh installs is "no restriction"
# until the operator configures it.

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
# v1.10.05: Persist LICENSE_EMAIL into .env so the activate wizard can
# pre-fill it. Avoids the "I'm repeating myself" friction — the operator
# already told us the license email, they shouldn't have to retype it in
# the browser. The wizard still renders the form so the operator can
# confirm/edit before clicking Activate — we don't auto-submit.
set_env "LICENSE_EMAIL" "$LICENSE_EMAIL"

if [ "$ENABLE_KC" = "Y" ]; then
  set_env "KEYCLOAK_URL" "$KEYCLOAK_URL_VALUE"
fi

if [ "$USE_CADDY" = true ]; then
  set_env "APP_DOMAIN"        "$APP_DOMAIN"
  set_env "LETSENCRYPT_EMAIL" "$LETSENCRYPT_EMAIL"
  if [ -n "$KEYCLOAK_DOMAIN" ]; then
    set_env "KEYCLOAK_DOMAIN" "$KEYCLOAK_DOMAIN"
  fi
  # v1.10.02: In Caddy mode, bind the Keycloak host port to 127.0.0.1
  # so it's NOT exposed on the public internet. Caddy reaches Keycloak
  # via the internal docker network (keycloak:8080), so the host port
  # is only useful for local debugging (via SSH port forward). This
  # stops bots from hammering http://<ip>:8180/admin/* and prevents
  # the "HTTPS required" confusion operators used to hit when they
  # accidentally opened the IP:8180 URL.
  set_env "KC_BIND" "127.0.0.1"
fi
print_success ".env written"

# v1.10.05: DNS pre-check — now that both domains are known and the
# operator hasn't started docker yet, verify each domain resolves to
# this server. Warn + prompt rather than block — some operators set
# up DNS after the install (e.g. they need the server IP first), and
# we don't want to hard-stop them from finishing configuration.
if [ "$USE_CADDY" = true ]; then
  print_header "DNS pre-check"
  DNS_ISSUES=0
  check_dns_match "$APP_DOMAIN" "App domain" || DNS_ISSUES=$((DNS_ISSUES + 1))
  if [ -n "$KEYCLOAK_DOMAIN" ]; then
    check_dns_match "$KEYCLOAK_DOMAIN" "Keycloak domain" || DNS_ISSUES=$((DNS_ISSUES + 1))
  fi
  if [ "$DNS_ISSUES" -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}${BOLD}${DNS_ISSUES} domain(s) above have DNS issues.${NC}"
    echo -e "${YELLOW}Caddy will keep trying to obtain a Let's Encrypt cert every few"
    echo -e "minutes in the background — it will work as soon as DNS is correct."
    echo -e "You can continue the install and fix DNS after. Set the A record to:"
    echo -e "${NC}"
    echo -e "    ${BOLD}${SERVER_IP}${NC}"
    echo ""
    DNS_CONTINUE=$(prompt_validated "Continue the install anyway? [Y/n] (Enter = Y): " "Y" is_valid_yn "Please type y or n.")
    case "${DNS_CONTINUE^^}" in
      N|NO)
        echo ""
        print_error "Install aborted — fix DNS and re-run bash install.sh"
        exit 1
        ;;
    esac
  fi
fi

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

# v1.10.02: Keycloak admin console URL is mode-dependent.
# - Direct mode: exposed on http://<server-ip>:8180 (same as before)
# - Caddy mode:  only reachable via the HTTPS Keycloak domain (the
#                host port is bound to 127.0.0.1 via KC_BIND in .env)
if [ "$USE_CADDY" = true ] && [ -n "$KEYCLOAK_DOMAIN" ]; then
  KC_ADMIN_URL="https://${KEYCLOAK_DOMAIN}"
else
  KC_ADMIN_URL="http://${SERVER_IP}:8180"
fi

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
echo -e "  ${BOLD}Keycloak admin:${NC}      ${GREEN}${KC_ADMIN_URL}${NC}"
if [ "$USE_CADDY" = true ]; then
  echo -e "  ${YELLOW}   Do NOT open http://${SERVER_IP}:8180 — port bound to localhost only.${NC}"
  echo -e "  ${YELLOW}   Use the HTTPS URL above. If DNS for ${KEYCLOAK_DOMAIN} is not set up${NC}"
  echo -e "  ${YELLOW}   yet, configure an A record pointing at this server's IP.${NC}"
fi
echo ""

echo -e "${BOLD}${YELLOW}═════ TicketBrainy admin (SAVE THIS PASSWORD) ═════${NC}"
echo -e "  Email:      ${CYAN}admin@ticketbrainy.local${NC}"
echo -e "  Password:   ${CYAN}${SEED_PASS}${NC}"
echo ""

echo -e "${BOLD}${YELLOW}═════ Keycloak admin console ═════${NC}"
echo -e "  URL:        ${CYAN}${KC_ADMIN_URL}${NC}"
echo -e "  Username:   ${CYAN}admin${NC}"
echo -e "  Password:   ${CYAN}${KC_ADMIN_PASS}${NC}"
echo ""

echo -e "${BOLD}═════ Next steps (first bootstrap) ═════${NC}"
if [ "$USE_CADDY" = true ]; then
  BOOT_URL="${APP_URL}"
else
  BOOT_URL="${LAN_URL}"
fi
echo "  1. Open ${BOLD}${BOOT_URL}/activate${NC} and activate with your license email:"
echo "       ${LICENSE_EMAIL}"
echo ""
echo "  2. Go to ${BOLD}${BOOT_URL}/login${NC}"
echo "     Until you create a Keycloak admin, the page shows a"
echo "     \"bootstrap mode\" banner and the local email+password form."
echo "     Log in with:  ${BOLD}admin@ticketbrainy.local${NC} + the password above."
echo ""
echo "  3. Open ${BOLD}${KC_ADMIN_URL}${NC} and log in with admin / (KC password above)"
echo "     — realm \"${BOLD}ticketbrainy${NC}\" — create your SSO user, set a password in"
echo "     the ${BOLD}Credentials${NC} tab (unchecked 'Temporary')."
echo ""
echo "  4. Log out of TicketBrainy, click ${BOLD}\"Se connecter avec SSO\"${NC} — your first"
echo "     SSO login auto-promotes to ADMIN. Bootstrap banner disappears,"
echo "     local form is hidden from public IPs from then on."
echo ""
echo "  5. Change the seed admin password in Settings → Team (or disable the account)."
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
