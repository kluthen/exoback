# Issue: Shield Bash is seeded as a Reaction but the reaction mechanism does not exist — needs an OnReceivedHit trigger that fires the recipient's reaction back at the attacker

**ID:** ISS-155_20260902_shield_bash_reaction_onreceivedhit
**Ref:** ISS-155
**Date:** 2026-09-02
**Severity:** Medium
**Status:** Open
**Component:** `upsilonbattle/battlearena/ruler/rules/skill_validation.go`
**Affects:**
- `upsilonhub/internal/seed/seed.go` — the `Shield Bash` template row (behavior `Reaction`)
- `upsilonbattle/battlearena/ruler/rules/skill_validation.go` — `preSkillChecks`, the `// no target for passives!` early return
- `upsilonbattle/battlearena/ruler/rules/skill.go:81` — `paySkillCost`, runs unconditionally on the success path
- `upsilonbattle/battlearena/property/effect/effectapplicator/effectapplicator.go` — `ApplyDirectEffect` / `applyDamageToSingleTarget`, the hit site where the trigger must fire
- `upsilontypes/property/def/registry_skill_cost_trigger.go:45-48` — `TriggerType` allowed set (no combat-outcome values)
- `upsilontypes/property/def/skill.go:112` — `BehaviorTypeReaction`

## Summary

`Shield Bash` **should remain a `Reaction`** — it is the vehicle for building the reaction mechanism,
which does not exist today.

Design intent:

- On a hit landing, inspect the **hit recipient** for reactive skills carrying reaction type
  **`OnReceivedHit`**.
- If the recipient has such a skill, **it triggers against the attacker** — i.e. Shield Bash stuns the
  entity that just struck the shield-bearer.

The seeded payload (`DamageScale:0, StunPower:15, StunChance:100`) is already registry-valid and
expresses the intended outcome; only the dispatch is missing.

## Current state

1. **No reaction dispatch.** `preSkillChecks` early-returns for `IsPassive()/IsReaction()/IsCounter()`
   before `checkSkillTarget`, the only populator of `ctx.targetedEntities` (the second writer at
   `skill.go:57` is gated on `isReposition && RepositionSubjectSelf` and does not apply). The effect
   applicators iterate an empty slice, so invoking Shield Bash through `UseSkill` does nothing —
   **while `paySkillCost` (`skill.go:81`) still deducts its 3 `SPLeech`, and the same early return
   skipped `checkSkillCost`, so affordability is never validated.** A reaction is therefore currently
   billable and inert.
2. **No trigger vocabulary for combat outcomes.** `TriggerType`'s allowed set is
   `OnEnter, OnExit, OnStep, OnTurn, OnDeath` — all **positional**. There is no `OnReceivedHit`, and
   nothing hooks the damage path. This is the vocabulary gap already described in **ISS-149**
   (no combat-outcome trigger family: on-hit / on-dodge / on-parry / on-miss) and it is the same
   missing on-hit hook **ISS-148** needs for Parry.

## Scope

- Add the combat-outcome reaction trigger (`OnReceivedHit`) and fire it from the hit site in the damage
  path, resolving the reaction **against the attacker** rather than the reactor's own aim target.
- Reactions bypass the normal turn/target flow, so the reaction's target resolution, cost payment and
  affordability check all need defining — the current path does none of them correctly.
- Guard against unbounded recursion: a reaction that itself lands a hit could re-enter the trigger.

## Notes

- Do **not** resolve this by demoting Shield Bash to `Direct`. Reaction is the correct classification;
  it is deliberately the driver for building the mechanism.
- Strongly overlapping with **ISS-148** (Parry needs the same on-hit trigger) and **ISS-149** (the
  trigger family itself). Consider resolving all three together. Sibling: **ISS-154**.
