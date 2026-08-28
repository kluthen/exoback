# Issue: No scenario positively asserts that a melee attack lands and deals damage

**ID:** `20260827_no_positive_melee_attack_damage_coverage`
**Ref:** `ISS-141`
**Date:** 2026-08-27
**Severity:** Medium
**Status:** Resolved
**Component:** `upsiloncli/tests/scenarios` (E2E scenario suite)
**Affects:** `upsilonbattle/battlearena` melee attack path, `upsilonapi/bridge` `type: "attack"` action handling —
any regression in basic melee damage would ship undetected by the suite

---

## Summary

After `e2e_credit_economy.js` was converted (2026-08-27) from walk-and-melee to an equipped
long-range skill, **no scenario in the suite asserts that a `type: "attack"` melee action
actually lands and deals damage.** Every remaining `edge_attack_*` scenario asserts a
*rejection* (out of range, no entity, wrong controller, already acted, friendly fire); the two
positive-path fight scenarios assert only that rounds were played. A regression that made
melee deal zero damage — or be silently rejected — would leave the suite fully green.

This is a coverage gap opened by an otherwise-correct change, not a defect in the engine. It is
filed separately because closing it properly is more involved than it looks: reliably reaching
melee adjacency is exactly the thing that made `e2e_credit_economy` flaky in the first place.

---

## Technical Description

### Background

`e2e_credit_economy.js` used to walk a character toward a foe over up to 80 rounds and melee-attack
on adjacency, then assert `myDamageDealt > 0`. It incidentally carried the suite's only positive
melee assertion. Its actual purpose is narrower — *damage dealt ⇒ credits earned* — and that
purpose does not require melee. It was hardened to grant every team member a long-range Fireball
via an equipped item so that damage infliction no longer depends on spawn distance or enemy
composition. The credit assertions are unchanged and the scenario now passes consistently
(5/5 consecutive runs). **That change is correct and should stand.**

### The Problem Scenario

Grep for a positive damage assertion across the whole scenario suite:

```
upsiloncli/tests/scenarios/e2e_credit_economy.js:220
    upsilon.assert(myDamageDealt > 0, "Attack landed but no damage was reported (defense too high?)");
```

That is the only hit — and it is now satisfied by a `type: "skill"` cast, not `type: "attack"`.

What the suite still covers:

| Capability | Covered? | Where |
|---|---|---|
| Movement succeeds (reach a target tile) | **Yes** | `e2e_friendly_fire_prevention.js:95` — asserts an ally was reached within 3 matches |
| Movement rejections (range, obstacle, boundary, collision, jump, wrong controller) | Yes | the `edge_movement_*` family |
| Melee attack rejections (out of range, no entity, wrong controller, already acted, friendly fire) | Yes | the `edge_attack_*` family |
| Skill cast lands and deals damage | Yes | `e2e_credit_economy.js` (as of this change) |
| **Melee attack lands and deals damage** | **No** | — nothing |

The user's expectation that movement is independently covered is correct — `e2e_friendly_fire_prevention`
carries it. Only the melee-damage half is missing.

### Why this is harder than adding one assertion

The gap cannot be closed by asserting inside an existing edge scenario, because reaching melee
adjacency is itself unreliable:

- Board width/height are each rolled 5..15 tiles (`mech_board_generation.atom.md`), so spawn
  separation varies widely. During the hardening work, melee adjacency was reached in only
  **1 of 5** runs within the 80-round budget.
- `edge_movement_already_attacked` is **already quarantined** under ISS-110 for precisely this
  reason — *"probe requires surviving enough turns to reach adjacency (~20% flaky)"*
  (`upsiloncli/tests/run_all_edge_cases.sh:38-39`).
- `edge_attack_target_out_of_grid` is quarantined under the same ISS-110 PVE-initiative RNG.

So a naive "walk up and hit it" melee scenario would reproduce the flake that motivated the
`e2e_credit_economy` change. The fix needs a deterministic way to establish adjacency.

### Where This Pattern Exists Today

- `upsiloncli/tests/scenarios/e2e_credit_economy.js:147-214` — the melee branch still exists as a
  fallback but is no longer reached in the common case, and `meleeReachAchieved` is logged as a
  diagnostic only, never asserted
- `upsiloncli/tests/scenarios/e2e_archetype_pve_full_fight.js:44` — asserts `round > 0` only
- `upsiloncli/tests/scenarios/e2e_combat_turn_management.js` — no assertions on damage
- `upsiloncli/tests/run_all_edge_cases.sh:33-43` — the quarantine list showing two
  adjacency-dependent scenarios already parked under ISS-110

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | **Low** — the melee path is long-standing and stable; this is about detection, not a live defect |
| Impact if triggered | **High** — melee is the baseline combat action; a silent regression there is a broken game with a green suite |
| Detectability | **Low** — by construction, nothing in the suite would go red. It would surface as a player/manual-test report |
| Current mitigant | Engine-level unit tests in `upsilonbattle/battlearena/property/effect/effectapplicator/effectapplicator_damaging_test.go` cover damage math directly, but not the end-to-end `type: "attack"` action path through the bridge |

---

## Recommended Fix

**Short term:**
Add a dedicated `e2e_melee_attack_damage.js` scenario asserting the full melee path:
action accepted → `results[].damage > 0` → target `new_hp` decreased by that amount. Keep it
separate from `e2e_credit_economy` so the two concerns (melee mechanics vs. credit accounting)
fail independently and name their own cause.

**Medium term:**
Give the scenario a deterministic path to adjacency rather than hoping the board cooperates —
options, in rough order of preference:
1. A test-only admin seam to place entities at chosen coordinates before the first turn (this
   would also un-quarantine `edge_movement_already_attacked` and `edge_attack_target_out_of_grid`
   under ISS-110). Must live behind an admin/test boundary, not a branch in production code
   (CODING_RULE §5: no test-only branches in production).
2. A bounded-dimension board request at match creation, so spawn separation is known.
3. Failing both, a reposition skill (`RepositionSubject` / `RepositionDistance` exist in the
   property enum) to close distance in one action instead of walking.

**Long term:**
Resolve ISS-110 (PVE AI initiative RNG wiping the squad before the player's turn), which is the
shared root cause behind both quarantined adjacency scenarios and any new melee scenario's
flakiness. Deterministic adjacency plus deterministic initiative would let all three be gating.

---

## Extra Data

Identified 2026-08-27 during review of the `e2e_credit_economy.js` hardening. The concern was
raised before the change landed and explicitly adjudicated by the user: melee reach is **not**
required by that scenario, whose contract is *damage dealt ⇒ credits earned*. The `meleeReachAchieved`
diagnostic was kept in the scenario so the loss of incidental coverage is visible in its log
rather than invisible.

Diagnostic observed during hardening: melee adjacency reached in 1 of 5 runs (80-round budget).

---

## References

- `upsiloncli/tests/scenarios/e2e_credit_economy.js` — the scenario that formerly carried this coverage
- `upsiloncli/tests/scenarios/e2e_friendly_fire_prevention.js:95` — the surviving positive movement assertion
- `upsiloncli/tests/run_all_edge_cases.sh:33-43` — quarantine list (ISS-110 adjacency flakes)
- `upsilonbattle/battlearena/property/effect/effectapplicator/effectapplicator_damaging_test.go` — engine-level damage coverage that does not exercise the action path
- `issues/ISS-110*` — PVE AI initiative RNG, shared root cause of the adjacency flakiness
- `docs`/`mech_board_generation.atom.md` — randomized board dimensions (5..15 per axis)

---

## Change Log
- **2026-08-27**: **Resolved.** Added `upsiloncli/tests/scenarios/e2e_melee_attack_damage.js`
  (carries `@test-link [[mech_combat_attack_computation]]`). Determinism achieved with a single
  "Overkill Kit" utility-slot fixture item — `properties_json: {Movement: 10, HP: 200, Attack: 1000}`
  — granted per character via `admin_shop_item_create` -> `shop_purchase` -> `character_equip`.
  Movement +10 (13 tiles/turn vs a 30-tile worst-case gap) removed the adjacency flakiness that
  motivated this issue: adjacency was reached within 1-2 of the bot's own turns on every run,
  never the 1-in-5 previously observed.

  **Assertion strengthened during scoping.** `attack.go:74` floors damage at
  `tools.Max(1, ...)`, so the originally-proposed `damage > 0` would have been nearly vacuous — a
  regression breaking the `totalAttack` computation would still report 1 and pass. The scenario
  asserts `damage > 500` instead, which only a real Attack of ~1000 flowing through the formula can
  produce. Nothing is asserted on `prev_hp`/`new_hp`; lethal hits are a valid pass (damage is
  populated into the `ActionResult` before the `foeHP <= 0` removal branch), and they are logged as
  diagnostics only.

  **Verification:** 5/5 consecutive passes by the implementer, plus 3/3 independently reproduced
  (damage 995 / 1010 / 1000). Observed magnitudes of ~1000 and ~1510 correspond to normal and
  backstab (1.5x) hits respectively, consistent with the documented formula.

  Not addressed here (deliberately out of scope): the ISS-110 quarantine of
  `edge_movement_already_attacked` and `edge_attack_target_out_of_grid` remains untouched, though
  the same fixture-item technique would likely un-quarantine both.
