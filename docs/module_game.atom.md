---
id: module_game
human_name: TRPG Game Module
type: MODULE
version: 1.0
status: REVIEW
priority: CORE
tags: [game, core]
parents: []
dependents:
  - [[spec_match_format]]
  - [[mech_initiative]]
---

# TRPG Game Module

## INTENT
Defines the overarching tactical RPG game flow, from initial start state to completion.

## THE RULE / LOGIC
- State Definition: A game session consists of an active board, participants (players and AI), and a combat loop.
- Start State: Characters are deployed to the board. Initiative is rolled mathematically for all participants to determine the first acting character.
- Combat Loop: Characters take turns based on their evaluated initiative value. Character performs actions (move, attack, pass), incurring delay costs that recalculate their next turn.
- End State: The game concludes when the victory condition is met (a team is entirely overcome).

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[module_game]]`
- **Test Names:** `TestGameInitialization`, `TestGameCombatLoop`

## EXPECTATION (For Testing)
- Game starts -> Initiative is rolled for all entities -> Turn loop begins.
- All enemies defeated -> Game enters End State.
