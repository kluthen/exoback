# Issue: upsilonauth and upsiloneconomy unit tests are never executed by CI or local CI

**ID:** `20260826_auth_economy_unit_tests_not_run`
**Ref:** `ISS-132`
**Date:** 2026-08-26
**Severity:** High
**Status:** Resolved
**Component:** `.github/workflows/ci.yml`
**Affects:** `scripts/run_ci_local.sh`, `scripts/run_all_unit_tests.sh`, `upsilonauth/*`, `upsiloneconomy/*`

---

## Summary

The `go vet` and `go test` module lists in `.github/workflows/ci.yml` and `scripts/run_ci_local.sh` were never updated when `upsilonauth` and `upsiloneconomy` were extracted from the hub (Phase 3/4). Both commands still enumerate only the pre-extraction module set, so the 17 `_test.go` files that exist inside `upsilonauth`/`upsiloneconomy` are never run by `go test` anywhere in the pipeline. CI only builds these two services (`go build` + Dockerfile `--check`) and exercises them at the coarse docker-compose integration level — there is no unit-test safety net for identity/token logic, account push, seeding, or admin gateway code in either service.

---

## Technical Description

### Background

Every other Go module in the umbrella (`upsilonapi`, `upsiloncli`, `upsilonbattle`, `upsilonhub`, `upsilonmapdata`, `upsilonmapmaker`, `upsilontools`, `upsilontypes`, and in `ci.yml` also `upsilonplatform`) is vetted and unit-tested in both the GitHub Actions workflow and the local CI mirror script. `go.work` lists `upsilonauth` and `upsiloneconomy` as workspace modules alongside the others, and both contain real Go unit tests.

### The Problem Scenario

```
.github/workflows/ci.yml:38   (go vet)
  ./upsilonapi/... ./upsiloncli/... ./upsilonbattle/... ./upsilonhub/...
  ./upsilonmapdata/... ./upsilonmapmaker/... ./upsilontools/... ./upsilontypes/...
  ./upsilonplatform/...
                                              ^ no ./upsilonauth/... or ./upsiloneconomy/...

.github/workflows/ci.yml:110   (go test)
  ./upsilonapi/... ./upsiloncli/... ./upsilonbattle/... ./upsilonhub/...
  ./upsilonmapdata/... ./upsilonmapmaker/... ./upsilontools/... ./upsilontypes/...
  ./upsilonplatform/...
                                              ^ same omission

scripts/run_ci_local.sh:214,247   (go vet / go test)
  same 8-module list, missing upsilonauth, upsiloneconomy, AND upsilonplatform
  (this script also skips the `go build` step ci.yml does have for auth/economy)

scripts/run_all_unit_tests.sh
  go test ./upsilonapi/... ./upsilonbattle/... ./upsiloncli/... ./upsilonhub/...
          ./upsilonmapdata/... ./upsilonmapmaker/... ./upsilontools/... ./upsilontypes/...
                                              ^ same omission (dev convenience runner)
```

Net effect: a regression introduced inside `upsilonauth/internal/identity/token.go` (or any other unit-tested file in either service) can only be caught if it happens to also break the docker-compose integration/E2E scenario suite. A logic bug with adequate unit-test coverage but no user-visible integration symptom ships silently.

### Where This Pattern Exists Today

- `.github/workflows/ci.yml:38` (vet), `:110` (test) — missing `./upsilonauth/...`, `./upsiloneconomy/...`
- `scripts/run_ci_local.sh:214` (vet), `:247` (test) — missing all three: `./upsilonauth/...`, `./upsiloneconomy/...`, `./upsilonplatform/...`
- `scripts/run_all_unit_tests.sh` — same three missing
- Confirmed orphaned test files (never run by any `go test` invocation in the repo):
  - `upsilonauth/internal/identity/token_test.go`
  - `upsilonauth/internal/identity/pg_registrations_test.go`
  - `upsilonauth/internal/identity/registrations_test.go`
  - `upsilonauth/internal/accountpush/producing_test.go`
  - `upsilonauth/internal/accountpush/accountpush_test.go`
  - `upsilonauth/internal/accountpush/hubclient_test.go`
  - `upsilonauth/internal/accountpush/integration_test.go`
  - `upsilonauth/internal/seed/seed_test.go`
  - `upsilonauth/internal/gateway/admin_test.go`
  - `upsilonauth/internal/gateway/introspect_test.go`
  - (plus additional `upsiloneconomy` test files — full count 17 across both services)

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | High — any future change to auth/economy internals silently loses unit coverage |
| Impact if triggered | High — auth owns tokens/identity/session revocation (see ISS-130 for a live symptom of this class); economy owns wallet/ledger correctness |
| Detectability | Low — `go vet`/`go test` report green in both CI and local CI even though these packages are untouched; only a docker-compose-level scenario failure (or none, if the bug isn't integration-visible) would surface it |
| Current mitigant | docker-compose integration stage builds and runs both services end-to-end, and `ci.yml` at least `go build`s them (local CI doesn't even do that) |

---

## Recommended Fix

**Short term:** Add `./upsilonauth/...` and `./upsiloneconomy/...` to the `go vet` and `go test` module lists in `.github/workflows/ci.yml` (lines 38, 110) and `scripts/run_ci_local.sh` (lines 214, 247); also add `./upsilonplatform/...` to `run_ci_local.sh` to match `ci.yml`. Add all three to `scripts/run_all_unit_tests.sh`.

**Medium term:** Add a `go build` step for auth/economy in `run_ci_local.sh` to match `ci.yml`'s build stage, so the local CI mirror doesn't diverge from the real pipeline.

**Long term:** Derive the module list programmatically from `go.work` (e.g. `go list -m` or parsing the `use ()` block) in all three scripts/workflows instead of hand-maintaining a duplicated literal list in three places — this is the second time module extraction has caused this list to drift (see ISS-123 for a related host-script drift after the same extraction).

---

## Extra Data

Verified via direct inspection: `go.work` includes `./upsilonauth` and `./upsiloneconomy` as workspace modules; `find upsilonauth upsiloneconomy -name "*_test.go"` returns 17 files; `grep -n -i "auth\|economy" scripts/run_ci_local.sh` returns no matches at all (the script never mentions either service by name).

---

## References

- `.github/workflows/ci.yml:38,49-64,110,176,235-238`
- `scripts/run_ci_local.sh:206-260`
- `scripts/run_all_unit_tests.sh`
- `go.work`
- Related: [ISS-123](ISS-123_20260724_host_side_ci_seed_scripts_superseded.md) (host-side CI scripts drifted after the same 6-image extraction), [ISS-130](ISS-130_20260819_revoked_token_not_rejected.md) (live auth-layer defect of the kind unit tests in this area would be expected to catch; note ISS-130 has since been corrected on record — see its own file — but the general point that this area lacked unit coverage stands)

---

## Resolution (2026-08-26)

**Status changed Open -> Resolved.** This file asserted that `upsilonauth` and `upsiloneconomy`
unit tests were absent from every executed test set (CI, local CI mirror, and the dev convenience
runner). That gap has been closed: `./upsilonauth/...` and `./upsiloneconomy/...` are now included
in the `go vet` / `go test` invocations this file identified as missing them, and the 17
previously-orphaned `_test.go` files listed above now execute as part of the run. No premise in
this file was wrong — it is closed out as fixed per the short-term recommendation above, not
corrected.
