#!/bin/bash
cd "$(dirname "$0")/.."

# Configuration
LOG_DIR="logs"
PID_FILE=".services.pids"
PORTS_VERIFY_TIMEOUT=10 # Max seconds to wait for a port

# Phase-3 economy swap: run the extracted upsiloneconomy alongside the hub so
# local dev mirrors prod (the hub talks to it over the internal S2S seam).
# DEV_S2S_TOKEN is the shared internal-service secret both sides present/expect;
# ECONOMY_DB_URL is the hub's DATABASE_URL retargeted at the upsiloneconomy
# database (provisioned by deploy/initdb on a fresh dev volume).
DEV_S2S_TOKEN="dev-internal-token"
ECONOMY_DB_URL="$(printf '%s' "$DATABASE_URL" | sed -E 's#(://[^/]+/)[^/?]+#\1upsiloneconomy#')"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

echo "---------------------------------------"
echo "Starting Upsilon Stack (Authoritative Mode)"
echo "---------------------------------------"

# 1. Authoritative Cleanup
./scripts/stop_services.sh

# Clear existing PIDs file
> "$PID_FILE"

# Function to start a service and verify it is listening
start_service() {
    local name=$1
    local dir=$2
    local command=$3
    local log_file=$4
    local port=$5

    echo "[+] Starting $name on port $port..."
    cd "$dir" || exit 1
    
    # Run in background
    nohup $command > "../$LOG_DIR/$log_file" 2>&1 &
    local shell_pid=$!
    
    # Verification loop
    echo -n "    Verifying..."
    local count=0
    local confirmed_pid=""
    while [ $count -lt $PORTS_VERIFY_TIMEOUT ]; do
        # Try to find the PID actually listening on the port
        confirmed_pid=$(ss -tulpn | grep ":$port " | grep -oP 'users:\(\("\S+",pid=\K\d+' | head -n 1)
        
        if [ ! -z "$confirmed_pid" ]; then
            echo " OK (PID: $confirmed_pid)"
            # Format: NAME|PID|LOG_FILE|PORT
            echo "$name|$confirmed_pid|$log_file|$port" >> "../$PID_FILE"
            cd ..
            return 0
        fi
        
        sleep 1
        echo -n "."
        count=$((count + 1))
    done

    echo " FAILED"
    echo "[ERROR] $name failed to start on port $port after $PORTS_VERIFY_TIMEOUT seconds."
    echo "Check logs/ $log_file for details."
    cd ..
    exit 1
}


# 1. Upsilon Engine (Go) — before the hub so its client finds it at boot
start_service "Upsilon Engine" "upsilonapi" "./bin/upsilonapi" "engine.log" 8081

# 2. Upsilon Economy (Go) — before the hub so the S2S seam is live at boot.
# Its database is a separate schema; provision it (migrate + seed the catalog)
# on every start — both are idempotent, so a warm dev volume is a no-op.
echo "[+] Provisioning economy database (migrate + seed)..."
( cd upsiloneconomy \
    && env DATABASE_URL="$ECONOMY_DB_URL" ./bin/upsiloneconomy -migrate \
    && env DATABASE_URL="$ECONOMY_DB_URL" ./bin/upsiloneconomy -seed ) \
    || { echo "[ERROR] economy migrate/seed failed (is the upsiloneconomy DB provisioned? 'docker compose down -v' to reprovision)"; exit 1; }
start_service "Upsilon Economy" "upsiloneconomy" "env DATABASE_URL=$ECONOMY_DB_URL S2S_TOKEN=$DEV_S2S_TOKEN APP_DEBUG=true ./bin/upsiloneconomy" "economy.log" 8092

# 3. Upsilon Hub (API + SSE + SPA). DATABASE_URL comes from the devcontainer
# env; APP_DEBUG=true is required for the '-- DEBUG MODE -- ' exception-prefix
# parity the CLI edge suites assert. ECONOMY_INTERNAL_URL + S2S_TOKEN swap the
# in-process economy for the extracted service (Phase 3).
start_service "Upsilon Hub" "upsilonhub" "env APP_DEBUG=true UPSILON_API_URL=http://localhost:8081 HUB_SPA_DIR=/workspace/upsilonbattleui/dist ECONOMY_INTERNAL_URL=http://localhost:8092 S2S_TOKEN=$DEV_S2S_TOKEN ./bin/upsilonhub" "hub.log" 8090

# 4. Vue Frontend (Vite dev server, proxies /api + /up to the :8085 front door)
start_service "Vue Frontend" "upsilonbattleui" "npm run dev" "vite.log" 5173

echo "---------------------------------------"
echo "All services are running and verified."
echo "Logs: $LOG_DIR/"
echo "Stop: ./scripts/stop_services.sh"
echo "---------------------------------------"

