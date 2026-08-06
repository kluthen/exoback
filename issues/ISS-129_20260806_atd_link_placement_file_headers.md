# Issue: ~60 Go files carry `@spec-link`/`@test-link` in the file header, and the two governing rule documents disagree on whether that is allowed

**ID:** `20260806_atd_link_placement_file_headers`
**Ref:** `ISS-129`
**Date:** 2026-08-06
**Severity:** Medium
**Status:** Open
**Component:** `CODING_RULE.md` §1, `.agent/rules/ATD.md` §252, ~60 Go source/test files across `upsilonhub`, `upsilonmapmaker`, `upsilonmapdata`, `upsilonapi`, `upsilonbattle`
**Affects:** ATD traceability granularity; `scripts/code_health_check.py` distinct-atom counting; ISS-126 / ISS-127 (link-cap breaches, which this pattern directly causes)

---

## Summary

A repo-wide scan finds **~60 Go files with at least one `@spec-link`/`@test-link` above the `package` declaration** rather than atop the specific function or type it describes. Before treating that as 60 defects, note the more important finding: **the two governing rule documents contradict each other** on whether header placement is permitted at all.

- `CODING_RULE.md` §1 (the transverse standard, inlined into `CLAUDE.md`): *"Every source file carries ≥1 ATD link (`@spec-link`/`@test-link`), atop the exact function/type — **never on package/file headers**."* — an absolute prohibition.
- `.agent/rules/ATD.md` line 252: *"**NO Global Headers:** Do not place `@spec-link` in the file header **unless the atom represents the ENTIRE architectural pattern of the file**."* — a conditional prohibition with an explicit, legitimate exception.

So the ~60 figure is an **upper bound on violations**, not a confirmed count. An unknown subset are legitimate under ATD.md's exception. The contradiction must be resolved before any cleanup, or the cleanup will churn files that were compliant all along.

---

## Technical Description

### Background

ATD binds atoms to code through `@spec-link`/`@test-link` comment tags. Placement granularity is what makes traceability meaningful: a tag atop a specific function asserts "this function implements this atom," whereas a tag in the file header asserts "everything below implements this atom" — a much broader and usually less accurate claim.

### The Problem Scenario

Detection heuristic used (links appearing before the `package` declaration):

```
FILES WITH HEADER-PLACED LINKS: 60
upsilonhub/internal/gateway/character_upgrade_test.go   (4)
upsilonhub/internal/gateway/shop_test.go                (4)
upsilonhub/internal/gateway/profile_test.go             (4)
upsilonhub/internal/gateway/leaderboard_test.go         (3)
upsilonmapmaker/gridgenerator/gridgenerator.go          (2)
upsilonmapmaker/gridgenerator/terrain_algorithms.go     (2)
upsilonhub/internal/awards/awards.go                    (2)
upsilonmapdata/grid/position/pattern/pattern_2d.go      (2)
upsilonapi/api/output_test.go                           (2)
scripts/watch_services.go                               (1)
... (60 total)
```

The concentration in `*_test.go` files with 3–4 header links each is the clearest signal of the anti-pattern: a test file header claiming four atoms is asserting that the whole file proves all four, rather than that specific test functions prove specific atoms.

### Why this matters beyond style

Header-placed links are a **direct cause** of the ATD link-cap breaches already tracked:
- `ISS-126` — `gateway/skills.go`, 5 distinct atoms in a header block.
- `ISS-127` — `user_flows.spec.ts`, 13 occurrences / 12 distinct atoms, accumulated in the header across eight unrelated feature areas.

Both were resolved or filed as "the header claim is over-broad." That is the same defect this issue generalises. Fixing placement discipline would relieve cap pressure structurally instead of file by file.

### Where This Pattern Exists Today

Confirmed example encountered while working on unrelated changes: `upsilonbattle/battlearena/ruler/ruler_shotclock_test.go` carries `@test-link [[rule_turn_clock]]` and `@test-link [[mechanic_arena_lifecycle]]` above `package ruler`, while also carrying a correctly-placed `@test-link [[rule_turn_clock]]` atop `TestShotClockExpiry` — the same atom asserted at both granularities in one file.

---

## Risk Assessment

**Severity: Medium.** No runtime or correctness impact. The cost is traceability precision: header links inflate distinct-atom counts (triggering the ≤10 cap), make "which code implements this atom" queries return whole files instead of functions, and weaken the `atd weave` dependency graph's usefulness. The rule-document contradiction is the sharper risk — two canonical documents giving opposite instructions means new code is written to whichever the author read last, and neither can be enforced automatically until they agree.

Risk of *not* fixing: the count grows, cap breaches keep arriving one file at a time as separate issues, and any future attempt to lint placement mechanically will be blocked by the ambiguity.

---

## Recommended Fix

**Step 1 — resolve the contradiction first (blocking).** Decide which reading governs:
- (a) Absolute prohibition per `CODING_RULE.md` §1 — simple, mechanically lintable, but forces awkward placement for genuinely file-wide architectural atoms (e.g. a MODULE atom describing an entire client package).
- (b) ATD.md's conditional rule — more faithful to intent, but "represents the ENTIRE architectural pattern of the file" is a judgment call that cannot be linted without a convention (e.g. permitted only for `type: MODULE`/`layer: ARCHITECTURE` atoms, and only one such link per file).

Recommendation: adopt (b) with the tightening in parentheses, then amend `CODING_RULE.md` §1 to match `.agent/rules/ATD.md` rather than contradict it. A one-per-file, MODULE-only exception is both honest and lintable.

**Step 2 — re-scan under the agreed rule** to convert the ~60 upper bound into a real violation list.

**Step 3 — remediate in batches by submodule**, relocating each link atop the function/type it actually describes. Expect this to reduce distinct-atom counts and clear cap pressure behind ISS-126/ISS-127.

**Step 4 — add a placement check** to `scripts/code_health_check.py` once the rule is unambiguous. Note that the checker is regex-based, not AST-based, so the check should stay heuristic (links appearing before the `package` line), consistent with its existing approach.

---

## Extra Data

- Detection command used (Go files only; other languages not yet measured — the true figure is higher):
  ```bash
  for f in $(grep -rl "@spec-link\|@test-link" --include="*.go" . | grep -v node_modules); do
    pkg=$(grep -n "^package " "$f" | head -1 | cut -d: -f1)
    [ -n "$pkg" ] && awk -v p="$pkg" 'NR<p && /@spec-link|@test-link/' "$f" | grep -q . && echo "$f"
  done
  ```
- `.ts`/`.tsx`/`.vue`/`.py` files were **not** included in this scan; `user_flows.spec.ts` (ISS-127) is a known instance outside the Go set.

---

## References

- `CODING_RULE.md` §1 — ATD adherence (absolute prohibition wording).
- `.agent/rules/ATD.md` line 252 — "NO Global Headers" (conditional prohibition wording).
- `ISS-126` — `skills.go` ATD link cap (Resolved) — same root cause.
- `ISS-127` — `user_flows.spec.ts` ATD link cap (Open) — same root cause.
- `ISS-128` — `@lint-ignore-*` naive substring match, a sibling defect in the same checker.
