# Issue: `go work sync` rewrites submodule `go.mod`/`go.sum` on every CI run — committed manifests have drifted from what the workspace resolves

**ID:** `20260826_go_work_sync_rewrites_submodule_gomod`
**Ref:** `ISS-134`
**Date:** 2026-08-26
**Severity:** Medium
**Status:** Open
**Component:** `go.work`
**Affects:** `upsilonauth/go.mod`, `upsilonauth/go.sum`, `upsiloneconomy/go.mod`, `upsiloneconomy/go.sum`, `upsilonhub/go.mod`, `upsilonhub/go.sum`, `.github/workflows/ci.yml`, `scripts/run_ci_local.sh`

---

## Summary

`go work sync` — an existing step in both `.github/workflows/ci.yml` (`:35`, `:105`) and `scripts/run_ci_local.sh` — pushes the workspace's resolved dependency versions back down into each member module's own `go.mod`/`go.sum`. Running it today **modifies tracked files inside three submodules**: `upsilonauth`, `upsiloneconomy`, and `upsilonhub`. That it changes anything at all is the finding: the committed manifests in those three submodules no longer describe what the umbrella workspace actually builds against.

This was discovered incidentally while fixing ISS-132 (resolved; file removed 2026-08-27); it is unrelated to that change and pre-dates it.

---

## Technical Description

### Background

In a Go workspace, `go.work` + `go.work.sum` decide which version of each shared dependency every member module actually compiles against. Each module's own `go.mod`/`go.sum` can be out of step with that resolution and nothing will complain, because workspace mode simply doesn't consult them for version selection. `go work sync` is the command that reconciles the two — writing the workspace's answer back into each module.

### The Problem Scenario

From a clean tree (all 13 submodules reporting 0 dirty), a single `go work sync` produces:

```
upsilonauth   go.mod | 11 +++++-----   go.sum | 12 ++++++++++
  + github.com/riverqueue/river v0.40.0            <- promoted from indirect to DIRECT
  - github.com/exaring/otelpgx v0.11.1 // indirect
  - github.com/golang-migrate/migrate/v4 v4.19.1 // indirect
  - github.com/lib/pq v1.10.9 // indirect
  - github.com/riverqueue/river/riverdriver/riverpgxv5 v0.40.0 // indirect
  + github.com/tidwall/{gjson,match,pretty,sjson}, go.uber.org/goleak // indirect

upsiloneconomy   go.mod | 2 ++   go.sum | 36 ------------------------
  + go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp v0.69.0 // indirect
  + golang.org/x/crypto v0.52.0 // indirect
  (go.sum loses 36 lines — the committed file carries stale surplus entries)

upsilonhub   go.mod | 9 +++++++++   go.sum | 12 ++++++++++
  + github.com/riverqueue/river v0.40.0            <- promoted from indirect to DIRECT
  + github.com/riverqueue/river/{riverdriver,rivershared,rivertype} v0.40.0 // indirect
  + github.com/tidwall/{gjson,match,pretty,sjson}, go.uber.org/goleak // indirect
```

`upsilonapi` and `upsilonplatform` are unaffected (0 dirty), so this is specific to the three services, not a workspace-wide condition.

The `river` promotion is the clearest signal: `upsilonhub` runs the durable credit-award worker on River (`upsilonhub/internal/awards/`), and `upsilonauth` uses River migrations in its test harness — yet neither `go.mod` declares River as a direct requirement. It resolves today only transitively, via `upsilonplatform`'s `jobs` package.

### Why It Matters

1. **CI mutates tracked files on every run.** Both pipelines run `go work sync` before building. On an ephemeral GH runner this is invisible, but locally it leaves three submodules dirty after any CI run — which, among other things, makes `scripts/push_all.sh` refuse to push them (it declines on a dirty tree by design).
2. **Workspace-mode verification may not match image builds.** `go vet`/`go test` run in umbrella workspace mode, resolving via `go.work`/`go.work.sum`. The service Dockerfiles do NOT use the umbrella workspace — each runs its own `go work init` over a narrow subset (`upsilonauth/Dockerfile:21`, `upsiloneconomy/Dockerfile:22`, `upsilonhub/Dockerfile:35`) and then `go mod download` against the module's committed manifests. Two different resolution inputs means what CI tests and what ships in the image are not guaranteed to be the same build.
3. **`contract_upsilon_contract` requires sub-projects to remain independently buildable.** A `go.mod` that under-declares its module's real direct dependencies is drift against that clause, whether or not it currently happens to build.

### What Was NOT Verified

Honest scope limit — this issue reports an observed condition, not a proven failure:

- **Docker image builds have NOT been shown to break.** They evidently succeed today, presumably because the missing requirements resolve transitively through `upsilonplatform`. The risk described in point 2 is structural, not a reproduced failure.
- Whether committing the synced manifests is safe has not been tested — it may cascade into submodule CI, and each submodule is an independent repo with its own pipeline.
- Which commit introduced the drift was not bisected. The Phase 3/4/5 auth/economy extraction is the obvious suspect, given only the three extracted/refactored services are affected.

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | High that the drift persists and grows; unknown that it causes a build/runtime divergence |
| Impact if triggered | Medium-High — a service image built against different dependency versions than the code CI verified |
| Detectability | Very Low — workspace mode never consults these files, so everything reports green |
| Current mitigant | Transitive resolution via `upsilonplatform` appears to cover the gaps today |

---

## Recommended Fix

**Short term:** Run `go work sync` once, review the resulting diffs, and commit the reconciled `go.mod`/`go.sum` in `upsilonauth`, `upsiloneconomy`, and `upsilonhub` — each in its own submodule commit. Verify each service's Docker image still builds afterward.

**Medium term:** Add a CI guard that fails the build if `go work sync` leaves the tree dirty (`git diff --exit-code` immediately after the existing sync step). That converts silent drift into a loud, immediate failure — the same principle applied to the module list in ISS-132.

**Long term:** Decide whether the service Dockerfiles should build against the umbrella workspace rather than reconstructing a narrow one, so image builds and CI verification share a single resolution source.

---

## References

- `.github/workflows/ci.yml:35,105` (the `go work sync` steps)
- `scripts/run_ci_local.sh` (`stage_build`, `stage_unit`)
- `upsilonauth/Dockerfile:18-26`, `upsiloneconomy/Dockerfile:19-27`, `upsilonhub/Dockerfile:25-44`
- `upsilonhub/internal/awards/` (River consumer), `upsilonplatform/jobs`
- Discovered during: ISS-132 (resolved; file removed 2026-08-27)
- Related: [ISS-123](ISS-123_20260724_host_side_ci_seed_scripts_superseded.md) — the same extraction produced host-script drift
