# Issue: ~87 E2E scenarios never call `battle_enroll` directly — a systematic Phase-4 staleness class

**ID:** `20260826_e2e_scenarios_skip_battle_enroll_class`
**Ref:** `ISS-138`
**Date:** 2026-08-26
**Severity:** Medium
**Status:** Open
**Component:** `upsiloncli` E2E scenario suite (`upsiloncli/tests/scenarios/`)
**Affects:** Any scenario using raw `auth_register` without `battle_enroll` or `upsilon.bootstrapBot`; `upsilonhub/internal/gateway/profile.go`, `upsilonhub/internal/gateway/enroll.go`

---

## Summary

This is filed as a **class**, not a single instance: ISS-130 turned out to be the first observed
case of it, misfiled for weeks as a security bypass when the actual cause was a missing
enrollment step. The Phase-4 cutover split account creation and game enrollment into two separate
steps, but only **10 of 97** scenarios call `battle_enroll` directly. The other ~87 are fine today
only because they route through `upsilon.bootstrapBot`, which happens to call enroll internally.
Any scenario that uses raw `auth_register` without going through enroll (directly or via
`bootstrapBot`) is silently stale and will fail with a confusing auth/permission-shaped error
rather than an honest "not enrolled" error. Filing this now so the remaining instances get found
by a deliberate audit sweep instead of surfacing one at a time as false alarms.

---

## Technical Description

### Background

Before the Phase-4 cutover, `auth_register` implicitly gave an account everything it needed
(characters, registrations) to use battle immediately. Post-cutover, `auth_register` mints an
account + token **only** — no characters, no registrations. Binding an account to a game is now an
explicit, additive-only opt-in step: `GET /api/v1/games` catalog -> the game's own enroll endpoint
-> roster.

### The Problem Scenario

```
scenario                          hub
────────                          ───
auth_register ──────────────────► account + token minted (no characters, no registrations)
profile_get ("GET /api/v1/profile") ─► battle-scoped, reads player_stats read model
                                   player_stats row only exists after POST /battle/enroll
                                   (upsilonhub/internal/gateway/enroll.go:46-79)
                                   no row -> playerstats.ErrNotFound
                                   -> deliberate 404 (profile.go:48-51)
upsilon.call throws on success:false envelope (bridge.go:133-154)
                                   scenario aborts here, looking like an auth/permission failure
```

Exposure count: only 10 of 97 scenarios call `battle_enroll` directly. The remaining ~87 rely on
`upsilon.bootstrapBot`, which does call it internally
(`upsiloncli/internal/script/bridge_battle.go:307`) and are therefore fine *today*. The risk is
structural, not that anything is currently broken: any scenario written or edited to use raw
`auth_register` without going through `bootstrapBot` or an explicit enroll call will silently
regress into this class, and the resulting failure looks like an auth/permission bug rather than a
missing-setup bug.

### Concrete Confirmed Instance

`edge_auth_session_timeout.js` is exactly this pattern: it dies at line 22 on its very first
`profile_get`, made with a fresh, genuinely valid token right after `auth_register` — it never
reaches the logout step it claims to be testing. This is why ISS-130 was misfiled as a security
bypass for weeks: the 404 "not enrolled" response was misread as a 401-vs-404 auth-layer defect
when the account simply had never enrolled.

### Where This Pattern Exists Today

- `upsilonhub/internal/gateway/enroll.go:46-79` — `battle_enroll`, the only path that creates the
  `player_stats` row.
- `upsilonhub/internal/gateway/profile.go:48-51` — the deliberate 404 (`playerstats.ErrNotFound`)
  when no row exists; correct crash-early behavior, not a bug.
- `upsiloncli/internal/script/bridge.go:133-154` — `upsilon.call` throws on any `success:false`
  envelope, which is why the scenario aborts rather than surfacing a distinguishable "not
  enrolled" signal.
- `upsiloncli/internal/script/bridge_battle.go:307` — `upsilon.bootstrapBot`, the path that
  happens to call enroll and is why ~87 scenarios are unaffected today.
- `upsiloncli/tests/scenarios/edge_auth_session_timeout.js:22` — confirmed concrete instance.

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | Medium — any new or edited scenario using raw `auth_register` without enroll/bootstrapBot reintroduces this; already happened once (ISS-130's scenario) |
| Impact if triggered | Medium — no real defect, but wastes significant investigation time because the failure shape (404 from a profile call) reads as an auth/permission bug rather than a setup bug |
| Detectability | Low — the current 404 message does not distinguish "not enrolled" from other auth-adjacent failures loudly enough to prevent misdiagnosis, as demonstrated by ISS-130 |
| Current mitigant | `upsilon.bootstrapBot` covers ~87 of 97 scenarios by construction, not by an enforced rule |

---

## Recommended Fix

**Short term (suggestions, not decisions):**
1. Audit sweep of all 97 scenarios to enumerate every remaining raw `auth_register` call site not
   covered by `bootstrapBot` or an explicit `battle_enroll`, so the other instances are found
   deliberately rather than one at a time as false alarms.
2. Make the battle-scoped 404 self-describing (e.g. an explicit `error_key` or message distinct
   from generic auth failures) so a missing enrollment is unmistakable at the point of failure
   instead of being misread as an auth-layer defect.

**Medium term:** Consider a lint/CI check that flags new scenario files calling `auth_register`
without a corresponding enroll call in the same file, to prevent regression into this class going
forward.

---

## References

- `upsilonhub/internal/gateway/enroll.go:46-79`
- `upsilonhub/internal/gateway/profile.go:48-51`
- `upsiloncli/internal/script/bridge.go:133-154`
- `upsiloncli/internal/script/bridge_battle.go:307`
- `upsiloncli/tests/scenarios/edge_auth_session_timeout.js:22`
- Related: [ISS-130](ISS-130_20260819_revoked_token_not_rejected.md) — the first observed instance
  of this class, corrected on record to reflect the real (missing-enrollment) cause.
