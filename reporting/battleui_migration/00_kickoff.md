# 00 — Migration Kickoff Brief

> **Start here.** This is the condensed, decision-final entry point for executing the
> battleui → Go migration. Full analysis: docs 01–06 in this folder. Platform context and
> decision ledger: [`../v3_platform/v3_platform_architecture.md`](../v3_platform/v3_platform_architecture.md) (§10).
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
| 5 — Economy/loadout + admin | **DONE 2026-07-06** | All remaining player + admin endpoints ported thin. **Profile/characters:** `profile\|credits\|characters\|character/{id}` + reroll/upgrade/rename/delete over `CharacterService` (+`IdentityService.IncrementRerollCount` — users-table writes stay behind the seam); CP-cap/negative-check wording byte-parity; policy denials verbatim (`You do not own this character.`, `Reroll limit reached.`). **Shop/inventory:** `EconomyService` grew the market/inventory surface (catalog, `Purchase` = wallet-lock → guards → debit → upsert → both audit ledgers in one tx, `int64`; `PurchaseError` carries the PHP message/status/reason). **Equipment:** 3-slot ops live in `CharacterService` (gameplay tables); the inventory ownership check is an explicit `EconomyService.GetInventoryItem` call — the designed Phase 8 hub→economy seam (doc 02 §5 wrinkle). Cross-character mutual exclusivity in one tx. **Skills:** templates browse + per-character inventory (roll/equip/unequip, slot cap under row locks); `battle.Content` is the skill-template registry (admin CRUD); engine roll via `Engine.GenerateSkill` — the one **raw-body** engine call (no envelope), 5 s timeout, non-2xx = `ErrGeneratorUnavailable` (PHP bridge parity: unavailable/unreachable/invalid-response 503s). **Leaderboard:** hand-built envelope preserved (no top-level `meta` — renewal never patches it, like PHP), Sunday-00:01-UTC cycle, wins→score→id-desc ranking, PHP division semantics (int when even). **Admin:** users/anonymize/destroy (self-protection ISS-093, last-admin guard incl. the trashed-target case), history/purge (ISS-051/053 cursor pages), shop-items + skill-templates CRUD as facet-shaped endpoints behind `middleware.RequireAdmin` (no Inertia — locked). Admin anonymize deliberately does **not** revoke tokens (PHP parity; soft-deleted owner locks them out anyway). PHP tests re-expressed: CharacterTest, CharacterUpgradeTest, SkillTest (all 15), LeaderboardTest, AdminSelfProtectionTest + shop/inventory/equipment/CRUD extras (~50 new tests); full suite green. Proxy routes `/api/v1/{profile,profile/*,shop/*,skills/*,leaderboard,admin/*}` → hub (Caddyfile validated). Dangling PHP spec-links re-anchored per doc 05: `api_skill_generate_engine`→`[[upsilonapi:api_skill_generation]]`, `mech_character_reroll_{limit,effect}`→`[[upsilonbattle:mech_character_reroll]]`, `rule_admin_content_authority` dropped (no such atom). `/api/v1/help` stays on Laravel (CodeDiscoveryService introspects PHP source — Phase 6 decides its fate). |
| 6 — Cutover & decommission | **DONE 2026-07-09** (A/B/D 2026-07-07, C/E 2026-07-09 — full detail: doc 07 + cutover report doc 08) | **C (standalone SPA): done.** Private repo `ecumeurs/upsilonbattleui` (Vite+Vue+vue-router, `src/` layout), full de-Inertia (zero `@inertiajs`/Ziggy refs), admin pages on the authed axios instance, channels keyed on `account_name` (no `ws_channel_key`, no user id — privacy). C gate hub-direct `:8090`: Playwright 61/62 (1 skipped, 0 failed); CLI spot-run 32/37 = A baseline. Filed ISS-104 (matchmaking parallel-join queue poison, High) + ISS-105 (CLI token starvation on 100-min fights, Low). **E (cutover): done.** Migration `000002` drops `users.ws_channel_key` (+field surface); Caddyfile collapsed to hub-only (`HUB_UPSTREAM`); hub image bakes the SPA (node stage → `/srv/spa`); CI/prod compose = hub-migrate→hub-seed→hub←proxy (prod `-migrate-mode baseline`, port `8000:8085`); CI workflow: hub in Go lists, php-tests deleted, Playwright re-enabled from upsilonbattleui; ATD workspace flip + `[[upsilonbattleui:*]]` re-link + SSE/Go atom rewrites (`atd_check full` clean); scripts + README/Setup/communication de-Laravel'd. **Dev-DB handover executed live** (baseline → ledger v2, `DROP TABLE migrations`, Laravel/Reverb stopped — runbook proven; prod remains runbook-only in doc 08 §4; note: migrator needs `sslmode=disable`). Final gate results: doc 08 §5. **A (E2E gates through `:8085`): done.** Playwright 53/62 (failures = stale visual baselines + one pre-existing arena race, reproduced against Laravel-direct); upsiloncli e2e 33/38 + edge 53/55, every remaining failure attributed and filed (ISS-102 forfeit-in-startup-window exposed by SSE latency, ISS-103 privacy scenario asserts never-implemented masking, gameplay-randomness flakes). Gates caught and fixed two hub parity bugs: `filterValidateInt` (Laravel `integer` accepts numeric strings) and **APP_DEBUG exception-prefix parity** (`respond.ExceptionError`; **dev/CI must run the hub with `APP_DEBUG=true`**). A4 resurrection drill green **after an engine fix** — upsilonapi's `HandleArenaResurrect` bound the bare struct instead of the Standard Envelope, so live ISS-054 resurrection had never worked from either stack (envelope binding fixed, deployed, drill verified through the proxy). A5 live `skills/generate` verified. **B (hub self-sufficiency): done.** `-migrate-mode full\|baseline\|river-only` (`database.Baseline` stamps a Laravel-migrated DB at 000001), `internal/seed` ports the four Laravel seeders (`-seed`, `-seed-leaderboard`; deterministic catalog UUIDs, upsert semantics, admin block gated on `ADMIN_INITIAL_PASSWORD`), static SPA serving behind `HUB_SPA_DIR` (index.html fallback, enveloped `/api` 404 kept), `upsilonhub/Dockerfile` (umbrella-root context like the engine's, distroless nonroot, one image serve/migrate/seed — smoke-tested migrate+seed+login on a throwaway DB). **D (upsiloncli transport + `/help` retirement): done.** `internal/ws/listener.go` rewritten as an SSE client on `GET /api/v1/events` (bearer auth, Last-Event-ID replay, backoff; `REVERB_*` env + gorilla/websocket dropped; scripting API untouched); `/help` retired — `HelpEndpoint` removed (registry was already static), `e2e_api_discovery.js` deleted (suite now 37), REPL `status` pings `GET /up`. Caveat (b) cleared. Nothing committed yet in any repo. |

Open caveats: (a) ATD MCP server was restarted (workspace cache now post-restructure), but
`atd_check`/`atd_test_links` scoped to `upsilonhub` still do not attribute *prefixed*
cross-project links (`[[upsilonapi:api_battle_proxy]]` reports NO_IMPL) — the doc 05 §3
link-resolution concern stands. Phases 1–2 links validated mechanically instead: all 18 (Phase 1)
+ 17 (Phase 2) `[[project:atom]]` references resolve to existing atoms; note the auth/GDPR/character atoms
live in `upsilonapi`/`upsilonbattle`/`upsilontypes`/`shared`, *not* in `battleui/docs` — battleui's
own corpus is frontend-only). Two PHP spec-links were dangling and are re-anchored/dropped in Go:
`uc_player_registration_generate_characters` → `[[shared:uc_player_registration]]`,
`entity_character_allocate_hp` → dropped (no such atom anywhere). (b) **Resolved at Phase 6 sub-phase A (2026-07-07)** — full stack behind `:8085`, Playwright +
both upsiloncli suites run, all backlogged checks covered (SSE `board.updated`, queue →
`match.found`, live ISS-054 resurrection drill, shop → equip → loadout, real `skills/generate`);
remaining reds attributed to pre-existing issues (ISS-102/ISS-103) or gameplay-randomness flakes,
none cutover-caused — details in the Phase 6 ledger row and doc 07 §A. (c) Local umbrella dir is still
`upsilon-hub` though the GitHub repo is `upsilonumbrella`. (d) `mech_sanctum_token_renewal` atom
*content* still describes Sanctum specifics; mechanism behavior is identical in Go — revise the
text at Phase 6 per doc 05 §4; same now for the `api_websocket*` atoms, which still describe the
Pusher/Reverb protocol while Phase 3 code links to them for their transport-agnostic semantics
(channels → stream, events, masking) — content rewrite at Phase 6 per doc 05 §4. (e) **Resolved at Phase 4** — the hub emits
`match.found` on the SSE stream; the dashboard polling stays as belt-and-braces but match entry is
push again. (f) `code_health_check.py` reports 110 errors on upsilonhub after Phase 5 — 10 hand-written
"too few ATD links" files pre-dating Phase 5 (main.go, config, database, clock, bus, jobs,
password, testutil, embed, authenv_test) plus ~100 that are all missing-doc/no-links on
**sqlc-generated** functions in the `*pg` packages (the same accepted category; hand-annotating
generated code would be wiped by the next `sqlc generate` — Phase 5 added many queries, so the
count grew). The hand-written Phase 5 diff adds zero errors — mounts moved into their handler
files and `engineclient/client_skills.go` split off to respect the ≤10-links budget.

### Session handover (updated 2026-07-09 — **Phase 6 complete, migration done**; cutover report: doc 08. The conventions below remain load-bearing for future hub work.)

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

**Phase 5 (economy/loadout + admin) conventions now load-bearing:**

- **Seam growth, not new seams:** profile character ops + equipment + character skills all
  live in `CharacterService` (`pg_profile.go`/`pg_equipment.go`/`pg_skills.go` on the same
  PG); shop/inventory/purchase in `EconomyService` (`pg_shop.go`/`pg_inventory.go`);
  skill templates in `battle.Content` (implemented by the same `battle.PG`, wired as
  `Deps.Content`). Users-table writes (reroll counter, admin destructive actions) stay in
  `IdentityService` (`pg_admin.go`).
- **The equip ownership check is the Phase 8 seam:** gateway → `EconomyService.GetInventoryItem`
  (owner + catalog slot) → `CharacterService.Equip`. Never join `player_inventory` from
  character queries for authz — that call is the future network hop.
- `Engine.GenerateSkill` is the one raw-body engine call (no stdmessage envelope) — it lives in
  `engineclient/client_skills.go`; non-2xx → `battle.ErrGeneratorUnavailable`, transport →
  `ErrEngineUnreachable`; the gateway maps the three PHP 503 messages off those.
- **Mount functions live beside their handlers** (mountProfile in profile.go etc.), not in
  router.go — that is how the ≤10-links budget holds; follow it for new endpoint groups.
- Laravel time formats in responses: Eloquent datetime casts → `microTime` ("…​.000000Z",
  resources_items.go); `toIso8601String` → `isoTime` ("+00:00", game.go); `toDateString` →
  `formatDate`. Cursor pagination emits `microTime` (Carbon `toISOString`).
- The leaderboard writes its envelope by hand (no top-level `meta`, header-only request id) —
  don't "fix" it onto `respond`; PHP renewal never patched meta-less responses either.
- ATD reality check: most Phase 5 API/rule atoms live in **upsilonapi/docs** (not
  upsilonbattle); entities partly in **upsilontypes**; `rule_progression`/`rule_stat_taxonomy`
  in umbrella `./docs`. Validate with the mechanical grep before assuming a prefix.

**Phase 6 (cutover & decommission) — COMPLETE 2026-07-09 (detail: doc 07 + cutover report doc 08):**

- Conventions added this phase, load-bearing:
  - **The hub must run `APP_DEBUG=true` in dev/CI test stacks** — the CLI's loose message
    matching (`jsAssertResponse`) only engages on the `-- DEBUG MODE -- ` prefix; the hub
    port is `respond.ExceptionError`/`ExceptionErrorMeta` and is for *exception-derived*
    errors only (findOrFail 404s, policy 403s, 401, 422, admin abort); direct-ApiResponder
    errors stay unprefixed. `respond.SetDebug` rides the request context from router.go.
  - Engine arena endpoints all bind the Standard Envelope now — `HandleArenaResurrect` was
    the outlier (bare struct) and was fixed engine-side; don't reintroduce bare bindings.
  - upsiloncli realtime is the hub SSE stream (`internal/ws/listener.go`): connection =
    private channel, identity-keyed reconnect (session `user_id`), token re-read per attempt;
    `IsSubscribed`/`Subscribe` are connectivity shims. `REVERB_*` env is gone.
  - Hub ops surface: `-migrate-mode full|baseline|river-only`, `-seed`/`-seed-leaderboard`,
    `HUB_SPA_DIR` for static SPA serving; one distroless image for all modes
    (`upsilonhub/Dockerfile`, umbrella-root build context).
- C and E landed 2026-07-09 (ledger row above); the dev stack runs hub-only behind `:8085`
  and the dev DB completed the baseline handover (`schema_migrations` v2, Laravel `migrations`
  table dropped). Known-red scenario families (not gates): ISS-102, ISS-103, ISS-105,
  ISS-106 (PHP-era `[]` skill payload), friendly-fire flakes.
- **E5 decommission done 2026-07-09 (user-confirmed):** battleui tagged `archive/laravel-final`
  (`d57e345`, pushed), GitHub repo `ecumeurs/battleui` archived, submodule removed from the
  umbrella (`.gitmodules` stanza + `.git/modules/battleui` gone). Laravel rollback = checkout
  the tag + un-archive; the stack is retired, not deleted.

**Operational notes:**

- Real `.env`s must adopt `UPSILON_WEBHOOK_URL=http://proxy:8085/api/webhook/upsilon`
  (env.example updated at Phase 2); with the old value the engine calls a webhook nobody
  serves anymore and the hub never sees events.
- Dev stack: `scripts/start_services.sh` boots engine + hub (`APP_DEBUG=true`,
  `HUB_SPA_DIR=/workspace/upsilonbattleui/dist`) + Vite; front door `:8085`.
- The golang-migrate path (lib/pq) needs `sslmode=disable` on `DATABASE_URL` against
  SSL-less Postgres — compose files and env.example carry it; the serve path (pgx) doesn't care.

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
