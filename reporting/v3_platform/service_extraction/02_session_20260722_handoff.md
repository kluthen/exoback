# Extraction session 2026-07-22 — state & continuation handoff

**Who:** Bastien + Claude (Fable 5). **Plan of record:** approved plan in the session
(mirrored by decisions below); playbook: [`../how_to_add_a_service.md`](../how_to_add_a_service.md).
**Stopped because:** monthly agent-spend limit + end of context. Everything below is pushed.

## Decisions locked this session

1. **Per-service databases** (`upsilon`/`upsilonauth`/`upsiloneconomy`) on the shared Postgres
   instance; provisioned by `deploy/initdb/create_databases.sql`; never cross-database SQL.
2. **upsilonauth** = platform token service (opaque Sanctum-parity tokens; no OIDC). Hub-side
   validation = `POST /internal/v1/introspect` + ~5s in-memory cache; **renewal decided in auth**,
   introspection response carries `renewed_token`.
3. **upsiloneconomy** internal-only behind the hub; wallets lazy-create @1000; awards are
   ledger-first idempotent (`credit_transactions.idempotency_key` UNIQUE).
4. **REMODEL (game-agnostic accounts):** auth register = account+token ONLY. Games own
   enrollment: hub gets `POST /api/v1/battle/enroll` (creates roster + player_stats, then
   records into auth's `service_registrations` — already built, key `tactical`). Login/user
   payloads carry account + `registrations: []string` (already on the wire, incl. introspection).
   Byte-parity gate for auth E2E is replaced by "updated register→enroll→play flow green".
5. **Hub rename → `upsilontactical`** as a dedicated operation AFTER the extraction phases
   (docs already rescope hub as the battle game service).

## Landed on main (all pushed, all repos clean)

- **Phase 0**: `upsilonplatform` kit (respond/clock/observability/database/jobs + httpx S2S
  client) extracted from hub; three new private repos/submodules wired (go.work,
  .gitmodules, .atd.workspace, CI); per-service DB provisioning in dev+CI compose.
- **Phase 1**: `upsilonauth` (:8091) complete and dark — full auth surface, introspection,
  constant-time S2S guard, seeds via `upsilontypes/seedids`, 31 tests. PLUS the
  registrations registry (later addition): table 000002, idempotent
  `POST /internal/v1/users/:id/registrations`, 44 tests total.
- **Phase 2**: `upsiloneconomy` (:8092) complete and dark — wallets/ledgers/shop/inventory,
  idempotent awards + GDPR purge, 18 tests incl. concurrency races.
- **Phase 6 (docs)**: `how_to_add_a_service.md` (+ INDEX), hub ATD pair
  (`contract_game_composition`, `vision_platform_v3`), architecture §8 amendment,
  service_map + UPSILON.md rescopes.
- **Verified**: full 6-image CI stack boots healthy locally; seeds land in all 3 DBs;
  introspection + S2S guards correct; scenario suite 33/37 (the 4 = ISS-119, pre-existing
  local-only race, proven on a pre-session worktree).
- **Issues filed**: ISS-117 (upsilonapi Dependabot 7-critical), ISS-118 (GDPR per-game
  export gap — gate before Phase-4 cutover), ISS-119 (match-start race, local dev only).

## Phase 3 (hub economy swap) — LANDED 2026-07-22 (merged to main, pushed)

All three `phase3-economy-swap` branches merged → main and pushed (platform `efdcef3`,
economy `ba61a64`, hub `1bbb228`), umbrella pointers bumped. The full swap is live: the hub
reads wallets, runs purchases and drains credit awards against the extracted
**upsiloneconomy**; economy DB holds all money/item writes, hub economy tables are dormant.

**Core swap (from the WIP branch):** economyclient over httpx; `economy.Service` reshaped
(wallet reads GetWallet/ListWallets; awards on an `IdempotentAwarder` seam); River worker
`internal/awards/` + enqueue in `processCredits` (key = sha256 match|player|source|ordinal);
migration 000003 drops equipment→inventory FKs; hub seed drops the shop catalog; config
`ECONOMY_INTERNAL_URL` (empty ⇒ in-process rollback) + `S2S_TOKEN`.

**Finish work this session:** Dockerfile brings in upsilontypes/upsilonmapdata/upsilontools;
`docker-compose.ci.yaml` wires the hub to economy; dev scripts run economy full-swap;
economyclient + award-worker unit tests.

**Two real bugs the CI stack caught (the WIP "code complete" claim missed both):**
1. **Economy envelope unwrap** — `upsiloneconomy` bailed on an empty `request_id`, but httpx
   always wraps and sends `""` (the award worker's background ctx). Every enveloped POST bound
   the outer object → awards 422, shop-create 500. Fixed to unwrap on the `data` key.
2. **Equipment-loadout read path** — `BattleLoadouts` still joined the (now-empty) hub
   catalog/inventory → equipped items gave 0 buffs. Rewired **fetch-at-battle** via a
   `character.EquippedItemResolver` economy seam (character stays economy-free; battle supplies
   the economy-backed resolver; skill_templates resolved hub-side). The plan had designed only
   the equip *write* ownership check, not this read path — a genuine scope gap.

**Verified:** economy DB holds inventory/credit txns + moved wallets, hub DB 0 economy writes;
hub logs zero downstream/award errors; equipment scenarios green; full hub + economy suites
green. Scenario suite 31–32/37 — residual are pre-existing local-only flakes (ISS-119
match-start race, engine pathing, foe skill-visibility), non-deterministic, no economy errors.

## Then: Phase 4 (re-cut by the remodel)

- Hub migration 000004: `player_stats` (user_id PK, denormalized account_name+deleted_at,
  wins/losses/ratio/reroll) + backfill; battle SQL `JOIN users`→`JOIN player_stats`; drop
  characters/match_participants→users FKs; delete hub `identitypg`.
- `internal/transport/authclient`: trimmed `identity.Service` over introspection (+5s cache
  keyed sha256(bearer), negative 2s; any client error ⇒ ErrUnauthenticated 401);
  `TokenRenewal` relays `renewed_token`.
- **`POST /api/v1/battle/enroll`** (RequireAuth): create roster + player_stats, then record
  `tactical` in auth (idempotent; whole op fails together). Battle endpoints needing a
  roster guard on enrollment (registrations ride in on introspection).
- Auth pushes account lifecycle to hub `POST /internal/v1/players/{id}/account`
  (authv1.AccountPush, durable via auth's River) → player_stats identity-column upsert.
- Caddyfile: `/api/v1/auth/*` → auth:8091; `respond /internal/* 404`; compose deps.
- upsiloncli: register→enroll→play flow in bootstrapBot + scenarios; new edge cases
  (auth-outage 401 parity, economy-outage, award-replay-after-restart).
- NO auth→hub/economy composition (remodel): login returns account+registrations only.
  Mind ISS-118 (export scope) before cutover.
- **GATE — ISS-120 (High):** internal S2S calls currently ship an empty `request_id`
  (the hub never propagates its inbound `X-Request-ID` into httpx; durable jobs mint none).
  A correlation id is mandatory — adopt-then-propagate, mint at a true origin, never empty.
  Phase 4 adds the authclient introspection hop and the enroll→auth push (longer internal
  chains), so this must be rectified as part of / before Phase 4, not deferred.

## Then: Phase 5

Hub migration 000005 drops users/personal_access_tokens/password_reset_tokens + the four
economy tables + users.credits remnants; delete in-process impls + rollback flag; prod
cutover runbook (`01_prod_cutover_runbook.md` + guarded `scripts/cutover_extraction.sh` —
same-instance pg_dump copies, wallets seeded from users.credits, player_stats backfill
BEFORE users drop). Never executed against AWS without Bastien.

## CI notes

- Umbrella CI needed a disk-space step (6 images > stock runner disk) — landed (`7c6dd71`).
- Latest runs: unit+build green; watch the first fully-green integration run post-fix.
- upsilonapi/upsiloncli Dockerfiles copy the whole workspace: any future go.work module
  addition must update their COPY lists (see playbook §6).
