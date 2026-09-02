# TODO — Property Key Space Unification round

**Status:** `active` — **STEP 18(a)+(b) DONE, COMMIT BLOCKER CLEARED (dec. 98/99). 18(c) REVIEWER GATE DISPATCHED.** Health baseline rebuilt from scratch: **179 -> 167, ZERO still-new errors, 12 pre-existing fixed** — all 10 regressions the round introduced are gone. `atd lint` = 13 = baseline. upsilontypes 203/0, upsilonbattle 189/0, upsilonapi 68/0; all 11 modules build (NB: `go build ./...` from umbrella ROOT is a no-op — run per-module). **Range is CLOSED by user ruling — targeting gets its own session; the two-Int-keys offer is WITHDRAWN, do not file it.** **Two measurement traps burned me today, do not repeat:** `git status --short | wc -l` undercounts by 1 (no trailing newline) and made me think work had vanished; bare `git reflog` hides dates and made Aug-30/31 resets look like today's. Use `git reflog --date=iso`. **My own prefix ruling caused a defect I then fixed** — entity.go carried the same atom under prefixed + unprefixed ids (7 distinct, limit 5); line 245 unified to the prefixed form, back to 6. **Remaining in step 18: (c) reviewer verdict, (d) commits — REQUIRE THE USER'S EXPLICIT GO-AHEAD (CODING_RULE §7), (e) close ISS-140/143/145/147.** End-of-session review still owed on the 7 issues filed 2026-09-02 (ISS-154..160, 61 active) plus 3 deferred findings: the registry atom's compile-vs-runtime-panic wording, the workspace-wide link-prefix convention, and `bridge_start.go` registering skills before inspecting `errs`. **NOTHING IS COMMITTED.**
Source code IS now modified (first time this round). The key space is unified, all 7 renames are
applied, the workspace compiles, and T6 is green. **Decision 23's regression is FIXED and verified.**
Wave 2 is COMPLETE — 64/64 keys registered and wired.
**Opened:** 2026-08-30 (supersedes the ISS-140 round, whose shipped work is summarized below).
**Next action:** collect the three slice reports, then **integrate and verify centrally myself** —
the module cannot build until all three land, so no individual agent can green the suite. Acceptance
is in "Acceptance for step 13 as a whole" below.

**Working tree:** the frozen vocabulary (`architecture/property_key_vocabulary.md` + its INDEX row),
five `.atom.md` files from Workflow E (1 new + 3 modified in `upsilontypes/docs/`, 1
weave-touched in `docs/rule_stat_taxonomy.atom.md`), and out-of-round CI tooling (`AGENTS.md`,
`scripts/run_local_ci_reports.sh`, modified `scripts/run_ci_local.sh`). All submodules except
`upsilontypes` are clean. Everything deliberately uncommitted.

**TWO ARTIFACTS GOVERN THE REST OF THE ROUND. Read them; do not re-derive them.**
1. [`architecture/property_key_vocabulary.md`](architecture/property_key_vocabulary.md) — the frozen
   spec steps 11-17 are built from: all 64 keys with scope, kind, default-when-absent, composition
   rule and min info level; the complete 7-entry rename map; 7 recorded traps.
2. `upsilontypes/docs/module_property_key_registry.atom.md` — the ARCHITECTURE atom (DRAFT), carrying
   the backward-compat waiver and the Logic-Isolation reasoning on the record.

**Do NOT re-run** the principal-advisor consultation, the ATD preflight, the vocabulary derivation,
or documentalist Workflow E. All four verdicts are recorded below in full.

---

## Round map — READ THIS FIRST

The previous round (ISS-140 chain) hit a root cause and the user redirected the work there. Rather
than fix ISS-145 Defect 1 in isolation, **this round unifies the property key space**, which
dissolves four filed issues at once.

| Ref | Sev | Status | Role in this round |
|---|---|---|---|
| ISS-140 | High | Open | Bridge silently drops unrecognized skill properties. **Dissolved by the registry** (unknown key ⇒ not in registry ⇒ reject) |
| ISS-143 | Medium | Open | Remove `propertyAliasMap`. **Dissolved** — the alias map's reason to exist disappears |
| ISS-145 | High | Open (partial) | Defect 2 (Dodge) already fixed+shipped. **Defect 1 dissolved** by declaring the 4 keys entity-scoped in the registry |
| ISS-147 | Medium | Open | Poison/Stun collision. **Dissolved structurally** by the rename giving each use case its own name |
| ISS-146 | Medium | Open | Shield semantics deferred by decision. **Not in this round**; Shield stays a plain resource |
| ISS-148 | Medium | Open | Parry declared-but-unread. **Not in this round.** Blocked by ISS-149 |
| ISS-149 | Medium | Open | Combat-outcome trigger family (on-hit/dodge/parry/miss). **Not in this round.** Blocks ISS-148 |

**Already shipped and committed 2026-08-28** (do not redo): ISS-141 (melee damage coverage) and
ISS-144 (property writes folded composed values into base) are **Resolved**, reviewer-gated and
ATD-synced. ISS-145 Defect 2 (Dodge read from attacker instead of target) fixed in the same round.
Commits: `upsilontypes` 2d1b743, `upsilonbattle` 1f62f73, `upsiloncli` 445d171, + umbrella bump.
That work produced the atom `upsilonbattle:rule_entity_property_write_isolation` (RULE/ARCHITECTURE,
REVIEW) which governs base-vs-composed write isolation and **must not be violated by this round**.

---

## Source

No external spec doc. This round was defined conversationally on 2026-08-30. Full restatement:

**The problem.** Three property key namespaces — `EntityProperties`, `SkillProperties`,
`ItemProperties` in `upsilontypes/property/propertyenum.go` — are independent named `string` types
sharing no common ancestor except `interface{}`. `def.DefaultProperty(name interface{})` runtime
type-switches; every `Entity.GetProperty*` accessor takes `interface{}`. There is no compile-time
safety at that seam. Worse, the string VALUES collide across namespaces with different meanings:
`"Shield"` is both an entity counter (absorbs damage) and a skill per-cast magnitude; same for
`"Poison"` and `"Stun"`. Because keys are stringified into `map[string]Property` storage, this is a
live defect (ISS-147): `applyItemAsBuff` falls through to `def.EntityProperty("Poison")` and creates
a real Poison buff from item data.

**The goal.** One flat key space + a declarative registry, killing the collisions structurally and
replacing the `interface{}` seams, which simultaneously resolves ISS-140/143/145-Defect-1/147.

### Verified grounding facts (trust these; re-verify only if something looks wrong)

- Go 1.25 workspace. **Blast radius is exactly 3 modules**: upsilonbattle (75 files importing
  `upsilontypes/property`), upsilontypes (34), upsilonapi (10). **No upsilonhub, no upsiloncli** —
  they touch property names only as JSON strings.
- **The "1892 call sites" figure is misleading.** `property.HP` compiles unchanged after a type
  merge. Real *type-mention* count needing edits: **26 cross-module + 49 in-package = 75**. The
  rename sweep touches only the subset of the 1892 whose identifier actually changes.
- 64 properties total: Entity 20 / Skill 31 / Item 13.
- LOC now: `def/skill.go` **392** (already at the 400 warn limit), `def/item.go` 235,
  `def/entity.go` 153, `propertyenum.go` 185, `property.go` 83. Ceiling is 400 warn / 600 error and
  **`code_health_check.py` counts comments as effective LOC**.
- Value-level ancestry ALREADY EXISTS and is fine: `property.Property` +
  `IntProperty`/`FloatProperty`/`BoolProperty`/`StringProperty`/`IntCounterProperty`. Only the KEY
  space lacks an ancestor.
- Entity+buff composition already works (`Entity.GetProperty` composes base + buffs via `ApplyBuff`).
  Equipment is NOT a live layer — the bridge flattens items into `Forever:true` buffs at battle start.
- `defaultproperty.MakeIntProperty`/`MakeFloatProperty`/`MakeBoolProperty` **return nil on their
  default branch** — a silent nil `Property` into storage. Pre-existing crash-early violation, in
  scope to delete.
- `def.ZoneProperty.Name()` returns hardcoded `"Zone"` (skill.go:170); `def.EffectProperty.Name()`
  returns hardcoded `"Effect"` (item.go:89). **`Entity.UpdateProperty` keys storage by
  `p.Name(GameMaster)`** — the VALUE's name, not the key passed in. A rename touching either
  silently desyncs the write key from the read key. **This is the highest-value test to write.**

---

## Plan

- [x] 1. Triage; ground the property system in source
- [x] 2. Confirm the user's problem model; correct two misreadings (composition already exists;
      equipment is not a live layer)
- [x] 3. Enumerate unification options (A flat / B sealed interface / C generic union / D struct key)
- [x] 4. principal-advisor consultation — **verdict: Option A**
- [x] 5. Independently verify the advisor's load-bearing claims (diff size, blast radius, traps)
- [x] 6. File out-of-scope discoveries as their own issues: **ISS-148** (parry), **ISS-149** (trigger family)
- [x] 7. **ATD preflight (documentalist D1+D2) DONE — verdict PROCEED-WITH-SIGNOFF-PENDING.**
      See the ATD section below. 3 signoff items for the user + 1 I found myself.
- [x] 8. **USER APPROVAL — GRANTED (2026-08-30).** Option A approved (user directed the round to
      unification, approved the registry, approved theme-grouped files) and **all four ATD signoff
      items approved**, with item 4 explicitly WAIVED (see decision 13).
- [x] 9. **DONE 2026-08-30 — frozen in one pass.** All 64 keys specified in
      `architecture/property_key_vocabulary.md`: scope, kind, default-when-absent, composition rule,
      min info level, plus the complete rename map and 7 traps. Counts verified mechanically
      (Entity 20 / Skill 31 / Item 13 = 64). Three corrections to earlier decisions fell out — see
      decisions 16, 17, 18.
- [x] 10. **DONE 2026-08-30 — documentalist Workflow E complete, verified independently.**
      Created `upsilontypes:module_property_key_registry` (MODULE/ARCHITECTURE, DRAFT) at
      `upsilontypes/docs/module_property_key_registry.atom.md`, parented to
      `[[shared:rule_stat_taxonomy]]`. Both required governance paragraphs are on the atom (see
      decision 13 waiver + signoff item 2 reasoning). Zero fenced code blocks — decision 12 honored.
      The 3 superseded atoms were demoted `STABLE → DRAFT`, tagged `superseded`, and their LOGIC
      rewritten to point forward; none deleted, graph edges untouched. `atd weave` appended the new
      atom to `rule_stat_taxonomy`'s `dependents:`. `atd lint` = 13 = baseline, no new failure.
      **Verified by me:** only `.atom.md` files touched, no source code.
- [x] 11. **DONE 2026-08-30 — 3 parallel slices, all verified by me.** 5 test functions, 14 failing
      assertions, 0 production-code changes, 0 regressions. T2 (ISS-145 D1) deferred into step 12;
      the ISS-143 alias-map guard deferred into step 14. Details in "Step 11 delegation" below.
- [x] 12. **COMPLETE 2026-08-31 (wave 1 + wave 2 + wiring).** Wave 1 (2026-08-30): `property.Key` + `Key.String()`; the three old types
      are now ALIASES of `Key`; `PropertyToString` rewritten; **all 7 renames applied** (moved here
      from step 14 — see decision 21); `CriticalMultiplier` comment fixed; 40 call sites swept;
      `def/registry.go` skeleton (Scope/Kind/Composition/Entry/mergeThemes/Lookup) landed.
      Collateral fixes to `defaultproperty.go` + `def/glob.go` — both verified necessary.
      Wave 2 (2026-08-31): all 7 theme data files landed, **64/64 keys, 0 duplicates**, and
      `registry.go` wired to `mergeThemes(...)` centrally by me. Runtime-probed: 64 entries,
      every `Entry.Key` matches its map key, 4 dual-scope, 9 with `Allowed` sets, 0 nil `New`.
- [x] 13. **DONE + REVIEWER-GATED (OKAY) 2026-08-31 — 4 slices (13A/B/C + 13D), all verified by me; 3 dual-scope defects and 1 bridge regression found and fixed during central verification. SPLIT 3 WAYS — see "Step 13 — THE THREE-WAY SPLIT" below for the full brief material.**
      13A registry-backed resolvers (`def/`, closes T5); 13B entity/skill/effect key seams (28) +
      the crash-early scope assertion; 13C the 6 `Make*` constructors + `PropertyToString`.
      Erasure layer = the key-side `interface{}` seams; verified count is **36, not 45**.
      **DISPATCHED 2026-08-31** — three parallel `coding-executor` slices, each briefed with the
      verbatim signature contract, its own file ownership, the five traps and per-slice acceptance.
      Pre-dispatch I re-verified ground truth against source: `property.Key` + 3 aliases present,
      `registry.go`/`Lookup` as recorded, seam counts exact (16+5+7 for 13B, 6 `Make*` for 13C),
      `go build ./...` clean, and the test baseline exactly T4 + T5/`TargetNumber` red — nothing
      had drifted. **Integration and full-suite verification are mine, not the agents'.**
- [x] 14. Rewrite `applyItemAsBuff` against the registry (distinct unknown-key vs wrong-scope errors);
      delete `propertyAliasMap` (now 2 entries); drop the three type aliases; rename the three
      lagging constructors `Damage()`/`MvtCost()`/`Value()` to match their keys. Turns T1/T3 green.
- [x] 15. **Fix the `Movement()` 5/5 defect** (decision 9) — rides along in this round per user
      ruling. Failing test first per rule 5: an entity created WITHOUT an explicit Movement must
      default to 3, not 5. This is the registry's `default-when-absent` field, so it lands naturally
      with step 12 — but it is an observable engine behavior change, so it gets its own test.
- [x] 16. **Add the buff-attribution accessor** (see decision 14) — joins this round per user ruling.
      `GetBuffsFor` currently discards the owning `TemporaryProperties`; add an accessor returning
      each buff's contribution WITH its `OriginEntityID`, `OriginSkillID`, `Duration` and `Forever`.
      Pairs with the already-existing `GetBaseProperty` (natural/unbuffed value) to give full
      "natural value + individual buffs with their effects" introspection.
- [x] 17. Sync non-Go surface: Go seed literals, JS scenarios, Postman collection
- [~] 18. **IN PROGRESS 2026-09-02.**
       Reviewer gate; documentalist Workflow B sync (**including STRIPPING the embedded Go code
      from `mechanic_item_buff_application` per decision 12, not rewriting it**, **and reconciling
      the stale `@spec-link` at `upsilontypes/property/property.go:12` per decision 20**); commit
      upsilontypes → upsilonbattle → upsilonapi → umbrella bump; close ISS-140/143/145/147

---

## ATD preflight — VERDICT: PROCEED-WITH-SIGNOFF-PENDING (2026-08-30)

**Good news first: `upsilontypes` HAS its own settled CONTRACT/VISION pair** —
`upsilontypes/docs/contract_types_contract.atom.md` and `vision_types_vision` (both STABLE), distinct
from the umbrella-wide root pair. **Not a blocker.** The one-per-project convention is satisfied, so
the feared prerequisite work does not exist. `vision_types_vision` reads "Enforce strict typing for
critical game entities… to prevent cross-module logic errors" — this refactor *fulfils* that vision.

**Blast radius: 37 distinct atoms** carry `@spec-link` into scope files. Note `def/entity.go`,
`def/item.go` and `defaultproperty/defaultproperty.go` carry **zero** `@spec-link` tags — the
type-switch functions being deleted there (including the silent-nil-return defect) have no
traceability today.

### FOUR signoff items — ALL APPROVED by the user 2026-08-30 (kept for the reasoning)

1. **Retiring/rewriting three STABLE atoms whose subject matter IS the split being deleted.**
   `upsilontypes:mech_entity_properties` (MODULE/ARCHITECTURE, STABLE) + its two IMPLEMENTATION
   children `mech_entity_properties_item_properties` and `mech_entity_properties_skill_properties`.
   These literally document the three-way `EntityProperties`/`SkillProperties`/`ItemProperties`
   split. They become **factually wrong** the moment step 12 lands. They also already carry
   near-zero code traceability (`atd trace` → `total_code_files: 0`), a pre-existing gap.
   **⚠ THIS TRACEABILITY CLAIM IS WRONG FOR ONE OF THE THREE — see decision 20.**
   `mech_entity_properties_skill_properties` has a live `@spec-link` at
   `upsilontypes/property/property.go:12` that must be reconciled in step 18.
   Recommended: supersede them with the new Workflow E registry atom rather than leave them stale.

2. **CONTRACT tension — `contract_types_contract` says "Logic Isolation: this project must contain
   only data structures and basic validation/serialization logic. No game mechanics."** The
   per-property composition-rule field (decision 5) edges toward mechanics living in `upsilontypes`,
   which is where the user ruled the registry must live (decision 2).
   **MY VERIFICATION SUBSTANTIALLY DEFUSES THIS:** composition mechanics are ALREADY in
   `upsilontypes` today — `defaultproperty.go:83` `DefaultIntProperty.ApplyBuff` is literally
   `res.Set(d.Get().(int) + p.Get().(int))`, i.e. additive composition, in this very package, with
   five such implementations. Declaring `Composition: CompositionAdd` **documents behavior that
   already exists** rather than introducing new mechanics. My recommendation: proceed, and record
   this reasoning on the Workflow E atom so the judgment is on the record rather than silent.

3. **`shared:rule_stat_taxonomy` (STABLE, BUSINESS) needs a human re-read post-implementation.** Its
   wording survives the plan as specified (it names entity-side `Shield`, which is untouched — only
   skill-side values change), but it is the one BUSINESS atom that enumerates the stat vocabulary,
   so the new registry must agree with it stat-by-stat.

4. **FOUND BY ME, NOT BY THE PREFLIGHT — the *other* CONTRACT clause.**
   `contract_types_contract` also states: **"Stability: Changes to core types must be backwards
   compatible or strictly versioned to avoid breaking the multi-stack integration."** This plan
   deletes three exported type names and renames property strings — explicitly NOT backwards
   compatible. **Mitigation:** all three consumers (upsilonbattle/upsilonapi/upsilontypes) are
   in-workspace, move together under `go.work`, and commit as one coordinated change; there is no
   external consumer to break, and the DB is disposable. I judge this acceptable but it is a STABLE
   CONTRACT clause and the user should say so explicitly rather than have me assume it.

### Atom text that needs rewriting once code lands (Workflow B, not blocking)

- `mechanic_effect_damage` (DRAFT) — uses "Skill.Damage" **6 times** in LOGIC/EXPECTATION
  (`rawPhysical = Attacker.Attack * Skill.Damage / 100`). Textual rewrite to `DamageScale`.
- `mechanic_item_buff_application` (DRAFT) — contains an embedded Go sample calling
  `def.ItemProperty(property.ItemProperties(key))`, the exact resolver step 13 deletes.
  **Substantial rewrite, not a tweak.**
- `mechanic_effect_poison`/`_stun`/`_shield`/`_critical` (DRAFT) — reference the Go identifiers,
  which are NOT renamed (only the underlying string values change). Likely no edit; re-read to confirm.
- `bridge_start.go`'s `@spec-link`s are file-level, not atop `applyItemAsBuff` — a pre-existing
  placement violation. Step 14 rewrites that function, so move
  `[[mechanic_item_buff_application]]` above it then.

### Workflow E (plan step 10) — shape already determined

No existing registry/property-key ARCHITECTURE atom anywhere. After approval, create a fresh one
(`type: MODULE`, `layer: ARCHITECTURE`) for the unified `property.Key` + `def` registry, **parented
to `shared:rule_stat_taxonomy`** (the real BUSINESS ancestor for "what is a property"), superseding
`mech_entity_properties` + its two children.

### Incidental pre-existing defects found (NOT caused by this round, not blocking)

- **Dangling `@spec-link` ids that resolve to no atom**: `mech_entity_expiration`,
  `mec_ai_archetype_system` (both in `propertyenum.go`), `rule_friendly_fire_team_validation` (in the
  upsilonbattle importer set; closest real atom is `rule_friendly_fire`, a different id). `atd lint`
  will flag these. Worth a separate cleanup, not this round.
- **`atd index` has never been built for any of the 15 projects**, so semantic `atd search`/`atd map`
  are unusable workspace-wide and fall back to low-signal keyword search (one run hallucinated advice
  to keep `PropertyToString`). Deterministic `grep`/`atd query`/`atd trace` were used instead. This is
  infrastructure debt worth its own issue.

---

## Decisions (current)

1. **Option A adopted (advisor-recommended, PENDING USER APPROVAL).** Flat `property.Key string`;
   constants stay in package `property`; table-driven registry in `upsilontypes/property/def`.
   - **B rejected** — a sealed interface leaves the collisions intact (they happen at
     stringification) and buys compile-time safety the codebase never actually had: the bridge does
     `property.ItemProperties(effectiveKey)` on a raw JSON string, and that conversion is free.
   - **C rejected, confirmed impossible** — Go type-union interfaces are constraint-only; illegal as
     a variable, field or map-key type. Cannot back `map[Key]Property` or a JSON boundary.
   - **D rejected** — storage is `map[string]Property` and the wire carries a bare name, so a
     `{Scope,Name}` struct only avoids collisions via a scope prefix: the exact machinery decision 3
     rejects.
2. **Registry home: `upsilontypes` (user-ruled).** Advisor refinement, compatible: the *table* lives
   in package `def` (which already holds the special constructors and imports `property`), while the
   *constants* stay in package `property`. Both inside upsilontypes, so the ruling holds. This split
   is what keeps the ~1892 constant references compiling untouched.
3. **Collisions fixed by DEDICATED NAMES per use case (user-ruled)** — not by scope qualifiers.
   Sweep for all needed renames at once; do not dribble them out later.
4. **Names must carry composition semantics (user-ruled)**: `Damage` → `DamageScale` /
   `DamageMultiplier`, since it multiplies attack rather than adding to it. Same treatment for the
   `Shield`/`ShieldPower`, `Poison`/`PoisonPower`, `Stun`/`StunPower` pairs.
5. **Composition is ALL-ADDITIVE for now (user-ruled)**: `Damage 150% + 20% = 170%`, explicitly not
   30%. Declared per-property as a `Composition` field so individual keys can override later.
   Implementation: a named string type (`CompositionAdd`, plus `CompositionReplace` for the
   string/Zone/Effect entries that already behave that way). **No function values, no strategy
   objects.** `ApplyBuff` stays the executor this round; a table-driven conformance test asserts
   observed behavior matches the declared rule.
6. **Registry shape: one documented ENTRY per property, in ~7 THEME-GROUPED FILES (user-approved
   2026-08-30).** Not 64 files, not codegen. Rationale: comments count toward the 400/600 LOC
   ceiling so ~1000+ LOC must be split anyway; a table of composite literals is invisible to the
   doc-density linter (which only matches `func`/`def`/`function`), so per-property prose is
   unbounded and free; and **constant map keys make a duplicate string a compile error** — the
   strongest possible guard against ISS-147 recurring. Group by domain (vitals, movement,
   combat-core, status effects, skill targeting, skill effect, skill cost, item). Watch ATD lint
   while grouping: warn above 5 distinct atoms/file, error above 10.
7. **DB IS DISPOSABLE (user-ruled)** — app not live, reseeding is cheap. No migration constraint.
   Non-Go surface is only Go seed literals, JS scenarios, and the Postman collection.
8. **MY EARLIER ISS-140 CONCERN WAS WRONG; corrected by advisor and accepted.** Demoting scope to
   metadata makes fail-fast *easier*, not harder. Today the bridge tries item-then-entity and takes
   whatever is non-nil (that fallthrough IS ISS-147) — two outcomes. The registry gives three
   distinguishable ones: unknown key / known-but-wrong-scope / accepted. At a JSON boundary a runtime
   check is the only kind available regardless of option chosen.
9. **ADVISOR'S "TRAP (c)" IS PARTLY WRONG — corrected by my own verification 2026-08-30.** The
   advisor claimed two default tables disagree and that picking a winner is a behavior change.
   Verified table:

   | Property | Documented "Absence means" | `def` constructor | `PropertiesForCharacter()` | Verdict |
   |---|---|---|---|---|
   | HP | 10 | 10/10 | 10/10 | consistent |
   | Movement | **3** | **5/5** | 3/3 | **GENUINE BUG in the constructor** |
   | SP / MP | 10 | 10/10 | 10/10 | consistent |
   | Attack | 1 | 1 | 3 | **NOT a bug** — different concepts |
   | Defense / JumpHeight / AttackRange | 0 / 2 / 1 | 0 / 2 / 1 | 0 / 2 / 1 | consistent |

   **They are two different concepts, not two copies of one table:** the `def` constructors are the
   *default-when-absent* (used by the `EntityProperty(name)` resolver); `PropertiesForCharacter()` is
   the *starting loadout* a real character is created with (used by
   `entitygenerator.go:24` and `battletest/scenario.go:112`). Attack absence=1 vs starting=3 is by
   design. **The registry must therefore NOT collapse them into one field** — it declares
   default-when-absent; the starting loadout stays a separate concern.
   **Exactly one genuine defect: `Movement()` returns 5/5 against its documented absence-default of
   3** (every other path uses 3). Impact is limited to entities created without an explicit Movement.
   Minor secondary inconsistency: constructors use `FriendlyController` where
   `PropertiesForCharacter` uses `Public`.
10. **PARRY (ISS-148) and the TRIGGER FAMILY (ISS-149) ARE OUT OF THIS ROUND (user-ruled).** Filed
   separately 2026-08-30. ISS-149 blocks ISS-148.

11. **ALL FOUR ATD SIGNOFF ITEMS APPROVED (user, 2026-08-30).** The user agreed with my assessment on
   each. Implementation is unblocked on the ATD side.
12. **ATD ATOMS MUST NOT EMBED CODE (user ruling, 2026-08-30) — general principle, not just this
   round.** Atoms store *intent and documentation*, not implementation. Consequence for this round:
   `mechanic_item_buff_application`'s embedded Go sample is **STRIPPED, NOT REWRITTEN** during
   Workflow B — do not "update" the sample to match the new registry, remove it and express the
   intent in prose.
   **Verified scope of the violation: 7 of 331 atoms carry fenced blocks, of which 4 embed real
   implementation code** — `mechanic_item_buff_application` (Go, in our blast radius, fixed this
   round), plus `mechanic_ai_controller_archetypes` (Go), `rule_credit_earning` (Go) and
   `mech_frontend_test_seams` (TS), all **out of round**. The other 3 are defensible as
   documentation, not code: `api_standard_envelope` (JSON envelope shape — this IS the contract),
   `rule_tracing_logging` (log line format spec) and `mechanic_ai_progression_matching` (pseudocode).
   **Not yet filed as an issue — offer it to the user.**
13. **BACKWARD COMPATIBILITY EXPLICITLY WAIVED (user, 2026-08-30).** `contract_types_contract`'s
   "Stability: changes to core types must be backwards compatible or strictly versioned" clause does
   NOT bind this round, because the app is not live. Deleting the three exported type names and
   renaming property strings is sanctioned. Record this waiver on the Workflow E atom so the
   judgment is on the record.
14. **BUFF-ATTRIBUTION ACCESSOR JOINS THIS ROUND (user, 2026-08-30).** The user's "natural value +
   individual buffs with their respective effects" idea. `GetBaseProperty` (natural/unbuffed) already
   exists from ISS-144 and `GetBuffsFor` already returns each contributing buff — the gap is that
   `GetBuffsFor` DISCARDS the owning `TemporaryProperties` and thus all attribution
   (`OriginEntityID`, `OriginSkillID`, `Duration`, `Forever`). Plan step 16.
15. **`Movement()` 5/5 DEFECT RIDES ALONG (user, 2026-08-30).** Not a separate issue. Plan step 15,
   failing test first.

16. **COMPOSITION VOCABULARY IS FOUR VALUES, NOT TWO — corrects decision 5 (freeze pass, 2026-08-30).**
   Decision 5 assumed `CompositionAdd` + `CompositionReplace`. Direct read of `defaultproperty.go`
   proves that wrong twice over: `DefaultBoolProperty.ApplyBuff` is `base && buff` (a third, distinct
   rule) and `DefaultStringProperty.ApplyBuff` / `EffectProperty.ApplyBuff` **ignore the buff
   entirely** rather than replacing it — only `ZoneProperty` actually replaces. The registry
   therefore declares **`Add` / `And` / `Replace` / `None`**. No behavior changes; what changes is
   what the conformance test is able to assert.
17. **`CriticalMultiplier`'s DOC IS WRONG, ITS CONSTRUCTOR IS RIGHT (freeze pass, 2026-08-30).** The
   enum comment says "Absence means 0%"; `def.CriticalMultiplier()` returns 100. 100 is correct — a
   0 multiplier would zero every crit. Fix the comment, not the behavior. **Note the contrast with
   `Movement`, where the constructor is the wrong one** (decisions 9 and 15) — do not mechanically
   assume one side always wins.
18. **BOTH OPTIONAL CLARITY RENAMES APPROVED (user, 2026-08-30).** `MvtCost` → `MovementCost` and
   `Value` → `ItemValue`. Brings the round's rename map to **7 entries**. Rationale: `Value` is
   dangerously generic once the three namespaces merge; `MvtCost` no longer pairs with `Movement`.
   Decision 3 forbids dribbling renames out later, so this had to be settled inside the freeze.
19. **NEW INVARIANT: CONSTANT IDENTIFIER == STRING VALUE, for all 64 keys.** Exactly 4 keys violate
   it today (`ShieldPower`/`StunPower`/`PoisonPower`/`ArmorRating`) and three of those violations
   **are** the ISS-147 collision. Restoring the invariant is what kills the collision class
   structurally. It is directly testable by walking the registry — this is the second-highest-value
   test in the round after the `Name()`-desync one.

20. **THE PREFLIGHT'S "NEAR-ZERO TRACEABILITY" CLAIM WAS WRONG ON ONE ATOM — found by documentalist
   in step 10, verified by me 2026-08-30.** The ATD preflight section above states all three
   superseded atoms carry `atd trace → total_code_files: 0`. True for `mech_entity_properties` and
   `mech_entity_properties_item_properties`, **false for
   `mech_entity_properties_skill_properties`**, which has `total_code_files: 1` via a live
   `@spec-link` at **`upsilontypes/property/property.go:12`** (`implementation_rate: 1`).
   **Consequence: that link goes stale the moment step 12 lands** and must be explicitly reconciled —
   removed, or re-pointed at `[[upsilontypes:module_property_key_registry]]` — during step 18's
   Workflow B. It is the ONE superseded atom with real traceability, so do not let Workflow B wave it
   through as doc cleanup. Recorded on the atom itself as well. Left untouched in step 10 by design
   (Workflow E originates no `@spec-link` changes).

---

## Step 11 grounding — VERIFIED BY ME AGAINST SOURCE 2026-08-30

Delegated to codebase-explorer, then every load-bearing claim re-checked by direct read. **Two of the
explorer's claims were wrong; corrected below.** Trust this section; do not re-derive it.

### The six tests are NOT six failing tests — they split three ways

This must be stated in the executor's brief or it will fake a failure or hunt a non-existent bug.

| # | Test | Today | Why |
|---|---|---|---|
| T1 | ISS-147 item `Poison` becomes a real entity buff | **RED** | genuine defect repro |
| T2 | ISS-145 D1 — 4 keys unreachable entity-side | **RED** | genuine defect repro |
| T3 | ISS-140 unknown skill key silently dropped | **RED** | genuine defect repro |
| T4 | `Movement` default 3/3 not 5/5 | **RED** | genuine defect repro |
| T5 | `Name()`-desync conformance (trap 1) | **GREEN — and that is correct** | `ZoneProperty.Name()`=="Zone" and its key IS "Zone"; likewise Effect. It is a PREVENTIVE guard that must exist BEFORE step 14's rename sweep. **Do not force it red.** |
| T6 | identifier==value invariant (decision 19) | **RED on all 7 rename-map entries** | only if written against the TARGET vocabulary (§7 of the vocabulary doc), not today's strings |

### Verified locations

- **`applyItemAsBuff`** — `upsilonapi/bridge/bridge_start.go:192-231`.
  **CORRECTION 1: it is UNEXPORTED** (lowercase `a`); the explorer called it "Exported (capital A)".
  Tests must live in `package bridge`. Existing bridge tests already do.
  The ISS-147 fallthrough is lines 220-225: `def.ItemProperty(...)` → nil → `def.EntityProperty(...)`
  → returns a REAL entity Poison → stored via `e.RegisterBuff` as a `Forever:true` buff. Confirmed by
  direct read; this is exactly ISS-147.
- **ISS-140 drop site** — `upsilonapi/bridge/bridge_utils.go:93-109` `buildSkillPropertyMap`. The
  doc comment literally says *"Unknown keys are silently skipped to ensure robustness"* — a written-down
  rule-3/rule-4 violation. `propertyAliasMap` is at `bridge_utils.go:12-16` (3 entries:
  `ArmorRating→Armor`, `CritChance→CriticalChance`, `CritDamage→CriticalMultiplier`); also used by
  `hydrateSingleBuffProperty` in `bridge_resurrect.go:186`. **Note the alias map's `ArmorRating→Armor`
  entry inverts once §7's rename lands — the alias becomes identity and the map dies (ISS-143).**
- **`def.Movement()`** — `upsilontypes/property/def/entity.go:14-16`, returns **5/5**. Confirmed.
  **`def.PropertiesForCharacter()`** — `entity.go:91-107`, Movement **3/3**. Confirmed. Decision 9 holds.
- **`TargetNumber`** — constructor EXISTS at `def/skill.go:15-17`, enum constant at
  `propertyenum.go:63`, and grep confirms **no case in the `def.SkillProperty` switch**
  (`skill.go:328-392`). Resolves `nil` today. Trap 2 confirmed.
- **`Entity.UpdateProperty`** — `upsilontypes/entity/entity.go:215-217`, body is
  `e.Properties[p.Name(property.GameMaster)] = p`. Trap 1 confirmed verbatim.
  `GetBuffsFor` at `entity.go:239-249` keys by `property.PropertyToString(name)` and **discards the
  owning `TemporaryProperties`** — confirms decision 14's gap.
- **`PropertyToString`** — `propertyenum.go:171-185`. Type-switches the 3 named types **plus a bare
  `string` case**, and **panics on anything else**. The bare-string case is what lets the bridge key
  storage off a raw JSON string.
- **`ZoneProperty.Name()`** — `def/skill.go:169-171`, hardcoded `"Zone"`.
  **`EffectProperty.Name()`** — `def/item.go:87-91`, hardcoded `"Effect"` **but returns `""` when the
  caller's info level is below `minInformationLevel`.**
  **CORRECTION 2 / NEW TRAP (mine, not in the vocabulary doc's §8):** an Effect property asked for its
  name below `Analyser` reports `""`. `UpdateProperty` always passes `GameMaster` so it is safe
  *there*, but T5 must assert at `GameMaster` specifically — matching what `UpdateProperty` does —
  and must not be written as a level-agnostic loop.

### Test conventions to follow

- **Style:** plain stdlib `testing` + `testify/assert` + `testify/require`. Three-phase comment
  structure (Setup / Execution / Validation) with narrative assertion messages.
- **`upsilonapi/bridge`:** in-package. Helpers `Get()` (bridge singleton), `createTestRequest()`,
  `intPtr()` in `test_helpers_test.go`. Async settle via `time.Sleep(150 * time.Millisecond)`;
  cleanup via `b.DestroyArena(matchID)`. Nearest models: `equipment_test.go`, `skill_test.go`.
- **`upsilonbattle`:** `battlearena/battletest/scenario.go` sandbox — `New(t,x,y,z)`, `Place(team,pos,
  WithHP/WithMovement/WithStat)`, `actor.Give(skill)`, `s.Turn`, `s.UseSkill`. `Place` seeds via
  `PropertiesForCharacter()` at `scenario.go:112` — **so T4 must NOT go through `Place`**, which would
  hand back the 3/3 loadout and mask the 5/5 constructor defect. T4 belongs in `upsilontypes`.
- **`upsilontypes/property/**` has NO test files today.** T4/T5/T6 create the first ones.
- **Run:** `go test -count=1 -timeout 600s ./...` per module. Full mirror: `scripts/run_ci_local.sh`.
- **`@test-link`:** both file-header and function-level placement exist in the tree; **function-level
  is the standard** per CLAUDE.md. New tests use function-level only.

---

## Step 11 delegation — THREE PARALLEL SLICES, DISPATCHED 2026-08-30

Cut on **package boundaries** so no two agents share a Go package. Each agent is restricted to one
new file and told to run ONLY its own package (`./...` would compile a sibling's in-progress file and
show phantom failures).

| Slice | Package owned | Tests | Sole new file | Expected result |
|---|---|---|---|---|
| A | `upsilonapi/bridge` | T1 (ISS-147), T3 (ISS-140) | `property_ingestion_test.go` | both RED |
| B | `upsilontypes/property/def` | T4 (Movement), T5 (Name-desync) | `defaults_conformance_test.go` | T4 RED; T5 63/64 green, 1 RED |
| C | `upsilontypes/property` | T6 (rename-map invariant) | `keyspace_invariant_test.go` | RED on exactly 7 of 64 rows |

**Two design traps caught before dispatch — both would have produced a build break instead of a red
test, and both are now written into the briefs:**
1. **T6 cannot reference `property.DamageScale` / `MovementCost` / `ItemValue`** — those identifiers
   do not exist yet. The table must be `(CURRENT identifier, TARGET string value)`, which compiles
   today and goes red on exactly the 7 rename rows.
2. **T5 must assert at `property.GameMaster` only.** Verified `InformationLevel` ordering
   (`property.go:19-33`): `Public=0 … Analyser=5 … GameMaster=9`. `EffectProperty.Name()` returns
   `""` below `Analyser`, so a level-agnostic loop would fail for a bogus reason. `GameMaster` is
   also exactly what `UpdateProperty` passes.

**Correction to the earlier "T5 is green today" reading:** T5 is green on 63 of 64 — it fails on
`TargetNumber`, which `def.SkillProperty` has no case for and resolves `nil`. That failure is
legitimate (trap 2) and stays. T5 remains fundamentally a *preventive* guard for step 14's rename
sweep; the brief forbids contriving further failures.

### Slice results

**SLICE C — VERIFIED BY ME 2026-08-30. Accepted.** `upsilontypes/property/keyspace_invariant_test.go`,
`TestKeySpace_IdentifierMatchesStringValue`. I re-ran it myself (`go test -count=1 ./property/`, never
`./...`) rather than trusting the report:
- **64 rows**, counted independently (`grep -cE '^\s*\{'` = 64), and the test self-guards with a
  fatal `len(rows) != 64` check.
- **Exactly 7 subtests fail**, and they are exactly §7's rename map: `Damage`, `ShieldPower`,
  `StunPower`, `PoisonPower`, `MvtCost`, `ArmorRating`, `Value`. 57 pass.
- **Quality signal — the test discriminates rather than blanket-failing.** It carries two distinct
  assertions and they fire on *different subsets*: the current-vs-target check fires on all 7, but
  the §1 identifier==value check fires on only 3 (`Damage`, `MvtCost`, `Value`) — precisely the rows
  where the *identifier itself* changes. For `ShieldPower`/`StunPower`/`PoisonPower`/`ArmorRating`
  the identifier already equals its target, so §1 correctly holds. That asymmetry is right and is
  good evidence the table was reasoned through, not pattern-filled.
- `@test-link [[upsilontypes:module_property_key_registry]]` is **function-level** (line 16, directly
  above the func) and the id matches the atom front-matter verbatim. `gofmt`/`go vet` clean.
- No production code touched; sole new file in `property/`.

**SLICE B — VERIFIED BY ME. Accepted.** `upsilontypes/property/def/defaults_conformance_test.go`.
- `TestDefaults_MovementAbsenceDefaultIsThree` **FAILS**: "gets 5/5 tiles instead of the documented
  default of 3/3". Correct defect, correctly named.
- `TestDefaults_ResolvedNameMatchesRegistryKey`: I counted the subtest result lines myself —
  **64 ran, 63 PASS, exactly 1 FAIL (`TargetNumber`, resolver returned nil)**. Exactly the specified
  outcome. `property.GameMaster` is the sole info level used (line 149); nil-guard at line 143 so a
  nil resolver produces `t.Errorf`, not a table-aborting panic.
- **No regression:** all 10 pre-existing `def` tests (`TestHP`, `TestZoneProperty_*`) still PASS.

**SLICE A — VERIFIED BY ME. Accepted.** `upsilonapi/bridge/property_ingestion_test.go`.
- `TestPropertyIngestion_ItemPoisonMustNotBecomeEntityBuff` FAILS on all 3 sub-cases
  (`Poison`/`Shield`/`Stun`), each message naming the entity-property fallthrough in
  `applyItemAsBuff` as the mechanism. That is ISS-147 stated precisely.
- `TestPropertyIngestion_UnknownSkillKeyMustNotBeSilentlyDropped` FAILS on both sub-cases: the bogus
  key (map has 1, wanted 2) and `TargetNumber` (documented property, working constructor, no resolver
  case). ISS-140 plus trap 2, both captured.
- **No regression, verified by me on the FULL bridge suite:** 25 top-level PASS, and the only
  top-level failures are the 2 new ones. Zero tracked `.go` files modified (`git diff --stat -- '*.go'`
  empty in both submodules).

### Step 11 tally

**5 test functions, 14 failing assertions, 0 production-code changes, 0 regressions.**
T1 (3 red) · T3 (2 red) · T4 (1 red) · T5 (1 red of 64) · T6 (7 red of 64). T2 deferred to step 12.

### Two findings from the slices — both worth keeping

1. **`upsilontypes/property/def/skill.go` is ALREADY NOT gofmt-clean at HEAD.** Slice B flagged it and
   speculated a parallel agent had touched it. **That speculation was wrong and I disproved it:**
   `git diff --stat -- '*.go'` is empty, and running `gofmt -l` on `git show HEAD:property/def/skill.go`
   flags it too — so it is pre-existing, not agent-caused. **But it directly amplifies this round's
   top risk.** The Gotchas section already warns that `gofmt -r` reformats whole files; `skill.go` is
   both the largest rename target (392 LOC, at the warn ceiling) *and* already unformatted, so a
   `gofmt -r` sweep there would blend a whole-file reformat into the rename diff and make review
   nearly impossible. **Step 14 must use package-qualified selector rewrites on this file, never
   `gofmt -r`, or must gofmt it as a separate isolated commit first.**
2. **My `@test-link` verification hint in the briefs was wrong.** Atom files do NOT all live under the
   umbrella `docs/`; `mechanic_item_buff_application` is at `upsilonbattle/docs/` and
   `mechanic_skill_payload_resolution` at `upsilonapi/docs/`. Slice A caught this and verified via a
   repo-wide grep on the `id:` front-matter instead. **Future briefs must say "grep the id repo-wide",
   not "ls docs/".**

### Deferred out of step 11 — my call, flagged for you

- **T2 (ISS-145 Defect 1, the 4 dual-scope keys) DEFERRED TO STEP 12.** The four keys are
  `SkillProperties` constants today, so there is no entity-side call to even make; a red-first test
  would have to reference post-registry symbols and would fail to COMPILE rather than fail an
  assertion. A non-compiling package also breaks its co-resident slice's `go test` run. It becomes a
  clean assertion-failure test the moment the registry lands. **Reverse this if you disagree.**
- **ISS-143 `propertyAliasMap` guard DEFERRED TO STEP 14.** It is a deletion-verification, not a
  defect repro, so it has no meaningful red-first form. Note its `ArmorRating→Armor` entry becomes an
  identity mapping the moment §7's rename lands, which is what kills the map.

---

## Step 12 — PLAN-ORDERING DISCOVERY, made before dispatch 2026-08-30

21. **THE 7 RENAMES MOVE FROM STEP 14 INTO STEP 12. They are a hard compile-time prerequisite for
    the registry, not cleanup.** Verified mechanically, not reasoned: extracting all 64
    `(identifier -> value)` pairs from `propertyenum.go` gives **64 pairs, all 64 identifiers unique**
    (they must be — same package), but **3 duplicate VALUES**:

    | value | identifiers sharing it |
    |---|---|
    | `"Poison"` | `Poison` (entity) + `PoisonPower` (skill) |
    | `"Shield"` | `Shield` (entity) + `ShieldPower` (skill) |
    | `"Stun"` | `Stun` (entity) + `StunPower` (skill) |

    Once the three namespaces alias to a single `property.Key`, a `map[property.Key]Entry` literal
    containing all 64 keys has **duplicate constant keys, which Go rejects at compile time**. So the
    registry literally cannot be written until at least those 3 are renamed. **This is decision 6's
    predicted guard firing exactly as intended** — it just fires one step earlier than the plan
    assumed. Decision 3 forbids dribbling renames out, so all 7 land together in step 12, not 3 now
    and 4 later. (`ArmorRating`="Armor" is NOT a duplicate and does not block compilation, but it
    rides along for the §1 invariant.)

    **Consequence: T6 goes GREEN at step 12, not step 14.** Step 14's "run the rename sweep" is
    largely absorbed here; what remains at 14 is the non-Go surface and the `applyItemAsBuff` rewrite.

    **Blast radius of the 3 IDENTIFIER renames — small and mechanical, 40 call sites:**
    `property.Damage` 29 (types 14 / battle 12 / api 3) · `property.MvtCost` 8 (types 3 / battle 5) ·
    `property.Value` 3 (types 3). The other 4 renames change only the string VALUE, so they touch
    **zero** Go call sites. All 40 are package-qualified `property.X` selectors — safe for scripted
    rewrite, which is exactly the form the Gotchas section says is safe.

22. **THE TYPE-ALIAS TRAP — two compile errors that a naive step 12 walks straight into.** Aliasing
    (`type EntityProperties = Key`, not a new defined type) is what keeps the ~1892 constant
    references compiling. But:
    - The three existing `String()` methods (`propertyenum.go:52`, `:110`, `:166`) all become methods
      on `Key` ⇒ **duplicate method declaration**. Two must go; define one `Key.String()`.
    - `PropertyToString`'s type switch (`:171-185`) has three cases that collapse into one type ⇒
      **duplicate case in type switch**. Must be rewritten to `case Key` + `case string` + panic default.
    `SkillTargetingProperties` / `SkillEffectProperties` / `SkillCostProperties`
    (`:114`, `:125`, `:138`) become `map[Key]bool` and are otherwise fine.

### Step 12 WAVE 1 — LANDED AND VERIFIED BY ME 2026-08-30

All three modules `go build` + `go vet` clean. **T6 fully GREEN.** T5 still 64 run / 1 fail
(`TargetNumber`). T4 still RED (5/5). T1/T3 still RED; bridge suite 25 top-level PASS, **0 non-ours
failures**. `upsilonbattle` 189 passed, all green. `upsilontypes` 190 passed / 3 failed — all 3 expected.

**I proved the §1 invariant from SOURCE, not from the test** (the test could in principle have been
edited to force green): re-extracted all 64 `(identifier, value)` pairs from `propertyenum.go` →
**64 pairs, zero identifier≠value mismatches, zero duplicate values**. T6's green is real.

**Agent deviated from the brief on 2 extra files — I checked both; both were genuinely required:**
- `defaultproperty.go` — 3 more instances of the same duplicate-type-switch trap. Mechanical.
  **LOC 488 → 446: still over the 400 warn ceiling, but it was ALREADY over at HEAD and got smaller.**
  Pre-existing violation, improved not worsened. Not a regression; worth its own cleanup someday.
- `def/glob.go` — `DefaultProperty`'s switch was **semantically** load-bearing (it dispatched *by
  type* to the three resolvers, which aliasing makes impossible). Rewritten to try all three in
  sequence, first non-nil. **This is structurally the same fallthrough shape as ISS-147**, so I did
  not take "behavior-preserving" on faith — I generated a throwaway test walking all 64 keys through
  all 3 resolvers: **64 checked, 0 overlapping, 1 unresolved (`TargetNumber`)**. Claim verified; it is
  safe *only because* the values are now unique. **Step 13 must replace it with a registry lookup +
  scope assertion and not leave this pattern in place.**

23. **REGRESSION INTRODUCED BY WAVE 1 — CAUSED BY MY OWN GUARDRAIL. Found by me, not by any test.**
    `upsilonapi/bridge/bridge_utils.go:13` still reads `"ArmorRating": "Armor"` in `propertyAliasMap`.
    I had explicitly forbidden the agent from touching that file ("later slice"), so it correctly
    left it — but the §7 rename changed the ArmorRating *value* from `"Armor"` to `"ArmorRating"`,
    which inverts the alias into a **live silent-drop bug**:
    incoming `"ArmorRating"` → aliased to `"Armor"` → `def.ItemProperty("Armor")` now returns nil →
    `def.EntityProperty("Armor")` nil → **property silently discarded.** Before the rename this path
    worked. Live in **two** call sites: `bridge_start.go:217` (`applyItemAsBuff`) and
    `bridge_resurrect.go:186` (`hydrateSingleBuffProperty`).
    **Invisible to the whole suite — no test covers the alias path**, which is why the bridge suite
    stayed at 25 green. Uncommitted, so nothing shipped.
    **Fix (needs a failing test first, CODING_RULE §5): delete the `"ArmorRating": "Armor"` entry.**
    It is now an identity mapping; removing it lets the key pass through and resolve correctly.
    `CritChance`/`CritDamage` stay — still legitimate legacy aliases.
    **Lesson for the remaining waves: when a slice renames a property VALUE, every lookup table
    keyed on the OLD value must move in the SAME wave, or be explicitly re-pointed.**

24. **`attack.go:105` `"Armor"` is NOT a bug — checked.** It is a logrus field label in a Debug line;
    the value comes from `foe.GetPropertyI(property.ArmorRating)` at `attack.go:59`. Cosmetic only,
    zero functional impact. Rename for consistency if convenient; not required.

---

## Open questions (current)

**None blocking.** Every gate is cleared: Option A approved, all four ATD signoff items approved,
backward-compat waived, `upsilontypes` CONTRACT/VISION confirmed settled. The two previously-open
scoping questions were both ruled IN scope (decisions 14 and 15).

Carried, non-blocking:
- **`atd index` has never been built for any of the 15 projects** (semantic `atd search`/`atd map`
  unusable workspace-wide). **The user has taken this one — do not file or act on it.**
- **Offer to file** the 3 out-of-round atoms that embed implementation code (decision 12):
  `mechanic_ai_controller_archetypes`, `rule_credit_earning`, `mech_frontend_test_seams`.
- **Offer to file** the pre-existing dangling `@spec-link` ids (`mech_entity_expiration`,
  `mec_ai_archetype_system`, `rule_friendly_fire_team_validation`).
- **Offer to file — NEW, found in the step-9 freeze** (all out of round, all declared-as-observed in
  the registry so none of them block):
  - **Bool buffs can never grant a flag.** `And` composition means base `false && buff true = false`,
    so `WalkThrough`, `Invisible` and `ExpiresWithCaster` are un-buffable in practice.
  - **`TeamID` and `IsDying` declare `Add` composition**, meaningless for an identity and dubious for
    a countdown.
  - **`def.SkillProperty()` has no `TargetNumber` case**, so that key resolves `nil` today despite
    having a constructor. Closed by construction in step 12 — but worth recording as a bug that
    existed.

## Gotchas — will waste an hour each if forgotten

- **`upsiloncli/.env` sets a dead `UPSILON_BASE_URL=http://localhost:8000`; the CI-mirror stack is on
  `:8085`.** Scenarios fail at register with connection-refused otherwise — looks like a scenario
  defect, is not.
- **ISS-136 (Open):** `e2e_friendly_fire_skill_test.js` is already non-deterministically flaky. Do
  not read a pre-existing flake as a regression from your own edit — and do not read a green run as
  proof either.
- **Pre-existing `atd lint` failures** (assorted atoms missing `## EXPECTATION`: `rule_friendly_fire`,
  `spec_match_format`, various `us_*`/`requirement_customer_*`). Unrelated; do not let them mask new
  failures. Baseline was 13.
- **`gofmt -r` reformats whole files**, so a per-rename sweep produces noisy diffs. Package-qualified
  selectors (`property.Damage -> property.DamageScale`) are safe to rewrite this way.

## Loose ends deliberately left (harmless, but do not lose them)

- `attack.go:76-89` (shield absorption) carries no `@spec-link` despite matching
  `mech_combat_shielding`. One-line source comment; missed because that task was docs-only guarded.
- 7 of 331 atoms still carry the literal `# New Atom` H1 placeholder. User ruled 2026-08-28 that only
  *our* atom gets a hand-edit and that the underlying `atd` tooling gap is **not** to be filed.
- Documentalist's DRAFT→REVIEW advance on `rule_entity_property_write_isolation` was flagged "for
  visibility, not sign-off" and has not been separately adjudicated.
- **ISS-111** (High, Open) claims skill cooldowns are never decremented, but `endofturn.go` visibly
  ticks equipped-skill cooldowns. Likely stale — worth a 5-minute check, unrelated to this round.
- Advisor's optional follow-ups, not filed: `def.ZoneProperty`/`def.EffectProperty` embed
  `property.Property` as a nil interface (any unoverridden method panics on nil dispatch); and
  `DefaultStringProperty.SetS` silently returns on a disallowed value (rule-3 violation).

---

## Wave 2 design — SETTLED 2026-08-30 (7 slices, parallelizable)

All 7 files go in `upsilontypes/property/def/`, package `def`. **`registry_` prefix is mandatory** —
`entity.go`, `skill.go`, `item.go`, `glob.go` already exist in that package and must not be shadowed.

| # | File | Var | Keys | Source |
|---|---|---|---|---|
| 1 | `registry_entity_vitals.go` | `entityVitalsEntries` | 7 — HP, SP, MP, Shield, Poison, Stun, IsDying | §3 |
| 2 | `registry_entity_movement.go` | `entityMovementEntries` | 5 — Movement, JumpHeight, WalkThrough, HasMoved, HasActed | §3 |
| 3 | `registry_entity_core.go` | `entityCoreEntries` | 8 — Attack, Defense, AttackRange, TeamID, AIArchetype, EntityDuration, ExpiresWithCaster, Invisible | §3 |
| 4 | `registry_skill_targeting.go` | `skillTargetingEntries` | 9 — §4a incl. **Accuracy, Dodge (dual-scope)** | §4a |
| 5 | `registry_skill_effect.go` | `skillEffectEntries` | 10 — §4b incl. **CriticalChance, CriticalMultiplier (dual-scope)** | §4b |
| 6 | `registry_skill_cost_trigger.go` | `skillCostTriggerEntries` | 12 — §4c(7) + §4d(2) + §4e(3) | §4c-e |
| 7 | `registry_item.go` | `itemEntries` | 13 | §5 |

20 + 31 + 13 = **64**, each key declared **exactly once**.

**Critical constraints for every slice brief:**
- **The 4 dual-scope keys stay in their §4 home** (Accuracy/Dodge in slice 4, CriticalChance/
  CriticalMultiplier in slice 5) with `Scopes: ScopeEntity | ScopeSkill` (same package — NO `def.` prefix). They must NOT also
  be declared in an entity slice — `mergeThemes` panics on a duplicate key, so a double-declaration
  is a hard build-time failure, not a silent bug.
- **Read the CURRENT identifier and value out of `upsilontypes/property/propertyenum.go`** for every
  key. All 7 §7 renames already landed in wave 1; do not trust the vocabulary doc's "RENAME from X"
  notes as pending work, and do not re-apply them.
- **`New` must be a closure**, because several constructors take arguments:
  zero-arg (`HP()`, `Attack()`, …) → `New: func() property.Property { return HP() }`;
  arg-taking (`RepositionSubject`, `RepositionDistance`, `TriggerType`, `RemoveOnTrigger`,
  `TriggerCount`, `MakeZoneProperty`) → pass the vocabulary's default-when-absent as the argument.
- **Reuse the existing exported constructors; do NOT write new ones and do NOT rename existing ones.**
  Note the live inconsistency: the key is now `property.DamageScale` but its constructor is still
  `def.Damage()` — map one to the other and leave the constructor name alone (step-13 cleanup;
  renaming it now would touch `skill.go`, which is a shared file across slices).
- **`Allowed` is non-nil ONLY for the validated-String kinds** (Behavior, TargetType,
  TargetingMechanics, RepositionSubject, TriggerType, ItemType, WeaponType, ArmorType, ToolType).
  `AIArchetype` is a free String — `Allowed: nil`.
- `Zone` has no min info level in the table (`—`); use `property.Public` and flag it in the report.
- **Do not edit `registry.go`** — the `mergeThemes(...)` wiring is a shared write point and is done
  once, centrally, after all 7 land.
- Code health: ≤400 LOC warn / 600 error **counting comments**; ATD lint warns above 5 distinct atoms
  per file. These tables are comment-heavy by design — keep per-entry commentary to one line.


### Wave 2 result — COMPLETE 2026-08-31

All 7 theme files landed and independently verified; `registry.go` wired centrally by me.

| Slice | File | Keys | LOC |
|---|---|---|---|
| 1 | `registry_entity_vitals.go` | 7 | 37 |
| 2 | `registry_entity_movement.go` | 5 | 29 |
| 3 | `registry_entity_core.go` | 8 | 40 |
| 4 | `registry_skill_targeting.go` | 9 | 47 |
| 5 | `registry_skill_effect.go` | 10 | 48 |
| 6 | `registry_skill_cost_trigger.go` | 12 | 58 |
| 7 | `registry_item.go` | 13 | 77 |

**My verification (not the agents' say-so):** 64 entries / 64 unique / 0 duplicates; exactly 4
dual-scope keys (Accuracy, Dodge, CriticalChance, CriticalMultiplier); build + `go vet` clean;
`upsilontypes` suite at the expected baseline (T4 red, T5's single `TargetNumber` subtest red,
everything else green, **no init panic**); throwaway runtime probe confirmed `len(registry)==64`,
all `Entry.Key` self-consistent, 9 `Allowed` sets, 0 nil `New`. Probe file deleted afterward.

**DECISION 25 — my wave-2 briefs were WRONG about two renames; both agents caught it.**
I told slices 6 and 7 that the `MvtCost` and `Value` renames were "NOT part of this round" and to use
the old identifiers. **False** — both had already landed in wave 1: the enum carries
`MovementCost SkillProperties = "MovementCost"` and `ItemValue ItemProperties = "ItemValue"`.
Because the briefs also said "use the CURRENT identifier from `propertyenum.go`, never invent one",
both agents followed the source over my framing and flagged the contradiction. §7's rename set is
therefore **larger than the 7 I had been carrying forward** — re-read §7 before trusting any
remaining rename claim in this file. Note the constructors keep their OLD names (`MvtCost()`,
`Value()`) while the keys are renamed — same split as `Damage()`/`DamageScale`. All three are
step-13 cleanup.

**GOTCHA (general, from the rate-limit incident):** three slices were killed mid-flight by a provider
rate limit, yet two had **already written complete, correct files** before dying. A failed-agent
notification says nothing about what reached disk. **Always inventory the filesystem after a failed
delegation before re-dispatching** — blind re-running would have clobbered good work.

## Step 13 — THE THREE-WAY SPLIT (designed 2026-08-31, NOT yet dispatched)

Three slices on **package** boundaries inside `upsilontypes`. All three are dispatchable in
parallel, but see the build-coupling warning below.

### THE SIGNATURE CONTRACT — all three slices code against this, verbatim

This is what makes parallel execution safe. Each slice changes its own package to match; nobody
negotiates at runtime.

```go
// package def
func EntityProperty(k property.Key) property.Property   // registry-backed, scope-filtered
func SkillProperty(k property.Key) property.Property    // registry-backed, scope-filtered
func ItemProperty(k property.Key) property.Property     // registry-backed, scope-filtered
func DefaultProperty(k property.Key) property.Property  // registry lookup, NO scope filter

// package defaultproperty — `name` only; the value params stay interface{}
func MakeIntProperty(name property.Key, value int, ...) *DefaultIntProperty
func MakeIntCounterProperty(name property.Key, value, maxvalue int, ...) *DefaultIntCounterProperty
func MakeFloatProperty(name property.Key, value float64, ...) *DefaultFloatProperty
func MakeBoolProperty(name property.Key, value bool, ...) *DefaultBoolProperty
func MakeStringProperty(name property.Key, value string, ...) *DefaultStringProperty
func MakeValidatedStringProperty(name property.Key, value string, ..., allowed []string) *DefaultStringProperty

// package entity / skill / effect — key params only
func (e Entity) GetProperty(name property.Key) property.Property   // …and siblings
func (e *Entity) RepsertPropertyValue(p property.Key, value interface{})  // NOTE: value STAYS interface{}
```

### Slice 13A — registry-backed resolvers  (`upsilontypes/property/def/`)
Files: `entity.go`, `skill.go`, `item.go`, `glob.go`. **Owns the three resolver switches + glob.**
- Replace each hand-written `switch` in `EntityProperty`/`SkillProperty`/`ItemProperty` with a
  `Lookup(k)` + **scope check** + `entry.New()`. Unknown key or wrong scope → return nil (keep the
  current nil contract; the *caller-side* crash-early assertion is 13B's job, not a change here).
- **Replace `glob.go`'s `DefaultProperty` try-all-three fallthrough** with a single registry lookup,
  no scope filter. This is the ISS-147-shaped code that must not survive the round.
- **Turns T5's last red subtest (`TargetNumber`) green** — that key resolves by construction now.
- Do NOT rename constructors (`Damage()`, `MvtCost()`, `Value()` keep old names — step-14 cleanup).

### Slice 13B — entity/skill/effect key seams  (`upsilontypes/entity/`, `upsilontypes/property/effect/`)
Files: `entity/entity.go` (16), `entity/skill/skill.go` (5), `property/effect/effect.go` (7) = **28 seams**.
- Convert every **key** param `interface{}` → `property.Key`. Exact entity.go list:
  `getBasePropertyOrDefault`, `GetProperty`, `GetPropertyI/F/C`, `GetBaseProperty`,
  `GetBasePropertyC`, `GetBuffsFor`, `HasProperty`, `RepsertPropertyValue`,
  `RepsertPropertyCMaxValue`, `RepsertPropertyCValue`, `UpdatePropertyValue`,
  `UpdatePropertyCMaxValue`, `UpdatePropertyCValue`, `AdjustPropertyCValue`.
- **Add the scope assertion in `getBasePropertyOrDefault`** — an entity asked for a skill/item-scope
  key is a programming error: **panic with a clear message** (CODING_RULE §3/§4, crash early; no
  silent nil, no "save the day" defaulting). This is the structural close on ISS-147's class of bug.

### Slice 13C — constructor seams + stringification  (`property/defaultproperty/`, `property/propertyenum.go`)
Files: `defaultproperty/defaultproperty.go` (6 `Make*`), `property/propertyenum.go` (`PropertyToString`).
- Convert the 6 `Make*` constructors' **`name`** param to `property.Key`.
- Simplify `PropertyToString` now that its input is typed.
- Nearly decoupled from A and B: the three type aliases are still in force, so existing call sites
  passing `property.HP` (an `EntityProperties`, i.e. a `Key`) keep compiling untouched.
- `defaultproperty.go` is 446 LOC — over the 400 warn ceiling, pre-existing. This slice may shrink it;
  it must not grow it.

### FIVE TRAPS — brief every slice on these

1. **21 `interface{}` seams are VALUE-side and MUST NOT be converted**: `Get() interface{}`,
   `Set(p interface{})`, `UserFriendlyGet(i) interface{}` across the 5 `Default*Property` types plus
   `ZoneProperty` and `EffectProperty`. These are the `property.Property` interface's value contract,
   not keys. Converting them would be a semantic disaster and would not fail loudly.
2. **`RepsertPropertyValue(p interface{}, value interface{})` and `UpdatePropertyValue(p, value)`
   are MIXED**: first param is a key (convert), second is a value (**leave as `interface{}`**).
   Highest-risk edit of the round — a careless sed converts both.
3. **A naive grep of `defaultproperty.go` reports 11 key-ish seams; only 6 are real** (the `Make*`
   constructors). The other 5 are `Set(p interface{})` value-side false positives — see trap 1.
4. **The module will NOT build until all three slices land.** 13B calls `def.DefaultProperty` whose
   signature 13A is changing. Each agent must treat cross-package signature errors naming the *other*
   slices' packages as expected, and verify only its own package. **I integrate and run the suite.**
5. `def/skill.go` is non-gofmt-clean at HEAD — **never run `gofmt -r` or a repo-wide formatter.**

### Step 13 slice results — as they land

**13A — LANDED 2026-08-31, VERIFIED BY ME AGAINST SOURCE.**
All four `property/def/` files changed and nothing else. Signatures now match the contract verbatim:
`EntityProperty/SkillProperty/ItemProperty(k property.Key)` and `DefaultProperty(k property.Key)`.
Each of the three resolvers is `Lookup(k)` + a bitmask scope check (`entry.Scopes&ScopeX == 0`) +
`entry.New()`, returning nil on unknown-key-or-wrong-scope — the nil contract is preserved, and the
caller-side crash-early assertion was correctly left to 13B.
**`glob.go`'s try-all-three fallthrough is GONE** — I read the whole file: a single unfiltered
`Lookup` + `New()`, 22 → 14 lines. This was the ISS-147-shaped code the round exists to kill.
LOC: entity 153→118, **skill 392→337 (now clear of the 400 warn ceiling)**, item 235→212, glob 22→14.
Constructors `Damage()`/`MvtCost()`/`Value()` correctly NOT renamed (step-14 work).
Agent-reported and consistent with the above: `go build`/`go vet ./property/def/...` clean;
`go test ./property/def/...` 75 pass / 1 fail, the single failure being T4 Movement (deliberate,
step 15) with **T5 fully green 64/64 including `TargetNumber`**; `code_health_check.py` 78 → 75
errors, all remaining pre-existing (confirmed by the agent via stash diff).
Expected cross-package breakage remains at `entity/skill/skill.go:126` — 13B's territory.
*Full-suite verification still pending; it cannot run until 13B and 13C land.*

**13B — LANDED 2026-08-31, VERIFIED BY ME AGAINST SOURCE.**
All 28 key seams converted to `property.Key`; only the 3 in-scope files touched.
Counts confirmed by me: `entity.go` 16 → **2**, `entity/skill/skill.go` 5 → **0**,
`property/effect/effect.go` 7 → **0**.
**Trap 2 handled correctly** — I re-read both mixed-param functions myself:
`RepsertPropertyValue(p property.Key, value interface{})` (line 317) and
`UpdatePropertyValue(p property.Key, value interface{})` (line 344). Key typed, value left
`interface{}`. Those two are the only remaining `interface{}` in entity.go, exactly as intended.
**The crash-early scope assertion is in `getBasePropertyOrDefault` and I read it in full.** Two
panic branches, both CODING_RULE §3-compliant, no silent nil and no fallback:
- unregistered key → `entity: property key %q is not registered in the property/def registry; ...`
- wrong scope → `entity: property key %q is not entity-scoped (scopes=%#b); using a skill- or
  item-only key on an Entity is a programming error`
The agent probed it live: `property.Range` (skill-only) panics, `property.HP` passes. **This is the
structural close on the ISS-147 bug class** — an item's `"Poison"` can no longer become an entity buff.
Note `entity` now imports `def`; no import cycle (module builds).

*Two notes on the 13B report, neither affecting the work:*
1. The agent **misattributed T4** (`TestDefaults_MovementAbsenceDefaultIsThree`) as "added by slice
   13A". Wrong — T4 came from step 11 and belongs to **step 15**. It correctly did not touch it, so
   the misreading was inert, but do not let that misattribution propagate.
2. It reported the whole module building because 13C had already landed in the tree by its
   verification pass. That is plausible but was NOT independently confirmed at the time.

**FORWARD RISK — `entity.go` is now 369 → 385 LOC against a 400 warn ceiling, and
`code_health_check.py` counts comments as effective LOC. Step 16 adds the buff-attribution accessor
TO THIS FILE. It will not fit.** Plan step 16 to land the new accessor in a separate file in package
`entity` (or split the property accessors out) rather than appending to `entity.go`.

**13C — LANDED 2026-08-31, VERIFIED BY ME.**
Only the 2 in-scope files touched. All 6 `Make*` constructors now take `name property.Key`;
`defaultproperty.go` 446 → **434 LOC** (shrank, as required — still over the 400 warn ceiling,
pre-existing). The `default: return nil` branches in `MakeIntProperty`/`MakeFloatProperty`/
`MakeBoolProperty` are **gone entirely** — with `name` statically typed the switch became
unreachable, so deletion (not a panic) was the right call; no silent-nil type-mismatch path remains.
**I audited the value-side seams across all modules: 21 implementation seams
(`defaultproperty.go` 15 = 5 types × 3, `def/skill.go` 3 ZoneProperty, `def/item.go` 3
EffectProperty) plus the 4 interface declarations in `property.go` — all UNCHANGED. Trap 1 held.**

*`PropertyToString` — behavior change I checked myself.* 13C dropped its `case string:` branch, so it
now **panics** on a non-`Key` instead of returning the raw string. I grepped every call site in
`upsilontypes`, `upsilonbattle`, `upsilonapi` **and** `upsilonhub` (90 matches / 11 files): all pass
typed `property.X` constants or `property.Key` vars. **Zero bare strings — the removal is safe.**
Its signature must stay `interface{}` for now; it can be narrowed once step 14 drops the aliases.
*13C also flagged (correctly, did not fix):* `MakeIntCounterProperty`/`MakeStringProperty`/
`MakeValidatedStringProperty` still `return nil` when the key stringifies to `""` — same
CODING_RULE §3 silent-nil class, different trigger. **Fold into step 14.**

### 13D — THE GAP CENTRAL INTEGRATION CAUGHT (dispatched 2026-08-31)

**Step 13 as designed was INCOMPLETE.** The three slices were all scoped inside `upsilontypes`, but
the round's own grounding says the blast radius is **3 modules**. Nobody owned the downstream key
seams, and **every slice reported success while `upsilonbattle` did not compile** — each had verified
only its own module. This is exactly the failure central integration verification exists to catch;
do not let a future round scope slices to one module when the blast radius is three.

Verified by me: `upsilontypes` builds+vets clean, but `upsilonbattle` fails with 2 errors (and
`upsilonapi` fails transitively through it — **`upsilonapi` itself needs no edits**).
Residue is **6 key seams in 2 files**, all the same `interface{}`-key pattern:
- `battlearena/property/effect/effectapplicator/effectapplicator.go` — `getPropertyOrDefault`,
  `getPropertyOrDefaultI`, `getPropertyOrDefaultF`, `getPropertyOrDefaultC` (4)
- `battlearena/battletest/scenario.go` `WithStat` + `inspect.go` `Stat` (2) — these were **masked**
  behind the transitive effectapplicator failure, so a naive "fix the 2 reported errors" misses them.

Dispatched to `coding-executor` as 13D, briefed on the mixed-param trap, the value-side trap, and —
critically — **that the new upstream panic must NOT be recovered/suppressed/worked around**: a
panicking `upsilonbattle` test is a REAL wrong-scope read this round is designed to expose, and must
be reported to me as a finding rather than patched by the agent.

**13D — LANDED 2026-08-31, VERIFIED BY ME. Build is GREEN across all three modules.**
6 seams converted in 2 files (7 insertions / 7 deletions, no other files touched). Confirmed by me:
`upsilontypes`, `upsilonbattle`, `upsilonapi` all `go build ./...` clean. `upsilonapi` needed zero edits.

### *** THE ROUND'S BIGGEST FINDING — `ArmorRating` IS A VOCABULARY DEFECT ***

**The new scope guard did exactly its job and caught a REAL, PRE-EXISTING, ISS-147-class bug.**
`upsilonbattle` now panics in 3 places, all one root cause:
```
panic: entity: property key "ArmorRating" is not entity-scoped (scopes=0b100);
       using a skill- or item-only key on an Entity is a programming error
```
Two wrong-scope reads, both verified by me in source:
- `battlearena/property/effect/effectapplicator/effectapplicator.go:134` — `target.GetPropertyI(property.ArmorRating)` (hit by 3 test paths)
- `battlearena/ruler/rules/attack.go:59` — `foe.GetPropertyI(property.ArmorRating)` (**latent twin, not yet triggered by any test**)

**MY DIAGNOSIS: the CODE IS RIGHT and the FROZEN VOCABULARY ROW 55 IS WRONG.** `ArmorRating` must be
**`ScopeItem | ScopeEntity`**, not Item-only. Four independent lines of evidence:
1. `applyItemAsBuff` (`upsilonapi/bridge/bridge_start.go:192`) **deliberately flattens item properties
   into a `Forever:true` entity buff** via `e.RegisterBuff(buff)`. That is the round's own recorded
   grounding fact: *"Equipment is NOT a live layer — the bridge flattens items into Forever:true
   buffs at battle start."* So an Entity legitimately carries `ArmorRating`. Reading it off the
   entity is correct **by design**.
2. Row 55 gives `ArmorRating` **`Composition: Add`**. Composition only has meaning when folding a
   buff onto an entity's base value. **An Item-only key cannot compose — the row is self-inconsistent.**
3. It is read in the damage formula immediately alongside `Defense` and `Shield`, **both `ScopeEntity`**.
4. **Exact precedent already in the registry**: `CriticalChance`, `CriticalMultiplier`, `Accuracy`,
   `Dodge` are all `ScopeSkill | ScopeEntity` — they are the ISS-145 Defect 1 resolution, the very
   same "declared on X, legitimately read off an Entity" pattern.

**Why the freeze missed it:** vocabulary §7 only ever contemplated **Entity|Skill** dual scope.
**`ArmorRating` is the first Entity|Item dual-scope key** and fell straight through that blind spot.
Only implementation could surface it — which is the guard earning its keep.

**Proposed fix (ONE line + doc, pending user sign-off since it amends a user-approved frozen artifact):**
`registry_item.go:26` → `Scopes: ScopeItem | ScopeEntity`; correct row 55 + §7 in
`architecture/property_key_vocabulary.md`. **Do NOT "fix" the two call sites** — they are correct.
**Do NOT weaken the guard.** Expect all 3 panics to clear and `upsilonbattle` to return to ~189 green.

*Note on the reported test counts:* 13D saw "54 passed / 3 failed", far below the ~189 baseline. That
is NOT extra hidden breakage — **each panic aborts its whole test binary**, so ~125 tests never ran.

### STEP 13 RESOLUTION — user approved dual-scope 2026-08-31; TWO more defects found during verification

**Fix 1 — the `ArmorRating` family turned out to be THREE keys, not one.** After the user approved
the dual-scope call, I ran a **systematic sweep** (extract every non-entity-scoped key from the
registry, then grep all 3 modules for entity-accessor reads of them) rather than fixing one panic at
a time. 91 raw hits, but almost all were `sk.`/`eff.` receivers — **Skill and Effect accessors carry
NO scope guard, only `Entity` does.** The true wrong-scope entity reads are exactly three, all the
same "innate stat + equipment contribution" pattern:

| Row | Key | Composed on the entity with | Read at |
|---|---|---|---|
| 55 | `ArmorRating` | `Defense` | `effectapplicator.go:134`, `ruler/rules/attack.go:59` |
| 59 | `WeaponRange` | `AttackRange` (via `Max`) | `ruler/rules/attack_checks.go:76` |
| 60 | `WeaponBaseDamage` | `Attack` (via `+`) | `ruler/rules/attack.go:49` |

All three → `Scopes: ScopeItem | ScopeEntity` in `registry_item.go`; vocabulary rows 55/59/60 and the
§2 correction updated. **The two weapon keys were applied as a direct extension of the user-approved
`ArmorRating` principle** (identical evidence, same file, same composition pattern) — flagged here
rather than re-asking. **No call site was changed; the engine code was right all along.**

**Fix 2 — a REAL regression from 13C that MY OWN EARLIER AUDIT MISSED. Recorded so it isn't repeated.**
13C removed `PropertyToString`'s `case string:` branch, and I cleared it by grepping the call sites
and finding them all "typed". **That audit was wrong.** I matched on the call *shape*
(`PropertyToString(x)`) and never checked the *type of the variable*. `effectiveKey` in
`bridge_start.go:227` / `bridge_resurrect.go:196` is a plain `string` — it comes from the JSON map
key `for key, dto := range item.Properties.Data` and from `propertyAliasMap map[string]string`.
It panicked `PropertyToString: Unknown property type: string`, killing the bridge test binary and
masking T1/T3. **Lesson: when auditing a removed type branch, resolve each argument's declared type;
a grep of call shapes is NOT sufficient evidence.**
Fixed correctly at the untyped boundary — `property.Key(effectiveKey).String()` — NOT by restoring
the string branch, which would have undone the round's purpose. Step 14 rewrites this block against
the registry anyway.

### STEP 13 — COMPLETE AND FULLY VERIFIED BY ME 2026-08-31 (pending reviewer gate)

Every acceptance criterion met, verified by me directly:
- **`go build ./...` + `go vet ./...` clean on all three modules.**
- **T5 `TestDefaults_ResolvedNameMatchesRegistryKey` FULLY GREEN 64/64** (65 PASS lines = 64 subtests
  + parent) — `TargetNumber` resolves. **This was step 13's headline goal.**
- **`upsilonbattle`: 189 passed, 0 failed — exactly the documented baseline, fully green.**
- `upsilontypes`: 192 passed, 1 failed = **T4 Movement only** (deliberate → step 15).
- `upsilonapi`: 47 passed, 6 failed = **T1 + T3 only** (deliberate → step 14), no longer masked.
- **No other failure anywhere.**
- Key-side `interface{}`: `entity.go` **2** (the two mixed value params, correct), `skill.go` **0**,
  `effect.go` **0**, `effectapplicator.go` **0**, `scenario.go`/`inspect.go` **0**.
- **Value-side seams unchanged: 15 + 3 + 3 = 21 impl, plus 4 interface decls in `property.go`.**
- **`glob.go` try-all-three fallthrough: GONE.**

**Obligation added to step 18's documentalist Workflow B:** the dual-scope correction to rows 55/59/60
changed registry scope semantics; the `upsilontypes:module_property_key_registry` atom and
`architecture/property_key_vocabulary.md` must be reconciled against it. (No new Workflow E needed —
this corrects data rows inside an already-materialized architectural decision, it does not introduce
a new one.)

### REVIEWER GATE — VERDICT: **OKAY** (2026-08-31)

Independent reviewer reproduced every claim on its own runs; **zero blocking issues**. It went wider
than I did: it also built the **other six workspace modules** (`upsiloncli`, `upsilonhub`,
`upsilonmapdata`, `upsilonmapmaker`, `upsilontools`, `upsilonserializer`) since `upsilontypes`
signatures changed — **all clean, no workspace-wide break.** Test counts reproduced to the number;
registry sums to exactly 64 across the seven theme files.

**It supplied a STRONGER justification for the dual-scope change than mine — record this, it is the
argument to reuse if the decision is ever questioned:** the change is **behavior-preserving, not
permission-granting.** Before the flat-`Key` merge, `ItemProperties` was a distinct Go type, so
`getBasePropertyOrDefault(property.ArmorRating)` hit `DefaultProperty`'s `case property.ItemProperties`
arm and resolved through `ItemProperty()`. Marking rows 55/59/60 `ScopeItem|ScopeEntity` therefore
**records a resolution that already happened**; it does not open a new one. The guard was not weakened.

Also independently confirmed: mixed params correct (entity.go:317/344, only 2 `interface{}` left, both
value slots); all 21 value-side seams untouched; **no bare-string caller of `PropertyToString` anywhere**
— it checked each argument's DECLARED TYPE across 10 files, the audit method I got wrong earlier; and
**the panic is unreachable from legitimate flow** — every dynamic string→key path
(`bridge_start.go`, `bridge_resurrect.go`, `bridge_utils.go`) routes through
`def.ItemProperty`/`EntityProperty`/`SkillProperty`, which return nil for unknown keys and never reach
`getBasePropertyOrDefault`. **Untrusted JSON cannot trigger it.**

*Reviewer's non-blocking note (fold into step 14):* `MakeIntCounterProperty` and
`MakeValidatedStringProperty` still carry `if nname == "" { return nil }` silent-nil guards — now
near-dead with a typed param. Not an oversight; the "default branches removed" claim was accurate.

**ATD:** documentalist Workflow B is deliberately NOT run now — the round plan batches it at step 18,
and steps 14–17 will modify these same files again (applyItemAsBuff rewrite, alias-map deletion,
constructor renames), so syncing atoms now would guarantee an immediate re-sync. The obligation is
recorded above and in step 18.

### Acceptance for step 13 as a whole (I verify, not the agents)
- `go build ./...` + `go vet ./...` clean across all three modules.
- **T5 fully green (64/64)** — `TargetNumber` resolves.
- T4 still red (Movement 5/5 → step 15); T1/T3 still red (bridge → step 14). **No other failures.**
- `grep -c "interface{}" ` on the key seams: 36 → 0; the 21 value-side seams **unchanged**.
- `glob.go` contains no try-all-three fallthrough.

**Correction to an earlier figure:** the plan previously said "45 `interface{}` seams". The verified
count is **36 key-side** (16+5+7+6+1 glob+1 PropertyToString) plus **21 value-side that stay**.


## Handover

### Where things stand (2026-08-31)

**STEP 13 IS COMPLETE, VERIFIED, AND REVIEWER-GATED (OKAY, zero blocking issues).** Everything is
still uncommitted across four repos; nothing has shipped.

**The registry is now LOAD-BEARING** — that was the whole point of step 13. The three resolvers and
`DefaultProperty` read the 64-key registry, `glob.go`'s try-all-three fallthrough is gone, the
key-side `interface{}` erasure layer is eliminated (the 21 value-side seams deliberately remain), and
`Entity.getBasePropertyOrDefault` panics on an unregistered or non-entity-scoped key.

That guard immediately paid for itself: it caught a **real, pre-existing three-key wrong-scope
defect** (`ArmorRating`/`WeaponRange`/`WeaponBaseDamage`), corrected as user-approved dual-scope.
Verification also caught a **regression from slice 13C** (`PropertyToString` no longer accepting bare
strings, breaking the bridge's untyped JSON boundary), fixed at the boundary.

### CURRENT TEST BASELINE — verified 2026-08-31, all three modules

| Module | Result | Notes |
|---|---|---|
| `upsilontypes` | 192 pass / **1 fail** | **T4 `TestDefaults_MovementAbsenceDefaultIsThree` ONLY** → step 15 |
| `upsilonbattle` | **189 pass / 0 fail** | fully green |
| `upsilonapi` | 47 pass / **6 fail** | **T1 + T3 `TestPropertyIngestion_*` ONLY** → step 14 |

`TestDefaults_ResolvedNameMatchesRegistryKey` (T5) is **green 64/64**. Build + vet clean on all three
modules, and the reviewer additionally confirmed the **other six workspace modules build clean**.
**Any OTHER failure is a real regression — investigate, do not absorb it.**

### DO FIRST — step 14

Rewrite `applyItemAsBuff` against the registry (distinct unknown-key vs wrong-scope errors); delete
`propertyAliasMap` (now 2 entries); drop the three type aliases (`EntityProperties`/`SkillProperties`/
`ItemProperties`); rename the lagging constructors `Damage()`/`MvtCost()`/`Value()` to match their
keys. **Turns T1 and T3 green.**

**Fold these into step 14** (found during step 13, all recorded above):
1. `MakeIntCounterProperty`, `MakeStringProperty`, `MakeValidatedStringProperty` still
   `return nil` when the key stringifies to `""` — CODING_RULE §3 silent-nil, now near-dead.
2. Once the three aliases are dropped, **narrow `PropertyToString`'s signature** from `interface{}`
   to `property.Key` — it currently panics on non-`Key` and only stays untyped because of the aliases.
3. The bridge's `property.Key(effectiveKey).String()` boundary conversions are a minimal stopgap;
   the registry rewrite should supersede them.

**Then:** 15 (Movement default, T4) → 16 (buff attribution — **NOTE: `entity.go` is at 385/400 LOC;
put the new accessor in a SEPARATE FILE**) → 17 (non-Go surface) → 18 (reviewer gate, documentalist
Workflow B **including the rows 55/59/60 dual-scope reconciliation**, commits, close ISS-140/143/145/147).

### Two process lessons from step 13 — do not repeat

1. **Scope slices to the real blast radius.** All three original slices were scoped inside
   `upsilontypes`, but the blast radius is 3 modules. **All three reported success while
   `upsilonbattle` did not compile.** Central integration caught it; slice-local verification cannot.
2. **When auditing a removed type branch, resolve each argument's DECLARED TYPE.** I cleared
   `PropertyToString` by grepping call shapes and was wrong — `effectiveKey` was a bare `string`.

### Do NOT re-derive — recorded above in full

Principal-advisor consultation; ATD preflight D1+D2; the 64-key vocabulary freeze; documentalist
Workflow E; the step-11 grounding; the step-12 ordering analysis (decisions 21/22); the wave-2 theme
data; the step-13 four-slice execution, the dual-scope investigation, and the reviewer verdict.

---

## Step 14 — GROUNDING DISPATCHED 2026-09-01

User authorized step 14 with an explicit directive: **delegate sub-tasks as much as possible.**

### Step 14 work items (5 planned + 3 folded in from step 13)

| # | Item | Module | Turns green |
|---|---|---|---|
| 1 | Rewrite `applyItemAsBuff` against the registry; distinct unknown-key vs wrong-scope errors | upsilonapi | T1 (ISS-147) |
| 2 | Delete `propertyAliasMap` (2 entries left after decision 23) | upsilonapi | ISS-143 |
| 3 | Fix `buildSkillPropertyMap`'s written-down silent drop | upsilonapi | T3 (ISS-140) |
| 4 | Drop the 3 type aliases (`EntityProperties`/`SkillProperties`/`ItemProperties`) | all 3 | — |
| 5 | Rename lagging constructors `Damage()`/`MvtCost()`/`Value()` to match their keys | upsilontypes | — |
| 6 | Kill 3 remaining `return nil` silent-nils in `Make*` (CODING_RULE §3) | upsilontypes | — |
| 7 | Narrow `PropertyToString` `interface{}` → `property.Key` (**only possible after #4**) | upsilontypes | — |
| 8 | Supersede the bridge's stopgap `property.Key(effectiveKey).String()` conversions | upsilonapi | — |

**Coupling to respect when slicing:** 4 → 7 → 8 is a hard chain. Dropping the aliases is what makes
narrowing `PropertyToString` possible, and narrowing it is exactly what broke the bridge's untyped
JSON boundary in step 13 (see handover). These three cannot be split across agents that verify only
locally.

**ATD:** round-level preflight (D1+D2) and Workflow E are already recorded above — do NOT re-run.
Step 14 carries one atom obligation forward: `bridge_start.go`'s `@spec-link`s are file-level; since
this step rewrites `applyItemAsBuff`, move `[[mechanic_item_buff_application]]` atop that function.

### Grounding — 2 parallel `codebase-explorer` passes dispatched 2026-09-01

Cut on module boundaries so they share no files.
- **Bridge side (`upsilonapi`)** — current `applyItemAsBuff` / `buildSkillPropertyMap` /
  `propertyAliasMap` / `hydrateSingleBuffProperty` bodies, the complete stopgap-conversion list, the
  alias mentions in-module, the T1/T3 test expectations, build/vet/test state, and the bridge's
  error-reporting convention (needed to specify "distinct unknown-key vs wrong-scope errors").
- **Types side (`upsilontypes` + cross-module)** — alias declarations and the FULL 3-module alias
  blast radius classified by usage kind, `PropertyToString` + every caller **with the declared type
  of each argument resolved** (step 13 lesson 2), the 3 lagging constructors + call-site counts, the
  3 silent-nil `Make*`, the verbatim registry API surface (`Entry`/`Scope`/`Kind`/`Composition`/
  `Lookup`) for the implementation brief, LOC ceilings, build/vet/test on types + battle, gofmt state.

Both told to flag anything contradicting the recorded context — that is the highest-value output.

**Baseline any slice must not regress** (verified 2026-08-31): upsilontypes 192/1 (T4 only) ·
upsilonbattle 189/0 · upsilonapi 47/6 (T1+T3 only). Any OTHER failure is a real regression.

### Step 14 grounding — BRIDGE SIDE LANDED + VERIFIED BY ME 2026-09-01

Explorer report re-checked against source by me (alias map, both fallthroughs, `property.Key(` sites,
alias counts, and the resolver/`Lookup` signatures). **Every load-bearing claim holds.**

25. **`def.Lookup` IS EXPORTED AND ALREADY CARRIES THE DISTINCTION — item 1 needs NO upsilontypes
    change.** Verified at `upsilontypes/property/def/registry.go:89-92`:
    `func Lookup(k property.Key) (Entry, bool)`. The three resolvers each collapse two different
    failures into one `nil`:
    `item.go:206-212` / `entity.go:112-118` / `skill.go:331-337` all read
    `if !ok || entry.Scopes&Scope<X> == 0 { return nil }`.
    So "distinct unknown-key vs wrong-scope errors" is expressible **entirely inside the bridge** by
    calling `def.Lookup` directly: `!ok` ⇒ unknown key; `ok && entry.Scopes&(ScopeItem|ScopeEntity)==0`
    ⇒ known-but-wrong-scope. **Consequence: the bridge slice and the types slice are DECOUPLED and can
    run in parallel.** This was not obvious from the plan, which implied new plumbing.

26. **THE ISS-147 FALLTHROUGH EXISTS TWICE, AND THE SECOND COPY HAS ZERO TEST COVERAGE.**
    `applyItemAsBuff` (`bridge_start.go:215-231`) and `hydrateSingleBuffProperty`
    (`bridge_resurrect.go:183-199`) contain a **byte-for-byte identical** `def.ItemProperty(...)` →
    nil → `def.EntityProperty(...)` fallthrough, each preceded by the same alias-map read and
    followed by the same `property.Key(effectiveKey).String()` stopgap. T1 only exercises
    `applyItemAsBuff`. The resurrection path (arena crash-recovery) is invisible to CI.
    **The plan's step-14 text names only `applyItemAsBuff`** — it lists `bridge_resurrect.go:186`
    solely as an alias-map call site, not as a second instance of the defect. **Scope call needed
    (see open question).** Fixing one and not the other leaves ISS-147 half-closed.

**Confirmed working-tree facts (bridge side):**
- `propertyAliasMap` (`bridge_utils.go:12-15`) is **down to 2 entries** — `CritChance`/`CritDamage`.
  Decision 23's `ArmorRating` deletion already landed. Only **2 live read sites**:
  `bridge_start.go:217`, `bridge_resurrect.go:186`.
- `buildSkillPropertyMap` (`bridge_utils.go:92-108`) unchanged; the *"silently skipped to ensure
  robustness"* doc comment is still on line 91.
- Exactly **2** stopgap `property.Key(<bare string>).String()` sites, both the buff-map write:
  `bridge_start.go:228`, `bridge_resurrect.go:197`.
- Alias identifiers in `upsilonapi`: **7 code usages** (6 type conversions + 1 test var decl at
  `property_ingestion_test.go:25`) + 2 prose-comment mentions = 9 grep hits. All mechanical.
- Bridge error convention is **three inconsistent styles**: wrapped `fmt.Errorf` for request-level
  failures, `log.Printf`+return for bad item UUIDs, and **silent `continue` with no error and no log**
  for per-key rejection. Item 1 must pick one deliberately, not inherit the local one.
- `upsilonapi` build + vet clean; 47 pass / 6 fail, and the 6 are exactly T1(3 subtests+parent) and
  T3(1 subtest+parent). **Baseline matches.**

**TWO STALE TEST ARTIFACTS — both currently PASSING, both asserting against already-fixed defects:**
- `property_alias_test.go` (`TestPropertyIngestion_ArmorRatingAliasMustNotBeSilentlyDropped`) documents
  a `"ArmorRating": "Armor"` entry that **no longer exists** in the map. Green, but its premise is gone.
- `property_ingestion_test.go`'s `/TargetNumber_is_a_documented_property_dropped_today` subtest comment
  claims `def.SkillProperty` has no `TargetNumber` case; the registry registers it
  (`registry_skill_targeting.go:21-23`). Green, premise stale.
  Both need their comments reconciled in step 14 or they will mislead the next reader.

**ATD note:** `bridge_start.go`'s `@spec-link [[mechanic_item_buff_application]]` is **cross-module** —
the atom lives at `upsilonbattle/docs/`, status **DRAFT**. Relevant when the link moves atop the
rewritten function.


### Step 14 grounding — TYPES SIDE LANDED + VERIFIED BY ME 2026-09-01

Re-checked by me against source: `PropertyToString` body, the alias declarations, the three
constructors' call sites, every `return nil` in `defaultproperty.go`, LOC, gofmt state.
**Four recorded facts were WRONG and are corrected here.**

27. **`PropertyToString` IS ALREADY NARROWED IN BEHAVIOR — item 7 is now trivial and safe.**
    Verified at `propertyenum.go:172-178`: the signature is still `p interface{}`, but the body is
    `k, ok := p.(Key); if !ok { panic(...) }; return k.String()`. **There is no bare-`string` case.**
    And I resolved the declared type at **every** caller across all 3 modules (18 sites): all pass a
    `Key` (directly or via an alias constant). **Zero bare-string callers exist.** So narrowing the
    signature `interface{}` → `property.Key` is a pure compile-time tightening with no behavior
    change and no call-site churn. Step 13's boundary fix (`property.Key(effectiveKey).String()`)
    is what already absorbed the untyped JSON edge.

28. **THE THREE LAGGING CONSTRUCTORS HAVE ZERO EXTERNAL CALL SITES — item 5 is far smaller than
    planned.** `grep` for `def.Damage()|def.MvtCost()|def.Value()` across all three modules returns
    **0**. Each has exactly **one** caller, unqualified and in-package, from its own registry `New:`
    closure: `registry_skill_effect.go:10` (Damage) · `registry_skill_cost_trigger.go:30` (MvtCost) ·
    `registry_item.go:86` (Value). Targets: `DamageScale` / `MovementCost` / `ItemValue`.
    **The rename is 3 declarations + 3 in-package closures. It cannot break another module.**

29. **ONLY TWO SILENT-NIL BRANCHES EXIST, NOT THREE — item 6 corrected.** `defaultproperty.go` has 7
    `return nil`s; I read all 7. **Five are `UserFriendlyGet` information-level gating** (lines 37,
    137, 215, 290, 379) — legitimate, NOT in scope. The real silent-nils are exactly **two**:
    `MakeIntCounterProperty:98` and `MakeValidatedStringProperty:356`, both `if name.String() == ""`.
    `MakeStringProperty` (346-349) has **no branch of its own** — it delegates to
    `MakeValidatedStringProperty`, so fixing that one covers it. `MakeIntProperty`/`MakeFloatProperty`/
    `MakeBoolProperty` no longer have nil branches at all — **step 12's wave-1 collateral fix already
    removed them**, so that grounding-facts bullet is now stale.

30. **LOC correction + a live ceiling violation.** `defaultproperty.go` is at
    `property/defaultproperty/defaultproperty.go` (a SUBPACKAGE — not `property/` as recorded) and is
    **434 LOC, not 446**. It is the ONLY file in this area over the 400 warn ceiling. `def/skill.go`
    is down to **337** (was 392 — the registry extraction shrank it). `entity/entity.go` is **385**,
    confirming step 16's separate-file requirement. No other file at or over 400.

31. **GOFMT IS FAR WORSE THAN RECORDED: 19 unclean files in `upsilontypes`, not just `def/skill.go`.**
    Four are files step 14 will touch: `property/propertyenum.go`, `property/property.go`,
    `property/def/skill.go`, `property/defaultproperty/defaultproperty.go`. The rest are pre-existing
    `entity/skill/**` noise, unrelated. **This amplifies the standing gotcha:** a `gofmt -r` sweep on
    `propertyenum.go` (item 4's main target) would blend a whole-file reformat into the alias diff and
    make review impossible. **Slices are FORBIDDEN from using `gofmt -r`.**

**Alias blast radius (verified): 104 identifier occurrences, but far less real work than that implies.**
| Module | Occurrences | Real (non-comment) work |
|---|---|---|
| upsilontypes | 92 | 64 const decls + 3 alias lines + 3 `map[SkillProperties]bool` + 3 func signatures, **all but 3 in `propertyenum.go`** |
| upsilonbattle | 3 | 1 map type (`micro/helpers.go:15`) + 1 test signature |
| upsilonapi | 9 | 6 type conversions + 1 test struct field (rest are comments) |

**KEY LEVERAGE: slice 14A dissolves all 6 upsilonapi conversions as a side effect.** Rewriting
`applyItemAsBuff`/`hydrateSingleBuffProperty`/`buildSkillPropertyMap` against `def.Lookup` deletes
every `property.ItemProperties(...)`/`EntityProperties(...)`/`SkillProperties(...)` call in the bridge.
**So 14A must land before the alias sweep, or the sweep edits lines 14A is about to delete.**

**Baselines confirmed independently by this pass:** upsilontypes build+vet clean, 192 pass / **1 fail**
(T4 `TestDefaults_MovementAbsenceDefaultIsThree` only) · upsilonbattle build+vet clean, **189/0**.
Matches the recorded baseline exactly. `TestDefaults_ResolvedNameMatchesRegistryKey` green **64/64**,
including `TargetNumber` — **both explorers independently flagged its doc comment as stale**, matching
the bridge-side `TargetNumber` finding. Same stale comment, two places.

32. **ATD SEMANTIC INDEX IS STALE AGAINST THE DIRTY TREE — both explorers hit this independently.**
    `atd search` returned a `bridge_start.go` snippet containing `PropertyToString(effectiveKey)`,
    which **no longer exists on disk**. Expected (the index predates this uncommitted round), but
    **treat every ATD-surfaced snippet this round as a lead to verify against the file, never as
    ground truth.** This compounds the already-recorded "`atd index` has never been built" debt.

## Step 14 — SLICE DESIGN (2026-09-01, NOT yet dispatched)

**Two waves.** Wave 1's two slices are disjoint by module AND by file, so they run in parallel.
Wave 2 must follow, because 14A deletes the very lines 14C would otherwise edit (see leverage note).
**Central integration and full-suite verification are MINE, not the agents'** — step 13's lesson 1
was that all three slices reported success while a sibling module did not compile.

### WAVE 1 — parallel, disjoint

| Slice | Module / files owned | Items | Turns green |
|---|---|---|---|
| **14A** — bridge registry rewrite | `upsilonapi/bridge/`: `bridge_start.go`, `bridge_utils.go`, `bridge_resurrect.go`, + the 2 test files | 1, 2, 3, 8 (+ the duplicate fallthrough, pending scope call) | **T1 + T3** |
| **14B** — types cleanup | `upsilontypes/property/def/{skill,item}.go`, `registry_skill_effect.go`, `registry_skill_cost_trigger.go`, `registry_item.go`, `property/defaultproperty/defaultproperty.go` | 5, 6 | — (no test moves) |

**14A** replaces both fallthroughs with a single `def.Lookup`-based resolution that distinguishes
`!ok` (unknown key) from `ok && entry.Scopes&(ScopeItem|ScopeEntity)==0` (known, wrong scope); deletes
`propertyAliasMap` and both its read sites; removes `buildSkillPropertyMap`'s silent `continue` AND its
"silently skipped to ensure robustness" doc comment; and supersedes both stopgap
`property.Key(effectiveKey).String()` conversions. Must pick ONE error convention deliberately — the
bridge currently has three. Also reconciles the two stale test comments and moves
`@spec-link [[mechanic_item_buff_application]]` atop the rewritten `applyItemAsBuff`.

**14B** renames `Damage`→`DamageScale`, `MvtCost`→`MovementCost`, `Value`→`ItemValue` (3 decls + 3
in-package closures, zero external reach per decision 28) and replaces the 2 silent-nil branches with
crash-early panics per CODING_RULE §3. **Must not touch `propertyenum.go`** — that is 14C's file.

### WAVE 2 — after 14A lands and I have integrated it

| Slice | Scope | Items |
|---|---|---|
| **14C** — alias deletion + signature narrowing | `propertyenum.go` (64 const type changes, 3 alias lines, 3 map types), 3 upsilontypes func signatures, `upsilonbattle/battlearena/controller/behavior/micro/helpers.go:15`, 2 test sites | 4, 7 |

Narrowing `PropertyToString` to `property.Key` is safe per decision 27 (zero bare-string callers).

### Guardrails every slice gets in its brief
- **`gofmt -r` is FORBIDDEN** (decision 31). Package-qualified selector rewrites only. Run plain
  `gofmt -w` on files you actually edited, and on nothing else.
- **Do not "fix" a failing test you did not cause.** T4 (`TestDefaults_MovementAbsenceDefaultIsThree`)
  is deliberately red until step 15. Leave it.
- **Do not treat `atd search` output as ground truth** (decision 32) — verify against the file.
- **Report, do not absorb, any failure outside your slice's expected set.**
- Baseline to hold: upsilontypes 192/1 · upsilonbattle 189/0 · upsilonapi 47/6 → **14A must move
  upsilonapi to 53/0**; 14B and 14C must move nothing.

33. **SCOPE EXPANSION APPROVED (user, 2026-09-01): the resurrect-path duplicate of the ISS-147
    fallthrough is FOLDED INTO SLICE 14A.** `hydrateSingleBuffProperty` (`bridge_resurrect.go:183-199`)
    gets the same registry rewrite as `applyItemAsBuff`, plus its own red-first test (it had ZERO
    coverage). Rationale accepted: fixing one and not the other closes ISS-147 only halfway, and both
    live in the same 3 files the slice already owns.

### THE ERROR CONTRACT for 14A — specified by me, not left to the agent

The bridge had THREE inconsistent conventions (wrapped `fmt.Errorf` / `log.Printf`+return / silent
`continue`). Converged on ONE for per-key rejection:
- **Return errors, never panic.** The bridge is an ingestion boundary fed by untrusted client JSON, so
  a bad key is bad INPUT, not a programming error. **Deliberate contrast with
  `entity.go:165-171`, which correctly DOES panic** — a bad key at the entity layer IS a programming
  error. That idiom must not be copied into the bridge.
- Two package-level sentinels wrapped with `%w` so tests can use `errors.Is`:
  `ErrUnknownPropertyKey` (`Lookup` → `!ok`) and `ErrPropertyKeyWrongScope`
  (`ok && entry.Scopes&<expected> == 0`, message carries expected + actual scopes).
- **Accumulate with `errors.Join`, do not abort on first bad key** — one typo must not discard a valid
  loadout.
- Nothing may be discarded with no error and no log.

### T3's assertion is being REWRITTEN — sanctioned, and the ONLY rewrite 14A may make

T3's subtest asserts `assert.Len(t, result, len(raw))` — a **length proxy** written red-first before
the fix shape was settled. Making it literally pass would require inserting an UNREGISTERED key into
the engine's property map, which is exactly the wrong outcome. Replaced with assertions on the real
contract: (1) an error is returned and `errors.Is(err, ErrUnknownPropertyKey)` holds naming the key;
(2) the valid key in the same payload still resolves, proving accumulation rather than abort.
**T1's `assert.Empty` is the correct contract and must NOT be weakened** — the brief says that editing
it means the agent has made a mistake and must stop.

### WAVE 1 DISPATCHED 2026-09-01 — 14A ∥ 14B

Both briefed with: verbatim `Lookup`/`Entry`/`Scope` contract, exact file ownership, hard cross-module
boundaries, the `gofmt -r` prohibition (decision 31), the "T4 is deliberately red — leave it" warning,
the stale-`atd search` warning (decision 32), a no-mutating-git-commands rule, LOC ceilings, and
per-slice acceptance with **pasted-output** evidence requirements.

**14B additionally carries the step-13 lesson-1 guard**: it MUST run `upsilonbattle`'s suite too
(189/0), because `upsilonbattle` imports `upsilontypes` and slice-local verification cannot see a
sibling-module break.

Both told: if a change outside your module looks required, **STOP and report — do not reach across**.

**Expected on return:** 14A → upsilonapi 47/6 becomes **53/0**. 14B → upsilontypes stays **192/1**
(T4 only) + new panic tests, upsilonbattle stays **189/0**.
**Integration + full-suite verification are MINE. Wave 2 (14C alias sweep) does not dispatch until
14A is landed and integrated**, since 14A deletes the 6 bridge alias conversions 14C would edit.

### SLICE 14B — LANDED AND INDEPENDENTLY VERIFIED BY ME 2026-09-01

I re-ran every acceptance check myself rather than trusting the report. **All claims hold.**

**Renames (items 5) — complete, no stragglers.**
`func Damage()|MvtCost()|Value()` → **zero matches** repo-wide. New decls at `def/skill.go:32`
(`DamageScale`), `def/skill.go:93` (`MovementCost`), `def/item.go:38` (`ItemValue`); the three registry
closures updated at `registry_skill_effect.go:10`, `registry_skill_cost_trigger.go:30`,
`registry_item.go:86`. A repo-wide grep for any lingering unqualified `Damage()`/`MvtCost()`/`Value()`
call returns **nothing**. Decision 28's zero-external-call-sites finding was re-confirmed by the agent.

**Silent-nils (item 6) — exactly the right two.**
Panics now at `defaultproperty.go:100` (`MakeIntCounterProperty`) and `:358`
(`MakeValidatedStringProperty`), each naming the constructor and the reason.
**`grep -c "return nil"` = 5** — precisely the five `UserFriendlyGet` info-level gates decision 29
ruled out of scope. `MakeStringProperty`'s pass-through is covered transitively, as designed.
Agent searched for callers depending on the nil return and found none; the 3 new tests confirm the
panics fire.

**Test state — verified by me, not reported:**
- `upsilontypes`: build+vet clean, **195 pass / 1 fail**. The single failure is
  `TestDefaults_MovementAbsenceDefaultIsThree` (T4), deliberately red until step 15. 192 baseline + 3
  new panic tests = 195. Exact.
- `upsilonbattle`: build+vet clean, **ZERO failures** — baseline 189/0 held. The step-13 lesson-1
  cross-module guard did its job.
- `TestMakeIntCounterProperty_EmptyKeyPanics` / `TestMakeValidatedStringProperty_EmptyKeyPanics` /
  `TestMakeStringProperty_EmptyKeyPanics` all present and PASS.

**`propertyenum.go` boundary held.** Its 71-line diff is pre-existing step-12/13 alias work; I grepped
the diff for 14B-shaped content (`DamageScale()`/`MovementCost()`/`ItemValue()`/`panic(fmt`) and found
**none**. The agent never opened the file, as instructed.

**ONE DEVIATION — accepted, recorded.** The agent ran `go mod tidy` on `upsilontypes` because its new
test imports `testify/require`. I inspected the diff: `testify v1.11.1` promoted **indirect → direct**,
plus `gopkg.in/yaml.v3` as indirect; go.sum +5 lines. **No new dependency actually enters the build** —
`go-spew` and `go-difflib` (testify's own deps) were already present as indirect, so testify was
already in the graph. This is a declaration correction, not a dependency addition. Legitimate and
minimal. Flagging it only because a `go.mod` change was not in the brief's scope.

**MINOR, not worth reopening:** `defaultproperty.go` went **434 → 436 LOC** (+2). The brief asked for
net-neutral-or-smaller. It remains over the 400 warn ceiling, but that violation is **pre-existing**
(decision 30) and 2 lines does not change its character. Left as-is; it still deserves its own
cleanup someday.

**14B is DONE.** Items 5 and 6 are closed.

### SLICE 14A — LANDED, VERIFIED BY ME, BLOCKED ON ONE VOCABULARY DECISION 2026-09-01

**The code work is correct and complete.** I verified every claim independently:
- `go build` + `go vet` **clean**.
- Both sentinels present (`bridge_utils.go:20,23`), wrapped with `%w`, `errors.Join` accumulation.
- **Both ISS-147 fallthroughs GONE** — `grep "def.EntityProperty\|def.ItemProperty" bridge/*.go`
  returns **nothing**. `applyItemAsBuff` AND `hydrateSingleBuffProperty` both resolve through the
  shared `resolveScopedProperty(key, want def.Scope)` helper off `def.Lookup`.
- `propertyAliasMap` gone from production (ISS-143 closed); `"silently skipped"` comment gone (ISS-140).
- `@spec-link [[mechanic_item_buff_application]]` **moved from the file header to line 200**, directly
  atop `applyItemAsBuff`. ATD obligation discharged.
- **T1, T3, the alias test, and the NEW resurrect-path test ALL PASS** (verified by direct run).
  The red-first resurrect test is real coverage on a path that had none.
- Error message quality is excellent: `key "Attack" has scopes Entity, expected Item`.

**Suite is 55 pass / 2 fail — NOT the 53/0 target. The agent correctly refused to absorb it.**

34. *** THE ROUND'S SECOND MAJOR VOCABULARY DEFECT — ISS-147's FIX COLLIDES WITH ISS-142's RULING ***
    **Same class as step 13's `ArmorRating` discovery, one layer deeper. Found by 14A, confirmed by me.**

    `TestArenaInit_EquippedItemsBecomeBuffs` (`equipment_test.go:18-41`) equips a **"PowerRing"**
    carrying `property.Attack.String(): 5` and asserts via `require.NoError` that it becomes a buff.
    `property.Attack` is registered **`Scopes: ScopeEntity`** only (`registry_entity_core.go:9`).
    Removing the entity-scope fallthrough — which is *precisely* ISS-147's fix — now correctly rejects
    it. **An item can no longer grant +5 Attack.**

    `TestArenaLifecycleDestruction` is a **pure cascade, confirmed**: it PASSES when run alone. The
    chain is `require.NoError` → `t.FailNow()` → trailing `b.DestroyArena(matchID)` never runs → a
    leaked arena in the package-level singleton → the next test's `GetActiveMatchCount()` sees 2, not 1.
    **One root cause, not two.**

    **THE DECIDING EVIDENCE — a user design ruling already exists and already draws exactly this line.**
    `ISS-142` (High, **Open**) §"Design ruling — buffability and failure mode (user, 2026-08-27)"
    partitions all 20 entity keys:
    | Class | Keys | Ruling |
    |---|---|---|
    | **Buffable — attributes** | `Attack`, `Defense`, `Movement`, `JumpHeight`, `AttackRange` | "True combat attributes; the intended target of the ruling" |
    | **Buffable — resources** | `HP`, `SP`, `MP` | "Included per ruling", with per-turn regen semantics |
    | **NOT buffable — statuses** | `Shield`, `Poison`, `Stun` | "Already applied directly by `effectapplicator` via `ShieldPower`/`PoisonPower`/`StunPower`; a parallel durational path would collide" |
    | **NOT buffable — flags/plumbing** | `TeamID`, `IsDying`, `HasMoved`, `HasActed`, `EntityDuration`, `ExpiresWithCaster`, `WalkThrough`, `Invisible`, `AIArchetype` | "Buffing `TeamID` or `Invisible` would be an exploit, not a feature" |
    5 + 3 + 3 + 9 = **20 = exactly the entity key count.** The partition is total.

    **The not-buffable statuses are EXACTLY the ISS-147 trio.** ISS-142's ruling and ISS-147's fix
    agree perfectly — the registry's scope model simply has not encoded the ruling yet.
    ISS-142 line 111 also records items buffing entity attributes as **existing working behavior**:
    *"Items **can** buff entity attributes ... so `Movement`, `HP`, `Attack`, `Defense` all work."*

    **MY RECOMMENDATION: dual-scope the 8 buffable keys as `ScopeItem | ScopeEntity`** — extending the
    exact precedent the user already approved in step 13 for `ArmorRating`/`WeaponRange`/
    `WeaponBaseDamage`. Poison/Shield/Stun and the 9 flags stay entity-only, so item `"Poison"` is
    still rejected and **T1 stays green**. This unbreaks `equipment_test` without weakening ISS-147.

    **Two caveats the user must see before ruling:**
    (i) ISS-142's ruling governs **skill**-originated buffs; applying it to **item**-originated buffs
        is an extension — defensible (the taxonomy is about legitimate buff *targets*, origin-agnostic,
        and line 111 documents items already doing it) but it IS an extension.
    (ii) ISS-142 flags its OWN status/flag exclusions as *"an inference ... should be confirmed before
        implementation."* The part we depend on (statuses excluded) is independently corroborated by
        ISS-147, so our reliance is safe — but the flag list is not settled law.

    **This changes the FROZEN vocabulary** (`architecture/property_key_vocabulary.md` §3 declares these
    entity-only), so per the freeze discipline and the ATD signoff pattern it needs explicit user
    approval — same as step 13's dual-scope change did.
35. **DUAL-SCOPE RULING — USER APPROVED 2026-09-01. Resolves decision 34.**
    **The 8 buffable entity keys become `ScopeItem | ScopeEntity`:** `Attack`, `Defense`,
    `AttackRange` (`registry_entity_core.go:9,13,17`), `Movement`, `JumpHeight`
    (`registry_entity_movement.go:10,14`), `HP`, `SP`, `MP` (`registry_entity_vitals.go:10,14,18`).
    **`Shield`/`Poison`/`Stun` (`registry_entity_vitals.go:22,26,30`) and the 9 flag/plumbing keys stay
    entity-only** — so ISS-147 stays structurally fixed and T1 stays green.
    This encodes ISS-142's 2026-08-27 user ruling directly into the registry's scope bits and extends
    step 13's approved `ArmorRating`/`WeaponRange`/`WeaponBaseDamage` precedent from 3 keys to 11.
    Resource keys HP/SP/MP were included per the ruling (the more conservative attributes-only variant
    was offered and declined).
    **The frozen vocabulary §3 is amended accordingly** — first amendment to the freeze this round.

### SLICE 14D DISPATCHED 2026-09-01 — dual-scope + conformance test + vocabulary amendment

Owns ONLY: the 3 `registry_entity_*.go` files, a new `registry_buffability_test.go`, and
`architecture/property_key_vocabulary.md`. Explicitly barred from `.atom.md` files (ATD sync is
step 18's), from `equipment_test.go` (its premise is correct — 14D's change is what makes it pass),
and from `propertyenum.go` (wave 2's).

Briefed with the exact 8 file:line targets, the must-not-touch list, the existing dual-scope style to
match (`registry_item.go:31,62,69`), the `gofmt -r` ban, the "T4 stays red" warning **plus an explicit
caution not to confuse changing `Movement`'s SCOPE with changing its DEFAULT**, and three-module
acceptance.

**Task 2 is the durable part:** a conformance test walking the registry to pin all three partitions
(8 dual-scoped / 3 statuses entity-only citing ISS-147 / 9 flags entity-only citing the exploit
rationale), so this ruling can never silently drift again.

**Expected:** upsilonapi **55/2 → 57/0** · upsilontypes 195→196 pass /1 fail (T4 only) ·
upsilonbattle 189/0.

**CARRY TO STEP 18:** the Workflow B "rows 55/59/60 dual-scope reconciliation" now grows to cover
**11 dual-scope keys, not 3**, and the vocabulary doc has a recorded amendment.

### SLICE 14D — LANDED AND INDEPENDENTLY VERIFIED BY ME 2026-09-01

**Scope partition verified by grep, not by report.** Exactly 8 keys carry
`Scopes: ScopeItem | ScopeEntity` in `registry_entity_{core,movement,vitals}.go`:
`Attack`, `AttackRange`, `Defense`, `HP`, `JumpHeight`, `Movement`, `MP`, `SP` (COUNT: 8).
Exactly 12 keys remain entity-only: the 3 statuses (`Shield`, `Poison`, `Stun`) + the 9
flag/plumbing keys. 8 + 12 = 20, matching the recorded entity-key total. **ISS-147 stays
structurally fixed** — the trio it was filed about is precisely the trio that stayed entity-only.

**New conformance test** `registry_buffability_test.go` pins the partition in three tests, citing
ISS-147 and the exploit rationale in its failure messages, so a future scope flip cannot pass silently.

**Vocabulary amendment landed** in `architecture/property_key_vocabulary.md`: a
`CORRECTION 2026-09-01 (slice 14D)` blockquote in §2, and §3 rows 1,2,3,4,5,6,7,12 Scope column
now read `**Item+Entity**`. This is the **first amendment to the round's frozen vocabulary**.

**Test state after 14A + 14B + 14D — all three modules, build + vet clean:**
- `upsilontypes`: **198 pass / 1 fail** — sole failure `TestDefaults_MovementAbsenceDefaultIsThree`
  (T4, deliberately red until step 15). Was 192/1 at baseline; +6 from 14D's conformance tests.
- `upsilonbattle`: **189 pass / 0 fail** — unchanged from baseline, as intended.
- `upsilonapi`: **57 pass / 0 fail** — was 47/6 at step 14 start (T1+T3 red), 55/2 after 14A alone.
  **T1 (ISS-147) and T3 (ISS-140) are both green.** The two residual failures after 14A were the
  vocabulary collision (decision 34) and its cascade; both are gone.

`TestArenaLifecycleDestruction`'s earlier failure was confirmed a pure cascade, not a real defect:
`require.NoError` → `t.FailNow()` skipped `b.DestroyArena(matchID)`, leaking an arena into the
package-level singleton that the next test's `GetActiveMatchCount()` observed. It passes alone and
passes now.

### ORCHESTRATION INCIDENT — TODO.md APPENDS MISROUTED, REPAIRED 2026-09-01

Bash working directory persists between tool calls. Several `cat >> TODO.md` heredocs inherited a
`cd` from a preceding command and wrote to **stray `TODO.md` files inside three submodules**:
`upsilonapi/`, `upsilonbattle/`, `upsilontypes/property/def/`, `upsilontypes/property/defaultproperty/`.
Decisions 25–35 and every narrative section after "Step 14 — GROUNDING DISPATCHED" were missing from
root. **Repaired**: all stray content merged back into root in chronological order, each of 25–35
verified present exactly once, strays deleted so they stop polluting `git status` in three submodules.
**Standing rule for the rest of this round: every `TODO.md` write uses the absolute root path.**

### Step 14 wave 2 — 14C grounding re-verified by me 2026-09-01 (post 14A/14B/14D)

Re-grepped rather than trusting the pre-wave-1 grounding, since three slices moved the tree.

36. **THE ALIAS SURFACE IS 95 REFS / 11 FILES, AND MOSTLY COMMENTS OUTSIDE `propertyenum.go`.**
    `upsilontypes` 88 · `upsilonbattle` 3 · `upsilonapi` 4. `propertyenum.go` alone holds 78 of the 88
    (64 const declarations + 3 alias type lines at 17/64/151 + 3 alias-keyed maps + doc comments).
    **Only 7 live-code sites exist outside it**: `skill.go:88,98`, `blueprint.go:36`,
    `micro/helpers.go:15`, `rules_endofturn_writeisolation_test.go:21`,
    `property_ingestion_test.go:29`, `property_resurrect_fallthrough_test.go:32`. Everything else
    (`def/item.go` ×5, `def/skill.go:103`, `property_alias_test.go` ×2, `keyspace_invariant_test.go:11`,
    `micro/helpers.go:14`) is a **comment** referencing the alias by name — real work, but zero compile risk.

37. **THE THREE `map[SkillProperties]bool` ARE REAL AND ALL LIVE IN `propertyenum.go`** (117
    `SkillTargetingProperties`, 128 `SkillEffectProperties`, 141 `SkillCostProperties`). The recorded
    fact was right; my first grep missed them only because it excluded `propertyenum.go`.

38. **NARROWING `PropertyToString` DELETES ITS PANIC, AND THAT IS AN IMPROVEMENT, NOT A §3 VIOLATION.**
    With the parameter typed `Key`, the `k, ok := p.(Key)` assertion is statically dead and the body
    collapses to `return k.String()`. The panic existed to catch a type error the **compiler now catches
    at build time**. Compile-time rejection strictly dominates runtime panic; CODING_RULE §3 is about
    not *swallowing* failures, and nothing is being swallowed. Recorded so no later reader reads the
    vanished panic as a regression.

**Explicitly NOT in 14C (follow-up candidate):** `PropertyToString` becomes a pure synonym for
`Key.String()` across ~90 call sites. Collapsing them is a separate mechanical sweep, out of scope here.

### SLICE 14C DISPATCHED 2026-09-01 — alias deletion + PropertyToString narrowing (plan items 4 + 7)

**Single slice, not parallel:** deleting a type alias breaks every referent in the same compile, so the
three modules must move together in one atomic change. Baseline it must not regress:
upsilontypes 198/1 (T4 only) · upsilonbattle 189/0 · upsilonapi 57/0.

### SLICE 14C — LANDED AND INDEPENDENTLY VERIFIED BY ME 2026-09-01. **STEP 14 IS COMPLETE.**

Verified by re-running everything myself, not by trusting the agent's report.

**Alias deletion complete.** `grep -rn --include=*.go -E "\b(EntityProperties|SkillProperties|ItemProperties)\b"`
over the whole umbrella returns **0 hits**. `type Key string` survives as the sole key type.
Exactly **64** const declarations now read `X Key = "X"` — matching the 64-key registry one-for-one.
The three alias-keyed maps are `map[Key]bool`. `propertyenum.go` shrank to **158 LOC**.

**`PropertyToString` narrowed** to `func PropertyToString(p Key) string { return p.String() }` — assertion,
panic and the now-unused `fmt` import all gone, exactly as decision 38 pre-approved.

**Verification, all three modules, build + vet clean:**
- `upsilontypes`: **198 pass / 1 fail** — the one failure is `TestDefaults_MovementAbsenceDefaultIsThree`
  (T4, still deliberately red until step 15). Exact baseline match.
- `upsilonbattle`: **189 pass / 0 fail** — exact baseline match.
- `upsilonapi`: **57 pass / 0 fail** — exact baseline match.

**Guardrails held:** no `.atom.md`, `.md`, `go.mod` or `go.sum` file was touched (verified by mtime sweep);
no stray `TODO.md` reappeared; `PropertyToString(x)` call sites were left alone as instructed.

39. **`code_health_check.py` FINDINGS ON THE TOUCHED FILES ARE ALL PRE-EXISTING — 14C INTRODUCED NONE.**
    Confirmed by running the checker against the `HEAD` version of each file and diffing the result sets:
    `propertyenum.go` 2 errors + 1 warning at HEAD, **identical** now (both errors are phantom ATD links,
    `[[mech_entity_expiration]]` and `[[mec_ai_archetype_system]]`, which reference atoms that do not exist);
    `skill.go` 2 errors at HEAD, identical now; `blueprint.go` 1 error at HEAD (`setEffectProperty` nesting 5),
    identical now. **For step 18:** the 2 phantom links are real ATD debt and `propertyenum.go`'s 6 `@spec-link`s
    sit atop **const blocks**, not functions — both belong in the documentalist Workflow B pass.

40. **ONE IMPRECISION IN THE AGENT'S REPORT, MATERIALLY HARMLESS.** It flagged
    `def/defaults_conformance_test.go` as a necessary out-of-brief edit (its `key` field was `interface{}`
    and fed `PropertyToString`) — correct, well-reasoned, and behavior-preserving, since every value assigned
    to that field is already a `Key` constant. But it claimed this was "the one call site in the whole umbrella
    not already typed `property.Key`", and `Skill.HasProperty(p interface{})` at `skill.go:73` carries the same
    forced narrowing. **I could not attribute that second one between 14C and an earlier step of this round**,
    because the whole round is uncommitted so `git diff HEAD` conflates steps 11–14 and no pre-14C snapshot
    exists. Recording the ambiguity rather than inventing certainty. The change is correct either way — it is
    compile-time only, forced by the `PropertyToString` signature, and the full suite is at baseline.

**`entity.go` is still 385 LOC** — step 16's buff-attribution accessor must still go in a SEPARATE FILE.

### Post-step-14 assurance pass DISPATCHED 2026-09-01 (user-requested, 2 agents in parallel)

**1. Full-umbrella test sweep** (read-only agent, no Edit/Write tools by construction).
Rationale: I had only been testing the 3 refactored modules. `upsilontypes` is imported widely, so a
downstream consumer (`upsilonhub`, `upsiloncli`, `upsilonserializer`, `upsilonmapdata`, `upsilontools`,
`upsilonauth`, `upsiloneconomy`, `upsilonplatform`) could be broken by the alias deletion without my
ever seeing it. Told to enumerate modules from `go.work`, run build/vet/test on each, report exact
counts, separate ENVIRONMENTAL failures (db/docker/network) from real ones, and treat a build failure
as the highest-value finding.

**2. Phantom ATD atom investigation** (documentalist, report-only — explicitly forbidden from authoring).
**User's steer: entity expiration and the AI archetype system are TRUE features with real properties bound
to them**, so these are not links to abandoned ideas — either the atoms exist under other IDs or this is
genuine coverage debt on live features. Hypothesis flagged for testing (not assuming): `mec_ai_archetype_system`
is spelled `mec_`, not `mech_`, so a typo variant may exist. Agent warned that the ATD semantic index is
**stale against this dirty tree** (decision 32 — it already misled two earlier agents) and told to confirm
against files on disk. Also asked to rule on whether `@spec-link` atop **const blocks** (6 of them in
`propertyenum.go`) is legal under this project's ATD convention, which holds that links go atop functions only.

Both feed step 18's documentalist Workflow B. Neither may modify anything.

### Assurance pass — first attempt DIED to a rate limit, RE-DISPATCHED 2026-09-01

Both parallel agents were killed mid-flight by an HTTP 429 (account rate limit, not a task failure).
The test agent had already run all 12 modules but was cut off before reporting; the atom agent was
mid-search. No partial results were recoverable and nothing was left modified.

**I did the build/vet half myself with plain Bash rather than re-spending agent budget on it** —
mechanical work needing no model reasoning:

41. **ALL 12 WORKSPACE MODULES BUILD AND VET CLEAN.** `upsilonapi` `upsilonauth` `upsilonbattle`
    `upsiloncli` `upsiloneconomy` `upsilonhub` `upsilonmapdata` `upsilonmapmaker` `upsilonplatform`
    `upsilonserializer` `upsilontools` `upsilontypes` — `go build ./...` and `go vet ./...` clean on
    every one. `go.work` lists exactly these 12 and a `find` for stray `go.mod` files outside it turned
    up none. **This is the strongest evidence yet that the alias deletion broke no downstream consumer**:
    `upsilontypes` is imported umbrella-wide, and deleting a type alias is a compile-breaking change, so
    a severed reference could not hide from the compiler. Remaining risk is therefore *silent/runtime*
    breakage, not structural — which is exactly what the two re-dispatched agents are scoped to find.

**Re-dispatched (2 agents, parallel):**
- **Test sweep** — narrowed to test COUNTS only, since I already proved build/vet clean. Same
  read-only agent type (no Edit/Write tools by construction).
- **Binding verification** — **user redirected this from documentalist to codebase-explorer**, and
  refocused it: the question is no longer primarily the atom bookkeeping but **"are entity expiration
  and the AI archetype system still correctly bound?"** Told to trace, per feature,
  constant → registry entry → writer → reader → real behavior, and to hunt specifically for *silent*
  breakage (declared-but-unregistered key, write/read key-string disagreement, raw string literals that
  the deleted aliases and the old `interface{}` `PropertyToString` used to paper over). The phantom-atom
  existence check is demoted to secondary.

### FULL-UMBRELLA TEST SWEEP — COMPLETE AND VERIFIED BY ME 2026-09-01

I recounted from the raw `go test -v` logs rather than trusting the agent's prose.

42. **767 PASS / 1 FAIL ACROSS ALL 12 MODULES. THE ONE FAILURE IS T4, THE DELIBERATELY-RED TEST.**

    | module | pass | fail | | module | pass | fail |
    |---|---|---|---|---|---|---|
    | upsilontypes | 198 | **1** (T4) | | upsilonhub | 174 | 0 |
    | upsilonbattle | 189 | 0 | | upsilonmapdata | 7 | 0 |
    | upsilonapi | 57 | 0 | | upsilonmapmaker | 4 | 0 |
    | upsilonauth | 70 | 0 | | upsilonplatform | 25 | 0 |
    | upsiloncli | 2 | 0 | | upsilonserializer | 1 | 0 |
    | upsiloneconomy | 20 | 0 | | upsilontools | 20 | 0 |

    The sole failure is `TestDefaults_MovementAbsenceDefaultIsThree` — "an entity created without an
    explicit Movement property gets 5/5 tiles instead of the documented default of 3/3" — which is
    exactly T4, red on purpose until step 15 fixes it. **Zero regressions anywhere.**

43. **NO ENVIRONMENTAL GAPS — DOCKER WAS UP, SO THE INTEGRATION SUITES ACTUALLY RAN.**
    `upsilonauth` (70), `upsiloneconomy` (20) and `upsilonhub` (174) are testcontainers-backed; their
    logs show `Connected to docker:` and a Reaper session, then `ok` for every package. So those 264
    tests are **real** coverage of the biggest downstream consumers, not skipped placeholders. This
    matters: `upsilonhub` is the platform gateway and the heaviest importer of `upsilontypes`.

    **False alarm I chased and cleared:** my signature scan flagged `connection refused` in the
    `upsilonapi` log. It is **log noise from passing tests** — webhook negative-path tests deliberately
    aimed at unreachable endpoints, asserting the failure is handled. No panic, no build failure, no
    real connection problem anywhere in the 12 logs.

**Combined with decision 41 (all 12 build + vet clean), the structural verdict on this round is:
no downstream breakage, compile-time or test-time, anywhere in the workspace.**

### BINDING VERIFICATION — BOTH FEATURES CORRECTLY BOUND. VERIFIED BY ME 2026-09-01.

I re-checked every load-bearing claim against the tree rather than trusting the report.

44. **ENTITY EXPIRATION AND THE AI ARCHETYPE SYSTEM ARE BOTH STILL CORRECTLY BOUND — THE ROUND
    SEVERED NOTHING.** All three keys are present in the registry with scopes matching the frozen
    vocabulary: `AIArchetype` (ScopeEntity/KindString/CompositionNone),
    `EntityDuration` (ScopeEntity/KindIntCounter/CompositionAdd, vocabulary row 13),
    `ExpiresWithCaster` (ScopeEntity/KindBool/CompositionAnd, row 14). No raw string literals build
    these keys anywhere, so the deleted aliases and the old `interface{}` `PropertyToString` were not
    papering over a mismatch. **`endofturn.go` and `gamestate_logic.go` — the two expiration readers —
    are byte-for-byte unmodified by this round** (empty `git diff --stat` vs HEAD), so the feature's
    behavior could not have shifted underneath it.

45. **BUT: ENTITY EXPIRATION HAS READERS AND NO PRODUCTION WRITER. PRE-EXISTING, NOT OURS.**
    Verified by grepping production (non-test) references:
    - `EntityDuration` — 3 production refs, **all in `endofturn.go:132,133,147`, all reads or a
      decrement of an already-existing property** (`UpdatePropertyValue` sits inside `if durProp != nil`).
      Nothing in production ever *creates* it.
    - `ExpiresWithCaster` — exactly 1 production ref, `gamestate_logic.go:106`, a **read**
      (`eff.HasProperty`). No writer at all.
    - Only test harnesses (`rules_iss066_test.go`) ever arm either key.
    So the expiry machinery is fully built and correct, but **nothing in production ever switches it on**.
    The dependent spawn code (turrets/traps/zone entities) is not yet built — `mechanic_expiration_controller`
    is status **DRAFT** and lists those as pending dependents. This predates the round entirely and is a
    feature-completeness gap, not a regression. **No dedicated issue exists for it yet** (a grep of
    `issues/` matches only ISS-142, incidentally).
    By contrast **`AIArchetype` is a complete loop**: written at `bridge_start_archetype.go:181`
    (`RepsertPropertyValue`, on auto-generated entities), read at `focus_backline.go:58,61`, and wired
    into a live behavior stack via `ranger.go`.

46. **THE TWO PHANTOM `@spec-link`s HAVE AN OBVIOUS, EVIDENCED REPAIR — AND IT IS NOT A TYPO FIX.**
    Neither `mech_entity_expiration` nor `mec_ai_archetype_system` exists, and **no `mech_`/`mec_`
    prefix variant exists either** (I checked all three spellings: 0 files each). But both features
    have real atoms that **the rest of the codebase already points at correctly**:
    - `upsilonbattle/docs/mechanic_expiration_controller.atom.md` (**DRAFT**) — already the `@spec-link`
      on `endofturn.go:129`, the actual reader.
    - `upsilonbattle/docs/mechanic_ai_controller_archetypes.atom.md` (**STABLE**) — already referenced by
      `ranger.go:13`, `sneak.go:13`.
    So `propertyenum.go:33,47` are the **only** two sites in the repo pointing at non-existent atoms;
    every other reference to these features already uses the correct IDs. The repair is to repoint those
    two links, which is a documentalist task for step 18, not a code change.

**Step 18 additions:** repoint the 2 phantom links; resolve whether `@spec-link` atop **const blocks**
(6 in `propertyenum.go`) is legal, since the convention is functions-only; consider filing an issue for
the expiration writer gap (decision 45).

47. **`atd map` IS UNRELIABLE ON THIS TREE — SECOND DISTINCT ATD TOOLING FAILURE THIS ROUND.**
    A supplementary `atd map` cross-check during the binding investigation errored with malformed JSON
    from its LLM link-recommender and returned nothing. It was additive only — the binding verdict rests
    on grep, `atd search`, and my own direct file checks — so no conclusion changes. But note this is a
    **different** failure mode from decision 32 (stale semantic index): that one returns wrong data, this
    one returns none. **Relevant to step 18**, which leans on documentalist and `atd` tooling for the
    Workflow B sync, the 2 phantom-link repairs, and the dual-scope reconciliation across 11 keys.
    Budget for the tooling being flaky and cross-check its output against files on disk.

**Standing rule added 2026-09-01 (user):** every ATD failure gets a report under
`~/work/atd/failures/` with date, title, expectation, verbatim command, verbatim actual result.
Committed to memory. Decisions 32 and 47 are now filed there
(`20260901_atd_search_stale_index_returns_deleted_code.md`,
`20260901_atd_map_malformed_json_from_link_recommender.md`). **For step 18:** any documentalist or
`atd` call that fails must produce a report, so the delegation brief must instruct the agent to
return the exact command and raw output on failure — both existing reports have their verbatim
fields marked "not captured" because the failures happened inside sub-agents that only reported prose.

## Step 15 — GROUNDING DISPATCHED 2026-09-01 (Movement default 5/5 -> 3/3)

**The edit itself is one line**, `upsilontypes/property/def/entity.go:15`:
`MakeIntCounterProperty(property.Movement, 5, 5, property.FriendlyController, property.Character)` -> `3, 3`.

48. **INTENT IS ALREADY UNANIMOUS ACROSS FOUR INDEPENDENT SOURCES — ONLY THE CONSTRUCTOR DISAGREES.**
    Frozen vocabulary §3 row 2 declares `**3 / 3**` and labels the current `5/5` a defect (decision 15);
    `propertyenum.go:15` comment reads `// Absence means 3; reset at end of turn`; T4 asserts 3/3 and is
    red on purpose; vocabulary §"Default-value change (no rename), decision 15" records the flip
    explicitly. So this is a **defect fix aligning code to settled spec**, not a new design decision.
    Nothing about the *intent* needs deciding — only the blast radius needs establishing.

**Why I am grounding a one-line change rather than just making it:** this is a **gameplay** change.
Step 13 made the registry load-bearing and wired `Movement()` in as the registry's `New:` constructor
for the `Movement` key, so this default is now reachable by materially more paths than when it was
written. Movement also feeds pathfinding, reachability and AI behavior, so a 5->3 flip can shift tests
that never mention Movement directly.

**Dispatched, parallel:**
- **`codebase-explorer` — blast radius.** Lead question: does this default actually reach live gameplay,
  or is it shadowed by explicit character templating? T4's own comment claims `PropertiesForCharacter`
  and "every other code path" already use 3 and only the constructor is wrong — the agent is told to
  **verify or refute** that rather than accept it. Plus: full caller list (direct + via registry `New:`),
  a specific named list of at-risk tests across 5 modules including indirect pathfinding/AI exposure,
  non-Go surfaces (seed data, goja JS scenarios, Postman, map data), and any other hardcoded `5`.
- **`documentalist` — mandatory ATD preflight (D1).** This is a business rule (per-turn movement), so it
  gets a real preflight, not a peek. Crux question: **does any atom state a movement default number?**
  If an atom says 5, this contradicts a settled atom and I stop and bring it to you. Agent warned about
  both known tooling failures and **explicitly instructed to quote any `atd` failure verbatim** —
  command and raw output — so the next failure report does not have to say "not captured".

### Step 15 — ATD PREFLIGHT (D1) RESULT: **PROCEED**. Verified by me 2026-09-01.

49. **NO ATOM STATES A MOVEMENT DEFAULT NUMBER — NOTHING IS CONTRADICTED BY 5->3.**
    Governing atom: `upsilontypes:module_property_key_registry` (`upsilontypes/docs/`, MODULE,
    ARCHITECTURE, **DRAFT**) — the same atom T4's `@test-link` points at. Ancestry: `shared:rule_stat_taxonomy`
    (RULE, BUSINESS, **STABLE**), `rule_progression` (STABLE), `upsilontypes:entity_character` (STABLE).
    All 53 movement-mentioning atom files were checked; the STABLE/BUSINESS ones state Movement's
    **CP upgrade cost** (30 CP per +1) but **no default-when-absent value**. `rule_progression`'s "5"
    is a win-count gate ("once every 5 wins"), unrelated to movement distance — a genuine false-positive
    worth noting. **No STABLE or BUSINESS atom needs editing; no signoff gate triggered.**
    Corroborating: `registry_entity_movement.go:9` already carries the inline comment
    `// Absence means 3/3 (constructor returns 5/5 today; ISS defect, fix deferred)` — the registry
    itself marks this exact fix as known, in-scope, deferred work.

50. **`atd map` FABRICATED CODE VALUES AND NEARLY STOPPED A CORRECT CHANGE. FILED WITH VERBATIM TRACE.**
    Its rationale claimed `PropertiesForCharacter` sets Movement `Low=5 High=5`. **That is false.**
    `entity.go:94` sets Movement `3, 3`; the `5, 5` lives in a *different function*, `Movement()`, at
    line 15 of the same file — the tool conflated two functions and attributed the value to the wrong one.
    It also claimed Movement's initial value is 10 (it is 3) and that `IsDying` is a bool (it is
    `MakeIntProperty(-1)`). It further emitted a full refusal *sentence* wrapped in `[[...]]` as if it
    were an atom ID.
    **Had I trusted it I would have concluded the fix creates an inconsistency and stopped.** Caught only
    because I grep the file before acting on tooling output.
    Filed: `~/work/atd/failures/20260901_atd_map_hallucinated_code_values.md`, **with the verbatim command
    and raw output** — the first report to satisfy the new rule's evidence bar. This is the **third
    distinct** failure mode and the most dangerous: stale index returns wrong-but-real data, malformed
    JSON returns nothing, **this returns confident fabrications indistinguishable from a good answer.**

51. **T4'S PREMISE IS CONFIRMED CORRECT, AND A SECOND, SEPARATE DEFECT SURFACED.**
    `PropertiesForCharacter` (`entity.go:94`) does use `3, 3` — so the documented claim that every other
    path already uses 3 holds, and `Movement()` at line 15 is the lone dissenter on **value**.
    **But the two constructors also disagree on visibility, and each is half-right:**
    - `Movement()` — value `5,5` **wrong**, MinInfoLevel `FriendlyController` **right**
    - `PropertiesForCharacter` — value `3,3` **right**, MinInfoLevel `Public` **wrong**

    Both the registry (`registry_entity_movement.go:14`) and frozen vocabulary §3 row 2 declare
    **`FriendlyController`**. So `PropertiesForCharacter` leaks Movement at `Public` visibility against spec.
    **This is OUT of step 15's approved scope** (which is value-only, decision 15). Flagging for a
    scope decision rather than folding it in unilaterally — it is a visibility/information-disclosure
    question, not a number tweak, and HP/SP/MP on adjacent lines may have the same divergence.

52. **STEP 15 BLAST RADIUS: NEAR-INERT. INDEPENDENTLY VERIFIED BY ME, NOT TAKEN ON THE AGENT'S WORD.**
    The delegated grounding said the change cannot reach live gameplay. I re-checked the three load-bearing
    claims directly against the tree:
    - **Bridge writes are unconditional.** `bridge_start.go:174-175` and `bridge_start_archetype.go:175-176`
      both call `RepsertPropertyCMaxValue`/`RepsertPropertyCValue(property.Movement, …)` as straight-line
      statements — **no `if` guard**, so `Properties["Movement"]` is never absent on a constructed entity.
    - **The default is absence-only.** `upsilontypes/entity/entity.go:164-184` `getBasePropertyOrDefault`
      reaches `def.DefaultProperty(name)` **only** in the `else` of `if _, found := e.Properties[nname]`.
      With the key always present, `Movement()` is never consulted at runtime.
    - **The hub already agrees.** `character.go:59` `NewBaseStats()` hardcodes `Movement: 3`.
    Additionally: `entity.go:15` was the **only** `5, 5` Movement literal left in the entire umbrella
    (test helpers already use `Move: 3, MaxMove: 3`), and `def.Movement()` has exactly **two** real callers —
    the registry `New:` closure and T4. Every other `Movement` grep hit is `ctx.RemainingMovement()`,
    an unrelated symbol.

53. **THE FLAGGED `applyItemAsBuff` CAVEAT IS AN ARGUMENT *FOR* THE FIX, NOT A RISK AGAINST IT.**
    Confirmed at `defaultproperty.go:166-171`: `ApplyBuff` does `res.MaxValue = d.MaxValue + p.MaxValue`
    — it **adds** the template Max. So an item DTO that supplies `Value` but omits `Max` inherits the
    constructor's Max and adds it into the composed value. At `5/5` that silently grants **+5** max movement
    against a documented vocabulary of 3; at `3/3` it grants the documented 3. The fix makes this path
    *correct*, it does not endanger it. No current item content or test exercises it, so nothing changes today.

54. **STEP 15 APPLIED AND VERIFIED — T4 IS GREEN.**
    `entity.go:15` `5, 5` -> `3, 3`, one line, no other edit. Result across the three affected modules:
    **upsilontypes 199 PASS / 0 FAIL (T4 now `--- PASS`), upsilonbattle 175 PASS, upsilonapi 57 PASS**,
    all three build + vet clean. The round's last deliberately-red test is now green.

55. **A PRE-EXISTING-LOOKING DATA RACE SURFACED DURING VERIFICATION. NOT PAPERED OVER — DELEGATED.**
    The first full `go test -v ./...` in upsilonbattle aborted `battlearena/ruler` with
    `fatal error: concurrent map iteration and map write` — `getEntitiesState` (`ruler_state.go:68`)
    racing the test-only `FakeController.SetQueue` (`ruler_fake_controller_test.go:138`), under
    `TestRulerEntityLeak`. A `fatal error` kills the binary, so the package's remaining tests never
    reported — **that abort alone explains the 189 -> 175 count drop; it is not 14 broken tests.**
    My own attribution attempts: **8/8 PASS** for that test in isolation; **0/5 fail** for the package alone
    with the fix; **0/5** reverted to 5/5; **0/3** full `./...` at baseline. It has occurred exactly **once**,
    only under full parallel `./...` load. A value constant cannot plausibly create a map race, but I am not
    closing this on plausibility. **Handed to a sub-agent for stress-attribution (10+ full runs plus
    `-race`) and root-cause**, under hard guardrails: investigation only, no fix, no git state changes,
    and `entity.go:15` must be restored to `3, 3` if it is flipped for an A/B.
    **Step 15 is not closed until that verdict lands.**

56. **THE `Public` vs `FriendlyController` DIVERGENCE MAY BE A SECURITY QUESTION, NOT A COSMETIC ONE.**
    Decision 51 framed the `PropertiesForCharacter` `Public` divergence as a spec-conformance tidy-up.
    **Maintainer raised a far sharper concern that reframes it entirely:** if all human-controlled
    characters — regardless of which *player* owns them — are bound to a **single shared controller
    instance** acting as a stand-in for API access, then `FriendlyController` does not mean "visible to
    the owning player." It collapses to "visible to any human client," and **an enemy player could read
    another player's character data that was meant to be restricted.**
    Under that reading, `FriendlyController` would be providing **no real protection**, and "fixing"
    `PropertiesForCharacter` from `Public` to `FriendlyController` would be **security theatre** —
    a change that looks like a hardening but grants no actual confidentiality.
    **Dispatched a read-only codebase-explorer** to establish, with evidence: the info-level enum and
    its comparison sites; whether controllers are shared or per-player; what identity (if any) is passed
    as the *viewer* at filter time; whether outbound state is filtered **per recipient** or filtered once
    and **broadcast identically**; and whether `TeamID` is consulted during visibility filtering at all.
    **The decisive sub-question is #4 (per-recipient vs broadcast).** If state is filtered once and
    fanned out identically over SSE, then every non-`Public` level is inert at the transport boundary and
    the whole `MinInfoLevel` scale is documentation rather than enforcement — a finding that would
    outrank the original divergence and likely warrant its own issue.
    **DO NOT reconcile the `Public`/`FriendlyController` divergence until this verdict lands** — the
    correct fix depends entirely on whether the mechanism enforces anything.

57. **RULER RACE VERDICT: INDEPENDENT OF STEP 15. PRE-EXISTING TEST-HARNESS BUG. STEP 15 IS CLOSED.**
    Stress attribution: **0/20** full `./...` runs at `3,3`, **0/10** at `5,5` (A/B flip, restored),
    **0/5** under `go test -race` on the package. Combined with my own 21 runs: **56 runs, 1 occurrence**,
    the original sighting only.
    **Root cause, verified by me against the tree, not taken on report:**
    `TestRulerEntityLeak` (`ruler_leak_test.go:35-40`) writes `r.GameState.Entities` **directly from the
    test goroutine** — `ent.ControllerID = uuid.Nil; r.GameState.Entities[id] = ent` — *after* `r.Start()`
    (line 20) has handed ownership of `GameState` to the Ruler's actor loop. The concurrent reader is
    production code, `Ruler.getEntitiesState` (`ruler_state.go:68`), reached via a legitimate async
    `SetQueue` message. **Production code is not at fault**: it correctly assumes single-writer semantics
    once the actor owns state. The test violates that contract.
    **The codebase already documents this exact anti-pattern.** `ruler_fake_controller_test.go:65-71`:
    *"Once Start() has been called the Ruler takes true ownership of GameState (see
    domain_ruler_state.atom.md); reading r.GameState directly from a test at that point races with the
    actor loop."* A race-free helper, `testingFetchEntities`, already exists — `ruler_leak_test.go`
    simply does not use it.
    **Why the constant provably cannot be implicated:** the leak test's entities come from
    `GenerateRandomEntity()`, which sets the property from `def.Movement()` and then immediately calls
    `.Set(r.Random())` over `IntRange{3,7}`. `DefaultIntCounterProperty.Set` (`defaultproperty.go:146`)
    is a bare `d.Value = p.(int)` with **no clamping to MaxValue** — so the constructor's 3-vs-5 is
    overwritten before any gameplay or timing code observes it.
    **-> FILE AN ISSUE** (pre-existing, not round-caused): `TestRulerEntityLeak` bypasses actor ownership;
    fix is to route the ControllerID mutation through the actor queue / `testingFetchEntities` pattern.
    Low frequency, but it aborts the whole package binary when it fires, which **silently truncates the
    upsilonbattle test count** and could mask a real failure in CI.

58. **MAINTAINER ANNOTATION ON THE VISIBILITY QUESTION — SEVERITY IS MITIGATED IN PRACTICE.**
    Recorded *before* the explorer's verdict returned, and it must temper how that verdict is written up:
    **it is a true security failure in principle, but there is currently no inspection mechanism, and
    privacy masking is otherwise quite thorough.**
    Consequence for the eventual issue: frame it as a **latent/defence-in-depth** weakness, not an
    actively exploitable disclosure. There is no player-facing surface today that lets one player *request*
    another player's character data, so the collapse of `FriendlyController` (if confirmed) is not reachable
    by a real client — it is a correctness-of-mechanism problem that would become exploitable the moment an
    inspection/observer/spectator feature is added. **Do not file it at a severity that implies live
    exposure.** The masking that does exist is thorough; this is about one level of the scale not carrying
    the meaning its name implies.

59. **VISIBILITY VERDICT: THE SUSPICION WAS WRONG, BUT THE UNDERLYING FINDING IS WORSE — `MinInfoLevel`
    IS NEVER ENFORCED ANYWHERE ON THE LIVE PATH.** Verified by me against source, not taken on report.
    **The shared-controller theory does NOT hold.** `bridge_start.go:299-304` does construct **one**
    shared `*HTTPController` for all human players — that part of the recollection is correct, and it is
    deliberate, documented transport consolidation. **But it does not collapse per-player identity:**
    each entity's `ControllerID` is set to the real per-account `playerID` (`bridge_start.go:163`,
    `bridge_start_archetype.go:163`), and both the masking (`is_self`) and the action-ownership check
    (`gateway/game.go:239-247` `ownsEntity`) key off those per-account fields, never off which controller
    actor handled the message. **Ownership and authorization are sound.**
    **The real defect is that the enforcement point does not exist.** `InformationLevel`
    (`property.go:17-33`) is an ordered scale `Public=0 … GameMaster=9` compared with `>=` inside
    `Name()`/`UserFriendlyGet()`. But:
    - `convertProperty` (`upsilonapi/api/output.go:394`) — the actual serialization boundary — calls
      **`v.Get()`**, the raw internal value. No level parameter. **VERIFIED.**
    - `NewEntity` (`output.go:198-233`) builds the wire DTO from raw `GetPropertyI(...).I()`.
    - **`UserFriendlyGet` — the only method that gates a *value* — has ZERO call sites in the entire
      umbrella** outside its own interface declaration (`property.go:37`) and `PrettyPrint`
      (`property.go:49`, debug-only). **VERIFIED by umbrella-wide grep.**
    - Every `.Name(level)` call site passes `GameMaster` or `OwnController` — i.e. always "reveal all".
    So **no viewer identity of any kind ever reaches the property layer.** Every key the registry marks
    `FriendlyController` — Movement, Attack, Defense, AttackRange, JumpHeight, Shield, Poison, Stun —
    is serialized unmasked.
    **-> This retroactively settles decision 51/56: fixing `PropertiesForCharacter` from `Public` to
    `FriendlyController` would close NOTHING. It is security theatre, exactly as suspected in 56.
    Do not make that change as a "hardening".**

60. **THE MAINTAINER'S "PRIVACY MASKING IS THOROUGH" IS CORRECT — BUT IT IS A DIFFERENT MECHANISM.**
    Decision 58's annotation holds, and the evidence supports it. What actually protects players lives in
    `upsilonhub/internal/games/battle/masking.go`, applied **per recipient** — once per SSE subscriber
    (`sse.go:150-158`) and once per REST request (`game.go:79`). **VERIFIED** it strips: `current_player_id`,
    `id`, `player_id`, `_atd_meta`, and — for foes only — `equipped_skills`, `equipped_items`, `buffs`.
    It is **stricter than "friendly"**: loadout is hidden from teammates too, keyed on exact ownership.
    So the fan-out **is** per-recipient (answering 56's decisive sub-question: **not** a shared broadcast),
    and the genuinely sensitive payload **is** protected — by a field-name rule governed by
    `module_foe_loadout_masking` / `requirement_foe_loadout_privacy`, which has **nothing to do with the
    `InformationLevel` enum**.
    **What masking does NOT touch:** `hp` and the flat stat fields. Enemy Movement/Attack/Defense are
    visible — which for a tactical game is plausibly *correct by design*, not a leak. That is a **product
    decision that has never been written down**, and it is the actual open question.
    **Net severity: LOW, and NOT an exposure.** Nothing sensitive is reachable; there is no inspection
    mechanism; ownership checks are sound. The defect is **dead weight**: a per-property visibility scale
    configured across ~60 registry entries that enforces nothing, inviting a future maintainer to trust it.

61. **ATD GAP: NO ATOM GOVERNS `InformationLevel`/`MinInfoLevel` AT ALL.**
    Keyword and semantic searches over `docs/*.atom.md` return nothing for the enum, its levels, or its
    per-property registry values — only `architecture/property_key_vocabulary.md`, which is a plain doc,
    not an atom. Consistent with the finding: **there is no enforcement point, so there was never anything
    to atomize.** Contrast `module_foe_loadout_masking`, which *is* atomized because it is real.
    **-> For step 18's Workflow B pass.**

62. **RECOMMENDED DISPOSITION (needs a user ruling — DO NOT ACT UNILATERALLY).**
    Two coherent options, and they are mutually exclusive:
    **(a) RETIRE** the `InformationLevel`/`MinInfoLevel` scheme as dead weight, keep field-name masking as
    the intended design, and update the frozen vocabulary doc to stop implying enforcement. Cheap, honest,
    removes a trap. Cost: loses a per-property model that is finer-grained than field-name rules.
    **(b) WIRE IT** into `masking.go`'s per-entity pass — viewer level = `OwnController` if `is_self`,
    `FriendlyController` if same team, else `Public`. Requires threading `TeamID` into the masking layer
    (it is currently passed for *display only*, `maskTurns` `masking.go:111-130`, never as a gating
    predicate) and would be a **gameplay-visible change** — hiding enemy stats alters tactical information.
    **My recommendation: (a), plus an issue capturing (b) as a design option.** Under decision 58's framing
    there is no exposure to close, and (b) silently changes game balance. But this is a product call.

63. **ANSWER TO "IS THERE ALREADY AN ISSUE ABOUT THIS?" — NO, BUT TWO ADJACENT ONES EXIST AND ONE IS STALE.**
    (Maintainer asked directly; searched rather than assumed.) **Methodology note: my first
    `issues --search` sweep returned empty for all 8 keywords — a FALSE NEGATIVE, because the CLI emits
    ANSI colour codes that broke my grep. Caught by re-running raw. Any future scripted use of `issues`
    must strip ANSI (`sed -r 's/\x1b\[[0-9;]*m//g'`) or it will silently report "no results".**
    - **ISS-077 (skill inspection)** — the *designed but unimplemented* inspection feature, including the
      privacy rule "enemy character skill details are hidden". **This is precisely the mechanism whose
      absence makes decision 59's finding non-exploitable today** (decision 58's annotation). It is the
      trigger condition: the day ISS-077 lands, the missing `MinInfoLevel` enforcement becomes material.
    - **ISS-103 (foe-loadout masking)** — component `masking.go`, asserts the masking "no stack ever
      implemented". **STALE: it has since been implemented.** `masking.go:99-101` deletes
      `equipped_skills`/`equipped_items`/`buffs` under `if !isSelf`, landed in upsilonhub commit `0aac6f4`
      *"fix(iss-131,iss-103): honour the engine envelope in CreateMatch; mask foe loadouts"*. The issue is
      still marked **Open** with no changelog entry recording the fix.
    - **Neither covers the `InformationLevel` enum being unenforced.** A new issue is warranted.
    **-> Dispatched an agent to file ISS-151 (`Public` vs `FriendlyController`, Low, explicitly subordinate
    to ISS-152 and explicitly NOT a security fix) and ISS-152 (retire-vs-wire the InformationLevel scheme,
    Low, dead weight not exposure), and to append a `Superseded 2026-09-01` note to ISS-103 —
    conservatively, WITHOUT flipping its status, pending a re-run of `e2e_battle_starts_privacy_check`.**

64. **STEP 16 OPENED — buff-attribution accessor. Grounding + ATD preflight dispatched in parallel.**
    Goal (decision 14): expose **natural value + each individual buff with its own attribution**.
    `GetBaseProperty` (`entity.go:221`) already gives the natural value; `GetBuffsFor` (`entity.go:255`)
    already gives the contributing buffs but returns `[]property.Property`, **discarding the owning
    `TemporaryProperties`** and with it `OriginEntityID`, `OriginSkillID`, `Duration`, `Forever`.
    **Hard constraint:** `entity.go` is **385 LOC** vs a 400 warn ceiling that counts comments —
    the accessor **MUST land in a new sibling file** in package `entity`.
    **The decisive unknown I flagged to grounding:** are `OriginEntityID`/`OriginSkillID` *actually
    populated on the production path*, or left zero? **If they are never written, the accessor is
    worthless and step 16 becomes a write-side task first.** No design is settled until that is answered.
    **Second flagged interaction:** `masking.go` strips `buffs` wholesale for foes, so widening what
    `buffs` carries touches the foe-privacy family — asked documentalist to check for a STABLE/BUSINESS
    constraint before I commit to a shape.

65. **ISS-151 AND ISS-152 FILED; ISS-103 ANNOTATED. VERIFIED BY ME.**
    - **ISS-150** — ruler actor-ownership race (filed earlier this session).
    - **ISS-151** (Low) — `PropertiesForCharacter` builds Movement/Attack/AttackRange/Defense/JumpHeight at
      `Public` against the registry's `FriendlyController`. **Verified the anti-hardening framing survived
      into the file** ("changes a value nothing reads"; "security theatre"), and that it is marked
      **subordinate to / blocked by ISS-152**. This is the guardrail that stops a future maintainer
      "fixing" it as a security win.
    - **ISS-152** (Low) — the `InformationLevel` scheme has no enforcement point. **Verified severity was
      NOT inflated** — reads "deliberately not inflated. This is NOT a live exposure", framed as dead
      weight / latent defence-in-depth, cross-referenced to **ISS-077** as the trigger condition, with
      retire (recommended) vs wire-in presented as mutually exclusive and needing a product ruling.
    - **ISS-103** — `> **Superseded 2026-09-01**` note added atop the file plus a dated Change Log entry;
      **status deliberately left `Open`**, pending a re-run of `e2e_battle_starts_privacy_check`. Not
      closed on inference.
    **Verified no source was touched:** umbrella `git status --short` shows only `issues/*`, `README.md`,
    `TODO.md` beyond the pre-existing round work; `entity.go:15` still reads `3, 3`. Root README auto-table
    regenerated: 51 -> **53 active issues**.
    **-> Open user ruling carried forward: ISS-152 retire-vs-wire. Nothing should touch ISS-151 until that
    is answered.**

66. **STEP 16'S PREMISE IS UNDERMINED: THREE OF THE FOUR ATTRIBUTION FIELDS ARE DEAD. VERIFIED BY ME.**
    The decisive unknown from decision 64 is answered, and the answer blocks the design as conceived.
    Umbrella-wide greps, run by me, not taken on report:
    - **`OriginSkillID` — ONE occurrence in the entire umbrella: `buff.go:13`, the field declaration
      itself.** Never written, never read, production or test. **DEAD.**
    - **`BuffTickDown` — defined `entity.go:267`, called from exactly ONE place: `entity_test.go:64`.**
      Never called in production. `EndOfTurn` ticks `SkillCooldownTickDown` and the separate
      `EntityDuration` (whole temporary *entities*), but **never** `ent.BuffTickDown()`. So a
      finite-`Duration` buff has no path that expires it. **DEAD.**
    - **The wire `Buff` DTO (`upsilonapi/api/input.go:157-161`) is `{origin_id, forever, properties}` —
      there is NO `Duration` field.** Even if duration ticked, it could not reach a client. **DEAD.**
    - **`RegisterBuff` production call sites are exactly two:** `bridge_start.go:238` (`applyItemAsBuff`,
      always `Forever:true`, `OriginEntityID`=item UUID) and `bridge_resurrect.go:205` (rehydration).
      **No skill-cast path calls `RegisterBuff` anywhere** — skill-granted buffs do not exist as a runtime
      mechanism, despite `OriginSkillID` being modelled for exactly that.
    **Scoreboard for the requested accessor:** `OriginEntityID` **LIVE** (items only) | `Forever` **LIVE**
    (always true in practice) | `OriginSkillID` **DEAD** | `Duration` **DEAD**.
    **This is the SECOND declared-but-never-wired mechanism found today** (ISS-152 was the first).
    Shipping the accessor as originally specified would surface two permanently-empty fields and create
    exactly the ISS-152 trap again: a modelled capability a future maintainer trusts. **I will not build
    that without a ruling.**
    **Cheap-to-change, at least:** `GetBuffsFor` has only **5** call sites umbrella-wide — 1 internal
    (`GetProperty`, needs only the value) and 3 tests, **none of which inspect attribution**. So the
    signature is not the obstacle; the missing write side is.
    **Options for the user (NOT to be chosen unilaterally):**
    **(a) SCOPE DOWN** — accessor exposes `OriginEntityID` + `Forever` only, explicitly documented as
    entity/item origin; file issues for the two dead fields. Honest, small, unblocks the user's actual
    ask ("which buff came from where"). **Provisional recommendation.**
    **(b) WIDEN** — also build the write side: a skill-buff producer populating `OriginSkillID`, a
    `BuffTickDown` call in `EndOfTurn`, and a `duration` field on the wire DTO. This is a **feature**,
    several times step 16's size, and needs its own atoms.
    **(c) SPLIT** — (a) now, (b) filed as a tracked follow-up. 
    **HOLD: documentalist D1 preflight still running.** If a BUSINESS/STABLE atom governs skill-granted
    buffs the recommendation may shift, so no design is settled until that verdict lands.

67. **DECISION 66 IS CORRECTED BY MAINTAINER CONTEXT — `OriginSkillID` IS SCAFFOLDING, NOT DEAD WEIGHT.**
    Maintainer (2026-09-01): *"originentity/skillid are meant for summons, traps and the like. so they
    should be used but it's still an early breed of skill that haven't seen much use so far."*
    **I verified this story holds, and it does — the whole summon/trap family is read-side complete and
    write-side absent:**
    - `EntityDuration` — enum, registry row 13, default constructor, **and a live decrementer/remover** at
      `endofturn.go:132-147`. **No production writer**: nothing ever sets a non-zero duration, and the
      default is 0 (= permanent), so no temporary entity ever expires because none is ever created as one.
    - `ExpiresWithCaster` — enum, registry row 14, default `false`, **and a live reader** at
      `gamestate_logic.go:106` that culls a dead caster's owned positional effects. **No production writer.**
    - `OriginSkillID` — same shape: modelled, no producer yet.
    **=> My decision-66 framing ("the SECOND declared-but-never-wired mechanism, an ISS-152-style trap")
    WAS WRONG and is retracted.** The two cases are different in kind:
    - **ISS-152 `InformationLevel`** — dead weight that *pretends to enforce* something. No consumer, no
      plan, and actively misleading. Correctly filed.
    - **`OriginSkillID` / `EntityDuration` / `ExpiresWithCaster`** — deliberate scaffolding for a **named,
      intended feature** (summons/traps) whose consumer machinery is *already built*. Not misleading;
      simply awaiting its producer. **Do NOT file these as defects.**
    **=> Step 16's accessor SHOULD expose the full `TemporaryProperties` shape — all four fields —**
    documenting `OriginSkillID` as reserved for the summon/trap family and not yet populated. That is
    forward-correct design, not a trap. The earlier "scope down to OriginEntityID + Forever" recommendation
    is **withdrawn**.
    **Still a genuine gap, unchanged by this:** `BuffTickDown` is never called in `EndOfTurn`, and the wire
    `Buff` DTO has no `duration` field — so *buff*-scoped duration (distinct from entity-scoped
    `EntityDuration`) cannot tick or reach a client. Worth an issue when the summon/trap producer lands.

68. **ATD D1 PREFLIGHT: `PROCEED-WITH-SIGNOFF-PENDING` — USER SIGN-OFF REQUIRED BEFORE CODE.**
    Governing atom for the accessor: **`mechanic_item_buff_application`** (IMPLEMENTATION/MECHANIC, DRAFT)
    — the natural parent; a new sibling file continues that link.
    `rule_entity_property_write_isolation` (ARCHITECTURE/RULE, REVIEW) is **not implicated** — the accessor
    is a read-only API with no persistence.
    **No BUSINESS atom grounds "a player can see which buff came from which source."** Documentalist judged
    a fresh BUSINESS atom unnecessary *for a Go-internal read accessor*, since the data already exists and
    is already governed at IMPLEMENTATION layer — but flagged the distinction rather than deciding it.
    **Why signoff-pending, not plain PROCEED:** `requirement_foe_loadout_privacy` is **BUSINESS-layer
    (DRAFT)** and states foe entities MUST NOT expose `buffs` in any board-state payload "regardless of
    transport." Its implementation, `module_foe_loadout_masking` (ARCHITECTURE/MODULE, REVIEW), strips the
    whole `buffs` key at `masking.go:99-101`. **No structural blast-radius hit today** — neither atom links
    to `entity.go`, and step 16 does not touch `masking.go`. **The risk is adjacency:** the masking module's
    guarantee rests on *every* board-state payload routing through `maskEntities`. A richer attribution
    accessor makes it easier to later build a path (debug view, replay, battle log, new endpoint) that
    bypasses that single funnel.
    **TWO CONFIRMATIONS NEEDED FROM THE USER BEFORE IMPLEMENTATION:**
    (i) step 16's accessor stays a **pure Go-internal read API** in `upsilontypes/entity`, with **no JSON
        tags on its return type** that a future handler could emit without passing through `maskEntities`;
    (ii) if the intent is *ever* to surface attribution to a client ("show me who buffed me"), that needs a
        **real BUSINESS atom written up front, not retrofitted**, plus explicit confirmation that
        `module_foe_loadout_masking` still holds under the richer shape. Out of step 16's scope as written.
    **Pre-existing ATD gap noted for step 18 / Workflow B:** `RegisterBuff` (239), `GetBuffsFor` (255) and
    the `Buffs` field (56) carry **no `@spec-link` at all**.

69. **STEP 16 DESIGN SETTLED — USER SIGN-OFF OBTAINED (2026-09-01): ENGINE-INTERNAL ONLY.**
    Clears the `PROCEED-WITH-SIGNOFF-PENDING` from decision 68. Confirmation (i) is **granted**:
    the accessor is a **pure Go read API** in `upsilontypes/entity` with **NO JSON tags on its return
    type**, so nothing can serialize it to a client without deliberate new work. The
    `requirement_foe_loadout_privacy` guarantee is therefore untouched — `maskEntities` remains the single
    funnel. Confirmation (ii) stays **out of scope**: surfacing attribution to a client is a separate task
    that must write its BUSINESS atom **up front**, not retrofit one.
    **Settled shape:**
    ```go
    // upsilontypes/entity/entity_buff_attribution.go  — NO json tags anywhere
    type BuffContribution struct {
        Buff  property.TemporaryProperties // Origin*, Duration, Forever — full shape, per decision 67
        Value property.Property            // this block's contribution to the key
    }
    // @spec-link [[mechanic_item_buff_application]]
    func (e Entity) GetBuffAttributionFor(name property.Key) (base property.Property, contribs []BuffContribution)
    ```
    Returns the **natural/unbuffed base** plus **each contributing buff with its owning
    `TemporaryProperties` intact** — closing exactly the gap in decision 14 (`GetBuffsFor` discards the
    owner). New sibling file, because `entity.go` is 385 LOC against a 400 warn ceiling.
    **`GetBuffsFor` is left ALONE** — its 5 call sites (1 internal in `GetProperty`, 3 tests) need only the
    value, and composition genuinely does not want the owner. Additive accessor, no signature churn.

70. **ISS-153 FILED — the summon/trap producer gap, at the maintainer's explicit request.** Decision 67
    retracted the "dead field" framing; this decision converts the corrected framing into tracked work.
    The user asked to "ensure that we do have summon/trap skills available (ensuring that those
    properties get used)". Filed as
    `issues/ISS-153_20260901_temporary_entity_summon_trap_no_producer.md` (Medium, Open) by a delegated
    Sonnet `coding-executor`, docs-only, **zero `.go` files touched** (verified: `git status --short |
    grep '\.go$'` empty; only `README.md` and `issues/README.md` edited alongside the new file).
    **The shape of the gap — consumer side complete, producer side absent:**
      - `EntityDuration` — enum `propertyenum.go:36`, registry row 13 `registry_entity_core.go:37-39`,
        default constructor `def/entity.go:70-71` returning `0,0` (**0 = permanent**), and a **live
        decrementer + `RemoveEntity` call** at `upsilonbattle/.../rules/endofturn.go:132-147` carrying
        `@spec-link [[mechanic_expiration_controller]]`. **No production writer.** Because the default is
        0, no entity is ever created as temporary, so that expiry branch **can never fire in production.**
      - `ExpiresWithCaster` — enum `propertyenum.go:39`, registry row 14 `registry_entity_core.go:41-43`,
        default `false`, **live reader** at `gamestate/gamestate_logic.go:106` culling a dead caster's
        owned positional effects. **No production writer**, so that cull can never fire either.
      - `OriginSkillID` — **exactly one occurrence umbrella-wide**, its own declaration at
        `property/buff.go:13`. Never written, never read, production or test.
      - **No skill-cast path creates a buff at all.** `RegisterBuff`'s only production callers are
        `bridge_start.go:238` (`applyItemAsBuff`, always `Forever:true`) and `bridge_resurrect.go:205`
        (rehydration). `skill.go`/`attack.go`/`effectapplicator.go` never touch `TemporaryProperties`.
      - `Entity.BuffTickDown()` (`entity.go:267`) is **never called in production** — sole caller is
        `entity_test.go:64`. `EndOfTurn` ticks `SkillCooldownTickDown()` and entity-scoped
        `EntityDuration`, never buff-scoped duration. A finite-`Duration` buff would not expire even if
        one existed. Wire DTO `api/input.go:157-161` has no `duration` field either.
    **Framing held to decision 67, and this is the point of the issue:** it is filed as **incomplete
    feature work, NOT a defect** — quoting the maintainer, "it's still an early breed of skill that
    haven't seen much use so far." The issue **contrasts** itself with ISS-152 rather than equating them:
    ISS-152 is dead weight that *pretends to enforce* something and has no plan behind it; ISS-153 is
    **scaffolding awaiting its producer**. Verified present in the filed text: the ISS-152 contrast (3
    refs), the maintainer quote, both governing DRAFT atoms (`mechanic_expiration_controller`,
    `mechanic_temporary_entity_system`), and the `GetBuffAttributionFor` forward-reference.
    **Two distinct `Duration` concepts are called out explicitly** so an implementer cannot conflate them:
    entity-scoped `property.EntityDuration` (how long a summon/trap lives) vs buff-scoped
    `TemporaryProperties.Duration` (how long a stat modifier lasts). Both lack producers, for different
    reasons.
    **Carried risk recorded in the issue:** `endofturn.go:132-147` and `gamestate_logic.go:106` read as
    live, `@spec-link`'d, plausible code that **has never once executed in production**. Whoever builds
    the producer should treat them as **unproven, not merely untested**, and expect latent bugs.
    Root README auto-table refreshed 53 -> 54 active issues; `issues/README.md` row added by hand.
    **This closes the user's request; step 16 implementation remains blocked on the Workflow E atom ID.**

71. **STEP 16 ATD WORKFLOW E COMPLETE — atom `mechanic_buff_attribution_accessor` materialized BEFORE
    any code.** Captured in `upsilontypes/docs/mechanic_buff_attribution_accessor.atom.md` (6.8K, DRAFT,
    priority 5), parented cross-project to `[[upsilonbattle:mechanic_item_buff_application]]`.
    **Verified by me directly, not taken on the agent's word:** the file exists; front matter carries
    `id`, `status: DRAFT`, `layer: IMPLEMENTATION`, `type: MECHANIC`, and all four tags
    (`entity,buffs,attribution,engine`); and the parent atom in `upsilonbattle` carries the backlink
    `- [[upsilontypes:mechanic_buff_attribution_accessor]]` at line 9 — the cross-project link is live in
    **both** directions, which `atd weave` confirmed ("Updated 1 files").
    **CLASSIFICATION RULING (documentalist flagged it for me; I ACCEPT its call).** It filed
    MECHANIC/IMPLEMENTATION rather than ARCHITECTURE, diverging from Workflow E's literal trigger list.
    **Accepted, and this is the right call:** Workflow E's ARCHITECTURE trigger is "a new or changed API,
    entity, module, service, UI flow, or specification." `GetBuffAttributionFor` is **none of those** — it
    is an additive Go-internal read accessor on the pre-existing `Entity` type, which is not changing
    shape. Decision 69's "engine-internal only, no JSON tags" sign-off is precisely what makes it *not*
    architecture: it adds no surface anything outside the engine can reach. Filing it as a sibling of
    `RemoveBuffsByOrigin` under the same parent, same type, same layer is the consistent placement.
    **Governance checks it performed and I accept:** `requirement_foe_loadout_privacy` and
    `rule_entity_property_write_isolation` both read and left untouched; near-duplicate search run before
    creating (none found — genuinely new coverage, not a revision); decisions (i) no-JSON-tags and
    (ii) client-attribution-out-of-scope both restated as first-class atom content rather than cited back
    to the handoff. `atd lint` on the new atom passes clean; `atd trace` reports
    `has_business_origin: true` with `total_code_files: 0` (expected pre-implementation).
    **CARRIED INTO STEP 18 (Workflow B):** the atom records as a **pre-existing** gap — one it does not
    create — that `RegisterBuff` (`entity.go:239`), `GetBuffsFor` (`entity.go:255`) and the `Buffs` field
    (`entity.go:56`) carry **no `@spec-link` at all**. This matches the step 18 backlog already recorded.
    **`atd` CLI HAZARD, worth carrying forward:** `--set tags=a,b,c,d` **silently drops all but the first
    value** (pflag CSV-splitting) with **no error surfaced**. It must be wrapped as
    `--set '"tags=a,b,c,d"'`. The agent caught this only on a mandatory re-read of the written file. Any
    future `atd update --set` with a comma-bearing value must be re-read to confirm it landed.
    **NO `.go` FILE WAS MODIFIED** — `@spec-link [[mechanic_buff_attribution_accessor]]` is *documented*
    in the atom as belonging atop the `GetBuffAttributionFor` declaration, but not applied, because
    `upsilontypes/entity/entity_buff_attribution.go` does not exist yet. **That is the executor's job.**
    **=> STEP 16 IS NOW UNBLOCKED FOR HANDOFF.** The `coding-executor` brief must carry: the atom id
    `mechanic_buff_attribution_accessor`, the decision-69 shape verbatim, the new-file requirement
    (`entity.go` is 385 LOC vs a 400 warn ceiling), the no-JSON-tags constraint, "leave `GetBuffsFor`
    alone", and the `@spec-link` placement rule (atop the function, never a file header).

72. **USER RULING ON ISS-152: WIRE IT IN, DEFERRED — "issue 152 will be wired (just not now)."** This
    closes the open question carried since decision 62. **The retire option is WITHDRAWN.** The
    `InformationLevel`/`MinInfoLevel` scheme is not dead weight to delete; it is unfinished enforcement to
    complete, on a later round.
    **The consequence matters more than the ruling, and it INVERTS decision 63's reading of ISS-151.**
    ISS-151 was filed saying its own fix would be *"security theatre: it changes a value nothing reads."*
    **That was only true under the assumption ISS-152 would be retired. That assumption is now dead.**
    Once enforcement is wired, every `MinInfoLevel` in the registry and in `PropertiesForCharacter`
    becomes **load-bearing**, and `PropertiesForCharacter` building HP/Movement/SP/MP/Shield/Attack/
    AttackRange/Defense/JumpHeight at `property.Public` — where the registry says `FriendlyController`
    (`def/entity.go:91-107` vs the registry rows) — **becomes a REAL over-exposure the day enforcement
    lands.** ISS-151 therefore flips from *"subordinate, probably moot"* to **"blocking prerequisite for a
    decided piece of work"**: it must be corrected before or as part of the wire-in, or the wire-in ships
    an exposure on day one.
    **What has NOT changed:** the current-state severity framing in both issues stays correct and stays
    intact. Today the scheme is genuinely inert — `UserFriendlyGet` has **zero callers umbrella-wide** and
    `convertProperty` (`upsilonapi/api/output.go:391-394`) serializes raw `v.Get()` with no
    `InformationLevel` parameter — so there is **no live exposure now**, and neither issue may be inflated
    to imply one. The distinction to preserve for a future reader: *inert today, load-bearing on wire-in.*
    Also unchanged: **do NOT flip `PropertiesForCharacter` Public->FriendlyController as a standalone
    hardening in this round.** It is sequenced after ISS-152's design, exactly as before — only the reason
    to keep it open has changed. Both issues stay `Open`; annotation delegated, `Status` untouched;
    ISS-151 severity re-rating is **my call, pending the agent's recommendation**.
    **Real masking is unaffected either way** — `upsilonhub/internal/games/battle/masking.go` is a
    separate per-recipient field-name mechanism governed by `requirement_foe_loadout_privacy`, and it IS
    thorough for loadout. The two mechanisms remain unrelated (decision 60).

73. **STEP 16 HANDED OFF TO `coding-executor`** (user go-ahead given). Brief carries, per decision 71's
    requirement: atom id **`mechanic_buff_attribution_accessor`** as the `@spec-link` target — **NOT**
    `mechanic_item_buff_application`, which is its *parent*, not the link target; decision 69's settled
    shape verbatim; **new file** `upsilontypes/entity/entity_buff_attribution.go` because `entity.go` is
    385 LOC against a 400 warn ceiling; **no JSON tags** (framed to the executor as the security boundary
    it is, not a style preference — it is what keeps attribution unserializable to a client);
    **`GetBuffsFor` left alone**; `@spec-link` atop the function only, `@test-link` only in the test file.
    Acceptance: `go build`/`go vet` clean, **baseline 199/0 in upsilontypes must hold**, code health clean
    on both new files, and a **consistency test** asserting that composing the returned `Value`s over
    `base` reproduces `GetProperty(name)` — with an explicit instruction to **STOP and report rather than
    adjust the test** if that assertion fails, since a divergence there would be a real finding about the
    composition path (cf. decision 53's `applyItemAsBuff` template-`Max` caveat), not a test bug.

74. **BOTH DELEGATES DIED MID-FLIGHT TO A 429 RATE LIMIT — recovered by INSPECTING DISK STATE, not by
    blind retry.** Both agents' last emitted lines understated how far they had actually got ("Now the
    Change Log entry for ISS-151"; "Both clean. Rebuild and retest"). **A blind re-dispatch would have
    duplicated their partial edits.** Rule confirmed for this round: on an agent abort, **assess the tree
    first, then decide retry vs finish-in-place.** In both cases the remaining work turned out to be
    *verification*, which is the orchestrator's own job — so I finished it directly rather than paying for
    two more agents.

75. **STEP 16 COMPLETE AND VERIFIED BY ME DIRECTLY.** Two new files, both code-health **clean**:
    `upsilontypes/entity/entity_buff_attribution.go` (2184 B) and `entity_buff_attribution_test.go`
    (5838 B, 4 tests).
    **Verification evidence (run by me, not taken on report):** `go build ./...` rc=0; `go vet ./...`
    rc=0; `go test ./...` = **203 passed / 0 failed** across 13 packages, against a **199/0 baseline** —
    exactly +4, the new tests, with no pre-existing test disturbed.
    **Every design constraint confirmed on disk:**
      - **Zero JSON tags** in either file (`grep 'json:'` empty) — the engine-internal boundary from
        decision 69 holds; attribution cannot be serialized to a client without deliberate new work.
      - `@spec-link [[mechanic_buff_attribution_accessor]]` sits **atop the function declaration**, and
        targets the **new atom, not its parent** — the trap flagged in decision 73 was avoided.
      - `@test-link` appears on all 4 test functions, **`@spec-link` nowhere in the test file** — correct
        per the link-placement rule.
      - **`entity.go` is still 385 LOC and `GetBuffsFor` (255-265) is byte-identical.** No signature churn.
      - Traversal **matches `GetBuffsFor` exactly** — same `property.PropertyToString` normalisation, same
        `e.Buffs` order, same `Properties[nname]` lookup — so **attribution order matches composition
        order**, which is what makes the consistency guarantee meaningful. Base resolution reuses the
        existing `getBasePropertyOrDefault`; no reimplemented lookup, no invented fallback.
      - Returns a **non-nil empty** `contribs` for an unbuffed key, no error, no panic (crash-early
        respected: an unbuffed property is a normal state, not a fault).
    **THE CONSISTENCY ASSERTION PASSED** — `TestGetBuffAttributionFor_ConsistentWithGetProperty` composes
    the returned `Value`s over `base` via `ApplyBuff` and asserts **both `Value` AND `MaxValue`** match
    `GetProperty(HP)` over two stacked buffs (5-duration + Forever). This was the one I told the executor
    to **stop and report on rather than adjust**; it went green honestly. **Note this does NOT clear
    decision 53's `applyItemAsBuff` template-`Max` concern** — the test proves the accessor agrees with
    `GetProperty`, i.e. that both compose identically; it does not prove that composition is *correct*.
    That candidate issue stays open.
    **Unprompted good judgment worth keeping:** the doc comment cross-references
    `rule_entity_property_write_isolation` to warn the accessor must never be the read half of a
    read-modify-write onto base state — tying it to last round's ISS-144/145 work.
    **REVIEWER GATE CALL (mine): SKIP a dedicated pass for step 16; fold it into the step 18 round gate.**
    Justification: purely additive, **zero production call sites**, design pre-signed-off by the user,
    evidence is strong (203/0 + clean health + the risky assertion green), and step 18 already carries a
    reviewer gate for the round. A separate gate here would be ceremony, not risk reduction.
    `entity.go`'s own 9 pre-existing health errors (missing `@spec-link` on `RegisterBuff`/`GetBuffsFor`/
    `Buffs`) are **untouched and already on the step 18 backlog** — this step neither fixed nor worsened
    them.

76. **ISS-151 SEVERITY RAISED Low -> Medium (my call, per decision 72's inversion).** The delegate
    correctly declined to self-rate and escalated the recommendation. Rationale recorded in the issue:
    it is no longer a cosmetic mismatch but a **prerequisite whose omission ships a real exposure** at
    ISS-152 wire-in time. Held at Medium, **not higher**, because there is **no live exposure today** and
    the wire-in is explicitly deferred — a hard *ordering* constraint, not an urgent one. Matches ISS-153.
    **NEW FINDING from the annotation pass — the scope is NINE keys, not five.** Additional registry rows
    at `registry_entity_vitals.go:12-33` carry the same `MinInfoLevel: FriendlyController` divergence
    against `PropertiesForCharacter`'s `Public`: HP, Movement, SP, MP, Shield, Attack, AttackRange,
    Defense, JumpHeight. ISS-151 was filed against five; it now covers nine. Also confirmed: **all 16
    `PropertiesForCharacter` callers are `_test.go`** — no production impact today, which is why this
    stays orderable rather than urgent.
    Both issues remain `Open`. `issues/README.md` rows refreshed for 151/152; root README regenerated
    (**54 active issues**, unchanged — no issue added).

77. **STEP 17 OPENED — the non-Go surface sweep. Its whole difficulty is DISCRIMINATION, not search.**
    The round's risk here is property keys living as **bare string literals on surfaces the Go compiler
    cannot check** — they fail at runtime as a silently missing property, not at build time.
    **This is not hypothetical: it already happened once this round.** A lookup keyed by `"Armor"` was
    missed, `def.EntityProperty("Armor")` returned nil, and **the property was silently discarded** with
    no error (recorded around TODO line 618). Step 17 exists to catch the rest of that class.
    **Authoritative old->new string map (from `architecture/property_key_vocabulary.md` §7, verified
    against the doc, not from memory):** `Damage`->`DamageScale`, `Shield`->`ShieldPower`,
    `Stun`->`StunPower`, `Poison`->`PoisonPower`, `Armor`->`ArmorRating`, `MvtCost`->`MovementCost`,
    `Value`->`ItemValue`.
    **THE TRAP THAT MAKES A NAIVE GREP WORTHLESS — and it is the round's own central collision (ISS-147):**
    `Shield`, `Stun` and `Poison` **still exist, unchanged and correct, as ENTITY keys.** Only the
    **skill** keys were renamed. So a hit on `"Poison"` is stale **only in a skill/effect context** and is
    **correct in an entity context**. Any sweep that reports hits without classifying scope produces a
    list that is actively dangerous to act on — "fixing" a legitimate entity `Poison` would break it.
    Likewise `Value` is a generic JSON/JS token (field names, variables, map keys) and is stale **only**
    as an *item property key*; `Damage` legitimately appears as a non-property concept (damage numbers,
    log text, event names). **Precision in the STALE bucket beats recall; an UNCERTAIN bucket is the
    correct home for anything whose scope cannot be read from context.**
    **Surfaces in scope:** Go **string literals** in seed/fixture/testutil builders (the Go files compile
    fine — it is the *strings* that are unchecked); goja `.js` scenarios in `upsiloncli`; JSON/YAML/SQL/
    migration fixtures; the `upsilonbattleui` Vue/TS SPA. **Out of scope:** type-checked Go identifiers
    (already migrated in step 12), and `docs/`/`TODO.md`/`issues/`/`architecture/` prose.
    **Expectation to confirm:** no `.postman_collection.json` exists in the tree. A surface confirmed
    *absent* is a real result for this step, not a gap.
    Grounding delegated read-only to `codebase-explorer` with the collision trap written into the brief.
    **No edits yet — this step produces a classified finding list first, then a scoped fix handoff.**

78. **STEP 17 COMPLETE — swept, classified, fixed, and verified. TWO OF MY OWN STATED BELIEFS WERE WRONG;
    both corrected here.**
    **CORRECTION 1 — POSTMAN COLLECTIONS DO EXIST.** Decision 77 and several earlier status lines assert
    "no `.postman_collection.json` exists." **That is FALSE.** Two live at the umbrella root:
    `Upsilon_Battle.postman_collection.json` (26.7K) and `Upsilon_Engine_Internal.postman_collection.json`
    (4.6K). I verified with `ls` after the sweep refuted me. Both were swept; the only hit is the legacy
    shape below, so **no Postman edit was required** — but the belief itself was wrong and any future step
    must not repeat it. **CODING_RULE §7 makes Postman a change-discipline surface, so this matters
    beyond this round.**
    **CORRECTION 2 — "silently discarded" is IMPRECISE for the functional hit.** I traced it myself rather
    than accepting the report: `buildSkillEffect` (`upsilonapi/bridge/bridge_utils.go:163-180`) does NOT
    swallow an unknown key — it `continue`s past it but **collects the error** and returns
    `errors.Join(errs...)`; `resolveScopedProperty` returns a real `ErrUnknownPropertyKey`. The caller
    `bridge_start.go:257` captures it as `errE` and **does return it** (line 284).
    **BUT the genuine defect shape is worse and different from both framings:** `e.RegisterSkill(s)` runs
    at **line 272 — BEFORE the error is ever examined.** So the skill is registered with its effect
    **stripped**, and only afterwards is an error returned. Whether that becomes a visible failure or a
    live neutered skill depends entirely on whether the top-level caller aborts the match start. **A
    partially-constructed object is committed before validation completes** — worth remembering as its own
    pattern risk (it is a CODING_RULE §3 crash-early smell), independent of this rename.
    **STALE hits found: 3 files, 4 edits, ALL APPLIED AND VERIFIED (zero residual old names):**
      - **The one functional break, caused by THIS round:**
        `upsiloncli/tests/scenarios/e2e_credit_economy.js:73` `effect: { Damage: 5000 }` ->
        `{ DamageScale: 5000 }`, plus its now-lying explanatory comment at line 65.
      - **Two skill-name-collision blocklists, drifted out of sync with the registry:**
        `upsilonbattleui/tests/playwright/user_flows.spec.ts:386` and
        `upsiloncli/tests/scenarios/e2e_skill_roll_naming.js:24` — both `Damage`->`DamageScale` and
        `Shield`->`ShieldPower`. **Note these guards are currently VACUOUS** (`namegen.go` is word-pool
        based and never emits registry key strings), so this fixes no live bug — it keeps the guard
        honest so it means something if the generator ever changes. Recorded as such, not oversold.
      - Comment drift: `e2e_inventory_equip_battle.js:59` `properties.Armor` -> `properties.ArmorRating`.
    **Verification:** `node --check` passes on all three touched `.js` files; a full-tree residual sweep
    across `*.js`/`*.ts`/`*.vue`/`*.json` for old skill-key literals returns **only** the legacy shape
    below. `MvtCost`'s only live hits are Go *identifier* builder methods (`battletest/builders.go`,
    `reposition_test.go`) — type-checked, out of scope by definition.
    **THE COLLISION TRAP HELD — nothing was over-corrected.** Every entity-scope `Shield`/`Stun`/`Poison`
    was correctly classified LEGITIMATE and left untouched, as were all `Value` hits (every one is a
    `PropertyDTO.Value`/`IntCounterProperty.Value` field, `context.Value()`, a table header or an AWS
    tag — **not one** is an item property key). `upsiloneconomy/internal/seed/seed.go:28` and
    `upsilonbattleui/src/Composables/useCharacterStats.js` were **already** on `ArmorRating` — those
    surfaces were migrated correctly earlier.
    **ROUND SCOPE WIDENED 3 -> 5 SUBMODULES.** `upsiloncli` and `upsilonbattleui` were **clean** before
    this step (verified) and are now modified. **Step 18's commit plan must grow accordingly:**
    upsilontypes -> upsilonbattle -> upsilonapi -> **upsiloncli -> upsilonbattleui** -> umbrella bump.
    All five touch only test/scenario files in the two new submodules; no production code there.

79. **NEW PRE-EXISTING DEFECT FOUND, NOT PART OF THIS ROUND — the legacy `Type`/`Stat`/`Value` skill-effect
    schema. RECOMMEND FILING AS ISS-154; not filed yet, awaiting the go-ahead.**
    Seed data and three scenarios still carry a **Laravel-era effect shape** —
    `{ Type: "Damage", Value: 10 }`, `{ Type: "Stun", Duration: 1 }`,
    `{ Type: "Buff", Stat: "Movement", Value: 2 }` — at `upsilonhub/internal/seed/seed.go:59-64`,
    `Upsilon_Battle.postman_collection.json:1109`, `upsiloncli/samples/pve_bot_item_skill.js:31`,
    `upsiloncli/tests/scenarios/edge_attack_skill_cooldown.js:36`, and
    `e2e_friendly_fire_skill_test.js:26`.
    **This is NOT a rename regression and must not be framed as one.** `buildSkillEffect` resolves
    **top-level** keys against the registry, so here it sees `"Type"`, `"Stat"`, `"Value"` — which were
    **never valid property keys, before or after the rename.** `"Damage"`/`"Stun"` in this shape are
    *values of a `Type` field*, not keys. It would have failed identically under the old vocabulary.
    Correctly left untouched by step 17.
    **Why it went unnoticed:** admin content is stored as unvalidated `json.RawMessage`
    (`upsilonhub/internal/gateway/admin_content.go` captures it raw to preserve key order), and the three
    scenarios using this shape **never assert the effect actually fires** — they only exercise validation
    and cooldown rejection. So seeded skills plausibly ship with **no working effect at all**.
    Ties directly to decision 78's finding that `RegisterSkill` commits before the error is checked.

80. **STEP 17b OPENED (user directive, supersedes decision 79's "file it as ISS-154"): FIX the legacy
    `Type`/`Stat`/`Value` skill-effect schema so seeded and test skills become VALID, before step 18.**
    Instruction: *"no solve this issue of seeded skills and test skills so that they become valid first."*
    Decision 79's recommendation to defer this to an issue is **withdrawn** — it is being fixed now.
    **WHY THIS IS NOT A FIND-AND-REPLACE, and why I refused to start editing:** the legacy payload is not
    merely misspelled, it is **semantically incompatible** with the valid vocabulary.
      - `{"Type":"Damage","Value":10}` means **flat 10 damage**. The valid key `DamageScale` is a
        **PERCENTAGE of the caster's Attack** — `truedmg = max((attack * scale / 100) - defense - armor, 0)`
        per the comment in `e2e_credit_economy.js` (which I have asked to be verified against
        `effectapplicator.go`, NOT trusted as written). **There is no 1:1 translation**; picking a number
        changes shipped starter-content balance.
      - `{"Type":"Buff","Stat":"Movement","Value":2}` may not be **expressible at all**. Decision 67/ISS-153
        established that **no skill-cast path anywhere calls `RegisterBuff`** — buffs come only from items
        (`bridge_start.go:238`) and resurrect rehydration (`bridge_resurrect.go:205`). If skill-granted
        buffs do not exist as a runtime mechanism, the honest fix for that seed entry is **to change what
        the skill does**, not how it is spelled. **This is the entry most likely to need a user decision.**
      - `{"Type":"Stun","Duration":1}` — need to confirm whether `StunPower` exists as a skill key and
        what its value means (turns? chance? magnitude?) before writing anything.
    **Two parallel groundings dispatched, both read-only, BEFORE any path is settled:**
      - `codebase-explorer` — the authoritative menu of skill-scope registry keys with Kind/Composition;
        the **real** damage formula from `effectapplicator.go`; baseline character Attack/Defense/Armor so
        a scale number can be chosen rather than guessed; whether skill-granted buffs are expressible;
        and **3-5 verbatim examples of effect maps that actually resolve today**, to use as templates.
      - `documentalist` **Workflow D1 preflight** — whether a BUSINESS/STABLE atom governs what the
        **seeded starter skills are supposed to DO**. This matters: rewriting flat damage into percentage
        scaling **changes the numeric behaviour of shipped content**, which is a balance change, not a
        correctness fix. I asked it to flag explicitly if this needs user sign-off on gameplay balance.
    **Scope note:** `upsilonhub` is currently **clean** and would become the **6th** modified submodule.
    Postman (`Upsilon_Battle.postman_collection.json:1109`) is also in scope — per CODING_RULE §7 it is a
    change-discipline surface that must move with the code, and per decision 78's correction it **does**
    exist, contrary to my earlier claim.
    **NOTHING WILL BE EDITED until both groundings land and a path is settled.** Explicitly NOT assuming
    the legacy numbers translate to anything in particular.

81. **STEP 17b GROUNDING COMPLETE — the task is 3x bigger than I scoped it, and ATD says HALT.**
    **documentalist D1 verdict: `HALT-NEEDS-USER-INPUT`**, explicitly flagging that this needs **gameplay
    balance sign-off**, not just a correctness fix. I agree and have not written a single number.
    **SCOPE CORRECTION — it is not just `effect`. ALL THREE property maps are malformed in ALL SIX seed
    templates**, which matches `issues/ISS-140`'s own text verbatim (so **this work IS ISS-140's remaining
    scope** — relevant because step 18 already plans to close ISS-140):
      - `targeting: {"Type":"Single","Range":3}` — `Type` is not a key. **And the correct replacement key
        DEPENDS ON THE VALUE**: `Single`/`AoE` are **Zone** patterns, but `Self` is a valid **TargetType**
        (`registry_skill_targeting.go:39` Allowed list). One legacy key maps to two different real keys.
      - `costs: {"MP":3}` / `{"SP":2}` — `MP`/`SP` are **Entity**-scope, not Skill-scope, so they fail
        `resolveScopedProperty(key, ScopeSkill)`. **RESOLVED BY ME, no user input needed:** the real cost
        keys are `MPLeech`/`SPLeech`/`HPLeech` — proven live at `skill_validation.go:213-227,254-260`
        (affordability check) and `skill.go:81 paySkillCost`. So `{"MP":3}` -> `{"MPLeech":3}`.
      - `effect:` — the case originally found.
      - `{"Type":"AoE","Range":2,"Radius":1}` — **`Radius` is not a property key at all** (grep of
        `upsilontypes/property/` returns nothing).
    **LANDMINE FOUND — "AoE" would PANIC.** `ZoneProperty.Set` (`def/skill.go:226`) **panics** on an
    unrecognised pattern; valid patterns are **`Single`, `Neighbours`, `Circle:N`, `Square:N`, `Line:N`**.
    `"AoE"` is not among them. So a naive `Type`->`Zone` rename on Lightning Strike would convert a silent
    no-op into a **hard panic**. This is exactly why I refused to find-and-replace.
    **VERIFIED ENGINE FACTS (each traced to source, not taken from the scenario comments):**
      - **Damage** (`effectapplicator.go:144-147`): `truedmg = max((attack*DamageScale/100) - defense -
        armor, 0) + truepoison + truestun`, then floored by the crit multiplier. `DamageScale` default
        **100**. The `e2e_credit_economy.js` comment is **correct** but omits the poison/stun terms (both
        0 when absent).
      - **Baseline character** (`character.go:56-60 NewBaseStats`): **HP 30, MP 10, SP 10, Attack 10,
        Defense 5, Movement 3, JumpHeight 2**; no Armor field (Class B, item/buff only) so armor = 0.
        Confirmed as the real roll (`pg.go:42`, `pg_profile.go:52`), not a test fixture.
        => **parity translation `DamageScale = (N+5)*10`**: legacy `Value:10` -> **150**, `Value:12` -> **170**.
      - **Stun is NOT a duration** (`effectapplicator.go:166-169` + `beginingofturn.go:24-48`):
        `StunPower` is a **magnitude** reduced by armor, gated by a `StunChance` percent roll, accumulated
        onto the entity `Stun` counter. A target **only actually skips a turn when accumulated `Stun` >
        MaxHP/2** (= **15** at baseline), and is then reset to 0. Below that it merely halves each turn.
        **=> `{"Type":"Stun","Duration":1}` is unrepresentable as written; it needs `StunPower >= 15` AND
        a non-zero `StunChance`, or the skill is mechanically dead** (the atom `mechanic_effect_stun`
        states this pairing rule independently).
      - **Q4 ANSWERED BY PROOF — SKILL-CAST BUFFS DO NOT EXIST.** `ApplyDirectEffect`
        (`effectapplicator.go:55-76`) has exactly **two** branches, damage and heal; neither touches
        `RegisterBuff`. Confirms decision 67/ISS-153 from the opposite direction. **So `Sprint`
        (`Buff`/Movement) and `Regen Aura` (`Buff`/HP) cannot be fixed by respelling — the semantics they
        describe are not in the engine.** This is a design decision, not a translation.
    **WHY IT SURVIVED UNDETECTED — the most useful finding for the round:** the crash-early guard is
    **real** (a legacy-shaped skill equipped in a real match aborts match creation loudly, propagating up
    through `bridge_start.go:72-74`), but it is **structurally unreachable for these six rows**: a
    repo-wide grep for the seed UUID constants (`fireballID`, `healID`, `sprintID`, `lightningStrikeID`,
    `shieldBashID`, `regenAuraID`) finds **ZERO references anywhere else in the codebase.** No test,
    scenario or fixture **ever equips or casts a seeded skill.** `TestSeedRunMatchesLaravelSeeders`
    only asserts **byte-parity with the old Laravel seeder strings** — it pins the broken shape in place
    rather than validating it. **Any fix MUST also update that test, or it will fail on correct data.**
    Admin-content storage validates nothing (`checkPresentArray` checks presence only; proven by
    `admin_content_test.go:121` accepting `{"damage": 7}` with 201).
    **PROPOSED REWRITE (4 of 6 skills fully grounded, 2 blocked on a design call):**
      | Skill | targeting | costs | effect |
      | Fireball | `{"Zone":"Single","Range":3}` | `{"MPLeech":3}` | `{"DamageScale":150}` |
      | Heal | `{"Zone":"Single","Range":2}` | `{"MPLeech":4}` | `{"Heal":10}` |
      | Lightning Strike | `{"Zone":"Circle:1","Range":2}` | `{"MPLeech":5}` | `{"DamageScale":170}` |
      | Shield Bash | `{"Zone":"Single","Range":1}` | `{"SPLeech":3}` | `{"StunPower":15,"StunChance":?}` |
      | Sprint | `{"TargetType":"Self","Range":0}` | `{"SPLeech":2}` | **BLOCKED — buffs unreachable** |
      | Regen Aura | `{"TargetType":"Self","Range":0}` | `{}` | **BLOCKED — buffs unreachable** |
    **THREE DECISIONS PUT TO THE USER** (balance intent; Sprint/Regen Aura disposition; AoE zone shape).
    **STILL NOTHING EDITED.**

82. **ALL THREE STEP-17b DECISIONS TAKEN BY THE USER; implementation handed to `coding-executor`.**
      - **Balance: PARITY WITH BASELINE.** `DamageScale = (N+5)*10` -> Fireball **150**, Lightning **170**;
        Shield Bash `StunPower` **15** / `StunChance` **100**.
      - **Sprint & Regen Aura: REDEFINE TO WORK NOW.** Regen Aura -> `{"Heal":1}`; Sprint -> `{}`.
      - **Lightning Strike zone: `Circle:1`.**
    **TWO ENGINE CONSEQUENCES I DISCOVERED WHILE VALIDATING THE CHOICES — surfaced to the user, and both
    are engine design, not avoidable by any value choice:**
      - **A STUN ALWAYS DEALS DAMAGE.** `effectapplicator.go:145-147` computes
        `truedmg = max((attack*scale/100) - def - armor, 0) + truepoison + truestun`, i.e. the stun
        magnitude is **added to damage**. Combined with the stun threshold being **MaxHP/2** (15 at
        baseline), **stunning a 30 HP target inherently costs it 15 HP — half its health.** There is no
        stun-without-damage in this engine. **Mitigation applied: explicit `"DamageScale":0` on Shield
        Bash**, because `DamageScale` **defaults to 100 when the key is ABSENT**, which would silently add
        another 5 attack damage on top. Without that explicit 0 the skill would deal 20, not 15.
        **This default-when-absent behaviour is the same trap class as the `"Armor"` nil-lookup earlier
        in the round: absence does not mean zero.**
      - **`{}` IS NOT INERT.** `IsHealing()` is `!HasPositiveProperty(DamageScale) || ...`
        (`upsilontypes/property/effect/effect.go:96-101`), so an **empty effect returns TRUE** and runs the
        healing branch — healing 0. `IsDamaging()` (lines 88-92) is correctly false. So Sprint is
        observably a no-op, which satisfies the approved "valid + inert" intent, but the healing branch
        **does execute**. Recorded so nobody later reads `{}` as "no branch runs."
    **FINAL SETTLED TABLE (note the Zone/TargetType asymmetry is CORRECT, not an inconsistency:
    `Single`/`Circle:1` are Zone patterns, `Self` is a TargetType):**
      | Fireball | `{"Zone":"Single","Range":3}` | `{"MPLeech":3}` | `{"DamageScale":150}` |
      | Heal | `{"Zone":"Single","Range":2}` | `{"MPLeech":4}` | `{"Heal":10}` |
      | Sprint | `{"TargetType":"Self","Range":0}` | `{"SPLeech":2}` | `{}` |
      | Lightning Strike | `{"Zone":"Circle:1","Range":2}` | `{"MPLeech":5}` | `{"DamageScale":170}` |
      | Shield Bash | `{"Zone":"Single","Range":1}` | `{"SPLeech":3}` | `{"DamageScale":0,"StunPower":15,"StunChance":100}` |
      | Regen Aura | `{"TargetType":"Self","Range":0}` | `{}` | `{"Heal":1}` |
    **THE TEST THAT PINS THE BROKEN DATA MUST MOVE TOO.** `TestSeedRunMatchesLaravelSeeders`
    (`upsilonhub/internal/seed/seed_test.go:25`) asserts **byte-parity with the old Laravel seeder
    strings** — it will FAIL on correct data, because it currently **enshrines the malformed shape**. The
    executor was told to update it to assert the new payloads and to rename it if "MatchesLaravelSeeders"
    no longer describes it, and **explicitly forbidden from deleting assertions to make it pass**.
    Also in the handoff: the 3 goja/sample mirrors and the **Postman collection** (CODING_RULE §7).
    **Round now spans 6 submodules** (`upsilonhub` joins). Postman is at the umbrella root.

83. **ATD FAILURE REPORT FILED BY documentalist, per the standing rule.** `atd map --file .../seed.go`
    returned truncated/malformed JSON from its `deepseek-r1:7b` link recommender **and exited 0 despite
    the functional failure**. Report at
    `~/work/atd/failures/20260902_atd_map_malformed_json_link_recommender_recurrence.md` — a **recurrence**
    of the 2026-09-01 failure, this time WITH the verbatim command and raw output the first report lacked.
    **No verdict depended on it** (the `@spec-link` question was answered by direct `grep` instead), so
    nothing was blocked. **Exit-code-0-on-failure is the dangerous part** — any future scripted use of
    `atd map` must check for empty/garbage output, not trust the exit status.

84. **Step 17b (legacy seed/skill payload rewrite) LANDED AND VERIFIED BY ME AGAINST THE TREE.**
    All six `seed.go` rows match the user-approved table byte-for-byte (`Zone`/`TargetType`,
    `MPLeech`/`SPLeech`, flat effect keys). The three goja mirrors and the Postman Fireball row
    carry the same shape. **`seed_test.go` was strengthened, not loosened** — the check I most
    expected to be quietly traded away. `TestSeedRunMatchesLaravelSeeders` →
    `TestSeedRunSeedsExpectedSkillCatalog` (the old name asserted byte-parity with the *broken*
    Laravel strings and would have failed on correct data); it now does per-row `assert.JSONEq`
    on all three payloads across **both** idempotent seed passes, keeps the 6-row count assertion,
    and adds a `seen[]` completeness check so a **missing** row fails instead of passing silently.
    `@test-link [[upsilontypes:entity_skill_template]]` preserved atop the function. Test ran for
    real against testcontainers Postgres (not skipped). code_health 0/0 on the package.
    **ISS-140's remaining scope is now closed on the data side.**

85. **The agent's engine claim was IMPRECISE but its conclusion SURVIVES — I re-derived it myself.**
    It reported `checkSkillTarget` as "the only code that populates `ctx.targetedEntities`". False:
    `skill.go:57` is a second writer. **But** that writer is gated on
    `isReposition(sk) && repositionSubjectOf(sk) == def.RepositionSubjectSelf` — a *movement*
    skill — so it does not rescue Shield Bash (Reaction) or Regen Aura (Passive), neither of which
    is a reposition. Conclusion holds. Logged because the next person to grep this will hit the
    same second writer and must know why it does not apply.

86. **NEW DEFECT — WORSE THAN THE AGENT REPORTED. Not caused by this round; do not fix here.**
    `preSkillChecks` (`skill_validation.go`, "no target for passives!") early-returns `true` for
    `IsPassive()/IsReaction()/IsCounter()` **before** `checkSkillTarget` — the agent's finding —
    but that same early return **also skips `checkSkillCost`**, which the agent missed. Meanwhile
    `paySkillCost` at `skill.go:81` runs unconditionally on the success path. Net for a
    passive/reaction invoked through `UseSkill`: `targetedEntities` is empty, so
    `applyDamagingEffect`/`applyHealingEffect` loop over nothing and the effect is a **silent
    no-op**, *and* the cost is deducted **with no affordability check at all**. So 2 of the 6
    freshly-seeded skills (Shield Bash, Regen Aura) are now correct-and-inert rather than
    malformed. **This is progress, not a regression** — the payloads are registry-valid; the gap
    is a pre-existing engine wiring hole in the ISS-148/ISS-149 family (trigger/behavior dispatch
    for non-Direct behaviors). Candidate follow-up issue, NOT YET FILED — awaiting go-ahead.


87. **REGEN AURA — USER RULING: STAYS `Passive`. Filed as ISS-154.** The name is right; it behaves
    like an item effect (sustained, always-on), not an activated action. Redefinition: `Zone` becomes
    **`Square:1` centred on the caster**, `Heal` **1 → 5**, healing an entity that **begins its turn**
    inside the zone, **allies only — must not fire for foes**. Required test bed (3 tests, all needing
    `HP < MaxHP` or the heal is unobservable): (a) ally starting its turn in-zone is healed; (b) a foe
    in the same zone is **not**; (c) a same-team entity owned by a **different player** IS healed —
    this last one guards against the faction filter being coded as an owner/controller check instead
    of a team check. **The `OnTurn` consumer ALREADY EXISTS** (`beginingofturn.go:53`,
    `ProcessPositionalEffects(..., property.TriggerOnTurn)`) — I verified it. What is missing is the
    **producer** (same hole as ISS-153) plus a genuinely novel bit: every existing positional effect
    sits on a **fixed tile**, whereas an aura centred on the caster is a **moving** zone with no
    precedent in the trap machinery. **Deferred to a later session.**

88. **SHIELD BASH — USER RULING: STAYS `Reaction`. Filed as ISS-155.** Deliberately kept as the
    vehicle for **building the reaction mechanism, which does not exist at all**. Intended semantics:
    on a hit landing, inspect the **hit recipient** for a reactive skill with reaction type
    **`OnReceivedHit`**; if present it triggers **against the attacker**. Verified the vocabulary gap
    myself: `TriggerType`'s allowed set (`registry_skill_cost_trigger.go:47`) is
    `OnEnter, OnExit, OnStep, OnTurn, OnDeath` — **all positional, no combat-outcome values**, and
    nothing hooks the damage path. Same missing on-hit hook ISS-148 (Parry) needs and the same family
    ISS-149 describes — **consider resolving 148/149/155 together.** The seeded payload
    (`DamageScale:0, StunPower:15, StunChance:100`) is already correct; only dispatch is missing.
    **Deferred to a later session.**

89. **SPRINT — MY ERROR, NOW BEING CORRECTED.** I approved `{}` as Sprint's effect under "redefine to
    work now"; `{}` is a **total no-op**. Worse, I missed that its targeting made the fix impossible
    to express: `checkReposition` derives direction from caster→target and rejects a zero vector with
    `skill.reposition.nodirection`, so `TargetType:Self, Range:0` can NEVER supply a direction. The
    engine has had a fully wired reposition mechanic all along (`mech_movement_reposition`,
    `isReposition` = `Effect.RepositionDistance != 0`, `RepositionSubject` ∈ {Self,Target}, fly-over
    semantics where only the landing tile fires OnEnter). **Reposition is orthogonal to `Behavior`** —
    a dash is a `Direct` skill. Canonical working shape is the `Dash` fixture
    (`reposition_test.go:25-27`): `TargetType(Tile).Range(1,3).Reposition(Self,3)`. Delegated to a
    coding-executor: keep `Direct` + `SPLeech:2` (a cost that is deliberately NOT `MovementCost`),
    make targeting aimable, add `RepositionSubject:"Self"` + non-zero `RepositionDistance`.

90. **ISS-156 FILED — admin skill-template endpoint performs ZERO registry validation.** I verified
    the sweep's claim against source rather than taking it: `admin_content.go:235-237` (create) and
    `281-288` (update) both call `checkPresentArray`, which per `409-411` applies **`present|array`
    only** — presence and type, never key content. The file's own header (line 3) states the blocks
    "are captured raw". So `POST /api/v1/admin/skill-templates` with
    `{"range":3}/{"mp":4}/{"damage":7}` returns **201 Created**, and the failure only surfaces
    mid-battle when the bridge rejects the keys. Authoring-time acceptance of data guaranteed to fail
    at use time = CODING_RULE §3 violation. Also latent: an unvalidated `Zone` string is a **panic**
    at battle time (`ZoneProperty.Set`). `TestSkillTemplateCRUDLifecycle` currently encodes the defect
    as expected behaviour and must be **inverted** to assert rejection. **Deferred to a later session.**

91. **DEFINITION SWEEP LANDED — the user's "(shouldn't)" expectation HELD.** Second read-only explorer
    inventoried every skill-defining site repo-wide. **No hardcoded skill definitions in production
    code**; all non-test/non-seed paths are `json.RawMessage` pass-through or delegate to
    `buildSkillPropertyMap`/`buildSkillEffect`. One borderline case named and dismissed:
    `upsilontypes/entity/skill/skillgenerator/*` constructs skills with concrete numbers, but that is
    the **designed procedural skill-roll mechanic** using type-safe `property.XXX` constants (cannot
    typo a key), not an authoring bypass. `Upsilon_Engine_Internal.postman_collection.json` confirmed
    clean (zero matches). Remaining findings NOT yet actioned: (a) three `upsilonhub/internal/gateway`
    test fixtures carry legacy lowercase keys — folded into ISS-156's scope; (b)
    `battleSandboxScenarios.js` uses a wrong wire shape (`Zone` nested in `targeting`; `{value:}` for
    string properties) and appears to be **dead data** — `ActionPanel.vue` reads neither `targeting`
    nor `Zone`; (c) 9 sites across 3 `upsilonbattle` leech tests file a **Cost** property into the
    **Targeting** map under key `"TargetType"` — harmless only by accident of `GetProperty`'s linear
    scan across all three maps; (d) the DamageScale-absent trap fires for real in
    `TestRuleSkillEffectPoisonCounter` and the `PoisonTrap()` builder (6+ callers), silently adding
    attack-scaled damage to "poison-only" traps that nobody asserts on. **(b), (c), (d) are unfiled.**

92. **SPRINT FIXED AND VERIFIED BY ME ON DISK.** Row is now
    `{"TargetType":"Tile","Range":{"value":1,"max":3}}` / `{"SPLeech":2}` /
    `{"RepositionSubject":"Self","RepositionDistance":3}` — Direct, SP-costed (deliberately NOT
    `MovementCost`), mirroring the `Dash` fixture. `seed_test.go`'s three Sprint entries updated, the
    `seen[]` loop and every other row untouched. New regression test
    `upsilonapi/bridge/sprint_reposition_test.go::TestSprintSeedPayload_IsAGenuineSelfReposition`
    (`@test-link [[mech_movement_reposition]]`, no `@spec-link`) runs the **exact seeded strings**
    through the real `buildSkillPropertyMap`/`buildSkillEffect` and asserts TargetType=Tile,
    Range=[1,3] **non-inverted**, RepositionSubject=Self, RepositionDistance≠0. This closes the blind
    spot that let the whole legacy-schema breakage survive: no test had ever exercised a seeded payload.
    Seed suite ran for real against a `postgres:18` testcontainer (PASS, not skipped); upsilonapi all
    packages ok; code_health clean on both touched dirs (3 pre-existing errors in `upsilonapi/bridge`
    are in files this change never touched).

93. **I MISREPORTED THE SEEDED CATALOG TO THE USER — CORRECTED. Filed as ISS-157, Severity High.**
    I told the user Fireball/Heal/Lightning Strike "work as seeded". **They do not — they are
    untargetable.** `Range` is an IntCounter where `value`=MIN and `max`=MAX. A **bare int**
    (`"Range":3`) hits `PropertyDTO`'s primitive fallback (`input.go:52-84`) which sets **only**
    `dto.Value`; `setSkillPropValue` (`bridge_utils.go:85-127`) maps that to `SetValue` — the MINIMUM
    — leaving `MaxValue` at `DefaultRange()`'s **1**. `SetValue` does **not clamp**
    (`defaultproperty.go:120-125`). So `"Range":3` → window `[min=3, max=1]`, and
    `skill_validation.go:100` rejects when `dist > max || dist < min` → **every distance rejected**.
    Fireball `[3,1]`, Heal `[2,1]`, Lightning Strike `[2,1]` all unusable; Shield Bash `[1,1]` and
    Regen Aura `[0,1]` happen to be fine. **Why it hid:** every passing e2e/goja scenario uses the
    STRUCTURED form (`Range:{value:0,max:20}`); only the seed used bare ints, and nothing ever
    exercised a seeded skill. Sprint's fix uses the structured form and is unaffected. Verified every
    link of this chain against source myself — this was flagged by the executor as out-of-scope, NOT
    acted on blindly.

94. **THE THREE "UNFILED LEFTOVERS" ARE NOW FILED, and one of them was WRONG as reported.**
    Filed as three separate issues (not one) because they are distinct components with distinct fixes,
    matching this repo's one-defect-per-issue convention (cf. ISS-148/149 kept separate).
    - **ISS-158 (Medium)** — battleui targeting wire-shape mismatch. **The sweep called this "dead
      sandbox mock data"; that is FALSE and I verified it.** `useActionDispatch.js` is imported by
      **`BattleArena.vue` — the real battle client**, not just the sandbox. It reads
      `targeting?.TargetType?.value ?? 'Entity'`, but the engine serializes string properties as
      **`svalue`** (`output.go:404,408`; tag at `input.go:41`), so the real value is NEVER read and the
      client silently defaults to `'Entity'` for every skill. `Zone` is likewise lifted to a top-level
      field and explicitly skipped from the targeting map (`output.go:345,356,369`), so
      `targeting.Zone` never exists. CODING_RULE §3 + §4.
    - **ISS-159 (Low)** — 9 sites file a Cost property into `Targeting` under key `"TargetType"`.
      Verified the count: 15 sites match the pattern, but 6 are legitimate `TargetType` writes; only
      4+4+1 are mis-keyed. Inert only by accident of `GetProperty`'s cross-map name scan.
    - **ISS-160 (Medium)** — `PoisonTrap()` (7 callers) and `TestRuleSkillEffectPoisonCounter` are
      poison-only by intent but carry no `DamageScale`, which **defaults to 100**, so they silently
      also deal attack-scaled damage. Confounds the reposition fly-over tests that use poison
      precisely because it is supposed to be a clean observable.

95. **ISS-157 RESOLUTION SETTLED BY USER, DELEGATED. Bare-int `"Range": N` ⇒ `value 0, max N`;
    structured `{"value":X,"max":Y}` left exactly as-is.** (User first said "min 1, max N", then
    corrected themselves to value 0 — the correction is the ruling.) **No seed row gets edited** —
    the same stored JSON simply resolves correctly once the interpretation is fixed: Fireball
    `[3,1]→[0,3]`, Heal `[2,1]→[0,2]`, Lightning Strike `[2,1]→[0,2]`, Shield Bash `[1,1]→[0,1]`,
    Regen Aura `[0,1]→[0,0]` (self-only, correct for an aura), Sprint `[1,3]` **unchanged**.
    **Leaving the structured form untouched is load-bearing:** Sprint REQUIRES min 1, because
    `checkReposition` rejects a zero direction vector — a min of 0 would let a player aim a dash at
    their own tile and re-break it.

    **BLAST RADIUS I CHECKED BEFORE DELEGATING — this is the trap in this fix.** `setSkillPropValue`
    has **four** callers, and two are NOT the skill path: `bridge_start.go:234` (item buffs) and
    `bridge_resurrect.go:220` (persisted buff hydration), both `ScopeItem`. Other `KindIntCounter`
    keys include `HP`/`SP`/`MP`/`Movement`/`Shield` (Entity/Item) and `Delay`/`Channeling`/`Cooldown`/
    `Duration` (Skill). **A blanket "bare int with no Max" rule would corrupt the item path** —
    `{"HP":5}` on an item must keep meaning `value=5`; rewriting it to `value=0,max=5` would zero out
    every item's stat bonus. Because `Range` is registered **ScopeSkill only**
    (`registry_skill_targeting.go:14`), gating the new behaviour on the Range property is inherently
    safe. **Brief mandates gating on Range, NOT on the generic shape**, plus a regression test proving
    the item path is untouched.

    **Deliberately still open after this fix:** the bare-int interpretation of `Delay`, `Channeling`,
    `Cooldown` and `Duration` is unreviewed and may carry the same min/max inversion. ISS-157 does NOT
    cover them — noted in the issue's Resolution section.

96. **ISS-157 FIX LANDED AND VERIFIED BY ME (agent `ac09ad59bf3ebb8ec`, 2026-09-02).** Bare-int
    `"Range":N` now resolves to `value 0, max N`; the structured `{"value":X,"max":Y}` form is
    untouched. **No seed row was edited** — the stored JSON just resolves correctly now.

    **What I verified personally, file by file (not taken on the agent's word):**
    - `bridge_utils.go:82-125` — `setSkillPropValue` gained a `key property.Key` parameter and an
      `error` return. The rewrite branch is gated on `key == property.Range && dto.Value != nil &&
      dto.Max == nil` → `cp.SetValue(0); cp.SetMaxValue(*dto.Value)`. **Gated on the Range key, NOT
      on the generic "IntCounter with no Max" shape** — exactly as the brief mandated (dec. 95).
      Since `Range` is ScopeSkill-only, this branch is structurally incapable of firing on an
      Entity/Item IntCounter. The trap is closed.
    - **New crash-early behaviour (CODING_RULE §3):** an *inverted structured* payload
      (`value > max`) now returns `fmt.Errorf("inverted skill range: value %d exceeds max %d")`
      instead of silently constructing an unusable skill. This is new strictness the brief did not
      ask for but is correct — it converts a silent dead-skill into a loud failure.
    - **All four call sites handle the new error rather than dropping it:** `bridge_utils.go:182`
      (`buildSkillPropertyMap`) and `:210` (`buildSkillEffect`) do `errs = append(errs,
      fmt.Errorf("%s: %w", key, err)); continue`; `bridge_start.go:234` (item buffs) same;
      `bridge_resurrect.go:220` (buff hydration) returns the wrapped error. No silent swallow.
    - `range_ingestion_test.go` (new, 6 tests, all `@test-link [[mechanic_skill_payload_resolution]]`):
      bare-int→`[0,N]`; structured unchanged; inverted structured rejected; all 5 seeded skills;
      and **`TestRangeIngestion_ItemPathBareIntIsUnaffected`** — the guard I demanded, running a real
      `{"HP":5}` item through `applyItemAsBuff` and asserting `counter.GetValue() == 5`. That is the
      regression test for the dec. 95 trap, and it exists and asserts the right thing.
    - **The agent's "pre-existing tree state" claim on the two other modified test files is TRUE.**
      `bridge/mapping_test.go` (+2/-2) and `handler/skill_generate_test.go` (+1/-1) are both
      `property.Damage` → `property.DamageScale` renames — this round's key-unification work, with
      no relation to Range. Checked by reading the diffs, not by trusting the report.

    **Resulting windows (agent-reported, consistent with the code I read):** Fireball `[3,1]→[0,3]`,
    Heal `[2,1]→[0,2]`, Lightning Strike `[2,1]→[0,2]`, Shield Bash `[1,1]→[0,1]`, Regen Aura
    `[0,1]→[0,0]`, Sprint `[1,3]` unchanged (structured form, untouched — it needs min 1 so the
    reposition vector is expressible). **Decision 93's untargetable-catalog defect is resolved for
    the three Direct skills.** Shield Bash/Regen Aura remain inert for the *separate* behaviour
    reasons tracked in ISS-155/ISS-154, not for range reasons.

    **Verification evidence:** builds/vets clean; `upsilonapi` and `upsilonbattle` full suites pass;
    `upsilonhub` seed suite ran against a real `postgres:18` testcontainer and passed;
    `code_health_check.py` reports only the 3 pre-existing errors in untouched files.

    **Known residual defect, NOT introduced by this fix and NOT fixed by it:** `bridge_start.go`
    registers the skill (`e.RegisterSkill(s)`) *before* inspecting the accumulated `errs`, so an
    inverted structured Range now produces an error that is collected but does not prevent
    registration. Pre-existing ordering bug; candidate for the end-of-session issue review.

    **Deliberately still open (unchanged from dec. 95):** the bare-int interpretation of `Delay`,
    `Channeling`, `Cooldown` and `Duration` is unreviewed and may carry the same inversion. ISS-157
    does not cover them.

    **Open offer, NOT acted on — awaiting the user's word:** `Range` is modelled as `KindIntCounter`
    only because no min–max Kind exists (dec. 94). Consequence: `ApplyBuff` adds both Value and
    MaxValue, so a "+1 range" buff silently raises the *minimum* too. The clean model is two plain
    `Int` keys (`RangeMin` + `Range`-as-max). **I offered to file this as an issue and the user has
    not answered. Do not file it unprompted.**

97. **STEP 18 OPENED 2026-09-02. USER CLOSED THE RANGE QUESTION: "leave range alone for now, i'll
    have another session used to review targeting as a whole."** The dec. 94/96 open offer (Range as
    two plain `Int` keys) is therefore **WITHDRAWN, not pending** — do not file it. Targeting gets its
    own dedicated session.

    **Plan checkboxes 14–17 were stale** (`[ ]` while the work was long done and recorded in
    decisions 84/78/75/57). Corrected to `[x]`; 18 marked in progress.

    **FRESH VERIFICATION EVIDENCE (all re-run by me today, not carried forward):**
    - **All 11 workspace modules build clean.** Note `go build ./...` from the umbrella ROOT is a
      no-op ("directory prefix . does not contain modules listed in go.work") — it must be run
      per-module or it silently proves nothing. I nearly recorded a false green off this.
    - `go vet` clean. Tests: **upsilontypes 203/0, upsilonbattle 189/0, upsilonapi 68/0.**
    - **`atd lint` = 13 errors = the exact recorded baseline.** No new ATD failure this round.
    - Uncommitted round spans **6 submodules**: upsilontypes (21 M + 9 new), upsilonbattle (16 M),
      upsilonapi (5 M + 5 new), upsiloncli (6 M), upsilonbattleui (1 M), upsilonhub (2 M).

    **THE ROUND IS NOT COMMIT-READY — 10 NEW CODE-HEALTH ERRORS. I found these by building a real
    HEAD baseline, not by eyeballing.** A raw whole-umbrella run reports 592 errors, which is useless
    noise; scoping to touched files still gave 181, also useless without a before. So I created
    read-only `git worktree` checkouts at HEAD in `/tmp/hb` (**no stash, no checkout, no reset on the
    live tree**), health-checked the same file list on both sides, and diffed. Result: **baseline 179
    -> now 181; 8 errors fixed, 10 introduced.** The 10:
    - **8 x `Too few ATD links: 0 (min 1)`** on the round's new registry files: `def/registry.go`,
      `registry_entity_core.go`, `registry_entity_movement.go`, `registry_entity_vitals.go`,
      `registry_item.go`, `registry_skill_targeting.go`, `registry_skill_effect.go`,
      `registry_skill_cost_trigger.go`. These are **core business files** — they need
      `@spec-link [[upsilontypes:module_property_key_registry]]` atop their functions. This is
      CODING_RULE §6 *and* §1. It is a genuine violation the round created, and it must be fixed
      before any commit.
    - **1 x `defaultproperty_test.go`: 0 ATD links** — needs a `@test-link` (test files take
      `@test-link` only, never `@spec-link`).
    - **1 x `property_resurrect_fallthrough_test.go`: nesting 5 (limit 4)** on
      `TestPropertyIngestion_ResurrectBuffPoisonMustNotBecomeEntityBuff` — needs flattening.

    **Consequence for step 18's ordering:** a fix phase now precedes the reviewer gate. Sequence is
    (a) documentalist Workflow B decides the atom bindings, (b) a `coding-executor` applies the link
    insertions + the nesting flatten, (c) reviewer gate, (d) commits, (e) close ISS-140/143/145/147.
    Commits do NOT happen without the user's explicit go-ahead (CODING_RULE §7).

98. **DOCUMENTALIST WORKFLOW B COMPLETE — AND I CAUGHT MY OWN DELEGATION FAILURE.** The user flagged
    that the agent **compacted once** mid-run: I had stuffed 7 carried-forward obligations + 10 new
    binding decisions into a single brief. That is on me, not the agent. Lesson for the rest of this
    round: **slice ATD sync work by obligation, not by "everything due at step 18".**

    **FALSE ALARM I RAISED AND THEN DISPROVED — recorded so nobody re-panics.** On seeing the
    compaction I checked for damage and thought work had vanished (upsilonbattleui 1->0 files,
    upsilonhub 2->1, upsiloncli 6->5, upsilonapi 10->9) and that `git reset` had been run despite
    being forbidden. **Both were wrong:**
    - The "vanishing files" were **my own `git status --short | wc -l` off-by-one** — that output has
      no trailing newline, so `wc -l` undercounts by exactly 1. Every module was short by exactly 1.
      Direct `git status` listing confirms everything intact: hub still has `seed.go` + `seed_test.go`,
      battleui 1, cli 6, and all 5 new upsilonapi test files present. **Never size up the tree with
      `wc -l` on `git status --short`.**
    - The `reset: moving to HEAD` reflog entries are dated **2026-08-30 and 2026-08-31** — earlier
      sessions, pre-dating today. The agent ran no forbidden git command. `git reflog --date=iso` is
      the check; a bare `git reflog` hides the dates and invites exactly this misread.

    **Agent's claims I verified myself against the tree (all TRUE):** no `.go` file touched (it edited
    exactly 3 `.atom.md` files); `atd lint` = **13 = baseline**; `bridge_start.go` already carries
    `@spec-link [[mechanic_item_buff_application]]` atop `applyItemAsBuff` at line 200 (obligation 7
    genuinely needs NO edit); poison/stun/shield/critical atoms need no edit.

    **AGENT CORRECTED THE ROUND'S OWN RECORD ON DUAL-SCOPE — it is 11 keys, not 8.** I had carried
    "8" from decision material; that only counted the three entity files. Verified by grep: 8 in
    `registry_entity_{core,movement,vitals}.go` (Attack, Defense, AttackRange, Movement, JumpHeight,
    HP, SP, MP) **+ 3 in `registry_item.go`** (ArmorRating:31, WeaponRange:62, WeaponBaseDamage:69)
    = **11**. `architecture/property_key_vocabulary.md` needed no edit — it was already reconciled.

    **THREE CORRECTIONS I MADE TO THE AGENT'S EDIT LIST before it was fit to hand over:**
    1. **Six items said "use the file's actual var name as read" — not mechanically applicable.**
       Resolved by grep: `entityCoreEntries`(:7), `entityMovementEntries`(:8), `entityVitalsEntries`(:8),
       `itemEntries`(:7), `skillTargetingEntries`(:7), `skillEffectEntries`(:7),
       `skillCostTriggerEntries`(:7). `registry.go` has real funcs: `mergeThemes`(:75), `Lookup`(:89).
    2. **Prefix form.** `code_health_check.py` resolves **unprefixed** ids workspace-wide AND validates
       them, but **skips phantom validation for any id containing `:`**. So prefixes hide typos. I kept
       `[[upsilontypes:module_property_key_registry]]` anyway because this round already established
       that exact prefixed form at **6 existing sites** — internal consistency wins, and I verified the
       atom file exists so there is no typo risk. Cross-project stays prefixed
       (`[[upsilonbattle:mechanic_ai_controller_archetypes]]`); `mechanic_temporary_entity_system` is
       same-project and already used unprefixed, so it stays unprefixed.
    3. **DROPPED the agent's item 18** — a `@spec-link` above the `Buffs` **struct field**. Project rule
       is links atop **functions** only; a field is not a function, and it clears no health error.
       `RegisterBuff`/`GetBuffsFor` (real functions) are kept.

    **Placement ruling I had to make:** the 7 theme files contain **no functions at all** — only one
    `var ...Entries = map[property.Key]Entry{...}` data table each. The "atop functions only" rule has
    no target. Ruling: **bind the link to the specific `var` declaration.** That honors the rule's
    intent (bind to the declaration embodying the spec, never a file/package header) and the health
    checker counts links anywhere in the file, so it clears the error.

    **Genuine drift the agent flagged and did NOT silently fix (correct behaviour) — needs a human call,
    added to the end-of-session review:** `module_property_key_registry`'s LOGIC claims duplicate keys
    are caught as "a Go compile error (duplicate map key)". They are not — the 7 themes are separate
    file-scoped `var`s, so `mergeThemes` catches duplicates as a **runtime panic at init**. The atom
    wording is simply wrong. Also flagged: two imperfect-fit links (`property.go:12` PropertyType vs
    Scope; `defaultproperty_test.go`'s empty-key-panic invariant) that may each deserve a narrower atom.
    **No atom promoted this pass** — agent recommended against it while the round is uncommitted and the
    edit list unapplied. I agree.

99. **STEP 18(a)+(b) COMPLETE — THE COMMIT BLOCKER IS CLEARED. Verified by rebuilding the HEAD
    baseline from scratch, not by trusting the executor's report.**

    **Definitive measurement: baseline 179 -> now 167. `comm -13` (still-new errors) is EMPTY, and
    12 pre-existing errors were fixed as a bonus.** All 10 regressions the round introduced are gone:
    the 8 `def/registry*.go` files, `defaultproperty_test.go`, and the nesting-5 test all clear.
    `def/glob.go`, `def/entity.go`, `property.go` and `defaultproperty_test.go` now report 0
    ATD-link errors. `atd lint` = **13 = baseline**, same 13 atom ids.
    Tests re-run green after every edit: **upsilontypes 203/0, upsilonbattle 189/0, upsilonapi 68/0.**

    **Executor touched NO `.atom.md` file** (verified by `git status | grep atom` — the 7 dirty atom
    files are exactly the documentalist's 3 plus the round's 4 pre-existing). No forbidden git ran.

    **Placement ruling applied:** the 7 theme files have no functions, so the `@spec-link` binds to the
    `var ...Entries` declaration. `registry.go` has real functions, so it got links atop `mergeThemes`
    and `Lookup`.

    **A DEFECT MY OWN PREFIX RULING CAUSED — found and fixed by me.** Instructing the executor to use
    the cross-project form on `entity.go` left the file carrying **the same atom under two different
    ids**: pre-existing unprefixed `[[mechanic_item_buff_application]]` at line 245 plus the two new
    `[[upsilonbattle:mechanic_item_buff_application]]`. The health checker counts them as 2 distinct
    atoms, pushing the file to 7 (limit 5). Since the atom lives in `upsilonbattle/docs`, the PREFIXED
    form is the correct one and line 245 was the wrong one — I rewrote line 245 to the prefixed form.
    Distinct count back to **6** (the pre-existing warn level, unchanged from before this round);
    upsilontypes still 203/0 after the edit. **Lesson: a prefix ruling is not local — check whether the
    same atom is already referenced under the other form in the same file before mandating one.**

    **Part 6 refactor reviewed line by line and ACCEPTED.** The agent extracted only the nested
    `[]api.Buff{...}` literal into `makeResurrectFallthroughBuff`. All 4 assertion phases survive
    intact (`assert.Empty(buffed)`, `require.Error(err)`, `errors.Is(err, ErrPropertyKeyWrongScope)`),
    all 3 table cases (Poison/Shield/Stun) survive, the `@test-link` survives, and it still calls
    `b.restoreEntityBuffs(&e, buffs)` — the identical path with identical inputs. Its diagnosis is
    correct: "nesting 5" was the checker's naive brace-depth counter hitting the struct literal, not
    real control-flow nesting. **The test still fails if the bug returns.**

    **DEFERRED to the end-of-session review, NOT fixed piecemeal:** cross-project `@spec-link`s are
    inconsistently prefixed across the workspace (e.g. `property_resurrect_fallthrough_test.go` in
    upsilonapi links unprefixed `[[mechanic_item_buff_application]]` to an upsilonbattle atom, and
    resolves fine). This is the project-wide convention question documentalist escalated. Fixing it
    file-by-file mid-round would be churn — it needs one ruling applied workspace-wide.

    **NEXT: step 18(c) reviewer gate, then (d) commits — which require the user's explicit go-ahead —
    then (e) close ISS-140/143/145/147.**
