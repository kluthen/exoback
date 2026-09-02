# Issue: A bare-int `Range` in an authored skill produces an inverted, unreachable [value,max] window — Fireball, Heal and Lightning Strike are untargetable

**ID:** ISS-157_20260902_bare_int_range_inverted_unreachable
**Ref:** ISS-157
**Date:** 2026-09-02
**Severity:** High
**Status:** Open
**Component:** `upsilonapi/api/input.go`
**Affects:**
- `upsilonapi/api/input.go:52-84` — `PropertyDTO.UnmarshalJSON`, primitive fallback sets only `Value`
- `upsilonapi/bridge/bridge_utils.go:85-127` — `setSkillPropValue`, `Value`→`SetValue` (min), `Max`→`SetMaxValue`
- `upsilontypes/property/def/skill.go:129-131` — `DefaultRange()` = `(value 1, max 1)`
- `upsilontypes/property/defaultproperty/defaultproperty.go:120-125` — `SetValue`/`SetMaxValue`, **no clamping**
- `upsilonbattle/battlearena/ruler/rules/skill_validation.go:100` — `if dist > rng.GetMaxValue() || dist < rng.GetValue()`
- `upsilonhub/internal/seed/seed.go` — Fireball, Heal, Lightning Strike, Shield Bash rows

## Summary

`Range` is an `IntCounter` (`value` = **minimum** range, `max` = **maximum** range). When a skill is
authored with a **bare integer** (`"Range":3`), `PropertyDTO`'s primitive fallback sets **only**
`dto.Value`. `setSkillPropValue` maps that to `SetValue` — the **minimum** — and leaves `MaxValue` at
`DefaultRange()`'s `1`. `SetValue` does **not** clamp.

Result: `"Range":3` yields the window `[min=3, max=1]`. `checkSkillTarget` rejects when
`dist > max || dist < min`, so **every possible distance is rejected**:

| Seeded | Resolves to | Result |
|---|---|---|
| Fireball `"Range":3` | `[3,1]` | every distance rejected — **unusable** |
| Heal `"Range":2` | `[2,1]` | every distance rejected — **unusable** |
| Lightning Strike `"Range":2` | `[2,1]` | every distance rejected — **unusable** |
| Shield Bash `"Range":1` | `[1,1]` | usable (exactly 1 tile) |
| Regen Aura `"Range":0` | `[0,1]` | usable |

The intuitive reading of `"Range":3` is "reaches 3 tiles". It actually means "**minimum** 3 tiles,
maximum 1" — unreachable. The failure is silent: no error at authoring time, no error at load time,
only `skill.target.range` on every attempt to use the skill.

## Why this went unnoticed

The e2e/goja scenarios that pass all use the **structured** form (e.g.
`Range: { value: 0, max: 20 }` in `e2e_credit_economy.js`), which sets both bounds correctly. Only
the seeded catalog uses bare ints — and no test ever exercised a seeded skill (the same blind spot
behind ISS-140). Sprint's fix (this round) uses `{"value":1,"max":3}` and is not affected.

## Scope

- Decide the intended semantics of a bare-int `Range` and make it non-silent. Treating a bare int as
  `max` (with min defaulting to 0/1) matches author intent; alternatively reject bare ints for
  `IntCounter` keys outright. Either way, **an inverted window must never be silently constructible**
  — per CODING_RULE §3 this should fail loudly, not degrade to "targets nothing".
- Fix the four affected seed rows.
- Consider validating `value <= max` for every `IntCounter` at ingestion.
- Add coverage that runs seeded payloads through the real bridge and asserts a usable range window —
  `upsilonapi/bridge/sprint_reposition_test.go` (added this round) is the pattern to follow.

## Notes

Found by the executor fixing Sprint (ISS-140 follow-on) and confirmed against source. Related:
**ISS-156** (no authoring-time registry validation — the same class of "accepted now, fails later"),
**ISS-140**.

## Resolution — settled 2026-09-02, IN PROGRESS

**User ruling:** a bare-int `"Range": N` resolves to **`value 0, max N`**. The structured form
`"Range": {"value": X, "max": Y}` is left **exactly as-is**.

Consequences for the seeded catalog — **no seed row is edited**; the same stored JSON simply resolves
correctly once the interpretation is fixed:

| Skill | Seeded | Was | Becomes |
|---|---|---|---|
| Fireball | `"Range":3` | `[3,1]` unusable | `[0,3]` |
| Heal | `"Range":2` | `[2,1]` unusable | `[0,2]` |
| Lightning Strike | `"Range":2` | `[2,1]` unusable | `[0,2]` |
| Shield Bash | `"Range":1` | `[1,1]` | `[0,1]` |
| Regen Aura | `"Range":0` | `[0,1]` | `[0,0]` (self-only, correct for an aura) |
| Sprint | `{"value":1,"max":3}` | `[1,3]` | `[1,3]` **unchanged** |

Leaving the structured form untouched is load-bearing, not incidental: **Sprint requires `min 1`**.
`checkReposition` rejects a zero direction vector (`skill.reposition.nodirection`), so a minimum of 0
would let a player aim a dash at their own tile and re-break it.

**Scoping constraint recorded during blast-radius analysis:** the fix must be gated on the `Range`
property specifically, **not** on "IntCounter with no Max". `setSkillPropValue` is shared by the item
path (`bridge_start.go:234`, `bridge_resurrect.go:220`, both `ScopeItem`), where a bare-int
`{"HP":5}` must keep meaning `value=5`; a blanket rule would rewrite it to `value=0,max=5` and zero
out every item stat bonus. `Range` is registered `ScopeSkill` only
(`registry_skill_targeting.go:14`), so gating on it is inherently safe.

**Still open after this fix** (deliberately out of scope, do not consider ISS-157 to cover them):
the bare-int interpretation of the other Skill-scope `IntCounter` keys — `Delay`, `Channeling`,
`Cooldown`, `Duration` — is unreviewed and may carry the same min/max inversion.
