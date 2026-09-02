# Issue: `PropertiesForCharacter` builds five properties at `Public`, contradicting the registry's declared `MinInfoLevel`

> **Maintainer ruling 2026-09-01**: ISS-152's RETIRE option is withdrawn — the `InformationLevel`
> scheme **will be wired in and enforced**, deferred to a future round. That kills the assumption
> under which this issue's "security theatre" framing and "blocked by / subordinate to ISS-152"
> status were correct (see the dated notes inline below, at the Risk Assessment and Recommended Fix
> sections — the original text is left intact, not deleted). With enforcement decided,
> `PropertiesForCharacter` building `HP`/`Movement`/`SP`/`MP`/`Shield`/`Attack`/`AttackRange`/
> `Defense`/`JumpHeight` at `property.Public` where the registry says `FriendlyController` **stops
> being cosmetic and becomes a real over-exposure at wire-in time**. This issue flips from "security
> theatre, don't bother" to **a prerequisite that must be corrected before or as part of the ISS-152
> wire-in**, or the wire-in ships an exposure on day one. It remains sequenced *after* ISS-152's
> design work — this constructor is still test/dev-only and nothing reads `MinInfoLevel` today, so no
> standalone hardening is warranted yet — but the *reason* to keep it open changes from "subordinate,
> maybe moot" to **"blocking prerequisite for a decided piece of work."** A future reader must not
> skim the old "security theatre" line below and close this as won't-fix. See the Change Log entry.

**ID:** ISS-151_20260901_properties_for_character_public_vs_registry_minlevel
**Ref:** ISS-151
**Date:** 2026-09-01
**Severity:** Medium
**Status:** Open
**Component:** `upsilontypes/property/def/entity.go`
**Affects:**
- `upsilontypes/property/def/entity.go:91-107` — `PropertiesForCharacter()`, the constructor at fault
- `upsilontypes/property/def/registry_entity_movement.go:14` — the registry's `MinInfoLevel: property.FriendlyController` for `Movement`
- `architecture/property_key_vocabulary.md` §3 row 2 — the frozen vocabulary, also `FriendlyController`
- `issues/ISS-152` — **this issue is subordinate to it**; see Recommended Fix

---

## Summary

`PropertiesForCharacter()` (`upsilontypes/property/def/entity.go:91-107`) constructs `Movement`,
`Attack`, `AttackRange`, `Defense` and `JumpHeight` with `property.Public` as their information level.
The registry (`registry_entity_movement.go:14`) and the frozen vocabulary
(`architecture/property_key_vocabulary.md` §3 row 2) both declare `Movement` — and, by the same
pattern, the other four keys — as `MinInfoLevel: property.FriendlyController`. The constructor and
its own registry entry disagree on the level.

**This is a consistency/correctness defect only. It must not be read or fixed as a security
hardening measure** — see the framing below.

---

## Problem Scenario

`entity.go:91-107`:

```go
// note: futher properties may be added per entity basis.
func PropertiesForCharacter() []property.Property {
	return []property.Property{
		defaultproperty.MakeIntCounterProperty(property.HP, 10, 10, property.Public, property.Character),
		defaultproperty.MakeIntCounterProperty(property.Movement, 3, 3, property.Public, property.Character),
		defaultproperty.MakeIntCounterProperty(property.SP, 10, 10, property.Public, property.Character),
		defaultproperty.MakeIntCounterProperty(property.MP, 10, 10, property.Public, property.Character),
		defaultproperty.MakeIntCounterProperty(property.Shield, 0, 0, property.Public, property.Character),
		defaultproperty.MakeIntProperty(property.Attack, 3, property.Public, property.Character),
		defaultproperty.MakeIntProperty(property.AttackRange, 1, property.Public, property.Character),
		defaultproperty.MakeIntProperty(property.Defense, 0, property.Public, property.Character),
		defaultproperty.MakeIntProperty(property.JumpHeight, 2, property.Public, property.Character),
		defaultproperty.MakeIntProperty(property.IsDying, -1, property.Public, property.Character),
		defaultproperty.MakeIntProperty(property.TeamID, 0, property.Public, property.Character),
		defaultproperty.MakeBoolProperty(property.HasMoved, false, property.GameMaster, property.Character),
		defaultproperty.MakeBoolProperty(property.HasActed, false, property.GameMaster, property.Character),
	}
}
```

Against `registry_entity_movement.go:8-22`:

```go
property.Movement: {
	Key: property.Movement, Scopes: ScopeItem | ScopeEntity, Kind: KindIntCounter, Composition: CompositionAdd,
	MinInfoLevel: property.FriendlyController, New: func() property.Property { return Movement() },
},
...
property.JumpHeight: {
	Key: property.JumpHeight, Scopes: ScopeItem | ScopeEntity, Kind: KindInt, Composition: CompositionAdd,
	MinInfoLevel: property.FriendlyController, New: func() property.Property { return JumpHeight() },
},
```

Five keys diverge this way: `Movement`, `Attack`, `AttackRange`, `Defense`, `JumpHeight`. It is a
small family, not a single stray line.

### Blast radius: none in production

`PropertiesForCharacter` is **test/dev-only**: all 16 of its callers are `_test.go` files. It is not
on any production entity-construction path. Production entity construction goes through
`bridge_start.go`, `bridge_start_archetype.go`, and `bridge_resurrect.go` (in `upsilonapi/bridge/`),
which set properties explicitly and do not call this function.

### The two constructors were each half-right before today

Both `PropertiesForCharacter` and the standalone `Movement()` constructor diverged from the frozen
`3/3` @ `FriendlyController` spec, but in complementary ways:

- `Movement()` had the wrong **value** (constructed `5/5` against the documented and now-frozen
  default of `3/3`) but the right **level** (`FriendlyController`, matching the registry). Fixed
  today (2026-09-01) to `3/3`.
- `PropertiesForCharacter` has the right **value** (`3/3`, and correct values for the other four
  keys) but the wrong **level** (`Public` instead of `FriendlyController`).

---

## Risk Assessment

**Low.** No production exposure — see Blast radius above. The risk is purely representational: a
test/dev-only entity constructor that silently disagrees with its own registry's declared visibility
level, which could mislead a future reader auditing property visibility, or produce test fixtures
whose masking behavior (if the registry level were ever wired to something real) would not match
production entity construction.

**Critical framing:** raising the constructor's level to `FriendlyController` would close **zero**
live exposure. Per ISS-152, `MinInfoLevel` is never consulted on any serialization path today — the
value that ships to clients comes from `convertProperty`'s raw `v.Get()`
(`upsilonapi/api/output.go:394`), which does not take an information level at all. Treating this fix
as a security improvement would be **security theatre**: it changes a value nothing reads.

> **2026-09-01 — reframed by maintainer ruling on ISS-152:** the "security theatre" verdict above
> held only because ISS-152's retirement was still on the table — if the scheme were retired, this
> `MinInfoLevel` mismatch would indeed be a value nothing reads. That assumption is now dead: ISS-152
> is ruled to be **wired in and enforced** (deferred, not cancelled). It remains true *today* that
> nothing reads this value, so this is still not a *current* exposure — but once enforcement lands,
> these five properties (`HP`/`Movement`/`SP`/`MP`/`Shield`/`Attack`/`AttackRange`/`Defense`/
> `JumpHeight`, all at `Public` here against a registry `MinInfoLevel` of `FriendlyController`) become
> a real over-exposure on day one of wire-in. Do not read the paragraph above as the final word.

---

## Recommended Fix

> **2026-09-01 — reframed by maintainer ruling on ISS-152:** "blocked by / subordinate to" below was
> written when ISS-152 retirement was live and step 2 ("if retired, this issue likely dissolves") was
> a real possible outcome. It is no longer: ISS-152 is ruled to be wired in, not retired. Step 2 is
> now dead — read the sequencing as step 1 → step 3 only. This issue is no longer "subordinate,
> possibly moot"; it is a **blocking prerequisite** for the ISS-152 wire-in — the wire-in must not
> ship without this fix landing first or alongside it, or it exposes HP/Movement/SP/MP/Shield/Attack/
> AttackRange/Defense/JumpHeight beyond `FriendlyController` on day one. The sequencing direction
> (settle/design ISS-152 before touching these values) is unchanged — this is still not a standalone
> hardening to do today.

**Blocked by / subordinate to ISS-152.** Do not fix this in isolation. The correct sequencing:

1. **Settle ISS-152 first** — decide whether the `InformationLevel`/`MinInfoLevel` scheme is retired
   or wired into `masking.go` as a real gate.
2. **If retired:** this issue likely **dissolves** — there would be no authoritative `MinInfoLevel`
   for `PropertiesForCharacter` to contradict, and the constructor's `Public` argument becomes inert
   metadata like the rest of the (retired) scheme.
3. **If wired in:** fix `PropertiesForCharacter` to pass `property.FriendlyController` for the five
   affected keys (`Movement`, `Attack`, `AttackRange`, `Defense`, `JumpHeight`), matching the
   registry and the frozen vocabulary, and add a conformance check (in the spirit of the constant/
   string-value conformance test already used for the key-identity invariant) so registry and
   constructor cannot silently diverge again.

Short term: no code change recommended until ISS-152 is decided — file for awareness only.

---

## References

- `upsilontypes/property/def/entity.go:91-107` — `PropertiesForCharacter`
- `upsilontypes/property/def/registry_entity_movement.go:8-22` — registry entries for `Movement`/`JumpHeight`
- `architecture/property_key_vocabulary.md` §3 — frozen ENTITY-scope table
- `issues/ISS-152_20260901_information_level_scheme_never_enforced.md` — the blocking decision

---

## Change Log

- **2026-09-01** — Filed. Verified against source: `PropertiesForCharacter` constructs `Movement`,
  `Attack`, `AttackRange`, `Defense`, `JumpHeight` at `property.Public`; the registry and the frozen
  vocabulary both declare `FriendlyController` for these keys. All 16 callers confirmed test-only.
  Explicitly scoped as consistency-only and made subordinate to ISS-152's retire-vs-wire decision.
- **2026-09-01** — Maintainer ruling on ISS-152 (RETIRE withdrawn, WIRE IT IN decided, deferred):
  reframed this issue's "security theatre" and "blocked by / subordinate to ISS-152" language, which
  assumed retirement was still possible. Also verified against source that `HP`/`SP`/`MP`/`Shield`
  (`registry_entity_vitals.go:12-33`) carry the same `MinInfoLevel: FriendlyController` divergence
  against `PropertiesForCharacter`'s `Public` as the originally-filed five keys — nine keys total,
  not five. Flipped framing from "don't bother, nothing reads this" to "blocking prerequisite for
  ISS-152's decided wire-in work" — the sequencing (fix lands with or before wire-in, not before
  design) is unchanged, but the risk story is no longer "possibly moot." Severity left at Low; a
  raise is recommended to the orchestrator for review, not applied here.
- **2026-09-01** — Severity raised **Low -> Medium** by the orchestrator, resolving the raise
  recommended in the previous entry. Rationale: with ISS-152's wire-in decided, this is no longer a
  cosmetic registry/constructor mismatch but a **prerequisite whose omission ships a real exposure**
  at enforcement time, across **nine** keys rather than the five originally filed. Held at Medium
  rather than higher because there is **no live exposure today** (the scheme is inert — `UserFriendlyGet`
  has zero callers) and the wire-in is explicitly deferred, so there is no urgency — only a hard
  ordering constraint. Matches ISS-153's rating for the same "decided future work, real consequence,
  no current breakage" shape.
