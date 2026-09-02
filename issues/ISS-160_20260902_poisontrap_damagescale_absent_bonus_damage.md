# Issue: Poison-only traps silently deal attack-scaled bonus damage because absent DamageScale defaults to 100

**ID:** ISS-160_20260902_poisontrap_damagescale_absent_bonus_damage
**Ref:** ISS-160
**Date:** 2026-09-02
**Severity:** Medium
**Status:** Open
**Component:** `upsilonbattle/battlearena/property/effect/effectapplicator/effectapplicator.go`
**Affects:**
- `effectapplicator.go:122` — `getPropertyOrDefaultI(eff, property.DamageScale)`, defaults to **100** when absent
- `effectapplicator.go:146` — `truedmg := max((attack*damage/100)-defense-armor, 0) + truepoison + truestun`
- `upsilontypes/property/effect/effect.go:88-101` — `IsDamaging()` true on positive `PoisonPower`/`StunPower`
- `upsilonbattle/battlearena/battletest/builders.go:100-116` — `PoisonTrap()`, 7 call sites
- `upsilonbattle/battlearena/ruler/rules/rules_skill_effects_test.go:99-133` — `TestRuleSkillEffectPoisonCounter`

## Summary

`DamageScale` **defaults to 100 when the key is absent** — absence is not zero. Any effect that enters
the damaging branch without an explicit `DamageScale` therefore also deals
`(attack*100/100) - defense - armor` on top of its intended payload.

`IsDamaging()` returns true for a positive `PoisonPower` or `StunPower`, so a **poison-only** or
**stun-only** effect enters that branch and silently picks up full attack-scaled damage.

## Confirmed live instances

1. **`PoisonTrap()`** (`builders.go:100-116`) sets `PoisonPower` + `PoisonChance` + `TriggerType` and
   **no `DamageScale`**. Its own doc comment calls it "the canonical observable for fly-over vs
   landing assertions" — i.e. poison-only by intent. Stepping on one of these traps also deals
   attack-scaled damage. 7 call sites, including `battletest/reposition_test.go` and
   `scenario_test.go`; trap triggers route through the same `ApplyDirectEffect` via
   `positionaleffect.go`.
2. **`TestRuleSkillEffectPoisonCounter`** — sets only `PoisonPower:5, PoisonChance:100`. Asserts the
   Poison counter only, so the extra damage happens unverified.

No test asserts HP after these fire, so the bonus damage is invisible to the suite.

## Why it matters

Reposition/fly-over tests use poison as their observable specifically because it is supposed to be a
clean, isolated signal. It is not: those traps also change HP. Any future assertion on HP in those
scenarios would be reasoning against a confounded fixture.

This is the same trap class already hit twice in this round: **absence is not zero** (cf. the
`"Armor"` nil-lookup, and Shield Bash needing an explicit `"DamageScale":0`).

## Scope

- Add explicit `DamageScale: 0` wherever poison-only/stun-only is the intent, starting with
  `PoisonTrap()` and `TestRuleSkillEffectPoisonCounter`.
- Then decide the real question: whether defaulting an **absent** `DamageScale` to 100 inside the
  damaging branch is correct at all. A skill that never mentions damage arguably should not deal any;
  a 100 default that silently activates is the root cause and is hard to reconcile with CODING_RULE §3.
- Add an HP assertion to at least one poison-trap test so a regression is observable.

## Notes

Found during the property-key unification round's skill-definition sweep.
