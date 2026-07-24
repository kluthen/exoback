# Issue: Migration 000004_player_stats is not idempotent — breaks database.Baseline() against an already-migrated DB

**ID:** `20260723_baseline_player_stats_not_idempotent`
**Ref:** `ISS-121`
**Date:** 2026-07-23
**Severity:** High
**Status:** Resolved (2026-07-23)
**Component:** `upsilonhub/db/migrations/000004_player_stats.up.sql`
**Affects:** `upsilonhub/internal/testutil/schema_test.go` (`TestBaselineAdoptsLaravelMigratedDatabase`), `upsilonplatform/database.Baseline`, any real Phase 4 cutover run against a database that already has `player_stats` (a retried/re-run deploy job, or a Laravel-baselined prod DB migrated a second time)

---

## Summary

`db/migrations/000004_player_stats.up.sql` issues a bare `CREATE TABLE public.player_stats (...)` with no `IF NOT EXISTS` guard. `database.Baseline()` (used both by the harness and by real deploys) stamps an already-schema'd database at version 1 and then reapplies every migration newer than that from scratch, on the assumption each one is idempotent — 000002 and 000003 hold up that assumption (their DDL uses `IF EXISTS`/`IF NOT EXISTS`), but 000004 does not, so baseline fails outright with `pq: relation "player_stats" already exists` on any database where the table is already present. This currently fails `internal/testutil/schema_test.go`'s `TestBaselineAdoptsLaravelMigratedDatabase` and would identically break a real Phase 4 cutover re-run (e.g. a retried deploy job) against a database that already carries the Phase 4 schema.

---

## Technical Description

### Background

`database.Baseline(url, db.Migrations, "migrations")` is the strangler-pattern adoption path: point it at a database Laravel already migrated (no `schema_migrations` ledger), and it stamps the ledger at version 1 (000001's blueprint = the Laravel schema) then walks forward applying every migration after that. It is also expected to be a safe no-op when run a second time against a database that is already fully migrated — the harness test exercises exactly this by calling `Baseline` twice in a row.

### The Problem Scenario

1. `testutil.StartPostgres(t)` migrates a fresh container all the way to the newest version (currently 000001–000004), so `player_stats` already exists.
2. The test drops only the `schema_migrations` ledger table, to simulate "Laravel ran the schema, golang-migrate has never seen it" — every other table, including `player_stats`, is left in place.
3. `database.Baseline(...)` stamps version 1 and replays 000002 → 000003 → 000004:
   - 000002/000003: idempotent (`IF EXISTS`/`IF NOT EXISTS`), succeed as no-ops.
   - 000004: `CREATE TABLE public.player_stats (...)` — no guard — fails:
     ```
     migration failed: relation "player_stats" already exists ... (details: pq: relation "player_stats" already exists)
     ```
4. Real-world equivalent: a Phase 4 cutover deploy job that runs `Baseline` and is retried (e.g. after an unrelated failure later in the same rollout) against a database where `player_stats` already landed on the first attempt — same failure, same blast radius (deploy job hard-fails instead of no-op'ing).

### Where This Pattern Exists Today

- `db/migrations/000004_player_stats.up.sql:8` — `CREATE TABLE public.player_stats (...)` with no `IF NOT EXISTS`.
- Contrast: the same file's own `ALTER TABLE ... DROP CONSTRAINT IF EXISTS ...` (lines ~30-33) *is* written idempotently — the inconsistency is local to this one file.
- `internal/testutil/schema_test.go:77` — `assert.Equal(t, 3, version, ...)` is now stale on top of the functional bug: with 000004 added there are 4 migrations, so once the `CREATE TABLE` is fixed to be idempotent, baseline over a fully-migrated DB lands at version **4**, not 3. The test's own comment ("apply everything newer") should be re-read against the current migration count when this is fixed.

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | Medium — only triggers when `Baseline` runs against a DB that already has `player_stats` (a re-run/retry of the same deploy, or the harness's own baseline test); a first-ever baseline against a genuinely untouched Laravel DB is unaffected. |
| Impact if triggered | High — the deploy/adoption job hard-fails instead of no-op'ing, blocking the Phase 4 cutover rollout path. |
| Detectability | High — fails loudly and immediately (`pq: relation "player_stats" already exists`); already caught by `TestBaselineAdoptsLaravelMigratedDatabase`. |
| Current mitigant | None in the migration itself. The failure is at least caught by CI via the existing schema test rather than surfacing only in a live cutover. |

---

## Recommended Fix

**Short term:** Change `db/migrations/000004_player_stats.up.sql`'s `CREATE TABLE public.player_stats` to `CREATE TABLE IF NOT EXISTS public.player_stats`, and guard the backfill `INSERT ... SELECT ... FROM public.users` so a second run doesn't re-insert/duplicate rows already backfilled (e.g. `INSERT ... ON CONFLICT (user_id) DO NOTHING`, mirroring the `CreatePlayerStats` sqlc query's own idempotency pattern in `internal/platform/playerstats/queries.sql`). Update `TestBaselineAdoptsLaravelMigratedDatabase`'s expected version from `3` to `4` to match the current migration count.

**Medium term:** Add a lint/CI check (or a code-health rule) that every `db/migrations/*.up.sql` file's DDL statements are idempotent (`IF NOT EXISTS` / `IF EXISTS` / `ON CONFLICT`), so this class of regression is caught at migration-authoring time rather than by a single targeted test.

**Long term:** Consider whether `database.Baseline`'s "replay everything newer, assume idempotent" contract should be made explicit and enforced (e.g. a small self-check that dry-runs each migration's DDL against `information_schema` before executing), rather than relying on migration authors remembering the convention.

---

## Extra Data

Reproduced on the `phase4-player-stats` branch. Confirmed pre-existing and **not** introduced by the Phase 4 gateway-test-harness session that discovered it: `git stash` (removing that session's `internal/gateway/*_test.go`/`enroll.go` changes) and re-running `go test ./internal/testutil/... -run TestBaselineAdoptsLaravelMigratedDatabase` reproduces the identical failure against the unmodified production migration.

```
go test ./internal/testutil/... -run TestBaselineAdoptsLaravelMigratedDatabase -v
--- FAIL: TestBaselineAdoptsLaravelMigratedDatabase (1.39s)
    schema_test.go:71:
        Error: Received unexpected error:
               migration failed: relation "player_stats" already exists in line 0: ...
               (details: pq: relation "player_stats" already exists)
```

The `internal/gateway/...` and `internal/games/battle/...` suites are unaffected and green (`go test ./...` shows this as the only failing package).

---

## Resolution (2026-07-23)

Applied the short-term fix on branch `phase4-player-stats`:
- `000004_player_stats.up.sql`: `CREATE TABLE` → `CREATE TABLE IF NOT EXISTS`, and the backfill `INSERT ... SELECT ... FROM public.users` now carries `ON CONFLICT (user_id) DO NOTHING` (mirrors the `CreatePlayerStats` sqlc idempotency).
- `internal/testutil/schema_test.go`: both post-baseline version assertions updated `3` → `4` (000004 is now the newest migration).
- `TestBaselineAdoptsLaravelMigratedDatabase` passes; full `go test ./...` green.

Medium/long-term recommendations (a migration-idempotency lint, and an explicit `Baseline` replay contract) remain open as future hardening — not tracked by this issue.

## References

- `db/migrations/000004_player_stats.up.sql`
- `db/migrations/000004_player_stats.down.sql`
- `internal/testutil/schema_test.go`
- `internal/platform/playerstats/queries.sql` (the `ON CONFLICT DO NOTHING` pattern this fix should mirror)
- hub migration `000004_player_stats` (the player_stats backfill this fix makes idempotent)
