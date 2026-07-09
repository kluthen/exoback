---
id: req_matchmaking
human_name: Matchmaking Flow Requirement
type: REQUIREMENT
layer: BUSINESS
version: 1.0
status: STABLE
priority: 5
tags: []
parents:
  - [[shared:req_tech_debt_backlog]]
dependents:
  - [[upsilonbattleui:ui_waiting_room]]
  - [[upsilonbattle:mech_matchmaking]]
---
# Matchmaking Flow Requirement

## INTENT
The system offers four explicit matchmaking queues and moves players from the Waiting Room onto the Board once the required human count is met.

## THE RULE / LOGIC
Matchmaking provides simple avenues to find opponents or play the system. Acceptance criteria:
- Exactly four queue options are offered: `1v1_PVE`, `1v1_PVP`, `2v2_PVE`, `2v2_PVP`; any other mode is rejected with a 4xx error.
- On selecting a queue, the player enters the Waiting Room.
- Players remain in the Waiting Room until the required human count for the chosen mode is met, then instantly spawn onto the Board.

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[req_matchmaking]]`
