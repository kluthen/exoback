---
id: entity_character
human_name: Character Entity
type: MODULE
version: 1.0
status: STABLE
priority: CORE
tags: []
parents: []
dependents: []
---

# Character Entity

## INTENT
To aggregate the constituent rules of Character Entity.

## THE RULE / LOGIC
Defines the baseline stat block and attributes of a playable character unit.

Attributes:
* HP (on the board, in game only)
* Max HP
* Attack
* Defense
* Move
* Position (on the board, in game only): {x,y}
* Name
* ID
* Player ID (the player that owns this character, UUID assigned to that player for a game, in game only)

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[entity_character]]`
