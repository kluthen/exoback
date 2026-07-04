# 06 — v3.0 Platform Constraints (forward-looking addendum)

> Added 2026-07-04 from user direction. **Status: design constraints only — none of this is
> implemented in the migration itself.** The full platform design derived from these
> constraints lives in [`../v3_platform_architecture.md`](../v3_platform_architecture.md). These notes exist so the Go restructure doesn't paint
> the project into a corner; where they conflict with earlier phrasing in docs 02/03, this
> document wins on *structure* while the original docs win on *scope* (nothing extra gets built).

## 1. The three constraints

1. **v3.0 becomes a multi-game platform built around "the world".** upsilon-hub is expected to
   expand beyond the single TRPG: economy, inventory, and characters may be **shared across
   games**, anchored in a **common world** — a world map with **cities**, **transport between
   cities**, **layers of progression** (to be detailed later), **events**, and **reputation**.
   The planned game roster (sketch, subject to change):
   - **Tycoon** — industry-oriented; CEOs ruling cities.
   - **Spycraft** — disruption / counter-espionage against CEOs.
   - **Battle (the current TRPG)** — repurposed as the world's military arm: protecting
     cities, founding new cities, exploring **"the wild"** (beyond the colonized world).
   - **Digital-world exploration** — monster-capture flavor.

   The games interlock *through* the shared world (cities are ruled by tycoon players,
   disrupted by spies, defended/founded by battlers), so cross-game effects are the point, not
   an edge case. Today's battleui/hub is therefore the *first game's* gateway, not *the*
   platform; battles become one activity a character does *in* the world.
2. **Internal communication moves from HTTP APIs to a message queue** (broker TBD) at some
   point. The rewrite must keep the communication layer separate enough that swapping
   transport is a bounded change, not a refactor.
3. **More sub-services will be carved out of battleui** than the two already planned — among
   others **economy** (planned, Phase 8), **character profile**, and likely inventory. The
   internal seams must anticipate extraction as the *normal* fate of a domain package, not the
   exception.

## 2. What this changes in the migration strategy (doc 02)

### 2.1 Transport isolation becomes a hard rule, not a style preference

- **Domain packages never touch a transport.** No `net/http`, no WS, no future MQ client
  imports inside `identity`, `economy`, `character`, `matchmaking`, `game` packages. Each
  domain depends only on narrow Go interfaces (`IdentityService`, `EconomyService`,
  `EngineClient`, …).
- **All transport implementations live in one place** (e.g. `internal/transport/…`): the
  typed HTTP client to `upsilonapi`, the future HTTP clients to extracted services, and the
  eventual MQ producers/consumers. Swapping HTTP → MQ is then a new implementation of an
  existing interface plus wiring, with zero domain-code churn.
- **Contracts are plain message structs**, not framework-shaped requests/responses. Define
  them in a contracts layer (cross-service ones belong in `upsilontypes`) so the same payload
  rides HTTP today and a queue tomorrow. Every message carries the correlation identity
  (`request_id` / `traceparent`, doc 04) as *message metadata*, which maps 1:1 onto MQ headers
  later. Design commands to be **idempotent** (dedupe key = request_id) — mandatory for
  at-least-once delivery on a queue, and already desirable over HTTP.

### 2.2 Prefer event-shaped internal communication where it's natural

The engine → hub path is *already* an event (`/webhook/upsilon` → fan-out). Keep that shape:
internally, the webhook handler should publish a domain event onto a small **in-process event
bus** which the WS hub, persistence, and credit-award logic subscribe to — rather than a
handler that imperatively calls each concern. That dispatcher is precisely the component an
MQ replaces; request/reply calls (token validation, balance check) stay as interface methods
and become RPC-over-MQ or stay HTTP, whichever the broker decision favours.

### 2.3 Characters/profile is a third extraction candidate

Doc 02 builds `IdentityService` (Phase 1) and `EconomyService` (Phase 5) as extraction seams.
Add the same treatment for characters:

- **Phase 1/5 addendum:** route all character/roster/profile access through a
  `CharacterService` interface — no direct `characters`-table reads from matchmaking, game, or
  equipment code.
- **Phase 9 (candidate, unscheduled) — Extract Characters/Profile service** owning
  `characters` (and plausibly `character_equipments`, `character_skills` — decide at
  extraction time, since equipment already straddles the economy seam per doc 02 §5).
- Consequence for the data-ownership table (doc 02 §5): treat the hub's ownership of
  `characters` as **provisional**. Reference characters by UUID across domain packages and
  avoid *new* SQL joins from gameplay tables into `characters` beyond what exists today.

### 2.4 Multi-game hygiene in soon-to-be-shared domains — cheap now, not speculative

Do **not** add `game_id` columns or multi-tenancy now. Do observe two cheap disciplines:

- Keep the shared-candidate domains (economy ledger, inventory, characters) free of
  battle-specific coupling: no battle/matchmaking imports, no battle-shaped enums in their
  schemas. Battle-specific reasons ("won match X") enter the ledger as opaque
  reference/description data, not as typed foreign keys into `game_matches`.
- Keep play-stats (wins/losses/ratio, leaderboard) clearly on the **battle-gateway side**
  (doc 02 already does this) — in a multi-game world these are per-game, while wallet and
  characters may not be.

### 2.5 What the world sketch implies for today's seams (nothing to build, three things to not-break)

The world detail (map/cities/transport, progression layers, events, reputation) sharpens three
of the disciplines above without adding scope:

- **Characters will acquire world state** (location, progression, reputation). This is the
  strongest argument for the `CharacterService` seam (§2.3): world attributes must be able to
  attach to a character *without* the battle gateway caring. Corollary: don't let battle code
  grow ad-hoc columns on `characters` during the port — battle-specific needs go in
  battle-owned tables keyed by character UUID.
- **"Events" and "reputation" are cross-domain reactions** (a match outcome may one day feed
  reputation, world events may feed the economy). The in-process event bus (§2.2) is the seam
  where those reactions will plug in — so domain outcomes (match concluded, purchase made,
  credits awarded) should be *published as events* even when today's only subscriber is the WS
  hub or a ledger write. That, not the transport swap, is what makes the future MQ valuable.
- **Reputation/progression ≠ play stats.** Doc 02 keeps `total_wins/losses/ratio` and the
  leaderboard gateway-side; that stays correct — they are *this game's* stats. Future
  reputation/progression layers are world/platform concerns and must not be bolted onto those
  columns or onto `users`.
- **Battles will be world-triggered, not only queue-triggered.** In the roster above, the
  battle game defends cities, founds cities, and explores the wild — meaning a *world event*
  (siege, expedition) will one day need to start a match with a given context and participant
  set, without anyone sitting in a matchmaking queue. Consequence for the port: keep **match
  creation** ("these participants, these teams, this context → running arena") as its own
  domain operation that queue-based matchmaking merely *calls*, rather than burying arena
  startup inside the queue-processing logic. Today's PVE path (AI roster generation → start
  arena) already has this shape — preserve that separation when porting
  `MatchMakingController`, and the future world-event trigger becomes just another caller.
  Queue-based play doesn't go away, though: **cities with the right infrastructure will host
  arenas that carry today's behavior forward** — the current global queue becomes "the queue
  at an arena". So treat queue *scope* as a parameter of the matchmaking domain rather than a
  global singleton woven through the logic: matching, mode rules, and AI generation should
  read the queue through the seam, so scoping queues per-arena later is a keying change (add
  a scope to the queue's identity), not a rewrite. No `arena_id`/`city_id` columns now — same
  rule as §2.4.

An open question deliberately *not* answered now: whether one character spans games (a CEO who
also battles) or each game has its own character type sharing only identity/wallet. Don't
encode either assumption — which is exactly what referencing characters by UUID through
`CharacterService` (§2.3) buys.

Note: the existing `upsilonmapdata`/`upsilonmapmaker` libraries model *battle boards*; the v3.0
world map is a different domain. Avoid overloading "map" vocabulary in new package/atom names —
say `board` for arena geometry so `world`/`map` stays free for v3.0.

### 2.6 Naming

Prefer **`upsilonhub`** over `battlehub` for the new module: post-v3.0 this process trends
toward "the battle game's gateway on a platform", and the platform-candidate packages
(identity, economy, inventory, character) should be visibly separable from the battle-specific
ones (matchmaking, game proxy, realtime) in the package tree from day one.

## 3. What this explicitly does *not* change

- **Phasing and scope** (doc 02 §5): same order, same side-by-side cutover; no MQ, no broker,
  no new services are built during the migration.
- **The WebSocket decision** (doc 03): the client-facing transport choice (A vs C) is
  orthogonal to internal MQ plans — the WS/SSE hub subscribes to the in-process bus either way.
- **The DB port** (doc 01 §6): schema still ports verbatim; ownership boundaries are enforced
  in code (interfaces) first, schema second, exactly so extractions stay implementation swaps.
- **Observability design** (doc 04): unchanged, and the `traceparent`-in-message-metadata rule
  above means trace continuity survives the MQ transition for free.
