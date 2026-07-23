# Session 2026-07-23 — handoff (Phase 4 code COMPLETE + GREEN; E2E + pointer-bump remain)

Continues `03_phase4_auth_cutover_design.md` (the design lock — READ IT FIRST). Supersedes the
session-1 state that was here (ISS-120 done; hub Wave-2 did-not-compile). **Session 2 finished the
hub finish-list and the tests: all three submodule branches now build/vet/test GREEN.** Nothing is
pushed. Code branches are committed; the umbrella infra + pointer bump are deliberately NOT
committed yet (see §4).

## 1. Status at a glance

| Repo | Branch | State |
|---|---|---|
| upsilonauth | `phase4-auth-cutover-authside` @ `e6d4755` | COMPLETE/green (session 1) — public admin group + durable AccountPush producer |
| upsilonhub | `phase4-player-stats` | **COMPLETE/GREEN** — `go build`+`go vet`+`go test ./...` all pass (gateway+battle 113/113) |
| upsiloncli | `phase4-infra-cli` | **COMPLETE/GREEN** — build/vet/test pass; register→login→enroll→play scenarios wired |
| umbrella | `main` | docs/issues committed; **infra (docker-compose.ci.yaml + scripts) + submodule pointer bumps UNCOMMITTED on purpose** — land atomically after E2E (§4) |

ISS-120 (mandatory request_id) remains done + merged to main from session 1 (platform `d41252b`,
economy `e95b07f`, auth `9dfa336`, hub `1e4c6a8`, umbrella `2055937`). sqlc v1.31.1 installed
(`export PATH="$(go env GOPATH)/bin:$PATH"`; needs go1.26, auto-switches).

## 2. What session 2 built (the hub cutover, on top of checkpoint `3e9479e`)

Production compile-core (all now green):
- **matchmaking.go / matchmaking_status.go** — retired `identity.Service`/`identity.User` →
  `playerstats.Service` + `identity.Principal`. `Matchmaker.Identity` field → `Players`;
  `assembleMatch` reads queued account names and the joiner's AI-grade `TotalWins` from `player_stats`.
- **config.go** — `AuthInternalURL` (env `AUTH_INTERNAL_URL`) + crash-early if set without `S2SToken`.
  Hard cutover: **no rollback flag** (unlike economy's `ECONOMY_INTERNAL_URL`).
- **router.go** — `Deps` reshaped: `Identity` is now `identity.Authenticator`; added `PlayerStats`,
  `Registrar` (`identity.ServiceRegistrar`), `S2SToken`. **`mountAuth` deleted** (Caddy routes
  `/api/v1/auth/*` + `/admin/users*` to upsilonauth). All `AuthDeps{Clock}`/`TokenRenewal()` removed
  from shop/leaderboard/game/events/matchmaking mounts.
- **main.go** — wires `authclient.New(cfg.AuthInternalURL, cfg.S2SToken)` (serves both `Authenticator`
  and `ServiceRegistrar`) + `playerstats.NewPG`; injects `Players` into the Matchmaker, `S2SToken` into Deps.
- **NEW enroll.go** — `POST /api/v1/battle/enroll` (RequireAuth): `player_stats.Create` → roster
  (generate only if empty) → `RegisterService(tactical)`. Idempotent-forward (not txn); already-enrolled
  callers short-circuit. **Order matters:** Create must precede the roster read because
  `ListByPlayer` inner-joins `player_stats` (see below).
- **NEW internal_consumer.go** — `mountInternal`: `POST /internal/v1/players/:id/account` →
  `playerstats.UpsertAccount`, guarded by `RequireInternalToken(S2SToken)` + `RequireRequestID()`.
- **identity.ServiceRegistrar** seam added; `authclient.Client` asserts both seams.

Tests (Sonnet agent, `internal/gateway/*_test.go`):
- `authenv_test.go` — `fakeAuthenticator` implementing `Authenticator`+`ServiceRegistrar`;
  `createUserFull` seeds a `player_stats` row + registers a default `Principal{Role:"User",
  Registrations:["tactical"]}`; `issueToken` mints a plaintext and maps it in the fake
  (`identity.IssueToken` is gone).
- `phase5env_test.go` — `setUserField` routes by column: `role`→fake principal, stats cols→`player_stats`,
  else (e.g. `credits`, still hub-owned)→`users`.
- `matchmaking_pve_test.go` — the `total_wins = 15` seed retargeted `users`→`player_stats`.
- **NEW enroll_test.go** — fresh-enroll provisioning, idempotent re-enroll, RequireAuth gate.

CLI (Sonnet agent, `phase4-infra-cli`): `battle_enroll` inserted into the remaining register→…→play
scenarios/samples; `AuthLogin.Next()` fixed (was missing `battle_enroll`, could dead-end a fresh
account into matchmaking with no roster).

## 3. Bug found + fixed this session

- **enroll.go ordering (caught by the new enroll test):** the handler generated the roster *before*
  the `player_stats` row, but `ListCharactersByPlayer` inner-joins `player_stats` — so enroll returned
  an empty roster and a crash-retry between the two steps doubled the roster. Fixed by reordering to
  Create → roster → register. Test-first per CODING_RULE §5.
- **ISS-121 (High) — RESOLVED:** migration `000004_player_stats.up.sql` had a bare `CREATE TABLE`,
  so `database.Baseline()` replay (a retried cutover deploy, or the Laravel-DB adopt path) hard-failed
  with `relation "player_stats" already exists`. Fixed: `CREATE TABLE IF NOT EXISTS` + backfill INSERT
  `ON CONFLICT (user_id) DO NOTHING`; `schema_test.go` expected version `3`→`4` (both asserts).
  `TestBaselineAdoptsLaravelMigratedDatabase` + full suite green. Issue marked Resolved.

## 4. NEXT SESSION — do this, in order

1. **Boot the 6-image CI stack and prove the new flow.**
   `docker compose -f docker-compose.ci.yaml down -v && docker compose -f docker-compose.ci.yaml up -d --build --wait`
   then `docker compose -f docker-compose.ci.yaml exec -T -w /app/upsiloncli tester sh ./tests/run_all_scenarios.sh`
   (run from `/app/upsiloncli` with **`sh`**, not bash — busybox). Prove **register→login→enroll→play**
   end-to-end. Expect the pre-existing ISS-119 race/privacy flakes; anything else is a real regression.
   The compose already wires hub `AUTH_INTERNAL_URL`/`depends_on auth` and auth `HUB_INTERNAL_URL` +
   shared `S2S_TOKEN` (uncommitted umbrella working tree).
2. **Only after E2E green: commit the umbrella infra + bump pointers ATOMICALLY.** The umbrella working
   tree still holds `docker-compose.ci.yaml` + `scripts/{build,start,stop}_services.sh` UNCOMMITTED, plus
   the three submodule pointer bumps (`M upsilonauth/upsiloncli/upsilonhub`). These MUST land in one
   commit together — committing the auth-wired compose to `main` while the hub pointer still points at
   the pre-cutover commit would break `main` CI. (This is why session 2 committed only the docs.)
3. Then consider merging the three submodule branches to their `main`s + pushing (ask Bastien).

## 5. Gates & follow-ups
- **ISS-118 / Ref_20260722_gdpr_export_per_game_gap** (per-game GDPR export) — resolve before any prod cutover.
- ISS-120 follow-ups (non-blocking): OTel trace-context across the River boundary; the pre-existing
  CONTRACT-as-@spec-link debt across the kit; relocate `api_request_id` atom out of upsilonapi.
- Pre-existing debt the CLI agent flagged (out of scope, worth issues): `endpoints.go`/`bridge_battle.go`
  nesting+LOC; `auth.go`/`registry.go` 0 ATD links; `samples/pve_2v2_battle_loner.js` never registers;
  `samples/progression_test_winner.js` calls a non-existent `api_profile_character_upgrade`.
- Phase 5 (later): drop `users`/PAT/economy tables + prod cutover runbook (NEVER run against AWS without Bastien).

## 6. Gotchas
- Monthly spend limit killed the session-1 Wave-2 agents; session-2 agents completed fine — watch for it.
- CONTRACT atoms are NEVER @spec-link/@test-link targets (link REQUIREMENT/MECHANIC; request-id → `[[upsilonapi:api_request_id]]`).
- The hub Caddyfile is in `upsilonhub/deploy/Caddyfile`, NOT the umbrella (already routes auth/* + admin/users* → auth, black-holes /internal/*).
- Feature tests never reach a live auth — they inject `fakeAuthenticator`; `AUTH_INTERNAL_URL` stays empty in-test.
