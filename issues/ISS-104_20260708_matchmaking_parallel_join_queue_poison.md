# Issue: Parallel joins can strand a queue entry that then poisons every later 1v1_PVE join

**ID:** `20260708_matchmaking_parallel_join_queue_poison`
**Ref:** `ISS-104`
**Date:** 2026-07-08
**Severity:** High
**Status:** Open
**Component:** `upsilonhub/internal/games/battle/matchmaking.go` (`Join` / `QueueHead`)
**Affects:** Playwright `battle_arena.spec.ts` / `battle_debug.spec.ts` when run with parallel workers; any two humans joining the same mode near-simultaneously

---

## Summary

`Matchmaker.Join` enqueues the joiner, then takes `QueueHead(scope, required)`
— the scope's FIFO head — and creates the match for *those* entries. Two joins
racing on the same mode can both read the same head entry: the loser creates a
second match for a user who already got one, deletes the already-consumed head
entry, and leaves **its own entry stranded in the queue**. The loser is told
`matched` with a `match_id` it is not a participant of, so every
`GET /api/v1/game/{id}` answers 403 ("This action is unauthorized.") and the
SPA lands on TACTICAL LINK FAILURE.

Worse, the strand **self-perpetuates**: with `required=1` (1v1_PVE), every
subsequent joiner finds the stranded entry at the head, creates a match for
the *previous* victim, and strands its own entry in turn. One race poisons the
mode's queue indefinitely (observed chain on the dev stack 2026-07-08:
`pve_debug_…` → `repro_…` → `curl_repro_…`, each match's sole participant
being the previous joiner).

The FIFO logic is a straight port of Laravel's `MatchMakingController`, so the
race predates the migration — it is the "pre-existing arena race" noted in the
Phase 6 §A gate report. The hub's lower latency (in-process bus, no Reverb
round-trip) and Playwright's parallel workers make it fire far more often.

## Reproduction

1. Clean `matchmaking_queues`.
2. Two clients POST `/api/v1/matchmaking/join` (`1v1_PVE`) concurrently until
   one receives `matched` with a `match_id` whose `match_participants` row
   names the other user (or, once poisoned, any single join reproduces the
   shifted-by-one pairing).
3. `GET /api/v1/game/{match_id}` as the victim → 403.

Dev-stack cleanup: delete the stranded `matchmaking_queues` row(s).

## Suggested direction

After `QueueHead`, require the joiner's own entry to be part of the consumed
head set before creating a match (else report `queued`); or make
enqueue+head+consume one serialized transaction per scope
(`SELECT … FOR UPDATE SKIP LOCKED`). Either also breaks the poison chain,
since a stranded entry can then only be consumed by a match that includes it.

## Workaround

Run Playwright arena specs with `--workers=1`; clear `matchmaking_queues`
if a run aborted mid-join.
