---
id: uc_match_resolution
human_name: Match Resolution Use Case
type: USECASE
version: 1.0
status: REVIEW
priority: CORE
tags: [combat, resolution, progression]
parents:
  - [[module_game]]
  - [[spec_match_format]]
dependents:
  - [[rule_progression]]
  - [[entity_player]]
---

# Match Resolution Use Case

## INTENT
End-to-end narrative of a game concluding, winner detection, match persistence, and the progression reward flow.

## THE RULE / LOGIC
1. During a normal combat turn, an attack reduces a character's HP to 0 or below.
2. The Go backend checks the victory condition: are all characters on the opposing team at 0 HP? (`spec_match_format`)
3. If yes: the match is concluded. The backend emits a "Match End" event with the winning team designation.
4. Laravel persists the match outcome to the `match_history` and `match_participants` tables. (`data_persistence`)
5. Laravel updates `total_wins` for all winning players and `total_losses` for all losing players.
6. Winning players are presented with a Progression reward screen.
7. The player allocates 1 Attribute Point to any character in their roster (HP, Attack, or Defense) — or defers it if thresholds allow (`rule_progression`).
8. Movement upgrade is only available if the player's win count is a multiple of 5.
9. All clients are redirected back to the Dashboard (`ui_dashboard`).

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[uc_match_resolution]]`
- **Test Names:** `TestUCMatchResolutionWinDetection`, `TestUCMatchResolutionProgression`

## EXPECTATION (For Testing)
- All enemy HP reach 0 -> Win event emitted -> Match persisted -> Win counter incremented -> Point allocation screen shows.
- Player tries to upgrade Movement at 3 wins -> Rejected.
