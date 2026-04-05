#!/bin/bash
set -e

IMPORT_DIR="/opt/keycloak/data/import"
TEMPLATE="/opt/keycloak/data/realm-template/ticketbrainy-realm.json"

# Substitute environment variables in realm template
if [ -f "$TEMPLATE" ]; then
  mkdir -p "$IMPORT_DIR"

  # Replace placeholders with actual env var values
  sed \
    -e "s|\${KC_CLIENT_SECRET}|${KC_CLIENT_SECRET}|g" \
    -e "s|\${APP_URL}|${APP_URL}|g" \
    -e "s|\${APP_PORT}|${APP_PORT:-3027}|g" \
    -e "s|\${LAN_HOST}|${LAN_HOST:-localhost}|g" \
    "$TEMPLATE" > "$IMPORT_DIR/ticketbrainy-realm.json"

  echo "[init] Realm template processed with env vars"
fi

# Start Keycloak
exec /opt/keycloak/bin/kc.sh start --import-realm "$@"
