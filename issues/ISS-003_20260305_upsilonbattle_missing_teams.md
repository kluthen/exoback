# Issue: UpsilonBattle missing team handling

**ID:** `20260305_upsilonbattle_missing_teams`
**Ref:** `ISS-003`
**Date:** 2026-03-05
**Severity:** High
**Status:** Open
**Component:** `upsilonbattle/battlearena`
**Affects:** Map Generation, Game Logic, Controllers

---

## Summary

The `upsilonbattle` engine currently lacks any concept of "teams" or alliances. Entities are treated individually and controllers only know about their own entity and "nearest foes". This prevents implementing basic game modes like 2v2 or team-based objectives.

---

## Technical Description

### Background

A battle arena game typically requires entities to be grouped into teams. This affects targeting (friendly vs enemy), win conditions (all enemy teams defeated), and map generation (spawning teams together).

### The Problem Scenario

1. Two players join the game intending to act as a team.
2. The game starts.
3. The engine generates entities and places them on the map randomly or via an unspecified rule.
4. Player A's controller logic attempts to find a target.
5. Because there is no team metadata or alliance system, Player A's controller might target Player B's entity, or the engine cannot enforce team-based targeting rules for skills.

### Where This Pattern Exists Today

- `upsilonbattle/battlearena/entity/entity.go`: No team identifier on the Entity struct.
- `upsilonbattle/battlearena/ruler/ruler.go`: Game state does not track teams.
- `upsilonbattle/battlearena/controller/controllers/aggressive.go`: `selectNearestFoe` targets any entity that is not the controller's own entity.

---

## Risk Assessment

| Factor              | Value                                                |
| ------------------- | ---------------------------------------------------- |
| Likelihood          | High                                                 |
| Impact if triggered | High                                                 |
| Detectability       | High — Players will attack each other in team modes. |
| Current mitigant    | None                                                 |

---

## Recommended Fix

**Short term:** Document the lack of team support as a known limitation for current scenarios.

**Medium term:** Add a `TeamID` to the `Entity` struct or `GameState` to allow basic team-based targeting in rules and controllers.

**Long term:** Implement a formal team/alliance system in the engine rules to govern win conditions, spawn points, and targeting.

---

## References

- `/workspace/upsilonbattle/battlearena/entity/entity.go`
- `/workspace/upsilonbattle/battlearena/ruler/ruler.go`
