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
| 2 — Engine bridge + game proxy | next | Typed `upsilonapi` client sharing `upsilontypes`; `game/*`; webhook ingestion; `BoardStateResource` masking. Green `BattleProxyTest`. |

Open caveats: (a) ATD MCP server still runs a pre-restructure workspace cache — restart it, then
rerun `atd_check`/`atd_test_links` for `upsilonhub` (Phase 1 links were validated mechanically:
all 18 `[[project:atom]]` references resolve to existing atoms; note the auth/GDPR/character atoms
live in `upsilonapi`/`upsilonbattle`/`upsilontypes`/`shared`, *not* in `battleui/docs` — battleui's
own corpus is frontend-only). Two PHP spec-links were dangling and are re-anchored/dropped in Go:
`uc_player_registration_generate_characters` → `[[shared:uc_player_registration]]`,
`entity_character_allocate_hp` → dropped (no such atom anywhere). (b) Playwright/upsiloncli gates
still pending: they need the full dev stack up and clients pointed at the `:8085` proxy front door
(only the DB container was running when Phase 1 landed). (c) Local umbrella dir is still
`upsilon-hub` though the GitHub repo is `upsilonumbrella`. (d) `mech_sanctum_token_renewal` atom
*content* still describes Sanctum specifics; mechanism behavior is identical in Go — revise the
text at Phase 6 per doc 05 §4.

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
