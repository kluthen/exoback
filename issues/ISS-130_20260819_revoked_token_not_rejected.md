# Issue: Revoked/logged-out bearer token is not rejected at the auth layer

**ID:** `20260819_revoked_token_not_rejected`
**Ref:** `ISS-130`
**Date:** 2026-08-19
**Severity:** High
**Status:** Open
**Component:** `upsilonhub/internal/platform/identity` (auth client seam) / gateway middleware ordering
**Affects:** `upsiloncli/tests/scenarios/edge_auth_session_timeout.js`, any endpoint reachable after a revoked token, `[[req_security_token_ttl]]`

---

## Summary

`edge_auth_session_timeout` revokes a session token via `auth_logout`, then
reuses the now-dead token on `GET /api/v1/profile`. It expects a `401
Unauthorized`. Instead the request returns `404` with `"-- DEBUG MODE -- You
are not enrolled in battle."` — i.e. the request is treated as authenticated
and falls through to a battle-enrollment check instead of being rejected by
the auth layer. First observed in CI on 2026-08-19 (umbrella run
32230359259, commit `5a3e854`), the first CI execution to reach the E2E
suite since the Phase 4/5 auth/economy extraction was pushed.

---

## Technical Description

### Background

`auth_logout` calls `RevokeToken` in `upsilonauth`, deleting the token row.
Every subsequent authenticated request should hit `AuthenticateToken` and be
rejected identically whether the token is unknown, expired, or its owner
deleted (per `edge_auth_session_timeout.js`'s own comment, this is the same
code path a genuinely expired token exercises). A 404 "not enrolled in
battle" means some handler downstream of auth executed — i.e. the identity
check was skipped or a stale/positive result was used.

### The Problem Scenario

```
CLI                          hub (gateway)              upsilonauth
───                          ─────────────              ───────────
auth_register  ─────────────► ...                        create account+token
profile_get (fresh token) ──► AuthenticateToken ────────► 200 OK
auth_logout ─────────────────► ...                        RevokeToken (DeleteToken row)
profile_get (dead token) ───► ??? ─────────────────────► expected: reject (401)
                              actual: 404 "-- DEBUG MODE --
                              You are not enrolled in battle."
```

Full CI reproduction log: `upsiloncli/tests/logs/edge_auth_session_timeout.log`
(umbrella run 32230359259).

### Where This Pattern Exists Today

- `upsiloncli/tests/scenarios/edge_auth_session_timeout.js` — the EC-22
  scenario (`@test-link [[req_security_token_ttl]]`).
- `upsilonhub/internal/platform/identity/identity.go` — the hub's thin
  client seam to `upsilonauth` (introspection + 5s cache per prior session
  decisions — a stale cache entry serving a just-revoked token as valid is a
  plausible root cause, needs verification).
- Gateway middleware ordering / games-catalog "games never import games"
  composition (post ISS-124 enroll-driven roster, commit `8b329c6`) — the
  404 message text ("not enrolled in battle") suggests the request reached
  battle-module enrollment logic, implying auth middleware did not short
  -circuit it.

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | High — deterministic in CI, exercises the exact logout→reuse path |
| Impact if triggered | High — a logged-out/revoked session is not actually cut off; security boundary bypass |
| Detectability | High — clear 401-vs-404 mismatch, deterministic CI failure |
| Current mitigant | None known |

---

## Recommended Fix

**Short term:** Reproduce locally against the hub + upsilonauth stack, log
what `AuthenticateToken`/the identity client seam returns for the dead token
on this exact path, and confirm whether the 5s introspection cache is
serving a stale "valid" result.

**Medium term:** Ensure auth middleware runs and short-circuits with 401
before any game/enrollment-specific handler executes, for every route under
`/api/v1/*` that requires auth — audit gateway middleware ordering after the
Phase 4/5 extraction.

**Long term:** Add a fast invalidation path (or shorten/bypass the cache on
explicit logout) so revocation is immediately effective, and cover this with
a hub-side unit test using the fake clock (mirrors the existing
`token_renewal_test.go` coverage for TTL boundaries) rather than relying
solely on the CLI E2E scenario.

---

## Extra Data

- CI run: umbrella `32230359259`, commit `5a3e854e7743e68a59ed1102720865bc52c39747`,
  rerun after fixing an unrelated transient submodule-checkout race.
- This is the first CI run to reach the E2E suite since the Phase 4/5
  auth/economy extraction was pushed — the extraction's cutover runbook was
  never CI-verified before this.

---

## References

- `upsiloncli/tests/scenarios/edge_auth_session_timeout.js`
- `upsilonhub/internal/platform/identity/identity.go`
- `upsilonhub/internal/gateway/token_renewal_test.go`
- Related: ISS-105 (mid-fight 401 on stale-but-not-yet-expired token — the
  opposite direction of this bug)
