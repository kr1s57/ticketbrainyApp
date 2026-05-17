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

if [ -f "$TEMPLATE" ]; then
  mkdir -p "$IMPORT_DIR"

  # Replace bare placeholders with sanitized env var values.
  sed \
    -e "s|\${KC_CLIENT_SECRET}|${KC_CLIENT_SECRET_SAFE}|g" \
    -e "s|\${APP_URL}|${APP_URL_SAFE}|g" \
    -e "s|\${APP_PORT}|${APP_PORT_SAFE}|g" \
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
