# 07 — Phase 6 Execution Plan: Cutover & Decommission

> Drafted 2026-07-07 from three recon sweeps (proxy/compose/hub readiness, ATD link surface,
> E2E gates + remaining Laravel surface). Decisions in §1 made by Bastien on 2026-07-07.
> Supersedes the one-paragraph Phase 6 sketch in doc 02 §5 where they differ.

## 1. Decisions (2026-07-07)

| Decision | Choice |
|---|---|
| SPA home | **New `upsilonbattleui` submodule** (SPA source + battleui's frontend-only docs corpus). Three more game-UI submodules will follow in v3.0, so per-game UI repos are the pattern. battleui repo archived whole (tag `archive/laravel-final`). |
| `/api/v1/help` | **Retired.** upsiloncli's startup route registry becomes static (it no longer boots off `/help`); the SPA ApiDocs page is removed during de-Inertia. This deliberately amends acceptance gate 3 ("upsiloncli unmodified") — the CLI needs a transport change anyway (§2.D). |
| Sub-phase order | **A → (B, C, D in any order) → E.** A (E2E gates through `:8085`) first; E (archive/delete/ATD flip) strictly last — Laravel stays the rollback path until A–D are green. |

## 2. Sub-phases

### A — E2E gates through the proxy front door (`:8085`)  ← current
The kickoff's caveat (b) backlog, cleared against the side-by-side stack **before any deletion**:

> **Status 2026-07-07 (sub-phase A complete ✅):** Playwright 53/62 (7 stale visual baselines
> reproduced against Laravel-direct, 1 pre-existing arena race — none cutover-caused). upsiloncli
> suites through `:8085` after the D transport work landed early (see §2.D): e2e 32/38, edge 49/55
> first pass. Fixed along the way, all hub parity bugs the gates exposed:
> `filterValidateInt` (Laravel `integer` rule accepts numeric strings — admin CRUD 422s),
> and the **APP_DEBUG exception-prefix parity** (`respond.ExceptionError`: exception-derived
> errors — ModelNotFound 404s, policy 403s, 401, 422, admin abort — carry Laravel's
> `-- DEBUG MODE -- ` prefix when `APP_DEBUG=true`; direct ApiResponder errors don't).
> **The hub must run with `APP_DEBUG=true` in the dev/CI test stack** or the CLI's
> debug-gated loose message matching never engages (5 edge scenarios). Remaining failures
> attributed and filed: ISS-102 (forfeit in the engine's startup window, exposed by SSE latency),
> ISS-103 (privacy scenario asserts unimplemented foe-loadout masking, red on both stacks),
> plus the two friendly-fire scenarios (pre-existing gameplay-randomness flakiness).
>
> **A4 drill (2026-07-07): ✅ green — after an engine fix.** The first drill failed with
> `engine refused resurrection: mandatory field callback_url is missing`: the engine's
> `HandleArenaResurrect` bound the **bare** `ArenaResurrectRequest` while every other arena
> endpoint (and both the PHP and Go gateway clients) sends the Standard Envelope — live
> ISS-054 resurrection had therefore never worked from either stack. Fixed engine-side
> (`api.ArenaResurrectMessage` envelope binding in `upsilonapi/handler/handler.go`, alias in
> `api/input.go`; engine build + tests green). Drill rerun through `:8085`: join `1v1_PVE` →
> kill/restart engine (active matches 0) → `GET /matchmaking/status` → hub log
> `arena resurrected successfully`, status `matched` ("Match in progress. Reconnecting..."),
> engine active count back to 1, restored board playable (2 players, `current_entity_id`
> scheduled, version = 1 tick).
>
> **A5 (real-engine skill roll): ✅** — `e2e_skill_roll_inventory`/`_naming` passed in the A3
> suite through `:8085`, and a rerun against the rebuilt engine shows the live
> `POST /v1/skills/generate` hits in the engine log.

1. Full dev stack up: `db`, `proxy` (Caddy `:8085`), `otel-collector`, and inside the `app`
   devcontainer: Laravel `:8000`, Reverb `:8080`, engine `:8081`, hub `:8090`; SPA assets built.
   Real `.env` must carry `UPSILON_WEBHOOK_URL=http://proxy:8085/api/webhook/upsilon`.
2. Playwright: `baseURL` becomes env-driven (`PLAYWRIGHT_BASE_URL`, default unchanged), suite run
   against `:8085` with `PLAYWRIGHT_SKIP_SERVER=1`. Covers: register/login flows, dashboard,
   shop → ACQUIRE → balance, equip → slot, skill roulette (Phase 5 checks), full 1v1 PVE arena
   (Phase 3 SSE `board.updated` through the proxy), queue → `match.found` (Phase 4).
3. upsiloncli scenario suites (`run_all_scenarios.sh`, `run_all_edge_cases.sh`) with
   `UPSILON_BASE_URL=http://localhost:8085`. **Expected finding:** battle scenarios that wait on
   Reverb events fail — Laravel stopped broadcasting when the webhook moved to the hub (Phase 2).
   That failure is the empirical mandate for sub-phase D; non-realtime scenarios must pass now.
4. ISS-054 live drill: start a match, kill the engine container mid-match, restart, verify
   resurrection through the proxy (hub path, `serializer_version` forwarded).
5. Real-engine skill roll: `skills/generate` against the live engine (the Go fake only pins the contract).

### B — Hub self-sufficiency (pure Go, no stack needed) — ✅ complete (2026-07-07)
- ✅ **Static SPA serving:** `HUB_SPA_DIR` env → `gateway.Deps.SPADir`; NoRoute serves real
  files verbatim, falls back to `index.html` for client routes, keeps the enveloped 404 for
  `/api` misses (`internal/gateway/spa.go`, contract pinned in `spa_test.go` incl. traversal).
  Empty env keeps the hub JSON-only (side-by-side default).
- ✅ **Dockerfile** (`upsilonhub/Dockerfile`): umbrella-root context like the engine's
  (workspace import of `upsilonapi/stdmessage`; two-module `go work init` in the builder),
  distroless-static nonroot runtime, one image for serve/migrate/seed;
  `Dockerfile.dockerignore` trims the context. SPA `COPY` slot documented for after §C.
  Smoke-tested: image migrated + seeded a throwaway postgres:18 and served `/up` 200 +
  a successful seeded-testuser login.
- ✅ **Migrate modes:** `-migrate-mode full|baseline|river-only` (`-migrate` = full).
  `database.Baseline` stamps a Laravel-migrated DB at version 1 via `Force(1)` then applies
  anything newer; idempotent (testcontainers test simulates the prod handover). river-only
  runs River's migrator alone for side-by-side CI. `000002` (drop `ws_channel_key`) stays in E.
- ✅ **Seeding:** `internal/seed` ports the four Laravel seeders with upsert/updateOrCreate
  semantics and the deterministic catalog UUIDs; `-seed` = DatabaseSeeder equivalent
  (shop 8, skills 6, testuser+roster, admin/dummy/admin2 — admin block gated on
  `ADMIN_INITIAL_PASSWORD`, warn+skip like Laravel), `-seed-leaderboard` = the 200-player
  demo seeder. Feature test seeds twice and checks idempotence.

### C — SPA de-Inertia (in the new `upsilonbattleui` repo) — ✅ complete (2026-07-09)
- ✅ **Repo:** private `ecumeurs/upsilonbattleui` (created via `gh`), umbrella submodule with
  relative URL `../upsilonbattleui.git`. Standard Vite layout: `src/` (from
  `resources/js`), root `index.html` (replicates `app.blade.php` incl. fonts/body classes),
  `public/` assets, `docs/` atoms **copied** (battleui stays intact as rollback until E),
  `tests/playwright/` + config. Pushed to `origin/main`.
- ✅ **De-Inertia:** `createApp` + vue-router (`src/router.js` mirrors `web.php` + the
  `/__test/*` seams with `props: true`; catch-all → Welcome; `afterEach` sets `document.title`;
  `requiresAdmin` meta guard). All `@inertiajs`/Ziggy imports gone (grep-clean); dead Breeze
  layouts + `DropdownLink`/`NavLink`/`ResponsiveNavLink` deleted; `ApiDocs.vue`, `EventTest.vue`
  deleted (+ footer link).
- ✅ **Admin pages** moved onto the authed axios instance (were on cookie-only global axios —
  latent coupling): `UserManagement.vue` fully API-driven (`GET /admin/users` cursor paging,
  anonymize/destroy by `account_name`), `History.vue` likewise.
- ✅ **`ws_channel_key` fully vestigial-free** — channels keyed on `account_name` (user JSON
  exposes no `id`, customer-user-id privacy): `services/game.js`, `usePrivateChannel.js`,
  `EngagementHub.vue`, `BattleArenaSandbox.vue`.
- ✅ **Gate (hub-direct on `:8090`, `HUB_SPA_DIR=dist`, no proxy change):** build green;
  Playwright **61 passed / 1 skipped / 0 failed** (`--workers=1`; beats the A baseline 53/62 —
  the 8 sandbox visual baselines were re-captured for the new origin, LED specs fixed by the
  `account_name` re-key). Arena 403s during verification traced to a **pre-existing**
  matchmaking race, filed as **ISS-104** (queue-poison chain; parallel joins). CLI spot-run
  through `:8085`: e2e **32/37** = A-baseline pass set (fails: 2× ISS-102, ISS-103, 1
  friendly-fire flake, + `archetype_pve_full_fight` token starvation on a 103-min fight —
  filed **ISS-105**, hub-only 15m sliding TTL vs Sanctum's never-expire).

### D — upsiloncli transport + `/help` retirement
- ✅ **Done (2026-07-07):** Reverb/Pusher listener (`internal/ws/listener.go`) replaced with an
  SSE client against `GET /api/v1/events` — bearer-auth, Last-Event-ID replay cursor,
  backoff reconnect (token re-read per attempt; stream keyed on `user_id` so token renewal
  doesn't reconnect but adminSection account switches do). Connection = subscription:
  `IsSubscribed`/`Subscribe` kept as connectivity shims for the JS bridge; the `upsilon.*`
  scripting API and all scenario files unmodified. `REVERB_*` env requirement removed from
  `main.go`; wscat print helpers and the `gorilla/websocket` dependency dropped; README updated.
- ✅ **Done (2026-07-07):** `/help` retirement. The registry was already fully static
  (`RegisterAll` in `internal/endpoint/endpoints.go` — there never was a runtime `/help`
  bootstrap); removed the `HelpEndpoint` (`api_help`) entry, deleted `e2e_api_discovery.js`
  (asserted the retired `[[api_help_endpoint]]` contract — e2e suite is now 37 scenarios),
  repointed `samples/test_farm.js` at `stats_waiting`, and switched the REPL `status`
  connectivity ping from `GET /api/v1/help` to the envelope-free liveness route `GET /up`
  (Laravel serves it today through the proxy fallback; the hub serves it after E).
- Session keeps tolerating an absent `ws_channel_key` field.
- ✅ Full scenario suites re-run against `:8085` — battle scenarios pass over SSE (closed A.3).

**Sub-phases A, B, C, D all green (C closed 2026-07-09). Remaining: E only.**

### E — Cutover, decommission, ATD flip (strictly last)
- Compose: dev/CI/prod get `hub` + `proxy`; collapse `app`/`ws`/`db-init` into the one `hub`
  container; `tester` env `UPSILON_BASE_URL=http://proxy:8085`; drop Reverb. Caddy fallback
  flips from `app:8000` to the hub (which now serves the SPA); later the proxy itself can go.
- Prod DB ownership handover: run the baseline migrate step; drop Laravel's `migrations` table.
- Schema migration `000002`: drop `users.ws_channel_key` + its unique constraint; remove
  rotation (`RotateWsChannelKey`, `internal/gateway/auth.go:71`) and the field from resources.
- ATD (per doc 05 §4 + the 2026-07-07 feedback):
  - Pre-deletion checklist via `atd_check full:true` + mechanical grep — **not** `atd_map`/
    `atd_trace` (trace uses a stale index; map confirm output unusable — feedback §5/§8).
  - `.atd.workspace`: `battleui` entry → `upsilonbattleui` path. Rewrite the ~50 inbound
    `[[battleui:*]]` refs (all docs-only: upsilonapi/docs ×13, shared docs ×15, upsilonbattle/docs ×11 files)
    to the new project name — mechanical sed, then full `atd_check`.
  - Content rewrites: `mech_sanctum_token_renewal` (describe the Go sliding renewal, drop
    Sanctum/PHP class names) and the four `api_websocket*` atoms (describe SSE stream/replay/
    masking, drop Pusher/Reverb protocol) — doc 05 §2 Task 1.
- Tag battleui `archive/laravel-final`; remove the submodule from the umbrella; update
  `go.work`-adjacent tooling, CI workflow (re-enable Playwright steps, now against the hub),
  README/Setup/communication.md.
- Cutover report + kickoff ledger update.

## 3. Standing risks / notes
- Laravel remains the rollback path until E — nothing gets deleted while A–D are open.
- `atd_check` diff mode is broken (feedback §1); per-phase ATD gates keep using full-mode + grep.
- The stray `upsilonhub/docs/.atd_index.db` (ATD server artifact, feedback §7) must not be committed.
- Playwright visual snapshots were captured against `:8000`; same DOM through `:8085` should
  match, but SwiftShader variance is the usual suspect if not.
