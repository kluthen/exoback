---
id: ui_board
human_name: Board Page UI
type: UI
version: 1.0
status: REVIEW
priority: CORE
tags: [ui, secure, combat]
parents:
  - [[module_game]]
dependents: []
---

# Board Page UI

## INTENT
The main gameplay screen where the tactical RPG battle actually occurs.

## THE RULE / LOGIC
- Visualization: Presents the tactical grid/board, character positions, and turn order.
- Controls: Allows the active player to select Move, Attack, or Pass actions when their character's turn is active (Initiative = 0).
- Timers: Displays the 30-second turn countdown for the currently active character.
- Security: Requires a valid JWT to access.

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[ui_board]]`
- **Test Names:** `TestBoardRendersActiveTurn`

## EXPECTATION (For Testing)
- Game starts -> Board renders grid -> Active turn character is highlighted -> Player can click actions.
