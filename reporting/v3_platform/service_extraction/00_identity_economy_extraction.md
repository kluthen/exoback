# Service Extraction — Identity & Economy (deferred, post-migration)

**Status:** Not started. Preserved for safe keeping, extracted 2026-07-09 from
`reporting/battleui_migration/02_migration_strategy.md` (§5 "Extraction phases",
§5 data-ownership boundary, §6 effort/risk rows 7–8).

## Why this doc exists

The battleui (Laravel) → upsilonhub (Go) migration was planned as **Phases 0–6**,
all now **DONE** (see `reporting/battleui_migration/00_kickoff.md` ledger). The
original strategy doc also sketched three *further* phases — **7, 8, and a
candidate 9** — that were never part of the port itself. They are **service
decomposition**: splitting the now-modular-monolith hub into independently
owned/deployed Go services along the interface seams that Phases 1 and 5
deliberately built.

They are pulled out here so they don't get lost inside a completed-migration
folder, and so the plan stays actionable if/when it's scheduled.

### Relationship to v3.0

These phases are **not orphaned** — the v3.0 platform roadmap already absorbs
the important one:

- **Phase 7 (Identity extraction) → v3.0 step "V3-1a Auth extraction"**
  (`reporting/v3_platform/v3_platform_architecture.md`): promote identity to a standalone
  `upsilonauth` service; the hub's identity package becomes its client; it is
  the SSO seam that landing, admin, and future game apps all trust. Phase 7's
  content is that step, resequenced.
- **Phase 8 (Economy extraction)** still slides *past* v3.0 — only its seam
  matters near-term. Extract when independent ownership/scale actually justifies
  the network hop.
- **Phase 9 (Characters/Profile)** remains an unscheduled candidate
  (`reporting/v3_platform/06_v3_platform_constraints.md` §2.3).

## Guiding principle (verbatim from the strategy doc)

> Driven by **clean ownership and independent deploy/scale**, not load — Identity
> and Economy are both *low-load* (co-location is fine), but they are
> cross-cutting substrates that several future services will depend on, so they
> get their own DB ownership and service boundary now while the code is fresh.
> Extract along the interfaces built in Phases 1 and 5 — this is an
> implementation swap (in-process call → network call), not a rewrite. Sequence
> them after the gateway is proven; do **not** big-bang them up front.

## The seams are already in place (built during the migration)

Extraction is an *implementation swap*, not a refactor, because the migration
already routed all access through interfaces:

- **`IdentityService`** — every `users`-table / auth / token / GDPR path in the
  hub goes through it (`upsilonhub/internal/platform/identity`). No package
  reads the `users` table directly. This is the Phase 7 cut line.
- **`EconomyService`** — every credit/wallet/market/inventory operation goes
  through it; the credit ledger is never mutated by ad-hoc `increment` calls.
  This is the Phase 8 cut line.
- **The cross-cutting wrinkle, already designed as an explicit call:**
  equip/unequip does a hub→economy ownership check via
  `EconomyService.GetInventoryItem` rather than a SQL join into inventory —
  so `character_equipments` (gameplay, hub) referencing inventory items
  (economy) does not surprise Phase 8.

## Phase 7 — Extract Identity service

Promote `IdentityService` to a standalone Go service owning its own schema:
`users` (account_name, email, password_hash, address/birth_date, role,
`ws_channel_key`, soft-deletes) + `personal_access_tokens`.

- **Exposes:** token issue/validate (the auth seam every other service trusts),
  account CRUD, GDPR export/anonymise, admin user management.
- **The hub becomes a *consumer*** — token validation goes through it.
  (Note: `ws_channel_key` was retired from the transport at Phase 3 and the
  column dropped at Phase 6 migration `000002`; the identity schema above is the
  original Phase-7 sketch and should be reconciled against the current hub
  schema before work starts.)
- **Gate:** re-run the auth / GDPR / renewal suite **against the service
  boundary**, not just in-process.
- **Relative effort:** M. **Primary risk:** token-validation seam latency — the
  auth path becomes a remote call; cache/validate carefully.

## Phase 8 — Extract Economy service

Promote `EconomyService` to a standalone Go service owning the wallet + market:
`credit_transactions`, `inventory_transactions`, `shop_items`,
`player_inventories`, and the **`credits` balance moved off the `users` row into
a wallet** owned here.

- **Exposes:** balance read, transactional award/spend (atomic ledger), market
  browse/purchase, inventory list.
- **Consumers:** `GameController` credit awards, shop purchase, equipment
  ownership checks.
- **Play stats stay gateway-side** — `total_wins`/`losses`/`ratio` and the
  leaderboard are battle concerns, not economy; only money/items move.
- **Relative effort:** M. **Primary risk:** moving `credits` off `users` (a data
  migration); award/spend must stay atomic across the boundary — idempotency on
  credit events.

## Phase 9 (candidate, unscheduled) — Extract Characters/Profile service

The `CharacterService` seam from Phase 1 is the preparation; extraction is a
v3.0-era decision. See `reporting/v3_platform/06_v3_platform_constraints.md`
§2.3. Hub ownership of `characters` is **provisional** — reference characters by
UUID and avoid new joins into `characters` to keep this option open.

## Data-ownership boundary (post-extraction)

| Owner | Tables | Notes |
|---|---|---|
| **Identity svc** | `users` (account/auth cols), `personal_access_tokens` | System of record for *who*; issues/validates tokens |
| **Economy svc** | `credit_transactions`, `inventory_transactions`, `shop_items`, `player_inventories`, wallet balance | System of record for *money & items* |
| **Hub (gateway)** | `characters`, `game_matches`, `match_participants`, `matchmaking_queues`, `character_equipments`, `skill_templates`, `character_skills`, play-stats columns | Gameplay truth; references Identity (player) + Economy (items) by id across the seam. Hub ownership of `characters` is **provisional** — v3.0 extraction candidate (doc 06 §2.3) |

> The one cross-cutting wrinkle: `character_equipments` (gameplay, hub)
> references inventory items (economy). Equip/unequip is a hub→economy ownership
> check rather than a SQL join — the `EconomyService.GetInventoryItem` call built
> in Phase 5 is exactly this seam.
