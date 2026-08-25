#!/bin/bash
set -e

IMPORT_DIR="/opt/keycloak/data/import"
TEMPLATE="/opt/keycloak/data/realm-template/ticketbrainy-realm.json"

# v1.10.1448: defensive sanitization of env vars that get substituted
# into the realm JSON. If a control character (e.g. ESC 0x1b from a
# mis-entered Del key during install) leaks into LAN_HOST/APP_URL/etc,
# it would poison the rendered JSON and Keycloak would crashloop with
# "Illegal unquoted character CTRL-CHAR code 27". install.sh now strips
# those at prompt time, but we defend in depth at import time too.
sanitize() { printf '%s' "$1" | tr -d '\000-\011\013-\037\177'; }
KC_CLIENT_SECRET_SAFE=$(sanitize "${KC_CLIENT_SECRET:-}")
APP_URL_SAFE=$(sanitize "${APP_URL:-}")
APP_PORT_SAFE=$(sanitize "${APP_PORT:-3027}")
LAN_HOST_SAFE=$(sanitize "${LAN_HOST:-localhost}")

# 2026-08-25: LAN_HOST is fed from LAN_HOSTS (docker-compose), which is a
# COMMA-SEPARATED list — install.sh writes "localhost,<server-ip>[,<admin-ip>]".
# Substituting it straight into "http://${LAN_HOST}:${APP_PORT}" produced a
# SINGLE malformed entry, e.g.
#     http://10.0.0.5,localhost:3027/api/auth/callback/keycloak
# which matches no browser request, so a direct-LAN OIDC login could never
# complete (only the public APP_URL callback worked). Expand the list into one
# redirect URI / web origin per host instead.
#
# LAN_HOSTS may legitimately hold CIDR ranges (it also feeds the web
# allowlist); a CIDR is not a valid URI host, so those entries are skipped.
#
# Pure bash — the Keycloak image ships no awk (bash/sed/tr/grep only).
build_lan_list() {
  # $1 = path suffix appended to each origin ("" for webOrigins)
  local suffix="$1" out="" seen="," host
  local IFS=','
  for host in $LAN_HOST_SAFE; do
    # trim surrounding whitespace
    host="${host#"${host%%[![:space:]]*}"}"
    host="${host%"${host##*[![:space:]]}"}"
    [ -z "$host" ] && continue
    # a CIDR range is not a valid URI host
    case "$host" in */*) continue ;; esac
    # de-duplicate
    case "$seen" in *",${host},"*) continue ;; esac
    seen="${seen}${host},"
    out="${out}, \"http://${host}:${APP_PORT_SAFE}${suffix}\""
  done
  printf '%s' "$out"
}

# Escape the characters sed treats specially in a replacement string.
sed_escape() { printf '%s' "$1" | sed 's|[\\&|]|\\&|g'; }

LAN_REDIRECT_URIS=$(build_lan_list "/api/auth/callback/keycloak")
LAN_WEB_ORIGINS=$(build_lan_list "")

if [ -f "$TEMPLATE" ]; then
  mkdir -p "$IMPORT_DIR"

  # Replace bare placeholders with sanitized env var values.
  # ${LAN_HOST} is kept for backward compatibility with pre-2026-08-25
  # realm templates; the current template uses the expanded lists.
  sed \
    -e "s|\${KC_CLIENT_SECRET}|${KC_CLIENT_SECRET_SAFE}|g" \
    -e "s|\${APP_URL}|${APP_URL_SAFE}|g" \
    -e "s|\${APP_PORT}|${APP_PORT_SAFE}|g" \
    -e "s|\${LAN_REDIRECT_URIS}|$(sed_escape "$LAN_REDIRECT_URIS")|g" \
    -e "s|\${LAN_WEB_ORIGINS}|$(sed_escape "$LAN_WEB_ORIGINS")|g" \
    -e "s|\${LAN_HOST}|${LAN_HOST_SAFE}|g" \
    "$TEMPLATE" > "$IMPORT_DIR/ticketbrainy-realm.json"

  echo "[init] Realm template processed with env vars"
fi

# v1.10.14776: render custom email theme with APP_URL baked into the
# executeActions templates so the activation email links the recipient
# back to the TicketBrainy portal once their account is activated.
#
# The source theme is mounted read-only at THEME_SRC; we copy it to the
# default themes dir (writable, in the image's rootfs) and substitute
# the __TB_PORTAL_URL__ placeholder with $APP_URL before Keycloak boots.
# Falls back gracefully if the source mount is absent (legacy installs).
THEME_SRC="/opt/keycloak/themes-src/ticketbrainy"
THEME_DST="/opt/keycloak/themes/ticketbrainy"
if [ -d "$THEME_SRC" ]; then
  rm -rf "$THEME_DST"
  cp -r "$THEME_SRC" "$THEME_DST"
  # Sanitized APP_URL (no control chars, no trailing slash).
  TB_PORTAL_URL=$(printf '%s' "${APP_URL_SAFE%/}" | sed 's|[&|]|\\&|g')
  if [ -n "$TB_PORTAL_URL" ]; then
    find "$THEME_DST" -type f \( -name '*.ftl' -o -name '*.properties' \) \
      -exec sed -i "s|__TB_PORTAL_URL__|${TB_PORTAL_URL}|g" {} +
    echo "[init] Theme rendered with TB_PORTAL_URL=${APP_URL_SAFE%/}"
  else
    echo "[init] WARN: APP_URL empty, theme placeholder left unrendered"
  fi
fi

# Start Keycloak
exec /opt/keycloak/bin/kc.sh start --import-realm "$@"
