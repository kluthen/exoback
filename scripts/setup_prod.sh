#!/bin/bash
# scripts/setup_prod.sh - Initialize production environment secrets

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
TEMPLATE_FILE="$ROOT_DIR/env.example"

echo "---------------------------------------"
echo "Initializing Production Environment..."
echo "---------------------------------------"

FORCE=false

# Simple argument parsing
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -f|--force) FORCE=true ;;
        *) echo "[!] Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "[!] Error: env.example not found at root."
    exit 1
fi

if [ -f "$ENV_FILE" ] && [ "$FORCE" = false ]; then
    echo "[!] .env already exists. Skipping recreation to avoid overriding secrets."
    echo "[TIP] Use --force or -f to overwrite the existing .env file."
    exit 0
fi

if [ "$FORCE" = true ]; then
    echo "[!] Overwriting existing .env as requested..."
fi

echo "[+] Copying template to .env..."
cp "$TEMPLATE_FILE" "$ENV_FILE"

# Function to generate a secure random string (alphanumeric)
generate_secret() {
    base64 < /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32
}

echo "[+] Generating secure secrets..."

# Admin seed password (hub -seed admin block)
ADMIN_INITIAL_PASSWORD=$(generate_secret)
# Use ^ to anchor the replacement to the start of the key name to avoid substring collision
sed -i "s|^ADMIN_INITIAL_PASSWORD=GENERATED_SECRET|ADMIN_INITIAL_PASSWORD=$ADMIN_INITIAL_PASSWORD|g" "$ENV_FILE"

echo "---------------------------------------"
echo "[OK] Production environment initialized."
echo "[!] Shared secrets generated and propagated to .env"
echo "---------------------------------------"
