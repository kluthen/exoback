# Issue: Nine test sites file a Cost property into the Targeting map under the key "TargetType" — passing only by accident of GetProperty's cross-map scan

**ID:** ISS-159_20260902_leech_tests_cost_filed_under_targeting
**Ref:** ISS-159
**Date:** 2026-09-02
**Severity:** Low
**Status:** Open
**Component:** `upsilonbattle/battlearena/ruler/rules`
**Affects:**
- `rules_skill_leech_hp_mvt_test.go:18,47,76,109` — `MovementCost` / `HPLeech`
- `rules_skill_leech_mp_sp_test.go:18,47,76,109` — `MPLeech` / `SPLeech`
- `rules_skill_writeisolation_test.go:37` — `HPLeech`
- `upsilontypes/entity/skill/skill.go:109-127` — `Skill.GetProperty`, scans all three maps by property name

## Summary

Nine sites do:

    fake.Skill.Targeting[property.TargetType.String()] =
        defaultproperty.MakeIntProperty(property.HPLeech, 11, ...)

A **Cost** property is stored in the **Targeting** map under the key `"TargetType"`. It should be
`Skill.Costs[property.HPLeech.String()]`.

The tests pass only because `Skill.GetProperty` resolves by scanning all three maps for a property
whose own `.Name()` matches — the map it lives in and the key it is filed under are both ignored. So
the mislabeling is inert **by accident**, not by design.

Verified: 15 sites match this pattern overall; the other 6 (`rules_skill_effects_test.go:68,147`,
`rules_skill_targeting_test.go:113` and siblings) legitimately store an actual `TargetType` property
and are correct. Only the 9 listed above are mis-keyed.

## Why it matters

- The `Targeting` map ends up holding a `"TargetType"` entry that is really a leech cost, so any test
  reading `Targeting["TargetType"]` directly gets a cost property.
- It misrepresents the data model to anyone reading or extending these tests.
- It silently depends on `GetProperty`'s cross-map scan. If that ever tightens to respect map
  boundaries (a reasonable hardening), all nine break at once for a non-obvious reason.

## Scope

Move each of the nine to `Skill.Costs[<the property>.String()]`. Mechanical, no behaviour change
expected — the tests should still pass for the right reason afterwards.

## Notes

Found during the property-key unification round's skill-definition sweep.
