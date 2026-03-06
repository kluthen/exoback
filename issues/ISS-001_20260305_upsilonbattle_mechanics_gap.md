# Issue: UpsilonBattle Mechanics Gap Analysis

**ID:** `20260305_upsilonbattle_mechanics_gap`
**Ref:** `ISS-001`
**Date:** 2026-03-05
**Severity:** Medium
**Status:** Open
**Component:** `upsilonbattle/battlearena`
**Affects:** `upsilonbattle/battlearena/ruler`

---

## Summary

There are multiple inconsistencies between the high-level specifications (README.md) and the current backend implementation (UpsilonBattle) regarding turn timeouts, delay costs, character attributes, and generation rules.

---

## Technical Description

### Background
The README defines the core gameplay rules for UpsilonBattle, including turn timeouts (30s), action delay costs (Move +20/tile, Attack +100), character attributes (10 points total, min 3 HP), and roster assignment.

### The Problem Scenario
A gap analysis reveals the following discrepancies in the `upsilonbattle` backend:
1. **Turn Timeout**: The 30s turn timeout and auto-pass penalty are completely missing from the `Ruler` and `Turner` logic.
2. **Action Delay Costs**: The implementation uses `+200` per tile for Move (instead of `+20`) and `+500` for Attack (instead of `+100`).
3. **Character Attributes & Progression**: The README mandates exactly 10 initial attribute points with a minimum of 3 in HP, with remaining points distributed among Movement, Attack, and Defense. The implementation (`entitygenerator.go`) rolls random attributes out of a specific range (e.g., HP 3-20, Attack 1-5) and includes additional stats like JumpHeight and AttackRange not explicitly defined in the core attributes intro. Level-up (attribute point gain on win) is also not handled in the core game ruler, which is expected as it belongs to the metagame/account system, but the initial distribution violates the constraint.
4. **Character Generation / Roster**: The `Ruler` generates random characters for each controller upon initialization instead of receiving assigned rosters from the matching system.

### Where This Pattern Exists Today
- `upsilonbattle/battlearena/ruler/ruler.go` (generates random characters internally)
- `upsilonbattle/battlearena/entity/entitygenerator/entitygenerator.go` (unbounded random attribute ranges)
- `upsilonbattle/battlearena/ruler/rules/move.go` (delay `+ 200 * path`)
- `upsilonbattle/battlearena/ruler/rules/attack.go` (delay `+ 500`)

---

## Risk Assessment

| Factor              | Value                                              |
| ------------------- | -------------------------------------------------- |
| Likelihood          | High                                               |
| Impact if triggered | Medium                                             |
| Detectability       | High — Obvious mechanics mismatch during gameplay. |
| Current mitigant    | None                                               |

---

## Recommended Fix

* Update delay costs in `move.go` and `attack.go` to match the design (or update the specs if the code is intended). Update `entitygenerator` to respect the 10-point allocation rule.
* Refactor `Ruler` to accept a pre-configured roster (entities) during initialization or `AddController` instead of generating them natively. Implement a turn timeout timer in the `Ruler` state machine (only after the battle has begun of course).
* Decouple entity generation entirely from the battle instance, making `Ruler` strictly an enforcer of combat rules.
  * Still ensure it's possible, as it's practical for testing, to generate random characters for a battle instance.

---

## References

- `README.md`
- `upsilonbattle/battlearena/ruler/ruler.go`
- `upsilonbattle/battlearena/entity/entitygenerator/entitygenerator.go`
- `upsilonbattle/battlearena/ruler/rules/move.go`
- `upsilonbattle/battlearena/ruler/rules/attack.go`
