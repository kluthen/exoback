# UpsilonBattle: Tactical RPG

**UpsilonBattle** is a simple, turn-based Tactical RPG (TRPG) designed for concurrent multiplayer combat and AI skirmishes. Designed entirely around the Atomic Documentation (ATD) framework, its concepts separates game logic, mechanics, and architectural boundaries into standalone, single-responsibility specifications.

## The Game At a Glance
- **Play Modes:** 1v1 (PvE or PvP) and 2v2 (PvE or PvP).
- **The Board:** A randomly generated rectangular grid (5-15 tiles per dimension, absolute minimum area of 50 tiles) containing up to 10% randomly placed impassable obstacles.
- **Victory Condition:** Eliminate all characters on the opposing team. **Friendly Fire is strictly disabled.**
- **The Roster:** Every player commands a roster of exactly 3 characters.

## Character System & Progression
- **Initial Core Roll:** New characters start with base stats (3 HP, 1 Move, 1 Attack, 1 Def) and exactly 4 additional points are randomly dispatched (Total 10 points). 
- **The Reroll Mechanic:** During account registration, players are granted an option to completely re-randomize their 3 initial character stat blocks. This reroll can be executed a strict maximum of **3 times**.
- **Stat Progression:** Securing a match victory rewards a player with 1 Attribute Point. 
  - **Constraints:** Total attributes cannot exceed `10 + total wins`. Matches result in a maximum of 1 point gain.
  - **Movement Restriction:** Upgrading the Movement attribute is heavily throttled and locked to once every 5 accumulated wins.

## Combat Mechanics
- **Initiative & Delay:** Turn order is non-linear. Characters roll a pre-initiative value ranging from `1-500`. Active turns fire when the ticker hits `0`. 
- **Action Economy:** During a turn, a character may perform a maximum of **1 Move** (`+20/tile`), **1 Attack** (`+100`), or safely **Pass** (`+300`). Performing actions accumulates a numerical "Delay Cost," mathematically extending the wait time until that character's next sequence.
- **The Shot Clock:** Active combat turns mandate a strict **30-second limit** per character. Failing to confirm an action manually results in an auto-pass forced by the server, accompanied by a penalty of `+100` (Total `+400` delay).

## Modular Architecture
The UpsilonBattle ecosystem is built as a modular multi-repo system. Each core component is maintained in its own repository and integrated into this main project as a formal **Git Submodule**.

### Repository Structure
1. **Frontend (`battleui`)**:
   - Built with Laravel, Vue.js, and Tailwind CSS.
   - Manages user sessions, JWT authentication, and player matchmaking.
   - Provides the visual interface for combat and the global leaderboard.

2. **Backend API (`upsilonapi`)**:
   - A high-performance Go JSON API.
   - Handles account management, character statistics, and match state persistence.

3. **Battle Engine (`upsilonbattle`)**:
   - The "calculating brain" that governs active combat sequences.
   - Mathematically simulates initiative, movement validation, and damage systems.

4. **Journey Explorer CLI (`upsiloncli`)**:
   - An interactive terminal tool for API exploration and verification.
   - Supports "Autopilot" sessions to simulate full player journeys.

5. **Shared Assets & Utilities**:
   - `upsilonmapdata`: Geometric board data and obstacle definitions.
   - `upsilonmapmaker`: Procedural generation tools for game boards.
   - `upsilontools`: Common TRPG utilities and helper functions.
   - `upsilontypes`: Shared type definitions and domain models used across all modules.

6. **AWS Infrastructure (`upsilonaws`)**:
   - Bash-based provisioning scripts for deploying the full stack to AWS (eu-west-3).
   - Manages: VPC, EC2 (t3.medium), RDS PostgreSQL 15, Route 53 DNS, nginx + Let's Encrypt SSL.
   - Public endpoint: [upsilon-hub.com](https://upsilon-hub.com) — run `setup.sh` to provision, `teardown.sh` to wipe everything.
   - Designed for pay-per-session use (~$0.075/hour, $0.50/month for Route 53 zone).

## Setup

The Upsilon project is a complex ecosystem. For a detailed guide on how to prepare your environment, install dependencies, and configure the system, please refer to the **[Setup Documentation](Setup.md)**.

## Getting Started

### Cloning the Project
Since the project relies on submodules, you must clone recursively to fetch all components:
```bash
git clone --recursive git@github.com:ecumeurs/upsilon-hub.git
```
If you have already cloned the repository, initialize the submodules with:
```bash
git submodule update --init --recursive
```

### Development & Monitoring

#### DevContainer Environment
The project provides a pre-configured development environment via **[.devcontainer/](.devcontainer/)**. This is the recommended way to develop for Upsilon, ensuring a consistent environment across all platforms.

- **Stack:** PHP 8.4, Go, Node.js 20.
- **Tools:** Includes Composer, Postgres client, and ATD integration tools.
- **Port Forwarding:**
  - `8000`: Laravel App
  - `8080`: Reverb (WebSockets)
  - `8081`: Upsilon Engine (Go API)
  - `5173`: Vue Frontend (HMR)

> **Running PHP unit tests:** the suite runs against **PostgreSQL** (the
> migrations use Postgres-only DDL that SQLite cannot build), so a dedicated
> `testing` database must exist on the `db` service. Create it once, then run
> the tests from `battleui/`:
> ```bash
> # inside the dev container
> psql -h db -U postgres -c 'CREATE DATABASE testing;'   # password: postgres (one-time)
> cd battleui && php artisan test
> ```
> Connection defaults (host `db`, database `testing`, user/pass `postgres`) live
> in `battleui/phpunit.xml`.

#### Service Management
The project includes a suite of scripts in the `scripts/` directory for local service management and testing:

- **[scripts/start_services.sh](scripts/start_services.sh)**: Launches the full Upsilon stack (Laravel API, Reverb Server, Vue Frontend, and Upsilon Engine) in the background. It automatically verifies that all ports are listening before exiting.
- **[scripts/stop_services.sh](scripts/stop_services.sh)**: Gracefully stops all tracked services and ensures ports are freed.
- **[scripts/check_services.sh](scripts/check_services.sh)**: Lightweight status utility for quick health checks of the local stack.
- **[scripts/watch_services.go](scripts/watch_services.go)**: Real-time TUI dashboard for monitoring CPU/Mem usage and recent errors across all services. Run with `go run scripts/watch_services.go`.
- **[scripts/trigger_all_ci_tests.sh](scripts/trigger_all_ci_tests.sh)**: Executes the full local test suite (E2E + Edge Cases) against the running local stack.

#### Development Utilities
- **[scripts/build_services.sh](scripts/build_services.sh)**: Rebuilds core service binaries (API and Engine).
- **[scripts/clear_matches.sh](scripts/clear_matches.sh)**: Authoritatively clears active match records from the database and engine cache.
- **[scripts/seed_ci.sh](scripts/seed_ci.sh)**: Resets and seeds the database with standard CI testing data.
- **[scripts/zombie_killer.sh](scripts/zombie_killer.sh)**: Forcefully kills any orphaned Upsilon processes (CLI bots, detached engines).
- **[scripts/stress_test.py](scripts/stress_test.py)**: High-concurrency performance orchestration script for load testing.

## Continuous Integration & Quality control

UpsilonBattle employs a robust CI/CD pipeline via GitHub Actions to ensure code quality, architectural integrity, and business rule compliance.

### Automated Workflows (`.github/workflows/`)
- **[Unit Tests](.github/workflows/unit-tests.yml)**: Runs Go unit tests for all backend modules and PHP unit tests for the Laravel frontend.
- **[Lint & Build](.github/workflows/lint-and-build.yml)**: Performs static analysis (Go vet) and verifies that all core components and Docker images build successfully.
- **[E2E Battle Tests](.github/workflows/e2e-battles.yml)**: Orchestrates a full ephemeral Docker stack to run integration tests. It uses specialized CLI bots to simulate real player journeys and verify complex game mechanics.

### Code Health Standards (`scripts/code_health_check.py`)
Upsilon enforces strict maintainability standards across all supported languages (Go, Python, PHP, JS, Vue). These are verified locally via the pre-commit hook and in CI.

- **File Length:** Maximum 300 LOC (Warning), 500 LOC (Error).
- **Complexity:** Function nesting depth must not exceed 3 levels.
- **Documentation:** Functions should have > 30% comment density (Warning) and > 50% (Error threshold for critical paths).
- **ATD Traceability:** Each file must have 2-5 `@spec-link` tags. Under 2 or over 10 links results in an Error.
- **Validity:** All `@spec-link` IDs must resolve to a valid ATD Atom in the `docs/` directory.

**Exemptions:**
Individual checks can be bypassed using specific tags:
- `@lint-ignore-file-bloating`
- `@lint-ignore-complexity`
- `@lint-ignore-documentation`
- `@lint-ignore-atd`

### CI Infrastructure (Docker Stack)
The project utilizes a dedicated **[docker-compose.ci.yaml](docker-compose.ci.yaml)** to spin up an ephemeral testing environment. This stack is optimized for speed and reliability.

- **Components:**
  - `db`: Postgres 18-alpine database.
  - `db-init`: Migration and seeding service.
  - `app`: The Laravel application.
  - `ws`: Reverb WebSocket server.
  - `engine`: The Upsilon Battle Engine (Go).
  - `tester`: The Upsilon CLI running in integration mode.
- **Usage:**
  ```bash
  docker compose -f docker-compose.ci.yaml up -d --wait
  ```

- **CI Reports**: Each run generates a summary report ([ci_report.sh](tests/ci_report.sh)) that is attached to the job summary, providing immediate visibility into test outcomes and compliance status.

## Specification (ATD) Maps
All fundamental mechanics, structural constraints, entities, and network rules that form the game are housed individually within the project-specific `docs/` folders (e.g., `upsilonapi/docs/`, `upsilonbattle/docs/`) governed by the ATD Workspace. These Atoms serve as the uncompromising basis for evaluating developer implementation logic.

## Open Issues

| Name | Date | Status | Severity | Oneliner |
|---|---|---|---|---|
| [CLI scenarios that idle past TokenTTL between requests 401 mid-fight](issues/ISS-105_20260709_cli_token_starvation_long_fights.md) | 2026-07-09 | Open | Low | Hub tokens have `TokenTTL = 15m` with sliding renewal after 10m (`identity.go... |
| [Parallel joins can strand a queue entry that then poisons every later 1v1_PVE join](issues/ISS-104_20260708_matchmaking_parallel_join_queue_poison.md) | 2026-07-08 | Open | High | `Matchmaker.Join` enqueues the joiner, then takes `QueueHead(scope, required)... |
| [e2e_battle_starts_privacy_check asserts foe-loadout masking that no stack ever implemented](issues/ISS-103_20260707_privacy_check_asserts_unimplemented_masking.md) | 2026-07-07 | Open | Medium | `e2e_battle_starts_privacy_check` asserts foe entities expose no `equipped_sk... |
| [Forfeit rejected in the engine's startup window right after match.found](issues/ISS-102_20260707_forfeit_before_engine_start_window.md) | 2026-07-07 | Open | Medium | Between arena creation and the engine's first tick, the arena is not yet "in ... |
| [Devcontainer lost WebGL — Playwright 3D visual specs cannot render](issues/ISS-100_20260616_devcontainer_webgl_playwright_visual.md) | 2026-06-16 | Open | Medium | Headless Chromium in the current devcontainer **cannot create a WebGL context... |
| [Action Endpoint Segregation](issues/ISS-090_20260427_action_endpoint_segregation.md) | 2026-04-27 | Open | Medium | Currently, all tactical actions (move, attack, skill, pass) are funneled thro... |
| [Deterministic Daily Random Shop](issues/ISS-089_20260426_mechanic_random_shop_algorithm.md) | 2026-04-26 | Open | Medium | Implementation of a daily rotating shop system that provides a deterministic ... |
| [Grid Generator Tuning - Large and Flat Maps](issues/ISS-087_20260426_grid_generator_tuning.md) | 2026-04-26 | Open | Medium | Since the integration of the `gridgenerator`, battle maps have been observed ... |
| [Cross-stack error handling harmonization](issues/ISS-081_20260425_cross_stack_error_handling.md) | 2026-04-25 | Open | Medium | `error_key` is currently propagated only on the engine action paths (`POST /g... |
| [ATD for `error_key` taxonomy and possible envelope promotion](issues/ISS-080_20260425_error_key_atd_and_envelope.md) | 2026-04-25 | Open | Medium | `error_key` is now plumbed end-to-end (engine ruler → upsilonapi handler → La... |
| [Standardize cell access on Y-major layout](issues/ISS-079_20260424_cell_access_y_major_standard.md) | 2026-04-24 | Open | Medium | The tactical grid is currently serialized width-major (`cells[x][y]`) by the ... |
| [Shielding Credit Attribution System](issues/ISS-078_20260423_shielding_credit_attribution.md) | 2026-04-23 | Open | Medium | Design and implement a robust system for attributing credits earned through d... |
| [Skill Inspection Command](issues/ISS-077_20260423_skill_inspection.md) | 2026-04-23 | Open | Medium | Implement skill inspection functionality allowing players to view detailed sk... |
| [Player Choosing Facing Direction on Pass](issues/ISS-072_20260423_pass_choose_facing.md) | 2026-04-23 | Open | Medium | When a player chooses to "Pass" their turn, they must be given the option to ... |
| [Actor Message Type Validation](issues/ISS-055_20260420_actor_message_validation.md) | 2026-04-20 | Open | Low | The `Actor` implementation should validate if the target message is of the co... |
| [Modernize Actor Library with Go Generics (Templates)](issues/ISS-049_20260418_actor_generics_modernization.md) | 2026-04-18 | Open | Low (Architectural Improvement) | The current Actor implementation was designed before Go 1.18 (Generics). It r... |

