# Phase 6 Cutover Report — battleui (Laravel) decommissioned, upsilonhub live

**Date:** 2026-07-09
**Scope:** Sub-phases C (SPA extraction) and E (cutover & decommission) of the
Phase 6 plan (doc 07). Sub-phases A/B/D were closed 2026-07-07.

## 1. What changed

| Area | Before (side-by-side) | After (cutover) |
|---|---|---|
| Frontend | Inertia SPA inside `battleui` (Laravel-served) | Standalone **`upsilonbattleui`** repo (Vite + Vue 3 + vue-router), served by the hub (`HUB_SPA_DIR`) |
| Front door | Caddy `:8085` split routing (ported groups → hub, rest → Laravel `:8000`) | Caddy `:8085` → hub only (`HUB_UPSTREAM` placeholder, default `app:8090`) |
| Realtime | SSE (hub) + Reverb still running (rollback) | SSE only; Reverb/WS tier gone |
| Schema | Laravel-migrated, `users.ws_channel_key` present | Hub-owned: migration **000002** drops `ws_channel_key` (+ unique constraint); golang-migrate ledger at version 2 |
| Serving image | Laravel `php:8.4-apache` + Reverb + artisan db-init | One hub image (distroless): serve / `-migrate-mode` / `-seed`; node build stage bakes the SPA at `/srv/spa` |
| CI | php-tests job, Playwright disabled, hub invisible | Go-only unit stage (hub included, testcontainers), Playwright re-enabled from `upsilonbattleui` vs `:8085`, hub+proxy compose stack |
| ATD | `battleui` project, `[[battleui:*]]` links | `upsilonbattleui` project; ~40 files re-linked; websocket/token atoms rewritten to SSE/Go (`atd_check full` clean) |

## 2. Sub-phase C — standalone SPA (closed 2026-07-09)

- Private repo `ecumeurs/upsilonbattleui`, umbrella submodule with relative URL
  `../upsilonbattleui.git`. Standard Vite layout (`src/`, root `index.html`, `public/`).
- Full de-Inertia: vue-router mirrors `web.php` + `/__test/*` seams; zero
  `@inertiajs`/Ziggy references; dead Breeze scaffold deleted; `/api-docs` and
  `/event-test` retired.
- Admin pages moved onto the bearer-authed axios instance (they had silently
  depended on the Laravel session cookie); `UserManagement` fully API-driven.
- All `ws_channel_key` reads removed — SSE is bearer-authed; local channel
  bookkeeping keys on `account_name` (user JSON exposes no id — customer
  user-id privacy).
- **C gate (hub-direct `:8090`):** Playwright **61 passed / 1 skipped / 0 failed**
  (beats the A baseline 53/62 — LED specs fixed by the account_name re-key,
  8 sandbox visual baselines re-captured for the new origin). CLI e2e spot-run
  through `:8085`: **32/37** = A-baseline pass set.
- New issues filed during the gate: **ISS-104** (matchmaking parallel-join
  queue-poison chain, pre-existing Laravel port, High) and **ISS-105** (CLI
  token starvation past the 15-min sliding TTL on very long fights, Low).

## 3. Sub-phase E — cutover steps

- **E1** `000002_drop_ws_channel_key` (+down); field surface removed from
  identity queries/sqlc, `User`, `RotateChannelKey`, `userJSON`, seeders,
  tests. Baseline test asserts stamp-then-apply → version 2.
- **E2** Caddyfile collapsed (SSE keeps `flush_interval -1`); dev compose drops
  the 8000/8080 publishes; CI compose = `db → hub-migrate → hub-seed → hub ←
  proxy` (+ engine, tester via `http://proxy:8085`); prod compose same shape
  with `-migrate-mode baseline` and the historical client port `8000:8085`.
  Hub Dockerfile gained the node build stage; image verified (binary boots,
  `/srv/spa/index.html` present).
- **E3** CI workflow: hub in vet/build/test (600s timeout for testcontainers),
  php-tests job deleted, Playwright steps re-enabled (`--workers=1`,
  `continue-on-error` kept for GPU-less visual specs, ISS-100).
- **E4** ATD flip: `.atd.workspace` repath; `[[battleui:*]]` →
  `[[upsilonbattleui:*]]` (shared docs ×15, upsilonapi/docs ×13,
  upsilonbattle/docs ×9, hub spec-links ×4); content rewrites:
  `api_websocket` master + `game_events` + `user_notifications` +
  `arena_updates` (SSE stream/replay/masking), `mech_sanctum_token_renewal`
  (Go middleware), `infra_mvp_docker` (hub+proxy stack); intra-repo
  `resources/js` → `src` repoints. `atd_check full:true` clean.
- **E5** Scripts: start/stop/build/seed_ci/clear_matches/pre-commit/
  run_all_unit_tests/run_ci_local/trigger_quick_ci_tests/fetch_latest_ci/
  setup_prod off Laravel/artisan/Reverb. Docs: README, Setup.md,
  communication.md rewritten to the hub topology (legacy WS +
  `/broadcasting/auth` sections removed).

## 4. Dev-stack handover (executed live, doubles as the prod runbook proof)

The dev database was Laravel-migrated with no golang-migrate ledger — exactly
the prod shape. Executed 2026-07-09:

1. `upsilonhub -migrate-mode baseline` → stamps 000001 as applied, applies
   000002 (drops `ws_channel_key`); ledger lands at **version 2, clean**.
2. `DROP TABLE migrations;` — Laravel's ledger removed; the hub owns the schema.
3. Laravel (`artisan serve`) and Reverb processes stopped; hub restarted with
   `HUB_SPA_DIR`; proxy reloaded on the collapsed Caddyfile.
4. `GET /up` 200 through `:8085`; seeded `testuser` login OK; user JSON
   carries no `ws_channel_key`.

**Caveat:** golang-migrate (lib/pq) requires `sslmode=disable` on
`DATABASE_URL` when the server has no SSL — the compose files and
`env.example` carry it; add it when running the migrator against any other DSN.

### Prod runbook (not executed — no live prod touched, per decision 2026-07-08)

1. Stop writes: stop the Laravel `app`/`ws` containers (leave `db` up).
2. Back up: `pg_dump` the database.
3. `docker compose -f docker-compose.prod.yaml build` (hub image, SPA baked in).
4. `docker compose -f docker-compose.prod.yaml up -d --wait` — `db-init` runs
   `-migrate-mode baseline` (idempotent; re-runs are no-ops).
5. Verify: front door `/up` 200; testuser (or a real account) login; one PVE
   match over SSE.
6. `DROP TABLE migrations;` (Laravel's ledger) once verified.
7. Decommission the Laravel/Reverb containers and images.
8. Rollback before step 6: `migrate down 1` (restores the column, NULL keys —
   Laravel rotates per login) and restart the Laravel containers.

## 5. Final gate (cutover stack, no Laravel running)

Run 2026-07-09 against the collapsed stack (`:8085` → hub `:8090`, no Laravel/Reverb process):

| Gate | Result | Notes |
|---|---|---|
| `/up` through `:8085` | **200** | proxy → hub only |
| Seeded `testuser` login | **OK** | user JSON carries **no** `ws_channel_key` (000002 confirmed live) |
| Playwright (`upsilonbattleui`, `--workers=1`, host) | **60 passed / 1 skipped / 1 failed** | the 1 failure is `battle_arena.spec.ts:57` — a stored-data quirk (**ISS-106**, PHP-era `[]` skill payload), not cutover-caused; reproduces identically from the old stack |
| CLI e2e (through `:8085`) | **32 / 37** | = the A baseline pass set; the 5 reds are the carried knowns **ISS-102** ×2 (forfeit startup window), **ISS-103** (privacy masking), a friendly-fire flake, **ISS-105** (token starvation on >15-min fights) |
| 1v1 PVE match over SSE | **OK** | join → `matched`, board webhook caches state, match live in engine |
| ISS-054 resurrection drill | **PASS** | match `f51bd05e`: joined → board cached → engine `kill -9` → engine restarted (empty memory) → `matchmaking/status` poll → hub logged `arena missing from engine, attempting resurrection (ISS-054)` then `arena resurrected successfully`; `concluded_at` stayed NULL, status held `matched` ("Reconnecting…"). The correct scenario is crash **and restart** — polling while the engine is fully down instead concludes the match ("Engine communication failure"), which is the intended dead-engine behaviour, not a resurrection path. |

Gate verdict: **green**. The only red is ISS-106, a pre-existing data-shape defect independent of the cutover (filed, workaround applied to the dev seed account).

## 6. Decommission (E5 — done 2026-07-09, user-confirmed)

The cutover stack is green, so battleui is no longer the rollback path. With
explicit sign-off:

1. battleui tagged `archive/laravel-final` at `d57e345` and pushed to origin —
   the Laravel/Inertia final state is recoverable from that tag.
2. `gh repo archive ecumeurs/battleui` — repo archived (`isArchived: true`).
3. `git submodule deinit -f battleui && git rm battleui`, `.gitmodules` stanza
   dropped, `.git/modules/battleui` gitdir cleaned. battleui is no longer a
   submodule of the umbrella.

Rollback, if ever needed, is a git checkout of `archive/laravel-final` plus
un-archiving the repo — the Laravel stack is preserved, just retired.

## 7. Known issues / follow-ups

- **ISS-104** (High): matchmaking parallel-join queue poison — serialize
  enqueue+head+consume or require the joiner's entry in the consumed head set.
- **ISS-105** (Low): CLI keepalive for > 15-min idle gaps mid-fight.
- **ISS-100**: CI/devcontainer WebGL — Playwright visual specs remain
  `continue-on-error` in CI.
- **ISS-102/103**: forfeit startup window / privacy-masking assertion — carried,
  unchanged by the cutover.
- The devcontainer image still contains PHP tooling; pruning it is a separate
  cleanup (deliberate non-goal of Phase 6).
