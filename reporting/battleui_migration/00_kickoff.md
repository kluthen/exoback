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
