---
id: mech_move_validation_move_validation_already_moved
human_name: Already Moved Rule
type: MECHANIC
version: 1.0
status: DRAFT
priority: CORE
tags: []
parents: 
  - [[mech_move_validation]]
dependents: []
---

# Already Moved Rule

## INTENT
The entity must not carry the HasMoved flag set to true.

## THE RULE / LOGIC
entity.movement.already

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[mech_move_validation_move_validation_already_moved]]`
