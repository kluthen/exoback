# 00 — Migration Kickoff Brief

> **Start here.** This is the condensed, decision-final entry point for executing the
> battleui → Go migration. Full analysis: docs 01–06 in this folder. Platform context and
> decision ledger: [`../v3_platform_architecture.md`](../v3_platform_architecture.md) (§10).
> All decisions below were made by Bastien on 2026-07-04.

## What we are building

Replace the Laravel `battleui` service with **`upsilonhub`**, a single Go binary that is both
the battle game's backend and the seed of the v3.0 multi-game platform landing. Keep the Vue
SPA, keep PostgreSQL, collapse `app`/`ws`/`db-init` into one container, run side-by-side with
Laravel behind a proxy and cut over per endpoint group.

## Locked decisions

| Decision | Choice |
|---|---|
| HTTP framework | Gin |
| Realtime | **SSE** (`GET /events`, heartbeat, `Last-Event-ID` replay; per-recipient fog-of-war masking per connection) — doc 03 |
| DB access | **pgx + sqlc + golang-migrate**, no ORM |
| Auth | **Opaque DB tokens**, Sanctum-parity sliding renewal (15 min, renew at 10–15, `meta.token`) |
| Background work | **River** (Postgres job queue, transactional enqueue) + **injected world clock** from Phase 0 — never ad-hoc goroutines/tickers, never bare `time.Now()` |
| Package layout | `internal/platform/{identity,character,economy,inventory}` · `internal/games/battle/…` · `internal/gateway` · `internal/transport` · `internal/events` |
| Inertia | **None.** Serve the SPA statically; the 3 admin pages become facet-shaped API endpoints (future `/admin/v1`) |
| Envelope | `{request_id, message, success, data, meta}` preserved **byte-for-byte**; `X-Request-ID` ⇄ `traceparent` mapping (doc 04) |
| Observability | OTel-native from Phase 0: `otelgin`, `otelpgx`, `otelhttp`; one collector in compose |
| ATD | Project renamed **`upsilonhub`**; inbound `[[battleui:*]]` links fixed once at Phase 6 cutover; re-anchor spec-links per phase (doc 05) |
| Module name | `upsilonhub`, registered in `go.work` |

## Structural rules to honor while porting (from the platform architecture)

1. **Transport isolation:** domain packages never import `net/http`; all clients live in
   `internal/transport`; contracts are plain structs carrying `request_id`/`traceparent`.
2. **Games never import games**; game code may import platform interfaces only. (Only
   `games/battle` exists during migration — lay it out that way anyway.)
3. **Seams:** all `users` access behind `IdentityService`; all credit/market mutations behind
   `EconomyService` (ledger only, no ad-hoc increments); all character access behind
   `CharacterService`.
4. **Match creation ≠ queue processing:** "participants + teams + context → running arena" is
   its own operation that queue matchmaking calls; queue identity carries a scope parameter
   (future: per-city-arena queues).
5. **Webhook → in-process event bus → subscribers** (persist, credits, SSE fan-out) — the bus
   is hand-built and is the future MQ seam.
6. **Port shop/inventory thin** — parity only; v3.0 reshapes them into market/registry.
7. Economy math in `int64` base units; no floats in money paths.

## Pre-Phase-0 blocker — CLEARED 2026-07-04

**Repo restructure** (arch §14, settled): `ecumeurs/upsilonhub` created (private, module
`github.com/ecumeurs/upsilonhub`), added as submodule, wired into `go.work` and
`.atd.workspace`. All upsilon repos flipped private; umbrella renamed `upsilonumbrella`.
Vue SPA stays in battleui until Phase 3+ (deferred from §14's "initially"). Phase 0 can start.

## Progress ledger

| Phase | Status | Notes |
|---|---|---|
| 0 — Skeleton & contracts | **DONE 2026-07-04** (upsilonhub `39dd269`) | Gin + envelope byte-parity (respond pkg, unwrap middleware), enveloped 404/405/panic paths, tracing log format, OTel (otelgin/otelpgx, collector in umbrella compose), injected clock + insert-only River, schema imported verbatim from dev DB (29 migrations → `db/migrations/000001`), testcontainers harness, `ApiResponderTest`+`ErrorHandlingTest` ported and green, code health 0/0. Hub serves on `:8090` during side-by-side; `-migrate` flag applies schema + River. |
| 1 — Auth + identity | **DONE 2026-07-04** | All `auth/*` endpoints (login, admin login, register+roster, logout, update, password, export, delete) behind `IdentityService`/`CharacterService` seams; Sanctum-wire-compatible opaque tokens (`{id}\|{40 chars+crc32b}`, sha256 stored, `tokenable_type` kept as the Laravel FQCN so tokens interop across both stacks); sliding renewal (10–15 min → `meta.token`, 20 s grace) via injected clock; Laravel-parity validation (422 `meta.errors`), bcrypt (Go `$2a$` ⇄ PHP `$2y$` verified both ways); sqlc introduced (`sqlc.yaml`, queries per domain package); `AuthTest`+`GdprTest`+`SanctumTokenRenewalTest` re-expressed in Go and green (11 tests, shared testcontainer + fake-clock time-warping; renewal suite drives `/auth/export` until matchmaking exists); cutover proxy added (`caddy` on `:8085`, `/api/v1/auth/*` → hub `:8090`, rest → Laravel). |
| 2 — Engine bridge + game proxy | **DONE 2026-07-05** | Typed engine client (`internal/transport/engineclient`, shares the engine's `stdmessage` envelope; engine rule rejections pass through with `meta.error_key`; `EngineConnectionException` 503 envelope byte-parity, `target_coords` kept raw-passthrough like PHP). `game/*` endpoints with `GameMatchPolicy`-parity authz + entity-ownership gate via `CharacterService.OwnedByPlayer`. `BoardStateResource` masking ported non-mutating (`battle.MaskBoardState`) so one snapshot masks per recipient — pinned by a unit suite. Webhook ingestion with `mech_game_state_versioning` gating (stale/duplicate), `game.ended` resolution (stats + PHP ratio string semantics), Laravel-parity validation. **In-process event bus** (`internal/events`, synchronous — the MQ seam) publishes `battle.BoardUpdated`; SSE fan-out subscribes here at Phase 3. **`EconomyService` seam introduced early** (kickoff rule 3): credit awards are ledger+wallet in one tx, `int64`. `BattleProxyTest` re-expressed (4 tests + a versioning-gate test) and green; full suite green. Proxy routes `/api/v1/game/*` + `/api/webhook/upsilon` → hub; `UPSILON_WEBHOOK_URL` repointed at the proxy front door (`env.example` — real `.env`s must follow). |
| 3 — Realtime (SSE) | **DONE 2026-07-05** | `GET /api/v1/events` (RequireAuth only — sliding renewal rides REST envelopes, never the stream): the bearer-authenticated stream *is* the user's private channel. **`ws_channel_key` decision (doc 03): retired from the transport**; login keeps rotating it for Laravel interop until Phase 6, column removal then. `internal/gateway/sse` broadcaster subscribes to the bus, masks per recipient (`battle.MaskBoardState`, participants only, exactly the PHP broadcast loop), frame = `id: {match}:{version}`, `event:` = engine event type passthrough, `data:` = the `BoardUpdated::broadcastWith` envelope (`message: "Board Updated"`, uuid7 request_id, `data.match_id` + masked state, empty meta). Heartbeat comment ~25s (`Deps.SSEHeartbeat` shortens it in tests); slow consumers dropped at a 32-frame buffer (reconnect + replay self-heals); broadcaster closed before `server.Shutdown` so streams drain. `Last-Event-ID` replay = current-snapshot-if-newer, participant-gated, named after `_atd_meta.last_event_type`. SPA: `laravel-echo`/`pusher-js`/`@laravel/echo-vue` **removed**; `services/sse.js` is a fetch-based SSE client behind an Echo-compatible facade — fetch, not native `EventSource`, because sliding renewal retires the old token ~20s after renewal, so a URL-frozen token dies mid-session; every reconnect re-reads localStorage and sends `Last-Event-ID`. Composables/components untouched (facade keeps `.private().listen/.subscribed/.error`, `.leave`, and the pusher-shaped `connector.pusher.connection` health object). Caddy routes `/api/v1/events` → hub with `flush_interval -1` (config validated). communication.md §2.8 rewritten + endpoint table + Postman entry added. 6 SSE feature tests over a real httptest server (masked fan-out to 2 recipients, envelope shape, non-participant silence, replay, replay authz, malformed-id degrade, 401) + full suite green; SPA `npm run build` green. |
| 4 — Matchmaking | **DONE 2026-07-05** | All `MatchMakingController` endpoints (`matchmaking/join\|status\|leave`, `match/stats/waiting\|active`) behind a `battle.Matchmaker` domain object; **match creation is its own operation** (`CreateMatch`: participants + teams + context → running arena) that queue processing calls, queue identity carries `QueueScope` (kickoff rule 4). PHP-parity AI generation (name patterns, archetypes ≤1 support/≤1 sneak, `total_wins` grading) and team split — including the PHP quirk that 2v2_PVE seats human #2 on team 2 beside both AIs (ported as-is). Engine start payload = `UpsilonPlayerResource` parity: new `CharacterService.BattleLoadouts` resolves equipment (armor→utility→weapon UNION over the 3 slot columns) + inventory skills + D11 item-derived skills. Engine client gains StartArena/ArenaExists/ResurrectArena/ActiveMatchStats. **ISS-054 resurrection is live, with two deliberate PHP divergences:** (1) `serializer_version` is forwarded from the cached blob — PHP never sent it, so the engine's schema guard (bridge_resurrect.go) refused *every* Laravel resurrection; (2) an engine envelope with `success=false` counts as a failed resurrection → match concluded (PHP fell through to "matched" pointing the player at an arena never rebuilt). `match.found` now rides the SSE stream (bus event `battle.MatchFound` with explicit recipients — user-targeted, no masking, **no `id:` line**, nothing to replay; SPA facade needed zero changes) — old caveat (e) resolved. Hub reads `UPSILON_WEBHOOK_URL` (default = proxy front door) as the callback for arenas it starts. Proxy routes `/api/v1/matchmaking/*` + `/api/v1/match/stats/*` → hub (Caddyfile validated; restart the `proxy` container). 14 PHP tests (Matchmaking/ExtraMatchmaking/PVEMatchmaking/MatchVerification) re-expressed + extras (409 conflicts, loadout payload, SSE `match.found`, 4-test resurrection suite); token-renewal suite now drives `/matchmaking/status` per its original note; full suite green. communication.md §2.3 + §2.8 updated. |
| 5 — Economy/loadout + admin | next | Shop, inventory, equipment, skills, leaderboard, admin CRUD — **port thin** (behavior parity over `EconomyService`/inventory seams; v3.0 reshapes shop→market, items→registry). Every credit/wallet/market mutation through `EconomyService` (seam already live since Phase 2). |

Open caveats: (a) ATD MCP server was restarted (workspace cache now post-restructure), but
`atd_check`/`atd_test_links` scoped to `upsilonhub` still do not attribute *prefixed*
cross-project links (`[[upsilonapi:api_battle_proxy]]` reports NO_IMPL) — the doc 05 §3
link-resolution concern stands. Phases 1–2 links validated mechanically instead: all 18 (Phase 1)
+ 17 (Phase 2) `[[project:atom]]` references resolve to existing atoms; note the auth/GDPR/character atoms
live in `upsilonapi`/`upsilonbattle`/`upsilontypes`/`shared`, *not* in `battleui/docs` — battleui's
own corpus is frontend-only). Two PHP spec-links were dangling and are re-anchored/dropped in Go:
`uc_player_registration_generate_characters` → `[[shared:uc_player_registration]]`,
`entity_character_allocate_hp` → dropped (no such atom anywhere). (b) Playwright/upsiloncli gates
still pending: they need the full dev stack up and clients pointed at the `:8085` proxy front door
(only the DB container was running when Phase 1 landed); the backlog now includes the Phase 3 SSE
E2E check (arena receives `board.updated` through the proxy) and the Phase 4 checks (queue → match
→ `match.found` on the stream through the proxy; a real ISS-054 kill-the-engine-mid-match
resurrection); restart the `proxy` container to pick up the Caddyfile changes. (c) Local umbrella dir is still
`upsilon-hub` though the GitHub repo is `upsilonumbrella`. (d) `mech_sanctum_token_renewal` atom
*content* still describes Sanctum specifics; mechanism behavior is identical in Go — revise the
text at Phase 6 per doc 05 §4; same now for the `api_websocket*` atoms, which still describe the
Pusher/Reverb protocol while Phase 3 code links to them for their transport-agnostic semantics
(channels → stream, events, masking) — content rewrite at Phase 6 per doc 05 §4. (e) **Resolved at Phase 4** — the hub emits
`match.found` on the SSE stream; the dashboard polling stays as belt-and-braces but match entry is
push again. (f) `code_health_check.py` reports 70 errors on upsilonhub — the 56 pre-existing plus
14 new ones that are all "missing doc comment" on **sqlc-generated** functions in the `*pg`
packages (the same accepted category; hand-annotating generated code would be wiped by the next
`sqlc generate`). The hand-written Phase 4 diff adds zero errors — new files were split to respect
the ≤10-links / ≤400-LOC budgets (`battle/enginepayload.go`, `battle/matchmaking_status.go`, the
three matchmaking test files).

### Session handover (updated 2026-07-05, post-Phase 4 — read before starting Phase 5)

**Porting conventions established in Phases 0–2** (follow these; they are load-bearing, not style):

- **Parity is byte-level, PHP quirks included.** Ported handlers reproduce Laravel wording and
  serialization exactly: `findOrFail` 404 keeps the PHP FQCN (`No query results for model
  [App\Models\GameMatch] {id}`), policy failures answer `This action is unauthorized.`,
  `EngineConnectionException` renders `data: []` (array, not `{}`) and a request_id that is
  **null** when no `X-Request-ID` header exists. Where PHP 500s on garbage (non-uuid path/entity
  ids → QueryException), Go `must(err)`-panics into the recovery 500 on purpose. Envelope key
  order is pinned with typed structs; the one order we can't keep is *inside* dynamic maps
  (`game_state` content) — accepted, JSON object order is not semantic.
- **Validation is hand-rolled** (`internal/gateway/validation.go` + per-handler `validateX`
  funcs) with Laravel's exact message wording ("The data.match id field is required."). No
  binding/validator library on parity surfaces.
- **Tests:** `authEnv` in `internal/gateway/authenv_test.go` is the shared feature-test harness
  (shared migrated testcontainer, `TRUNCATE` per test = RefreshDatabase, `clock.Fake` = 
  `Carbon::setTestNow`, `fakeEngine` = the Mockery engine mock). Extend it, don't fork it.
  Feature tests hit real Postgres; only the engine is doubled.
- **sqlc:** one queries.sql + generated `<domain>pg` package per domain, registered in
  `sqlc.yaml`; binary at `~/go/bin/sqlc`. Nullable uuid columns generate `pgtype.UUID` (the
  override only covers NOT NULL) — check generated types after `sqlc generate`.
- **Cross-module imports** (e.g. hub → `upsilonapi/stdmessage`) rely on `go.work` resolution
  with **no `require` in go.mod** — sibling convention; don't run `go mod tidy` blindly.
- **ATD:** links use workspace prefixes (`[[upsilonapi:...]]`, `[[upsilonbattle:...]]`,
  `[[shared:...]]` = umbrella `./docs`); tags go atop the exact function/type, test files carry
  `@test-link` only (ATD.md §6). Validate mechanically (grep links → check
  `<project>/docs/<atom>.atom.md` exists) until the MCP cross-project attribution works.

**Phase 3 (SSE) conventions now load-bearing:**

- The SSE surface lives in `internal/gateway/sse` (broadcaster, per-user registry, frame
  building) + `internal/gateway/events.go` (the gin handler, replay). The broadcaster is
  constructed in `main`/`authEnv` beside the bus and **must be `Close()`d before
  `server.Shutdown`** (streams never end on their own).
- New realtime events for later phases (e.g. `match.found` at Phase 4): publish a typed event
  on the bus and give the broadcaster a frame for it — the SSE event name is the client
  contract (`EngagementHub` listens for `match.found`); user-targeted (not match-targeted)
  frames will need a recipient rule other than `Teams`.
- The SPA facade (`battleui/resources/js/services/sse.js`) dispatches by SSE event name to
  every registered channel's listeners; channel *names* are lifecycle-only. Adding events
  client-side = `.listen('.new.event', cb)` — no transport work.
- `Deps.SSEHeartbeat` (100ms in `authEnv`) is how stream tests bound "nothing arrives":
  `expectSilence(t, beats)` reads until N heartbeats pass.

**Phase 4 (matchmaking) conventions now load-bearing:**

- `battle.Matchmaker` (`internal/games/battle/matchmaking.go` + `matchmaking_status.go`) is the
  domain object for queue processing; gateway handlers validate/translate only and map its
  sentinel errors (`ErrAlreadyQueued`/`ErrInActiveMatch` → the PHP 409 wordings). `CreateMatch`
  is the rule-4 operation — extend `QueueScope`, not the operation, for new queue identities.
- Engine payload contracts live in `battle/enginepayload.go` (plain structs mirroring
  upsilonapi's `api.Player` family; property blocks stay `json.RawMessage` — the hub forwards,
  the engine interprets). `CharacterService.BattleLoadouts` is the only reader of the
  equipment/skill tables; Phase 5's inventory work should grow that seam, not bypass it.
- `fakeEngine` now carries **per-method** canned results (`startResult`, `existsResult`,
  `resurrectResult`, `statsResult` + call recorders); set only what the test needs.
- User-targeted SSE frames (vs match-targeted): publish a bus event with explicit `Recipients`
  and give the broadcaster a frame builder — `MatchFoundFrame` is the template. Transient
  frames set no `Frame.ID` (the `id:` line is omitted; the client's replay cursor keeps
  pointing at board state).
- Health-check budgets are real gates: ≤10 ATD links and ≤400 effective LOC per file — split
  files along domain seams before trimming links. sqlc-generated `*pg` files are accepted debt
  (caveat f).
- ISS-054 divergences from PHP are deliberate and pinned by tests (serializer_version
  forwarded; engine refusal = failure → conclude). Don't "fix" them back to PHP behavior.

**Phase 5 (economy/loadout + admin) entry points:**

- Laravel side to port: `ShopController`, `EquipmentService`, `SkillService`,
  `ProfileController` (profile/credits/characters + reroll/upgrade/rename/delete),
  `LeaderboardController`, and the admin CRUD pages (locked decision: facet-shaped API
  endpoints, future `/admin/v1` — no Inertia).
- **Port thin** (kickoff rule 6): behavior parity over the seams, no polish — v3.0 reshapes
  shop→market vendor, items→shared registry.
- Every credit/wallet/market mutation through `EconomyService` (live since Phase 2, ledger+
  wallet in one tx, `int64`); equipment↔inventory coupling becomes the first cross-service
  calls (doc 02 Phase 5 note).
- PHP suites to re-express: `SkillTest`, `CharacterTest`/`CharacterUpgradeTest`,
  `LeaderboardTest`, `AdminSelfProtectionTest` (+ shop/inventory coverage inside them).

**Operational notes:**

- Real `.env`s must adopt `UPSILON_WEBHOOK_URL=http://proxy:8085/api/webhook/upsilon`
  (env.example updated at Phase 2); with the old value the engine calls Laravel's webhook and
  the hub never sees events.
- The hub binary is run by hand inside the `app` devcontainer (`upsilonhub/bin/upsilonhub`,
  `:8090`); config: `UPSILON_API_URL` (default `http://engine:8081`) and, since Phase 4,
  `UPSILON_WEBHOOK_URL` (default `http://proxy:8085/api/webhook/upsilon`) — the callback the
  hub hands the engine for arenas it starts/resurrects.
- Gates 2–3 (Playwright, upsiloncli at `:8085`) have not run for Phases 1–2 — first session
  with the full stack up should clear that backlog before building on top.

### Compose review vs the side-by-side architecture (2026-07-04, post-Phase 1)

- **`docker-compose.yaml` (dev): aligned.** otel-collector + cutover `proxy` (caddy, `:8085`
  front door, `/api/v1/auth/*` → hub `:8090`, rest → Laravel `:8000`); `:8090` exposed. The hub
  binary runs inside the `app` devcontainer by hand, same as Laravel/vite/engine do.
- **`docker-compose.ci.yaml`: still pre-migration** (db/db-init/app/ws/engine/tester). To match:
  add a `hub` service + the proxy, and point `tester` at the proxy (`UPSILON_BASE_URL=http://proxy:8085`)
  so gate 3 (upsiloncli unmodified) actually exercises the cutover. **Two blockers first:**
  (1) `upsilonhub` has no Dockerfile yet; (2) `hub -migrate` cannot run against a
  Laravel-migrated DB — golang-migrate would apply the imported schema over existing tables.
  Side-by-side CI needs Laravel to keep owning the schema and the hub to apply **River's schema
  only** (add a river-only migrate mode) until Phase 6 flips ownership.
- **`docker-compose.prod.yaml`: still pre-migration.** Same gaps as CI; wiring hub+proxy into
  prod is a rollout decision — needed at the latest by Phase 3 (SSE replaces the `ws` container).
  At Phase 6, `app`/`ws`/`db-init` collapse into the single `hub` container per the brief.

## Phase sequence & acceptance gates

Phases 0–6 per doc 02 §5 (skeleton → auth → engine bridge/game proxy → SSE → matchmaking →
economy/admin → cutover). Identity extraction happens later, *inside* v3.0 (V3-1a), not here.

Per phase, all four gates must be green:
1. The corresponding PHP feature tests re-expressed in Go (74 total — the executable spec, doc 01 §7).
2. Playwright E2E (transport-agnostic, drives the real frontend).
3. **upsiloncli scripting unmodified** — it must stay green across the cutover.
4. `atd_test_links` + `atd_check` for the phase's re-anchored atoms (doc 05 §4 — capture the
   atom checklist with `atd_map`/`atd_trace` *before* deleting any PHP).

## Riskiest parts (watch these)

- Fog-of-war masking parity (`BoardStateResource`, per-recipient payloads) — Phase 2/3.
- Matchmaking breadth + **arena resurrection (ISS-054)** — Phase 4.
- SSE reconnect/replay mid-match; proxy buffering; heartbeat — Phase 3.
- Sliding-renewal exactness (`SanctumTokenRenewalTest`) — Phase 1.
- Also Phase 3: decide whether `ws_channel_key` rotation survives SSE (doc 03 note).
