---
id: uc_match_resolution
human_name: Match Resolution Use Case
type: USER_STORY
layer: ARCHITECTURE
version: 1.0
status: STABLE
priority: 5
tags: []
parents:
  - [[upsilonbattleui:req_player_experience]]
dependents: []
---
# Match Resolution Use Case

## INTENT
Evaluates the game state at the conclusion of each turn/action and handles the final match resolution.

## THE RULE / LOGIC
1. **Win Detection/Forfeit**: System identifies a victor when all characters on an opposing team reach 0 HP (per the [[spec_match_format]] win condition) or when a player **Forfeits** during UC-4.
2. **State Check (No Winner)**: If no win condition is met at the end of a character turn, the flow returns to **Combat Turn Management (UC-4)** for the next character's turn.
3. **Match Conclusion**: If a winner is detected:
   - System persists match history to the database (`match_history`, `match_participants`).
   - System awards the winner Character Points (CP) to spend through the point-buy progression system per [[rule_progression]] (no fixed per-win attribute point, no movement-every-5-wins gate).
4. **Transition**: Winning players see a Progression reward screen. All players can then transition to **Progression (UC-6)** or the **Dashboard**.

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[uc_match_resolution]]`

## EXPECTATION (For Testing)
- Victor detected -> Database entry created -> Progression points awarded.
- Forfeit action -> Immediate defeat applied to current turn holder.
- No winner -> Control returned to next character in initiative ticker.
