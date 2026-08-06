# Issue: `gateway/skills.go` breaches the 10-link ATD cap (12) and conflates three concerns

**ID:** `20260804_skills_go_atd_link_cap`
**Ref:** `ISS-126`
**Date:** 2026-08-04
**Severity:** Medium
**Status:** Resolved
**Component:** `upsilonhub/internal/gateway/skills.go`
**Affects:** `scripts/code_health_check.py` (zero-error standard, CODING_RULE.md §6), `upsilonhub/internal/gateway/skill_test.go`, any future `@spec-link` addition to this file

---

## Summary

`upsilonhub/internal/gateway/skills.go` carries **12 `@spec-link` tags against a hard cap of 10**, so `code_health_check.py` reports it as an ERROR. The file was already breaching at 11 before the ISS-124 work; adding the mandated `[[upsilonbattle:mech_skill_selection_progression]]` link (needed so that atom was no longer at zero implementations) took it to 12. The cap is not arbitrary here — the link count is an accurate signal that this single 274-line file implements **three separate concerns** governed by three unrelated atom clusters. The fix is to split the file, not to delete links.

---

## Technical Description

### Background

CODING_RULE.md §6 requires zero errors from `code_health_check.py`: files ≤400 (warn) / 600 (error) effective LOC, nesting ≤4, every function documented, and **1–10 ATD links per file**. The link cap exists to keep a file's spec surface comprehensible — a file bound to many atoms is usually a file doing many jobs.

Note the checker counts **link occurrences**, not distinct atoms. `skills.go` has 12 occurrences but only **5 distinct atoms**, because several handlers legitimately repeat the same `@spec-link`. Whether the rule intends occurrences or distinct atoms is worth confirming — but in this instance the file is over the line either way on the concern-count argument below.

### The Problem Scenario

The 12 links cluster cleanly into three groups that share almost nothing:

```
skills.go (274 LOC, 10 funcs, 12 links / 5 distinct atoms)
│
├── CONCERN A — skill template catalogue
│   ├─ listTemplates      :43   [[upsilonapi:api_skill_template_browse]]
│   └─ showTemplate       :57   [[upsilonapi:api_skill_template_browse]]
│
├── CONCERN B — a character's skill inventory (equip/unequip)
│   ├─ listSkills         :75   [[upsilonapi:api_character_skill_inventory]]
│   ├─ equipSkill        :143   [[upsilontypes:rule_character_skill_slots]]
│   ├─ unequipSkill      :171   [[upsilonapi:api_character_skill_inventory]]
│   ├─ ownedCharacter    :196   [[upsilonapi:api_character_skill_inventory]]
│   └─ findSkill         :215   [[upsilonapi:api_character_skill_inventory]]
│
└── CONCERN C — the creation/progression skill roll (the roulette)
    ├─ roll               :96   [[upsilonbattle:req_skill_generation]]
    │                          [[upsilontypes:rule_character_skill_slots]]
    │                          [[upsilonbattle:mech_skill_selection_progression]]
    └─ gradeAllowed      :236   (grade gating by win count)

    mountSkills          :256   [[upsilonapi:api_character_skill_inventory]]
                               [[upsilonapi:api_skill_template_browse]]
```

Consequences today:

1. `code_health_check.py upsilonhub` reports an ERROR on this file, so the module cannot reach the zero-error standard without addressing it.
2. **Any future `@spec-link` addition to this file is blocked** — the next atom needing implementation evidence here cannot get it without first breaching the cap further. This is the acute cost: it makes the ATD papertrail *harder to keep honest*, which is the opposite of the rule's intent.
3. A file-header `@test-link` in `skill_test.go` now covers four atoms spanning all three concerns, which is an over-broad claim about what any single test proves.

### Where This Pattern Exists Today

- `upsilonhub/internal/gateway/skills.go:1-274` — the file itself; link sites listed above.
- `upsilonhub/internal/gateway/skill_test.go` — file-header `@test-link` block, now carrying 4 atoms.
- `upsilonhub/internal/gateway/skills.go:256` — `mountSkills` mounts all three concerns' routes together.

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | High — already occurring; the ERROR is reported on every `code_health_check.py upsilonhub` run |
| Impact if triggered | Medium — no runtime or correctness risk whatsoever; the cost is to code health compliance and to the ATD papertrail's future extensibility |
| Detectability | High — `python3 scripts/code_health_check.py upsilonhub` names the file and the count explicitly |
| Current mitigant | None. The breach predates this session (was 11, now 12) and sits among ~67 other pre-existing errors in `upsilonhub`, so it is not currently gating CI |

---

## Recommended Fix

**Short term:** Nothing that removes links. Deleting a valid `@spec-link` to satisfy the counter would silently drop a real spec relationship and make the papertrail dishonest — strictly worse than the ERROR. Leave as-is until the split is done, and do not add further links to this file in the meantime.

**Medium term:** Split `skills.go` along the three concern boundaries above, e.g.:

- `skill_templates.go` — `listTemplates`, `showTemplate` (→ `api_skill_template_browse`)
- `skill_inventory.go` — `listSkills`, `equipSkill`, `unequipSkill`, `ownedCharacter`, `findSkill` (→ `api_character_skill_inventory`, `rule_character_skill_slots`)
- `skill_roll.go` — `roll`, `gradeAllowed` (→ `req_skill_generation`, `rule_character_skill_slots`, `mech_skill_selection_progression`)

`mountSkills` stays in whichever file keeps the routing group, or moves to a small `skills.go` that only wires. Each resulting file lands comfortably inside 1–10 links. Split `skill_test.go` to match, so each test file's `@test-link` header claims only what that file actually exercises.

**Long term:** Consider whether the link cap should count **distinct atoms** rather than occurrences in `code_health_check.py`. Under a distinct-atom count this file reads 5/10 and would never have flagged — which may or may not be the intended semantics. Worth a deliberate decision, since it changes the rule's behaviour repo-wide.

---

## Extra Data

Discovered during ISS-124 close-out (game-agnostic accounts / games catalog work), when a documentalist Workflow B sync established that `upsilonbattle:mech_skill_selection_progression` had **zero** `@spec-link`/`@test-link` references anywhere and therefore could not honestly advance past DRAFT. Adding the missing link to `roll` was the correct action for the papertrail and is what surfaced the pre-existing cap breach. The executor that added it flagged the overflow rather than quietly rebalancing tags to stay under the limit — the right call, and the reason this issue exists.

Verified counts at filing time: 274 LOC, 10 functions, 12 link occurrences, 5 distinct atoms (corrected from an initial miscount of 6 — see Change Log).

---

## References

- `upsilonhub/internal/gateway/skills.go`
- `upsilonhub/internal/gateway/skill_test.go`
- `scripts/code_health_check.py`
- `CODING_RULE.md` §6 (Zero-error code health)
- `.agent/rules/ATD.md` (link placement: `@spec-link` atop functions only)
- `upsilonbattle/docs/mech_skill_selection_progression.atom.md`

---

## Resolution

`skills.go` was split along the three concern boundaries recommended above into `skill_templates.go`, `skill_inventory.go`, and `skill_roll.go`, plus a thin `skills.go` retaining only routing. Tests were redistributed into three matching files (`skill_templates_test.go`, `skill_inventory_test.go`, `skill_roll_test.go` / `skill_equip_test.go`).

Independently verified at close:
- Link set preserved: 12 → 12 identical occurrences across the split files, 5 distinct atoms, none deleted.
- Routes: byte-identical before/after the split.
- Tests: 11 → 11 identical test set, redistributed not rewritten.
- `go build ./...` and `go vet ./...`: clean.

## Change Log

- **2026-08-05**: Corrected the summary's distinct-atom count from 6 to 5 — `sort -u` over the atom IDs in `skills.go` at filing time yields exactly `api_character_skill_inventory`, `api_skill_template_browse`, `mech_skill_selection_progression`, `req_skill_generation`, `rule_character_skill_slots`. The three-concern split conclusion is unaffected by this correction. Closed as Resolved: the file was split per the Medium-term recommendation and independently verified (link set 12→12 identical / 5 distinct atoms, routes byte-identical, tests 11→11 identical set, `go build ./...` and `go vet ./...` clean).
