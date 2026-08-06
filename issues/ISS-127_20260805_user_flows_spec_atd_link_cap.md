# Issue: `user_flows.spec.ts` breaches the 10-link ATD cap (13 occurrences / 12 distinct atoms), pre-existing

**ID:** `20260805_user_flows_spec_atd_link_cap`
**Ref:** `ISS-127`
**Date:** 2026-08-05
**Severity:** Medium
**Status:** Open
**Component:** `upsilonbattleui/tests/playwright/user_flows.spec.ts`
**Affects:** `scripts/code_health_check.py` (zero-error standard, CODING_RULE.md §6), any future `@spec-link`/`@test-link` addition to this file

---

## Summary

`upsilonbattleui/tests/playwright/user_flows.spec.ts` carries **13 `@spec-link`/`@test-link` occurrences resolving to 12 distinct ATD atoms**, against a hard cap of 10, so `code_health_check.py` reports it as an ERROR. This is the same failure mode `ISS-126` describes for `gateway/skills.go` one layer up: a single test file whose link header asserts coverage of 12 atoms is an over-broad claim about what that one spec file actually proves. The breach is **pre-existing**, not caused by the most recent commit that touched the file.

---

## Technical Description

### Background

CODING_RULE.md §6 requires zero errors from `code_health_check.py`: files ≤400 (warn) / 600 (error) effective LOC, nesting ≤4, every function documented, and 1–10 ATD links per file (distinct-atom semantics per ISS-126's Long-term note). `user_flows.spec.ts` accumulated link tags across multiple feature sessions (registration, login, websocket notifications, character reroll, skill inventory, shop, game selection, skill generation/name, action panel/skill icon) without ever being split, so it now carries links spanning at least eight unrelated feature areas.

### The Problem Scenario

```
user_flows.spec.ts (13 link lines / 12 distinct atoms)
│
1:  @test-link [[ui_registration]]
2:  @test-link [[ui_login]]
3:  @test-link [[api_websocket_user_notifications]]
4:  @test-link [[us_character_reroll]]
5:  @test-link [[entity_character_skill_inventory]]
6:  @test-link [[ui_shop]]
125: @test-link [[ui_game_selection]]
126: @test-link [[api_games_catalog]]
354: @test-link [[shared:req_skill_generation_overhaul]]
355: @test-link [[mech_skill_name_generation]]
356: @test-link [[ui_skill_icon]]
401: @test-link [[ui_action_panel]]
402: @test-link [[ui_skill_icon]]   ← repeat, same atom as :356 (13 lines → 12 distinct atoms)
```

Confirmed **pre-existing**: commit `8a95229` (`feat(iss-124): game selection page — enroll before entering a game`, upsilonbattleui) added 66 lines to this file (69 insertions, 3 deletions) and added **zero** `@spec-link`/`@test-link` lines to it. The cap breach predates that commit and was not introduced by it.

### Where This Pattern Exists Today

- `upsilonbattleui/tests/playwright/user_flows.spec.ts:1-6,125-126,354-356,401-402` — the file-header/section link lines listed above.

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | High — already occurring; every `code_health_check.py upsilonbattleui` run reports the file as an ERROR |
| Impact if triggered | Medium — no runtime or correctness risk; the cost is to code health compliance and to keeping the ATD papertrail's per-file claims honest and to future extensibility (any new link addition to this file is blocked without breaching further) |
| Detectability | High — `python3 scripts/code_health_check.py upsilonbattleui` names the file and count explicitly |
| Current mitigant | None. Pre-existing among the repo's other pre-existing code-health errors; not currently gating CI |

---

## Recommended Fix

**Short term:** Nothing that removes links. Deleting a valid `@spec-link`/`@test-link` to satisfy the counter would silently drop a real spec relationship and make the papertrail dishonest — strictly worse than the ERROR. Leave as-is until the split is done, and do not add further links to this file in the meantime.

**Medium term:** Split the spec along **flow boundaries**, mirroring how ISS-126 split `skills.go` along concern boundaries, e.g. grouping the registration/login/notifications flow, the character reroll/skill-inventory/shop flow, the game-selection/catalog flow, and the skill-generation/action-panel/skill-icon flow into separate `*.spec.ts` files, each carrying only the `@test-link`s it actually exercises.

**Long term:** Same open question ISS-126 raises applies here too — whether the checker's link-cap semantics (occurrences vs. distinct atoms) are the intended rule; a repo-wide decision on that would apply consistently to both `skills.go`-style and spec-file-style breaches.

---

## Extra Data

Verified counts at filing time: 13 `@spec-link`/`@test-link` occurrences, 12 distinct atoms (`ui_skill_icon` repeated at lines 356 and 402). Verified pre-existing via `git show 8a95229 --stat -- tests/playwright/user_flows.spec.ts` (69 insertions, 3 deletions — 66 net lines added) and `git show 8a95229 -- tests/playwright/user_flows.spec.ts | grep -E '^\+' | grep -c '@spec-link\|@test-link'` returning `0`.

---

## References

- `upsilonbattleui/tests/playwright/user_flows.spec.ts`
- `scripts/code_health_check.py`
- `CODING_RULE.md` §6 (Zero-error code health)
- `.agent/rules/ATD.md` (link placement)
- `issues/ISS-126_20260804_skills_go_atd_link_cap.md` (same failure mode, one layer up)
