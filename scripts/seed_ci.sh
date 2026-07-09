#!/bin/bash
cd "$(dirname "$0")/.."
# seed_ci.sh - Reset and seed the database for CI/E2E testing (hub-owned)

set -e

HUB=upsilonhub/bin/upsilonhub
if [ ! -x "$HUB" ]; then
    echo "--- Building hub ---"
    (cd upsilonhub && go build -o bin/upsilonhub ./cmd/upsilonhub)
fi

echo "--- Resetting Database ---"
# Fresh CI database: drop and re-apply the embedded schema + River.
psql "${DATABASE_URL:?DATABASE_URL is mandatory}" -q -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'
"$HUB" -migrate-mode full

echo "--- Seeding Database (catalog, testuser, admins) ---"
# ADMIN_INITIAL_PASSWORD gates the admin/dummy/admin2 block (warn+skip unset).
ADMIN_INITIAL_PASSWORD="${ADMIN_INITIAL_PASSWORD:-AdminPassword123!}" "$HUB" -seed

echo "--- Seeding Complete ---"
