# Issue: Jump-Height Rejection Edge Is Structurally Unreachable via E2E

**ID:** `20260710_jump_height_edge_unreachable`
**Ref:** `ISS-109`
**Date:** 2026-07-10
**Severity:** Medium
**Status:** Open
**Component:** `upsilonapi/bridge/bridge_start.go`, `upsilonmapmaker/gridgenerator`
**Affects:** `upsiloncli/tests/scenarios/edge_movement_jump_limitations.js` (EC-07), any E2E test that needs to exercise the `entity.path.notvalid` jump-height rejection edge (`[[mech_move_validation]]` rule 9).

---

## Summary

The jump-height move-validation edge (`entity.path.notvalid`, mechanic rule 9 of `[[mech_move_validation]]`) can never be exercised by an E2E scenario against an API-started `1v1_PVE` match. `bridge_start.go` builds the arena with `gridgenerator.Flat` and a `Height` range of `(2, 3)`, capping the maximum Z-coordinate delta across the entire board at 2. Every API-started character defaults to `JumpHeight = 2` (the bridge never overrides it). Since the check is `|Δheight| > JumpHeight`, the condition can never be true anywhere on the board. Distinct from ISS-108 (~20% flaky): this edge is **0% reachable, on every run, permanently**, not a probability issue.

---

## Technical Description

### Background
`[[mech_move_validation]]` rule 9 (`upsilonbattle/battlearena/ruler/rules/move.go`, inside `preMoveChecks`) rejects a path step when the height delta between consecutive cells exceeds the moving entity's `JumpHeight`, returning `entity.path.notvalid`.

### The Problem Scenario
1. `ArenaBridge.Start` (`upsilonapi/bridge/bridge_start.go`) constructs the `1v1_PVE` grid via `gridgenerator.Flat` with `Height: tools.NewIntRange(2, 3)` — every cell's height sits within a 1-2 unit band.
2. API-started characters are never given an explicit `JumpHeight`; they take the struct default, which is `2`.
3. Because the board's maximum reachable Z-delta between adjacent cells is bounded by the same small range, `|Δheight| > 2` cannot occur.
4. The E2E scenario (`edge_movement_jump_limitations.js`) searches the live board for a qualifying cliff and, finding none, SKIPs every run — confirmed empirically 6/6 executions.

### Secondary defect (assertion design, latent even if reachability were fixed)
The scenario performs a **single-step** move (path length 1, i.e. `i == 0`). Per `move.go` (`:153-155`), a violation at `i == 0` is reported as `entity.path.notadjacent`, not `entity.path.notvalid` — only a violation at `i > 0` (a non-first step in a multi-node path) yields `notvalid`. This is confirmed by the unit test `TestRuleMoveFailNotAdjascentJumpHeight` (`rules_move_extended_test.go:324`), which deliberately uses a 3-node path with the cliff at index 1. So even on a board with a real cliff, a single-step scenario would assert the wrong error key.

### Where This Pattern Exists Today
- `upsilonapi/bridge/bridge_start.go` — `Flat` generator + narrow `Height` range for `1v1_PVE`.
- `upsilonbattle/.../move.go:153-155` — `i==0` vs `i>0` error-key asymmetry.
- `upsiloncli/tests/scenarios/edge_movement_jump_limitations.js` — permanently-SKIP scenario.
- `mech_move_validation.atom.md` rule 9 — implies `entity.path.notvalid` uniformly, doesn't document the `i==0`/`i>0` split.

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | High — affects 100% of runs against the current `1v1_PVE` arena config, not a probability. |
| Impact if triggered | Low (gameplay) / Medium (testability) — jump-height rejection logic is unit-tested but has zero E2E coverage, hiding future regressions in the live request path. |
| Detectability | Medium — the scenario SKIPs cleanly rather than failing, so CI stays green; the gap is silent unless someone reads the log. |
| Current mitigant | None. Rewritten scenario (this audit pass) at least documents the unreachability accurately instead of a misleading "Hill map rarely" comment, but does not fix the gap. |

---

## Recommended Fix

**Short term:** Keep the scenario as a documented, honest SKIP (done in this audit pass) rather than a misleading comment implying occasional reachability. Do not claim E2E coverage of rule 9 in any status report.

**Medium term:** Fix the scenario's assertion design regardless of reachability — use a >=2-node path so a genuine cliff violation lands at `i>0` and asserts `entity.path.notvalid` correctly. Also correct `mech_move_validation.atom.md` rule 9 to document the `i==0` (→`notadjacent`) vs `i>0` (→`notvalid`) split.

**Long term:** Give `1v1_PVE` (or a dedicated test-only mode) a `gridgenerator.Hill`-based arena, or widen the `Height` range beyond default `JumpHeight`, so the jump-height edge is reachable at all via the public match-start API. This pairs with the test-seam direction already recommended in `[[ISS-108]]` / `[[ISS-082]]` for deterministic terrain in E2E.

---

## Extra Data

- Confirmed via 6/6 live runs against the `1v1_PVE` API-started arena: board height variation never exceeds `JumpHeight=2`, so no cliff-qualifying step exists on any generated board.
- `TestRuleMoveFailNotAdjascentJumpHeight` (`rules_move_extended_test.go:324`) is the only test coverage of rule 9; it uses a hand-crafted grid, not anything reachable via the API.

---

## References

- `upsilonbattle/battlearena/ruler/rules/move.go:109` (`@spec-link [[mech_move_validation]]`), `:153-155` (i==0/i>0 split), rule 9 (jump-height check)
- `upsilonapi/bridge/bridge_start.go` (grid config, `1v1_PVE` arena)
- `upsiloncli/tests/scenarios/edge_movement_jump_limitations.js` (permanently-SKIP scenario)
- Related: `[[ISS-108]]` (obstacle-adjacency flakiness, same board-gen/testability family), `[[ISS-082]]` (frontend test seams), `[[ISS-087]]` (grid generator tuning)
