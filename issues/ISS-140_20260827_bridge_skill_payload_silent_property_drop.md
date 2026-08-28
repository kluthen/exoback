# Issue: The engine bridge silently drops unrecognized/unusable skill properties instead of erroring

**ID:** `20260827_bridge_skill_payload_silent_property_drop`
**Ref:** `ISS-140`
**Date:** 2026-08-27
**Severity:** High
**Status:** Open
**Component:** `upsilonapi/bridge/bridge_utils.go` (`buildSkillEffect`, `buildSkillPropertyMap`, `setSkillPropValue`)
**Affects:** `upsilonapi/bridge/bridge_start.go` (arena start), `upsilonapi/bridge/bridge_resurrect.go` (arena resurrection),
every skill Targeting / Costs / Effect payload authored through `admin_skill_template_create`,
`upsiloncli/tests/scenarios/e2e_friendly_fire_skill_test.js`, `upsiloncli/tests/scenarios/edge_attack_skill_cooldown.js`

---

## Summary

When the bridge rehydrates a stored skill into engine state, any property key it does not
recognize — and any recognized key whose value it cannot apply — is dropped with no error,
no log, and no signal to the caller. The engine then falls back to that property's *default*,
so the skill runs with semantics the author never wrote. This violates CODING_RULE §3
(crash early / fail fast — no silent failures) and §4 (strict API contract adherence — no
defaulting to "save the day"): a malformed payload is a contract violation on the wire and
must be loud, not absorbed.

This is not hypothetical. Two committed E2E scenarios author `effect: { Type: "Damage", Value: N }`
— a shape the bridge does not understand at all. Both keys are dropped, the effect ends up
empty, and the engine substitutes the default `Damage` of **100%** of Attack. The scenarios
pass, because neither asserts on a damage amount, while casting a skill 10–20× stronger than
the one written in the test.

> **BLOCKED BY `ISS-142`.** Once the bridge rejects malformed payloads, every match started with
> a seeded skill fails at arena start — all six templates in `upsilonhub/internal/seed/seed.go:59-64`
> are malformed in all three property maps. `ISS-142` must land first. See
> `issues/ISS-142_20260827_skill_originated_attribute_buffs_unsupported.md`.

---

## Technical Description

### Background

`admin_skill_template_create` stores a skill's `targeting`, `costs`, and `effect` as free-form
JSON property maps. At arena start (and at resurrection) the bridge converts each map back into
typed engine properties by resolving every key against the `SkillProperties` registry. The
expected shape is flat — property name → value — for all three maps:

```js
targeting: { TargetType: "EnemyOnly", Range: { value: 0, max: 30 } }
costs:     { MPLeech: 5 }
effect:    { Damage: 5000 }
```

### The Problem Scenario

There are **two** distinct silent-drop paths, and both exist in **both** builders:

**Path A — unrecognized key** (`bridge_utils.go:99` and `:119`)

```go
prop := def.SkillProperty(property.SkillProperties(key))
if prop == nil {
    // Skip unknown properties to avoid engine initialization failures.
    continue
}
```

`def.SkillProperty` (`upsilontypes/property/def/skill.go:328`) is a closed switch over the
`SkillProperties` enum with a bare `return nil` at the bottom. Anything not in that switch —
a typo, a renamed property, a wrong-shaped payload — yields `nil` and is discarded.

**Path B — recognized key, unusable value** (`bridge_utils.go:43-90`)

`setSkillPropValue` returns `hasValue = false` when the DTO carries no field the property can
consume (e.g. an int sent to a `BoolProperty`). The builders then simply do not append it —
same silence, but now for a key the registry *did* recognize.

Walk-through of the live defect:

1. A scenario authors `effect: { Type: "Damage", Value: 10 }`.
2. `buildSkillEffect` resolves `"Type"` → `nil` → `continue`. Resolves `"Value"` → `nil` → `continue`.
3. `eff.Properties` is empty. The skill is registered and the match starts normally.
4. `effectapplicator.go:120` reads `getPropertyOrDefaultI(eff, property.Damage).I()`.
5. Absent → `def.Damage()` default = **100**. The skill deals 100% of Attack, not 10%.

Nothing anywhere reports that the authored payload was not the payload that ran.

The blast radius is wider than `effect`. `buildSkillPropertyMap` feeds both **Targeting** and
**Costs** (`bridge_start.go:247-248`, `bridge_resurrect.go:211-212`), so the same silence turns
a dropped `Range` into default range 1 (a long-range skill becomes melee) and a dropped cost
into a free skill.

### Where This Pattern Exists Today

- `upsilonapi/bridge/bridge_utils.go:99-102` — Path A in `buildSkillPropertyMap`
- `upsilonapi/bridge/bridge_utils.go:119-122` — Path A in `buildSkillEffect`
- `upsilonapi/bridge/bridge_utils.go:43-90` — Path B in `setSkillPropValue` (`hasValue` false → caller drops)
- `upsilonapi/bridge/bridge_utils.go:92` — the doc comment states the behaviour as a feature:
  *"Unknown keys are silently skipped to ensure robustness."*
- `upsilontypes/property/def/skill.go:328-391` — the closed switch whose `return nil` is the trigger
- Consumers: `upsilonapi/bridge/bridge_start.go:206,247-249`; `upsilonapi/bridge/bridge_resurrect.go:211-213`

Known bad payloads already committed:

- `upsiloncli/tests/scenarios/e2e_friendly_fire_skill_test.js:26` — `effect: { Type: "Damage", Value: 10 }`
- `upsiloncli/tests/scenarios/edge_attack_skill_cooldown.js:36` — `effect: { Type: "Damage", Value: 5 }`

Both currently pass. `e2e_friendly_fire_skill_test` asserts only pre-damage targeting rejection
(`skill.target.none`); `edge_attack_skill_cooldown` asserts only cooldown gating. Neither
observes a damage amount, which is exactly why the drop has gone unnoticed.

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | **High** — already triggered by two committed scenarios; any admin-authored typo triggers it |
| Impact if triggered | **High** — the skill that runs is not the skill that was authored; balance, targeting and cost semantics all silently substituted |
| Detectability | **Low** — no error, no log, no envelope signal. It surfaces only as unexplained combat numbers, and only if a test happens to assert on an amount. It also actively poisons test evidence: a suite can be green while exercising the wrong skill |
| Current mitigant | None. The behaviour is documented as intentional robustness at `bridge_utils.go:92` |

---

## Recommended Fix

**Short term (this is the fix the user asked for — make it loud):**
Replace both `prop == nil → continue` branches with a hard error. The bridge is a contract
boundary: an unresolvable property name is a malformed payload and must be rejected, not
absorbed. `setSkillPropValue` returning `false` for a recognized key must be treated the same
way — a value the property cannot consume is equally a contract violation.

Both builders currently return values with no error channel (`map[string]property.Property`
and `effect.Effect`), so this is a signature change rippling to the call sites in
`bridge_start.go` / `bridge_resurrect.go`, which must fail the start/resurrect with a clear
`error_key` naming the offending key(s).

**Verified ripple depth (2026-08-27): 5 hops, terminating cleanly at two HTTP handlers.** Four
currently-`void` functions must gain error returns —
`registerEntitySkill` (`bridge_start.go:235`), `applyItemAsBuff` (`bridge_start.go:192`),
`restoreEntitySkills` (`bridge_resurrect.go:201`), `restoreEntityBuffs` (`bridge_resurrect.go:166`)
— propagating through `addExplicitEntity` (`bridge_start.go:155`) and `dtoToEntity`
(`bridge_resurrect.go:142`), both of which already return errors, up to
`HandleArenaStart` (`handler/handler.go:20-40`) and `HandleArenaResurrect`
(`handler/handler.go:138-158`), which already wrap errors as 400 + envelope. No handler signature
changes are required. Per CODING_RULE §3 a clear failure beats undefined
behaviour; per §4 the envelope is a hard contract.

Also delete the `bridge_utils.go:92` comment that blesses the silence, so the intent is not
reintroduced.

**Any deliberate exception must be explicitly annotated.** If a specific key genuinely must be
tolerated (e.g. a forward-compatibility allowance for a property the engine has not shipped
yet), it belongs on an explicit allow-list with a comment stating why — never as a catch-all
`continue`.

**Also in scope — two adjacent defects of the same class, in the same file (added 2026-08-27):**

1. **`parseBehaviorType` silently defaults** (`bridge_utils.go:22-37`). Its switch ends in
   `default: return def.BehaviorTypeDirect`, so an unknown or misspelled `behavior` string
   silently becomes `"Direct"` — a skill authored as `Reaction`, `Passive`, `Counter` or `Trap`
   can be registered as something else entirely, with no signal. This is the same §3/§4 violation
   as the property drop, in the same file, in a function that already carries the
   `@spec-link [[mechanic_skill_payload_resolution]]`. It must fail loudly on an unrecognized
   behavior instead of defaulting.

2. **`propertyAliasMap` must become an explicit, annotated allow-list** (`bridge_utils.go:12-16`).
   The three aliases (`ArmorRating`->`Armor`, `CritChance`->`CriticalChance`,
   `CritDamage`->`CriticalMultiplier`) must keep resolving at API level — the frontend and hub
   actively speak that vocabulary, so removing them here would break character stat display. But
   the map must carry a comment stating plainly that it is **closed, frozen, not to be extended,
   and slated for removal**, with a pointer to `ISS-143` which owns the rename. Everything outside
   those three entries fails, per the collect-all rule above.

   Note the map is currently applied **only** in the item/buff paths (`bridge_start.go:217`,
   `bridge_resurrect.go:186`), not in `buildSkillPropertyMap`/`buildSkillEffect`. Preserve that
   asymmetry deliberately or the collect-all will emit false rejections for legitimate item keys.

**Error strategy — COLLECT-ALL (user ruling, 2026-08-27):**
On a malformed payload, gather **every** offending key in one pass and report them together;
do not fail on the first. Rationale: the post-fix suite re-run is an explicit discovery pass, and
failing one key at a time turns it into whack-a-mole where each fix reveals the next key in the
same payload. The envelope convention already exists — `api.NewError` / `api.NewErrorWithKey`
(`upsilonapi/api/output.go:147-180`), with the machine-readable code carried in `meta.error_key`.

**Also fix the `@spec-link` placement.** `bridge_utils.go:3` carries
`@spec-link [[mechanic_skill_payload_resolution]]` at the **file header, before the import block**.
Links belong atop functions only. `upsilonbattle/battlearena/ruler/rules/attack.go` is the correct
contrast case. Move it to the function(s) it actually describes while editing this file.

**Medium term:**
Validate the payload at *authoring* time, in `admin_skill_template_create`, so a bad template
is rejected on write rather than at match start. Failing at start time is loud but late: the
bad row is already persisted and the player sees a broken match.

**Long term:**
Replace the free-form `PropertyMap` on the wire with a typed, schema-validated skill payload so
an unknown key cannot be expressed at all. Unblocks the same class of defect as ISS-106.

**Fix the two bad scenarios** (`e2e_friendly_fire_skill_test.js:26`,
`edge_attack_skill_cooldown.js:36`) to `effect: { Damage: N }`. Note this is a prerequisite for
the short-term fix, not optional cleanup: once the bridge errors loudly, both scenarios fail.

---

## Extra Data

Found on 2026-08-27 while hardening `upsiloncli/tests/scenarios/e2e_credit_economy.js` to make
damage infliction independent of spawn distance. The corrected scenario uses the flat shape
`effect: { Damage: 5000 }` and works; the discrepancy against the two older scenarios is what
exposed the drop.

Per CODING_RULE §5 (test-first on bugs), the fix should start from a failing test at
`upsilonapi/bridge` level: feed `buildSkillEffect` a payload with an unknown key and assert it
errors, rather than returning an empty effect.

ATD: the correction touches the engine bridge's payload contract — check
`upsilonapi/docs/api_go_battle_start.atom.md` and `upsilonapi/docs/domain_skill_system.atom.md`
for the governing atom before changing behaviour, and settle it first if the contract is not
already written down.

---

## References

- `upsilonapi/bridge/bridge_utils.go` — the three silent-drop paths
- `upsilontypes/property/def/skill.go:328` — `SkillProperty` closed switch returning `nil`
- `upsilontypes/property/propertyenum.go:56-105` — the valid `SkillProperties` key set
- `upsilonbattle/battlearena/property/effect/effectapplicator/effectapplicator.go:120` — the default substitution that hides the drop
- `upsilonapi/bridge/bridge_start.go:206,247-249`, `upsilonapi/bridge/bridge_resurrect.go:211-213` — call sites
- `issues/ISS-106_20260709_php_empty_array_skill_payload_start_failure.md` — adjacent defect in the same payload path (PHP-era `[]` empty property maps)
- `CODING_RULE.md` §3 (crash early / fail fast), §4 (strict API contract adherence)

---

## Change Log
- **2026-08-27**: Scope refined after blast-radius investigation. (a) Error strategy set to
  **collect-all** rather than fail-on-first, per user ruling. (b) Added `parseBehaviorType`'s
  silent `default: Direct` as an in-scope defect of the same class. (c) Added the
  `propertyAliasMap` annotation requirement; full removal split out as `ISS-143`. (d) Added the
  `bridge_utils.go:3` file-header `@spec-link` placement fix. (e) Recorded the verified 5-hop
  ripple and the four void functions needing error returns. (f) **Marked BLOCKED BY `ISS-142`** —
  the seeded skill templates are all malformed and would break every match start once this lands.
  (g) Corrected a misreading raised during investigation: the nested
  `Range: { value, max }` shape used by the scenarios is **legal** (it maps to an
  IntCounterProperty via `PropertyDTO`'s `Value`+`Max` handling) and must not be "fixed" — only
  the `effect: { Type, Value }` line is wrong in those two files.
- **2026-08-27**: Noted interaction with `ISS-136` — `e2e_friendly_fire_skill_test.js` is already
  tracked as non-deterministically flaky, and this fix edits line 26 of that same file. A failure
  after the edit may be the pre-existing flake rather than a regression; equally, one green run is
  not proof.
