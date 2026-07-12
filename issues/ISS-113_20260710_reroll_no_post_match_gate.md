# Issue: Character Reroll Has No Post-Match Gate — Documented "Creation Flow Only" Availability Rule Is Unenforced

**ID:** `20260710_reroll_no_post_match_gate`
**Ref:** `ISS-113`
**Date:** 2026-07-10
**Severity:** Medium
**Status:** Open
**Component:** `upsilonhub/internal/gateway/profile.go` (`reroll` handler)
**Affects:** Any player who has already played a match and still has rerolls remaining (`reroll_count < 3`); `upsiloncli/tests/scenarios/edge_char_reroll_post_match.js` (EC-26) depends on this gate and, once corrected to call the right endpoint, fails deterministically because the gate does not exist.

---

## Summary

`upsilonbattle/docs/mech_character_reroll.atom.md` — the atom the `reroll` handler itself cites via `@spec-link` — documents the mechanic's **Availability** as: "the reroll is allowed only while the account is in the creation flow, after the initial 3 characters have been generated." The Go implementation (`profileAPI.reroll`, `upsilonhub/internal/gateway/profile.go:79-105`) only enforces two of the atom's three clauses: character ownership and the 3-attempt lifetime `reroll_count` cap. It has **no check at all** for match participation / "still in creation flow" — a character can be rerolled (stats reset to baseline, `spent_cp` zeroed) at any point in an account's lifetime, including after playing and losing/winning any number of matches, as long as `reroll_count < 3`.

Because `Character::rerollStats`/`Reroll` also zeroes `spent_cp` (`upsilonhub/internal/platform/character/pg_profile.go:47-68`), this is not just a documentation gap: a player who has earned wins, spent CP on stat upgrades (`upgrade` handler, same file), and played matches can still reroll (if they haven't used all 3 attempts) and get a full CP refund via the stat reset — a potential progression-economy exploit, not merely a cosmetic timing quirk.

---

## Technical Description

### Background
Per the atom doc, reroll is meant to be a new-account-only, pre-match convenience (re-randomize a starting roster you're unhappy with) — not a tool available throughout a player's active career.

### The Problem Scenario
```
1. Register account. reroll_count = 0. 3 starting characters.
2. POST /profile/character/{id}/reroll  → 200 OK (reroll_count → 1). Expected: allowed (still creation flow).
3. Join and complete a 1v1_PVE match (forfeit to end it quickly).
4. POST /profile/character/{id}/reroll  → 200 OK (reroll_count → 2).
   Expected per mech_character_reroll's Availability clause: rejected (no longer
   in creation flow).
   Actual: succeeds — character.go's Reroll() has no caller-side or
   handler-side check for match history/creation-flow state at all.
```
Confirmed live via the corrected `edge_char_reroll_post_match.js` CLI scenario, 2/2 deterministic runs, ~3-4s each: the post-match `character_reroll` call returns `200 "Character rerolled."` every time.

### Where This Pattern Exists Today
- `upsilonhub/internal/gateway/profile.go:79-105` (`reroll` handler) — checks only `char.PlayerID != user.ID` and `user.RerollCount >= 3`; no match/creation-flow check.
- `upsilonhub/internal/platform/character/pg_profile.go:47-68` (`Reroll` — stat reset, `spent_cp` zeroed unconditionally).
- `upsilonhub/internal/platform/identity/pg_admin.go:18-30` (`IncrementRerollCount` — pure counter bump, no gating logic either).
- Nothing in `identity.User` or `character.Character` tracks "has this account played a match yet" for this purpose (`total_wins`/`total_losses` exist but are never consulted by `reroll`).

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | Certain — reproduces every time, no RNG involved, as long as `reroll_count < 3`. |
| Impact if triggered | Medium — undermines the documented "new-player-only" framing of reroll, and doubles as a CP-refund exploit (reroll after spending CP on upgrades resets `spent_cp` to 0, effectively "banking" a free respec while keeping earned wins/credits). Bounded by the existing 3-attempt lifetime cap, so not unlimited. |
| Detectability | Low in normal play — a player who reads the reroll button as "always available a few times" wouldn't notice anything wrong; the gap only matters to players intentionally sequencing reroll after upgrades/matches. |
| Current mitigant | The 3-attempt lifetime cap bounds the blast radius; still allows the CP-refund pattern up to 3 times per account. |

---

## Recommended Fix

**Short term:** Confirm with design/gameplay owners whether the "creation flow only" availability clause is still an intended constraint (in which case this is a code gap) or was superseded by "reroll count is the only real gate" (in which case `mech_character_reroll.atom.md`'s Availability clause is stale and should be corrected/removed instead).

**Medium term:** If the creation-flow gate is intended, add a check in `reroll` (`profile.go:79`) — e.g. `if user.TotalWins+user.TotalLosses > 0 { reject }` or a dedicated `HasPlayedMatch`/`onboarding_complete` flag on the user record — mirroring the ownership/limit checks already present.

**Long term:** Add a Go unit test (alongside `TestUserCannotRerollPastLimit` in `profile_test.go`) pinning the post-match rejection, so this class of "documented rule, unenforced code" gap is caught by CI going forward. `upsiloncli/tests/scenarios/edge_char_reroll_post_match.js` already covers this at the E2E layer post-correction but will fail until the gate is added.

---

## Extra Data

- Discovered during the ISS-107 CI edge-case audit while auditing `edge_char_reroll_post_match.js` (scenario #21). The scenario itself had an unrelated, more severe bug first: it called `character_rename` (a cosmetic name-change endpoint with no reroll semantics at all) instead of `character_reroll` for both its pre- and post-match calls, so it never exercised reroll in the first place. Worse, because `character_rename` has no restrictions either, the post-match call always succeeded (200), which threw the scenario's own `assert(false, "ERROR: Post-match reroll was accepted!")` — but that assert lived *inside* the same `try` block's enclosing `catch`, so the failure was silently swallowed and logged as "✅ Post-match reroll properly rejected: undefined" (the `.message` access on the raw thrown value was itself `undefined`). Same "assert-inside-its-own-catch" anti-pattern previously found and filed against `edge_auth_session_timeout` (scenario #19, wave 3).
- After fixing the scenario to call the correct `character_reroll` endpoint, the real availability gap described here became visible immediately and reproduces deterministically (2/2 runs).
- Sibling scenario `edge_char_reroll_limit` (#20, concurrent audit) covers the 3-attempt count cap, which — unlike the creation-flow gate — is correctly enforced (`TestUserCannotRerollPastLimit`, `profile_test.go:93-105`).

---

## References

- `upsilonhub/internal/gateway/profile.go:74-105` (`reroll` handler)
- `upsilonhub/internal/platform/character/pg_profile.go:47-68` (`Reroll`)
- `upsilonbattle/docs/mech_character_reroll.atom.md` (Availability clause, unenforced)
- `upsiloncli/tests/scenarios/edge_char_reroll_post_match.js` (scenario where this was surfaced, corrected as part of this filing)
- `issues/ISS-111_20260710_skill_cooldown_never_decrements.md` (same audit wave, same class of "documented behavior not enforced" defect)
