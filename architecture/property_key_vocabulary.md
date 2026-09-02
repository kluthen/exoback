# Property key vocabulary — the frozen 64

**Status:** FROZEN 2026-08-30 (plan step 9 of the Property Key Space Unification round).
**Authority:** this table is the specification the unified `property.Key` + `def` registry is built
from. Once the registry lands, the *code* is authoritative and this document becomes the rationale
record — but until then, nothing in the implementation may invent a name, scope, default or
composition rule that is not written here.

Derived by direct read of `upsilontypes/property/propertyenum.go`, `property/property.go`,
`property/def/{entity,skill,item}.go` and `property/defaultproperty/defaultproperty.go` at
commit `8363c0a`. Counts verified mechanically: **64 constants, Entity 20 / Skill 31 / Item 13.**

---

## 1. The invariant that makes this safe

**Constant identifier == string value, for all 64 keys.** Today exactly four keys violate this
(`ShieldPower`="Shield", `StunPower`="Stun", `PoisonPower`="Poison", `ArmorRating`="Armor") — and
three of those four violations *are* the ISS-147 collision. Restoring the invariant is what kills the
collision class structurally rather than by convention.

This is directly testable: a conformance test walks the registry and asserts
`entry.Key == property.Key(<identifier>)` for every entry, so a future divergence is a red test, not
a silent production defect.

## 2. Vocabularies used by the table

**Scope** (metadata on the entry, no longer a Go type): `Entity`, `Skill`, `Item`. A key may declare
more than one. Four keys become dual-scope (`Entity|Skill`) in this round to resolve ISS-145 Defect 1.

> **CORRECTION 2026-08-31 (step 13) — THREE more dual-scope keys, the first `Entity|Item` ones.**
> This section originally contemplated dual scope only as `Entity|Skill`. Implementing the scope
> guard proved that blind spot wrong: **`ArmorRating` (row 55) is `Item|Entity`.** An entity
> legitimately carries it because `applyItemAsBuff`
> (`upsilonapi/bridge/bridge_start.go`) deliberately flattens equipped items into `Forever:true`
> entity buffs — equipment is not a live layer. Two engine sites read it off the entity
> (`effectapplicator.go:134`, `ruler/rules/attack.go:59`) and **both are correct**; it was this
> table that was wrong. Corroborating: row 55 declares `Composition: Add`, which is meaningless for
> an Item-only key since composition only folds onto an entity base.
>
> A systematic sweep of every entity-accessor read of a non-entity-scoped key found the defect is a
> **three-key family**, all the "innate stat + equipment contribution" pattern:
>
> | Row | Key | Composed on the entity with | Read at |
> |---|---|---|---|
> | 55 | `ArmorRating` | `Defense` | `effectapplicator.go:134`, `ruler/rules/attack.go:59` |
> | 59 | `WeaponRange` | `AttackRange` (via `Max`) | `ruler/rules/attack_checks.go:76` |
> | 60 | `WeaponBaseDamage` | `Attack` (via `+`) | `ruler/rules/attack.go:49` |
>
> The sweep confirmed these three are the ONLY wrong-scope entity reads; every other hit was a
> `Skill`/`Effect` receiver, which carries no scope guard.
>
> **When adding a key, ask whether the bridge flattens it onto an entity — if so it needs `Entity`
> scope regardless of where it is authored.**

> **CORRECTION 2026-09-01 (slice 14D) — EIGHT more dual-scope keys, encoding ISS-142's buffability
> ruling.** `ISS-142`'s design ruling (user, 2026-08-27, reconfirmed 2026-09-01) declares
> `Attack`, `Defense`, `AttackRange`, `Movement`, `JumpHeight`, `HP`, `SP` and `MP` legitimately
> item-grantable — an equipped item may buff these via `applyItemAsBuff`, same mechanism as the
> step-13 `Item+Entity` family above. `Shield`, `Poison` and `Stun` are excluded by the same ruling
> (already applied directly by `effectapplicator`; a parallel item-buff path would reproduce the
> ISS-147 escalation), as are the 9 flag/plumbing keys (`TeamID`, `IsDying`, `HasMoved`,
> `HasActed`, `EntityDuration`, `ExpiresWithCaster`, `WalkThrough`, `Invisible`, `AIArchetype`) —
> buffing those from an item would be an exploit, not a feature. Rows 1, 2, 3, 4, 5, 6, 7 and 12
> below are updated to `Item+Entity` accordingly; a registry conformance test
> (`registry_buffability_test.go`) pins the partition.

**Kind** — which `Property` implementation backs the entry:
`Int`, `IntCounter`, `Bool`, `String` (optionally with a validated allowed-value set), plus the two
specials `Zone` (`def.ZoneProperty`) and `Effect` (`def.EffectProperty`).
`Float` (`defaultproperty.DefaultFloatProperty`) exists in the machinery but **no property uses it** —
the registry declares no Float entry.

**Composition** — how `ApplyBuff` folds a buff onto a base. Four values, **not the two assumed in
decision 5**; see §6 correction 1:

| Rule | Observed implementation | Applies to |
|---|---|---|
| `CompositionAdd` | `base + buff` (IntCounter adds *both* `Value` and `MaxValue`) | Int, IntCounter, Float |
| `CompositionAnd` | `base && buff` | Bool |
| `CompositionReplace` | buff's value overwrites base | Zone only |
| `CompositionNone` | `ApplyBuff` returns the base unchanged; buff is ignored | String, Effect |

**Default-when-absent** is the value the resolver hands back when a key is not present on the
carrier. Per decision 9 this is a *different concept* from `def.PropertiesForCharacter()`, which is
the starting loadout a real character is created with. The registry declares only the former; the
loadout stays a separate list.

---

## 3. The table — ENTITY scope (20)

| # | Key | Scope | Kind | Default-when-absent | Composition | Min info level | Notes |
|---|---|---|---|---|---|---|---|
| 1 | `HP` | **Item+Entity** | IntCounter | `10 / 10` | Add | FriendlyController | **DUAL-SCOPE (ISS-142 buffability ruling, 2026-08-27, reconfirmed 2026-09-01)** — item-grantable. See §2 correction. |
| 2 | `Movement` | **Item+Entity** | IntCounter | **`3 / 3`** | Add | FriendlyController | **Defect fix (decision 15): constructor returns `5/5` today against a documented and universally-used default of 3.** Reset at end of turn. **DUAL-SCOPE (ISS-142 buffability ruling, 2026-08-27, reconfirmed 2026-09-01)** — item-grantable. See §2 correction. |
| 3 | `SP` | **Item+Entity** | IntCounter | `10 / 10` | Add | FriendlyController | **DUAL-SCOPE (ISS-142 buffability ruling, 2026-08-27, reconfirmed 2026-09-01)** — item-grantable. See §2 correction. |
| 4 | `MP` | **Item+Entity** | IntCounter | `10 / 10` | Add | FriendlyController | **DUAL-SCOPE (ISS-142 buffability ruling, 2026-08-27, reconfirmed 2026-09-01)** — item-grantable. See §2 correction. |
| 5 | `Attack` | **Item+Entity** | Int | `1` | Add | FriendlyController | Starting loadout is `3` — deliberately different, not a bug (decision 9). **DUAL-SCOPE (ISS-142 buffability ruling, 2026-08-27, reconfirmed 2026-09-01)** — item-grantable. See §2 correction. |
| 6 | `Defense` | **Item+Entity** | Int | `0` | Add | FriendlyController | **DUAL-SCOPE (ISS-142 buffability ruling, 2026-08-27, reconfirmed 2026-09-01)** — item-grantable. See §2 correction. |
| 7 | `JumpHeight` | **Item+Entity** | Int | `2` | Add | FriendlyController | **DUAL-SCOPE (ISS-142 buffability ruling, 2026-08-27, reconfirmed 2026-09-01)** — item-grantable. See §2 correction. |
| 8 | `TeamID` | Entity | Int | `0` | Add | Public | Additive composition on an identity is semantically wrong — declared as observed; see §8. |
| 9 | `IsDying` | Entity | Int | `-1` | Add | Public | `-1` = not dying. Set to 3 at 0 HP, decremented each end of turn, removed at 0. |
| 10 | `HasMoved` | Entity | Bool | `false` | And | GameMaster | |
| 11 | `HasActed` | Entity | Bool | `false` | And | GameMaster | |
| 12 | `AttackRange` | **Item+Entity** | Int | `1` | Add | FriendlyController | **DUAL-SCOPE (ISS-142 buffability ruling, 2026-08-27, reconfirmed 2026-09-01)** — item-grantable. See §2 correction. |
| 13 | `EntityDuration` | Entity | IntCounter | `0 / 0` | Add | Public | Temporary-entity lifetime; `0` = permanent. Distinct from skill `Duration`. |
| 14 | `ExpiresWithCaster` | Entity | Bool | `false` | And | Public | |
| 15 | `WalkThrough` | Entity | Bool | `false` | And | Public | |
| 16 | `Invisible` | Entity | Bool | `false` | And | Public | |
| 17 | `AIArchetype` | Entity | String | `""` | None | Public | e.g. `fighter`, `ranger`, `support`, `sneak`. |
| 18 | `Shield` | Entity | IntCounter | `0 / 0` | Add | FriendlyController | Damage-absorbing counter. Overshield allowed to 2× max HP. **Keeps the bare name; the skill side moves.** |
| 19 | `Poison` | Entity | Int | `0` | Add | FriendlyController | Accumulated poison state. Halved each turn, removed below 1. |
| 20 | `Stun` | Entity | Int | `0` | Add | FriendlyController | Accumulated stun state. Halved each turn, removed below 1. |

## 4. The table — SKILL scope (31)

### 4a. Targeting (9)

| # | Key | Scope | Kind | Default-when-absent | Composition | Min info level | Notes |
|---|---|---|---|---|---|---|---|
| 21 | `Behavior` | Skill | String (validated) | `"Direct"` | None | FriendlyController | Allowed: Direct, Reaction, Passive, Counter, Trap. |
| 22 | `Range` | Skill | IntCounter | `1 / 1` | Add | FriendlyController | |
| 23 | `Zone` | Skill | Zone | `Single` | Replace | — | **`ZoneProperty.Name()` is hardcoded `"Zone"`; see §8 trap.** |
| 24 | `TargetNumber` | Skill | Int | `0` (= all in zone) | Add | FriendlyController | **Live gap: the constructor exists but `def.SkillProperty()` has no case for it, so it resolves `nil` today. The registry closes this by construction.** |
| 25 | `Accuracy` | **Skill + Entity** | Int | `100` | Add | FriendlyController | ISS-145 Defect 1: becomes entity-reachable. |
| 26 | `Dodge` | **Skill + Entity** | Int | `0` | Add | FriendlyController | ISS-145 Defect 1. (Defect 2 — read from attacker — already fixed and shipped.) |
| 27 | `Parry` | Skill | Int | `0` | Add | FriendlyController | Stays skill-only: ISS-148/149 are out of round (decision 10). |
| 28 | `TargetType` | Skill | String (validated) | `"Entity"` | None | FriendlyController | Allowed: Entity, FriendOnly, EnemyOnly, Tile, EntityOrTile, Self. |
| 29 | `TargetingMechanics` | Skill | String (validated) | `"Anywhere"` | None | FriendlyController | Allowed: Anywhere, Line of Sight. |

### 4b. Effect (10)

| # | Key | Scope | Kind | Default-when-absent | Composition | Min info level | Notes |
|---|---|---|---|---|---|---|---|
| 30 | **`DamageScale`** | Skill | Int | `100` | Add | FriendlyController | **RENAME from `Damage`.** Percentage scaling of attack, not a flat addend — the name now says so (decision 4). Additive across buffs: 150% + 20% = 170% (decision 5). |
| 31 | `Heal` | Skill | Int | `0` | Add | FriendlyController | |
| 32 | `ShieldPower` | Skill | Int | `0` | Add | FriendlyController | **VALUE RENAME `"Shield"` → `"ShieldPower"`.** Go identifier already correct. Signed. |
| 33 | `StunPower` | Skill | Int | `0` | Add | FriendlyController | **VALUE RENAME `"Stun"` → `"StunPower"`.** Signed; negative cures. |
| 34 | `StunChance` | Skill | Int | `0` | Add | FriendlyController | Percent. |
| 35 | `CriticalChance` | **Skill + Entity** | Int | `0` | Add | FriendlyController | ISS-145 Defect 1. Percent. |
| 36 | `CriticalMultiplier` | **Skill + Entity** | Int | **`100`** | Add | FriendlyController | ISS-145 Defect 1. **The enum comment says "Absence means 0%" and is wrong** — the constructor's `100` is correct; a 0 multiplier would zero every crit. Comment gets fixed, behavior does not change. |
| 37 | `Duration` | Skill | IntCounter | `0 / 0` | Add | FriendlyController | Buff duration. Distinct from `EntityDuration`. |
| 38 | `PoisonPower` | Skill | Int | `0` | Add | FriendlyController | **VALUE RENAME `"Poison"` → `"PoisonPower"`.** Signed; negative cures. **This rename is ISS-147's structural fix.** |
| 39 | `PoisonChance` | Skill | Int | `0` | Add | FriendlyController | Percent. |

### 4c. Cost (7)

| # | Key | Scope | Kind | Default-when-absent | Composition | Min info level | Notes |
|---|---|---|---|---|---|---|---|
| 40 | `Delay` | Skill | IntCounter | `0 / 500` | Add | FriendlyController | |
| 41 | `Channeling` | Skill | IntCounter | `0 / 0` | Add | FriendlyController | |
| 42 | `HPLeech` | Skill | Int | `0` | Add | FriendlyController | |
| 43 | `MPLeech` | Skill | Int | `0` | Add | FriendlyController | |
| 44 | `SPLeech` | Skill | Int | `0` | Add | FriendlyController | |
| 45 | `MvtCost` | Skill | Int | `0` | Add | FriendlyController | Rename candidate — see §6 correction 3. |
| 46 | `Cooldown` | Skill | IntCounter | `0 / 3` | Add | FriendlyController | `Value` = cooldown remaining at battle start; `MaxValue` = cooldown applied when used. |

### 4d. Reposition (2)

| # | Key | Scope | Kind | Default-when-absent | Composition | Min info level | Notes |
|---|---|---|---|---|---|---|---|
| 47 | `RepositionSubject` | Skill | String (validated) | `"Self"` | None | FriendlyController | Allowed: Self, Target. |
| 48 | `RepositionDistance` | Skill | Int | `0` | Add | FriendlyController | Signed tiles along the caster→target ray. |

### 4e. Trigger (3)

| # | Key | Scope | Kind | Default-when-absent | Composition | Min info level | Notes |
|---|---|---|---|---|---|---|---|
| 49 | `TriggerType` | Skill | String (validated) | `"OnEnter"` | None | FriendlyController | Allowed: OnEnter, OnExit, OnStep, OnTurn, OnDeath. |
| 50 | `RemoveOnTrigger` | Skill | Bool | `true` | And | FriendlyController | |
| 51 | `TriggerCount` | Skill | Int | `1` | Add | FriendlyController | `0` = unlimited. |

## 5. The table — ITEM scope (13)

| # | Key | Scope | Kind | Default-when-absent | Composition | Min info level | Notes |
|---|---|---|---|---|---|---|---|
| 52 | `Durability` | Item | Int | `0` (= invulnerable) | Add | Public | |
| 53 | `Weight` | Item | Int | `0` | Add | Public | |
| 54 | `ItemType` | Item | String (validated) | `"Misc"` | None | OwnController | Allowed: Wearable, Consumable, Usable, Throwable, Ammunitions, Misc. |
| 55 | `ArmorRating` | **Item+Entity** | Int | `0` | Add | Public | **VALUE RENAME `"Armor"` → `"ArmorRating"`** to restore the §1 invariant. **DUAL-SCOPE (corrected 2026-08-31, step 13)** — declared on items but legitimately read off an Entity, because `applyItemAsBuff` flattens equipped items into `Forever:true` entity buffs. See §7. |
| 56 | `WeaponType` | Item | String (validated) | `"None"` | None | Public | Allowed: None, One-Handed Melee, Two-Handed Melee, One-Handed Ranged, Two-Handed Ranged. |
| 57 | `ArmorType` | Item | String (validated) | `"None"` | None | Public | Allowed: None, Head, Body, Hands, Legs, Feet, Belt, Neck, Ring. |
| 58 | `ToolType` | Item | String (validated) | `"None"` | None | Public | Allowed: None, SomeTool. |
| 59 | `WeaponRange` | **Item+Entity** | Int | `0` | Add | Public | **DUAL-SCOPE (corrected 2026-08-31, step 13)** — composed with `AttackRange` on the entity. See §2 correction. |
| 60 | `WeaponBaseDamage` | **Item+Entity** | Int | `0` | Add | Public | **DUAL-SCOPE (corrected 2026-08-31, step 13)** — composed with `Attack` on the entity. See §2 correction. |
| 61 | `Stackable` | Item | Bool | `false` | And | Public | |
| 62 | `StackSize` | Item | Int | `0` | Add | Public | |
| 63 | `Effect` | Item | Effect | `nil` | None | Analyser | **`EffectProperty.Name()` is hardcoded `"Effect"`; see §8 trap.** |
| 64 | `Value` | Item | Int | `0` | Add | Public | Monetary value. Rename candidate — see §6 correction 3. |

---

## 6. Corrections to earlier round decisions

**Correction 1 — the composition vocabulary is FOUR values, not two.** Decision 5 assumed
`CompositionAdd` plus `CompositionReplace` "for the string/Zone/Effect entries that already behave
that way". Direct reading of `defaultproperty.go` shows that is wrong on two counts:
`DefaultBoolProperty.ApplyBuff` is `base && buff` (a distinct rule), and `DefaultStringProperty.ApplyBuff`
/ `EffectProperty.ApplyBuff` **ignore the buff entirely** rather than replacing. Only `ZoneProperty`
actually replaces. Hence `Add` / `And` / `Replace` / `None`. This does not change any behavior — it
changes what the registry must be able to *say* about behavior, and therefore what the conformance
test can assert.

**Correction 2 — `CriticalMultiplier`'s documented default is wrong, not its constructor.** Enum
comment says 0%; `def.CriticalMultiplier()` returns 100. The constructor is right. The comment is
corrected; no behavior changes. (Contrast with `Movement`, where the *constructor* is the wrong one —
decision 9 / decision 15.)

**Correction 3 — two optional clarity renames, deferred to the user, resolved in §7.**
`MvtCost` and `Value` are the only two names that read poorly in a flat key space (`Value` in
particular is dangerously generic once the three namespaces merge). Decision 3 requires all renames
be swept at once, so this had to be settled during the freeze rather than later.

## 7. Complete rename map

| Old identifier | Old string value | New identifier | New string value | Why |
|---|---|---|---|---|
| `Damage` (Skill) | `"Damage"` | `DamageScale` | `"DamageScale"` | Decision 4 — name must carry composition semantics |
| `ShieldPower` | `"Shield"` | `ShieldPower` | `"ShieldPower"` | Collision with entity `Shield`; §1 invariant |
| `StunPower` | `"Stun"` | `StunPower` | `"StunPower"` | Collision with entity `Stun`; §1 invariant |
| `PoisonPower` | `"Poison"` | `PoisonPower` | `"PoisonPower"` | **ISS-147** — collision with entity `Poison`; §1 invariant |
| `ArmorRating` | `"Armor"` | `ArmorRating` | `"ArmorRating"` | §1 invariant |
| `MvtCost` | `"MvtCost"` | `MovementCost` | `"MovementCost"` | Flat-space clarity; pairs with `Movement` |
| `Value` (Item) | `"Value"` | `ItemValue` | `"ItemValue"` | Flat-space clarity; `Value` is too generic once namespaces merge |

**Scope widenings (no rename), ISS-145 Defect 1:** `Accuracy`, `Dodge`, `CriticalChance`,
`CriticalMultiplier` gain `Entity` alongside `Skill`.

**Default-value change (no rename), decision 15:** `Movement` default-when-absent `5/5` → `3/3`.

Everything else — 55 of 64 keys — keeps both its identifier and its string value unchanged.

## 8. Traps and latent defects this freeze exposes

Recorded so the implementation does not trip on them. Items marked *out of round* are not to be
fixed here.

1. **`Name()` desync — the highest-value test in the round.** `Entity.UpdateProperty` keys storage by
   `p.Name(GameMaster)` — the *value's* self-reported name, not the key it was written under.
   `ZoneProperty.Name()` and `EffectProperty.Name()` return hardcoded literals. A conformance test
   must assert, for every registry entry, that a freshly constructed default's `Name(GameMaster)`
   equals its registry key.
2. **`TargetNumber` resolves to `nil`** — constructor exists, no `def.SkillProperty()` case. Closed by
   construction when the resolver becomes a table lookup.
3. **`MakeIntProperty` / `MakeFloatProperty` / `MakeBoolProperty` return `nil` on their default
   branch**, putting a silent nil `Property` into storage. Crash-early violation; in scope to delete.
4. **Bool buffs can never grant a flag.** `And` composition means base `false` && buff `true` =
   `false`, so `WalkThrough`, `Invisible` and `ExpiresWithCaster` are un-buffable in practice.
   *Out of round* — declare as observed, file as follow-up.
5. **`TeamID` and `IsDying` declare `Add` composition**, which is meaningless for an identity and
   dubious for a countdown. *Out of round* — declare as observed, file as follow-up.
6. **`def.ZoneProperty` / `def.EffectProperty` embed `property.Property` as a nil interface** — any
   unoverridden method panics on nil dispatch. *Out of round* (already noted as an advisor follow-up).
7. **Constructors use `FriendlyController` where `PropertiesForCharacter()` uses `Public`** for the
   same keys. Registry declares the constructor's level. *Out of round.*
