---
id: us_leaderboard_view
human_name: Leaderboard View Story
type: USER_STORY
version: 1.0
status: REVIEW
priority: SECONDARY
tags: [leaderboard, dashboard, stats]
parents:
  - [[ui_leaderboard]]
dependents: []
---

# Leaderboard View Story

## INTENT
Capture the competitive motivation of a player checking their global standing relative to others.

## THE RULE / LOGIC
**As a** logged-in player,  
**I want** to view a global leaderboard ranking all players by their wins and win/loss ratio  
**so that** I can gauge my competitive standing and set progression goals.

- Acceptance Criterion 1: A leaderboard link is clearly present on the Dashboard.
- Acceptance Criterion 2: The leaderboard shows all players sorted by total Wins (descending); ties broken by Win/Loss Ratio.
- Acceptance Criterion 3: Each row shows Account Name, Wins, Losses, and Ratio.
- Acceptance Criterion 4: The leaderboard is only accessible to authenticated users (JWT required).

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[us_leaderboard_view]]`
- **Test Names:** `TestUSLeaderboardSortOrder`, `TestUSLeaderboardAuthGate`

## EXPECTATION (For Testing)
- Authenticated user clicks leaderboard -> Sorted list displays correctly.
- Unauthenticated request to leaderboard route -> Redirected to Landing page.
