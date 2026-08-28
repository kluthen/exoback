# TODO — the ISS-140 round (opened on 140/141; now eight issues)

**Status:** `active` — ISS-141, ISS-144 and ISS-145's Dodge defect are DONE, reviewer-gated,
ATD-synced and **COMMITTED**. The round's original goal (ISS-140) is still four items deep.
**COMPACT-READY: no work is in flight, no agent is running, nothing is half-applied, working tree
is clean of round work.**
**Next action requires a USER DECISION** — ISS-145 Defect 1's design question (see Open questions).
Do not start ISS-142 or ISS-140 before it is answered; Defect 1 sets ISS-143's rename scope too.

**Opened:** 2026-08-27

---

## Round map — READ THIS FIRST

The round opened on two issues and grew to eight. Every addition was a defect found by verification
during scoping, not scope creep — but ISS-140, the issue the user actually came for, is now four
items deep and still untouched.

**Dependency chain:**

```
ISS-144  (buff writeback corrupts base state)   ─┐
ISS-145  (crit/accuracy/dodge unreachable;       ├─> ISS-142 ──> ISS-140
          Dodge read from attacker)             ─┘   (skill buffs)   (bridge fail-fast)
```

| Ref | Sev | Status | One-line |
|---|---|---|---|
| ISS-140 | High | Open | Bridge silently drops unrecognized skill properties. **The round's original goal.** Blocked by 142 |
| ISS-141 | Medium | **Resolved** | Melee attack damage coverage. Done, verified 3/3 + 5/5, ATD synced |
| ISS-142 | High | Open | Skills cannot apply attribute buffs. Blocked by 144 + 145 |
| ISS-143 | Medium | Open | Remove `propertyAliasMap` via coordinated cross-submodule rename. Not in this round's critical path |
| ISS-144 | High | **Resolved** | Property writes folded composed values into base. Fixed, reviewed, committed |
| ISS-145 | High | Open (**partial**) | Defect 2 (Dodge read from attacker) FIXED. Defect 1 (crit/accuracy/dodge unreachable) open — **needs a user design decision**; still gates ISS-142 |
| ISS-146 | Medium | Open | Shield-specific buff semantics deferred by decision; Shield = plain resource for now |
| ISS-147 | Medium | Open | Poison/Stun writes violate the new write-isolation invariant. Found by Workflow B, off critical path |

**Round scope RULED (user, 2026-08-27): the whole chain stays in this round.** ISS-140 is not to be
re-planned around a narrower path; the four items ahead of it are all in.

**Current action:** BLOCKED ON THE USER. ISS-144 + the Dodge fix are shipped and committed.
The next chain item is ISS-145 Defect 1, which carries an undecided design question that is the
user's to settle (Open questions #1). Nothing should be delegated until it is answered.

**Committed 2026-08-28** (4 commits, direct to `main` per repo convention, no branch/PR):
`upsilontypes` 2d1b743, `upsilonbattle` 1f62f73, `upsiloncli` 445d171, umbrella pointer bump +
issue tracker. Working tree retains only out-of-round items (AGENTS.md, the two CI scripts).

---

## Source

No external spec doc. Restated from the user's request and two filed issues.

### Item 1 — ISS-140: bridge silently drops skill payload properties
`issues/ISS-140_20260827_bridge_skill_payload_silent_property_drop.md`

When `upsilonapi/bridge` rehydrates a stored skill into engine state at arena start /
resurrection, any property key it cannot resolve — and any recognized key whose value it
cannot apply — is discarded with no error, no log, no signal to the caller. The engine then
substitutes that property's DEFAULT, so the skill that runs is not the skill that was
authored (an authored 10% damage effect silently runs at the default 100% of Attack).

Two silent-drop paths, both present in BOTH builders:
- Path A — unrecognized key: `bridge_utils.go:99-102` and `:119-122`, `prop == nil -> continue`.
  Root: `def.SkillProperty` (`upsilontypes/property/def/skill.go:328-391`) is a closed switch
  with a bare `return nil`.
- Path B — recognized key, unusable value: `setSkillPropValue` (`bridge_utils.go:43-90`)
  returns `hasValue = false`; callers simply don't append.

`bridge_utils.go:92` documents the silence as a feature ("Unknown keys are silently skipped
to ensure robustness"). That comment is to be deleted.

Blast radius beyond `effect`: `buildSkillPropertyMap` also feeds **Targeting** and **Costs**
(`bridge_start.go:247-248`, `bridge_resurrect.go:211-212`) — a dropped `Range` turns a
long-range skill melee; a dropped cost makes the skill free.

**User rulings on scope:**
- The proposed upsilonapi-side "checker" endpoint is **DROPPED**. Not this round.
- No authoring-time validation in `admin_skill_template_create` either. Bridge-level
  fail-fast only.
- Re-running the full E2E/EDGE suite afterwards is an explicit **discovery pass** — other
  scenarios silently riding on defaults are expected to surface. Those become NEW follow-up
  issues, they are NOT in-scope fixes for this round.

### Item 2 — ISS-141: no positive melee attack damage coverage
`issues/ISS-141_20260827_no_positive_melee_attack_damage_coverage.md`

No scenario asserts a melee `type: "attack"` lands and deals damage. Every `edge_attack_*`
asserts a REJECTION; positive-path fight scenarios assert only that rounds were played. A
regression zeroing melee damage would leave the suite fully green.

Blocker is reaching melee adjacency: board dims roll 5..15 per axis, adjacency reached in
only 1 of 5 runs on an 80-round budget. `edge_movement_already_attacked` and
`edge_attack_target_out_of_grid` are already quarantined under ISS-110 for this.

**User's chosen approach:** one "overkill" test fixture ITEM bolstering movement +
survivability + attack (+1000) so the bot can close distance, survive the approach, and
guarantee damage. Enemies equip nothing, so the asymmetry is natural. This deliberately
hedges BOTH candidate root causes (spawn distance AND survivability) without needing to
first prove which dominates.

**User ruling on the assertion:** assert on the reported damage in the action result
(`results[].damage > 0`). A lethal hit is a valid pass — "if the target is dead it's dead,
we should still get a report on damage dealt". `new_hp` decrease is at most a soft
diagnostic, NOT a hard assertion.

### Item 3 — ATD drift: `mech_combat_attack_computation` §A
Surfaced by the ISS-141 preflight, adopted by the user as in-scope for this round.

§A documents standard attack as `Attack - Defense` (floor 1). `attack.go` actually computes
`totalAttack = Attack + WeaponBaseDamage`, `effectiveDefense = Defense + ArmorRating`, plus a
backstab branch (1.5x, 50% armor pen).

**Scoping refinement (verified, not assumed):** backstab and armor-pen already have their own
atoms — `mechanic_backstab_detection_algorithm` (with a correctly-placed `@spec-link` at
`attack.go:63`) and `mechanic_armor_penetration_system`. So §A must NOT absorb backstab;
restating it would duplicate two existing atoms and create a second drift surface.
Correction is narrow: **fix the base formula's missing terms (`WeaponBaseDamage`,
`ArmorRating`), reference the sub-atoms for the modifiers.** documentalist's edit, not the
executor's.

---

### Item 4 — ISS-142: skills cannot apply attribute buffs (reframed at user direction)

Filed initially as a seed-data defect, reframed by the user: *"we need to ensure that skill that
buff works correctly. make it the main purpose of 142 (with side effect working on seeded skills)."*
User also accepted it blocking ISS-140: *"as for 142 blocking 140 it's okay. i don't predict 142 to
be that complex to solve"* — an estimate that has since proven optimistic (three parts, two
blockers). Later ruled: *"i want the complete solution for 142 to land prior working on 140"* — no
splitting the seed reshape out to unblock ISS-140 early.

Full buffability ruling is recorded in the issue file under "Design ruling" and "refinement 2".

### Item 5 — ISS-143: remove the bridge property alias map

User: *"property alias i don't like, either use the right name or fail"*, then tabled: *"ok table
the property alias as a separate issue for now, and ensure that the alias are correctly recognized
at api level for now. add a proper comment on alias that this isn't meant to be extended, but
removed at some point."* Not on the critical path.

### Item 6 — ISS-144 and ISS-145: found during ISS-142 scoping

Both are defects discovered by verification while scoping ISS-142's buff design, not user requests.
Both block ISS-142. See the issue files; the reproductions are recorded there with their numbers.
User approved implementing ISS-144 plus ISS-145's Dodge fix as one bounded handoff.

## ATD preflight (both PROCEED, no STABLE/BUSINESS signoff required)

**ISS-140 — this is a COMPLIANCE fix, not a behaviour change.** The target behaviour is
already mandated by documentation that predates the issue:
- `upsilonbattle:contract_battle_contract` (CONTRACT / BUSINESS / **STABLE**) — "Fail fast on
  illegal state transitions rather than allowing undefined behavior."
- `upsilonapi:api_go_battle_start` (API / ARCHITECTURE / **STABLE**) — EXPECTATION amended
  2026-08-24 for ISS-131 names this exact scenario: a skill payload carrying an unrecognized
  or malformed property shape must return non-2xx with a well-formed `Success: false`
  envelope.
- No atom anywhere blesses the silent skip. `bridge_utils.go:92` is an unlinked developer
  comment with no atom backing — which is why deleting it is correct, not contentious.
- `upsilonapi:mechanic_skill_payload_resolution` (MECHANIC / IMPLEMENTATION / REVIEW) is the
  atom tagged in `bridge_utils.go` today. It covers DTO shape normalization (`Flex[T]`,
  polymorphic unmarshal) only and is SILENT on semantic key-resolution failure. **This is the
  atom that needs extending via Workflow E before code is written.**
- Ruled out as non-conflicting: `api_skill_template_admin_crud` (STABLE) validates only
  `behavior`/`grade`, says nothing about targeting/costs/effect map contents — so declining
  authoring-time validation contradicts no STABLE atom.

**ISS-141 — PROCEED.**
- Governing atom / `@test-link` target: `upsilonbattle:mech_combat_attack_computation`
  (MECHANIC / IMPLEMENTATION / DRAFT), **Section A** (standard non-skill attack).
- The fixture item gets **no atom and no `@spec-link`** — precedent is the Fireball item in
  `e2e_credit_economy.js`, equally real business data through a real admin API, which got no
  atom. It is setup, not the thing under test.
- The scenario file is NOT `@lint-ignore-atd` territory — test harness means "no atom of its
  own", not "exempt from `@test-link`".
- Equip mechanics already atomized, no update needed: `mechanic_equipment_stat_bonuses`,
  `mechanic_three_slot_equipment_system`, `entity_equipment_system`.

---

## Phase 4 findings (blast radius — VERIFIED)

### FINDING A — the real ISS-140 blast radius is the SEED DATA, not the two scenarios

`upsilonhub/internal/seed/seed.go:59-64` seeds **6 skill templates, and ALL THREE property
maps are malformed on every one of them.** Verified against the legal key set
(`upsilontypes/property/propertyenum.go:56-107`, 29 keys) and `def.SkillProperty`:

| Map | Seeded value | Verdict |
|---|---|---|
| targeting | `{"Type":"Single","Range":3}` | `Type` ILLEGAL (legal key is `TargetType`). `Range` legal; bare `3` unmarshals fine via PropertyDTO's primitive fallback |
| costs | `{"MP":3}` | ILLEGAL. `MP` is an **EntityProperties**, not a SkillProperties. Legal cost key is `MPLeech` |
| effect | `{"Type":"Damage","Value":10}` | BOTH keys ILLEGAL. Legal shape is `{"Damage":10}` |

**Consequence: every seeded skill in the product currently runs with defaults across the
board** — no target-type restriction, default range (1 = melee), **free to cast**, and default
damage of 100% of Attack. These are the skills real players get, not just test fixtures. This
is a live production-data defect, materially bigger than the two test scenarios ISS-140 was
filed about.

### FINDING B — two seeded skills are NOT EXPRESSIBLE in the legal key set

Fixing seed.go is NOT a mechanical reshape. Two templates encode semantics with no legal
SkillProperties representation at all:
- **Sprint** — `{"Type":"Buff","Stat":"Movement","Value":2,"Duration":2}`. There is no
  stat-buff skill property in the 29-key set. A movement buff cannot be expressed as a skill
  effect. `RepositionSubject`/`RepositionDistance` exist but are a different mechanic (forced
  movement, not a Movement-stat buff).
- **Regen Aura** — `{"Type":"Buff","Stat":"HP","Value":1,"Duration":-1}`. Possibly
  approximable as `{Heal:1, Duration:-1}`, but that is a semantic decision, not a translation.

Mechanically translatable: Fireball/Lightning Strike (`{Damage:N}`), Heal
(`"Recovery"` → `{Heal:10}`), Shield Bash (`"Stun"` → `StunPower` + `Duration`).

**This needs a product decision, not an executor.** Blocked pending user ruling.

### FINDING C — explorer claim CORRECTED (verified against source)

Sweep (a) flagged `targeting: { TargetType: "EnemyOnly", Range: { value: 0, max: N } }` in the
two scenarios as "likely bad". **That is wrong.** `PropertyDTO` (`upsilonapi/api/input.go:36`)
is exactly `{value, fvalue, max, bvalue, svalue}`, and `setSkillPropValue` maps Value+Max to an
IntCounterProperty. The nested `Range` shape is CORRECT — it is the shape the known-good
`e2e_credit_economy.js` uses and the shape ISS-140's own text documents as expected. Only the
`effect: {Type, Value}` line is wrong in those two files. Do not "fix" their targeting.

### FINDING D — `damage > 0` is a NEARLY VACUOUS assertion for ISS-141

`attack.go:74`: `computedDamage := tools.Max(1, int(float64(totalAttack)*multiplier) - effectiveDefense)`

**Damage is floored at 1.** Any successful melee attack reports at least 1 damage regardless of
whether the Attack stat flowed through correctly. So `results[].damage > 0` would NOT catch the
exact regression ISS-141 exists to catch — a broken `totalAttack` computation still reports 1.
(Only a Shield absorbing the full hit yields 0, per `attack.go:77-89`.)

The +1000 Attack fixture is therefore not needed to make damage positive — it is needed to make
the assertion *discriminating*. Recommend asserting a MAGNITUDE (e.g. `damage > 500`) so the
test proves the attacker's Attack stat actually reached the formula.


### FINDING E — the buff mechanism: user's recollection CONFIRMED, with a precise gap

Verified for the ISS-142 discussion:
- **Items DO buff character attributes.** `applyItemAsBuff` (`bridge_start.go:192-230`) builds a
  `property.TemporaryProperties{Forever: true}` and resolves each item property key via
  `def.ItemProperty` then `def.EntityProperty` — so `Movement`, `HP`, `Attack`, `Defense` are all
  valid there. This is exactly the mechanism the ISS-141 overkill fixture item rides on.
- **An item's `effect` map is also folded into that buff** — `buildSkillEffect(item.Effect.Data)`
  stored as an `Effect` property inside the `TemporaryProperties` (`bridge_start.go:206-208`).
- **BUT no skill can create an attribute buff.** `RegisterBuff` has exactly two non-test callers
  in the whole repo, both in the bridge: `bridge_start.go:230` (item equip) and
  `bridge_resurrect.go:178` (restoring a persisted buff). `effectapplicator.go` contains **zero**
  occurrences of `Buff`, `Temporary` or `Duration`.
- Note `effectapplicator_buff_test.go` is MISNAMED — it tests Shield and Heal
  (`@test-link mechanic_effect_shield` / `mechanic_effect_heal`), not attribute buffs.
- The machinery exists but is unwired: `property.TemporaryProperties` has `Duration`, `Forever`,
  `TickDown()`, `MakeTemporaryProperties(duration)` and an **`OriginSkillID`** field — that last
  one implies skill-originated buffs were designed for and never built.

**Conclusion for ISS-142/Sprint:** the gap is NOT payload vocabulary, it is a missing engine
capability — the wiring from a skill effect to a durational `TemporaryProperties`. Items give
permanent (`Forever`) attribute buffs; nothing gives a 2-turn one.

### FINDING F — two more ISS-140-class defects in the same file

1. **`parseBehaviorType` (`bridge_utils.go:22-37`) silently defaults.** `default: return
   def.BehaviorTypeDirect` — an unknown/misspelled behavior string silently becomes "Direct".
   Same silent-default violation as ISS-140, same file, and the function already carries the
   `@spec-link`. **Recommend folding into ISS-140's scope** — it is the same fix.
2. **`propertyAliasMap` (`bridge_utils.go:12-16`) is path-asymmetric.** `ArmorRating`->`Armor`,
   `CritChance`->`CriticalChance`, `CritDamage`->`CriticalMultiplier` are applied ONLY in the
   item/buff paths (`bridge_start.go:217`, `bridge_resurrect.go:186`), NOT in
   `buildSkillPropertyMap`/`buildSkillEffect`. **ISS-140's collect-all must respect this
   asymmetry or it will emit false rejections** for legitimately-aliased item keys.

### Confirmed mechanics (no blockers)

- **Fixture item works as designed.** One `utility`-slot item carries all three stats via
  free-form `properties_json`; no per-property slot constraint. Pattern:
  `admin_skill_template_create` -> `admin_shop_item_create` -> `shop_purchase` ->
  `character_equip` (`e2e_credit_economy.js:36-120`). Proof of multi-property items:
  `upsilonapi/bridge/equipment_test.go:24-26`; `edge_attack_skill_cooldown.js:52` already
  uses `properties_json: {Defense: 500}`.
- **Movement is a non-issue.** `Movement` defaults to 3/turn, reset each turn. +10 gives 13/turn
  vs a 30-tile worst-case Manhattan gap on a 15x15 board. Residual risk is obstacle pathfinding,
  not distance.
- **Lethal hits report damage.** `ActionResult` (`upsilonapi/api/output.go:98-105`) is
  `{target_id, damage, heal, prev_hp, new_hp, credits}`; Damage is populated before the
  `foeHP <= 0` removal branch, so a kill still reports. User's ruling is safe.
- **Registration is automatic** — `run_all_scenarios.sh:56-58` globs `e2e_*.js`;
  `run_all_edge_cases.sh:86-88` globs `edge_*.js`. No registration file to touch.
- **ISS-140 ripple depth is 5 hops** and terminates cleanly at two HTTP handlers
  (`handler.go:20-40` HandleArenaStart, `handler.go:138-158` HandleArenaResurrect), which
  already wrap errors as 400 + envelope. Four currently-void functions must gain error returns:
  `registerEntitySkill` (bridge_start.go:235), `applyItemAsBuff` (bridge_start.go:192),
  `restoreEntitySkills` (bridge_resurrect.go:201), `restoreEntityBuffs` (bridge_resurrect.go:166).
  Envelope convention already exists: `api.NewError` / `api.NewErrorWithKey`
  (`upsilonapi/api/output.go:147-180`), error_key carried in `meta.error_key`.

---

## Decisions (current)

1. **ISS-140 checker endpoint: DROPPED.** Bridge-level fail-fast only this round.
2. **ISS-140 error strategy: COLLECT-ALL.** On a bad payload, gather every offending key in
   one pass and report them together — do NOT fail on the first. Rationale: the post-fix suite
   re-run is a discovery pass; failing one key at a time turns it into whack-a-mole where each
   fix reveals the next key in the same payload. Costs a little more code in the builders.
3. **ISS-141 fixture item carries movement + survivability + attack (+1000)** in one item;
   enemies equip nothing.
4. **ISS-141 assertion is `results[].damage > 0`**, lethal hit passes, `new_hp` soft only.
5. **`bridge_utils.go:3` file-header `@spec-link` IS in scope** — user approved absorbing it.
   It violates the links-atop-functions-only rule. `attack.go` places its links correctly and
   is the contrast case. Executor is editing this file anyway.
6. **`mech_combat_attack_computation` §A drift correction is in scope** for this round
   (Item 3 above), narrowed to base-formula terms only.
7. **seed.go is OUT of this round — filed separately as ISS-142** (High), since REFRAMED.
   `issues/ISS-142_20260827_seeded_skill_templates_all_malformed.md`. Rationale: it is a live
   production-data defect deserving its own severity, and two of its six templates need a
   product decision (Finding B) that would stall an execution round.
   **CRITICAL SEQUENCING: ISS-142 is a hard PREREQUISITE for ISS-140 landing.** Once the bridge
   errors on malformed payloads, every match started with a seeded skill fails at arena start.
   ISS-140 must NOT be merged before ISS-142 is fixed, or CI and the product both break.
8. **ISS-142 REFRAMED (user direction):** its primary purpose is now *making skills that buff
   attributes work correctly*; fixing the seeded templates is the side effect. Renamed to
   `issues/ISS-142_20260827_skill_originated_attribute_buffs_unsupported.md`. It remains the
   hard blocker for ISS-140, and the user has accepted that ("i don't predict 142 to be that
   complex to solve").
9. **propertyAliasMap: KEEP resolving at API level for now, but annotate** it as closed/frozen/
   not-to-be-extended/slated-for-removal, pointing at ISS-143. Full removal is a coordinated
   cross-submodule rename (frontend + hub gateway + character columns all speak the aliased
   vocabulary) and is tracked as **ISS-143** (Medium, filed). User ruling: "either use the right
   name or fail— honoured via explicit allow-list now, rename later.
10. **ISS-142 lands COMPLETE before ISS-140 begins — NO SPLIT (user ruling, 2026-08-27).**
   The short-term seed reshape is explicitly NOT to be carved out and shipped early to unblock
   ISS-140. The capability (skill-originated attribute buffs) and the seed correction land as one
   piece of work; ISS-140 waits behind the whole thing. Consequence accepted: ISS-140 is idle until
   ISS-142 is fully done and verified.
11. **`parseBehaviorType`'s silent `default: Direct` is folded into ISS-140** — same class of
   defect, same file.
12. **ATD link-placement nuance confirmed:** file-header `@test-link` IS the project convention for
   *test* files (E2E scenarios and Go `*_test.go` alike), since a test file is one cohesive unit.
   The "atop functions only" rule governs multi-function *source* files. Verified by documentalist
   against ~40 sibling scenarios. This is why `bridge_utils.go:3` is wrong (source file) while
   `e2e_melee_attack_damage.js:2` is right (test file).
13. **Buffability ruling (user, 2026-08-27):** buffable = entity **attributes only, including
   resources**. Buffing a resource's *current* value means **per-turn regeneration** — explicitly
   for `HP`, `SP` and `MP` alike, not just HP. Buffing its *max* raises the ceiling for the buff's
   duration, resolved **in favour of the recipient**. Malformed payloads fail **exactly like
   ISS-140** (collect-all, error, never default). My inference needing confirmation: statuses
   (`Shield`/`Poison`/`Stun`) and engine flags (`TeamID`, `Invisible`, `HasActed`, ...) are excluded
   despite being `EntityProperties` members.
14. **ISS-141 asserts a damage MAGNITUDE, not `> 0`** (e.g. `damage > 500`), because
   `attack.go:74` floors damage at 1 and `> 0` would not catch the regression the scenario
   exists to catch (Finding D).

### Correction on record
An earlier statement in this session cited `truedmg = max((attack*damage/100) - defense -
armor, 0)` as the melee formula. **That is wrong** — it is the SKILL tunnel formula
(`mechanic_effect_damage`), applying only to `type: "skill"` casts through
`effectapplicator.go`. Melee `type: "attack"` uses the linear `attack.go` path. The
conclusion (+1000 attack clears either) held by accident. The new scenario must document the
REAL melee math, not copy `e2e_credit_economy.js:68`'s comment.

---

## Open questions (current)

- ~~AWAITING: ATD preflight verdict for ISS-144 + the Dodge fix~~ **ANSWERED: PROCEED (both).** Full
  detail in the "ATD preflight #2" section above. Its one escalation — whether STABLE
  `mech_skill_validation` gates `paySkillCost` on same-file grounds — was **ruled by the user on
  2026-08-28: it does not.** Nothing ATD-side now blocks the handoff except Workflow E (step 19c).
- ~~Does the whole chain belong in this round?~~ **ANSWERED: yes, keep the whole chain.**
- ~~Are statuses excluded from the buffable set?~~ **ANSWERED, and my inference was wrong.**
  `Shield` **is** buffable, treated as any other resource. `Poison` and `Stun` are **not**. Shield's
  own special mechanics (2x maxHP cap, overshield, absorption, init-only max) are deferred to
  **ISS-146** — Shield is to be implemented as a plain resource with no special-casing, and
  implementers must not invent answers to the deferred questions.
- **Deferred, ISS-145:** whether crit/accuracy/dodge get promoted to `EntityProperties` or keep a
  skill-level declaration with an entity-level counterpart. Affects ISS-143's rename scope.
- **Noted interaction, not blocking:** `ISS-136` (Open, Medium) reports
  `e2e_friendly_fire_skill_test.js` as already non-deterministically flaky. ISS-140 requires
  editing line 26 of that exact file. Whoever verifies must not read a pre-existing ISS-136
  flake as a regression from their own edit — and must not read a green run as proof either.
- **Deferred to ISS-142, do not fix here:** `Upsilon_Battle.postman_collection.json:1108-1127`
  reproduces the same bad payload shape and teaches it to anyone copying from it.
- Deferred, NOT in scope, needs a later call: pre-existing `atd lint` failures (assorted atoms
  missing `## EXPECTATION`: `rule_friendly_fire`, `spec_match_format`, various
  `us_*`/`requirement_customer_*`). Unrelated to this round; do not let them mask new failures.

---

---

## ATD preflight #2 — ISS-144 + ISS-145 Dodge fix (2026-08-27)

**VERDICT: PROCEED (both changes).** No STABLE or BUSINESS atom's stated RULE/LOGIC is contradicted
or altered. No CONTRACT/VISION conflict (`contract_battle_contract` covers concurrency/determinism/
perf/fail-fast; both fixes are compatible with its determinism and fail-fast clauses).

Note: `upsilontypes`, `upsilonbattle`, `upsilonapi` are separate submodules, each with its own
`.atd`/`docs/`. Atom IDs below are project-qualified where they cross a boundary.

**Governing atoms — ISS-144:**
- `upsilonbattle:mechanic_item_buff_application` (IMPLEMENTATION, DRAFT) — documents the **read**
  side only (`GetProperty` iterating buffs via `ApplyBuff`). Says nothing about write paths, so it
  does **not** encode the broken write-back as intended. No drift.
- `upsilonbattle:mechanic_equipment_stat_bonuses` (IMPLEMENTATION, DRAFT) — parent; equipment-bonus
  narrative only, doesn't touch persistence.
- `upsilonbattle:mech_skill_validation` (IMPLEMENTATION, **STABLE**) — governs the *file*, but its
  LOGIC is scoped to the 8 pre-execution validation checks. `paySkillCost` (lines 244-271, the
  function this fix touches) is **deduction, not validation**, and carries no `@spec-link` of its
  own — only sibling `checkSkillCost` is tagged. See open decision below.
- `upsilontypes:mech_entity_properties` family (**STABLE**) — confirmed NOT in blast radius; only
  code reference is `property.go:12`, unrelated to entity.go's accessors.
- `rule_stat_taxonomy` (BUSINESS, STABLE, umbrella) — different system (Laravel-side CP/DB
  persistence), untouched.

**Governing atoms — ISS-145 Dodge:**
- `upsilonbattle:mech_combat_attack_computation` (IMPLEMENTATION, **REVIEW** — advanced by our own
  ISS-141 sync earlier this round) — sole atom mentioning Dodge in a hit-test context: "Hit Test
  (Skills Only): Accuracy vs Dodge roll." Under-specified as to *whose*, but endorses nothing wrong.
  Stays correct after the fix; no link move needed.
- `upsilonbattle:mechanic_exotic_attribute_progression` (DRAFT, unimplemented) — **independently
  corroborates the bug**: "Dodge provides a percentage chance to evade **incoming** skill-based
  effects", i.e. a defensive stat of the entity being attacked.

**Both changes confirmed COMPLIANCE FIXES, not business-rule changes.** Documentalist searched
explicitly for `composed`/`base state`/`write-back` across all three projects' docs and found
nothing describing write-back semantics at all — correct or broken.

**Confirmed gap (§3):** no atom in any submodule states the base/composed separation as an
invariant. `entity.go`'s `GetProperty`, `UpdatePropertyValue`, `RepsertPropertyValue` and
`RepsertPropertyCMaxValue` carry **zero** `@spec-link` tags. Verified absence, not a search miss.
Workflow E recommended to capture it before code; deliberately NOT created yet.

**D2 blast radius:** no `@spec-link` needs moving anywhere. None of the four affected functions
carries a surgical link today. Post-fix, entity.go's accessors are the placement targets for the
new invariant atom (Workflow B).

**Preflight escalations:**
1. ~~Open judgment call for the user~~ **RESOLVED (user, 2026-08-28): documentalist's judgment
   ACCEPTED.** STABLE `mech_skill_validation` is scoped to the 8 pre-execution validation checks;
   `paySkillCost` is deduction, falls outside it, and carries no `@spec-link`. Not gating, no
   sign-off required, verdict stays plain **PROCEED**.
2. Workflow E recommended before `@spec-link` is added (see plan step 19c).
3. Structural note, not blocking: the missing-`## EXPECTATION` pattern is repo-wide and broader than
   the list we knew about. Not introduced here.
4. `atd map`'s LLM pass was run and **discarded** — no semantic index is configured for any project,
   and it surfaced non-existent atom IDs (`[[EntityType]]`, `[[Position]]`). Only deterministic
   `check`/`lint`/`search --grep` findings were relied on.

---

## Plan

- [x] 1. Triage both issues; ground in the actual code
- [x] 2. ATD preflight D1 on both (documentalist) — both PROCEED
- [x] 3. Settle user decisions: collect-all, absorb header-link fix, adopt drift correction
- [x] 4. Blast-radius refinement — two codebase-explorer sweeps in flight:
- [x] 4b. File seed.go defect separately -> ISS-142 (High), index updated
- [ ] 5. documentalist D2 blast-radius confirm for ISS-140 once real diff shape is known
- [ ] 6. Workflow E pre-code capture on `mechanic_skill_payload_resolution` — record the
      collect-all error shape BEFORE implementation, so it is not reverse-engineered from the diff
- [ ] 7. Write the single combined plan; get user approval
- [ ] 8. Handoff to coding-executor (ISS-140 bridge fail-fast + scenario payload corrections +
      header-link fix)
- [x] 9. Handoff to coding-executor (ISS-141) — DELEGATED, running in background
- [x] 9b. ISS-141 VERIFIED independently — 3/3 reproduced (damage 995/1010/1000) on top of the
      implementer's 5/5. Artifact inspected directly: `@test-link` present and correctly placed,
      correct melee formula cited (with explicit warning against the skill formula), `damage > 500`
      magnitude assertion, nothing asserted on `new_hp`, only the one file added. Marked Resolved.
- [x] 9c. Issue bookkeeping: ISS-143 filed (alias removal); ISS-140 amended (collect-all,
      parseBehaviorType, alias annotation, header-link fix, verified 5-hop ripple, BLOCKED-BY note,
      Range-shape correction, ISS-136 interaction); ISS-142 reframed + renamed; both indexes refreshed
- [x] 10. documentalist: ISS-141 Workflow B sync + `mech_combat_attack_computation` §A drift
      correction — DONE. Atom advanced DRAFT -> REVIEW (first real e2e verification traffic). §A now
      carries the corrected base formula (`+WeaponBaseDamage`, `+ArmorRating`) and cross-references
      the backstab / armor-penetration / shielding atoms instead of restating them. Shield absorption
      was judged to belong to `mech_combat_shielding`, not §A. `atd check` OK; `atd lint` clean for
      this atom (13 pre-existing failures elsewhere, none introduced). Scenario `@test-link`
      confirmed correctly placed.
- [x] 11. ISS-142 implementation groundwork — the gap is TWO holes, not one (see ISS-142 addendum)
- [x] 12. Buffability design ruling captured from user; recorded in ISS-142
- [x] 13. **ISS-144 FILED (High)** — buff writeback folds composed values into base state;
      reproduced unbounded `Movement` escalation (3/3 -> 13 -> 23 -> 33 -> 43...) against the real
      `Entity`. Live today via any Movement item. **New hard blocker ahead of ISS-142.**
- [x] 14. ISS-144 scope narrowed by enumerating every write site — corruption is confined to
      `HP`/`SP`/`MP`/`Movement`; `Attack`/`Defense`/`AttackRange`/`JumpHeight` buffs are already
      correct and need no work. Fix is small and standalone, not a repo-wide audit.
- [x] 15. Buffability ruling refined (crit/accuracy/dodge in; flags out; Movement max-only;
      resource current-value buffs = turn-start regen, not read-composed)
- [x] 16. **ISS-145 FILED (High)** — crit/accuracy/dodge are `SkillProperties` only, resolve as
      neither entity nor item, so item/buff payloads drop them silently; crit is read from the
      effect not the entity; and `Dodge` is read from the ATTACKER instead of the target.
- [x] 17. Verified the refined rulings do NOT dissolve ISS-144 (max-only Movement buff still
      escalates 3/13 -> 13/23 -> 23/33 -> 33/43)
- [x] 18. User APPROVED (2026-08-27): proceed with ISS-144 + the ISS-145 Dodge two-line fix as one
      bounded handoff. Rest of ISS-145 (crit/accuracy/dodge entity-reachability) NOT in this handoff.
- [x] 19. documentalist D1+D2 preflight for ISS-144 + Dodge fix — **VERDICT: PROCEED (both)**
- [x] 19b. **DECIDED (user, 2026-08-28): ACCEPT PROCEED.** Documentalist's scope-based reading
      stands — STABLE `mech_skill_validation` governs the 8 pre-execution validation checks, not
      the deduction path, so `paySkillCost` is not gated and no sign-off is required. No re-flag to
      PROCEED-WITH-SIGNOFF-PENDING.
- [x] 19c. documentalist **Workflow E** DONE (2026-08-28). Atom created:
      **`upsilonbattle:rule_entity_property_write_isolation`** (RULE / ARCHITECTURE / DRAFT, v1.0,
      priority 5), parented to `[[shared:rule_stat_taxonomy]]` (BUSINESS, STABLE). No `@spec-link`
      placed yet — that is the post-fix Workflow B step. No source file touched anywhere.
      **Home project = `upsilonbattle`, not `upsilontypes`**, even though the four governed accessors
      live in `upsilontypes/entity/entity.go`. Justified against existing convention: entity.go
      already carries `@spec-link [[upsilonbattle:...]]` tags on types defined there; every violating
      call site is in upsilonbattle; preflight ruled the upsilontypes-side `mech_entity_properties`
      family out of blast radius; and sibling `rule_combat_range_validation` uses the same
      RULE/ARCHITECTURE + single `shared:` BUSINESS-parent shape.
      **Independently verified by me:** atom file present with stated frontmatter; reverse edge landed
      in `rule_stat_taxonomy`'s `dependents:` (NOT `parents:` — the git-diff hunk context line is
      misleading, checked the file directly, traceability direction is correct); `git status` confirms
      zero `.go` changes in upsilonbattle/upsilontypes/upsilonapi; atom body reviewed and it correctly
      covers the `paySkillCost` `GetPropertyC`+`UpdateProperty` path, not just `UpdatePropertyValue`.
      `atd lint` 69 pre-existing failures before and after, byte-identical — none introduced.
      `atd check --atom` = `0 impl / 0 tests / NO_IMPL`, correct for a pre-code atom.
- [x] 19d. H1 placeholder investigated — **NOT a defect in our atom; a confirmed `atd` tooling gap.**
      documentalist declined to hand-edit the file (correctly: its boundary is that atoms move through
      `atd` tooling) and escalated. **I verified the gap myself:** `atd update --help` exposes only
      `--set`, `--intent`, `--logic`, `--interface`, `--expectation`, `--spec-link` — there is no
      `--title`/`--h1`, and setting `human_name` does not resync the heading. The `# New Atom` line is
      written once by the creation template and passed through unmodified forever after. `atd lint`
      does not check H1 text, so the mismatch is structurally invisible to the tool.
      **Scope is repo-wide, not ours:** 7 of 331 atoms carry the placeholder H1, 6 of them
      pre-existing and unrelated to this round — `upsilonbattleui/docs/ui_game_selection`,
      `upsilonhub/docs/module_foe_loadout_masking`, `upsilonhub/docs/api_games_catalog`,
      `upsilonhub/docs/requirement_game_agnostic_accounts`, `docs/requirement_foe_loadout_privacy`,
      `upsilonbattle/docs/specification_arena_lifecycle`, plus our
      `rule_entity_property_write_isolation`.
      **RULED (user, 2026-08-28): authorize a one-line Edit-tool deviation for OUR atom only.**
      documentalist authorized and re-dispatched to change line 15 to
      `# Entity Property Write Isolation Rule`. This is a named, acknowledged deviation from the
      atoms-move-through-atd-tooling boundary, justified by the tool having no path for this text.
      The user **declined to file the underlying tooling gap as an issue**, so the 6 pre-existing
      placeholder headings stay as they are — deliberate call, not an oversight. **Residual left on
      the table (do not lose):** `atd update`/`atd_update` still have no H1<->`human_name` sync, so
      every future `atd`-created atom will carry `# New Atom` until someone fixes the tool.
      Cosmetic; does NOT gate step 20.
      NOTE on lint counts: the two documentalist runs reported 69 and then 37 findings/32 atoms —
      different project scope between invocations, not a regression. Neither run flags our atom.
- [x] 19e. H1 deviation APPLIED and verified: line 15 is now `# Entity Property Write Isolation Rule`.
      Atom not flagged by `atd lint`; `atd check --atom` still `NO_IMPL` (correct, pre-`@spec-link`).
      No source touched. The 6 pre-existing placeholder headings left alone per user scope ruling.
- [x] 20. **coding-executor DONE (2026-08-28).** ISS-144 + ISS-145 Dodge implemented.
      **Approach:** new delta primitive `AdjustPropertyCValue(p, delta)` on `Entity` — reads BASE,
      applies delta, writes base. Sound because `composed = base + buffSum` and buffSum is constant
      across one read-modify-write, so a composed-level delta applied to base is equivalent to
      stripping the buff. Plus new `GetBaseProperty`/`GetBasePropertyC` for the one absolute-target
      case (Movement restore). The 6 pre-existing write helpers switched from composed
      (`GetProperty`) to base (`getBasePropertyOrDefault`) internally.
      Executor deliberately did NOT use `property.UnapplyBuff` — its `tools.Max(delta, newMaxValue)`
      clamp gives wrong results for deltas smaller than the buff magnitude. Reasoning checked, agreed.
- [x] 20b. **VERIFIED INDEPENDENTLY BY ME (not taken on the executor's word):**
      - Build clean; `go test ./upsilontypes/...` = **62 passed / 13 pkgs**, `go test
        ./upsilonbattle/...` = **189 passed / 15 pkgs** — I re-ran both, counts match the claim exactly.
      - **`SetValue` does NOT clamp** (`defaultproperty.go:137` is a bare assignment), so base may go
        negative and the delta arithmetic stays correct even when a cost exceeds base. This was my
        main suspicion about the approach; it does not bite. **But see the residual risk below.**
      - **Shared-module blast check:** the 6 changed helpers have cross-module callers in
        `upsilonapi/bridge` (`bridge_start.go:172-178`, `bridge_start_archetype.go:169-181`,
        `bridge_resurrect.go:152-158`) — ALL at construction time, before any buff is registered, so
        base == composed there and the change is a no-op for them. `upsilonapi` working tree untouched.
      - **No missed sites:** every remaining `UpdateProperty(` in non-test upsilonbattle source is on
        `hasActed`/`hasMoved` (flags, not buffable). `beginingofturn.go` writes only `Stun` (ruled
        non-buffable this round). `ruler.go` writes only `TeamID`. Confirmed clean.
      - **Poison semantics preserved:** the can't-die-from-poison floor is now applied at the COMPOSED
        level via a base delta (`AdjustPropertyCValue(HP, 1-hp)`), so it still floors at exactly 1.
      - **Movement restore judgment call reviewed and ACCEPTED:** restore now targets
        `GetBasePropertyC(Movement).GetMaxValue()`. Paired buff -> composed stays 13/13 (identical to
        pre-bug intent, no gameplay regression); max-only buff -> 3/13. Both match the expected tables
        recorded in ISS-144 independently of the executor.
      - **Tests reviewed:** they assert COMPOSED values across 4 turns with exact pre-fix numbers
        (23/23, 13/23) matching the issue's independently-filed reproduction tables — i.e. they are
        structurally capable of catching the real bug, not tautological post-hoc assertions.
      - Change scale proportionate: upsilontypes +99/-6, upsilonbattle source +67/-43.
- [x] 20c. **Executor finding accepted: `move.go:76-79` (move cost payment) had the identical
      corruption on `Movement`** but was NOT in ISS-144's enumerated site list. In scope by the
      round's own definition (one of the 5 in-match-written properties); fixed. Update ISS-144's site
      enumeration to include it before close-out.
- [x] 21. **Reviewer gate: VERDICT = OKAY, no blockers (2026-08-28).** Unusually strong review —
      it independently reproduced the pre-fix failures rather than reasoning about them.
      - **Delta-equivalence CONFIRMED** for Value AND MaxValue, for arbitrarily stacked buffs:
        `DefaultIntCounterProperty.ApplyBuff` (defaultproperty.go:183-188) adds both fields linearly,
        so `composed = base + sum(buffs)`. No composed->base MaxValue write exists on any path.
        No aliasing hazard: `getBasePropertyOrDefault` returns `Duplicate()`. Type assertion safe —
        all five properties are `MakeIntCounterProperty`.
      - **Test integrity INDEPENDENTLY VERIFIED** via `git archive HEAD` into a scratch tree with only
        the new test files dropped in (working tree never touched). Pre-fix failures reproduced with
        matching numbers: 13/13 vs got 23/23; 3/13 vs 13/23; Dodge 1 damaged vs 0. **The one claim I
        could not verify myself is now verified.** (One number differs from the executor's report:
        the skill test's pre-fix actual is 25/30, not 25/20 — composed max escalates too.)
      - **Movement-restore decision CONFIRMED, and shown to be the ONLY atom-conformant option:**
        restoring to composed max also avoids escalation but folds the buff into base (13 against a
        base max of 3 for a max-only buff), violating EXPECTATION bullet 3. Reviewer flags the real
        gameplay consequence: a max-only Movement buff grants headroom that can never be refilled
        into (pinned 3/13). That is what the atom mandates.
      - **Deferral boundaries HELD:** ISS-146 Shield untouched (the `tools.Min(...maxhp*2)` cap is
        logically identical, only the write became a delta); ISS-145 remainder untouched (`accuracy`
        still reads from `ent` at effectapplicator.go:86, crit still off the effect at :128-129).
      - **`scripts/code_health_check.py` run pre vs post on all six changed files:** error counts
        identical (entity.go 9->9, skill_validation.go 1->1, all pre-existing). No new health debt.
- [x] 22. **Close-out work identified by the reviewer — ALL DONE:**
      - [x] **documentalist Workflow B DONE.** `rule_entity_property_write_isolation` advanced
            **DRAFT -> REVIEW**; `atd check` now **Impl=10, Tests=2, OK** (was NO_IMPL). TECHNICAL
            INTERFACE rewritten (stale "not yet placed" removed; call sites reframed as corrected;
            `move.go` addition called out). `@spec-link` placed atop 10 functions in
            `upsilontypes/entity/entity.go` and inline at the corrected call sites in
            skill_validation/move/attack/endofturn/effectapplicator. `@test-link` file-headers on the
            3 new test files (dodge test -> `mech_combat_attack_computation`, correctly, since it is a
            hit-test concern not a write-isolation one).
            Also fixed **stale paths** on `mechanic_item_buff_application` AND
            `mechanic_equipment_stat_bonuses` (both named the long-dead
            `upsilonbattle/battlearena/entity/entity.go`); added a companion-atom cross-reference.
            **Declined the parent-link change** I had queued from Workflow E, with sound reasoning:
            `parents:` encodes lineage, not dependency, and forcing the edge would conflate "must
            respect this invariant" with "exists because of this atom". Accepted.
            `atd lint` unchanged from baseline; no new failures. **I re-verified: build clean across
            all 3 modules, 62 + 189 tests still green after the comment insertions.**
      - [x] Stale docstring fixed in `rules_skill_writeisolation_test.go` (`25/20` -> `25/30`, with
            the reason: composed max escalates too). gofmt clean, package tests pass.
      - [x] ISS-144 site enumeration amended to include `move.go:76-79`; added to **Affects**.
      - [x] **ISS-144 marked Resolved** — full Resolution section added (approach, sites, semantics
            preserved, governing atom, verification incl. reviewer's independent reproduction, and the
            out-of-range-base consequence) + change-log entry. Index row + root README updated.
      - [x] **ISS-145 partial recorded** — Defect 2 (Dodge) resolved with its one-line diff, test
            evidence and the note that it is dormant until Defect 1 lands; Defect 1 stays Open and
            still gates ISS-142. Index row updated.
            **Gotcha hit and fixed:** I first set `**Status:** Open (Defect 2 resolved; ...)`, which
            the `issues` tool could not parse — ISS-145 silently vanished from
            `issues --status open`. Status must be exactly one of Open/In Progress/Resolved/Wont Fix.
            Reverted to `Open` and put the nuance in a separate `**Partial:**` field. Re-verified:
            open+high count back to 7.
      - [x] **ISS-147 FILED (Medium)** — see the new-drift section below.
      - [x] **ISS-142 precondition written** — the inherited out-of-range base (both directions),
            why it is unobservable today (zero non-test callers of `UnapplyBuff`/`RemoveBuffsByOrigin`,
            all buffs `Forever`), that ISS-142 owns the expiry-clamp decision, and that
            `UnapplyBuff`'s `tools.Max`-should-be-`tools.Min` defect is still live in its path.
            Also marked ISS-142 unblocked.

### NEW DRIFT found by Workflow B, filed as ISS-147 (2026-08-28)

The **Poison/Stun** application block (`effectapplicator.go` ~162-169) and cleansing block (~270-275)
use the exact composed-read/absolute-write pattern `rule_entity_property_write_isolation` prohibits.
Documentalist refused to tag them compliant and escalated rather than silently fixing them.

**Triaged: NOT dead code.** The round ruled Poison/Stun non-buffable, but that ruling is *design
intent only, unenforced*: `def.EntityProperty` resolves both (`upsilontypes/property/def/entity.go`
:135-138) and `applyItemAsBuff` (`upsilonapi/bridge/bridge_start.go:214-228`) falls through to it, so
an item with `properties_json: {"Poison": 5}` creates a real Poison buff today.

Filed as **ISS-147 (Medium)** rather than absorbed — ISS-144 was already Resolved and reviewed, and
this needs its own decision. Medium because it takes deliberately authored item data; no seeded item
does it. `Poison`/`Stun` are `DefaultIntProperty`, **not** `IntCounterProperty`, so
`AdjustPropertyCValue` does not apply as-is — the fix is either a fail-fast rejection of these keys
as buff properties (cheapest, matches ISS-140's stance) or a new delta path for `DefaultIntProperty`.
Independently corroborated afterwards by a backgrounded `atd check --semantic` run (same two blocks;
that run's separate claim that `AdjustPropertyCValue` "overwrites" rather than deltas is false and
was discounted as weak-local-model noise).

### ADJUDICATED residual: base may sit out of range in BOTH directions

Because `SetValue` does not clamp, after ISS-144 base can go **negative** (a cost affordable at
composed level but larger than base: base MP 3/3 with a +10 buff — composed 13/13 — a 5-MP skill
leaves base -2) **and above max** (healing under a +0/+10 maxHP buff caps at composed max and leaves
base 15/10 — the reviewer's case, more reachable than mine). This is arithmetically correct and is
exactly what makes the delta approach work.

**Reviewer verdict: correctly DEFERRED, not blocking.** Base state is currently *unobservable* —
`UnapplyBuff` and `RemoveBuffsByOrigin` have **zero non-test callers**, and every live buff is
`Forever: true`. Composed reads stay exact; `bridge_resurrect` stores base and re-registers buffs, so
persistence round-trips correctly even from a negative base.

**This is now written into ISS-142 as an inherited precondition** (both directions), together with
the note that ISS-142 owns the expiry-clamp decision and that `UnapplyBuff`'s
`tools.Max`-where-`tools.Min`-is-wanted defect is still live in that path. It will not be
rediscovered as a fresh bug.

- [x] 23. **Committed** (2026-08-28, direct to `main` per repo convention — the entire history is
      direct-to-main; no branch or PR was requested). Four commits, submodules first:
      `upsilontypes` **2d1b743** (base-state write helpers + `AdjustPropertyCValue` /
      `GetBaseProperty*`), `upsilonbattle` **1f62f73** (call sites, Dodge fix, 3 regression tests,
      new atom + 2 stale-path corrections; pre-commit ATD structural check PASSED), `upsiloncli`
      **445d171** (ISS-141 scenario + credit-economy determinism), umbrella (3 pointer bumps, 8 issue
      files, `rule_stat_taxonomy` dependents edge, both indexes, this file).
      Pre-commit verification: `code_health_check.py` run against a HEAD worktree vs the working tree
      — **error counts identical** (65/2/24, all pre-existing); +4 warnings, all
      "Many distinct ATD atoms: 6 (limit 5)" caused by the new `@spec-link`s (known tracked pattern,
      cf. ISS-126/ISS-127). Builds clean across `upsilontypes`/`upsilonbattle`/`upsilonapi`;
      62 + 189 tests green.
      **Deliberately NOT committed** (out of round, still in the working tree): `AGENTS.md`,
      `scripts/run_local_ci_reports.sh` (new), `scripts/run_ci_local.sh` (modified) — all CI/agent
      tooling from a parallel effort, unrelated to ISS-140..147.
- [ ] 11. Full E2E/EDGE suite re-run as discovery pass; file follow-up issues for new offenders
- [ ] 12. Reviewer gate before close-out; final report

---

## Handover

**State: clean, committed, compact-ready.** No agent is running, no handoff is in flight, nothing is
half-applied. The working tree contains no round work.

**The next action is not mine to take — it needs a user decision.** ISS-145 Defect 1 (crit,
accuracy and dodge are `SkillProperties` that resolve nowhere at entity level) must be settled first:
*promote them to `EntityProperties`, or keep them skill-level with an entity-level counterpart?* That
same choice sets ISS-143's rename scope, and Defect 1 still gates ISS-142. Do not delegate anything
on the chain before it is answered.

**Then, in this order (user-ruled, do not re-plan around a narrower path):**
1. **ISS-145 Defect 1** — design decision, then implementation.
2. **ISS-142 complete** — three parts: the buff effect family, turn-end expiry wiring at
   `endofturn.go:116`, and resource regen mirroring the poison tick. Plus it now owns the
   out-of-range-base clamp decision inherited from ISS-144 (see the adjudicated-residual section).
   The user ruled ISS-142 lands **complete** before ISS-140 begins — no splitting.
3. **ISS-140** — bridge fail-fast. Checker endpoint DROPPED (bridge-level only), COLLECT-ALL error
   strategy. Hard-blocked behind ISS-142's seed reshape. Followed by a full E2E/EDGE re-run as a
   **discovery pass**: new offenders become new issues, not in-scope fixes.

**Off the critical path, open:** ISS-143 (remove `propertyAliasMap`), ISS-146 (Shield semantics),
ISS-147 (Poison/Stun write isolation).

**Verification gotcha that will waste an hour if forgotten:** `upsiloncli/.env` sets the dead
`UPSILON_BASE_URL=http://localhost:8000`; the CI-mirror stack is on **:8085**. Scenarios fail at
register with connection-refused otherwise — looks like a scenario defect, isn't.

**Loose ends deliberately left, each harmless but do not lose them:**
- `attack.go:76-89` (shield absorption) carries no `@spec-link` despite matching
  `mech_combat_shielding`. One-line source comment; missed because that task was docs-only guarded.
- 7 of 331 atoms still carry the literal `# New Atom` H1 placeholder. The user ruled 2026-08-28 that
  only *our* atom gets a hand-edit and that the underlying `atd` tooling gap (no `--title`/`--h1`,
  `human_name` does not resync the H1, `atd lint` never checks it) is **not** to be filed as an issue.
- Documentalist's DRAFT->REVIEW advance on `rule_entity_property_write_isolation` was flagged "for
  visibility, not sign-off" and has not been separately adjudicated.
- **ISS-111** (High, Open) claims skill cooldowns are never decremented, but `endofturn.go` visibly
  ticks equipped-skill cooldowns. Likely stale — worth a 5-minute check, unrelated to this chain.
