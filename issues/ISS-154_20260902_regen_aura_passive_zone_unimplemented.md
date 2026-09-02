# Issue: Regen Aura is seeded as a Passive but no passive/aura mechanism exists — it needs a self-centred Square:1 OnTurn healing zone and a real test bed

**ID:** ISS-154_20260902_regen_aura_passive_zone_unimplemented
**Ref:** ISS-154
**Date:** 2026-09-02
**Severity:** Medium
**Status:** Open
**Component:** `upsilonhub/internal/seed/seed.go`
**Affects:**
- `upsilonhub/internal/seed/seed.go` — the `Regen Aura` template row (behavior `Passive`)
- `upsilonbattle/battlearena/ruler/rules/skill_validation.go` — `preSkillChecks`, the `// no target for passives!` early return
- `upsilonbattle/battlearena/ruler/rules/skill.go:81` — `paySkillCost`, runs unconditionally on the success path
- `upsilonbattle/battlearena/ruler/rules/beginingofturn.go:53` — `ProcessPositionalEffects(gs, ent, ent.Position, property.TriggerOnTurn)`, the consumer that already exists
- `upsilontypes/property/def/registry_skill_cost_trigger.go:45-48` — `TriggerType` allowed set
- `upsilontypes/property/def/registry_skill_targeting.go:17-20` — `Zone` (`KindZone`, `CompositionReplace`)

## Summary

`Regen Aura` **should remain `Passive`** — the name is correct and it behaves like an item effect: a
sustained, always-on aura rather than an activated action. The problem is that no passive mechanism
exists to carry it.

Design intent for the skill:

- **Behavior:** `Passive` (unchanged)
- **Zone:** `Square:1` **centred on the caster** (a 3x3 block that follows the caster as it moves)
- **Effect:** `Heal` raised from **1 to 5**
- **Trigger:** an entity that **begins its turn** inside the zone is healed
- **Faction filter:** allies only — **must not** trigger for foes

## Current state

The seeded payload is registry-valid but inert. Two independent gaps block it:

1. **Passive dispatch gap.** `preSkillChecks` early-returns for `IsPassive()/IsReaction()/IsCounter()`
   *before* `checkSkillTarget`, which is the only code that populates `ctx.targetedEntities`
   (the one other writer, `skill.go:57`, is gated on `isReposition && RepositionSubjectSelf` and so
   does not apply). `applyDamagingEffect`/`applyHealingEffect` iterate that empty slice, so the heal
   is a silent no-op. The same early return **also skips `checkSkillCost`**, while `paySkillCost`
   (`skill.go:81`) still runs — so a passive is charged with no affordability check. Regen Aura's
   cost is `{}` today, so the billing half is currently latent rather than observable.
2. **Producer gap.** The `OnTurn` consumer already exists (`beginingofturn.go:53`), but nothing ever
   creates a skill-originated zone/positional effect. This is the same producer hole tracked in
   **ISS-153** (summon/trap family has a built consumer side and no producer).

A third, novel requirement: existing positional effects are placed on a **fixed tile**. An aura
centred on the caster is a **moving** zone and has no precedent in the current trap machinery — that
is a design question, not just wiring.

## Required test bed

All three tests must exist and pass; targets need starting `HP` strictly below `MaxHP` or the heal is
unobservable.

1. **Heals an ally that begins its turn in the zone.** Ally inside `Square:1` of the caster, `HP < MaxHP`
   at turn start, `HP` increases by 5.
2. **Does not heal a foe.** An enemy standing inside the same zone begins its turn and is **not** healed.
   This is the friend/foe discrimination check.
3. **Heals a same-team entity belonging to a different player.** Guards against the faction filter being
   implemented as an owner/controller check rather than a team check.

## Notes

- Do **not** resolve this by demoting Regen Aura to `Direct`. Passive is the correct classification;
  the mechanism is what is missing.
- Blocked on / related: **ISS-153** (producer gap), **ISS-155** (the sibling reaction-mechanism gap).
