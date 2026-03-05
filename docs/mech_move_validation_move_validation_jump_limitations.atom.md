---
id: mech_move_validation_move_validation_jump_limitations
human_name: Jump Limitations Rule
type: MECHANIC
version: 1.0
status: DRAFT
priority: CORE
tags: []
parents: 
  - [[mech_move_validation]]
dependents: []
---

# Jump Limitations Rule

## INTENT
The Z-axis difference between any two adjacent steps in the path must not exceed the entity's Jump property.

## THE RULE / LOGIC
entity.path.notvalid

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[mech_move_validation_move_validation_jump_limitations]]`
