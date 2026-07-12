# Issue: Board Generation Does Not Guarantee Obstacles Near Spawns

**ID:** `20260710_obstacle_not_adjacent_to_spawn`
**Ref:** `ISS-108`
**Date:** 2026-07-10
**Severity:** Medium
**Status:** Open
**Component:** `upsilonmapmaker/gridgenerator`, `upsilonapi/bridge/bridge_start.go`
**Affects:** `upsiloncli/tests/scenarios/edge_movement_obstacle_collision.js` (EC-01), any E2E test that needs to exercise the `entity.path.obstacle` rejection edge.

---

## Summary

The `entity.path.obstacle` move-validation edge (mechanic #7 of `[[mech_move_validation]]`) can only be exercised by an E2E scenario when an Obstacle cell is orthogonally adjacent to the acting entity's spawn, because a single-step move onto a non-adjacent obstacle is rejected earlier by the adjacency check (`entity.path.notadjacent`). Board generation scatters only 2-8 obstacles uniformly at random over a 7-8 x 7-8 board with no constraint relative to spawn positions, so an obstacle lands adjacent to a given spawn on only ~29% of generated boards. The rewritten EC-01 scenario is therefore correct but flaky.

---

## Technical Description

### Background
`[[mech_move_validation]]` (`upsilonbattle/battlearena/ruler/rules/move.go:151-176`) validates a move path cell-by-cell. The adjacency check (step 5) runs **before** the obstacle/type check (step 7). Consequently the engine emits `entity.path.obstacle` only when the obstacle cell is itself adjacent (within `JumpHeight`, default 2) to the preceding position. For a single-step move from spawn, that means the obstacle must be orthogonally adjacent to the spawn.

### The Problem Scenario
1. `ArenaBridge.Start` (`upsilonapi/bridge/bridge_start.go:61-68`) builds a `Flat` grid, 7-8 x 7-8, `ObstructionRate = NewIntRange(2, 8)`.
2. `generateFlat` (`upsilonmapmaker/gridgenerator/terrain_algorithms.go:53-57`) calls `placeRandomObstacle` `obstruction` times. `placeRandomObstacle` picks a uniformly random `(x, y)` and converts the topmost ground cell there to `cell.Obstacle`.
3. Entity spawn positions are independent of obstacle placement.
4. On a ~49-64 cell board with 2-8 obstacles, the probability that any of a spawn's <=4 orthogonal neighbors is an obstacle is low.

### Empirical Measurement
Ran `edge_movement_obstacle_collision` 9 times against the live hub/api stack (ISS-107 audit):
- GREEN (adjacent obstacle found, `entity.path.obstacle` asserted, position unchanged): **2**
- HARD-FAIL ("No obstacle tile orthogonally adjacent to spawn"): **7**
- Observed hit rate: **~29%**.

When the board does cooperate, the test is provably correct: e.g. spawn (1,3), obstacle (1,2), single-step move rejected with exactly `entity.path.obstacle` ("Invalid path(wrong type)"), position unchanged at (1,3).

### Where This Pattern Exists Today
- `upsilonapi/bridge/bridge_start.go:67` — obstacle density config.
- `upsilonmapmaker/gridgenerator/terrain_algorithms.go:94-104` (`placeRandomObstacle`) — uniform random placement, no spawn awareness.
- `upsiloncli/tests/scenarios/edge_movement_obstacle_collision.js` — the flaky scenario.

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | High — affects the majority of generated 1v1 boards. |
| Impact if triggered | Low (gameplay) / Medium (testability) — gameplay is unaffected; the obstacle-collision edge becomes untestable via E2E on most boards, hiding regressions. |
| Detectability | High — the scenario hard-fails with an explicit FINDING message. |
| Current mitigant | None. The prior version of the scenario masked this by SKIP-and-pass (false green); the ISS-107 rewrite converts that to a hard failure, exposing the gap. |

---

## Recommended Fix

**Short term:** Accept the flakiness as a known limitation and re-run on miss (current state). Document the ~29% hit rate in CI notes.

**Medium term (testability seam):** Allow E2E scenarios to request a deterministic board layout (or a "guaranteed obstacle adjacent to spawn" flag) via the match-start request, so edge-case scenarios can reliably exercise terrain-dependent rules without depending on RNG. This mirrors the test-seam pattern already discussed in `[[ISS-082]]` for the frontend.

**Long term (generation quality):** Make board generation spawn-aware — ensure each spawn has at least one tactical feature (obstacle or elevation change) within Manhattan distance 1-2. This also improves gameplay depth and aligns with `[[ISS-087]]` (grid generator tuning), which proposes raising `ObstructionRate` to `NewIntRange(5, 15)`. Note: raising density improves the odds but still does not *guarantee* adjacency.

---

## Extra Data

- Confirmed production error path: `move.go:170-176` — any path cell whose type is neither `Ground` nor `Dirt` yields `entity.path.obstacle`. The unit test `TestRuleMoveFailObstacle` (`rules_move_extended_test.go:137-163`) verifies this deterministically with a hand-crafted grid.
- Obstacle placement guarantee: `placeRandomObstacle` converts the **topmost ground** cell (`TopMostGroundAt`) to `cell.Obstacle`, so the obstacle is always the topmost cell of its column; the bridge's `TopMostCellAt` projection therefore resolves client `(x,y)` to the obstacle cell. Z-delta to an adjacent spawn is within the Flat board's variation (<= `JumpHeight` 2), so adjacency is satisfied when horizontal adjacency holds.

---

## References

- `upsilonbattle/battlearena/ruler/rules/move.go:109` (`@spec-link [[mech_move_validation]]`), `:151-176` (obstacle check)
- `upsilonapi/bridge/bridge_start.go:61-68` (grid config)
- `upsilonmapmaker/gridgenerator/terrain_algorithms.go:53-57`, `:94-104` (obstacle placement)
- `upsiloncli/tests/scenarios/edge_movement_obstacle_collision.js` (flaky scenario)
- Related: `[[ISS-087]]` (grid generator tuning), `[[ISS-082]]` (frontend test seams), `[[ISS-079]]` (cell access standard)
