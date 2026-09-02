# Issue: The bridge's property alias map papers over a vocabulary mismatch and should be removed by rename

**ID:** `20260827_bridge_property_alias_map_should_be_removed`
**Ref:** `ISS-143`
**Date:** 2026-08-27
**Severity:** Medium
**Status:** Resolved
**Component:** `upsilonapi/bridge/bridge_utils.go` (`propertyAliasMap`, lines 12-16)
**Affects:** `upsilonapi/bridge/bridge_start.go:217` (`applyItemAsBuff`), `upsilonapi/bridge/bridge_resurrect.go:186`
(`hydrateSingleBuffProperty`), `upsilonbattleui/src/Composables/useCharacterStats.js:29,43,48-49`,
`upsilonhub/internal/gateway/resources.go:45-46`, `upsilonhub/internal/gateway/profile.go:199,215`,
`upsilonhub/internal/platform/character/characterpg/queries.sql.go`

---

## Summary

`upsilonapi/bridge/bridge_utils.go:12-16` carries a three-entry alias map that silently rewrites
incoming property keys before resolution:

```go
var propertyAliasMap = map[string]string{
	"ArmorRating": "Armor",
	"CritChance":  "CriticalChance",
	"CritDamage":  "CriticalMultiplier",
}
```

This is not a compatibility shim for a dead client — it reconciles a **live vocabulary mismatch**
between the engine, the hub, and the frontend. The correct end state is one name per property,
used everywhere, with anything else rejected (`CODING_RULE` §4 — strict API contract adherence,
no defaulting to "save the day"). Getting there is a coordinated cross-submodule rename, which is
why it is tracked separately from `ISS-140` rather than folded into it.

---

## Technical Description

### Background

`ISS-140` makes the bridge reject unrecognized skill/item property keys instead of dropping them
silently. During that work the alias map was reviewed and deliberately **retained as an explicit,
annotated allow-list** — the alias entries must keep resolving at API level so the frontend and
hub keep working. This issue tracks eliminating them properly.

### The Problem Scenario

Each alias hides a different kind of mismatch:

1. **`ArmorRating` -> `Armor` is a Go-identifier leak.** The constant is declared
   (`upsilontypes/property/propertyenum.go:153`) as:
   ```go
   ArmorRating ItemProperties = "Armor"   // Absence means 0: no armor (only for Wearable)
   ```
   The **wire name is `Armor`**; `ArmorRating` is the Go identifier spelling. The alias exists
   because callers wrote the identifier name rather than the value. `upsilonbattleui` says so
   outright at `useCharacterStats.js:29`:
   ```js
   ArmorRating: 0, WeaponBaseDamage: 0 // Aliases for engine parity
   ```

2. **`CritChance` / `CritDamage` are live first-class names in the hub**, not typos. They are
   character table columns (`characterpg/queries.sql.go`), exposed as `crit_chance` /
   `crit_damage` through the gateway (`resources.go:45-46`, `profile.go:199,215`), and mapped for
   display by the frontend (`useCharacterStats.js:48-49`). The engine's canonical
   `SkillProperties` spellings are `CriticalChance` / `CriticalMultiplier`
   (`propertyenum.go:75-76`).

So the same concept has two names, and the boundary between them is patched at the bridge rather
than resolved at the source.

### Asymmetry worth noting

The alias map is applied **only** in the item/buff paths (`bridge_start.go:217`,
`bridge_resurrect.go:186`). It is **not** applied in `buildSkillPropertyMap` or
`buildSkillEffect`. An aliased spelling therefore resolves as an item property but is rejected as
a skill property — inconsistent behaviour for the same string on the same wire.

### Where This Pattern Exists Today

- `upsilonapi/bridge/bridge_utils.go:12-16` — the map itself
- `upsilonapi/bridge/bridge_start.go:217`, `upsilonapi/bridge/bridge_resurrect.go:186` — the only application sites
- `upsilonbattleui/src/Composables/useCharacterStats.js:29,43,48-49` — frontend speaking the aliased vocabulary
- `upsilonhub/internal/gateway/resources.go:45-46`, `profile.go:199,215` — hub exposing `crit_chance`/`crit_damage`
- `upsilonhub/internal/platform/character/characterpg/queries.sql.go` — persisted column names

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | **Medium** — the aliases work today; the risk is drift, not breakage |
| Impact if triggered | **Medium** — a fourth alias gets added, or someone "fixes" a caller to the canonical name in one layer only and the mismatch silently splits |
| Detectability | **Medium** — post-`ISS-140` a non-aliased misspelling fails loudly; an aliased one still silently succeeds, so this specific class stays invisible |
| Current mitigant | Post-`ISS-140`: the map is an explicit, commented allow-list carrying a pointer to this issue, rather than an undocumented rewrite |

---

## Recommended Fix

**Short term (done as part of `ISS-140`):**
Keep the three aliases resolving so nothing breaks, but annotate the map explicitly: it is a
closed, frozen allow-list, **not to be extended**, slated for removal under this issue. Anything
outside it fails loudly.

**Medium term:**
Pick one canonical name per property and rename across the seam in a single coordinated change:
- `ArmorRating` -> `Armor` at every call site that currently writes the identifier spelling
- `CritChance`/`CritDamage` -> `CriticalChance`/`CriticalMultiplier`, or rename the engine
  constants to match the hub — one direction, chosen deliberately, applied everywhere
Includes `upsilonbattleui`, `upsilonhub` gateway DTOs, and any persisted column naming. Then
delete `propertyAliasMap` entirely.

**Long term:**
Generate the shared property vocabulary from a single source of truth consumed by engine, hub and
frontend, so a name can only exist in one spelling and a mismatch becomes a build error rather
than a runtime alias lookup.

---

## Extra Data

Raised 2026-08-27 during `ISS-140`'s blast-radius refinement. The user's ruling was: *"property
alias i don't like, either use the right name or fail"* — with the pragmatic caveat that the
aliases must keep being recognized at API level for now, and must carry a comment stating they
are not meant to be extended but removed. That short-term shape is implemented in `ISS-140`; this
issue owns the removal.

The blast radius is what makes this separate: deleting four lines in the bridge would break
character stat display in `upsilonbattleui` and the hub's `crit_chance`/`crit_damage` contract.

---

## References

- `upsilonapi/bridge/bridge_utils.go:12-16` — `propertyAliasMap`
- `upsilontypes/property/propertyenum.go:75-76,153` — canonical `CriticalChance`/`CriticalMultiplier` and the `ArmorRating = "Armor"` declaration
- `issues/ISS-140_20260827_bridge_skill_payload_silent_property_drop.md` — the fail-fast fix that retains this map as an annotated allow-list
- `CODING_RULE.md` §4 (strict API contract adherence)

## Change Log

- **2026-09-02 — RESOLVED** by the Property Key Space Unification round. `propertyAliasMap` is
  **deleted outright**; `grep -rn propertyAliasMap upsilonapi/` returns only three hits, all of them
  comments in `bridge/property_alias_test.go` documenting the removal. The map existed to paper over
  the three-way `EntityProperties`/`SkillProperties`/`ItemProperties` split; with the unified
  `property.Key` and the `def` registry as the single source of truth, there is nothing left to
  alias. `property_alias_test.go` was written first (CODING_RULE §5) and pins that the wire keys
  formerly needing an alias now resolve directly through the registry.
