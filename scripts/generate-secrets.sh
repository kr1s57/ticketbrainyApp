#!/bin/bash
###############################################################################
#  TicketBrainy — Secure Secrets Generator
#  Generates all required passwords, tokens, and keys in your .env file.
#  Usage:  bash scripts/generate-secrets.sh
###############################################################################

set -e

ENV_FILE=".env"

if [ ! -f "$ENV_FILE" ]; then
  echo "Error: $ENV_FILE not found. Run: cp .env.example .env"
  exit 1
fi

echo "Generating secure secrets for TicketBrainy..."
echo ""

# Generate values
DB_PASSWORD=$(openssl rand -hex 16)
REDIS_PASSWORD=$(openssl rand -base64 20 | tr -d '=+/' | head -c 24)
NEXTAUTH_SECRET=$(openssl rand -base64 32)
ENCRYPTION_MASTER_KEY=$(openssl rand -hex 32)
INTERNAL_SERVICE_TOKEN=$(openssl rand -base64 32)
SEED_ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d '=+/' | head -c 16)
KEYCLOAK_CLIENT_SECRET=$(openssl rand -hex 16)
KC_ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d '=+/' | head -c 16)

# Replace empty values in .env
sed -i "s|^DB_PASSWORD=$|DB_PASSWORD=${DB_PASSWORD}|" "$ENV_FILE"
sed -i "s|^REDIS_PASSWORD=$|REDIS_PASSWORD=${REDIS_PASSWORD}|" "$ENV_FILE"
sed -i "s|^NEXTAUTH_SECRET=$|NEXTAUTH_SECRET=${NEXTAUTH_SECRET}|" "$ENV_FILE"
sed -i "s|^ENCRYPTION_MASTER_KEY=$|ENCRYPTION_MASTER_KEY=${ENCRYPTION_MASTER_KEY}|" "$ENV_FILE"
sed -i "s|^INTERNAL_SERVICE_TOKEN=$|INTERNAL_SERVICE_TOKEN=${INTERNAL_SERVICE_TOKEN}|" "$ENV_FILE"
sed -i "s|^SEED_ADMIN_PASSWORD=$|SEED_ADMIN_PASSWORD=${SEED_ADMIN_PASSWORD}|" "$ENV_FILE"
sed -i "s|^KEYCLOAK_CLIENT_SECRET=$|KEYCLOAK_CLIENT_SECRET=${KEYCLOAK_CLIENT_SECRET}|" "$ENV_FILE"
sed -i "s|^KC_ADMIN_PASSWORD=$|KC_ADMIN_PASSWORD=${KC_ADMIN_PASSWORD}|" "$ENV_FILE"

echo "Secrets generated successfully!"
echo ""
echo "  DB_PASSWORD          = ${DB_PASSWORD}"
echo "  REDIS_PASSWORD       = ${REDIS_PASSWORD}"
echo "  NEXTAUTH_SECRET      = ${NEXTAUTH_SECRET:0:16}..."
echo "  ENCRYPTION_MASTER_KEY = ${ENCRYPTION_MASTER_KEY:0:16}..."
echo "  INTERNAL_SERVICE_TOKEN = ${INTERNAL_SERVICE_TOKEN:0:16}..."
echo "  SEED_ADMIN_PASSWORD  = ${SEED_ADMIN_PASSWORD}"
echo "  KEYCLOAK_CLIENT_SECRET = ${KEYCLOAK_CLIENT_SECRET}"
echo "  KC_ADMIN_PASSWORD    = ${KC_ADMIN_PASSWORD}"
echo ""
echo "IMPORTANT: Save SEED_ADMIN_PASSWORD — you need it for first login."
echo "Next steps:"
echo "  1. Edit APP_URL in .env (your public domain)"
echo "  2. Run: docker compose up -d"
echo "  3. Open your browser and activate with your license email"
