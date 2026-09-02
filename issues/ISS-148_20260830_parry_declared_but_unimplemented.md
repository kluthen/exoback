# Issue: Parry is declared and constructible but never read — and its semantics need an on-hit trigger that does not exist

**ID:** ISS-148_20260830_parry_declared_but_unimplemented
**Ref:** ISS-148
**Date:** 2026-08-30
**Severity:** Medium
**Status:** Open
**Component:** `upsilontypes/property/propertyenum.go`
**Affects:**
- `upsilontypes/property/propertyenum.go:66` (`Parry SkillProperties = "Parry"`)
- `upsilontypes/property/propertyenum.go:120` (membership in `SkillTargetingProperties`)
- `upsilontypes/property/def/skill.go:27-28` (`Parry()` constructor)
- `upsilontypes/property/def/skill.go:344-345` (resolver case)
- `upsilonbattle/battlearena/ruler/rules/attack.go:74` (the damage floor parry would key off)
- `upsilontypes/property/triggertype.go` (the missing on-hit trigger family)
- `issues/ISS-145` — Parry shares Defect 1's entity-unreachability shape but is deliberately NOT in its scope

---

## Summary

`Parry` is a fully declared `SkillProperties` key with a working constructor and resolver case, and
it is a member of `SkillTargetingProperties` — but it has **zero read sites anywhere in combat**. No
rule consults it. It is inert declared surface that reads, to anyone browsing the property list, as
an implemented mechanic.

Split out of ISS-145 by user direction (2026-08-30) so the property-space unification work is not
widened by a gameplay-design question.

---

## Problem Scenario

Two distinct gaps, and the second is the blocker:

### Gap 1 — declared, constructible, never read

```go
// propertyenum.go:66
Parry SkillProperties = "Parry" // Absence means 0%

// def/skill.go:27-28
func Parry() *defaultproperty.DefaultIntProperty {
	return defaultproperty.MakeIntProperty(property.Parry, 0, property.FriendlyController, property.Skill)
}
```

Both resolve fine. Nothing in `attack.go` or `effectapplicator.go` ever reads the value. A skill or
item advertising Parry does nothing.

Parry additionally shares ISS-145 Defect 1's shape — it is declared **only** as `SkillProperties`,
so it resolves as neither entity nor item and an item/buff payload naming it is silently dropped.
That half will be fixed incidentally by the property-space unification round; the gameplay half
below will not.

### Gap 2 — the intended semantics need a trigger family that does not exist

Semantics specified by the user (2026-08-30):

> Parry is an off chance to **take** a hit but suffer **no damage beyond the floor of 1** — in
> contrast with Dodge, which avoids the hit entirely. Effects that trigger **on hit** would still
> apply under a parry.

The first clause maps cleanly onto existing code: `attack.go:74` already floors damage at
`tools.Max(1, ...)`, so "parried" is expressible as "force `computedDamage` to the existing floor"
rather than as a new damage path.

The second clause has nothing to attach to. **There is no on-hit trigger today.** Every member of
`TriggerTypeValue` (`triggertype.go`) is positional and cell-based:

| Trigger | Fires when |
|---|---|
| `OnEnter` | entity enters the cell |
| `OnExit` | entity leaves the cell |
| `OnStep` | every step through the cell |
| `OnTurn` | start of each turn while in the cell |
| `OnDeath` | entity dies while in the cell |

None of these is "an attack connected with this entity". The user suspected as much; it is
confirmed. So the distinguishing behaviour of parry-vs-dodge — that on-hit effects still fire —
**cannot currently be implemented or tested**, because no effect can be registered to fire on hit.

---

## Risk Assessment

**Low operational risk, medium design risk.** Nothing is corrupted and no live payload misbehaves;
parry simply does nothing. The risk is that the declared key is mistaken for a working mechanic — by
a designer authoring a skill, by a player reading an item tooltip, or by a future implementer who
wires up the damage-floor half, sees it "work", and ships a parry that is behaviourally identical to
a weak dodge because the on-hit clause was quietly dropped.

---

## Recommended Fix

Sequenced, because the halves have different prerequisites:

1. **Decide parry's fate explicitly.** Either implement it or remove the declaration. Leaving it
   declared-and-inert is the one outcome to avoid. (Crash-early/no-silent-failure argues against
   keeping dead declared surface.)
2. **If implementing — introduce an on-hit trigger family first.** This is the real prerequisite and
   is a larger piece of work than parry itself: it needs a non-positional trigger concept, since the
   current family is entirely cell-based. Worth confirming whether any *other* planned mechanic wants
   on-hit triggers before sizing this; if parry is the only customer, that changes the calculus.
3. **Then implement the damage-floor half** — parry roll succeeds ⇒ `computedDamage` forced to the
   `tools.Max(1, ...)` floor at `attack.go:74`, hit still registers as a hit (so on-hit effects fire),
   in contrast to dodge which short-circuits the hit test entirely.
4. **Entity-reachability** — no separate action needed if the property-space unification round lands;
   Parry should be declared entity-scoped there along with `Accuracy`/`Dodge`/`Critical*`. Confirm it
   was included rather than assuming.

**Do not** implement step 3 without step 2, or parry ships as a strictly-worse dodge and the
distinction the mechanic exists for is lost.

---

## References

- `issues/ISS-145_20260827_combat_modifiers_not_entity_reachable.md` — the four sibling keys; Parry
  was split out of it by user direction on 2026-08-30
- Property-space unification round (decisions 15-22 of the ISS-140 round) — fixes Parry's
  entity-unreachability incidentally, not its gameplay gap
- `upsilonbattle/battlearena/ruler/rules/attack.go:74` — the existing damage floor
- `upsilontypes/property/triggertype.go` — the positional-only trigger family

---

## Change Log

- **2026-08-30** — Filed. Split from ISS-145 by user direction. Semantics captured from the user;
  verified against source that Parry has zero combat read sites and that no on-hit trigger exists.
