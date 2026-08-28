# Issue: Shield-specific buff semantics are deferred — Shield is treated as a plain resource for now

**ID:** ISS-146_20260827_shield_specific_buff_semantics_deferred
**Ref:** ISS-146
**Date:** 2026-08-27
**Severity:** Medium
**Status:** Open
**Component:** `upsilonbattle/battlearena/property/effect/effectapplicator/effectapplicator.go`
**Affects:**
- `upsilonbattle/battlearena/ruler/rules/attack.go:77-89` (shield absorption in the melee path)
- `upsilontypes/property/propertyenum.go:45` (`Shield`, and its overshield/cap note)
- `issues/ISS-142` — buffable set; Shield is included there with plain-resource semantics
- `issues/ISS-144` — Shield is in the write-back fix's affected set, treated as any other resource

---

## Summary

`Shield` is a resource-like counter with mechanics none of the other resources have: it absorbs
damage ahead of HP, it supports *overshield*, and it is capped at twice max HP. Making it buffable
raises questions those mechanics do not currently answer.

**Deliberate decision (user, 2026-08-27):** do not answer them yet. For ISS-142 and ISS-144, Shield
is treated as **any other resource** — no special-casing. This issue records the deferred
Shield-specific work so it is not silently lost.

This is a deferral record, not a defect report. Nothing is broken today by leaving it open.

---

## Problem Scenario

Shield's declared behaviour (`propertyenum.go:45`):

> `(counters) Absence means 0,0, can have overshield (when applied through healing and buffs...)
> Max shield is only used at initialisation of battle. Allowed to twice HP Max`

The existing mechanics, none of which are shared by `HP`/`SP`/`MP`:

1. **Cap at 2x max HP** — `effectapplicator.go:249`:
   ```go
   target.UpdatePropertyValue(property.Shield, tools.Min(shield+shieldPower, maxhp*2))
   ```
2. **Absorption before HP** — `attack.go:77-89` and `effectapplicator.go:176`; shield is consumed
   ahead of health rather than being a stat that is read.
3. **Overshield** — explicitly contemplated by the enum comment, and explicitly attributed to
   "healing and buffs", i.e. exactly the path ISS-142 is about to build.
4. **Max is init-only** — "Max shield is only used at initialisation of battle", unlike the other
   resources whose max is live.

Open questions this raises once Shield becomes buffable:

- Does a buff to **max Shield** raise the `2 x maxHP` cap, or is the cap absolute?
- Does a buff to **max HP** (already in the buffable set) transitively raise the Shield cap, since
  the cap is expressed in terms of max HP?
- Does a **current-Shield** buff mean per-turn shield regeneration, by the same rule as HP/SP/MP? Or
  is a regenerating shield a different game-design proposition than a regenerating resource?
- How does overshield interact with the "max is init-only" rule when a buff changes max mid-match?

---

## Risk Assessment

Low while the deferral holds: treating Shield as a plain resource is coherent and self-consistent,
and the questions above only become live if someone tries to special-case it. The risk is purely
that the deferral is forgotten and one of the questions gets answered by accident, in code, without
a decision — which is what this issue exists to prevent.

---

## Recommended Fix

**Short term.** None — the deferral is the decision. Ensure ISS-142 and ISS-144 treat Shield exactly
as `HP`/`SP`/`MP` with no Shield-specific branch, and that no implementer quietly invents cap or
overshield behaviour along the way.

**Medium term.** Settle the four questions above as a design decision before any Shield-specific
buff behaviour is written, and capture the outcome as an ATD atom — the cap and absorption rules are
mechanics, and `mech_combat_shielding` already exists as their likely home.

---

## References

- `upsilontypes/property/propertyenum.go:45` — `Shield` declaration, overshield and cap note
- `upsilonbattle/.../effectapplicator.go:150,176,249` — shield application, absorption, cap
- `upsilonbattle/battlearena/ruler/rules/attack.go:77-89` — absorption in the melee path
- `mech_combat_shielding` (atom) — existing home for shielding mechanics
- `issues/ISS-142_20260827_skill_originated_attribute_buffs_unsupported.md` — buffable set
- `issues/ISS-144_20260827_buff_writeback_folds_into_base_state.md` — write-back fix scope
- `issues/ISS-078_20260423_shielding_credit_attribution_system.md` — adjacent open shielding work

---

## Change Log
- **2026-08-27**: Filed as a deferral record. User ruled Shield buffable but explicitly separated its
  specific handling: *"leave the shield specifically to its own issue to be handled later, for now
  consider it like any resource."*
