# Issue: CLI Harness Blocks Negative-Path Testing of Admin-Gated Endpoints

**ID:** `20260710_admin_negative_path_untestable_via_cli`
**Ref:** `ISS-112`
**Date:** 2026-07-10
**Severity:** Medium
**Status:** Open
**Component:** `upsiloncli/internal/script/bridge.go`
**Affects:** `upsiloncli/tests/scenarios/edge_auth_non_admin_access.js` (EC-17), likely `edge_admin_private_data_access.js` (EC-49, already flagged separately as an "ISS-103 candidate" in the ISS-107 tracker), and any future E2E scenario that needs to prove a non-admin caller is rejected by an admin-gated endpoint.

---

## Summary

`upsiloncli`'s scripting bridge hard-blocks any `admin_`-prefixed route call made outside of `upsilon.adminSection()` (`bridge.go:110`), and `adminSection()` only ever authenticates as the real seeded admin account — there is no scripting path to call an admin route while authenticated as a non-admin user. This makes the non-admin-rejection branch of admin-gated endpoints (e.g. `adminLogin()`'s `403 "Access denied. Administrative privileges required."`, `upsilonhub/internal/gateway/auth.go:100-103`) structurally unreachable via the CLI E2E harness, even though the production code itself is correct and behaves properly when exercised directly (verified via raw `curl`, bypassing the CLI). The branch also has zero Go unit-test coverage. Distinct from ISS-108/109 (board-gen RNG) and ISS-110 (initiative RNG): this is a **harness-imposed reachability gap**, not test flakiness.

---

## Technical Description

### Background
`upsiloncli` scripts route certain calls through `upsilon.adminSection()`, which authenticates internally as the seeded admin user before issuing `admin_*`-prefixed API calls, presumably to keep test scripts from accidentally leaking admin credentials or performing admin actions outside an explicit, clearly-marked block.

### The Problem Scenario
```
Scenario intent: prove a NON-admin, authenticated user is rejected (403)
                 when calling an admin-gated route (e.g. admin login /
                 admin-only resource).

Attempt:  upsilon.call("admin_login", {...non-admin credentials...})
Result:   bridge.go:110 rejects the call before it ever reaches the
          network — "unknown route" / harness-level block — because
          the call wasn't wrapped in adminSection(), and adminSection()
          itself only authenticates as the real admin.

Attempt:  upsilon.adminSection(() => upsilon.call("admin_login", ...))
Result:   adminSection() authenticates as the seeded admin FIRST —
          there is no way to make the call "as" a non-admin while
          still going through the admin-route path.

Net effect: no scripting path exists that reaches the server's
            non-admin-rejection code at all.
```
Verified deterministic (3/3 identical runs) — not a probability issue, a structural one. The server-side behavior was independently confirmed correct via raw `curl` (bypassing the CLI): `POST /api/v1/auth/admin/login` with valid non-admin credentials returns `403 "Access denied. Administrative privileges required."` (`auth.go:100-103`).

### Where This Pattern Exists Today
- `upsiloncli/internal/script/bridge.go:110` — hard block on `admin_`-prefixed routes outside `adminSection()`.
- `upsiloncli`'s `adminSection()` implementation — always authenticates as the real seeded admin, no non-admin-as-caller-of-admin-route mode.
- `upsilonhub/internal/gateway/auth.go:100-103` (`adminLogin()` non-admin branch) — correct, but zero E2E and zero Go unit coverage.
- Same root cause plausibly affects `edge_admin_private_data_access.js` (EC-49, `admin_users`/similar routes gated by `RequireAdmin()` middleware) — noted as a likely duplicate-cause "ISS-103 candidate" already tracked in the `ci_edge_case_reporting.md` audit tracker for Phase 10.

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | Certain — reproduces on every run, deterministically; not RNG-dependent. |
| Impact if triggered | Low (gameplay/prod correctness — the guarded code is independently verified correct) / Medium (testability) — an entire class of security-relevant negative-path behavior (admin gate rejects non-admins) has no automated regression coverage at any layer. |
| Detectability | Medium — the CLI harness fails cleanly with an "unknown route" style error, which could be mistaken for a passing rejection test if the scenario doesn't check the error's origin carefully (this is exactly what the original EC-17 scenario did, before this audit). |
| Current mitigant | None at the E2E layer. Server-side logic is correct per manual `curl` verification, but that isn't part of any automated suite. |

---

## Recommended Fix

**Short term:** Keep EC-17 rewritten to pin the one thing actually observable today — the CLI harness itself blocking the call — with an explicit header comment documenting that this only proves the *harness's* guard, not the *server's* rejection behavior. Do not claim server-side E2E coverage of the non-admin-rejection branch in any status report.

**Medium term:** Add a Go unit test directly against `adminLogin()`'s non-admin branch (`auth.go:100-103`) as interim coverage, independent of the CLI harness gap. Apply the same treatment to EC-49 if its root cause matches.

**Long term:** Add a scripting escape hatch to `upsiloncli` — e.g. an explicit `upsilon.callAsNonAdmin("admin_*", ...)` or a flag on `adminSection()` to authenticate as a specified (non-admin) session instead of always the seeded admin — so negative-path admin-gate testing becomes possible via true E2E, not just harness-level or unit-level substitutes.

---

## Extra Data

- Confirmed the original EC-17 scenario had a second, independent false-green mechanism unrelated to this harness gap: both catch blocks checked `e.status_code`, a field that never exists on any error thrown by the CLI (the bridge sets `status`, not `status_code`) — so even without the routing block, the assertions would never have fired.
- Route-name bug also found and fixed in the same scenario: it called a nonexistent `auth_admin_login` (real name `admin_login`) and a nonexistent `admin_dashboard` (never an API route, only a retired Vue page).

---

## References

- `upsiloncli/internal/script/bridge.go:110` (admin-route harness guard)
- `upsilonhub/internal/gateway/auth.go:82` (`adminLogin()` spec-link), `:100-103` (non-admin rejection branch, correct but uncovered)
- `upsiloncli/tests/scenarios/edge_auth_non_admin_access.js` (EC-17, rewritten during this audit)
- Related: `edge_admin_private_data_access.js` (EC-49) — tracked separately in `ci_edge_case_reporting.md` as an "ISS-103 candidate"; likely same root cause, to be confirmed when that scenario is audited.
