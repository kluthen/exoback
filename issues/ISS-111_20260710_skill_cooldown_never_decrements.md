# Issue: Skill Cooldown Is Set on Cast but Never Decremented — Permanent Lockout

**ID:** `20260710_skill_cooldown_never_decrements`
**Ref:** `ISS-111`
**Date:** 2026-07-10
**Severity:** High
**Status:** Open
**Component:** `upsilonbattle/battlearena/ruler/rules/skill_validation.go`
**Affects:** Any battle (`upsilonbattle`) in which a player casts an active skill more than once — every match, effectively. `upsiloncli/tests/scenarios/edge_attack_skill_cooldown.js` (EC-10) depends on this behavior and could only be made to assert it correctly, not fix it.

---

## Summary

`paySkillCost` sets `sk.Cooldown = skpc.GetMaxValue()` when a skill is cast (`skill_validation.go:248`), and `checkSkillCost`/the cooldown gate rejects re-use while `sk.Cooldown > 0` (`skill_validation.go:206`). No code anywhere in the repo ever decrements `sk.Cooldown`. A repo-wide grep for `Cooldown` (excluding tests) across `upsilonbattle` and `upsilontypes` shows exactly two live references to `sk.Cooldown`: the set at cast time and the read at the gate — no tick-down assignment (`sk.Cooldown--`, `sk.Cooldown -= 1`, or similar) exists anywhere. The only tick-down mechanism in the codebase, `Entity.BuffTickDown` (`upsilontypes/entity/entity.go:234`), operates on buff `TemporaryProperties`, is unrelated to skill cooldown, and is itself only invoked from a unit test (`entity_test.go:64`) — never from production turn-advancement code. **Once any active skill is cast, it is permanently locked out for the rest of the match.**

---

## Technical Description

### Background
Per the `Cooldown` property doc comment (`upsilontypes/property/propertyenum.go:88`): "Absence means 3 turns... Cool down is stored as a counter, minValue represent initial cooldown at battle start. MaxValue represent the cooldown value when used." The design intent is clearly a decrementing counter — cast the skill, cooldown counts down turn by turn, skill becomes available again once it reaches 0.

### The Problem Scenario
```
Turn N:   Player casts Skill X.
          skill_validation.go:248 → sk.Cooldown = skpc.GetMaxValue()  (e.g. 3)
Turn N+1: Player attempts Skill X again.
          skill_validation.go:206 → sk.Cooldown (3) > 0 → rejected, "skill.cooldown"
          (correct behavior for turn N+1)
Turn N+k (any k>1, for the rest of the match):
          Nothing has ever decremented sk.Cooldown.
          skill_validation.go:206 → sk.Cooldown (still 3) > 0 → rejected, "skill.cooldown"
          (INCORRECT — skill should be available again after 3 turns)
```
Confirmed via grep: `grep -rn "sk.Cooldown" upsilonbattle upsilontypes` returns only the set (line 248) and the check (line 206) — no decrement site exists in production code.

### Where This Pattern Exists Today
- `upsilonbattle/battlearena/ruler/rules/skill_validation.go:206` (gate), `:247-249` (set, no corresponding decrement).
- `upsilontypes/entity/entity.go:234` (`BuffTickDown`) — the only tick-down primitive in the codebase, unrelated to skill cooldown and dead in production (only called from `entity_test.go:64`).
- No call site exists in `ruler_turn.go` (turn-advancement) or anywhere else that would decrement `sk.Cooldown` per elapsed turn.

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | Certain — reproduces on every single active-skill cast, every match, no RNG or special conditions involved. |
| Impact if triggered | High (gameplay) — any active skill becomes permanently single-use per match, which is very likely not the intended design (the property doc explicitly describes a counter with a default 3-turn cooldown, implying reusability). Materially changes combat balance/strategy for the entire game. |
| Detectability | Low in normal play — reads as "this skill just isn't very good" or "I used my one good skill already," not obviously a bug, unless a player specifically waits out the documented cooldown and tries again. |
| Current mitigant | None found. |

---

## Recommended Fix

**Short term:** Confirm with design/gameplay owners whether "skill usable once per match" is actually the intended semantic (in which case this is a documentation bug, not a code bug — `propertyenum.go:88`'s "counter" language should be corrected) or a genuine regression.

**Medium term:** If skills are meant to be reusable, add a decrement call in the turn-advancement path (`ruler_turn.go`, likely alongside wherever per-turn entity state like move credits is reset) that ticks every equipped skill's `Cooldown` down by 1 (floored at 0) once per elapsed turn for its owner, mirroring the existing `BuffTickDown` pattern but wired into production turn advancement instead of only a test.

**Long term:** Add a unit test asserting a skill becomes castable again after its cooldown elapses (the mirror-image of the existing `skill.cooldown` rejection test), so this class of "set but never decremented" bug is caught by CI going forward.

---

## Extra Data

- Discovered during the ISS-107 CI edge-case audit while auditing `edge_attack_skill_cooldown.js` (scenario #10): the original scenario was a false-green (never actually reached the cooldown-rejection code path), and once rewritten to correctly cast-pass-cast-assert, the bug became visible in that the "cooldown should still apply on turn 2" assertion is correct today only because there is no decrement — the intended "cooldown clears after 3 turns" behavior was not and could not be tested, because it doesn't exist.
- Verified independently by the orchestrator via `grep -rn "Cooldown" upsilonbattle upsilontypes` (excluding `_test.go`): confirms no decrement site.

---

## References

- `upsilonbattle/battlearena/ruler/rules/skill_validation.go:206` (gate), `:247-249` (set)
- `upsilontypes/property/propertyenum.go:88` (`Cooldown` property doc — describes intended counter semantics)
- `upsilontypes/entity/entity.go:234` (`BuffTickDown` — analogous mechanism, unrelated property, dead in production)
- `upsiloncli/tests/scenarios/edge_attack_skill_cooldown.js` (scenario where this was surfaced)
