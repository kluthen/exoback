#!/bin/bash
cd "$(dirname "$0")/.."

# Configuration
PID_FILE=".services.pids"
# 8092 (economy, Phase 3) and 8091 (auth, Phase 4) were missing from forceful
# cleanup — graceful PID-file stop covered them, but a stuck process on either
# port survived past that step. Added so a bad restart can't wedge either seam.
PORTS=(8090 5173 8081 8092 8091)

echo "---------------------------------------"
echo "Stopping Upsilon Stack..."
echo "---------------------------------------"

# 1. Try graceful stop of tracked PIDs
if [ -f "$PID_FILE" ]; then
    while IFS='|' read -r name pid log_file port; do
        if [ ! -z "$pid" ]; then
            if ps -p "$pid" > /dev/null; then
                echo "[-] Stopping $name (PID: $pid)..."
                pkill -P "$pid" 2>/dev/null
                kill "$pid" 2>/dev/null
            fi
        fi
    done < "$PID_FILE"
    rm "$PID_FILE"
fi

# 2. Forceful port cleanup (Authoritative)
echo "[!] Ensuring ports are free..."
for port in "${PORTS[@]}"; do
    # Find PIDs on the port using ss
    pids=$(ss -tulpn | grep ":$port " | grep -oP 'users:\(\("\S+",pid=\K\d+')
    if [ ! -z "$pids" ]; then
        echo "    Cleaning up port $port (PIDs: $pids)..."
        for pid in $pids; do
            sudo kill -9 "$pid" 2>/dev/null
        done
        sleep 1
    fi
done

# 3. Final Verification
STUCK=0
for port in "${PORTS[@]}"; do
    if ss -tulpn | grep -q ":$port "; then
        echo "[ERROR] Port $port is still in use!"
        STUCK=1
    fi
done

if [ $STUCK -eq 0 ]; then
    echo "---------------------------------------"
    echo "All tracked services stopped."
    echo "---------------------------------------"
else
    echo "---------------------------------------"
    echo "Warning: Some ports remain occupied."
    echo "---------------------------------------"
    exit 1
fi
