# Issue: Audit the upsiloncli edge-case scenario suite — scenario assertions, not mechanics, are what fail CI

**ID:** `20260709_edge_case_scenario_suite_audit`
**Ref:** `ISS-107`
**Date:** 2026-07-09
**Severity:** Medium
**Status:** Open
**Component:** `upsiloncli/tests` (`run_all_edge_cases.sh` + the edge scenario scripts)
**Affects:** the `Integration & E2E Tests` CI job (the "E2E: Run Edge Case Suite" step is the sole red after the Phase 6 cutover green-up)

---

## Summary

After the Phase 6 CI green-up (submodule token, engine/CLI image builds, Ryuk
disabled), the pipeline is green **except the edge-case suite**: Build & Lint,
Go Unit Tests, Unit Test Summary, "Boot Upsilon Services", and the centralized
customer scenarios all pass; only `E2E: Run Edge Case Suite` exits non-zero and
turns the job red.

The failures are overwhelmingly in the **scenarios** (the CLI e2e assertions and
their timing/setup), not in the **mechanics** the scenarios exercise — the Go
unit + feature suites that pin those mechanics are green. Several edge scenarios
assert behavior that no stack ever implemented, or flake on gameplay randomness
and token/latency timing. They should be reviewed as a batch and each one
classified and dispositioned, rather than left to redden every run.

## Known contributors (already filed, carried through the cutover)

- **ISS-102** — forfeit inside the engine's start-up window 400s
  (`game.not.in.progress`); exposed by SSE's lower latency, a scenario-timing
  issue.
- **ISS-103** — a privacy scenario asserts foe-loadout masking that neither
  Laravel nor the hub ever implemented (the assertion is wrong, not the code).
- **ISS-105** — token starvation when a fight idles past the 15-min sliding TTL;
  a scenario-runtime keepalive gap.
- **Friendly-fire flakes** — gameplay-randomness sensitivity in the fight
  scenarios (non-deterministic assertions).

## What to do

1. Run `run_all_edge_cases.sh` against the cutover stack and capture the full
   pass/fail list (CI artifact `integration-test-results` already uploads
   `edge_case_report.md` + `upsiloncli/tests/logs/edge_*.log`).
2. Classify each failing scenario:
   - **Stale/incorrect assertion** (asserts unimplemented or since-changed
     behavior — e.g. ISS-103) → fix or delete the assertion.
   - **Non-deterministic** (gameplay randomness, timing) → seed/pin or relax the
     assertion; or quarantine.
   - **Genuine mechanic bug** → file/keep a mechanic-level issue (these should be
     rare, since the Go suites are green).
3. Decide the **CI policy** until the audit lands: the edge-case step currently
   has no `continue-on-error` (unlike the customer-scenarios step), so any
   known-red scenario fails the whole pipeline. Either mark the step
   `continue-on-error` like its sibling, or split the known-red scenarios into a
   quarantined set so the green ones gate CI and the reds are tracked here.

## Notes

This is deliberately an audit/triage issue, not a single-bug fix — it supersedes
the ad-hoc "known-red, not a regression" notes scattered through the Phase 6
reports by giving the edge suite one owner and one disposition pass. Individual
mechanic bugs found during the audit get their own issues; ISS-102/103/105 stay
as-is and are folded into the disposition.
