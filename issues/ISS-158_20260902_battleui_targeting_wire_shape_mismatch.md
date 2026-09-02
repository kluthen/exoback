# Issue: The battle client reads a targeting wire shape the engine never sends — `TargetType` silently falls back to 'Entity' and `Zone` is unreachable

**ID:** ISS-158_20260902_battleui_targeting_wire_shape_mismatch
**Ref:** ISS-158
**Date:** 2026-09-02
**Severity:** Medium
**Status:** Open
**Component:** `upsilonbattleui/src/composables/useActionDispatch.js`
**Affects:**
- `upsilonbattleui/src/composables/useActionDispatch.js:145,174,261` — `skill.targeting?.Range?.value`, `skill.targeting?.TargetType?.value ?? 'Entity'`
- `upsilonbattleui/src/Pages/BattleArena.vue:19,81` — the **real** battle client, imports `useActionDispatch`
- `upsilonbattleui/src/Pages/BattleArenaSandbox.vue:151,217` — same reads
- `upsilonbattleui/src/Pages/battleSandboxScenarios.js:43-101` — mock fixtures encoding the wrong shape
- `upsilonapi/api/output.go:404,408` — string properties serialize to `SValue`
- `upsilonapi/api/input.go:41` — `SValue *string \`json:"svalue,omitempty"\``
- `upsilonapi/api/output.go:345,356,369` — `Zone` is lifted out of `targeting` into a top-level field

## Summary

The frontend reads targeting properties as `{ value: ... }` for **all** kinds. The engine serializes
**string** properties as `{ svalue: ... }` (`output.go:404,408`, json tag `svalue`). So:

    skill.targeting?.TargetType?.value ?? 'Entity'

is `undefined` against real engine data and **silently falls back to `'Entity'`** — regardless of
whether the skill is actually `Self`, `Tile`, `FriendOnly` or `EnemyOnly`. The default is applied
without any signal that the real value was never read.

Separately, the fixtures nest `Zone` inside `targeting`, but `output.go:345,356` lifts `Zone` out into
a top-level `EquippedSkill.Zone` field and `:369` **explicitly skips** it when serializing the
targeting map. `targeting.Zone` therefore never exists on the wire.

## This is not sandbox-only

An earlier sweep characterised this as dead mock data. **That is wrong.** `useActionDispatch.js` is
imported by `BattleArena.vue` — the real battle client, not just `BattleArenaSandbox.vue`. The faulty
reads are on the live path. `SkillDetail.vue:74-77` also iterates `data.targeting` generically for
display.

## Impact

Targeting behaviour in the client is decided by a silent default rather than by the skill's actual
`TargetType`. This violates CODING_RULE §3 (no silent defaulting / crash early) and §4 (strict API
contract adherence — the envelope is a hard contract).

## Scope

- Read string properties from `svalue` (and confirm each property kind's real serialized field:
  `value`/`max`, `svalue`, `bvalue`, `fvalue`).
- Read `Zone` from the top-level `EquippedSkill.Zone` field, not from `targeting`.
- Replace the `?? 'Entity'` / `?? 1` silent fallbacks with something that surfaces a missing contract
  field instead of hiding it.
- Correct `battleSandboxScenarios.js` to the real wire shape — as written it actively teaches the
  wrong contract, and its inaccuracy is why the mismatch stayed invisible.

## Notes

Found during the property-key unification round's skill-definition sweep. Related: **ISS-156**.
