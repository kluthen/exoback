# Issue: Buffed properties are folded into base state on every write — item Movement buffs escalate without bound

**ID:** ISS-144_20260827_buff_writeback_folds_into_base_state
**Ref:** ISS-144
**Date:** 2026-08-27
**Severity:** High
**Status:** Resolved
**Component:** `upsilontypes/entity/entity.go` (`GetProperty` / `UpdatePropertyValue`)
**Affects:**
- `upsilonbattle/battlearena/ruler/rules/endofturn.go:106` (movement restore — the live trigger)
- `upsilonbattle/battlearena/ruler/rules/move.go:76-79` (move cost payment — **found during
  implementation, was NOT in the original enumeration**; identical corruption on `Movement`)
- `upsilonapi/bridge/bridge_start.go:190-230` (`applyItemAsBuff` — the live source of buffs)
- `upsilonapi/bridge/bridge_resurrect.go:178` (rebuilds buffs from persisted blobs)
- Any equipped item granting `Movement`, `HP`, `SP`, `MP`, `Attack`, `Defense`
- `issues/ISS-142` — blocks its design; skill buffs cannot be built on this model as-is

---

## Summary

Entity property reads compose `base + all active buffs`, but property **writes** persist that
*composed* value back into the base map. Every write therefore permanently absorbs the buff's
contribution into the base, and the buff is then applied *again* on the next read. For any property
that is both buffed and written each turn, the value escalates without bound.

This is **live today**, reachable through normal play (equip any item granting `Movement`), and is
not hypothetical — it is reproduced below.

---

## Problem Scenario

`GetProperty` composes base with every active buff (`entity.go:170-179`):

```go
func (e Entity) GetProperty(name interface{}) property.Property {
	prop := e.getBasePropertyOrDefault(name)
	for _, buff := range e.GetBuffsFor(name) {
		prop = prop.ApplyBuff(buff)      // base + buffs
	}
	return prop
}
```

`UpdatePropertyValue` reads *composed*, mutates it, then writes it to the **base** map
(`entity.go:300-304`):

```go
func (e *Entity) UpdatePropertyValue(p interface{}, value interface{}) {
	prop := e.GetProperty(p)   // <-- composed (base + buffs)
	prop.Set(value)
	e.UpdateProperty(prop)     // <-- written to e.Properties (base)
}
```

For counters, `ApplyBuff` adds **both** `Value` and `MaxValue`
(`defaultproperty.go:183-188`), so the whole buffed counter — max included — is folded into base.

End of turn restores movement to its max (`endofturn.go:106`):

```go
ent.UpdatePropertyValue(property.Movement, ent.GetPropertyC(property.Movement).GetMaxValue())
```

With a base of `3/3` and an item buff of `+10/+10`, that reads the composed max (13), writes 13 to
base, and the buff is re-added on the next read:

| Turn | Composed `Movement` |
|---|---|
| 1 | 13/13 |
| 2 | 23/23 |
| 3 | 33/33 |
| 4 | 43/43 |

**Reproduced** with a scratch test against the real `Entity` (since deleted), replaying
`endofturn.go:106` verbatim for four turns: composed reached `53/53` and base `43/43` from a base of
`3/3` plus one `Forever` `+10` buff. Escalation is unbounded and compounds every turn.

The same mechanism corrupts any buffed property that is written back. `HP` is written on damage,
healing, and poison ticks (`endofturn.go:92-98`); `SP`/`MP` on skill cost payment.

### Why it has gone unnoticed
- Item buffs are the only buffs that exist today, and nothing asserts on post-turn `Movement`.
- `ISS-141`'s new `e2e_melee_attack_damage.js` equips a `Movement +10` item and *does* trigger this
  every turn — it still passes because it asserts on damage magnitude, not on movement. The bot is
  simply getting unboundedly faster, which only makes reaching melee easier.
- `UnapplyBuff` exists but has **zero non-test callers**: expiry works by dropping the buff from the
  slice and letting reads recompose. That design is correct and cheap — but only if writes never
  touch composed state, which is exactly the invariant being violated.

---

## Risk Assessment

- **Gameplay integrity:** any item granting `Movement` yields effectively unlimited movement within
  a few turns. Directly exploitable by a normal player with a normal item.
- **Persistence:** corrupted base values are serialized into resurrection blobs
  (`bridge_resurrect.go` re-registers buffs on top of an already-inflated base), so the corruption
  survives a crash/restore and compounds again.
- **Blocks ISS-142:** skill-originated buffs cannot be implemented on this model. The user's ruling
  for that issue — buffing a max resource must resolve "in favour of the recipient", and buffing a
  resource's current value means *regeneration* — depends on base and composed state being cleanly
  separable. They are not, today.
- **Severity call:** filed **High**. A case for Critical exists (persisted state corruption,
  trivially exploitable in production), but there is no data loss or security breach, and the blast
  radius is confined to in-match entity state.

---

## Recommended Fix

**Short term.** Stop writes from folding composed state into base. `UpdatePropertyValue` must mutate
the *base* property, not the composed one — read via `getBasePropertyOrDefault` rather than
`GetProperty`. Audit each caller first: several (e.g. damage application) legitimately compute
against the composed value and then need the *delta* applied to base, not the composed absolute
written wholesale. `UpdatePropertyCMaxValue` already documents the intended discipline ("wont affect
buffs") and is a useful reference for the target semantics.

**Medium term.** Make the base/composed split explicit and hard to misuse — a distinct accessor (or
type) for composed reads so that a composed value cannot be passed to a write path by accident, plus
regression coverage that runs several turns with an active buff and asserts the base is unchanged.
This must be settled before ISS-142 builds skill buffs on top of it.

**Do not** fix this by making buffs mutate base directly on application: that breaks expiry, which
currently relies on reads recomposing from an untouched base.

---

## References

- `upsilontypes/entity/entity.go:170-179` — `GetProperty`, composes base + buffs
- `upsilontypes/entity/entity.go:300-310` — `UpdatePropertyValue` / `UpdatePropertyCMaxValue`
- `upsilontypes/property/defaultproperty/defaultproperty.go:183-196` — counter `ApplyBuff`/`UnapplyBuff`
- `upsilonbattle/battlearena/ruler/rules/endofturn.go:106` — the movement-restore trigger
- `upsilonapi/bridge/bridge_start.go:190-230` — `applyItemAsBuff`, the live buff source
- `upsiloncli/tests/scenarios/e2e_melee_attack_damage.js` — equips a `Movement +10` item, triggers this
- `issues/ISS-142_20260827_skill_originated_attribute_buffs_unsupported.md` — blocked by this
- `CODING_RULE.md` §3 (crash early / fail fast)

---

## Narrowing — verified 2026-08-27: only in-match writes are affected

The corruption requires a property to be **both buffed and written back while the match runs**. A
full enumeration of every write-path call (`UpdatePropertyValue` / `RepsertPropertyValue` /
`UpdateProperty` on a composed read) splits the buffable set cleanly in two:

| | Properties | Write site | Corrupts? |
|---|---|---|---|
| **Written in-match** | `HP`, `SP`, `MP`, `Movement`, `Shield` | `skill_validation.go:250-268` (cost payment), `endofturn.go:106` (movement restore), `endofturn.go:92-98` (poison tick), `effectapplicator.go:150,176,249` + `attack.go:77-89` (shield application & absorption) | **Yes** |
| **Written only at construction** | `Attack`, `Defense`, `AttackRange`, `JumpHeight`, `ArmorRating` | `bridge_start.go:176-177`, `bridge_start_archetype.go:177-180`, `bridge_resurrect.go:156-157` | **No** |

The construction-time writes are safe purely by **ordering**: `bridge_start.go` sets attributes at
lines 176-178 and only then calls `applyItemAsBuff` at line 181, so `GetProperty` still returns base
(no buffs registered yet) and `RepsertPropertyValue`'s identical composed-read flaw never fires.

**Consequence:** durational buffs on `Attack`, `Defense`, `AttackRange` and `JumpHeight` are already
correct with no changes at all — they are read-composed by `GetProperty` and never written back.
The defect is confined to the resources plus `Movement`, which is functionally a resource (spent per
turn, restored to max at `endofturn.go:106`) even though it reads as an attribute.

Note the cost-payment path corrupts by the same mechanism through a different API — it reads
composed via `GetPropertyC` and writes base via `UpdateProperty` directly, bypassing
`UpdatePropertyValue` entirely:

```go
mp := user.GetPropertyC(property.MP)      // composed: base + buffs
mp.SetValue(mp.GetValue() - skp.I())
user.UpdateProperty(mp)                   // written to base
```

So the fix cannot be confined to `UpdatePropertyValue`; it must cover every site that pairs a
composed read with a base write.

### Revised fix scope

Substantially smaller than first assessed. **Not** a repo-wide audit of every `UpdatePropertyValue`
caller — only four properties and three write sites, all reachable in-match. Recommended as a small
standalone change landing **before** ISS-142, with no semantics change: make those sites read base
(or apply a delta) rather than persisting a composed absolute. That immediately closes the live
`Movement` exploit and gives ISS-142 the clean base/composed separation its resource regen and
max-resource semantics depend on.

### Residual fragility (worth noting, not blocking)

The attributes' safety rests on an **implicit, unenforced ordering invariant** — "attributes are
written before any buff is registered". Nothing prevents a future mid-match attribute write (a
Defense debuff, an equipment swap, a re-run of the archetype seeding) from silently reintroducing
this bug on the properties currently classed safe. A regression test pinning the invariant, or an
explicit base-write accessor, is the cheap durable guard.

---

---

## Resolution (2026-08-28)

**Fixed, reviewed OKAY, not yet committed.**

**Approach:** a new write-isolation primitive on `Entity` that operates on **deltas** instead of
composed absolutes:

```go
// upsilontypes/entity/entity.go
func (e *Entity) AdjustPropertyCValue(p interface{}, delta int) {
    prop := e.getBasePropertyOrDefault(p).(property.IntCounterProperty)
    prop.SetValue(prop.GetValue() + delta)
    e.UpdateProperty(prop)
}
```

Sound because `composed = base + sum(buffs)` and the buff sum is constant across a single
read-modify-write, so applying a composed-observed delta to base is equivalent to stripping the buff
contribution. Confirmed by review to hold for `Value` **and** `MaxValue` and for arbitrarily stacked
buffs (`DefaultIntCounterProperty.ApplyBuff` adds both fields linearly).

Also added `GetBaseProperty` / `GetBasePropertyC` for the one case needing an absolute base target
(turn-end `Movement` restore), and switched the six pre-existing write helpers
(`RepsertPropertyValue`, `RepsertPropertyCMaxValue`, `RepsertPropertyCValue`, `UpdatePropertyValue`,
`UpdatePropertyCMaxValue`, `UpdatePropertyCValue`) to read base internally rather than composed.

`property.UnapplyBuff` was deliberately **not** used: its `tools.Max(delta, newMaxValue)` clamp
returns wrong results for ordinary deltas smaller than the buff's magnitude.

**Sites fixed:** `endofturn.go` (poison tick + Movement restore), `skill_validation.go`
(`paySkillCost`, 4 deductions), `move.go` (move cost — outside the original enumeration),
`attack.go` (shield absorption + HP damage), `effectapplicator.go` (shield deplete/absorb, HP damage,
heal, overshield).

**Semantics preserved:** poison still cannot kill (the floor-at-1 is now applied at the composed
level via a base delta). Movement still refills each turn — but to the entity's own **base** max,
with the buff re-applying by composition. A paired `+10/+10` buff therefore still yields composed
13/13, identical to pre-bug intent. A max-only `+0/+10` buff yields 3/13, i.e. headroom that cannot
be refilled into. Review confirmed this is the **only** variant satisfying all three EXPECTATION
bullets of the governing atom — restoring to composed max avoids escalation too, but folds the
buff into base and violates bullet 3.

**Governing atom:** `upsilonbattle:rule_entity_property_write_isolation` (RULE / ARCHITECTURE),
written *before* the code via ATD Workflow E; its `## EXPECTATION` served as the acceptance criteria.

**Verification:**
- Test-first: 4 regression tests written and confirmed **failing** against unmodified code before the
  fix. Reviewer independently reproduced these in a scratch `git archive HEAD` tree: paired-buff
  Movement expected 13/13 got 23/23; max-only expected 3/13 got 13/23; `paySkillCost` under buff
  expected 15/20 got 25/30; Dodge expected 1 damaged target got 0.
- Post-fix: `go test ./upsilontypes/...` 62 passed / 13 pkgs; `go test ./upsilonbattle/...` 189
  passed / 15 pkgs. Build + `go vet` clean, incl. dependent `upsilonapi`.
- `scripts/code_health_check.py` error counts identical pre/post on all six changed files.
- Reviewer gate: **OKAY, no blocking issues.**

**Known consequence, deferred to ISS-142 — NOT a regression, read this before working on ISS-142:**
after this fix, base state may legitimately sit **out of range in both directions**:
- **Negative:** a cost affordable at composed level but larger than base (base MP 3/3, `+10` buff ->
  composed 13/13; a 5-MP skill leaves base **-2**, composed 8 — arithmetically correct).
- **Above max:** healing under a `+0/+10` maxHP buff caps at *composed* max and leaves base **15/10**.

Both are currently **unobservable**: `UnapplyBuff` and `RemoveBuffsByOrigin` have zero non-test
callers and every live buff is `Forever: true`, so no buff is ever removed. ISS-142 introduces
expiring skill buffs and owns expiry-clamp semantics — it must handle out-of-range base explicitly.

## Change Log
- **2026-08-27**: Filed. Found while scoping ISS-142's buff design; confirmed live by reproducing
  the unbounded `Movement` escalation against the real `Entity` type.
- **2026-08-27**: **Scope narrowed after enumerating every write site.** Corruption is confined to
  properties written *during* the match: `HP`, `SP`, `MP` and `Movement`. `Attack`, `Defense`,
  `AttackRange`, `JumpHeight` and `ArmorRating` are written only at entity construction — before
  `applyItemAsBuff` runs — so buffs on them are already correct and need no work. Also found that
  skill cost payment (`skill_validation.go:250-268`) corrupts via `GetPropertyC` + `UpdateProperty`,
  bypassing `UpdatePropertyValue`, so the fix must target composed-read/base-write pairs rather than
  one accessor. Fix is now a small standalone change rather than a repo-wide audit.
- **2026-08-27**: **`Shield` added to the affected set.** The user ruled `Shield` buffable, with the
  same semantics as any other resource (`Poison` and `Stun` remain non-buffable). `Shield` is
  written in-match via `UpdatePropertyValue` at `effectapplicator.go:150,176,249` and absorbed
  against at `attack.go:77-89`, so it corrupts by the same composed-read/base-write mechanism as
  `HP`/`SP`/`MP`/`Movement` and must be covered by this fix. Affected set is now five properties.
- **2026-08-27**: Shield remains in this fix's affected set, treated **exactly as any other
  resource** — no Shield-specific handling. Its special mechanics are deferred to **ISS-146**.
- **2026-08-28**: **RESOLVED.** Implemented via a base-delta write primitive
  (`AdjustPropertyCValue`) plus base-only accessors; six shared write helpers switched to base reads.
  A fifth corrupting site, `move.go:76-79` (move cost payment), was found during implementation and
  fixed — it was not in the 2026-08-27 enumeration. Test-first with 4 regression tests confirmed
  failing pre-fix and independently re-reproduced by the reviewer. Full suites green (62 + 189).
  Reviewer verdict OKAY. Recorded that base may now legitimately be out of range in both directions
  (negative and above-max), deferred to ISS-142 which owns buff-expiry clamping. Not yet committed.
