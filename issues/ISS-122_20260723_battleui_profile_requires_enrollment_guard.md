# Issue: battleui reads /api/v1/profile after login without enrolling — now 404s under the game-agnostic model

**ID:** `20260723_battleui_profile_requires_enrollment_guard`
**Ref:** `ISS-122`
**Date:** 2026-07-23
**Severity:** Medium
**Status:** Open
**Component:** `upsilonbattleui/src` (post-login flow)
**Affects:** freshly-registered accounts viewing the SPA before enrolling in battle

---

## Summary

Phase-4's game-agnostic remodel makes `GET /api/v1/profile` **battle-scoped**:
registration (now served by upsilonauth) creates only the account+token; the
battle-specific `player_stats` row and roster are provisioned lazily by
`POST /api/v1/battle/enroll`. Per the maintainer decision of 2026-07-23, the hub
`getProfile` handler returns a clean **HTTP 404 ("You are not enrolled in
battle.")** for an account with no `player_stats` row (previously it panicked
into a 500; see the `phase4-player-stats` fix). The upsiloncli E2E was updated to
enroll before reading `/profile` (`e2e_customer_login`).

The **battleui SPA** (currently on `main`, not yet phase-4-adapted) still calls
`profile_get` in its post-login flow without any enroll step or 404 guard. Once
the Phase-4 cutover ships, a freshly-registered user who reaches a profile view
before enrolling will hit a 404 the SPA does not handle.

---

## Technical Description

- Hub contract (post-fix): `GET /api/v1/profile` → 200 with roster+stats+credits
  when enrolled; **404** when the caller has no `player_stats` row.
- battleui consumes `/profile` (and the roster) assuming it always resolves — a
  hangover from the Laravel era where the `users` row carried stats for every
  registered account.

## Recommended Fix (battleui phase-4 integration)

One of, decided during battleui's phase-4 auth adaptation:
1. **Enroll-on-entry:** the SPA calls `battle/enroll` (idempotent-forward) as part
   of the register/login-into-battle flow, mirroring `upsilon.bootstrapBot` and
   `e2e_customer_onboarding` — then `/profile` always resolves.
2. **Guard + route:** treat 404 from `/profile` as "not enrolled" and route the
   user to an enroll/onboarding step instead of surfacing an error.

Option 1 matches the canonical journey (register → login → **enroll** → play) and
is the least surprising.

## Scope note

This is part of the broader, still-pending **battleui phase-4 auth adaptation**
(login/register/admin all moved to upsilonauth; admin registry envelope is now
`{items, has_more, next_cursor}`). battleui was intentionally left out of the
2026-07-23 atomic cutover branch set (auth/hub/cli); resolve this alongside that
adaptation, not before.

## References

- Hub fix: `upsilonhub/internal/gateway/profile.go` `getProfile` (branch `phase4-player-stats`)
- CLI parity: `upsiloncli/tests/scenarios/e2e_customer_login.js` (branch `phase4-infra-cli`)
- Related: [[game-agnostic-accounts-remodel]], ISS-118 (per-game GDPR export), the auth admin-registry envelope change (branch `phase4-auth-cutover-authside`)
- SPA consumers: `upsilonbattleui/src/Pages/Admin/UserManagement.vue`, profile/roster views
