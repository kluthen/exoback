---
id: mech_move_validation_move_validation_path_adjacency
human_name: Path Adjacency Rule
type: MECHANIC
version: 1.0
status: DRAFT
priority: CORE
tags: []
parents: 
  - [[mech_move_validation]]
dependents: []
---

# Path Adjacency Rule

## INTENT
Each coordinate in the requested path array must be strictly adjacent to the previous one.

## THE RULE / LOGIC
entity.path.notadjascent, entity.path.notvalid

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[mech_move_validation_move_validation_path_adjacency]]`
