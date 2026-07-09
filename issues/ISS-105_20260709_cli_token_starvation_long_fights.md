# Issue: CLI scenarios that idle past TokenTTL between requests 401 mid-fight

**ID:** `20260709_cli_token_starvation_long_fights`
**Ref:** `ISS-105`
**Date:** 2026-07-09
**Severity:** Low
**Status:** Open
**Component:** `upsiloncli` (scenario runtime) / `upsilonhub/internal/platform/identity` (sliding renewal)
**Affects:** `e2e_archetype_pve_full_fight` and any scenario whose fight stalls long enough
that the agent makes no HTTP request for > 15 minutes

---

## Summary

Hub tokens have `TokenTTL = 15m` with sliding renewal after 10m
(`identity.go:24-26`): a renewed token is only issued when a request arrives
inside the 10–15 min window. A CLI agent that spends most of a fight listening
on SSE (already authenticated at connect) and only fires HTTP calls when its
turn comes can idle past the TTL between calls — the next call 401s
(`-- DEBUG MODE -- Unauthenticated.`), and every subsequent step including
teardown (`matchmaking_leave`, `game_forfeit`, `auth_delete`) fails too.

Observed 2026-07-09 on the C-gate spot-run: `e2e_archetype_pve_full_fight` ran
~103 min with only 17 HTTP calls on a never-renewed token (enemy units rolled
delays 135/218, stalling the turn cycle). The same scenario passed the A gate
on 2026-07-07 with a faster fight — whether it fires is gameplay-randomness.

Laravel Sanctum tokens never expired (`expiration = null`), so this failure
class is hub-specific; it is a designed-in consequence of the 2026-07-04
opaque-token/sliding-renewal decision, not an auth bug.

## Reproduction

1. Run `e2e_archetype_pve_full_fight` until the archetype roll produces
   high-delay enemies (or artificially pause an agent > 15 min mid-fight).
2. The next `game_action` after the idle gap returns 401.

## Suggested direction

CLI-side keepalive: while a scenario has an active match, ping a cheap
authenticated endpoint (e.g. `GET /api/v1/auth/session`) on a < 10 min timer so
the sliding window always engages — no hub change needed. Alternatively, cap
scenario fight length (assert on stall) so a 100-minute fight fails fast for
the real reason instead of a downstream 401.

## Workaround

Rerun the scenario; short fights pass. Do not raise `TokenTTL` for this — the
15m/10m sliding pair is a locked platform decision.
