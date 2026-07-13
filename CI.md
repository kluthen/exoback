# CI Testing Framework

This document outlines the automated verification strategy for Upsilon Battle, ensuring that code changes remain compliant with the Business Requirement Document (BRD) and Atomic Traceable Documentation (ATD).

## Architecture

The CI pipeline is consolidated into a single workflow file (`.github/workflows/ci.yml`) with three primary stages to optimize resource usage and Docker build times:

| Stage | Trigger | Purpose |
|---|---|---|
| **Build & Lint** | Push + PR | Go/PHP syntax checks, Dockerfile validation, compilation |
| **Unit Tests** | Push + PR | Isolated Go and PHP unit tests (PHP on ephemeral PostgreSQL) |
| **Integration & E2E** | Push + PR | Full stack integration, Edge cases, and Playwright UI tests |

### Infrastructure

| Component | File | Purpose |
|---|---|---|
| `.env.ci` | CI environment variables | Deterministic config for ephemeral stack |
| `docker-compose.ci.yaml` | CI Docker Compose | Ephemeral stack with healthchecks |
| `tests/run_all_scenarios.sh` | Scenario Runner | **Centralized discovery & execution** |
| `tests/ci_report.sh` | E2E report generator | Markdown summary of customer scenarios |
| `tests/edge_case_report.sh` | Edge case report generator | Markdown summary of edge case tests |
| `tests/lint_report.sh` | Lint report generator | Markdown summary of linting results |
| `tests/unit_report.sh` | Unit test report generator | Markdown summary of unit tests |

---

## Edge Case Testing

The edge case testing suite validates API boundaries, validation rules, and error handling. All scripts use the `edge_` prefix and are organized by category.

### Test Categories

| Category | Test Count | Priority | Focus |
|---|---|---|---|
| **Movement Validation** | 9 | P0 | Obstacle collision, entity collision, turn/controller mismatch, path validation |
| **Attack Validation** | 9 | P0 | Out of turn, wrong controller, friendly fire, range limits, targeting rules |
| **Authentication** | 5 | P0 | Password policy, invalid credentials, session timeout, missing token |
| **Character & Progression** | 6 | P1 | Reroll limits, stat allocation constraints, movement gate |
| **Matchmaking** | 4 | P1 | Queue restrictions, game mode validation |
| **Match Resolution** | 2 | P2 | Forfeit rules, post-match action prevention |
| **API & Communication** | 4 | P2 | Request validation, error handling |
| **Leaderboard** | 2 | P2 | Mode validation, pagination |
| **Admin** | 3 | P3 | Access control, GDPR compliance |
| **WebSocket** | 3 | P3 | Authentication, channel validation, timeout handling |

**Total Edge Cases**: 47 tests

### Implementation Status

As of 2026-04-25, 47 edge case tests are active (EC-15 retired — see note below):

| EC ID | Test Name | Status |
|---|---|---|
| EC-01 | Movement on Obstacle Tiles | ✅ Implemented |
| EC-02 | Movement on Entity Collision | ✅ Implemented |
| EC-03 | Movement Already Attacked | ✅ Implemented |
| EC-04 | Movement Path Too Long | ✅ Implemented |
| EC-05 | Movement Path Not Adjacent | ✅ Implemented |
| EC-06 | Movement Out of Turn | ✅ Implemented |
| EC-07 | Movement Wrong Controller | ✅ Implemented |
| EC-08 | Movement Grid Boundaries | ✅ Implemented |
| EC-09 | Movement Jump Limitations | ✅ Implemented |
| EC-10 | Attack Out of Turn | ✅ Implemented |
| EC-11 | Attack Wrong Controller | ✅ Implemented |
| EC-12 | Attack Friendly Fire | ✅ Implemented |
| EC-13 | Attack Target Not in Range | ✅ Implemented |
| EC-14 | Attack Target Out of Grid | ✅ Implemented |
| EC-15 | Attack Invalid Cell Type | ⚠️ Retired (see below) |
| EC-16 | Attack No Entity | ✅ Implemented |
| EC-17 | Attack Already Acted | ✅ Implemented |
| EC-18 | Attack Skill Cooldown | ✅ Implemented |
| EC-19 | Attack Targeting Rules | ✅ Implemented |
| EC-20 | Password Policy Full Coverage | ✅ Implemented |
| EC-21 | Invalid Credentials | ✅ Implemented |
| EC-22 | Session Timeout | ✅ Implemented |
| EC-23 | Missing Token | ✅ Implemented |
| EC-24 | Admin Non-Admin Access | ✅ Implemented |
| EC-25 | Character Reroll Limit | ✅ Implemented |
| EC-26 | Reroll After Match | ✅ Implemented |
| EC-27 | Progression Without Wins | ✅ Implemented |
| EC-28 | Progression Attribute Cap | ✅ Implemented |
| EC-29 | Progression Movement Gate | ✅ Implemented |
| EC-30 | Progression Negative Value | ✅ Implemented |
| EC-31 | Queue While Already Queued | ✅ Implemented |
| EC-32 | Queue While in Match | ✅ Implemented |
| EC-33 | Invalid Game Mode | ✅ Implemented |
| EC-34 | Leave Queue Not Queued | ✅ Implemented |
| EC-35 | Forfeit Out of Turn | ✅ Implemented |
| EC-36 | Action After Match End | ✅ Implemented |
| EC-37 | Missing Request ID | ✅ Implemented |
| EC-38 | Invalid UUID Format | ✅ Implemented |
| EC-39 | Malformed JSON | ✅ Implemented |
| EC-40 | 5xx Error Handling | ✅ Implemented |
| EC-41 | Leaderboard Invalid Mode | ✅ Implemented |
| EC-42 | Leaderboard Over Pagination | ✅ Implemented |
| EC-43 | Admin View Private Data | ✅ Implemented |
| EC-44 | Anonymize Non-Existent | ✅ Implemented |
| EC-45 | Soft Delete Non-Existent | ✅ Implemented |
| EC-46 | WebSocket Connection Without Token | ✅ Implemented |
| EC-47 | WebSocket Wrong Channel | ✅ Implemented |
| EC-48 | WebSocket Ping/Pong Timeout | ✅ Implemented |

**Implementation Progress**: 47/47 active tests ✅

> EC-15 ("Attack Invalid Cell Type") was retired on 2026-04-25. The Cell DTO
> exposed externally only carries `obstacle` + `height` after the API trim;
> "invalid cell type" no longer maps onto a distinct concept and the test
> overlapped with EC-01 (obstacle collision). The slot is intentionally left
> unfilled to keep the EC-NN numbering stable across reports and logs.

### Running Edge Case Tests

```bash
# Run specific edge case test
cd upsiloncli
./bin/upsiloncli --farm tests/scenarios/edge_movement_obstacle_collision.js --timeout 60

# Run all edge cases (via CI or runner)
docker compose -f docker-compose.ci.yaml exec tester /bin/sh ./tests/run_all_scenarios.sh
```

### Edge Case Report

The `tests/edge_case_report.sh` script generates a comprehensive markdown report including:
- Individual test results (EC-01 to EC-48)
- Summary statistics (total, passed, failed, skipped, pass rate)
- Coverage by category
- ATD atom references

---

## Customer Requirement Mapping

The following scenarios map directly to the **Conformity Matrix** and validate specific customer-facing requirements. All scripts are located in `upsiloncli/tests/scenarios/`.

| ID | Scenario Name | Primary ATOM | Script |
|---|---|---|---|
| **CR-01** | Complete New Player Onboarding | `[[uc_player_registration]]` | `e2e_customer_onboarding.js` |
| **CR-02** | Player Login & Session Management | `[[uc_player_login]]` | `e2e_customer_login.js` |
| **CR-03** | Character Reroll Mechanics | `[[us_character_reroll]]` | `e2e_character_reroll.js` |
| **CR-04** | Matchmaking Flow (PvE Instant) | `[[uc_matchmaking]]` | `e2e_matchmaking_pve_instant.js` |
| **CR-05** | Matchmaking Flow (PvP Queue) | `[[uc_matchmaking]]` | `e2e_matchmaking_pvp_queue.js` |
| **CR-06** | Combat Turn Management | `[[uc_combat_turn]]` | `e2e_combat_turn_management.js` |
| **CR-07** | Friendly Fire Prevention | `[[rule_friendly_fire]]` | `e2e_friendly_fire_prevention.js` |
| **CR-08** | Match Resolution (Standard) | `[[uc_match_resolution]]` | `e2e_match_resolution_standard.js` |
| **CR-09** | Match Resolution (Forfeit) | `[[uc_match_resolution]]` | `e2e_match_resolution_forfeit.js` |
| **CR-10** | Character Progression (Post-Win) | `[[uc_progression_stat_allocation]]` | `e2e_progression_post_win.js` |
| **CR-11** | Progression Constraints | `[[rule_progression]]` | `e2e_progression_constraints.js` |
| **CR-12** | Leaderboard Viewing | `[[us_leaderboard_view]]` | `e2e_leaderboard_viewing.js` |
| **CR-13** | Password Policy Enforcement | `[[rule_password_policy]]` | `e2e_password_policy.js` |
| **CR-14** | GDPR Data Portability | `[[api_profile_export]]` | `e2e_gdpr_portability.js` |
| **CR-15** | Admin User Management | `[[uc_admin_user_management]]` | `e2e_admin_user_management.js` |
| **CR-16** | Session Timeout Handling | `[[req_security_token_ttl]]` | `e2e_session_timeout.js` |
| **CR-17** | API Self-Discovery | `[[requirement_customer_api_first]]` | `e2e_api_discovery.js` |
| **CR-18** | Admin Full Lifecycle | `[[uc_admin_login]]` | `e2e_admin_full_lifecycle.js` |
| **CR-19** | Admin History Management | `[[uc_admin_history_management]]` | `e2e_admin_history_management.js` |
| **CR-20** | Credit Economy (Damage) | `[[rule_credit_earning_damage]]` | `e2e_credit_economy.js` |

---

## Integration & E2E Testing Strategy

All end-to-end verifications are centralized and executed within a single ephemeral Docker stack to ensure consistency and minimize redundant build steps.

### 1. Centralized Runner (`run_all_scenarios.sh`)
The runner automatically discovers all `e2e_*.js` scripts. It handles:
- **Agent Coordination**: Determines required agent count based on filename (e.g., `pvp` or `combat` triggers 2 agents).
- **Execution**: Runs the `upsiloncli --farm` command.
- **Reporting Contract**: Appends `[SCENARIO_RESULT: PASSED]` to the log file upon successful exit (code 0).

### 2. Scenario Library
All customer-facing scenarios from the **Conformity Matrix** are implemented here:
- `e2e_customer_onboarding.js` (CR-01)
- `e2e_customer_login.js` (CR-02)
- `e2e_character_reroll.js` (CR-03)
- ... (Total of 17 scenarios)

### 3. CI Report Generation
The `tests/ci_report.sh` script parses the logs in `upsiloncli/tests/logs/`. It uses a **unified detection method**: it only marks a test as `✅ PASS` if the success marker `[SCENARIO_RESULT: PASSED]` is present in the log.

---

## Adding a New Edge Case Test

Adding a new edge case test follows the same zero-touch process as customer scenarios:

1.  **Create the Script**: Add a new JavaScript file in `upsiloncli/tests/scenarios/`.
    - **Naming**: Use the `edge_` prefix with descriptive name (e.g., `edge_movement_obstacle_collision.js`)
    - **Pattern**: All edge case tests should follow the try-catch pattern for expected failures
2.  **Add Assertions**: Use the `upsilon` JS API helpers:
    - `upsilon.assert(condition, msg)`
    - `upsilon.assertEquals(actual, expected, msg)`
3.  **Tag with ATD**: Include `@spec-link [[atom_id]]` in the header for traceability
4.  **Update the Report Generator**: Add the new test to `tests/edge_case_report.sh` to ensure it appears in the final CI summary
5.  **Update CI.md**: Add the new test to the implementation status table
6.  **Save & Push**: The CI runner will automatically find your script and include it in the next run

## Adding a New CI Test

Adding a new verification scenario is a **zero-touch process** (no GitHub Actions YAML edits required):

1.  **Create the Script**: Add a new JavaScript file in `upsiloncli/tests/scenarios/`.
    - **Naming**: Use the `e2e_` prefix. If it requires 2 agents (PVP/Combat), include `pvp` or `combat` in the name.
2.  **Add Assertions**: Use the `upsilon` JS API helpers:
    - `upsilon.assert(condition, msg)`
    - `upsilon.assertEquals(actual, expected, msg)`
3.  **Tag with ATD**: Include `@spec-link [[atom_id]]` in the header for traceability.
4.  **Update the Report Generator**: Add the new requirement to the `check_brd` mapping in `tests/ci_report.sh` to ensure it appears in the final CI summary.
5.  **Save & Push**: The CI runner will automatically find your script and include it in the next run.

---

## Running Locally

### PHP Unit Tests (PostgreSQL)
PHP unit tests run against PostgreSQL, not SQLite — several migrations use
Postgres-only DDL (`ALTER TABLE ... ADD CONSTRAINT ... CHECK`) that SQLite
cannot build. The connection defaults (host `db`, database `testing`, user/pass
`postgres`) are set in `battleui/phpunit.xml`.

```bash
# Inside the dev container: create the dedicated test database once, then run.
psql -h db -U postgres -c 'CREATE DATABASE testing;'   # password: postgres
cd battleui && php artisan test
```

Tests tagged `#[Group('engine-required')]` (e.g. `UpsilonApiRoundtripTest`) make
real calls to the Go engine and are excluded from the unit run via
`--exclude-group=engine-required`.

To reproduce the CI job exactly (ephemeral postgres + production-style image),
use `scripts/run_ci_local.sh --stages unit`.

### Full E2E Stack
```bash
# 1. Boot Docker stack
docker compose -f docker-compose.ci.yaml up -d --wait

# 2. Build CLI
cd upsiloncli && go build -o bin/upsiloncli cmd/upsiloncli/main.go && cd ..

# 3. Run the Suite
docker compose -f docker-compose.ci.yaml exec tester /bin/sh ./tests/run_all_scenarios.sh

# 4. Generate Report
./tests/ci_report.sh > ci_report.md
```
