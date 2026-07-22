# 02 — Migration Strategy: Go / Gin

## 1. Target architecture

A **single Go binary** (proposed module `upsilonhub` or `battlehub`, registered in `go.work`)
that hosts, in one process:

```
                     ┌─────────────────────────────────────────────┐
   Vue SPA  ──HTTP──▶│  Gin router  /api/v1/*   (REST handlers)     │
            ──WS────▶│  WS hub      /ws         (realtime fan-out)  │──┐
                     │  /webhook/upsilon        (engine callback)   │  │ in-process
                     │  background workers (matchmaker tick, etc.)  │◀─┘ channels
                     └───────────────┬─────────────────────────────┘
                                     │ pgx                  │ typed HTTP client
                                     ▼                      ▼
                              PostgreSQL              upsilonapi (Go engine)
```

The webhook handler writes state + pushes to the in-process WS hub directly — **no broker,
no second container, no Pusher**. This is the structural win.

### Recommended libraries (no hard requirement from user; these are conventional, well-supported choices)

| Concern | Choice | Rationale |
|---|---|---|
| HTTP router | **Gin** | Per user. Mature, fast, huge middleware ecosystem. |
| DB access | **pgx/v5** + **sqlc** (or GORM) | `sqlc` gives type-safe queries from SQL, matching the "strict typing" ethos; GORM if you prefer ActiveRecord familiarity. pgx is the Postgres driver either way. |
| Migrations | **golang-migrate** or **goose** | Port the 28 Laravel migrations to plain SQL up/down. |
| Realtime | **RESOLVED: SSE** — stdlib `net/http` + flusher, no WS library needed | Doc 03, resolved 2026-07-04. |
| Auth tokens | **lestrrat-go/jwx** (JWT) *or* opaque tokens in DB | Replaces Sanctum; see §4. |
| Validation | **go-playground/validator** | Struct-tag validation ≈ FormRequests. |
| Config | **viper** or stdlib + `envconfig` | Read existing `.env` keys. |
| Observability | **OpenTelemetry Go SDK** (`otelgin`, `otelpgx`, `otelhttp`) | Doc 04. |
| Tests | stdlib `testing` + **testify** + **testcontainers-go** | Postgres-backed feature tests mirroring the 74 PHP tests. |

> **RESOLVED (2026-07-04): pgx + sqlc + golang-migrate** — no ORM. Keeps SQL explicit (good
> for the JSONB-heavy `game_state_cache`) and avoids ORM surprises around the
> optimistic-version logic.

### Package layout & the communication seam (v3.0 constraint — see doc 06)

Structure the binary as **domain packages behind interfaces** — per the platform architecture
(`reporting/v3_platform/v3_platform_architecture.md` §9, which supersedes this section on layout naming):
`internal/platform/{identity,character,economy,inventory,…}` + `internal/games/battle/…` +
`internal/gateway` + `internal/events` — with **all transport implementations in a dedicated
layer** (`internal/transport/…`): the typed `upsilonapi` HTTP client, future clients
to extracted services, and eventually MQ producers/consumers. Domain code never imports a
transport; contracts are plain message structs (cross-service ones in `upsilontypes`) carrying
`request_id`/`traceparent` as metadata. This is what makes the planned HTTP → MQ transition and
the further service extractions (doc 06) implementation swaps rather than refactors. Internally,
prefer event-shaped flow where it is already natural: the webhook handler publishes onto a small
in-process event bus that persistence, credit award, and the WS hub subscribe to.

## 2. Layer-by-layer mapping

| Laravel concept | Go/Gin equivalent | Notes |
|---|---|---|
| Route file + middleware groups | Gin `RouterGroup` + middleware chain | `/api/v1` group, `auth` + `admin` middleware |
| `StandardEnvelope` middleware | Gin middleware: unwrap req body, wrap response writer | Preserve exact `{request_id,message,success,data,meta}` shape |
| `ApiResponder` trait | `respond.Success(c, data, msg)` / `respond.Error(...)` helpers | |
| FormRequest (`*Request.php`) | request struct + `validator` tags + bind helper | 23 request classes → 23 DTOs |
| API Resource (`*Resource.php`) | response DTO + mapper func | 17 resources; **fog-of-war masking** in `BoardStateResource` is the tricky one — port carefully |
| Eloquent Model | sqlc row structs + repository funcs | UUIDs, JSONB casts, soft-delete `WHERE deleted_at IS NULL` |
| Policy (`*Policy.php`) | authz funcs called in handlers | `view`/`action`/`forfeit` checks |
| Service (`ShopService`, etc.) | domain package funcs | Mostly straight ports of arithmetic + DB tx |
| Broadcast Event | hub message + serializer | `BoardUpdated`/`MatchFound` → hub publish |
| Sanctum | JWT or opaque-token middleware | §4 |
| Exception handler | Gin recovery + error-to-envelope middleware | Map error types → status codes |
| Artisan migrate / seed | golang-migrate + a seed command | Port `DatabaseSeeder` family |
| Queue (`jobs` table) | **River** (Postgres job queue) + injected world clock | Platform arch §13 decision applied to the migration: background work (matchmaking tick, token cleanup) lands as River jobs with the injected clock from Phase 0 — not ad-hoc goroutines — because this becomes the platform's time infrastructure (arch §7) |

## 3. The frontend question (decisive for effort)

Three viable stances, in increasing ambition:

1. **Keep Vue SPA + Inertia shell, Go serves it.** Use a Go Inertia adapter
   (`romsar/gonertia`) for the ~6 bare shells and 3 admin prop-passing pages, serve the Vite
   build as static assets, and keep the SPA's axios `/api/v1` calls unchanged. **Lowest
   frontend churn.** Most of the SPA never knew it was Laravel.
2. **Keep Vue SPA, drop Inertia.** Serve `index.html` + assets statically, convert the 3 admin
   pages to fetch their data from a new `/api/v1/admin/*` endpoint (they already have API twins).
   Removes the Inertia dependency entirely. **Recommended** — Inertia buys little here since the
   app is already token-API-driven.
3. **Rewrite frontend.** Out of scope and unjustified — the Vue/Three.js arena is the most
   valuable, least-broken asset.

**The WebSocket transport is the real frontend coupling, not Inertia** — see doc 03. Decide
that first; the Inertia choice is minor by comparison.

> **Settled by the platform architecture (2026-07-04): option 2, and no `gonertia` at all.**
> The v3.0 common admin backend (arch doc §4) moves admin to a separate SPA on `/admin/v1`
> facets — so during the migration, build the 3 admin pages' data as facet-shaped API
> endpoints from the start and serve the SPA statically. Investing in an Inertia adapter
> would be building a bridge to a shore we're leaving.

## 4. Auth migration (Sanctum → Go)

Sanctum today = opaque DB tokens, 15-min expiry, sliding renewal, `ws_channel_key` rotated per
login. Two paths:

- **Opaque tokens in Postgres (closest behaviour):** keep `personal_access_tokens`, hash+lookup
  on each request, replicate the 10–15 min renewal injecting `meta.token`. Zero client change.
- **JWT (stateless):** simpler horizontally but loses server-side revocation and complicates the
  exact sliding-renewal semantics the tests assert.

**RESOLVED (2026-07-04): opaque tokens** — preserves `SanctumTokenRenewalTest` behaviour with
no frontend change; post-extraction (`upsilonauth`), consumers add a short-lived validation
cache. (The per-login `ws_channel_key` rotation may retire with the SSE decision — doc 03.)

## 5. Phasing (incremental, each phase shippable & testable)

> Principle: the Go service can run **side-by-side** with Laravel behind the same DB. Cut over
> endpoint groups behind a reverse proxy; the frontend never sees a big-bang switch.

- **Phase 0 — Skeleton & contracts.** New Go module in `go.work`; Gin up; envelope middleware;
  health `/up`; OTel bootstrapped (doc 04); golang-migrate importing the existing schema;
  testcontainers harness. Port `ApiResponderTest`/`ErrorHandlingTest` first — they pin the
  conventions everything else depends on.
- **Phase 1 — Auth + identity.** `auth/*`, profile, characters, Sanctum-equivalent tokens.
  Gate behind proxy for these routes. Green `AuthTest`/`GdprTest`/`SanctumTokenRenewalTest`.
  **Build all auth/account access behind an `IdentityService` interface** (no direct `users`-table
  reads from other packages) so Phase 7 is an implementation swap, not a refactor. Apply the same
  treatment to characters: a **`CharacterService` interface** in front of all roster/profile access —
  characters are a v3.0 extraction candidate (doc 06 §2.3).
- **Phase 2 — Engine bridge + game proxy.** Typed `upsilonapi` client (sharing `upsilontypes`),
  `game/*`, webhook ingestion, `BoardStateResource` masking. Green `BattleProxyTest`.
- **Phase 3 — Realtime (SSE).** Replace Reverb with the SSE stream (doc 03, resolved). This is
  where the container count drops. Validate with Playwright E2E against the live arena.
- **Phase 4 — Matchmaking.** The thorniest logic (modes, AI gen, resurrection/ISS-054). Green the
  full matchmaking suite. Resurrection touches the engine + JSONB cache — test hard.
- **Phase 5 — Economy/loadout + admin.** Shop, inventory, equipment, skills, leaderboard, admin CRUD.
  **Port shop/inventory *thin*** — behavior-parity handlers over the `EconomyService`/inventory
  seams, no extra polish: v3.0 reshapes shop into a market vendor and items into the shared
  registry (arch doc §5.1, open question #5), so depth invested here is depth rewritten there.
  **Route every credit/wallet/market operation through an `EconomyService` interface** (the credit
  ledger is never mutated by ad-hoc `increment` calls scattered across handlers) so Phase 8 is a
  clean cut. Note the existing coupling: `GameController` awards credits and equipment references
  inventory items — these become the first cross-service calls.
- **Phase 6 — Cutover & decommission.** Flip the proxy fully; delete `app`/`ws`/`db-init`
  containers; replace with one `hub` container (the modular monolith). Archive Laravel.

### Extraction phases (turn the seams into services) — moved out

> **Phases 7 (Extract Identity), 8 (Extract Economy), and the Phase 9 candidate
> (Characters/Profile), plus the post-extraction data-ownership boundary, have
> been relocated for safe keeping to
> `reporting/v3_platform/service_extraction/00_identity_economy_extraction.md`.** They were
> never part of the port (Phases 0–6, all done) — they are post-migration
> service decomposition along the `IdentityService`/`EconomyService` seams, and
> Phase 7 is already absorbed into the v3.0 roadmap as "V3-1a Auth extraction".

## 6. Effort & risk

| Phase | Relative effort | Primary risk |
|---|---|---|
| 0 Skeleton | S | Envelope/round-trip parity subtleties |
| 1 Auth | M | Sliding-renewal exactness; GDPR anonymise semantics |
| 2 Game proxy | M | **Fog-of-war masking** fidelity; envelope passthrough of engine errors |
| 3 Realtime (SSE) | M (was L — transport decision now made) | Reconnect/replay fidelity mid-match; proxy buffering; per-recipient masking parity |
| 4 Matchmaking | **L** | AI generation parity; **arena resurrection (ISS-054)** correctness |
| 5 Economy/admin | M | Breadth (many endpoints), credit-ledger tx integrity |
| 6 Cutover | S | Ops/runbook, data continuity (same DB → low) |

> Effort/risk for the extraction phases (7 Identity, 8 Economy) moved with them to
> `reporting/v3_platform/service_extraction/00_identity_economy_extraction.md`.

**Lowest risk:** DB schema (port verbatim), engine bridge (gets *better* with shared types).
**Highest risk:** WebSocket transport choice and matchmaking/resurrection logic.

**De-risking levers:** (a) shared DB side-by-side running; (b) the 74 PHP tests as the
acceptance oracle — port them *first* per phase; (c) Playwright E2E as the cross-stack gate;
(d) the Postman collections (`Upsilon_Battle.postman_collection.json`) as additional contract checks;
(e) **upsiloncli as the almost-E2E harness** — its existing battleui scripting must stay green
across the cutover (same envelope, same endpoints), which makes it a free per-phase acceptance
gate; it is slated to grow per-domain clients for all platform APIs in v3.0,
so keep its client layer per-endpoint-group rather than one monolithic client (arch doc §13.4).

## 7. What gets *deleted* by this migration

- Laravel Reverb + `pusher-js` server dependency, and the `ws` + `db-init` containers.
- The PHP-FPM/queue split; `jobs`/`cache` tables (if Go uses native concurrency).
- The runtime envelope middleware gymnastics (becomes idiomatic Go middleware).
- PHP itself from the deploy surface — the user's stated motivation.
