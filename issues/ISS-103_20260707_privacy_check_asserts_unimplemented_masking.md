# Issue: e2e_battle_starts_privacy_check asserts foe-loadout masking that no stack ever implemented

**ID:** `20260707_privacy_check_asserts_unimplemented_masking`
**Ref:** `ISS-103`
**Date:** 2026-07-07
**Severity:** Medium
**Status:** Open
**Component:** `upsilonhub/internal/games/battle/masking.go` (and formerly `battleui/app/Http/Resources/BoardStateResource.php`)
**Affects:** `upsiloncli/tests/scenarios/e2e_battle_starts_privacy_check.js`, board state served on `GET /api/v1/game/{id}` and SSE `board.updated` frames

---

## Summary

`e2e_battle_starts_privacy_check` asserts foe entities expose no
`equipped_skills` / `equipped_items` / `buffs`. Neither the Laravel
`BoardStateResource` nor its faithful Go port strips those fields — masking
only covers ids (`player_id`, `current_player_id`) and derived flags. The
engine has always included AI/foe skills in its board payloads (verified in
`game_state_cache` rows from 2026-06-18, pre-migration, and 2026-07-07), so
the assertion fails against both stacks. The scenario encodes the privacy
contract of ISS-077 ("enemy character skill details are hidden"), which is
designed but unimplemented. This is **not** a migration regression; the hub
port must not "fix" it silently either, or byte-parity with Laravel breaks
mid-cutover.

---

## Technical Description

### Background

Fog-of-war masking (`[[arch_api_id_masking_gateway]]`) rewrites board state
per viewer: is_self flags replace player ids, dead flags are derived, internal
metadata is stripped. Loadout fields pass through untouched for every entity,
own and foe alike.

### The Problem Scenario

1. Bot joins `1v1_PVE`, receives `match.found`, hydrates the board from
   `GET /api/v1/game/{id}` (cache-backed).
2. Every AI entity in the payload carries its two engine-generated
   `equipped_skills` (full effect/cost/targeting data).
3. Scenario assertion `!e.equipped_skills || e.equipped_skills.length === 0`
   fires: "PRIVACY VIOLATION: Foe … has visible skills".

DB evidence (shared cache = raw engine payload in both eras):

```
match created 2026-06-18 (Laravel era): AI entities n_skills = 2
match created 2026-07-07 (hub era):     AI entities n_skills = 2
```

### Where This Pattern Exists Today

- `upsilonhub/internal/games/battle/masking.go:18-95` — no loadout stripping
  (faithful to `BoardStateResource::toArray`).
- `upsiloncli/tests/scenarios/e2e_battle_starts_privacy_check.js:42-44` — the
  three loadout privacy assertions (added 2026-06-16, WP-A2 era).

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | Certain — fails on every run examining a board with AI entities |
| Impact if triggered | Medium — foe loadout intel leaks to clients; also a permanently red e2e scenario polluting suite signal |
| Detectability | High — deterministic assertion failure |
| Current mitigant | None |

---

## Recommended Fix

**Short term:** Decide the contract: either implement foe-loadout stripping in
`MaskBoardState` (one masking point now — the SSE edge and the game endpoint
both go through it) as a deliberate post-parity improvement, or relax the
scenario to WARN (like its stat-visibility check) until ISS-077 lands.

**Medium term:** Implement ISS-077's privacy rules (owned-skill inspection
only) and turn the scenario's warnings back into assertions.

**Long term:** Specify per-field visibility in the board-state ATD atom so
masking is driven by contract, not accretion.

---

## Extra Data

- Found during Phase 6 sub-phase A gates (2026-07-07): scenario fails through
  the hub (:8085); code + DB analysis shows Laravel served identical data.
- Companion pre-existing flakiness in the same gate run: the two
  friendly-fire scenarios ("could not reach an ally within 3 matches") are
  gameplay-randomness bound, unrelated to transport or masking.

---

## References

- `upsilonhub/internal/games/battle/masking.go`
- `battleui/app/Http/Resources/BoardStateResource.php`
- `upsiloncli/tests/scenarios/e2e_battle_starts_privacy_check.js`
- ISS-077 (skill inspection & privacy rules — the designed contract)
