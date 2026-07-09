# Issue: Forfeit rejected in the engine's startup window right after match.found

**ID:** `20260707_forfeit_before_engine_start_window`
**Ref:** `ISS-102`
**Date:** 2026-07-07
**Severity:** Medium
**Status:** Open
**Component:** `upsilonapi` (arena lifecycle) / `upsilonhub/internal/games/battle/matchmaking.go`
**Affects:** `upsiloncli` battle scenarios (`e2e_match_resolution_forfeit`, `e2e_match_resolution_standard_with_2`, `e2e_progression_constraints_with_2`, `e2e_progression_post_win_with_2`), any SPA client forfeiting immediately after `match.found`

---

## Summary

Between arena creation and the engine's first tick, the arena is not yet "in
progress" engine-side, so `POST /game/{id}/forfeit` bounces with 400
`game.not.in.progress`. The window existed under Laravel but was hidden by
Reverb's broadcast latency (tens of ms). The hub publishes `match.found` on the
in-process bus straight onto the SSE stream, so a client can now forfeit ~2ms
after learning about the match — inside the window. Three e2e scenarios that
"forfeit immediately" fail through the hub for this reason; none of it is a
gateway logic bug (both Laravel and the hub delegate the forfeit guard to the
engine unchanged).

---

## Technical Description

### Background

Matchmaking (`Matchmaker.Join`) creates the match on the engine synchronously
(`CreateMatch`), then publishes `MatchFound` on the bus; the SSE edge delivers
it to the participants. Forfeit is a pure engine passthrough: the gateway
authorizes participants and forwards to `POST /v1/arena/{id}/forfeit`; the
engine only accepts it once the game is in progress (i.e. after its game loop
has started, around the `game.started` event).

### The Problem Scenario

```
hub                      engine                    upsiloncli
───                      ──────                    ──────────
CreateMatch ───────────► arena created (not yet
                         "in progress")
publish MatchFound
  └─► SSE match.found ─────────────────────────► received (t+0ms)
                                                 GET /game/{id}   (t+1ms)
                                                 POST forfeit ──► (t+2ms)
                         400 game.not.in.progress ◄──────────────
                         first tick / game.started (t+X ms)
                         ... forfeit would now succeed
```

Observed 2026-07-07 in the Phase 6 sub-phase A gates (upsiloncli through the
:8085 proxy): `e2e_match_resolution_forfeit` forfeits 2ms after `match.found`
and gets the 400. In `e2e_match_resolution_standard_with_2` the rejected
forfeit cascades: the match runs its idle course and `game.ended` lands 14ms
after the scenario's 10s stats-poll deadline ("Loser never recorded a loss").

### Where This Pattern Exists Today

- `upsilonhub/internal/games/battle/matchmaking.go:172-191` — CreateMatch then
  Bus.Publish(MatchFound); no wait for engine start (Laravel did the same).
- `upsilonhub/internal/gateway/game.go:156-187` — forfeit passthrough, engine
  decides (port of `GameController::forfeit`).
- `upsiloncli/tests/scenarios/e2e_match_resolution_forfeit.js` — "Forfeit
  immediately" right after `joinWaitMatch`.

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | High for scripted clients (CLI bots); Low for humans (UI reaction time exceeds the window) |
| Impact if triggered | Medium — forfeit 400s, match continues; client can simply retry |
| Detectability | High — enveloped 400 with `error_key: game.not.in.progress` |
| Current mitigant | None; scenarios that wait for a first turn event never hit it |

---

## Recommended Fix

**Short term:** In the three scenarios, retry the forfeit on
`game.not.in.progress` for a bounded window (~2s), mirroring what a human
retry does. Keeps the "forfeit immediately" intent while tolerating the
engine's startup tick.

**Medium term:** Engine accepts forfeit from arena creation onward (a player
abandoning during setup is a legitimate forfeit), emitting `game.ended`
directly.

**Long term:** Define the arena lifecycle contract (created → starting →
in_progress → concluded) in an ATD atom with the allowed action set per state,
so gateway and clients can reason about the window explicitly.

---

## Extra Data

- A/B evidence: same scenarios against Laravel-direct (:8000, pre-migration
  CLI from git HEAD) accepted the forfeit — the window is masked by Reverb
  latency, not absent.
- The hub run's failures are timing-only: hub forfeit handler, stats
  resolution (`resolveMatch`) and envelope passthrough all match the PHP
  behavior line for line.

---

## References

- `upsilonhub/internal/games/battle/matchmaking.go`
- `upsilonhub/internal/gateway/game.go`
- `upsiloncli/tests/scenarios/e2e_match_resolution_forfeit.js`
- `upsiloncli/tests/logs/e2e_match_resolution_forfeit.log` (2026-07-07 run)
- Related: ISS-101 (fast engine AI auto-pass behavior)
