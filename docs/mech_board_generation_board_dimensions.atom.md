---
id: mech_board_generation_board_dimensions
human_name: Board Dimensions Mechanic
type: MECHANIC
version: 1.0
status: DRAFT
priority: CORE
tags: []
parents: 
  - [[mech_board_generation]]
dependents: []
---

# Board Dimensions Mechanic

## INTENT
Defines the constraints for the width and height of the board.

## THE RULE / LOGIC
Dimensions: The board is a standard grid (rectangle). Its width and height must each be randomly rolled between 5 and 15 tiles inclusive.

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[mech_board_generation_board_dimensions]]`
