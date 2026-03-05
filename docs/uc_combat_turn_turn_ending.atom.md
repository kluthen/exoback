---
id: uc_combat_turn_turn_ending
human_name: Turn Ending Logic
type: USECASE
version: 1.0
status: DRAFT
priority: CORE
tags: []
parents: 
  - [[uc_combat_turn]]
dependents: []
---

# Turn Ending Logic

## INTENT
End the turn by recalculating the next-turn timer

## THE RULE / LOGIC
Turn ends. The character's next-turn timer is recalculated from the accumulated Delay Cost.

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[uc_combat_turn_turn_ending]]`
