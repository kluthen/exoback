# Issue: `run_ci_local.sh` booted the stack without `--build`, silently testing five-week-old images — every prior local E2E result is unreliable

**ID:** `20260826_local_ci_reuses_stale_docker_images`
**Ref:** `ISS-135`
**Date:** 2026-08-26
**Severity:** High
**Status:** Resolved
**Component:** `scripts/run_ci_local.sh`
**Affects:** `scripts/run_ci_local.sh`, `docker-compose.ci.yaml`, every local E2E result produced before 2026-08-26

---

## Summary

`scripts/run_ci_local.sh` booted the integration stack with `docker compose up -d --wait` and no
`--build`. `docker compose up` only builds images that do not already exist locally; it never
rebuilds an existing one. Because this mirror is a long-lived developer machine rather than an
ephemeral CI runner, images persisted between runs, so the "local CI mirror" was running whatever
was last built — in the observed case, a hub image from **2026-07-20**, five weeks stale and
predating the Phase 4 auth cutover.

The result is worse than a false negative: the mirror returned a confident red/green signal that
described code nobody was running. This is the same failure family as ISS-132 (CI not executing
what it claims to execute), but with a broader blast radius, because it silently invalidates
historical results rather than merely omitting tests.

## Technical Description

### Background

`stage_integration` boots `docker-compose.ci.yaml`, which builds every service from local context
(`context: .`). The GitHub workflow is immune to this: `.github/workflows/ci.yml:205` runs
`docker image prune -af`, and hosted runners start cold, so compose necessarily builds from
scratch there. Only the local mirror keeps a warm image cache, and only the local mirror was
affected.

### The Problem Scenario

Observed on 2026-08-26 while running step 9 verification of the ISS-102/103/130/131 round, from a
`--fresh` clone of the just-pushed remote (umbrella `9801c13`, hub `0aac6f4`, api `9e5eb50`):

- Stage 1 (build) and stage 2 (unit) **passed** — they run against the clone's source directly and
  are unaffected.
- Stage 3 (integration) collapsed: **2 of 37 scenarios** and **8 of 51 edge cases** passed.

All 489 hub ERROR lines were a single route:

```
[/internal/v1/players/<uuid>/account] The route /internal/v1/players/<uuid>/account could not be found.
```

That is upsilonauth's AccountPush client (`upsilonauth/internal/accountpush/hubclient.go:38`)
calling a hub endpoint that returns 404. With no account push, the player_stats read model is never
populated, registration/login break, and effectively the whole suite cascades.

The route is not missing from source. It exists (`upsilonhub/internal/gateway/internal_consumer.go:38`),
its registrar is called (`upsilonhub/internal/gateway/router.go:109`), and both mount conditions
hold (`S2S_TOKEN=ci-internal-token` is set in `docker-compose.ci.yaml`; `PlayerStats` is
unconditionally non-nil at `upsilonhub/cmd/upsilonhub/main.go:181`).

The running container was simply not that code. Proof from `ci_logs/hub.log`, whose Gin route table
at boot registered:

```
[GIN-debug] POST /api/v1/auth/login    --> gateway.(*authAPI).login-fm
[GIN-debug] POST /api/v1/auth/register --> gateway.(*authAPI).register-fm
```

Those are in-hub account routes that the current source explicitly no longer mounts — `router.go`
states the account surface "moved to upsilonauth in the Phase 4 cutover ... the hub mounts none of
it". A pre-cutover hub also has no `mountInternal`, which is exactly the observed 404.

Image timestamps confirmed it directly:

```
upsilon-hub-ci-auth:latest      2026-08-26 14:39   <- new service, no cache, built fresh
upsilon-hub-ci-economy:latest   2026-08-26 14:39   <- new service, no cache, built fresh
upsilon-hub-ci-hub:latest       2026-07-20 09:27   <- REUSED, five weeks stale
```

The extracted services looked healthy precisely because they were new enough to have no cached
image, while the services that predated the extraction were served from cache.

### Why It Matters

Re-running the identical stage with `--build` and no other change produced **36/37 scenarios and
52/52 edge cases**, with exactly one hub ERROR in the entire suite (a deliberate malformed-UUID
probe from a passing edge case). The delta between 2/37 and 36/37 was entirely the image cache.

Consequences beyond the single run:
- Any local E2E result predating this fix may describe stale artefacts. Green results are not
  trustworthy evidence, and red results may have been chased as bugs that no longer existed.
- The failure is silent and gets *worse* with time, since the gap between cached and current
  widens on every commit.
- It disproportionately punishes architectural change. The extraction of auth/economy is exactly
  the kind of work this masks, because new services build fresh while changed old ones do not.

### A second, related gap found alongside it

The failure-path log collection loop still enumerated only the pre-extraction services:

```
for svc in hub-migrate hub-seed hub proxy engine db tester; do
```

`auth` and `economy` were absent, so an auth or economy failure left no evidence on disk at all —
which materially slowed the diagnosis above. `.github/workflows/ci.yml:258-261` already collects
both; the local mirror had drifted from the workflow, same drift class as ISS-132.

## Risk Assessment

**Severity: High.** No production impact — this is a verification-integrity defect. It is rated
High rather than Medium because it undermines the trustworthiness of the verification tooling
itself: a mirror that silently tests stale artefacts is more dangerous than no mirror, since it
manufactures unwarranted confidence. It also retroactively taints prior results, so the cost is
not bounded to the single run in which it was discovered.

GitHub CI is **not** affected, so no shipped artefact is implicated.

## Recommended Fix

Both parts applied on 2026-08-26:

1. `docker compose up -d --build --wait` in `stage_integration`, with a comment recording that
   `--build` is mandatory rather than an optimisation, and why (so it is not "tidied away" later
   by someone optimising run time).
2. Log-collection loop extended with `auth-migrate auth-seed auth economy-migrate economy-seed
   economy`, restoring parity with `ci.yml`.

Verified by re-running the stage: 2/37 -> 36/37 scenarios, 8/51 -> 52/52 edge cases, and
`auth.log` (341K) / `economy.log` now present in `ci_logs/` where previously they did not exist.

Follow-up worth considering, not done here: a cheap staleness guard that compares image creation
time against the checkout's HEAD commit date and warns loudly, so this class of drift is caught
even if `--build` is ever removed again.

## References

- ISS-132 — same family (CI not executing what it claims to execute); found in the same round.
- `scripts/run_ci_local.sh` — `stage_integration`.
- `.github/workflows/ci.yml:205` — `docker image prune -af`, why hosted CI is immune.
- `upsilonhub/internal/gateway/router.go:109`, `internal_consumer.go:38` — the route proven present in source.
- `upsilonauth/internal/accountpush/hubclient.go:38` — the caller that 404'd.
