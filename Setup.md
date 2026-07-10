# Upsilon Production Stack Setup Guide

This document details the architecture, configuration, and operation of the Upsilon production environment.

## 1. Architecture Overview

The Upsilon system is orchestrated using Docker Compose (Project Name: `upsilon-prod`) across six specialized services:

| Service | Responsibility | Healthcheck |
|---|---|---|
| `db` | PostgreSQL 18 database for all system state. | `pg_isready` |
| `db-init` | Hub image running `-migrate-mode full` on startup (applies the embedded schema + River from scratch on a fresh DB). | (One-shot) |
| `hub` | Go platform gateway serving the REST API, the SSE realtime stream and the SPA on `:8090`. | (via `proxy`) |
| `proxy` | Caddy front door; publishes the client port and gates the stack on `:8085/up`. | `wget :8085/up` |
| `engine` | Go-based battle engine for damage computation and logic. | `http://localhost:8081/health` |
| `cli` | Interactive CLI runner for debug and administrative tasks. | (Active) |

## 2. Shared Secrets Management

To ensure security and consistency, the stack uses a root-level `.env` file generated from `env.example`.

### Automatic Generation
The `scripts/setup_prod.sh` script generates a high-entropy value for:
- `ADMIN_INITIAL_PASSWORD` (gates the admin block of `hub -seed`)

### Propagation
All services share the `.env` file via the `env_file` directive in `docker-compose.prod.yaml`. This avoids duplicating secret definitions across the YAML file.

## 3. Operations Procedure

### First Start (Scratch)
Run the following commands from the project root:
```bash
chmod +x scripts/setup_prod.sh
./scripts/setup_prod.sh
docker compose -f docker-compose.prod.yaml up -d --wait
```

### Persistence & Restarts
The stack is designed for **Persistence-First** operation:
- **Data Safety**: PostgreSQL data is stored in the `db_data` named volume. This survives `docker compose down`, container deletions, and host reboots.
- **Restarts**: `docker compose restart` or `up -d` will not result in data loss. The `db-init` service will verify migrations but will not destructive-seed (it uses `migrate --force`).

### Port Mapping
| Host Port | Service Port | Scope |
|---|---|---|
| `8000` | `8085` | Caddy front door → hub (WebUI + API + SSE) |
| `8081` | `8081` | Go Engine |

## 4. CLI Usage & Scripting

The `cli` service provides a headless environment for executing automation scripts and performing system checks.

### Basic CLI Commands
From the project root on the host, you can interact with the containerized CLI:

*   **System Status**: Verify reachability of the hub (API + SSE) and Go Engine.
    ```bash
    docker compose -f docker-compose.prod.yaml exec cli upsiloncli status
    ```
*   **Help**: List all available flags and commands.
    ```bash
    docker compose -f docker-compose.prod.yaml exec cli upsiloncli --help
    ```

### Available Sample Bots
The CLI container comes pre-loaded with tactical scripts located in `./samples/`. You can execute them directly to test different scenarios:

*   **PvP Battles**: `pvp_1v1_battle.js`, `pvp_2v2_battle.js`, `pvp_1v1_battle_loner.js`, `pvp_2v2_battle_loner.js`
*   **PvE Battles**: `pve_1v1_battle.js`, `pve_2v2_battle.js`, `pve_1v1_battle_loner.js`, `pve_2v2_battle_loner.js`
*   **Stress Testing**: `fast_bot_battle.js`, `slow_bot_battle.js`
*   **Onboarding**: `onboard_and_match.js` (Handles full account registration)

**Example execution:**
```bash
docker compose -f docker-compose.prod.yaml exec cli upsiloncli --farm ./samples/pvp_1v1_battle.js ./samples/pvp_1v1_battle.js
```

Note: PvP 1v1 requires 2 bots, PvP 2v2 requires 4 bots, PvE 1v1 requires 1 bot, PvE 2v2 requires 2 bots started, as they wait for each other in the queue.
Loner scripts are for testing purposes and do not require other bots to be started.

### Introduction to Scripting
The CLI includes a "Farm" coordination engine that executes JavaScript scenarios. Each agent identifies itself via the `upsilon` global object.

#### Core API Reference
*   `upsilon.bootstrapBot(name, password)`: Handles registration, login, and automatic cleanup.
*   `upsilon.joinWaitMatch(mode)`: Joins the queue (e.g., `1v1_PVE`) and blocks until a match is found.
*   `upsilon.waitNextTurn()`: Blocks until it's the bot's turn to act.
*   `upsilon.call(action, params)`: Executes a direct game action (move, attack, pass).
*   `upsilon.planTravelToward(id, target, board)`: Calculates tactical paths toward a target.

#### Sample Test Script: PvE 1v1 Battle
You can run an automated tactical battle between a bot and the engine's internal AI.

1. Create a script named `test_pve.js`:
```javascript
const botName = "prod_tester_" + Math.floor(Math.random() * 1000);
upsilon.bootstrapBot(botName, "SecurePassword123!");

const match = upsilon.joinWaitMatch("1v1_PVE");
upsilon.log("Entered match: " + match.match_id);

while (true) {
    const board = upsilon.waitNextTurn();
    if (!board) break; // Game finished

    const me = upsilon.currentCharacter();
    const enemies = upsilon.myFoesCharacters();
    
    // Simplistic Logic: Move toward the first enemy found
    if (enemies.length > 0) {
        const path = upsilon.planTravelToward(me.id, enemies[0].position, board);
        upsilon.call("game_action", { 
            id: match.match_id, 
            entity_id: me.id, 
            type: "move", 
            target_coords: path.map(p => p.x + "," + p.y).join(";") 
        });
    }
}
```

2. Execute the script in the production stack:
```bash
docker compose -f docker-compose.prod.yaml exec cli upsiloncli --farm samples/pve_1v1_battle.js
```

## 5. Verification
... (rest of the content)
- If services fail to start, check logs: `docker compose -f docker-compose.prod.yaml logs -f`
- To reset everything (destructive): `docker compose -f docker-compose.prod.yaml down -v`


## 6. Administrative Setup (Seeding)
To establish the initial system administrator, you must define a password and run the hub seeder (one-shot container on the prod network):

```bash
docker compose -f docker-compose.prod.yaml run --rm \
  -e ADMIN_INITIAL_PASSWORD="your_secure_password" db-init -seed
```
This will create a default administrator at `admin@admin.com` with the `Admin` role (plus the seeded catalog and test accounts).
## 7. Troubleshooting

### Clearing Stuck Matches
If you find yourself stuck in a match that no longer exists or if the system state becomes inconsistent, you can clear all active matches and participants without resetting the entire database:

```bash
docker compose -f docker-compose.prod.yaml exec db \
  psql -U postgres -d upsilon -c "TRUNCATE table game_matches CASCADE; TRUNCATE table match_participants CASCADE; TRUNCATE table matchmaking_queues;"
```

> [!WARNING]
> This command will globally terminate all active battles for all players. Use it only when necessary.
