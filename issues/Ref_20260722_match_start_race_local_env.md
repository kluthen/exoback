# Issue: Five match-resolution E2E scenarios race engine game-start and fail on dev machines

**ID:** `20260722_match_start_race_local_env`
**Ref:** `ISS-119`
**Date:** 2026-07-22
**Severity:** Low
**Status:** Open
**Component:** `upsiloncli/tests/scenarios/` (match-resolution family)
**Affects:** `e2e_battle_starts_privacy_check`, `e2e_match_resolution_forfeit`, `e2e_match_resolution_standard_with_2`, `e2e_progression_post_win_with_2`, `e2e_progression_constraints_with_2` (Bot-02, the loser, forfeits immediately after `match.found` → `game_forfeit: Game is not in progress`; surfaced in the 2026-07-23 Phase-4 E2E run); local full-suite runs

---

## Summary

The four scenarios act on a match immediately after the SSE `match.found` event. The engine's game-start (actor transition + `game.started` webhook) is asynchronous relative to `match.found`, so an immediate `game_forfeit`/action can hit the engine inside the not-yet-in-progress window and get `game.not.in.progress`. On GitHub CI runners the window has never been observed (suite green through 2026-07-20); on Bastien's dev machine the four scenarios fail **deterministically** — verified 2026-07-22 against both the current tree and a pristine pre-session worktree (`d59984b`), which rules out the v3-extraction changes as the cause.

---

## Technical Description

### Background

`upsilon.joinWaitMatch()` resolves on SSE `match.found` (bridge_battle.go:365). The scenarios then immediately call `game_forfeit` (or an action). The hub proxies to the engine; the engine's Ruler actor rejects with "Game is not in progress" if the start transition hasn't landed.

### The Problem Scenario

```
CLI                    hub                     engine
 |---- join ---------->|                        |
 |<== SSE match.found ==|---- start arena ----->|   (async)
 |---- forfeit -------->|---- forfeit --------->|  actor not yet in progress
 |<---- 400 game.not.in.progress ---------------|
 |                      |<=== game.started webhook (same second) ===|
```

Engine log (2026-07-22 14:14:43): `ControllerForfeit → "Game is not in progress"` followed by `forwardToWebhook for game.started` in the same second.

### Where This Pattern Exists Today

- `upsiloncli/tests/scenarios/e2e_match_resolution_forfeit.js:16` (forfeit straight after `joinWaitMatch`); same shape in the other three.
- The CLI already has a game-start wait primitive: `WaitForAnyData(..., "game.started", ...)` (`upsiloncli/internal/script/bridge_battle.go:424`) — just not used by these scenarios.
- Related but distinct: ISS-106 (hub `Join` answers `matched` even when engine-start *fails*).

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | High on dev machines, unobserved on CI runners |
| Impact if triggered | Low — test noise only; production clients act on user time scales |
| Detectability | High — consistent, clearly logged |
| Current mitigant | CI (the merge gate) is unaffected |

---

## Recommended Fix

**Short term:** Treat these four as known-red on local full-suite runs; CI remains the arbiter.

**Medium term:** Make the scenarios wait for `game.started` (the existing `WaitForAnyData` bridge) before acting — that is also the more faithful customer journey (a real client sees the board render first).

**Long term:** Close the seam itself: the hub should not report/relay a match as actionable until the engine has confirmed start (ties into ISS-106's join-vs-engine-start gap).

---

## Extra Data

Discriminating experiment (2026-07-22): full stack from pre-session commit `d59984b` in an isolated worktree/compose project failed identically → not caused by the upsilonplatform kit refactor, dependency unification, or the extraction wiring.

---

## References

- `upsiloncli/tests/scenarios/e2e_match_resolution_forfeit.js`
- `upsiloncli/internal/script/bridge_battle.go` (lines 365, 424)
- `issues/ISS-106_20260709_php_empty_array_skill_payload_start_failure.md`
