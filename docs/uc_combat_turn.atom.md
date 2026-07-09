---
id: uc_combat_turn
human_name: Combat Turn Use Case
type: USER_STORY
layer: ARCHITECTURE
version: 1.0
status: STABLE
priority: 5
tags: []
parents:
  - [[upsilonbattleui:req_player_experience]]
dependents:
  - [[us_api_flow_game_turn]]
  - [[us_take_combat_turn]]
  - [[upsilonbattle:mechanic_battle_startup_handshake]]
  - [[upsilonbattle:rule_turn_atomic_selection]]
  - [[upsilonbattle:rule_turn_clock]]
---
# Combat Turn Use Case

## INTENT
Governs the tactical interaction within a match, ensuring fair play and adherence to the action economy.

## THE RULE / LOGIC
1. **Initiative**: Turn order is dynamically calculated. The character with a value of `0` in the initiative ticker becomes active (`mech_initiative`).
2. **Action Selection**: The active player chooses between **Move** (up to Movement stat), **Attack** (against an enemy), **Pass**, or **Forfeit**.
3. **Shot Clock**: System starts a 30-second countdown. If no action is taken, a forced Pass (+300) and a penalty (+100) are applied (Total +400).
4. **Turn Conclusion**: Recalculates the next-turn timer from the accumulated Delay Cost and triggers a state check in **UC-5**.

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[uc_combat_turn]]`

## EXPECTATION (For Testing)
- Active character highlighted -> Timer counts down -> Action triggers delay cost calculation.
- Timer hits 0 -> Auto-pass and penalty applied.
- Forfeit terminates match via UC-5.

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[uc_combat_turn]]`
