---
trigger: always_on
---

# Upsilon Hub: Project Map & Infrastructure

## 1. Project Background
Upsilon Hub is a multi-stack ecosystem designed for high-performance battle engine simulation and management. It bridges a Go-based core logic with a Go platform gateway (the **hub**) and a flexible CLI for automation and testing. Since the Phase 6 cutover the hub owns auth, matchmaking, economy, admin, the realtime SSE stream and the database schema, and serves the standalone Vue SPA — the former Laravel `battleui` is decommissioned.

## 2. Who's Who (Service Architecture)

| Component | Stack | Role | Default Port |
|---|---|---|---|
| **upsilonhub** | Go | Platform gateway — auth/identity, matchmaking, economy, admin, realtime SSE, DB schema; serves the API + SPA | Hub `8090`, front door (Caddy) `8085` |
| **upsilonbattleui** | Vue 3 / Vite | Standalone SPA (management UI + battle client); built and served by the hub | Vite dev: `5173` |
| **upsilonapi** | Go | The "Bridge" - provides API/WS access to the engine | `8081` |
| **upsilonbattle** | Go | Core Battle Engine (BattleArena) | N/A (Embedded) |
| **upsiloncli** | Go | Scripting, E2E Testing, and Bot Orchestration | N/A |
| **upsilontypes** | Go | Shared type definitions and serialization | N/A |

## 3. Folder Organization
- `/upsilonhub`: The Go platform gateway (API, SSE, DB schema, migrations/seed; serves the SPA).
- `/upsilonbattleui`: The standalone Vue 3 + Vite SPA (management UI + battle client).
- `/upsilonapi`: The Go bridge server.
- `/upsilonbattle`: Core engine logic (BattleArena).
- `/upsiloncli`: Command-line tools and E2E test scenarios.
- `/upsilontypes`: Shared Go structures and engine types.
- `/upsilonmapmaker`: Map and grid generation algorithms.
- `/upsilonmapdata`: Shared map and grid data structures.
- `/upsilonserializer`: Specialized Go serialization for engine state.
- `/upsilontools`: Shared developer utilities and helpers.
- `/scripts`: Operational shell scripts for dev, CI, and deployment.
- `/docs`: Shared ATD documentation (Atoms).
- `/issues`: Tracked project risks and technical debt.

## 4. Operational Workflows

### Starting the Stack
- **Standard**: `./build_services.sh` followed by `./start_services.sh`.
- **Validation**: Check health via `scripts/check_services.sh`.

### Match Life Cycle
1. **Creation**: Orchestrated by `battleui` via the API bridge.
2. **Simulation**: `upsilonbattle` executes the core rules.
3. **Observation**: `upsiloncli` or the Vue frontend monitors via WebSocket (`8080`).
4. **Archival**: Results persisted in the database via `battleui`.

### Debugging
- **Log Parsing**: Use `scripts/upsilon_log_parser.sh` to filter engine events.
- **State Audit**: Check `debug_board.json` or match resurrection state (ISS-054).

## 5. Testing Toolkit

### Core Scripts
- `scripts/trigger_one_ci_test.sh <name>`: Run a specific E2E test scenario. Accepts the scenario name with or without the `edge_`/`e2e_` prefix and `.js` suffix (e.g. `movement_entity_collision`).
- `scripts/run_all_unit_tests.sh`: Executes all Go and PHP unit tests.
- `scripts/check_services.sh`: Health check for running docker/local services.
- `scripts/repo_status.sh [--fetch]`: One-shot health check of the umbrella **and every submodule** — branch, HEAD, push-sync (ahead/behind), submodule-pointer coherence, and working-tree cleanliness in one aligned table. Exits non-zero if anything is dirty / unpushed / drifted, so it works as a pre- and post-push preflight. Run it before bumping submodule pointers and after pushing to confirm a coherent snapshot.

### Manual Verification
- `upsiloncli --local --farm`: Starts a local match with automated bot players.
- `scripts/upsilon_log_parser.sh`: Parses and colorizes engine logs for debugging.

## 6. Environments
- **Dev/DevContainer**: Fully containerized environment (Standard for development).
- **CI**: Automated testing via GitHub Actions and `docker-compose.ci.yaml`.
- **Prod**: High-availability deployment via `docker-compose.prod.yaml`.