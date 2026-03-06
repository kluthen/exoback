---
id: entity_grid
human_name: Grid Entity
type: ENTITY
version: 1.0
status: DRAFT
priority: CORE
tags: [spatial, map, 3d]
parents: []
dependents: []
---

# Grid Entity

## INTENT
To manage a 3D spatial collection of cells, providing utilities for navigation, entity placement, and layout management.

## THE RULE / LOGIC
- **Dimensionality:** A Grid is defined by `Width` (X), `Length` (Y), and `Height` (Z).
- **Cell Collection:** A Grid contains a mapping of `position.Position` (X, Y, Z) to `cell.Cell`.
- **Verticality:**
    - `TopMostGroundAt(x, y)`: Identifies the highest Z-index where a `Ground` type cell exists.
    - `LowestGroundAt(x, y)`: Identifies the lowest Z-index where a `Ground` type cell exists.
- **Entity Management:**
    - Entities are pinned to specific cells.
    - `MoveEntity(from, to, uuid)`: Updates `EntityID` in the source and destination cells if valid.
- **Pathfinding:**
    - `AStarPath(start, end, jumpHeight)`: Calculates a path between two positions, restricted by a maximum vertical step (`jumpHeight`) and traversable cell types (`Ground`).
- **Boundaries:** All operations must verify if a `position.Position` is within `[0, Width)`, `[0, Length)`, and `[0, Height)`.

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[entity_grid]]`
- **Primary Struct:** `type Grid struct` in `grid.go`

## EXPECTATION (For Testing)
- `NewGrid(10, 10, 2)` -> Returns a grid where `Height` is 4 (groundlevel + 2) and all X,Y positions have `Dirt` or `Ground` cells up to level 2.
- `AStarPath` from (0,0,0) to (1,1,1) with `jumpHeight=0` -> Fails if verticality change is required.
- `MoveEntity` to a position outside `Width`/`Length` -> Returns an error.
