# Issue: New account shows 0 characters on the dashboard (SPA never calls battle/enroll)

**ID:** `20260801_new_account_dashboard_empty_roster`
**Ref:** `ISS-124`
**Date:** 2026-08-01
**Severity:** High
**Status:** Open
**Component:** `upsilonbattleui/src/Pages/Auth/Register.vue`
**Affects:** `upsilonhub/internal/gateway/enroll.go`, dashboard character roster display, new-user onboarding

---

## Summary

A freshly registered account shows 0 characters on the dashboard, persisting across login/logout, instead of the expected 3 starter characters each with a pending roll for their unique skill. Root cause: the SPA's registration flow never calls `POST /api/v1/battle/enroll`, so the account never gets its baseline roster generated.

---

## Technical Description

### Background

Per the Phase-4 game-agnostic account model (`enroll.go:1-6`), `auth_register` mints only an account + token — it has no roster, no `player_stats` row, and no `tactical` service registration. Games own enrollment: `POST /api/v1/battle/enroll` (`upsilonhub/internal/gateway/enroll.go:46`) is the endpoint responsible for calling `GenerateInitialRoster` (3 baseline characters, `upsilonhub/internal/platform/character/pg.go:39`) and recording the `tactical` registration. The handler's own doc comment describes this as "the act every bot/scenario runs once, right after register→login."

### The Problem Scenario

1. User submits the registration form (`upsilonbattleui/src/Pages/Auth/Register.vue:24-40`).
2. `submit()` calls `register(form.value)` then immediately `router.push('/dashboard')` (`Register.vue:29-30`) — no call to the enroll endpoint anywhere in between.
3. `grep -rn "battle/enroll\|/enroll" upsilonbattleui/src` returns **zero matches** — the enroll endpoint is never invoked from the SPA at all (not on register, not on login, not on dashboard mount).
4. The dashboard queries the roster, finds none (the account was never enrolled), and displays 0 characters. This state is durable (server-side, not a cache artifact), so it persists across login/logout — matching the reported symptom exactly.

### Where This Pattern Exists Today

- `upsilonbattleui/src/Pages/Auth/Register.vue:24-40` — registration submit handler, missing the enroll call.
- `upsilonhub/internal/gateway/enroll.go:46-80` — the enroll handler that must run before a roster exists.
- Not yet checked: whether the CLI (`upsiloncli`) calls enroll automatically as part of its register/login scenario helpers — user has not tested CLI for this account. If the CLI does call it and the SPA doesn't, this confirms the gap is SPA-only.

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | High — affects every new account created through the SPA, unconditionally |
| Impact if triggered | High — new players cannot access any battle features (no characters to field) until manually enrolled some other way |
| Detectability | High — immediately visible on first login as an empty dashboard |
| Current mitigant | None found in the SPA; bots/CLI scenarios reportedly enroll explicitly per `enroll.go`'s doc comment, but that path is unverified here |

---

## Recommended Fix

**Short term:** Call `POST /api/v1/battle/enroll` immediately after a successful `register()` (or after `login()`, to also backfill pre-existing un-enrolled accounts) in `Register.vue`'s `submit()`, before routing to `/dashboard`.

**Medium term:** Enroll on login instead of/in addition to register, so any account missing the `tactical` registration self-heals on next sign-in without a code change per game. The handler is already idempotent and safe to call repeatedly (`enroll.go:50-57`).

**Long term:** As more games are added, the dashboard/shell should probably enroll into every game the account isn't yet registered for on session start, rather than each Register/Login page needing to know about each game's enroll endpoint individually.
