# 01 — Current State: Complete Inventory of battleui

This is the "what must be reproduced" map. Everything here is a migration obligation.

## 1. Stack & runtime

| Concern | Today |
|---|---|
| Framework | Laravel 12 (PHP 8.2+) |
| Frontend | Vue 3 SPA via Inertia 2, Vite, TailwindCSS, TresJS/Three.js (3D arena) |
| Realtime | **Laravel Reverb** (Pusher-protocol WS server) + `laravel-echo` + `pusher-js` client |
| Auth | Laravel Sanctum (personal access tokens, 15-min expiry + sliding renewal) |
| Modules | `nwidart/laravel-modules` present in composer but **no `Modules/` dir exists** — unused |
| DB | PostgreSQL 18 (dev: `postgres`; prod: `upsilon`) |
| Queue/Cache/Session | DB-backed (`jobs`, `cache` tables) — no Redis in compose despite env keys |
| Engine bridge | `UpsilonApiService` → HTTP to `upsilonapi` (Go, port 8081) |

### Production container topology (the pain point)

`docker-compose.prod.yaml` builds **one image** from `battleui/Dockerfile.prod` and runs it as:

- **`app`** — PHP-FPM/nginx serving HTTP on `:80` (the REST API + Inertia shell)
- **`ws`** — same image, `php artisan reverb:start` on `:8080` (the WebSocket server)
- **`db-init`** — same image, one-shot `php artisan migrate --force`

Plus `db` (Postgres), `engine` (`upsilonapi`), `cli`. So **battleui alone is 3 containers**.
The split is forced: PHP-FPM workers are request-scoped and cannot host persistent sockets,
so Reverb *must* be its own long-lived process. Broadcasting from the API process reaches the
WS process via the configured broadcast connection. This is exactly what a Go service collapses.

## 2. HTTP API surface (`routes/api.php`, prefix `/api/v1`)

All wrapped by the **Standard Envelope** (see §5). `auth:sanctum` unless noted.

### Public (no auth)
- `POST /webhook/upsilon` — **engine callback** (no `/v1` prefix; validated by `WebhookRequest`)
- `GET  /v1/help` — API self-documentation (`HelpController` + `ApiDiscoveryService`/`CodeDiscoveryService`)
- `POST /v1/auth/login`, `POST /v1/auth/admin/login`, `POST /v1/auth/register`

### Auth — account & GDPR (`AuthController`)
- `POST /v1/auth/logout` · `POST /v1/auth/update` · `POST /v1/auth/password`
- `GET  /v1/auth/export` (GDPR data export) · `DELETE /v1/auth/delete` (anonymise + soft delete)

### Profile & characters (`ProfileController`)
- `GET /v1/profile` · `/profile/credits` · `/profile/characters` · `/profile/character/{id}`
- `POST /v1/profile/character/{id}/reroll` · `/upgrade` · `/rename` · `DELETE /{id}`

### Matchmaking (`MatchMakingController`) — **highest business complexity**
- `GET /v1/matchmaking/status` — also handles **reconnection + arena resurrection (ISS-054)**
- `POST /v1/matchmaking/join` · `DELETE /v1/matchmaking/leave`
- `GET /v1/match/stats/waiting` · `/match/stats/active` (proxies engine)
- Modes: `1v1_PVP`, `1v1_PVE`, `2v2_PVP`, `2v2_PVE`. PVE generates AI players with
  archetype/name/grade logic (see `assignAIArchetypes`, `generateAIName`).

### Game proxy (`GameController`)
- `GET  /v1/game/{id}` — masked board state (fog-of-war via `BoardStateResource`)
- `POST /v1/game/{id}/action` — entity-ownership check → engine; awards credits from results
- `POST /v1/game/{id}/forfeit`

### Economy & loadout
- Shop: `GET /v1/shop/items` · `POST /v1/shop/purchase` (`ShopController` + `ShopService`)
- Inventory: `GET /v1/profile/inventory` (`InventoryController`)
- Equipment: `GET/POST/DELETE /v1/profile/character/{id}/equipment|equip|unequip/{slot}` (`EquipmentService`)
- Skill templates (catalog): `GET /v1/skills/templates[/{id}]`
- Character skills (loadout): `GET /v1/profile/character/{id}/skills` · `roll` · `{skillId}/equip` · `unequip` (`SkillService` + `SkillGeneratorBridge`)
- Leaderboard: `GET /v1/leaderboard`

### Admin (`admin` middleware, prefix `/v1/admin`)
- `GET /users` · `POST /users/{name}/anonymize` · `DELETE /users/{name}` (withTrashed)
- `GET /history` · `POST /history/purge`
- `apiResource skill-templates` + `apiResource shop-items` (full CRUD, `AdminSkillTemplateController`, `AdminShopItemController`)

### Web routes (`routes/web.php`) — Inertia shells
- `/`, `/login`, `/register`, `/dashboard`, `/battlearena`, `/api-docs`, `/admin/*`
- Catch-all SPA router `/{any}` excluding `api/` and `up`
- `__test/component/*` and `__test/battle/*` — **frontend test seams** (`mech_frontend_test_seams`)
- Only **3** Inertia renders pass server props (admin pages); the rest are bare shells.

## 3. WebSocket / realtime (`routes/channels.php`, `app/Events/*`)

| Channel | Auth rule | Events |
|---|---|---|
| `arena.{matchId}` (private) | requester is a `MatchParticipant` of the match | — (defined, see note) |
| `user.{key}` (private) | `user.ws_channel_key === key` (rotated every login) | `BoardUpdated`, `MatchFound` |
| `battle.{id}` (public) | none | `BattleUpdated` (legacy/test) |

- **`BoardUpdated`** (`ShouldBroadcast`): on each engine webhook, broadcasts a **per-recipient
  masked** board snapshot to each participant's private `user.{key}` channel. Masking
  (fog-of-war) is identity-aware via `BoardStateResource($payload, $recipient)`.
- **`MatchFound`**: notifies queued players their match is ready.
- **`BattleUpdated`** (`ShouldBroadcastNow`): legacy event on public `battle.{id}`.
- Client wiring: `resources/js/bootstrap.js` → `new Echo({ broadcaster: 'reverb', ... })`
  driven by `VITE_REVERB_*`. Composables `useBattleChannel`, `usePrivateChannel`,
  `useBoardState` consume it.

**Critical migration fact:** the wire protocol is **Pusher**. Any Go replacement must either
speak Pusher (to keep the frontend untouched) or the frontend's transport layer must change.
See doc 03.

## 4. The engine bridge — `UpsilonApiService` (~190 LOC)

Single HTTP client to `upsilonapi` (`config services.upsilon.url`). Methods:
`startArena`, `sendAction`, `forfeit`, `checkArenaExistence`, `getActiveMatchStats`,
`resurrectArena` (translates cached `BoardState` JSONB → engine `ArenaResurrectRequest`).
All calls wrapped in the standard envelope with `request_id` propagation. Engine rule
rejections (e.g. 412) are preserved (envelope passthrough), connection failures throw
`EngineConnectionException`. **In Go this becomes a typed client sharing `upsilontypes`.**

## 5. Cross-cutting conventions (must be preserved byte-for-byte)

- **Standard Envelope** (`StandardEnvelope` middleware + `ApiResponder` trait):
  every `/api/v1` request is *unwrapped* (`{request_id, data}` → controller sees `data`;
  `request_id`→`X-Request-ID` header) and every JSON response is *wrapped* as
  `{request_id, message, success, data, meta}`. Atom `[[api_standard_envelope]]`.
- **Request ID** (`[[api_request_id]]`): payload `request_id` → `X-Request-ID` header → fresh UUIDv7.
- **Error handling** (`bootstrap/app.php` `withExceptions`): all `api/*`/`v1/*` errors render
  as envelopes; structured log line `[ts] [ref_id] [endpoint] message`; 500s sanitised unless debug.
  Atom `[[rule_tracing_logging]]`.
- **Sanctum token renewal** (`SanctumTokenRenewal`): tokens issued 15-min; sliding renewal at
  10–15 min injects new token into response `meta.token`. Atom `[[mech_sanctum_token_renewal]]`. Sanctum equivalent solution must be found.
- **Health**: `GET /up` (`[[api_laravel_health_check]]`).
- **Inertia shared props** (`HandleInertiaRequests`): shares `auth.user`. Go equivalent must be found.

## 6. Data model (PostgreSQL — ported as-is)

28 migrations. Core tables and notable columns:

| Table | Notes |
|---|---|
| `users` | UUID PK; `account_name`, `email`, `password_hash`, `full_address`, `birth_date` (GDPR/resident data); `ws_channel_key`; `role`; `credits` (default 1000); `total_wins/losses`, `ratio`; `reroll_count`; `roulette_used`; **soft deletes**; admin perf indexes |
| `characters` | UUID; `player_id` FK (cascade); v2 stat block; `initial_movement`; `spent_cp`; `roulette_used` |
| `game_matches` | UUID PK; `game_mode`; `game_state_cache` **JSONB**; `grid_cache` JSONB; `turn` (bigint); `version` (optimistic concurrency, `[[mech_game_state_versioning]]`); `started_at`/`concluded_at`/`winning_team_id` |
| `match_participants` | `match_id`, `player_id` (**nullable** for AI), `team` |
| `matchmaking_queues` | `user_id`, `game_mode`, `character_ids` (JSON), `created_at` ordering |
| `personal_access_tokens` | Sanctum |
| Credit economy | `credit_transactions`, `inventory_transactions` (ledgers) |
| Item system | `shop_items`, `player_inventories`, `character_equipments` (3-slot: armor/utility/weapon), each linkable to a `skill_template` |
| Skills | `skill_templates` (catalog), `character_skills` (slot-based loadout) |
| Laravel infra | `cache`, `jobs` (queue) — **may be dropped** if Go uses native concurrency |

Models add behaviour worth noting: `Character::generateInitialRoster()`, `User::anonymize()`
(GDPR), policies (`CharacterPolicy`, `GameMatchPolicy`) gating view/action/forfeit.

## 7. Tests — the executable specification (74 methods)

PHP feature tests are the most reliable behavioural contract. They must be **re-expressed in Go**,
not discarded. Coverage clusters:

- **Auth/GDPR**: `AuthTest`, `GdprTest`, `SanctumTokenRenewalTest`, `AdminSelfProtectionTest`
- **Matchmaking**: `MatchmakingTest`, `ExtraMatchmakingTest`, `PVEMatchmakingTest`, `MatchVerificationTest`
- **Game proxy**: `BattleProxyTest` (engine bridge behaviour, mocked)
- **Economy/loadout**: `CharacterTest`, `CharacterUpgradeTest`, `SkillTest`, `LeaderboardTest`
- **Conventions**: `ApiResponderTest`, `ErrorHandlingTest`, `UpsilonApiRoundtripTest`, `UpsilonEntityResourceTest`
- **Unit**: `CharacterSkillSlotsTest`, `CharacterStatDistributionTest`
- **E2E (stays as-is)**: Playwright specs (`tests/playwright/*`) drive the *frontend* and are
  transport-agnostic — they remain valid against the Go backend if the API/WS contract holds,
  and become the **cross-stack acceptance gate** for the migration.

## 8. ATD traceability load

**200 `@spec-link [[atom]]` occurrences across 60 PHP files**, plus battleui's own ATD project
registration (`battleui/.atd`, `docs/` with 63 `.atom.md` files) and the workspace entry in
`.atd.workspace`. Cross-project links exist (e.g. `[[upsilonapi:api_shop_purchase]]`,
`[[upsilonbattle:mec_three_slot_equipment_system]]`). Migrating the code without migrating
these links would silently break the project's traceability graph. See doc 05.
