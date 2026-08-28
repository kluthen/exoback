# Issue: Skills cannot apply attribute buffs — the engine path is unwired, and the seeded buff skills silently do something else

**ID:** `20260827_skill_originated_attribute_buffs_unsupported`
**Ref:** `ISS-142`
**Date:** 2026-08-27
**Severity:** High
**Status:** Open
**Component:** `upsilonbattle/battlearena/property/effect/effectapplicator/effectapplicator.go` (no buff support)
**Secondary:** `upsilonhub/internal/seed/seed.go` (`SkillTemplates`, lines 59-64)
**Affects:** every account that receives a seeded skill; `upsilonapi/bridge` (`buildSkillPropertyMap`, `buildSkillEffect`),
`upsilonhub` skill template list/get endpoints, `Upsilon_Battle.postman_collection.json:1108-1127` (same bad shape),
and — once `ISS-140` lands — every CI run that starts a match with a seeded skill

---

## Summary

**Primary purpose of this issue: make skills that buff character attributes actually work.**

`property.TemporaryProperties` — the engine's buff container — supports durational, entity-scoped
attribute modification, and it even carries an `OriginSkillID` field. But **no skill can ever
create one.** `RegisterBuff` has exactly two non-test callers in the whole repository, both in the
bridge: item equip (`bridge_start.go:230`) and restoring a persisted buff
(`bridge_resurrect.go:178`). `effectapplicator.go` — the code that applies skill effects — contains
**zero** occurrences of `Buff`, `Temporary` or `Duration`.

So today: **equipping an item can buff your attributes; casting a skill cannot.** The machinery
exists and is simply unwired.

The visible symptom is in the seed data. Two of the six seeded skill templates
(`upsilonhub/internal/seed/seed.go:59-64`) are authored as attribute buffs — `Sprint`
(`Movement +2` for 2 turns) and `Regen Aura` (`HP +1`, permanent) — and neither can do what it
says. Worse, **all six** seeded templates are malformed in all three property maps, so combined
with the silent-drop defect (`ISS-140`) every seeded skill currently runs on engine defaults: no
target-type restriction, default range 1 (melee), **free to cast**, and default damage of 100% of
Attack. These are the skills real accounts receive.

Fixing the seeded templates is the **side effect** of this work, not its purpose — four of the six
are a mechanical reshape, and the other two only become expressible once the buff path exists.

> **This issue BLOCKS `ISS-140`.** Once the bridge rejects malformed payloads, every match started
> with a seeded skill fails at arena start. The seed data must be correct before that lands.

---

## Technical Description

### Background

`admin_skill_template_create` and the seeder store a skill's `targeting`, `costs` and `effect` as
free-form JSON property maps. At arena start the bridge resolves each key against the
`SkillProperties` registry (`upsilontypes/property/propertyenum.go:56-107` — 29 legal keys) via
`def.SkillProperty` (`upsilontypes/property/def/skill.go:328-391`), a closed switch that returns
`nil` for anything else. The expected shape is **flat**: property name -> value, where the value
is a `PropertyDTO` (`upsilonapi/api/input.go:36`) of `{value, fvalue, max, bvalue, svalue}`, or a
bare primitive via its polymorphic unmarshaller.

Correct example, from the known-good `upsiloncli/tests/scenarios/e2e_credit_economy.js:73`:

```js
targeting: { TargetType: "EnemyOnly", Range: { value: 0, max: 30 } }
costs:     {}
effect:    { Damage: 5000 }
```

### The Problem Scenario

`upsilonhub/internal/seed/seed.go:59-64` seeds:

```go
{fireballID,        "Fireball",         "Direct",   `{"Type":"Single","Range":3}`,          `{"MP":3}`, `{"Type":"Damage","Value":10}`,                          "I",  5},
{healID,            "Heal",             "Direct",   `{"Type":"Single","Range":2}`,          `{"MP":4}`, `{"Type":"Recovery","Value":10}`,                        "I",  5},
{sprintID,          "Sprint",           "Direct",   `{"Type":"Self","Range":0}`,            `{"SP":2}`, `{"Type":"Buff","Stat":"Movement","Value":2,"Duration":2}`, "I",  3},
{lightningStrikeID, "Lightning Strike", "Direct",   `{"Type":"AoE","Range":2,"Radius":1}`,  `{"MP":5}`, `{"Type":"Damage","Value":12}`,                          "II", 8},
{shieldBashID,      "Shield Bash",      "Reaction", `{"Type":"Single","Range":1}`,          `{"SP":3}`, `{"Type":"Stun","Duration":1}`,                          "II", 7},
{regenAuraID,       "Regen Aura",       "Passive",  `{"Type":"Self","Range":0}`,            `{}`,       `{"Type":"Buff","Stat":"HP","Value":1,"Duration":-1}`,   "I",  4},
```

Key-by-key verdict against the legal `SkillProperties` set:

| Map | Seeded key | Legal? | Notes |
|---|---|---|---|
| targeting | `Type` | **NO** | The legal key is `TargetType`, and its values are e.g. `EnemyOnly` — not `Single`/`AoE`/`Self` |
| targeting | `Range` | yes | Bare int unmarshals fine via `PropertyDTO`'s primitive fallback |
| targeting | `Radius` | **NO** | Not in the enum; the AoE concept is `Zone` |
| costs | `MP` | **NO** | `MP` is an **EntityProperties**, not a SkillProperties. The cost key is `MPLeech` |
| costs | `SP` | **NO** | Same — the cost key is `SPLeech` |
| effect | `Type` | **NO** | Not a key; the effect name *is* the key |
| effect | `Value` | **NO** | Not a key |
| effect | `Stat` | **NO** | Not a key; no stat-buff mechanism exists |
| effect | `Duration` | yes | Legal, but currently orphaned next to illegal siblings |

Resulting runtime behaviour for **all six** skills:

```
authored:  Fireball — single target, range 3, costs 3 MP, deals 10 damage
   ↓ bridge drops every unrecognized key, silently (ISS-140)
registered: {} targeting, {} costs, {} effect
   ↓ engine substitutes defaults
actual:    no target-type restriction, range 1 (melee), FREE to cast,
           damage = 100% of Attack
```

### The missing capability (the core of this issue)

Verified 2026-08-27:

| Fact | Evidence |
|---|---|
| Buff container supports duration and skill origin | `upsilontypes/property/buff.go:5-23` — `TemporaryProperties{Properties, Duration, Forever, OriginEntityID, **OriginSkillID**}`, plus `MakeTemporaryProperties(duration)` and `TickDown()` |
| Items **can** buff entity attributes | `applyItemAsBuff` (`bridge_start.go:192-230`) builds `TemporaryProperties{Forever: true}` and resolves keys via `def.ItemProperty` then `def.EntityProperty` — so `Movement`, `HP`, `Attack`, `Defense` all work |
| An item's `effect` map is folded into that buff | `bridge_start.go:206-208` — `buildSkillEffect(item.Effect.Data)` stored as an `Effect` property inside the buff |
| Skills **cannot** | `RegisterBuff` non-test callers: `bridge_start.go:230`, `bridge_resurrect.go:178`. Nothing in `upsilonbattle`. `effectapplicator.go` has zero `Buff`/`Temporary`/`Duration` occurrences |
| There is no stat-buff effect key | The 29 legal `SkillProperties` (`propertyenum.go:56-107`) cover Damage/Heal/Shield/Stun/Poison and targeting/cost concerns — nothing that names a target attribute to modify |

Note `effectapplicator_buff_test.go` is **misnamed** — it tests Shield and Heal
(`@test-link mechanic_effect_shield` / `mechanic_effect_heal`), not attribute buffs. It should not
be mistaken for existing coverage of this path.

The gap is therefore **not payload vocabulary** — it is the wiring from a skill effect to a
durational `TemporaryProperties`, plus an effect key to express which attribute is modified, by how
much, for how long.

### The two seeded buff skills, concretely

Fixing this is **not** a mechanical reshape. Four of the six translate cleanly:

- `Fireball` -> `{Damage: 10}`, `Lightning Strike` -> `{Damage: 12}`
- `Heal` (`"Recovery"`) -> `{Heal: 10}`
- `Shield Bash` (`"Stun"`) -> `{Stun: N, Duration: 1}` (stored as `StunPower`)

The other two are the ones this issue exists for — they encode attribute buffs, which have **no
legal representation in the 29-key set and no engine path even if they did**:

- **Sprint** — `{"Type":"Buff","Stat":"Movement","Value":2,"Duration":2}`. There is no stat-buff
  skill property. `RepositionSubject`/`RepositionDistance` exist but describe forced movement,
  a different mechanic from a temporary Movement-stat buff.
- **Regen Aura** — `{"Type":"Buff","Stat":"HP","Value":1,"Duration":-1}`. Possibly approximable
  as `{Heal: 1, Duration: -1}`, but that is a semantic decision about what the skill *should*
  do, not a translation of what it says.

Neither is a translation problem. `Sprint` needs a *durational* buff (2 turns); items only produce
`Forever: true` buffs, so even re-expressing Sprint as an item would not preserve its semantics.

### Where This Pattern Exists Today

- `upsilonhub/internal/seed/seed.go:59-64` — all six templates
- `Upsilon_Battle.postman_collection.json:1108-1127` — the admin "Fireball" example reproduces the
  same bad shape (`effect: {Type, Value}`, `costs: {MP}`, `targeting: {Type, Range}`), so anyone
  copying from the collection authors a broken skill
- Correct counter-examples: `upsiloncli/tests/scenarios/e2e_credit_economy.js:73`,
  `upsilonapi/bridge/mapping_test.go:31`

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | **High** — not conditional; every seeded skill is affected on every deployment |
| Impact if triggered | **High** — skills are free, unrestricted in targeting, melee-ranged, and deal 100% of Attack instead of authored values. Balance and economy (credits are awarded per damage dealt) are both distorted |
| Detectability | **Low** — no error, no log, no envelope signal (`ISS-140`). Surfaces only as unexplained combat numbers |
| Current mitigant | None. The silent-drop is currently documented as intentional at `bridge_utils.go:92` |

---

## Recommended Fix

**Short term — unblock `ISS-140`:**
Re-author the four mechanically-translatable templates in `seed.go` to the flat legal shape
(`Fireball` -> `{Damage:10}`, `Lightning Strike` -> `{Damage:12}`, `Heal` -> `{Heal:10}`,
`Shield Bash` -> `{Stun:N, Duration:1}`), correcting `targeting` to use `TargetType` with legal
values and `costs` to use `MPLeech`/`SPLeech`. Fix `Upsilon_Battle.postman_collection.json:1108-1127`
in the same pass so it stops teaching the wrong shape. Decide explicitly what happens to `Sprint`
and `Regen Aura` in the interim — parked, or seeded in a form that is honest about what they do.

**Medium term — the actual point of this issue:**
Wire skill-originated attribute buffs end to end:
1. Add an effect vocabulary for attribute modification to `SkillProperties` — enough to name the
   target attribute, the magnitude, and the duration.
2. Teach `effectapplicator.go` to construct a `TemporaryProperties` via
   `MakeTemporaryProperties(duration)`, populate `OriginSkillID`, and register it on the affected
   target(s).
3. Ensure the buff ticks down (`TickDown()`) on the existing turn/round boundary and expires.
4. Ensure it survives the resurrect path — `restoreEntityBuffs` (`bridge_resurrect.go:166`) already
   rehydrates persisted buffs, so serialization must round-trip the new shape.
5. Re-author `Sprint` and `Regen Aura` against the new capability, and cover both with tests.
6. Rename `effectapplicator_buff_test.go` (it tests Shield/Heal) so the name is free for real buff
   coverage.

**Long term:**
Replace the free-form `PropertyMap` on the wire with a typed, schema-validated payload so an
illegal key cannot be expressed — the same structural fix called for by `ISS-140` and `ISS-106`.

---

## Extra Data

Found on 2026-08-27 during the blast-radius refinement for `ISS-140`. The `ISS-140` fix makes the
bridge reject malformed payloads loudly; **this issue is a hard prerequisite for that landing**,
because once the bridge errors, every match started with a seeded skill will fail at arena start.

Sequencing note: `ISS-140` names two malformed test scenarios
(`e2e_friendly_fire_skill_test.js:26`, `edge_attack_skill_cooldown.js:36`). Those are the small
half of the problem — the seed data is the large half, and it is production data rather than test
fixtures.

Verified during investigation: the nested `Range: {value, max}` shape used by the *correct*
scenarios is legal and must not be "corrected" — it maps to an IntCounterProperty via
`setSkillPropValue`'s `Value`+`Max` handling.

---

## References

- `upsilonhub/internal/seed/seed.go:59-64` — the six malformed templates
- `upsilontypes/property/propertyenum.go:56-107` — the 29 legal `SkillProperties` keys
- `upsilontypes/property/def/skill.go:328-391` — the closed switch returning `nil`
- `upsilonapi/api/input.go:36` — `PropertyDTO`, the legal value shape
- `upsilonapi/bridge/bridge_utils.go:92-130` — the silent-drop that hides this
- `issues/ISS-140_20260827_bridge_skill_payload_silent_property_drop.md` — the fail-fast fix this blocks
- `issues/ISS-106_20260709_php_empty_array_skill_payload_start_failure.md` — adjacent defect in the same payload path
- `CODING_RULE.md` §3 (crash early / fail fast), §4 (strict API contract adherence)

---

## Addendum — verified 2026-08-27: the gap is TWO holes, not one

Scoping for implementation confirmed the capability gap is wider than the original write-up. Both
holes must close for a durational skill buff (e.g. seeded `Sprint`, `Duration: 2`) to behave
correctly. Closing only the first produces buffs that apply and then **never expire**.

**Hole 1 — nothing ever creates a skill-originated buff.**
`effectapplicator.go` (262 LOC) implements exactly two effect families: `applyDamagingEffect` and
`applyHealingEffect`. `grep -n "Buff|Temporar|Duration" effectapplicator.go` returns **nothing**.
`RegisterBuff` has only two non-test callers, both in the bridge and both item-originated
(`bridge_start.go:230`, `bridge_resurrect.go:178`). No engine code path ever registers a buff.

> Note: `effectapplicator_buff_test.go` is **misnamed** and is not evidence to the contrary — it
> tests `TestShieldOvershield_CappedAt2xMaxHP`, `TestHealAndShield_Combined`, and
> `TestCleanse_PoisonAndStun`, all of which are immediate property mutations, not durational
> buffs. Renaming it (or splitting the genuine buff coverage out) is in scope here.

**Hole 2 — `BuffTickDown()` is never called. Durational buffs would never expire.**
`upsilontypes/entity/entity.go:234` defines `BuffTickDown()`, which decrements each buff and drops
those reaching 0. It has **zero non-test callers repo-wide**. This is currently invisible because
the only buffs that exist are item buffs, which are built with `Forever: true`
(`bridge_start.go:190`) and whose `TickDown()` therefore short-circuits to `false` immediately
(`buff.go:27-29`). The moment a `Duration`-bearing buff exists, it becomes permanent.

The insertion point is unambiguous and has a working sibling precedent: `endofturn.go:116` already
calls `ent.SkillCooldownTickDown()` — whose own doc comment explicitly says it "mirrors
BuffTickDown" — inside the per-turn-end block that also restores Movement and clears
`HasActed`/`HasMoved`. `BuffTickDown()` belongs alongside it. Care is needed on ordering for the
same reason ISS-111 documented for cooldowns: a buff applied during the entity's own turn must not
be decremented by that same turn's end, or `Duration: 2` silently means one turn.

**Consequence for effort estimate.** This is not a "wire one call" change: it needs a new effect
family in `effectapplicator.go`, a decision on which properties are legally buffable and how a
malformed buff effect fails (which must agree with ISS-140's collect-all contract), the turn-end
lifecycle wiring with its off-by-one, and unit coverage proving a buff both applies AND expires on
schedule. The seed reshape is the small part.

---

## Design ruling — buffability and failure mode (user, 2026-08-27)

**Buffable set: entity attributes only, including resources.** Skill payloads may not buff skill
properties, item properties, or engine plumbing.

`EntityProperties` cannot be used wholesale as the allow-list — it is a heterogeneous enum that also
carries flags and engine internals. Proposed split, derived from `propertyenum.go:7-51`:

| | Properties | Rationale |
|---|---|---|
| **Buffable — attributes** | `Attack`, `Defense`, `Movement`, `JumpHeight`, `AttackRange` | True combat attributes; the intended target of the ruling |
| **Buffable — resources** | `HP`, `SP`, `MP` | Included per ruling, with the special semantics below |
| **NOT buffable — statuses** | `Shield`, `Poison`, `Stun` | Already applied directly by `effectapplicator` via `ShieldPower`/`PoisonPower`/`StunPower`; a parallel durational path would collide |
| **NOT buffable — flags/plumbing** | `TeamID`, `IsDying`, `HasMoved`, `HasActed`, `EntityDuration`, `ExpiresWithCaster`, `WalkThrough`, `Invisible`, `AIArchetype` | Not attributes. Buffing `TeamID` or `Invisible` from a skill payload would be an exploit, not a feature |

> The status/flag exclusions are an inference from "entity attributes only" and should be confirmed
> before implementation — the literal enum membership would admit them.

### Resource semantics (the caveat)

Buffing a resource is **not** a flat bump. Per the ruling, and applying to `HP`, `SP` and `MP`
alike:

- **Buffing the current value ⇒ regeneration.** The buff grants that amount *per turn* for its
  duration, not once. `HP` regen is the mirror of the existing poison tick
  (`endofturn.go:90-102`), which already applies a per-turn HP delta — that block is the structural
  precedent to follow. **No `Regen` property or regen machinery exists anywhere in the repo today**
  (`grep -rn "Regen" --include=*.go` returns nothing); it must be built.
- **Buffing the max ⇒ raise the ceiling for the buff's duration**, resolving **in favour of the
  recipient** when a max resource changes. On application the recipient gains the headroom rather
  than sitting at an unchanged current against a higher max; on expiry the recipient must not be
  punished beyond the unavoidable clamp back to the restored max.

`DefaultIntCounterProperty.ApplyBuff` (`defaultproperty.go:183-188`) already adds both `Value` and
`MaxValue`, so the composition primitive for the max case exists. Its `UnapplyBuff` counterpart
(`:190-196`) uses `tools.Max` where a clamp would want `tools.Min`, and would *raise* a damaged
entity's current value on expiry — but it has zero non-test callers, since expiry works by dropping
the buff and letting reads recompose. It should be either fixed or deleted, not quietly relied upon.

### Failure mode

A malformed buff effect **fails exactly like ISS-140**: collect-all (report every offending key, not
just the first), error out, never silently default or skip. The two issues share the payload path,
so the error shape must be settled once and used by both — this is the coupling that makes ISS-142's
design a prerequisite for ISS-140's implementation rather than merely its scheduling predecessor.

### Blocked by ISS-144

This design assumes base and composed state are cleanly separable. **They are not today** — see
`ISS-144`, where property writes fold composed (buffed) values back into base, causing item
`Movement` buffs to escalate without bound. Skill buffs cannot be built correctly on that model, and
the max-resource "in favour of the recipient" semantics above are unimplementable until it is fixed.
ISS-144 must land first.

**UPDATE 2026-08-28 — ISS-144 IS NOW FIXED (reviewed OKAY, uncommitted). Unblocked, but read the
precondition below before starting.**

#### PRECONDITION inherited from ISS-144: base state may legitimately be OUT OF RANGE

ISS-144's fix works by writing base-level **deltas** instead of composed absolutes
(`Entity.AdjustPropertyCValue`). That is arithmetically correct, but it means the persisted base
value is no longer guaranteed to sit within `0..baseMax`:

- **Negative base.** A cost affordable at the *composed* level but larger than base drives base
  negative. Base MP 3/3 with a `+10` buff reads composed 13/13; a 5-MP skill leaves base **-2**,
  composed 8. Correct — composed is what gameplay reads.
- **Base above base max.** Healing under a `+0/+10` maxHP buff caps at *composed* max and leaves base
  **15/10**. The reviewer judged this case **more reachable** than the negative one.

Neither is observable today: `UnapplyBuff` and `RemoveBuffsByOrigin` have **zero non-test callers**,
and every live buff is an item buff with `Forever: true`, so no buff is ever removed and composed is
always the value in play.

**ISS-142 is the issue that changes that.** The moment skill buffs expire (turn-end wiring at
`endofturn.go:116`), buff removal can expose an out-of-range base — an entity left with -2 MP, or
with base HP above its own base max. **This is a known, accepted consequence of ISS-144, not a
regression to be re-filed.** ISS-142 owns expiry-clamp semantics and must decide explicitly what
clamping (if any) happens when a buff is removed.

Related, already flagged in this issue: `property.UnapplyBuff` has a `tools.Max(delta, newMaxValue)`
where `tools.Min` is wanted. ISS-144 deliberately avoided using `UnapplyBuff` for that reason, so the
defect is still live and lands squarely in ISS-142's path.

---

## Design ruling — refinement 2 (user, 2026-08-27)

Supersedes the buffable-set table above where they conflict.

**1. Combat modifiers are buffable: `CriticalChance`, `CriticalMultiplier`, `Dodge` (evasion),
`Accuracy`.** The user's note that these are "item-based" is accurate in spirit but not in the code:
all four are declared as **`SkillProperties`** and resolve as *neither* entity nor item properties.
They cannot currently be carried by any buff, and crit is read from the effect rather than the
entity so an entity-level crit buff would have no path into damage. Filed as **ISS-145**, which
blocks this part of the ruling. `Accuracy` is the exception — already read from the entity
(`effectapplicator.go:86`), so it composes buffs for free once the key resolves.

**2. Flags confirmed excluded for now:** `HasActed`, `HasMoved`, `TeamID`, and the remaining engine
plumbing (`IsDying`, `EntityDuration`, `ExpiresWithCaster`, `WalkThrough`, `Invisible`,
`AIArchetype`). The user notes real use cases exist for some of these; they are deferred, not
rejected. Statuses (`Shield`, `Poison`, `Stun`) remain excluded as previously reasoned.

**3. `Movement` is special: no buff to current `Movement` — only to max.** Movement is restored to
its max at each turn end, so a current-value buff is meaningless. Only the ceiling may be buffed.

**4. Resource buffs are applied once at turn start, NOT composed on `Get*`.** This is the key
architectural distinction, and it splits buff handling in two:

| Buff kind | Properties | Mechanism |
|---|---|---|
| **Composed on read** | `Attack`, `Defense`, `JumpHeight`, `AttackRange`, crit/accuracy/dodge (pending ISS-145), and the **max** of `HP`/`SP`/`MP`/`Movement` | `GetProperty` composes base + buffs at read time — the existing mechanism, already working |
| **Applied once at turn start** | the **current value** of `HP`, `SP`, `MP` | A per-turn mutation (regeneration), mirroring the poison tick at `endofturn.go:90-102`. Must NOT participate in read composition |

This resolves the regen semantics cleanly: a resource buff is a scheduled mutation, not a read-time
overlay, so "buffing current HP" naturally means "+N per turn" rather than a phantom pool.

### Consequence: ISS-144 is still required, and is not dissolved by ruling 3

It might appear that forbidding current-`Movement` buffs (ruling 3) and removing resources from read
composition (ruling 4) together eliminate the ISS-144 write-back corruption. **They do not.**
Verified empirically: a **max-only** Movement buff still corrupts, because `endofturn.go:106` writes
the *whole composed counter* — `Value` **and** `MaxValue` — back into base:

| Turn | Composed `Movement` |
|---|---|
| 1 | 3/13 |
| 2 | 13/23 |
| 3 | 23/33 |
| 4 | 33/43 |

Base 3/3 with a `+0 value / +10 max` buff escalates exactly as the current-value case did. Any
buffable max on a property that is written in-match hits this. ISS-144 must land first.

---

## Change Log
- **2026-08-27**: **Reframed.** Filed initially as a seed-data defect
  (`seeded_skill_templates_all_malformed`). Investigation showed the seeded `Sprint` / `Regen Aura`
  templates are not merely misspelled but express a capability the engine does not have: skills
  cannot create attribute buffs at all. Per user direction the primary purpose of this issue is now
  *making skills-that-buff work correctly*, with correcting the seeded templates as the side
  effect. Renamed from `ISS-142_20260827_seeded_skill_templates_all_malformed.md`; severity held at
  High since it blocks `ISS-140` and the seeded skills are live player-facing data.
- **2026-08-27**: **Scope widened after implementation groundwork.** Added the "TWO holes" addendum.
  Newly verified: `BuffTickDown()` has zero non-test callers, so durational buffs would never expire
  even once registration is wired; `effectapplicator_buff_test.go` is misnamed and covers
  shield/heal/cleanse rather than buffs. Turn-end insertion point identified at `endofturn.go:116`
  next to the `SkillCooldownTickDown()` precedent, with an ISS-111-style off-by-one hazard called
  out. Confirmed as the sole blocker for ISS-140: per user ruling the complete ISS-142 solution
  lands before ISS-140 begins — the short-term seed reshape is explicitly NOT to be split out and
  shipped early.
- **2026-08-27**: **Design ruling recorded** (buffable set, resource regen/max semantics, ISS-140
  failure mode) and a new hard blocker identified. Buffable = entity attributes + resources, with
  statuses and engine flags excluded (inference, flagged for confirmation). Buffing a resource's
  current value means per-turn regeneration — for `HP`, `SP` and `MP` alike — and no regen machinery
  exists yet; buffing its max raises the ceiling, resolved in the recipient's favour. Malformed
  payloads fail collect-all per ISS-140. **Now blocked by ISS-144** (buff writeback folds into base
  state), which must land before this design is implementable.
- **2026-08-27**: **Design ruling refined.** Crit/accuracy/dodge added to the buffable set (blocked
  by new **ISS-145** — they are `SkillProperties` and resolve nowhere useful). Flags/statuses
  confirmed excluded for now. `Movement`: max-only, no current-value buff. Resource *current*-value
  buffs are applied once at turn start as regeneration and must not participate in `Get*`
  composition, unlike every other buff. Verified that these rulings do **not** dissolve ISS-144: a
  max-only Movement buff still escalates 3/13 -> 13/23 -> 23/33 -> 33/43 because the turn-end restore
  writes the composed counter's Value and MaxValue wholesale into base.
- **2026-08-27**: **Buffable set finalised.** `Shield` is **buffable**, treated exactly as any other
  resource — a current-value buff means per-turn regeneration, a max buff raises the ceiling.
  `Poison` and `Stun` are **not** buffable (they remain status effects applied directly by
  `effectapplicator` via `PoisonPower`/`StunPower`). This supersedes the earlier inference in
  "refinement 2" that grouped all three as excluded statuses. Consequence: `Shield` joins
  `HP`/`SP`/`MP`/`Movement` in ISS-144's affected write-back set.
- **2026-08-27**: **Shield-specific handling deferred to ISS-146.** Shield stays in the buffable set
  but is to be implemented as a *plain resource*, identical to `HP`/`SP`/`MP`, with no
  Shield-specific branch. Its cap (`2 x maxHP`), overshield, absorption-before-HP and init-only-max
  mechanics raise real questions once buffable; those are recorded in ISS-146 and deliberately left
  unanswered. Implementers must not invent answers to them here.
- **2026-08-28**: **Unblocked** — ISS-144 landed (base/composed write isolation via
  `AdjustPropertyCValue`, reviewer verdict OKAY, uncommitted). Recorded the precondition ISS-142
  inherits from it: base state may now legitimately be out of range in **both** directions (negative,
  and above base max), unobservable today only because no buff is ever removed. ISS-142 owns the
  expiry-clamp decision and must handle this explicitly rather than treating it as a new bug.
  ISS-145's Dodge defect also fixed in the same round; ISS-145 Defect 1 (crit/accuracy/dodge
  entity-reachability) remains Open and still gates this issue's buffability ruling.
