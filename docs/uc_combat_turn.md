---
id: uc_combat_turn
human_name: Combat Turn Use Case
type: USECASE
version: 1.0
status: REVIEW
priority: CORE
tags: [combat, turn, gameplay]
parents:
  - [[module_game]]
dependents:
  - [[mech_initiative]]
  - [[mech_action_economy]]
  - [[rule_friendly_fire]]
---

# Combat Turn Use Case

## INTENT
End-to-end narrative of a single character's active turn cycle from activation through to delay recalculation.

## THE RULE / LOGIC
1. System evaluates the initiative ticker for all characters in the sequence. The character with a value of `0` becomes active.
2. The board highlights the active character and starts the 30-second shot clock (`mech_action_economy`).
3. The active player selects one ore more actions:
   - **Move:** Character moves up to their Movement stat value in squares. Valid targets exclude impassable obstacles and characters. (`mech_board_generation`)
   - **Attack:** Player selects an enemy target (not a teammate — `rule_friendly_fire`) within attack range.
   - **Pass:** Player voluntarily ends turn.
4. All chosen actions have their Delay Costs accumulated.
5. Shot Clock expires: If no action is confirmed within 30 seconds, the system forces a Pass and applies a `+100` Delay penalty.
6. Turn ends. The character's next-turn timer is recalculated from the accumulated Delay Cost.
7. System re-evaluates the initiative sequence and activates the next character at `0`.

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[uc_combat_turn]]`
- **Test Names:** `TestUCCombatTurnFlow`, `TestUCCombatTurnTimeout`

## EXPECTATION (For Testing)
- Move + Attack selected -> Delay costs summed -> Character requeued at correct delay value.
- 30s pass with no action -> Auto-pass + +100 delay applied.
- Attack targeting allied unit -> Action blocked.
