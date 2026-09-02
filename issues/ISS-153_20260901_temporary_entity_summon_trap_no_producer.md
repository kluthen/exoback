# Issue: The summon/trap temporary-entity family has a fully built consumer side but no producer — nothing ever creates a temporary entity or a skill-originated buff

**ID:** ISS-153_20260901_temporary_entity_summon_trap_no_producer
**Ref:** ISS-153
**Date:** 2026-09-01
**Severity:** Medium
**Status:** Open
**Component:** `upsilontypes/property/def/entity.go`
**Affects:**
- `upsilontypes/property/propertyenum.go:36` — `property.EntityDuration` declaration
- `upsilontypes/property/def/registry_entity_core.go:37-39` — `EntityDuration` registry row (13)
- `upsilontypes/property/def/entity.go:70-71` — `EntityDuration` default constructor (`0,0` = permanent)
- `upsilonbattle/battlearena/ruler/rules/endofturn.go:132-147` — live decrementer/remover, `@spec-link [[mechanic_expiration_controller]]`, never exercised in production
- `upsilontypes/property/propertyenum.go:39` — `property.ExpiresWithCaster` declaration
- `upsilontypes/property/def/registry_entity_core.go:41-43` — `ExpiresWithCaster` registry row (14)
- `upsilontypes/property/def/entity.go:74-75` — `ExpiresWithCaster` default constructor (`false`)
- `upsilonbattle/battlearena/ruler/gamestate/gamestate_logic.go:106` — live reader, culls caster-owned positional effects, never exercised in production
- `upsilontypes/property/buff.go:5-13` — `TemporaryProperties`, carries `OriginEntityID`/`OriginSkillID`
- `upsilontypes/property/buff.go:26-33` — `TickDown()`
- `upsilontypes/entity/entity.go:267-275` — `Entity.BuffTickDown()`, only caller is `entity_test.go:64`
- `upsilonapi/bridge/bridge_start.go:238` — `applyItemAsBuff`, the only production `RegisterBuff` call site that isn't resurrect rehydration (always `Forever:true`, `OriginEntityID` = item UUID)
- `upsilonapi/bridge/bridge_resurrect.go:205` — the other production `RegisterBuff` call site (rehydration)
- `upsilonapi/api/input.go:157-161` — wire `Buff` DTO, no duration field
- `upsilontypes/entity/entity_buff_attribution.go` — `GetBuffAttributionFor` (landing this round), the read side that is ready ahead of any producer

---

## Summary

`EntityDuration` and `ExpiresWithCaster` are fully wired on the *consumer* side: both are declared
properties with registry rows, default constructors, and live readers in production code —
`endofturn.go:132-147` decrements `EntityDuration` and removes the entity at zero, and
`gamestate_logic.go:106` culls positional effects owned by a caster when that caster dies. Both default
to "permanent"/"false" and **nothing in the umbrella ever sets either to a non-default value in
production**. `TemporaryProperties.OriginSkillID` (`buff.go:13`) has exactly one occurrence anywhere —
its own field declaration — never written, never read.

As the maintainer put it (2026-09-01): `OriginEntityID`/`OriginSkillID` "are meant for summons, traps
and the like. so they should be used but it's still an early breed of skill that haven't seen much use
so far." This is **missing feature work, not a defect** — the consumer half of a mechanic (summons,
traps, skill-granted buffs) is built and waiting for its producer, which does not exist yet.

---

## Problem Scenario

1. A registry property `EntityDuration` exists to mark a temporary entity's remaining lifetime, default
   `0` (permanent):
   ```go
   // upsilontypes/property/def/entity.go:70-71
   func EntityDuration() property.Property {
       return defaultproperty.NewIntCounterProperty(property.EntityDuration, 0, 0, ...)
   }
   ```
2. `endofturn.go:132-147` decrements it every end-of-turn and removes the entity at zero — but since no
   caller ever sets a non-zero value, this branch (`if dur > 0`) never executes in production:
   ```go
   // upsilonbattle/battlearena/ruler/rules/endofturn.go:132-147
   // @spec-link [[mechanic_expiration_controller]]
   if durProp := ent.GetProperty(property.EntityDuration); durProp != nil {
       dur := ent.GetPropertyC(property.EntityDuration).GetValue()
       if dur > 0 {
           dur--
           if dur == 0 {
               gs.RemoveEntity(req.EntityID)
               ...
           }
       }
   }
   ```
3. Same shape for `ExpiresWithCaster` (default `false`, reader at `gamestate_logic.go:106`) — nothing
   ever sets it `true`.
4. `RegisterBuff` has exactly two production call sites umbrella-wide, and neither is a skill cast:
   - `bridge_start.go:238` (`applyItemAsBuff`) — item-granted, always `Forever:true`.
   - `bridge_resurrect.go:205` — resurrect rehydration of already-registered buffs.
   `upsilonbattle`'s `skill.go`, `attack.go`, and `effectapplicator.go` never call `RegisterBuff` or
   construct a `TemporaryProperties` value. **Skill-granted buffs do not exist as a runtime mechanism.**
5. `Entity.BuffTickDown()` (`entity.go:267-275`) is never called from `EndOfTurn` in production — its
   only caller anywhere is `entity_test.go:64`. `EndOfTurn` ticks `SkillCooldownTickDown()` and the
   entity-scoped `EntityDuration`, but not buff-scoped `Duration`. A finite-duration buff, even if one
   were created today, would never expire.
6. The wire `Buff` DTO carries no duration field at all:
   ```go
   // upsilonapi/api/input.go:157-161
   type Buff struct {
       OriginID   string
       Forever    bool
       Properties map[string]interface{}
   }
   ```

**Two distinct `Duration` concepts — do not conflate them.** Entity-scoped `property.EntityDuration`
(how long a summoned entity/trap lives, ticked in `endofturn.go`) is separate from buff-scoped
`TemporaryProperties.Duration` (how long a stat modifier lasts, ticked by the never-called
`BuffTickDown`). Both lack producers, for different reasons, and both need addressing.

This is distinct from `ISS-151`/`ISS-152`, which were deliberately kept narrow: those properties
(`InformationLevel`/`MinInfoLevel`) are dead weight that pretends to enforce something with no plan
behind it. `EntityDuration`/`ExpiresWithCaster`/`OriginSkillID` are the opposite — scaffolding for an
intended, not-yet-built feature, not dead weight to retire.

`upsilontypes/property/def/entity.go` currently carries no `@spec-link`, and the
`mechanic_expiration_controller` / `mechanic_temporary_entity_system` atoms are both **DRAFT** — the
paper trail for this family is as incomplete as the code.

---

## Risk Assessment

**Medium.** No current breakage — nothing is broken and no user-facing behaviour is wrong today. The
risk is that live-looking machinery has never actually run: `endofturn.go:132-147` and
`gamestate_logic.go:106` read as functioning code and are `@spec-link`'d to a mechanic atom, so a
future maintainer will reasonably assume they work. They have never executed against a real producer in
production. Whoever builds the producer should expect latent bugs in that never-exercised code and
should treat both paths as unproven, not merely untested.

---

## Recommended Fix

Sequence this — do not collapse the steps.

1. **Settle the design first** (atoms before code, per ATD): what skill archetype summons an entity or
   places a trap; what `EntityDuration`/`ExpiresWithCaster` values it sets; whether a summon is a full
   `Entity` or a positional effect. `mechanic_temporary_entity_system` and `mechanic_expiration_controller`
   are the DRAFT atoms to advance.
2. **Build the producer** — a skill-cast path that constructs a temporary entity with a non-zero
   `EntityDuration` and, where appropriate, `ExpiresWithCaster: true`.
3. **Populate attribution** — set `OriginSkillID` (and `OriginEntityID`) when a skill grants a buff or
   spawns an entity, so provenance is real rather than modelled. `GetBuffAttributionFor`
   (`upsilontypes/entity/entity_buff_attribution.go`, landing this round) will surface these fields the
   moment they are populated — the read side is ready first, deliberately.
4. **Wire buff expiry** — call `BuffTickDown()` in `EndOfTurn` alongside the existing
   `SkillCooldownTickDown()`, and decide whether buff `duration` belongs on the wire DTO.
5. **Test-first per CODING_RULE §5** — the expiry paths at `endofturn.go:132-147` and
   `gamestate_logic.go:106` have never executed against a real producer; they are unproven, not merely
   untested.

- **Short term:** no code change required; file the gap so the next skill-authoring round knows the
  producer is the missing half, and advance the two DRAFT atoms before any implementation starts.

---

## References

- `upsilontypes/property/propertyenum.go:36,39` — `EntityDuration`/`ExpiresWithCaster` declarations
- `upsilontypes/property/def/registry_entity_core.go:37-43` — registry rows 13-14
- `upsilontypes/property/def/entity.go:70-75` — default constructors (permanent/false)
- `upsilonbattle/battlearena/ruler/rules/endofturn.go:132-147` — `mechanic_expiration_controller` decrementer, unproven
- `upsilonbattle/battlearena/ruler/gamestate/gamestate_logic.go:106` — caster-death cull reader, unproven
- `upsilontypes/property/buff.go:5-33` — `TemporaryProperties`, `OriginEntityID`/`OriginSkillID`, `TickDown()`
- `upsilontypes/entity/entity.go:267-275` — `Entity.BuffTickDown()`, only called from `entity_test.go:64`
- `upsilonapi/bridge/bridge_start.go:238` — `applyItemAsBuff`, item-only `RegisterBuff` call site
- `upsilonapi/bridge/bridge_resurrect.go:205` — resurrect rehydration `RegisterBuff` call site
- `upsilonapi/api/input.go:157-161` — wire `Buff` DTO, no duration field
- `upsilontypes/entity/entity_buff_attribution.go` — `GetBuffAttributionFor`, the ready read side
- `issues/ISS-151_20260901_properties_for_character_public_vs_registry_minlevel.md` — sibling round, contrast case (dead weight, not scaffolding)
- `issues/ISS-152_20260901_information_level_scheme_never_enforced.md` — sibling round, contrast case (dead weight, not scaffolding)
- `CODING_RULE.md` §1 — ATD adherence, atoms before business-layer code
- `CODING_RULE.md` §5 — test-first on bugs

---

## Change Log

- **2026-09-01** — Filed. Verified against source: `EntityDuration`/`ExpiresWithCaster` have no
  production writer anywhere in the umbrella (declaration, registry row, default constructor, and
  reader only); `OriginSkillID` has exactly one occurrence umbrella-wide (its own declaration);
  `RegisterBuff` has exactly two production call sites, neither a skill-cast path; `BuffTickDown()` is
  never called outside its own test. Framed as missing feature work per maintainer intent, not a
  defect — contrast with `ISS-151`/`ISS-152`, which are dead weight rather than scaffolding.
