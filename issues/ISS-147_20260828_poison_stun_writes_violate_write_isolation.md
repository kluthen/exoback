# Issue: Poison and Stun writes violate the write-isolation invariant — and an item CAN buff them

**ID:** ISS-147_20260828_poison_stun_writes_violate_write_isolation
**Ref:** ISS-147
**Date:** 2026-08-28
**Severity:** Medium
**Status:** Open
**Component:** `upsilonbattle/battlearena/property/effect/effectapplicator/effectapplicator.go`
**Affects:**
- `upsilonbattle/battlearena/ruler/rules/beginingofturn.go:24-42` (Stun decay — same pattern)
- `upsilonapi/bridge/bridge_start.go:214-228` (`applyItemAsBuff` — the reachability path)
- `upsilontypes/property/def/entity.go:135-138` (`Poison`/`Stun` resolve as EntityProperties)
- `upsilonbattle:rule_entity_property_write_isolation` — the invariant these sites violate
- `issues/ISS-142` — inherits this; its buffability ruling excluded Poison/Stun *by design*, but the engine does not enforce that exclusion

---

## Summary

ISS-144 established and fixed the base-vs-composed write-isolation invariant for the five
in-match-written resource properties (`HP`, `SP`, `MP`, `Movement`, `Shield`). Two blocks handling
**Poison** and **Stun** were left untouched because the round had ruled those properties
non-buffable — but that ruling is a *design intent* for ISS-142's buffable set, and **nothing in the
engine enforces it**. `def.EntityProperty` resolves both, and `applyItemAsBuff` falls through to
exactly that resolver, so an item carrying `properties_json: {"Poison": 5}` creates a real Poison
buff today. With such a buff active, these sites reproduce the ISS-144 escalation exactly.

Found by the ATD Workflow B sync for ISS-144 (documentalist), which correctly declined to tag these
blocks as compliant and escalated instead of silently mis-marking them.

---

## Problem Scenario

Both sites read through a **composed** getter and persist an **absolute** value:

```go
// effectapplicator.go ~162-169 — status APPLICATION
if truepoison > 0 && tools.RandomInt(0, 100) < poisonchance {
    poison := target.GetPropertyI(property.Poison).I()      // composed: base + buffs
    target.RepsertPropertyValue(property.Poison, truepoison+poison)  // written as BASE
}
// ... identical shape for Stun

// effectapplicator.go ~270-275 — status CLEANSING
if poisonPower < 0 {
    target.UpdatePropertyValue(property.Poison, tools.Max(poison+poisonPower, 0))
}
```

Escalation, with an item granting a `+5` Poison buff:

```
                      base   buff   composed(read)
initial                 0      5          5
apply 3 poison          8      5         13     <- wrote composed(5)+3 = 8 into base
apply 3 poison         16      5         21     <- wrote composed(13)+3 = 16
apply 3 poison         24      5         29
```

`beginingofturn.go:24-42` then reads that inflated composed Stun/Poison to decide incapacitation
and decay, compounding the effect.

---

## Risk Assessment

**Severity Medium, not High**, because reaching it requires deliberately authored item data
(`properties_json: {"Poison": N}` through `admin_shop_item_create`). No seeded item does this today,
so it is not believed live in the current product. But:

- It is **reachable without any code change** — data alone triggers it.
- The engine's silence here is the same class of problem as ISS-140: an illegal-by-design payload is
  accepted and does something wrong instead of being rejected.
- `Poison`/`Stun` are `DefaultIntProperty`, **not** `IntCounterProperty`, so ISS-144's
  `AdjustPropertyCValue` primitive does **not** apply to them as-is. This needs its own delta path
  or an explicit exclusion.

---

## Recommended Fix

**Short term:** decide, and record, one of two paths:
1. **Enforce the design ruling** — make `applyItemAsBuff` (and the ISS-142 skill-buff path) *reject*
   `Poison`/`Stun` as buff keys, fail-fast per ISS-140's collect-all error strategy. Then document
   these two blocks as out of `rule_entity_property_write_isolation`'s scope with that rationale, and
   tag them accordingly. Cheapest, and consistent with the round's "either use the right name or
   fail" stance.
2. **Extend isolation to them** — add a base-delta write path for `DefaultIntProperty` and route both
   blocks through it, making the invariant genuinely type-wide.

**Long term:** whichever path is chosen, the invariant should be enforceable rather than
convention-based. ISS-144's own "Residual fragility" note already flags that the safety of the
attribute properties rests on an implicit, unenforced ordering invariant; this issue is the same
weakness surfacing on a different property class.

---

## References

- `issues/ISS-144_20260827_buff_writeback_folds_into_base_state.md` — the parent defect and its fix
- `upsilonbattle/docs/rule_entity_property_write_isolation.atom.md` — the invariant
- `issues/ISS-142_20260827_skill_originated_attribute_buffs_unsupported.md` — owns the buffability
  ruling that excluded Poison/Stun by design
- `issues/ISS-146_20260827_shield_specific_buff_semantics_deferred.md` — sibling deferral

---

## Change Log
- **2026-08-28**: Filed. Surfaced by the ISS-144 Workflow B ATD sync, which found the two blocks
  matching the prohibited composed-read/absolute-write pattern and declined to tag them compliant.
  Verified during triage that `def.EntityProperty` resolves `Poison`/`Stun` and that
  `applyItemAsBuff` reaches that resolver, so the "non-buffable" ruling is unenforced — which is what
  makes this a real defect rather than dead code. Also noted that `AdjustPropertyCValue` cannot be
  reused directly, since these are `DefaultIntProperty` not `IntCounterProperty`.
- **2026-08-28**: Corroborated independently. A backgrounded `atd check --atom
  rule_entity_property_write_isolation --semantic` run finished after filing and returned
  `passed: false`, flagging precisely this defect: write-back after reading composed Poison/Stun
  values does not subtract the buff contribution before persisting to base. Two independent methods
  (direct code reading during triage, and the semantic checker) now agree on the same two blocks.
  Note: the same run also emitted unfounded noise about `AdjustPropertyCValue` "overwriting" rather
  than applying a delta — it does apply a delta; that claim is not backed by the diff and is
  consistent with known weak-local-model false signal on semantic checks. Only the Poison/Stun
  finding is load-bearing.
