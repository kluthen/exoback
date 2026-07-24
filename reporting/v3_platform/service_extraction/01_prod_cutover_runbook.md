# Phase 5 — Production cutover runbook: adopt a single-DB hub into the v3 topology

**Status:** reference procedure — **never executed** (there is no production deployment;
the pre-extraction monolith DB was wiped, see ISS-106). This documents *how* an existing
single-database hub deployment would be split into the extracted per-service topology, and
is the companion to the guarded `scripts/cutover_extraction.sh`. **No step is ever run
against AWS without Bastien** — the script hard-refuses AWS/RDS hosts, but that backstop
does not replace the judgement.

## 0. What this cuts over

From a **single Postgres database** owned by the pre-extraction hub (accounts, tokens,
wallets-as-`users.credits`, shop catalog, inventory, ledger, characters, matches, …) to
**three databases on the same Postgres instance**:

| DB | Owner | Adopts |
|---|---|---|
| `upsilonauth` | upsilonauth | `users`, `personal_access_tokens`, `password_reset_tokens` (+ its own `service_registrations`, populated by enroll, not copied) |
| `upsiloneconomy` | upsiloneconomy | `shop_items`, `player_inventory`, `credit_transactions`, `inventory_transactions`, **wallets seeded from `users.credits`** |
| `upsilon` (hub, slimmed) | upsilonhub | keeps `characters`, `character_*`, `game_matches`, `match_participants`, `matchmaking_queues`, `skill_templates`, `player_stats`; **drops** the seven adopted tables via migration `000005` |

## 1. The ordering invariant (why this is a runbook, not one `psql`)

**Back-fill before drop.** The hub's `player_stats` read model (migration `000004`) and the
economy's wallets are *derived from* `users` (`users.credits`, win/loss counters). The hub
`000005` migration **drops `users`**. So the only safe order is:

1. auth + economy **adopt** their tables (copies — source untouched);
2. economy **seeds wallets** from `users.credits`;
3. hub **confirms `player_stats` is backfilled** (000004 did it on the adopt);
4. **only then** hub `000005` drops `users`/tokens/economy tables.

Run `000005` before step 3 and the derived data is gone with no source to rebuild it from.
This is exactly the failure the ISS-121 fix (`IF NOT EXISTS` + idempotent backfill) and the
`baseline` adopt mode were built to make replay-safe.

## 2. Preconditions

- All three service DBs exist and are migrated to their own heads **first**: `upsilonauth
  -migrate`, `upsiloneconomy -migrate`, and hub `upsilonhub -migrate-mode baseline` up to but
  **not including** `000005` is not possible (migrations run to head) — so instead run hub
  migrations to head on a **copy**, or gate `000005` by running it as the explicit last step
  after verification (the script keeps `000005` in your hands, not in the SQL it auto-runs).
- Same-instance access: the script uses `pg_dump --data-only | psql` between DBs on one
  instance (no cross-network dump). `PGHOST/PGPORT/PGUSER/PGPASSWORD` point at that instance.
- A fresh **full backup / snapshot** of the source DB exists and has been test-restored.
- Traffic is drained (maintenance window) — accounts/wallets must not mutate mid-copy.

## 3. Procedure (mirrors `scripts/cutover_extraction.sh`)

Always **dry-run first** (`scripts/cutover_extraction.sh`, no flag) and read every printed
statement. Then `--execute` (types-`CUTOVER` confirmation) in the window.

1. **Preflight** — confirm the source still has `users`/`shop_items` (else it is already cut
   over; stop).
2. **auth** — `pg_dump --data-only -t users -t personal_access_tokens -t password_reset_tokens
   $SOURCE | psql $AUTH_DB`.
3. **economy tables** — `pg_dump --data-only -t shop_items -t player_inventory
   -t credit_transactions -t inventory_transactions $SOURCE | psql $ECONOMY_DB`.
4. **economy wallets** — seed from `users.credits`. Because wallets are *derived*, this is the
   one transform the script leaves explicit rather than auto-generating, so schema drift can't
   silently mis-seed money. Concretely (adjust to upsiloneconomy's live wallet schema):
   ```sql
   -- inside a psql connected to upsiloneconomy, with users reachable via
   -- postgres_fdw / dblink to the source DB, OR from a (id,credits) export:
   INSERT INTO wallets (user_id, balance)
   SELECT id, credits FROM users
   ON CONFLICT (user_id) DO UPDATE SET balance = EXCLUDED.balance;
   ```
5. **hub backfill check** — `SELECT count(*) FROM player_stats;` must be non-zero and match the
   live account count (000004 backfilled it). Do NOT proceed if it is empty.
6. **hub drop (LAST)** — run the migration binary, not raw SQL: `upsilonhub -migrate-mode
   baseline` (adopted DB) applies `000005`, dropping the seven tables. Kept out of the script
   deliberately so the drop is owned by the tested migration, gated behind your verification.

## 4. Service config after cutover

Each serving hub needs the internal seams set (the hub crash-early's without them —
`config.RequireServe`): `ECONOMY_INTERNAL_URL`, `AUTH_INTERNAL_URL`, `S2S_TOKEN`. Migrate/seed
one-shots need only `DATABASE_URL`. Caddy routes `/api/v1/auth/*` + `/admin/users*` to auth
(Phase 4) and the hub is a client of both seams.

## 5. Verification (before cutting traffic back)

- `upsilonauth`: account count == pre-cutover; a known user can log in; admin can list users.
- `upsiloneconomy`: wallet balances sum == pre-cutover `SUM(users.credits)`; shop catalog and
  a sample inventory row present; an idempotent award is accepted.
- hub `upsilon`: the seven adopted tables are **gone** (`SELECT to_regclass('public.users')` is
  NULL); `player_stats` intact; a full register→login→enroll→play E2E passes end-to-end.

## 6. Rollback

Until `000005` runs, rollback is trivial: the source DB is untouched — point traffic back at
the single-DB hub and discard the new DBs. **After `000005`** the drop is committed; rollback
means restoring the source DB from the step-2 snapshot and re-pointing traffic. There is no
partial rollback of a completed drop — which is why steps 1–5 are all reversible-by-discard and
`000005` is the single irreversible gate, run last, after every check in §3.5 and §5 passes.
