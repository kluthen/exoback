# Issue: `bootstrapBot`'s single-slot teardown hook silently drops cleanup for the first of two bots in one agent

**ID:** `20260710_bootstrapbot_teardown_hook_overwrite`
**Ref:** `ISS-114`
**Date:** 2026-07-10
**Severity:** Low
**Status:** Open
**Component:** `upsiloncli/internal/script/bridge_battle.go` (`jsBootstrapBot`, `Agent.GoTeardownHook`)
**Affects:** Any CLI scenario that calls `upsilon.bootstrapBot(...)` more than once in the same agent — confirmed in `upsiloncli/tests/scenarios/edge_equip_unowned_character.js`, `edge_skill_unowned_character_equip.js`, `edge_skill_unowned_character_roll.js` (all "victim/owner + attacker" two-account patterns)

---

## Summary

`jsBootstrapBot` (`bridge_battle.go:231-296`) assigns `a.GoTeardownHook` as a plain closure field on the `Agent` struct — a single slot. When a script calls `bootstrapBot` twice (e.g. register a "victim"/"owner" account, then register an "attacker" account to exercise a cross-account rejection), the second call **overwrites** the first call's teardown closure. At script end, `coordinator.go:118-121` invokes only the surviving (second) closure.

Worse, the surviving closure doesn't even reliably clean up the account named in its own log line: `safeCall("auth_delete", nil)` deletes whichever account is **currently authenticated in the session** at teardown time (self-service GDPR delete, no target-account param), not necessarily the account captured in the closure. In practice this means: whichever account the script is authenticated as *last* (immediately before teardown fires) gets deleted; the other bootstrapped account is permanently orphaned in the DB, and the teardown log line can misreport which account was actually deleted.

## Technical Description

### Background
`bootstrapBot(accountName, password)` sets `a.GoTeardownHook` to a closure that calls `matchmaking_leave` → `game_forfeit` (if a match is active) → `auth_delete`, then registers the named account. `coordinator.go` runs `agent.GoTeardownHook()` once per agent at scenario end.

### The Problem Scenario
1. Script calls `bootstrapBot(accountA, passA)` → `GoTeardownHook` = "clean up + delete current session" (closure logs "Deleting temporary account: A").
2. Script calls `bootstrapBot(accountB, passB)` → `GoTeardownHook` is **reassigned**, closure now logs "Deleting temporary account: B". A's cleanup closure is discarded entirely.
3. Script does work as B, then `auth_login`s back to A and finishes the scenario authenticated as A.
4. At teardown, the surviving (B-labeled) closure's `auth_delete` call fires — but it operates on the **current session**, which is A. Net effect: **A gets deleted, log says "Deleting temporary account: victim_..." (B)**, and **B is never deleted** — permanently orphaned in the `users` table (confirmed live: `deleted_at` stayed NULL for the never-cleaned account after 3 live runs of a reproduction case).

### Where This Pattern Exists Today
- `upsiloncli/internal/script/bridge_battle.go:231-296` (`jsBootstrapBot`) — single-slot `a.GoTeardownHook` field.
- `upsiloncli/internal/script/agent.go:29-30` — `TeardownHook`/`GoTeardownHook` fields.
- `upsiloncli/internal/script/coordinator.go:118-125` — invokes both hooks once each, unconditionally.
- Reproduced live against `edge_equip_unowned_item.js`'s original two-account setup (register A via `bootstrapBot`, then B via a second `bootstrapBot` call): after a passing run, `SELECT account_name, deleted_at FROM users WHERE account_name IN ('thief_...','victim_...')` showed the *thief* (A, first-bootstrapped) row anonymized/`deleted_at` set, and the *victim* (B, second-bootstrapped) row still fully live — despite the teardown log claiming "Deleting temporary account: victim_...". The scenario file itself has since been reverted to *not* double-`bootstrapBot` (manual `auth_register` for B instead) to sidestep this, at the cost of B still never being cleaned up either way.

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | High — deterministic, fires on every run of any scenario using two `bootstrapBot` calls (or one `bootstrapBot` + one manual `auth_register` for a throwaway second account, which never gets any cleanup at all) |
| Impact if triggered | Low — leaked rows are test/CI throwaway accounts (`thief_*`, `victim_*`, `owner_*`, `attacker_*` etc.), not real user data; but every CI run of the ~3-4 affected scenarios permanently grows the `users`/`characters`/`character_inventory` tables and the misleading teardown log line makes the leak hard to notice from logs alone |
| Detectability | Low — the teardown log line actively misreports which account was cleaned, so this is invisible without a direct DB check |
| Current mitigant | None; scenarios currently either double-`bootstrapBot` (leaks the non-final account) or manually `auth_register` the second account (leaks it unconditionally, no teardown hook registered at all) |

---

## Recommended Fix

**Short term:** Document the constraint (one `bootstrapBot` call per agent; use manual `auth_register`/`auth_delete` pairs for extra throwaway accounts, deleting each explicitly while still authenticated as it, before switching sessions).

**Medium term:** Change `Agent.GoTeardownHook` from a single closure field to a slice (`[]func()`), and have `jsBootstrapBot` append rather than assign. `coordinator.go` runs all of them at teardown. Each closure should capture and restore its own session token before calling `auth_delete`, rather than relying on "whatever is currently authenticated."

**Long term:** Give the CLI harness an explicit multi-account bookkeeping primitive (e.g. `upsilon.registerCleanupAccount(token)`), so any account created via any path (bootstrapBot or manual register) is guaranteed torn down regardless of call order or final session state.
