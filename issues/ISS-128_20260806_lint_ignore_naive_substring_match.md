# Issue: `code_health_check.py` matches `@lint-ignore-*` tags by naive whole-file substring, silently skipping any file that merely *mentions* them

**ID:** `20260806_lint_ignore_naive_substring_match`
**Ref:** `ISS-128`
**Date:** 2026-08-06
**Severity:** Medium
**Status:** Open
**Component:** `scripts/code_health_check.py`
**Affects:** every file the checker scans; CODING_RULE.md §6 (zero-error standard); any documentation, test, or tooling file that discusses the lint tags

---

## Summary

`code_health_check.py` decides whether to suppress a check by testing `if '<tag>' in content` against the **entire file body**, with no requirement that the tag appear in a comment, on its own line, or anywhere near the top of the file. Any file that merely *mentions* the literal string — in a comment, a docstring, a regex, a test fixture, or prose documentation — silently disables that check for itself. For `@lint-ignore-all` the consequence is total: the whole file is skipped with only a `Skipping ...` line as evidence.

The checker currently does this to **itself**: `code_health_check.py` contains the literal `'@lint-ignore-all'` on the line that implements the check, so it skips its own source on every full-repo run. This was originally mis-diagnosed as an intentional opt-out tag; it is not — there is no standalone `@lint-ignore` comment anywhere in the file.

---

## Technical Description

### Background

CODING_RULE.md §6 requires zero errors from `code_health_check.py`. The script supports five escape hatches — `@lint-ignore-all`, `@lint-ignore-file-bloating`, `@lint-ignore-complexity`, `@lint-ignore-documentation`, `@lint-ignore-atd` — intended as deliberate, per-file opt-outs.

### The Problem Scenario

```python
# scripts/code_health_check.py
content = "".join(lines)
if '@lint-ignore-all' in content:          # <-- naive whole-file substring
    print(f"Skipping {filepath} (@lint-ignore-all found)")
    return

ignore_bloating   = '@lint-ignore-file-bloating' in content   # same flaw
ignore_complexity = '@lint-ignore-complexity'    in content   # same flaw
ignore_docs       = '@lint-ignore-documentation' in content   # same flaw
ignore_atd        = '@lint-ignore-atd'           in content   # same flaw
```

Three distinct ways this misfires:

1. **Self-skip (live today).** The script's own source contains `'@lint-ignore-all'` as a string literal, so it never checks itself. Its own LOC, nesting, and documentation coverage are unmeasured.
2. **Discussion-by-mention.** Any file that documents or tests the tags — a future `lint_test.py`, a fixture, a docstring explaining the hatches — disables those checks on itself just by naming them.
3. **Accidental, invisible suppression.** Because the match is not anchored to a comment or to the file head, a tag buried mid-file (or inside an unrelated string) suppresses checks with no visible signal for four of the five tags — only `@lint-ignore-all` prints anything at all.

### Where This Pattern Exists Today

- `scripts/code_health_check.py` — self-skipping, confirmed by running the checker over the repo and observing the `Skipping` line.
- `scripts/stress_test.py` and `scripts/code_health_check.py` both now legitimately carry `@lint-ignore-atd` (added when `rule_code_health_monitoring` left ATD for CODING_RULE.md §6), so the tag is in genuine active use and its matching semantics now matter more than before.

---

## Risk Assessment

**Severity: Medium.** Not a correctness or runtime bug — the checker is advisory, is not wired into CI, and is not wired into the pre-commit hook (deliberately; see the Code Health Standards section of `README.md`). But it silently under-reports, which is the worst failure mode for a quality tool: the summary line claims a clean-ish result while an unknown number of files were never actually examined. The self-skip means the enforcement script is the one file in the repo exempt from its own standard.

Risk of *not* fixing: the exemption set grows invisibly as more files come to mention the tags, and the repo-wide error count (603 at time of writing) becomes progressively less trustworthy as a baseline.

---

## Recommended Fix

Anchor the match to a comment line rather than raw file content:

1. Scan **line by line**, and only honour a tag when it appears on a line whose stripped form starts with a comment marker (`//`, `#`, `/*`, `*`) — consistent with how `@spec-link`/`@test-link` are already matched via regex rather than substring.
2. Optionally restrict recognition to the file header region (e.g. the first ~20 non-blank lines), matching the tags' documented intent as per-file declarations.
3. Use a regex mirroring the existing ATD-link approach, e.g. `re.search(r'^\s*(?://|#|/\*|\*)\s*@lint-ignore-all\b', content, re.MULTILINE)`, and take care that `@lint-ignore-atd` does not also match a longer tag by prefix.
4. Once anchored, add an explicit, intentional `@lint-ignore-*` to `code_health_check.py` **only if** it genuinely warrants one — and let it be measured otherwise.
5. Re-baseline the repo-wide error/warning count afterwards; expect it to rise as previously-skipped files start being scanned.

---

## Extra Data

- Thresholds in force: `LOC_WARN=400`, `LOC_ERROR=600`, `NESTING_MAX=4`, `ATD_MIN=1`, `ATD_WARN_MAX=5`, `ATD_ERROR_MAX=10` (distinct-atom semantics).
- Full-repo baseline at time of filing: **603 errors** (602 before `.ts`/`.tsx` were added to `EXTENSIONS`; the +1 is ISS-127).
- The checker is regex-based, not AST-based, which is the root reason several of its checks rely on textual heuristics.

---

## References

- `CODING_RULE.md` §6 — Code health, zero-error standard (now the canonical home of the standard, after `rule_code_health_monitoring` was retired from ATD).
- `README.md` — Code Health Standards: the checker is available but deliberately not automated; run manually at the end of each development session.
- `ISS-126`, `ISS-127` — related ATD-link-cap breaches surfaced by the same checker.
