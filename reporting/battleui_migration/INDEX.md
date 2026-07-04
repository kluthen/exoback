# BattleUI → Go/Gin Migration Study

> Exploration commissioned 2026-06-19. Goal: replace the Laravel/PHP **battleui** service
> with a Go service (Gin), keep PostgreSQL, collapse the multi-container WebSocket
> topology into a single binary, and introduce first-class OpenTelemetry observability.
>
> **Scope of this document set:** analysis + strategy only. No code is migrated here.
> OpenTelemetry *integration design* is in scope; its *exploitation* (dashboards,
> alerting, backends) is explicitly deferred.

## The one-paragraph summary

`battleui` is a Laravel 12 app that is **80% an HTTP/WebSocket gateway** in front of the
Go battle engine (`upsilonapi`) and **20% a meta-game database service** (accounts,
characters, matchmaking, shop, inventory, skills, leaderboard). It serves a Vue 3 SPA.
The single biggest operational cost is **Laravel Reverb**: because PHP-FPM cannot hold
long-lived sockets, production runs the same image as *two* containers (`app` + `ws`)
plus a queue concern, and the WebSocket layer speaks the Pusher protocol. Re-implementing
this gateway in Go collapses HTTP + WebSocket + background work into **one stateful binary**,
removes the Pusher/Reverb dependency, and is a natural place to standardise tracing across
the whole stack. The risk is concentrated in two places: the **Vue frontend's coupling to
Inertia + laravel-echo/Pusher**, and the **breadth of meta-game business logic** (not its
depth). The database is portable as-is.

## Reading order

| # | Document | What it answers |
|---|----------|-----------------|
| 0 | [00_kickoff.md](00_kickoff.md) | **Start here to execute**: locked decisions (2026-07-04), structural rules, gates, pre-Phase-0 blocker. |
| 1 | [01_current_state.md](01_current_state.md) | What exists today: every endpoint, event, model, migration, test, and the WS topology. The complete feature inventory. |
| 2 | [02_migration_strategy.md](02_migration_strategy.md) | Target Go/Gin architecture, library choices, layer-by-layer mapping, phasing, effort, and risks — including the **Identity** and **Economy** service extractions and the post-extraction data-ownership boundary. |
| 3 | [03_websocket_strategy.md](03_websocket_strategy.md) | The core motivation. Reverb/Pusher today, the three options for Go, and the frontend impact. |
| 4 | [04_observability.md](04_observability.md) | OpenTelemetry integration design (traces/metrics/logs) for the new service and how it threads into the existing stack. |
| 5 | [05_atd_rewiring.md](05_atd_rewiring.md) | Carrying the 200 `@spec-link [[atom]]` traceability annotations and ATD project registration across the rewrite. |
| 6 | [06_v3_platform_constraints.md](06_v3_platform_constraints.md) | Forward-looking v3.0 constraints (multi-game platform with a shared world, HTTP→MQ transition, further service extractions) and how they shape — but do not expand — the migration. |

## Headline numbers (measured)

| Area | Size | Migration character |
|------|------|---------------------|
| App PHP (controllers/models/services/etc.) | ~6,065 LOC | Rewrite — business logic + gateway |
| DB migrations | 28 files, ~1,197 LOC | **Port near-verbatim** (schema is portable) |
| PHP feature/unit tests | 18 files, **74 test methods**, ~2,461 LOC | Re-express as Go table tests (the executable spec) |
| Vue + JS frontend | 81 `.vue` + composables/services, ~13,277 LOC | **Keep**, but rewire its server/transport coupling |
| ATD spec-links in PHP | **200 occurrences across 60 files** | Re-anchor into Go source |
| REST endpoints (`/api/v1`) | ~45 routes | 1:1 handler port |
| Broadcast events | 3 (`BoardUpdated`, `MatchFound`, `BattleUpdated`) | Re-implement over new WS hub |
| Production containers for battleui | **3** (`app`, `ws`, `db-init`) | Collapse to **1** |

## Key findings up front

1. **The Inertia coupling is shallow.** Only **9** `Inertia::render` calls exist, and all but
   3 (admin pages) render a bare page shell with no server props. The SPA fetches real data
   from `/api/v1` via axios with a Bearer token. This makes "keep the Vue app, replace the
   backend" viable without a full Inertia adapter — see doc 03.
2. **WebSocket is the whole point.** The multi-instance topology exists *solely* because
   Reverb must be a separate process. Go erases that constraint. This is the strongest
   technical justification for the migration.
3. **The DB is the stable core.** PostgreSQL stays. The schema (UUID PKs, JSONB state cache,
   soft deletes, credit ledger) ports cleanly; this is the lowest-risk layer.
4. **The "engine bridge" is thin and well-isolated.** `UpsilonApiService` is a single
   ~190-line HTTP client wrapping the standard envelope. In Go it becomes a typed client —
   and shares types directly with `upsilontypes`, which PHP could never do.
5. **Observability is greenfield.** There is effectively no tracing today. Building the new
   service OTel-native (and propagating `X-Request-ID`/trace context into `upsilonapi`)
   closes the project-wide gap the user flagged.
