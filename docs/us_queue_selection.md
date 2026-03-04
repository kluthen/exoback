---
id: us_queue_selection
human_name: Queue Selection Story
type: USER_STORY
version: 1.0
status: REVIEW
priority: CORE
tags: [matchmaking, queue, dashboard]
parents:
  - [[uc_matchmaking]]
dependents:
  - [[req_matchmaking]]
---

# Queue Selection Story

## INTENT
Capture the need of a logged-in player to easily select and enter a game type without confusion.

## THE RULE / LOGIC
**As a** logged-in player on the Dashboard,  
**I want** to see 4 clearly distinct buttons for each game mode  
**so that** I can immediately select my preferred play style without navigating additional menus.

- Acceptance Criterion 1: Dashboard displays exactly 4 buttons: `1v1 PVE`, `1v1 PVP`, `2V2 PVE`, `2V2 PVP`.
- Acceptance Criterion 2: Clicking a PVE button starts the game immediately (no waiting room).
- Acceptance Criterion 3: Clicking a PVP button navigates to the Waiting Room.
- Acceptance Criterion 4: The Dashboard also displays my current Win/Loss record and my Win/Loss ratio.

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[us_queue_selection]]`
- **Test Names:** `TestUSQueueButtonsVisible`, `TestUSQueuePVEInstant`, `TestUSQueuePVPNavigation`

## EXPECTATION (For Testing)
- Dashboard loads -> 4 buttons present -> Click 1v1 PVE -> Board renders -> Click 1v1 PVP -> Waiting room renders.
