---
id: uc_matchmaking
human_name: Matchmaking & Queue Use Case
type: USER_STORY
layer: ARCHITECTURE
version: 1.0
status: STABLE
priority: 5
tags: []
parents:
  - [[upsilonbattleui:req_player_experience]]
dependents:
  - [[us_api_flow_matchmaking]]
  - [[upsilonapi:api_matchmaking]]
  - [[upsilonapi:rule_matchmaking_single_queue]]
---
# Matchmaking & Queue Use Case

## INTENT
Facilitates the transition from the **Character Review Dashboard** to an active combat session, while allowing a return to the Dashboard (Leave Queue).

## THE RULE / LOGIC
1. From the Dashboard, the Player selects a game mode (PvE or PvP) from the queue selection screen.
2. **PvE**: Laravel spawns an immediate match against AI.
3. **PvP**: System enters the matchmaking queue; System matches the player against another human opponent.
4. **Queue Management**: During the queue period, the User may choose to cancel and return to the **Dashboard** (Leave Queue).
5. **Transition (Start)**: Upon match assignment, UC-3 dispatches a 'Match Start' payload to the Go backend and redirects the Player(s) to the tactical board.

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[uc_matchmaking]]`

## EXPECTATION (For Testing)
- User selects PvP -> Waiting room rendered -> Match found -> Board redirection.
- User selects PvE -> Board redirection (no queue period).
- User clicks cancel while in queue -> Redirected back to Dashboard.
