---
id: mech_move_validation_move_validation_entity_collision
human_name: Entity Collision Rule
type: MECHANIC
version: 1.0
status: DRAFT
priority: CORE
tags: []
parents: 
  - [[mech_move_validation]]
dependents: []
---

# Entity Collision Rule

## INTENT
The final destination node must not be currently occupied by another entity.

## THE RULE / LOGIC
entity.path.occupied

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[mech_move_validation_move_validation_entity_collision]]`
