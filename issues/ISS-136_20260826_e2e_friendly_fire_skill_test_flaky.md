# Issue: `e2e_friendly_fire_skill_test.js` fails non-deterministically — narrow single-character probe window, not a masking regression

**ID:** `20260826_e2e_friendly_fire_skill_test_flaky`
**Ref:** `ISS-136`
**Date:** 2026-08-26
**Severity:** Medium
**Status:** Open
**Component:** `upsiloncli/tests/scenarios/e2e_friendly_fire_skill_test.js`
**Affects:** `upsiloncli` E2E scenario suite; local/CI stacks that rely on this scenario's pass/fail as a signal for `rule_friendly_fire` / `mech_skill_validation_entity_targeting_rules_verification` coverage

---

## Summary

`e2e_friendly_fire_skill_test.js` is flaky: three isolated runs against the live CI stack produced
**PASS / FAIL / PASS**. The failing run never reached a castable state at all — it burned its
entire match-attempt budget retrying match creation against a leftover active match, and the
`matchAttempt--` "don't count this attempt" logic at line 79 lets those retries consume wall-clock
without consuming the `MAX_MATCHES` budget. This is a pre-existing latent flake, not a regression:
the scenario file was not touched in the round that surfaced it (last modified `006a27f`; that
round's `upsiloncli` commit was `c5dc3c6`). A masking hypothesis (ISS-103's foe-loadout stripping
over-clearing `equipped_skills`) was investigated and is exonerated by the data. No existing issue
covers this — searched `issues/` for "friendly_fire" and "e2e_friendly_fire", no hits.

---

## Technical Description

### Background

The scenario provisions Fireball deterministically via an item grant, not via random skill
generation — this half of the mechanic is already correctly implemented:

```js
// lines 17-42
const fireballTemplate = admin.call("admin_skill_template_create", {
    name: "Fireball", targeting: { TargetType: "EnemyOnly", Range: { value: 0, max: 10 } }, ...
});
const amuletItem = admin.call("admin_shop_item_create", {
    name: "Amulet of Fire", skill_template_id: fireballTemplate.id, ...
});
// ... shop_purchase, then:
upsilon.call("character_equip", { characterId: pyromancerId, item_id: amuletInv.id });
```

The battle loop then runs up to `MAX_MATCHES = 3` matches, each up to `MAX_ROUNDS = 100`, looking
for a turn where the acting character holds Fireball and an ally is in range, then asserts (line
154) that a friendly-fire cast attempt is rejected within that budget.

### The Problem Scenario

1. The amulet (and therefore Fireball) is equipped on exactly **one** character:
   `const pyromancerId = charIds[0];` (line 51) → `character_equip({ characterId: pyromancerId, ... })` (line 58).
2. The battle loop acts as whichever entity currently holds the turn:
   `const me = upsilon.currentCharacter();` (line 94), guarded by `if (!me || !me.is_self) continue;` (line 95).
3. `const fireball = me.equipped_skills.find(s => s.name === "Fireball");` (line 110) is `undefined`
   whenever `me` is not `charIds[0]` — the comment at line 109 (`// Check if I am the "Pyromancer"`)
   shows this was known and accepted, not an oversight discovered here.
4. Consequence: only the turns where `me.id === pyromancerId` can ever exercise the friendly-fire
   assertion. This narrows the window the scenario needs to hit inside `MAX_ROUNDS = 100` /
   `MAX_MATCHES = 3`, and interacts badly with the match-creation retry accounting below.
5. Match-creation retries do not consume the match budget:

```js
// lines 66-82
for (let matchAttempt = 1; matchAttempt <= MAX_MATCHES && !fireballRejected; matchAttempt++) {
    ...
    try {
        matchData = upsilon.joinWaitMatch(gameMode);
    } catch (e) {
        upsilon.log(`Failed to join match: ${e.message}. Retrying...`);
        matchAttempt--; // Don't count this attempt
        upsilon.sleep(3000);
        continue;
    }
    ...
}
```

   A `Conflict: You are currently participating in an active match` on `joinWaitMatch` decrements
   `matchAttempt` back, so the loop can spin on conflicts indefinitely (bounded only by wall-clock
   via `upsilon.sleep(3000)`), while the actual castable-state budget never grows.

### Where This Pattern Exists Today

- Amulet equip on a single character: `upsiloncli/tests/scenarios/e2e_friendly_fire_skill_test.js:51,58`
- Turn-holder gate that silently skips non-Pyromancer turns: `upsiloncli/tests/scenarios/e2e_friendly_fire_skill_test.js:94-95,109-110`
- Conflict retry that doesn't cost budget: `upsiloncli/tests/scenarios/e2e_friendly_fire_skill_test.js:66-82` (specifically `matchAttempt--` at line 79)
- Misleading final assertion message: `upsiloncli/tests/scenarios/e2e_friendly_fire_skill_test.js:154`

### Measured Evidence

Three isolated runs against the live CI stack: **PASS / FAIL / PASS**.

| | conflicts | cast_attempts | "Pyromancer attempting" log lines |
|---|---|---|---|
| Failing run | 24 | 0 | 0 |
| Passing run 1 | 0 | 1 | present |
| Passing run 2 | 0 | 1 | present |

"conflicts" = `Conflict: You are currently participating in an active match` on match creation — 30
of 33 attempts across the three runs. The failing run produced zero `"Pyromancer attempting"` log
lines, i.e. it never reached a castable state at all; it was consumed entirely by conflict retries
before exhausting rounds/time.

**Masking hypothesis exonerated.** ISS-103 introduced foe-loadout masking in `MaskBoardState` that
strips `equipped_skills` from entities that aren't the viewer's own. The hypothesis that this
over-stripped `equipped_skills` from self/allies was measured and killed: across the run,
`equipped_skills` was present 170 times and empty only 9 times — not the dominant failure mode.

**Not a regression from this round's changes.** The scenario file was last modified in `006a27f`;
this round's `upsiloncli` commit is `c5dc3c6`. The flake predates and is independent of the
ISS-102/103/130/131 work.

**Open question, not yet verified — do not treat as fact:** whether a `1v1_PVE` match even fields
`charIds[0]` at all in every match. If match composition can select a subset of the roster, the
equipped Pyromancer character may be entirely absent from some matches, which would make this
structural (some matches are simply unwinnable for the assertion) rather than merely a narrow
per-turn window. Needs verification against the matchmaking/roster-selection code before assuming
either way.

---

## User's Original Framing (recorded for context)

Verbatim: *"i expected the fireball to have been a 'given' skill through item, forcing the
character(s) to have the fireball skill"*.

Half of this is already implemented: Fireball is granted deterministically via item
(`admin_skill_template_create` → `admin_shop_item_create` → `shop_purchase` → `character_equip`),
not left to random skill generation. Nobody should re-solve that half.

The other half is the real, unaddressed gap: the user said "character(s)", plural, but the amulet
is equipped on only `charIds[0]`, and the loop only probes friendly-fire on whichever entity
happens to hold the turn.

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | Medium — observed 1 failure in 3 runs (~33% in this small sample) |
| Impact if triggered | Medium — a spurious red on a CI/E2E gate for `rule_friendly_fire` coverage, which can either block an unrelated merge or (worse) get "fixed" by loosening the actual friendly-fire rule instead of the test |
| Detectability | Medium — the current failure message ("never rejected within 3 matches") does not distinguish "never got into a match" from "got in, cast, and was wrongly accepted", so a skim of CI output misattributes the cause to the engine rather than the harness |
| Current mitigant | None — `MAX_MATCHES = 3` / `MAX_ROUNDS = 100` are the only bounds, and conflict retries don't consume `MAX_MATCHES` |

---

## Recommended Fix

**Short term:** When this scenario shows a spurious red, check for `conflicts=N, cast_attempts=0`
in its log before assuming the friendly-fire rule itself regressed — that signature means the
scenario never reached a castable state, not that rejection failed.

**Medium term (suggestions, not decisions):**
1. Equip the Amulet of Fire on every character in the roster (loop `charIds`) per the user's
   "character(s)" intent, so every own-turn is a valid friendly-fire probe instead of only turns
   where `charIds[0]` happens to act. Requires purchasing N amulets or confirming a single item can
   be equipped roster-wide.
2. Fix the assertion message at line 154 to distinguish "never got into a castable state" from
   "cast attempted and wrongly accepted" — the current wording actively misleads triage.
3. Address the leftover-active-match session cleanup that produces the `Conflict:` retries (line
   79's `matchAttempt--` masks the cost of the retry loop rather than resolving the underlying
   leftover-match state).

**Long term:** Verify whether `1v1_PVE` match composition can field a roster subset that excludes
`charIds[0]`; if so, the equip-everyone fix above is necessary, not merely an improvement, and
match composition/roster-selection may need its own look.

---

## References

- `upsiloncli/tests/scenarios/e2e_friendly_fire_skill_test.js` — the scenario (lines 51, 58, 66-82, 94-95, 109-110, 154 cited above).
- ISS-102/103/130/131 round (`3db0e9d`) — the work during which this flake was characterized; scenario itself untouched (`006a27f` / `c5dc3c6`).
- `MaskBoardState` (foe-loadout masking, ISS-103) — investigated as a possible cause and exonerated by measurement.
