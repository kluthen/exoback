# Issue: Map Generation ignores specifications

**ID:** `20260305_upsilonbattle_mapgen_ignores_spec`
**Ref:** `ISS-004`
**Date:** 2026-03-05
**Severity:** Medium
**Status:** Resolved
**Component:** `upsilonbattle/battlearena/ruler`
**Affects:** Map Generation

---

## Summary

In `upsilonbattle/battlearena/ruler.go`, the `NewRuler` function hardcodes the grid generator configuration (`gg.Width`, `gg.Length`, `gg.Height`, `gg.Type`), ignoring any external map generation specifications or rules.

---

## Technical Description

### Background

The battle arena requires a map (grid) to play on. The dimensions, obstruction rate, and type of the map should Ideally be configurable based on game modes, player count, or specific scenario specifications.

### The Problem Scenario

1. A new battle is initialized by calling `ruler.NewRuler()`.
2. The grid generator is instantiated and configured with hardcoded values (e.g., `Width = tools.NewIntRange(20, 50)`, `Type = gridgenerator.Flat`).
3. The map is generated using these hardcoded values, regardless of what the intended map size or type should be for the specific match.

### Where This Pattern Exists Today

- `upsilonbattle/battlearena/ruler/ruler.go`: Lines 68-76 in `NewRuler()`.

```go
	gg := gridgenerator.GridGenerator{}
	gg.Width = tools.NewIntRange(20, 50)
	gg.Length = tools.NewIntRange(20, 50)
	gg.Height = tools.NewIntRange(10, 15)
	gg.GenerateObstrcution = false
	gg.Type = gridgenerator.Flat
	gg.ObstructionRate = tools.NewIntRange(0, 0)

	r.GameState.Grid = gg.Generate()
```

---

## Risk Assessment

| Factor              | Value                                                             |
| ------------------- | ----------------------------------------------------------------- |
| Likelihood          | High (Always happens on every new battle)                         |
| Impact if triggered | Medium (Restricts gameplay variety and prevents custom scenarios) |
| Detectability       | High (Maps are always flat and within the hardcoded size ranges)  |
| Current mitigant    | None                                                              |

---

## Recommended Fix

**Short term:** Add a TODO comment acknowledging the hardcoded values.

**Medium term:** Update `NewRuler` to accept a map configuration or specification object as an argument, and use that to configure the `GridGenerator`.

**Long term:** Implement a robust map specification system that integrates seamlessly with the ruler and supports diverse terrain types, obstructions, and spawn zones.

---

## References

---

## Change Log

- **2026-03-09**: Marked as resolved per user request. The `NewRuler` and `SetGrid` methods now allow for external grid configuration, addressing the core issue of hardcoded map generation in `NewCompleteRuler`.

