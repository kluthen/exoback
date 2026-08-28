# Issue: Crit / Accuracy / Dodge are unreachable as entity properties — and Dodge is read from the attacker

**ID:** ISS-145_20260827_combat_modifiers_not_entity_reachable
**Ref:** ISS-145
**Date:** 2026-08-27
**Severity:** High
**Status:** Open
**Component:** `upsilonbattle/battlearena/property/effect/effectapplicator/effectapplicator.go`
**Partial:** Defect 2 (Dodge read from attacker) RESOLVED 2026-08-28. Defect 1 (entity-reachability) outstanding — this is what keeps the issue Open.
**Affects:**
- `upsilonapi/bridge/bridge_start.go:214-226` (`applyItemAsBuff` lookup chain)
- `upsilontypes/property/propertyenum.go:64-76` (`Accuracy`, `Dodge`, `CriticalChance`, `CriticalMultiplier`)
- `upsilonapi/bridge/bridge_utils.go:12-16` (`propertyAliasMap`'s dead `CritChance`/`CritDamage` entries)
- `issues/ISS-142` — blocks the user's ruling that these properties be buffable
- Any shop item advertising crit, accuracy or dodge

---

## Summary

Two independent defects in the same property family, both live:

1. **`CriticalChance`, `CriticalMultiplier`, `Accuracy` and `Dodge` exist only as `SkillProperties`.**
   They cannot be resolved as entity or item properties, so an item or buff payload naming them is
   silently discarded. Crit is additionally read from the *effect* rather than the entity, so even a
   correctly-resolved entity-level crit value would have no effect on damage.
2. **`Dodge` is read from the attacker instead of the target** in the hit test, so the caster's own
   dodge suppresses their own attacks and the target's dodge is never consulted.

Both must be resolved for ISS-142's ruling ("crit chance/damage, evasion, accuracy should still be
buffable") to be implementable.

---

## Problem Scenario

### Defect 1 — the keys resolve nowhere useful

Verified against the real registries (scratch test, since deleted):

```
CriticalChance       ItemProperty=false  EntityProperty=false  SkillProperty=true
CriticalMultiplier   ItemProperty=false  EntityProperty=false  SkillProperty=true
Accuracy             ItemProperty=false  EntityProperty=false  SkillProperty=true
Dodge                ItemProperty=false  EntityProperty=false  SkillProperty=true
Attack               ItemProperty=false  EntityProperty=true   SkillProperty=false
```

`applyItemAsBuff` tries **only** `ItemProperty` then `EntityProperty` (`bridge_start.go:220-224`):

```go
if prop := def.ItemProperty(property.ItemProperties(effectiveKey)); prop != nil {
    p = prop
} else if prop := def.EntityProperty(property.EntityProperties(effectiveKey)); prop != nil {
    p = prop
}
if p != nil && setSkillPropValue(p, dto) { ... }   // p == nil -> silently dropped
```

Both lookups return nil for all four keys, so `p` stays nil and the property is dropped without a
word. **An item advertising crit chance does nothing at all today**, and the player is never told.

This also makes `propertyAliasMap`'s `CritChance -> CriticalChance` and
`CritDamage -> CriticalMultiplier` entries (`bridge_utils.go:14-15`) **dead code**: the alias
rewrites the key and the rewritten key then fails both lookups anyway. See ISS-143.

Even with resolution fixed, crit would still not apply: `effectapplicator.go:126-127` reads it from
the **effect**, not the entity —

```go
critChance := getPropertyOrDefaultI(eff, property.CriticalChance).I()
critMultiplier := getPropertyOrDefaultI(eff, property.CriticalMultiplier).I()
```

— so an entity-level crit buff has no path into the damage computation. `Accuracy` by contrast is
already read from the entity (`:86`) and would compose buffs correctly for free once the key
resolves.

### Defect 2 — Dodge is read from the wrong entity

`effectapplicator.go:86-93`:

```go
accuracy := ent.GetPropertyI(property.Accuracy).I()      // ent = caster (correct)
for _, target := range targetedEntities {
    dodge := ent.GetPropertyI(property.Dodge).I()        // <-- ent, not target
    if tools.RandomInt(0, 100) < accuracy-dodge {
        damageTargets = append(damageTargets, target)
    }
}
```

`dodge` is taken from `ent`, the caster, for every target. Consequences:
- A target's `Dodge` never affects whether it is hit — evasion is inert as a defensive stat.
- A caster that raises its own `Dodge` makes its *own* attacks miss more often.
- The read is loop-invariant, which is what makes the mistake easy to miss on review.

It is currently masked because nothing sets `Dodge` on any entity (defect 1 guarantees no payload
can), so the value is always the default and `accuracy-dodge` reduces to plain accuracy. Fixing
defect 1 without defect 2 would activate the inverted behaviour.

---

## Risk Assessment

- **Player-facing silence:** shop items promising crit/accuracy/dodge are inert. Players pay for
  nothing, with no error anywhere — the exact failure class ISS-140 exists to eliminate, here on the
  *item* path rather than the skill payload path.
- **Latent inversion:** defect 2 is dormant only because of defect 1. Enabling buffability without
  fixing the read turns evasion into a self-inflicted penalty.
- **Blocks ISS-142:** the buffable-set ruling explicitly includes these four properties.

---

## Recommended Fix

**Short term.** Fix defect 2 — read `Dodge` from `target`, and hoist it inside the loop only where
it belongs. This is a two-line correction with no dependency on the rest, and should not wait.

**Medium term.** Decide where these four properties *live*. They are combat modifiers of an entity,
not of a skill, yet they are declared as `SkillProperties` and consumed inconsistently (accuracy and
dodge from the entity, crit from the effect). Options: promote them to `EntityProperties`; or keep
the skill-level declaration and add an entity-level counterpart that the effect falls back to.
Whichever is chosen, crit must become reachable from the entity for the ISS-142 ruling to mean
anything, and the resolution chain in `applyItemAsBuff` must be extended to match. Coordinate with
ISS-143 — the dead crit aliases should be removed as part of whatever rename lands here.

**Do not** simply add the keys to `EntityProperties` without addressing the crit read site: the
payload would then resolve and be stored, and still silently fail to affect damage.

---

## References

- `upsilonbattle/.../effectapplicator.go:86-93` — hit test, Dodge read from caster
- `upsilonbattle/.../effectapplicator.go:126-127` — crit read from effect, not entity
- `upsilonapi/bridge/bridge_start.go:214-226` — `applyItemAsBuff` two-step lookup chain
- `upsilontypes/property/propertyenum.go:64-76` — the four properties, declared as `SkillProperties`
- `issues/ISS-142_20260827_skill_originated_attribute_buffs_unsupported.md` — buffability ruling
- `issues/ISS-143_20260827_bridge_property_alias_map_should_be_removed.md` — dead crit aliases
- `issues/ISS-140_20260827_bridge_skill_payload_silent_property_drop.md` — same silent-drop class
- `CODING_RULE.md` §3 (crash early / fail fast), §4 (strict API contract adherence)

---

---

## Partial resolution (2026-08-28) — Defect 2 only

**Defect 2 (Dodge read from the attacker) is FIXED. Defect 1 (crit/accuracy/dodge unreachable as
entity properties) remains OPEN and is unstarted.**

Defect 2's fix was one line, in `effectapplicator.go:89`, inside the loop over `targetedEntities`:

```go
-  dodge := ent.GetPropertyI(property.Dodge).I()
+  dodge := target.GetPropertyI(property.Dodge).I()
```

It rode along with ISS-144's write-isolation work as one bounded handoff, since both touch the same
combat-resolution files and both are compliance fixes rather than behaviour changes.

**Verification:** a dedicated regression test,
`upsilonbattle/battlearena/property/effect/effectapplicator/effectapplicator_dodge_test.go`, asserts
evasion keys off the **target's** Dodge, not the caster's. Confirmed failing pre-fix (expected 1
damaged target, got 0 — the caster's Dodge of 100 wrongly suppressed the hit) and passing post-fix,
independently re-reproduced by the reviewer in a scratch tree. Full suite green; reviewer verdict
OKAY.

**Still dormant, and that is the point:** nothing can set `Dodge` on an entity yet — that is exactly
Defect 1. The fix inverts nothing today; it ensures evasion resolves against the correct entity the
moment Defect 1 is closed and Dodge becomes reachable.

**What remains under this issue (Defect 1, unchanged):** `Accuracy`, `Dodge`, `CriticalChance` and
`CriticalMultiplier` are declared as `SkillProperties` only, so they resolve as neither entity nor
item properties and are silently dropped from item/buff payloads; crit is read off the effect rather
than the entity (`effectapplicator.go:128-129`) and accuracy is still read from `ent`
(`effectapplicator.go:86`, correct for accuracy — it is the attacker's stat). The open design
question of whether these get promoted to `EntityProperties` or keep a skill-level declaration with
an entity-level counterpart is still undecided, and it affects ISS-143's rename scope.

## Change Log
- **2026-08-27**: Filed. Found while scoping ISS-142's buffable set against the user's ruling that
  crit/evasion/accuracy be buffable. Key resolution verified empirically against the real registries;
  the Dodge misread was found in the same read path. Filed as one issue because both concern the
  same property family and the same file, and defect 2 is unmasked by fixing defect 1 — split if
  preferred.
- **2026-08-28**: **Defect 2 RESOLVED** (Dodge now read from `target`, not `ent`, at
  `effectapplicator.go:89`), landed as part of the ISS-144 handoff with a dedicated regression test
  confirmed failing pre-fix. Reviewer verdict OKAY. **Defect 1 remains Open and unstarted** — the
  crit/accuracy/dodge entity-reachability work was explicitly excluded from that handoff's scope.
  Issue status set to `Open (Defect 2 resolved; Defect 1 outstanding)`. Not yet committed.
