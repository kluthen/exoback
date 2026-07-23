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
1. **Frontend (`upsilonbattleui`)**:
   - Standalone Vue 3 + Vite SPA (vue-router, Tailwind CSS, TresJS 3D).
   - Served by the hub; talks to `/api/v1` with bearer tokens and listens on the SSE event stream.

2. **Platform Gateway (`upsilonhub`)**:
   - Go service owning auth/identity, matchmaking, economy/loadout, admin, realtime SSE and the database schema.
   - One image serves the API + SPA, runs migrations (`-migrate-mode`) and seeds (`-seed`).

3. **Backend API (`upsilonapi`)**:
   - A high-performance Go JSON API.
   - Handles account management, character statistics, and match state persistence.

4. **Battle Engine (`upsilonbattle`)**:
   - The "calculating brain" that governs active combat sequences.
   - Mathematically simulates initiative, movement validation, and damage systems.

5. **Journey Explorer CLI (`upsiloncli`)**:
   - An interactive terminal tool for API exploration and verification.
   - Supports "Autopilot" sessions to simulate full player journeys.

6. **Shared Assets & Utilities**:
   - `upsilonmapdata`: Geometric board data and obstacle definitions.
   - `upsilonmapmaker`: Procedural generation tools for game boards.
   - `upsilontools`: Common TRPG utilities and helper functions.
   - `upsilontypes`: Shared type definitions and domain models used across all modules.

7. **AWS Infrastructure (`upsilonaws`)**:
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
git clone --recursive git@github.com:ecumeurs/upsilonumbrella.git
```
If you have already cloned the repository, initialize the submodules with:
```bash
git submodule update --init --recursive
```

### Development & Monitoring

#### DevContainer Environment
The project provides a pre-configured development environment via **[.devcontainer/](.devcontainer/)**. This is the recommended way to develop for Upsilon, ensuring a consistent environment across all platforms.

- **Stack:** Go, Node.js 20.
- **Tools:** Postgres client and ATD integration tools.
- **Port Forwarding:**
  - `8085`: Caddy front door (hub API + SSE + SPA)
  - `8090`: Upsilon Hub (direct)
  - `8081`: Upsilon Engine (Go API)
  - `5173`: Vue Frontend (Vite dev server, HMR)

> **Running hub feature tests:** they boot throwaway Postgres containers via
> testcontainers — Docker must be reachable from the environment running
> `go test ./upsilonhub/...`.

#### Service Management
The project includes a suite of scripts in the `scripts/` directory for local service management and testing.

**First-time dev bring-up sequence** (inside the devcontainer):
```bash
./scripts/build_services.sh   # build engine, hub, CLI binaries + SPA
./scripts/seed_ci.sh          # migrate (-migrate-mode full) + seed a fresh DB — required once
./scripts/start_services.sh   # launch engine (:8081), hub (:8090), Vite (:5173)
./scripts/trigger_one_ci_test.sh e2e_customer_onboarding   # run one CLI-backed e2e test
```
> The hub does **not** auto-migrate on boot; `seed_ci.sh` is the one-shot that
> applies the schema and seeds the catalog / test accounts. `trigger_one_ci_test.sh`
> drives the CLI in `--local` mode, which targets the hub directly on `:8090`.

- **[scripts/start_services.sh](scripts/start_services.sh)**: Launches the full Upsilon stack (Upsilon Engine, Upsilon Hub, and Vite dev server) in the background. It automatically verifies that all ports are listening before exiting.
- **[scripts/stop_services.sh](scripts/stop_services.sh)**: Gracefully stops all tracked services and ensures ports are freed.
- **[scripts/check_services.sh](scripts/check_services.sh)**: Lightweight status utility for quick health checks of the local stack.
- **[scripts/watch_services.go](scripts/watch_services.go)**: Real-time TUI dashboard for monitoring CPU/Mem usage and recent errors across all services. Run with `go run scripts/watch_services.go`.
- **[scripts/trigger_all_ci_tests.sh](scripts/trigger_all_ci_tests.sh)**: Executes the full local test suite (E2E + Edge Cases) against the running local stack.

#### Development Utilities
- **[scripts/build_services.sh](scripts/build_services.sh)**: Rebuilds the core binaries (Engine, Hub, CLI) and the SPA bundle.
- **[scripts/clear_matches.sh](scripts/clear_matches.sh)**: Authoritatively clears active match records from the database and engine cache.
- **[scripts/seed_ci.sh](scripts/seed_ci.sh)**: Resets and seeds the database with standard CI testing data.
- **[scripts/zombie_killer.sh](scripts/zombie_killer.sh)**: Forcefully kills any orphaned Upsilon processes (CLI bots, detached engines).
- **[scripts/stress_test.py](scripts/stress_test.py)**: High-concurrency performance orchestration script for load testing.
- **[scripts/repo_status.sh](scripts/repo_status.sh)**: One-shot source-control health check across the umbrella **and all submodules** — branch, short HEAD, push-sync (ahead/behind upstream), submodule-pointer coherence, and working-tree cleanliness, in a single aligned table. Pass `--fetch` to refresh remote-tracking refs first. Exits non-zero if any repo is dirty, has unpushed commits, lacks an upstream, or the umbrella points at a commit that isn't the submodule's checked-out HEAD — making it a handy **pre-/post-push preflight** for this multi-repo tree.

## Continuous Integration & Quality control

UpsilonBattle employs a robust CI/CD pipeline via GitHub Actions to ensure code quality, architectural integrity, and business rule compliance.

### Automated Workflow (`.github/workflows/ci.yml`)
A single **CI Pipeline** runs three staged jobs on push / PR to `main`:
- **Build & Lint**: static analysis (Go vet), verifies all core components build, and checks the Docker images.
- **Go Unit Tests**: Go unit tests for all backend modules (including the hub's testcontainers feature suites).
- **Integration & E2E**: orchestrates the ephemeral [docker-compose.ci.yaml](docker-compose.ci.yaml) stack and runs the `upsiloncli` customer + edge scenario suites — specialized CLI bots simulating real player journeys through the hub and engine.

### Code Health Standards (`scripts/code_health_check.py`)
Upsilon enforces strict maintainability standards across all supported languages (Go, Python, JS, Vue). These are verified locally via the pre-commit hook and in CI.

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
  - `hub-migrate` / `hub-seed`: hub-image init containers (schema + seed).
  - `hub`: the platform gateway serving API + SSE + SPA.
  - `proxy`: Caddy front door on `:8085` (its healthcheck gates the stack).
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
| [upsilonapi default branch carries 15 Dependabot vulnerabilities (7 critical)](issues/Ref_20260722_upsilonapi_dependabot_vulns.md) | 2026-07-22 | Open | High | On pushing to `ecumeurs/upsilonapi` (2026-07-22, go.work-sync dependency comm... |
| [Four match-resolution E2E scenarios race engine game-start and fail on dev machines](issues/Ref_20260722_match_start_race_local_env.md) | 2026-07-22 | Open | Low | The four scenarios act on a match immediately after the SSE `match.found` eve... |
| [GDPR export loses per-game data coverage under the game-agnostic account model](issues/Ref_20260722_gdpr_export_per_game_gap.md) | 2026-07-22 | Open | Medium | Under the 2026-07-22 remodel, upsilonauth's `GET /auth/export` returns accoun... |
| [Migration 000004_player_stats is not idempotent — breaks database.Baseline() against an already-migrated DB](issues/ISS-121_20260723_baseline_player_stats_not_idempotent.md) | 2026-07-23 | Resolved | High | `db/migrations/000004_player_stats.up.sql` issues a bare `CREATE TABLE public... |
| [Admin User Registry Leaks `full_address`/`birth_date` in Plaintext](issues/ISS-116_20260712_admin_users_endpoint_leaks_private_fields.md) | 2026-07-12 | Open | Medium | `rule_admin_access_restriction` (`upsilonapi`) documents: *"Administrators MU... |
| [CLI HTTP Client Unconditionally Injects Request ID — "Missing Request ID" Path Untestable via E2E](issues/ISS-115_20260711_cli_client_cannot_omit_request_id.md) | 2026-07-11 | Open | Low | `upsiloncli`'s HTTP client (`Client.Do` in `upsiloncli/internal/api/client.go... |
| [Character Reroll Has No Post-Match Gate — Documented "Creation Flow Only" Availability Rule Is Unenforced](issues/ISS-113_20260710_reroll_no_post_match_gate.md) | 2026-07-10 | Open | Medium | `upsilonbattle/docs/mech_character_reroll.atom.md` — the atom the `reroll` ha... |
| [CLI Harness Blocks Negative-Path Testing of Admin-Gated Endpoints](issues/ISS-112_20260710_admin_negative_path_untestable_via_cli.md) | 2026-07-10 | Open | Medium | `upsiloncli`'s scripting bridge hard-blocks any `admin_`-prefixed route call ... |
| [Skill Cooldown Is Set on Cast but Never Decremented — Permanent Lockout](issues/ISS-111_20260710_skill_cooldown_never_decrements.md) | 2026-07-10 | Open | High | `paySkillCost` sets `sk.Cooldown = skpc.GetMaxValue()` when a skill is cast (... |
| [PVE AI Can Wipe the Player's Squad Before the Human Gets a Single Turn](issues/ISS-110_20260710_pve_ai_can_sweep_before_player_turn.md) | 2026-07-10 | Open | Medium | Turn initiative in `1v1_PVE` matches is decided by a per-entity random delay ... |
| [Jump-Height Rejection Edge Is Structurally Unreachable via E2E](issues/ISS-109_20260710_jump_height_edge_unreachable.md) | 2026-07-10 | Open | Medium | The jump-height move-validation edge (`entity.path.notvalid`, mechanic rule 9... |
| [Board Generation Does Not Guarantee Obstacles Near Spawns](issues/ISS-108_20260710_obstacle_not_adjacent_to_spawn.md) | 2026-07-10 | Open | Medium | The `entity.path.obstacle` move-validation edge (mechanic #7 of `[[mech_move_... |
| [Audit the upsiloncli edge-case scenario suite — scenario assertions, not mechanics, are what fail CI](issues/ISS-107_20260709_edge_case_scenario_suite_audit.md) | 2026-07-09 | Open | Medium | After the Phase 6 CI green-up (submodule token, engine/CLI image builds, Ryuk... |
| [Stored skill payloads with PHP-era `[]` empty objects break arena start; join still reports "matched"](issues/ISS-106_20260709_php_empty_array_skill_payload_start_failure.md) | 2026-07-09 | Open | Low (downgraded 2026-07-09 — see "Post-wipe update") | Two stacked defects, found during the Phase 6 E6 resurrection drill: |
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

