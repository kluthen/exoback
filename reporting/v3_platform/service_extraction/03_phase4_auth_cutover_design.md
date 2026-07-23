# Phase 4 — Auth cutover + game-agnostic accounts (design lock)

**Status:** design locked 2026-07-23 (continues `02_session_20260722_handoff.md`).
**Gate cleared:** ISS-120 (mandatory request_id) — fixed on branches `iss-120-mandatory-request-id`.
**Pre-cutover gate remaining:** ISS-118 (per-game GDPR export).
**Ownership decision (Bastien 2026-07-23):** standard account self-service is **removed from the
hub and Caddy-routed to auth**; the hub keeps only game-local concerns. Admin *account*
registry moves to auth too (auth grows a public admin surface); admin *game* views
(match history, leaderboard, shop/skill CRUD) stay in the hub.

---

## 1. Ownership boundary after cutover

| Concern | Owner after Phase 4 | How the hub reaches it |
|---|---|---|
| register / login / admin-login / logout / update / password / delete / export | **auth** (public `/api/v1/auth/*`) | Caddy routes the SPA/CLI straight to `auth:8091`; **hub handlers deleted** |
| admin user registry (list / count-admins / anonymize / soft-delete) | **auth** (NEW public `/api/v1/admin/users*`, admin-gated) | Caddy routes to auth; **hub `admin.go` account handlers deleted** |
| token validation / renewal | **auth** (introspection) | hub `authclient` over `POST /internal/v1/introspect` |
| account identity lookup for matchmaking | **hub** read model | `player_stats.account_name` (enrolled players only) |
| enroll (create roster + stats + register `tactical`) | **hub** | new `POST /api/v1/battle/enroll` |
| play stats (wins/losses/ratio/reroll), leaderboard, match history | **hub** | `player_stats` |
| wallet / shop / inventory | **economy** (Phase 3, done) | economyclient |

**auth build-out required this phase:** a public admin route group (reuse the existing
internal admin handlers' logic, gate with auth's own `RequireAuth` + admin-role check).
Everything else on the auth side already exists (introspection, registrations, account CRUD).

---

## 2. `identity.Service` split

The 19-method `identity.Service` (hub) collapses. Introduce a **thin hub-side interface**
that `authclient` implements; delete `identitypg` and the account/admin methods entirely
(their handlers move to auth).

```
// identity.Authenticator — the only identity seam the hub keeps.
type Authenticator interface {
    // AuthenticateToken validates a bearer via auth introspection, returning the
    // principal (ID, AccountName, Role, Registrations) plus any sliding-renewal
    // replacement token decided by auth. Any client error ⇒ ErrUnauthenticated.
    AuthenticateToken(ctx, bearer string) (Principal, error)
}
```

- `Principal`: `{ID uuid, AccountName string, Role string, Registrations []string, RenewedToken *string}`.
  No stats/credits — those are player_stats / economy.
- `RequireAuth` (`middleware/auth.go:43`) calls `AuthenticateToken`; `TokenRenewal`
  (`auth.go:75`) relays `Principal.RenewedToken` (auth decides renewal; hub only relays).
- `authclient` caches introspection ~5s (negative 2s), keyed `sha256(bearer)`.
- **Matchmaking** `assembleMatch` (`matchmaking.go:210`) drops `identity.GetByID`; reads
  `account_name` from `player_stats` (all queued players are enrolled).
- **Reroll guard** (`profile.go:106-118`): stats + `IncrementRerollCount` read/write `player_stats`.
- **Delete** `identity.Service`, `identitypg`, and all account/admin methods from the hub.

---

## 3. `player_stats` read model (hub migration 000004)

```
CREATE TABLE player_stats (
    user_id       uuid PRIMARY KEY,           -- auth-owned account id; NO cross-db FK
    account_name  text        NOT NULL,       -- denormalized for leaderboard/history/matchmaking
    deleted_at    timestamptz,                -- denormalized soft-delete (zombie-queue, history, leaderboard scope)
    total_wins    integer     NOT NULL DEFAULT 0,
    total_losses  integer     NOT NULL DEFAULT 0,
    ratio         numeric(8,2) NOT NULL DEFAULT 0,   -- keep serialized as text on the wire (parity)
    reroll_count  integer     NOT NULL DEFAULT 0,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);
-- backfill from the still-present users table (pre Phase-5 drop):
INSERT INTO player_stats (user_id, account_name, deleted_at, total_wins, total_losses, ratio, reroll_count, created_at, updated_at)
SELECT id, account_name, deleted_at, total_wins, total_losses, ratio, reroll_count, created_at, updated_at FROM users;
-- drop the two account FKs (auth owns the account; per-service DBs, no cross-db FK):
ALTER TABLE characters         DROP CONSTRAINT characters_player_id_foreign;
ALTER TABLE match_participants DROP CONSTRAINT match_participants_player_id_foreign;
```
(The economy FKs — credit_transactions/inventory_transactions/player_inventory → users — are
Phase 5's drop, not here.)

**Sync sources for player_stats:** insert @enroll; `account_name`/`deleted_at` upsert via
AccountPush (§5); wins/losses/ratio via the retargeted `UpdatePlayerStats` after a match;
`reroll_count` via reroll.

**SQL retargeting (`JOIN users`/`FROM users`/`UPDATE users` → player_stats), then `sqlc generate`:**
- `games/battle/queries.sql`: `ListParticipantPlayers` (41-45), `UpdatePlayerStats` (47-50, a write),
  `DeleteQueueZombies` (74-79), `AdminMatchHistory` (183-197), `LeaderboardRows` (206-219).
- `platform/character/queries.sql`: `ListCharactersByPlayer` (20-27), `GetCharacterByID` (68-76).
- Re-decide `LeaderboardRows`' deliberate "raw users, bypass soft-delete" semantic against player_stats.
- `economy/queries.sql` `GetUserCreditsForUpdate`/`DebitUserCredits` are rollback-only in-process
  paths (dead when `ECONOMY_INTERNAL_URL` set) — leave for Phase 5, do NOT retarget to player_stats (money ≠ stats).

sqlc v1.31.1 is installed and regenerates the current tree with zero diff — regen is safe.

---

## 4. `POST /api/v1/battle/enroll` (hub, RequireAuth)

Game-owned enrollment; the whole op succeeds or fails together:
1. `character.GenerateInitialRoster(ctx, principal.ID)` (three baseline characters).
2. Insert the `player_stats` row (account_name from principal; zeroed stats).
3. Record `tactical` in auth: `POST /internal/v1/users/:id/registrations` via authclient
   (idempotent; already built auth-side). Failure rolls back 1-2.
Battle endpoints needing a roster gate on enrollment (registrations ride in on introspection,
so `RequireAuth` can check `principal.Registrations` contains `tactical`).

---

## 5. AccountPush (auth → hub, durable)

Auth pushes account lifecycle mutations (create/rename/soft-delete/anonymize) to the hub so
`player_stats`' denormalized `account_name`/`deleted_at` stay correct.
- **Producer (auth):** on account mutation, enqueue a River job → `POST /internal/v1/players/:id/account`
  (wire type `authv1.AccountPush` already defined). Durable, idempotent, request_id carried (ISS-120).
- **Consumer (hub):** `POST /internal/v1/players/:id/account` → upsert `player_stats` identity columns.
  A push for an unknown (not-yet-enrolled) user is a no-op upsert or ignored (enroll creates the row).

---

## 6. Caddy + config + composition

- **Caddyfile:** `/api/v1/auth/*` and `/api/v1/admin/users*` → `auth:8091`; keep `respond /internal/* 404`;
  everything else → hub. Compose: hub `depends_on auth healthy`; add auth URL/token env.
- **config:** add `AuthInternalURL` (env `AUTH_INTERNAL_URL`) + reuse `S2SToken`; crash-early if unpaired.
  Hard cutover — **no** rollback flag (unlike economy's `ECONOMY_INTERNAL_URL==""`).
- **main.go:** add `selectAuth` → `authclient.New(cfg.AuthInternalURL, cfg.S2SToken)`, inject as the
  `identity.Authenticator`; delete `identity.NewPG`. Update matchmaker wiring.

---

## 7. Sequencing & agent decomposition (Sonnet)

Design is locked → fan out. Wave 1 parallel, then Wave 2.

- **Agent A (hub):** migration 000004 (player_stats + backfill + drop 2 FKs), retarget the 7 SQL
  sites, `sqlc generate`, wire the player_stats read model; matchmaking + reroll read player_stats.
- **Agent B (hub):** `authclient` (mirror economyclient) + `identity.Authenticator` interface +
  `Principal`; swap `RequireAuth`/`TokenRenewal`; config `AuthInternalURL` + `selectAuth` in main;
  delete `identitypg` + dead account/admin methods (coordinate deletions with C's handler moves).
- **Agent C (auth + hub):** auth public admin route group (reuse internal admin logic);
  hub `POST /api/v1/battle/enroll`; AccountPush producer (auth River) + consumer (hub internal).
- **Agent D (infra + cli):** Caddyfile + compose deps + env; delete hub account/admin-account
  handlers + routes; upsiloncli register→enroll→play bootstrapBot + scenarios; new edge cases
  (auth-outage 401 parity, economy-outage, award-replay-after-restart).

**Integration (me):** reconcile handler deletions (B/C/D touch overlapping router wiring), boot
the CI stack, verify register→enroll→play end-to-end, then bump pointers. Land ISS-118 before
final prod cutover.
