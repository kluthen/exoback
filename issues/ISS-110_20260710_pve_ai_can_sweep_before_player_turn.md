# Issue: PVE AI Can Wipe the Player's Squad Before the Human Gets a Single Turn

**ID:** `20260710_pve_ai_can_sweep_before_player_turn`
**Ref:** `ISS-110`
**Date:** 2026-07-10
**Severity:** Medium
**Status:** Open
**Component:** `upsilonbattle/battlearena/ruler/turner/turner.go`, `upsilonbattle/battlearena/ruler/ruler.go`
**Affects:** Any `1v1_PVE` E2E scenario that requires the human player to survive to melee/act at least once (e.g. `edge_attack_already_acted.js`, EC-09; likely other `edge_attack_*` and `edge_movement_*` scenarios in the same family as ISS-108).

---

## Summary

Turn initiative in `1v1_PVE` matches is decided by a per-entity random delay (`tools.NewIntRange(1000, 1500).Random()`, `ruler.go:195`) with no relationship to team, player-controlled status, or any "human acts first" safeguard. Since the AI-controlled squad typically fields multiple entities against the player's, an unlucky independent draw (all AI delays sorting ahead of all player delays) lets the AI act repeatedly before the human ever reaches the front of the turn queue. Combined with deterministic, stat-based AI damage and no per-turn player-protection rule, this can — and empirically did, ~1/5 runs during the ISS-107 audit — wipe the player's entire squad before a single human turn, ending the match by round ~9 with `winner_team_id` = the AI team.

---

## Technical Description

### Background
Turn order is a delay-based priority queue: `Turner.AddEntity`/`NextTurn` (`upsilonbattle/battlearena/ruler/turner/turner.go`) sorts entities ascending by `CurrentDelay`. Initial delay is randomized independently per entity at `ruler.go:195` (production `AddEntity` path used for both human and AI entities) and `ruler.go:123` (test/complete-ruler path). Post-action delay increments are small and deterministic (`attack.go:92`: `+100`; `rules/move.go:73`: `+20*pathlen`), so a favorable initial draw compounds rather than self-correcting.

AI action selection runs through `AIController` (`controller/controllers/aggressive.go`) via a `LayeredBehavior` pipeline (`controller/behavior/pipeline.go`), with archetype micro-tactics (`controller/behavior/micro/*.go`). Damage (`rules/attack.go:74`) is deterministic and purely stat-based (Attack+WeaponDmg vs Defense+Armor); AI "Grade" (from `bridge_start_archetype.go:24-38`, human `TotalWins`-derived) only tunes tactic sophistication, not turn order or damage output.

### The Problem Scenario
```
1. Match starts; N AI entities + M player entities each get
   CurrentDelay = random(1000, 1500), independently.
2. Turner sorts ascending by CurrentDelay — pure luck of the draw.
3. If, by chance, every AI entity's delay < every player entity's delay,
   the AI squad acts first, repeatedly, before any player turn.
4. No safeguard exists: no "player acts first" rule, no damage cap,
   no minimum-turns-before-loss guarantee.
5. AI damage is deterministic/optimal once it acts → squad wipeout
   is likely once the AI has several uncontested turns.
6. Match ends, winner_team_id = AI team, human squad recorded 0 actions.
```
Observed during the ISS-107 audit (scenario `edge_attack_already_acted`): 1 of 5 baseline runs ended this way — 0 "Auto Action" logs for the human player, loss by round ~9.

### Where This Pattern Exists Today
- `upsilonbattle/battlearena/ruler/ruler.go:123,195` — independent per-entity random initial delay, no team/human bias.
- `upsilonbattle/battlearena/ruler/turner/turner.go` — pure delay-order queue, no fairness rule.
- `upsilonbattle/battlearena/ruler/rules/attack.go:74` — deterministic AI damage compounds an early-initiative advantage.
- Any `edge_attack_*`/`edge_movement_*` E2E scenario requiring the player to survive to act (same risk family as `[[ISS-108]]`, which is board-gen flakiness rather than initiative flakiness).

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | Medium — ~20% observed in a small sample (1/5); exact probability depends on squad sizes and delay range overlap. |
| Impact if triggered | Low (gameplay) / Medium (testability) — legitimate PVE outcome for players, but it silently fails any E2E scenario requiring the player to act at least once, without a diagnosable root cause unless logs are inspected. |
| Detectability | Low — presents as a generic scenario failure/timeout; only distinguishable from a real regression by checking "Auto Action" log count and `winner_team_id`. |
| Current mitigant | None. |

---

## Recommended Fix

**Short term:** Document the failure signature (0 "Auto Action" logs for the human, early AI-team win) in scenario runbooks so it's recognized as this known flake, not a regression, when it occurs during CI/audit runs.

**Medium term:** Add a deterministic or biased tie-break for initial turn order in `1v1_PVE` — e.g. guarantee the human player's first entity has the lowest `CurrentDelay` in the match, or narrow/desync the AI's random range slightly so pure-AI-sweep draws become vanishingly rare rather than ~1-in-5.

**Long term:** Consider a general "no-op prevention" safeguard (matching the spirit of `[[ISS-101]]`, which addressed silently auto-passed human turns) — e.g. a minimum-actions-before-loss floor for PVE matches, or expose a test-only seam to fix initiative deterministically for E2E scenarios, mirroring the test-seam direction already recommended in `[[ISS-108]]`/`[[ISS-109]]` for board generation.

---

## Extra Data

- Discovered incidentally while auditing `edge_attack_already_acted.js` (ISS-107 audit pass, wave 3): 4/5 baseline runs passed normally; 1/5 ended in a full player-squad wipeout with zero human turns before the fix was even applied, i.e. unrelated to the scenario's own logic.
- Distinct mechanism from `[[ISS-108]]` (board generation / obstacle adjacency) — this is initiative/turn-order RNG, not terrain RNG — but the same class of "PVE match randomness undermines deterministic E2E assertions" risk.
- Related to `[[ISS-101]]` (Resolved) — that issue closed a structural gap where human turns were silently auto-passed; this issue is a different mechanism (AI simply acts first, repeatedly, due to initiative RNG) with a similar symptom (human never gets to act).

---

## References

- `upsilonbattle/battlearena/ruler/ruler.go:123,195` (random initial delay)
- `upsilonbattle/battlearena/ruler/turner/turner.go` (`Turner.AddEntity`/`NextTurn`, delay-order queue)
- `upsilonbattle/battlearena/ruler/ruler_turn.go` (`advanceTurn`, `handTurn`)
- `upsilonbattle/battlearena/ruler/rules/attack.go:74,92` (deterministic damage, delay increment)
- `upsilonbattle/battlearena/controller/controllers/aggressive.go`, `controller/behavior/pipeline.go`, `controller/behavior/micro/*.go` (AI action selection)
- `upsilonapi/bridge/bridge_start_archetype.go:24-38` (AI Grade derivation)
- `upsiloncli/tests/scenarios/edge_attack_already_acted.js` (scenario where this was observed)
- Related: `[[ISS-108]]`, `[[ISS-109]]` (board-gen/testability RNG family), `[[ISS-101]]` (Resolved — related but distinct "human never acts" symptom)
