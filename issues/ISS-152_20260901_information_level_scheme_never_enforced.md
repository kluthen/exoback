# Issue: The `InformationLevel` / `MinInfoLevel` per-property visibility scheme has no enforcement point on the live path — it is configured across the registry but never consulted

> **Maintainer ruling 2026-09-01**: the RETIRE option below is **withdrawn**. This scheme **will be
> wired in and enforced** — deferred, not cancelled ("issue 152 will be wired (just not now)"). The
> WIRE IT IN path in Recommended Fix is the decided direction; scheduling is a future round, not this
> one. Consequence for whoever picks this up: the work is **additive enforcement**, not deletion.
> `UserFriendlyGet` still has zero callers umbrella-wide, and `convertProperty`
> (`upsilonapi/api/output.go:391-394`) still serializes the raw `v.Get()` with no `InformationLevel`
> parameter — that call path is where enforcement has to land. The Risk Assessment below — "Low,
> deliberately not inflated, NOT a live exposure" — **remains correct today**, precisely because the
> scheme is still inert; leave it as written. But **the moment enforcement is wired, every
> `MinInfoLevel` value in the registry and in `PropertiesForCharacter` becomes load-bearing**, and any
> value that is wrong today (see ISS-151) becomes a real exposure then. See the Change Log entry
> below.

**ID:** ISS-152_20260901_information_level_scheme_never_enforced
**Ref:** ISS-152
**Date:** 2026-09-01
**Severity:** Low
**Status:** Open
**Component:** `upsilontypes/property/property.go`
**Affects:**
- `upsilontypes/property/property.go:17-33` — `InformationLevel` enum (`Public=0` … `GameMaster=9`)
- `upsilontypes/property/defaultproperty/defaultproperty.go` (~lines 28-40, 128-140, 209-220, 288+) — `Name()`/`UserFriendlyGet()`, the only places the level is compared
- `upsilontypes/property/def/item.go:88-96` — `EffectProperty.Name`/`UserFriendlyGet`, same pattern
- `upsilonapi/api/output.go:394` — `convertProperty`, the actual wire-serialization boundary; calls `v.Get()` with no level parameter
- `upsilonapi/api/output.go:198-233` — `NewEntity`, builds the DTO from raw `GetPropertyI(...).I()`
- `upsilonhub/internal/games/battle/masking.go` — the real, working per-recipient protection (not this scheme)
- `upsilonhub/internal/gateway/sse/sse.go:150-158`, `upsilonhub/internal/gateway/game.go:79` — masking call sites
- `issues/ISS-151` — subordinate to the decision made here
- `issues/ISS-077` — the designed-but-unimplemented inspection feature that would make this scheme relevant

---

## Summary

`InformationLevel` (`property.go:17-33`) is an ordered visibility scale — `Public=0` through
`GameMaster=9` — and every property in the registry declares a `MinInfoLevel`. The mechanism for
using it, `UserFriendlyGet(level)`, gates a property's *value* by comparing the caller's level against
that minimum. **It has zero call sites in the entire umbrella** outside its own interface declaration
and a debug-only `PrettyPrint` helper. The actual wire path (`convertProperty`, `NewEntity`) never
passes a viewer identity into the property layer at all — it calls the unguarded `Get()` /
`GetPropertyI(...).I()` instead. Every property the registry marks `FriendlyController` — Movement,
Attack, Defense, AttackRange, JumpHeight, Shield, Poison, Stun, and the skill targeting/effect/cost
families — is serialized to every recipient unmasked by this scheme.

**No ATD atom governs the enum.** `docs/*.atom.md` has nothing for `InformationLevel`,
`MinInfoLevel`, or `FriendlyController`. Consistent with there being no real enforcement point to
atomize — contrast `module_foe_loadout_masking`, which *is* atomized because it is real.

---

## Problem Scenario

### The scale and its one real consumer

`property.go:17-33`:

```go
type InformationLevel int

const (
	Public             InformationLevel = 0
	ArenaObserver      InformationLevel = 1
	ForeignController  InformationLevel = 2
	FriendlyController InformationLevel = 3

	OwnController InformationLevel = 4

	Analyser          InformationLevel = 5
	ExpertAnalyst     InformationLevel = 6
	SpecialistAnalyst InformationLevel = 7
	MasterAnalyst     InformationLevel = 8

	GameMaster InformationLevel = 9
)
```

`UserFriendlyGet` — the only method that gates a *value* rather than a name — is implemented per
property kind, e.g. `def/item.go:88-96`:

```go
func (bh *EffectProperty) UserFriendlyGet(i property.InformationLevel) interface{} {
	if i >= bh.minInformationLevel {
		return bh.Effect
	}
	return nil
}
```

But grepping the umbrella for `UserFriendlyGet(` call sites finds only:
- `property.go:37` — the interface declaration itself
- `property.go:49` — `PrettyPrint`, a debug-only formatter

Zero production or serialization call sites.

### The actual wire boundary bypasses the scale entirely

`upsilonapi/api/output.go:391-399`:

```go
func convertProperty(v property.Property) PropertyDTO {
	dto := PropertyDTO{}
	val := v.Get()   // <-- raw internal value, no level parameter at all
	switch t := val.(type) {
	case int:
		dto.Value = &t
	...
```

`v.Get()` has no notion of a viewer. `NewEntity` (`output.go:198-233`) is the same shape — it reads
`ent.GetPropertyI(property.Attack).I()` etc. directly. Every `.Name(level)` call site in non-test
code (used only for map-keying, not value gating) passes `property.GameMaster` or
`property.OwnController` — i.e. always "reveal everything." No viewer identity of any kind reaches
the property layer on the path that actually produces client-visible JSON.

### What DOES work — read this before concluding "we have no privacy"

`upsilonhub/internal/games/battle/masking.go` provides real, **per-recipient** protection, applied
once per SSE subscriber (`gateway/sse/sse.go:150-158`) and once per REST request
(`gateway/game.go:79`). The fan-out is **not** a shared broadcast — each recipient gets their own
masked copy. It strips `current_player_id`, `id`, `player_id`, `_atd_meta`, and — for foes only —
`equipped_skills`, `equipped_items`, `buffs` (`masking.go:99-101`). This is **stricter than
"friendly"**: loadout is hidden from teammates too, keyed on exact ownership, not team.

Ownership/authorization are **sound**. A shared `*HTTPController` actor is reused for all human
players (`upsilonapi/bridge/bridge_start.go:299-304`) — a deliberate, documented transport
consolidation — but per-player identity is **not** collapsed: `entity.ControllerID` is the real
per-account `playerID` (`bridge_start.go:163`, `bridge_start_archetype.go:163`), and both `is_self`
masking and the `ownsEntity` action check (`gateway/game.go:239-247`) key off per-account fields.

`TeamID` is **not** consulted for visibility anywhere; its only masking use is cosmetic display in
`maskTurns` (`masking.go:111-130`).

---

## Risk Assessment

**Low — and deliberately not inflated. This is NOT a live exposure.** There is no inspection
mechanism today by which one player could request another player's character data (ISS-077 designed
this, but it is unimplemented), and the genuinely sensitive payload — loadout — **is** protected by
`masking.go`. What is currently visible to all viewers is enemy HP/Attack/Defense/Movement, which for
a tactical game is **plausibly correct by design** — it is simply never written down as one.

Frame this as **dead weight / latent defence-in-depth**: a per-property visibility scale configured
across the entire registry that enforces nothing, whose real danger is that a future maintainer sees
`MinInfoLevel: FriendlyController` on a property and *trusts* it to already be gating something. It
becomes materially relevant the moment an inspection/observer/spectator feature (ISS-077 or similar)
lands and someone reaches for this scheme assuming it already works.

---

## Recommended Fix

Two mutually exclusive options. This is a product decision, not just an engineering one — present
both, do not implement either without a ruling.

### (a) RETIRE — **orchestrator's recommendation**

Remove `InformationLevel`/`MinInfoLevel` as dead weight; keep field-name masking (`masking.go`) as the
intended, actually-working design. Update `architecture/property_key_vocabulary.md` to stop implying
enforcement (its `Min info level` column currently reads as if it does something).

- **Cost:** loses a finer-grained per-property model than the current field-name rules provide.
- **Benefit:** cheap, honest, removes the trap for a future maintainer.

### (b) WIRE IT IN

Thread a real viewer level into `masking.go`'s per-entity pass: `OwnController` if `is_self`,
`FriendlyController` if same team, else `Public`. Requires promoting `TeamID` from cosmetic
(`maskTurns`) to a real gating predicate in the entity-masking path — it is display-only today.

- **Cost / consequence:** this is a **gameplay-visible balance change** — hiding enemy stats
  (HP/Attack/Defense/Movement) alters tactical information available to the player. It is not a pure
  refactor and needs a product decision, not just an engineering one.

### Sequencing note

`issues/ISS-151` (the `PropertiesForCharacter` vs. registry `MinInfoLevel` mismatch) is
**subordinate to this decision**. If (a) is chosen, ISS-151 likely dissolves — there is no
authoritative level left to contradict. If (b) is chosen, ISS-151 becomes a real bug to fix.

---

## References

- `upsilontypes/property/property.go:17-49` — `InformationLevel` enum, `UserFriendlyGet`, `PrettyPrint`
- `upsilontypes/property/defaultproperty/defaultproperty.go` — per-kind `Name`/`UserFriendlyGet` implementations, unused on the wire path
- `upsilonapi/api/output.go:198-233,363-399` — the actual serialization boundary (`NewEntity`, `convertPropertyMap`, `convertProperty`)
- `upsilonhub/internal/games/battle/masking.go` — the real, working masking layer
- `upsilonhub/internal/gateway/sse/sse.go:150-158`, `upsilonhub/internal/gateway/game.go:79` — masking call sites
- `upsilonapi/bridge/bridge_start.go:163,299-304`, `upsilonapi/bridge/bridge_start_archetype.go:163` — per-account `ControllerID` assignment, shared-controller consolidation
- `upsilonhub/internal/gateway/game.go:239-247` — `ownsEntity`, the real per-account ownership check
- `architecture/property_key_vocabulary.md` — declares `Min info level` per key with no enforcement behind it
- `issues/ISS-077_20260423_skill_inspection.md` — the designed-but-unimplemented feature that would make this scheme relevant
- `issues/ISS-151_20260901_properties_for_character_public_vs_registry_minlevel.md` — subordinate to this decision

---

## Change Log

- **2026-09-01** — Filed. Verified against source: `UserFriendlyGet` has zero non-declaration,
  non-debug call sites umbrella-wide; the wire boundary (`output.go` `convertProperty`/`NewEntity`)
  never passes a viewer level; `masking.go` provides real, sound, per-recipient field-name masking
  independent of this scheme. Explicitly framed as latent dead weight, not a live exposure, per
  instruction not to inflate severity.
- **2026-09-01** — Maintainer ruling: RETIRE is withdrawn; WIRE IT IN is the decided path, deferred
  to a future round (not this one). Reframed from "product decision, present both options" to
  "scheduled enforcement work." Current Low severity and "not a live exposure" framing left
  unchanged — both remain true while the scheme stays inert — but flagged that every `MinInfoLevel`
  value becomes load-bearing once enforcement lands, making ISS-151's mismatch a real future
  exposure rather than a moot one. Severity not re-rated.
