# Issue: No combat-outcome trigger family (on-hit / on-dodge / on-parry / on-miss) attached to entities

**ID:** ISS-149_20260830_combat_outcome_trigger_family
**Ref:** ISS-149
**Date:** 2026-08-30
**Severity:** Medium
**Status:** Open
**Component:** `upsilontypes/property/triggertype.go`
**Affects:**
- `upsilontypes/property/triggertype.go` (`TriggerTypeValue` — positional-only today)
- `upsilonbattle/battlearena/ruler/rules/positionaleffect.go:48-59` (existing trigger dispatch)
- `upsilonbattle/battlearena/property/effect/effectapplicator/effectapplicator.go:86-96` (the only hit test)
- `upsilonbattle/battlearena/ruler/rules/attack.go` (melee path — **has no hit test at all**)
- `issues/ISS-148` — **blocks it**: parry's defining behaviour is that on-hit effects still fire
- `issues/ISS-145` — Dodge/Accuracy reachability, same combat-modifier family

---

## Summary

Requested by the user (2026-08-30): a trigger family for **combat outcomes** — `OnHit`, `OnDodge`,
`OnParry`, `OnMiss` — **attached to entities** rather than to cells. Such an effect may apply to
either the attacker or the defender, and may be *self-based* (i.e. "fires when **I** am the
attacker" vs "fires when **I** am the defender").

Today no such family exists. Every trigger is positional. This issue was surfaced by ISS-148, whose
parry semantics are not implementable without it.

---

## Problem Scenario

### The existing trigger family is entirely positional

`TriggerTypeValue` has five members, all cell-based: `OnEnter`, `OnExit`, `OnStep`, `OnTurn`,
`OnDeath`. They are carried as a `TriggerType` property on a *positional effect* and dispatched from
`positionaleffect.go`. There is no concept of an effect that belongs to an **entity** and fires when
that entity participates in an attack exchange. The requested family is therefore a genuinely new
attachment model, not four new enum values.

### Blocker 1 — miss and dodge are the same roll, so they cannot be told apart

The only hit test in the codebase (`effectapplicator.go:86-96`):

```go
accuracy := ent.GetPropertyI(property.Accuracy).I()
for _, target := range targetedEntities {
    dodge := target.GetPropertyI(property.Dodge).I()
    if tools.RandomInt(0, 100) < accuracy-dodge {
        damageTargets = append(damageTargets, target)
    } else {
        logger.WithField("targetID", target.ID).Debug("Target dodged the effect")
    }
}
```

`accuracy - dodge` is collapsed into **one** comparison. A failed roll is indistinguishable between
"the attacker missed" (low accuracy) and "the defender evaded" (high dodge) — note the `else` branch
already mislabels *every* failure as a dodge. `OnMiss` and `OnDodge` cannot be dispatched separately
until this roll is split into two decisions with a defined order and interaction.

### Blocker 2 — the melee path has no hit test whatsoever

`attack.go` contains no `Accuracy`, no `Dodge`, no roll of any kind. Melee attacks **always hit**;
damage is computed straight through `tools.Max(1, ...)`. Consequences:

- Accuracy and Dodge are skill-tunnel-only concepts today. The ISS-145 Defect 2 Dodge fix corrected
  *which entity* is read, but only within the skill tunnel — melee never consults dodge at all.
- There is no attachment point for `OnHit`/`OnMiss`/`OnDodge`/`OnParry` on melee.
- Introducing one is a **balance change**, not just plumbing: melee currently has a 100% hit rate
  and every existing scenario's expectations are built on that.

### Blocker 3 — parry has no triggering condition

Per ISS-148, parry is declared but never read. `OnParry` has nothing to fire from until parry itself
is implemented — and parry cannot be meaningfully implemented without this family. The two issues are
mutually dependent; **this one must land first** (a parry that only floors damage is a worse dodge).

---

## Design Questions To Settle

None of these should be guessed by an implementer:

1. **Attachment.** Where does an entity-attached triggered effect live — a new entity field, an
   entity property, or a separate registry? Note the positional family stores its trigger as a
   *skill property on the effect*; entity attachment has no precedent to copy.
2. **Perspective / self-based.** How is "fires when I am the attacker" vs "when I am the defender"
   expressed? A `Perspective` field (`Self` / `Attacker` / `Defender` / `Either`)? This is the crux of
   the user's "may be self based" note and drives the whole data model.
3. **Which side's effects fire, and in what order,** when both attacker and defender carry a
   trigger on the same exchange.
4. **Recursion guard.** An `OnHit` effect that itself deals damage can re-enter the attack path and
   re-fire `OnHit`. A depth limit or re-entrancy rule is mandatory, not optional — crash-early
   argues for a hard cap that panics rather than a silent stop.
5. **Scope.** Skill tunnel only, or melee too? Melee requires Blocker 2 to be resolved first.
6. **Splitting the roll** (Blocker 1): does accuracy resolve first and dodge second, or one roll with
   attribution? This decides whether `OnMiss` and `OnDodge` are mutually exclusive.

---

## Risk Assessment

**Medium.** Nothing is broken today; this is absent capability. The risk is in the implementation:
Blocker 2 makes melee hit rates a live balance question, and Blocker 1 means a naive implementation
would silently alias `OnMiss` to `OnDodge` — reproducing, in a new mechanic, exactly the
silent-conflation class of defect that ISS-140/145/147 exist to remove.

---

## Recommended Fix

Sequenced; do not collapse:

1. **Settle the six design questions above** as an explicit decision record before any code.
2. **Split the hit test** into distinguishable outcomes (miss / dodge / hit), with the `else`-branch
   mislabel fixed. Test-first per rule 5.
3. **Decide melee's hit test** — either bring melee under the same resolution (balance change,
   needs its own scenario review) or explicitly scope this family to the skill tunnel and document
   why melee is exempt.
4. **Introduce the entity-attached trigger model** with the perspective field and recursion guard.
5. **Then implement parry (ISS-148)** on top, since its distinguishing clause depends on `OnHit`
   firing under a parried hit.

---

## References

- `issues/ISS-148_20260830_parry_declared_but_unimplemented.md` — dependent; parry needs this family
- `issues/ISS-145_20260827_combat_modifiers_not_entity_reachable.md` — Accuracy/Dodge reachability
- `upsilontypes/property/triggertype.go` — the positional-only family this extends
- `upsilonbattle/battlearena/ruler/rules/positionaleffect.go` — existing dispatch precedent

---

## Change Log

- **2026-08-30** — Filed at user request. Verified against source: trigger family is positional-only;
  the sole hit test conflates miss and dodge in one roll and mislabels all failures as dodges; the
  melee path has no hit test at all.
