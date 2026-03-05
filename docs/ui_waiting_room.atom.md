---
id: ui_waiting_room
human_name: Waiting Room UI
type: UI
version: 1.0
status: REVIEW
priority: CORE
tags: [ui, secure, matchmaking]
parents:
  - [[req_matchmaking]]
dependents:
  - [[ui_board]]
---

# Waiting Room UI

## INTENT
To bridge the gap between selecting a queue and joining the battle board while searching for other players.

## THE RULE / LOGIC
- State: Displays the current matchmaking status (e.g., "Waiting for 1 more player...").
- PVE Bypass: If a pure PVE mode is selected (e.g., 1v1 PVE) or matchmaking dictates an instant start, this screen may instantly redirect to the Board page.
- Security: Requires a valid JWT to access.

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[ui_waiting_room]]`
- **Test Names:** `TestWaitingRoomDisplay`

## EXPECTATION (For Testing)
- User clicks 1v1 PVP -> Redirects to Waiting Room -> Shows "Searching for opponent..." -> When matched, redirects to Board.
