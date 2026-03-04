---
id: uc_matchmaking
human_name: Matchmaking & Queue Use Case
type: USECASE
version: 1.0
status: REVIEW
priority: CORE
tags: [matchmaking, queue]
parents:
  - [[req_matchmaking]]
  - [[req_security]]
dependents:
  - [[spec_match_format]]
  - [[ui_waiting_room]]
  - [[ui_board]]
---

# Matchmaking & Queue Use Case

## INTENT
End-to-end narrative of a logged-in player selecting a game mode, waiting for a match, and transitioning to the board.

## THE RULE / LOGIC
1. Logged-in user on Dashboard (`ui_dashboard`) authenticates via valid JWT.
2. User selects one of four queue buttons: `1v1 PVE`, `1v1 PVP`, `2V2 PVE`, `2V2 PVP`.
3. **PVE path:** Laravel immediately spawns a game against AI; user is placed directly on the Board (`ui_board`). No wait.
4. **PVP path:** Laravel adds the user to the appropriate queue. User waits in the Waiting Room (`ui_waiting_room`).
5. Once the required Human player count is reached, the orchestrator confirms the match and dispatches a "Match Start" payload to the Go backend.
6. All matched clients are simultaneously redirected to the live Board page (`ui_board`).

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[uc_matchmaking]]`
- **Test Names:** `TestUCMatchmakingPVEInstant`, `TestUCMatchmakingPVPQueue`

## EXPECTATION (For Testing)
- PVE select -> No waiting -> Board renders.
- 2v2 PVP select -> 3 additional players join -> all 4 redirect to Board simultaneously.
