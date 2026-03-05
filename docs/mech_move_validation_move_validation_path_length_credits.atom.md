---
id: mech_move_validation_move_validation_path_length_credits
human_name: Path Length / Credits Rule
type: MECHANIC
version: 1.0
status: DRAFT
priority: CORE
tags: []
parents: 
  - [[mech_move_validation]]
dependents: []
---

# Path Length / Credits Rule

## INTENT
The total length of the path array must not exceed the current available Movement credits remaining for the entity.

## THE RULE / LOGIC
entity.path.too.long, entity.movement.nocredits, entity.movement.credits

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[mech_move_validation_move_validation_path_length_credits]]`
