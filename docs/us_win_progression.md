---
id: us_win_progression
human_name: Post-Win Progression Story
type: USER_STORY
version: 1.0
status: REVIEW
priority: CORE
tags: [progression, win, character]
parents:
  - [[uc_match_resolution]]
dependents:
  - [[rule_progression]]
---

# Post-Win Progression Story

## INTENT
Capture the satisfaction and strategic depth of a player improving their roster after a victory.

## THE RULE / LOGIC
**As a** winning player after a completed match,  
**I want** to allocate a stat point to one of my characters  
**so that** I can shape my roster progression according to my play style over time.

- Acceptance Criterion 1: A progression screen appears only after a match victory.
- Acceptance Criterion 2: I can allocate exactly 1 point to HP, Attack, or Defense freely.
- Acceptance Criterion 3: The Movement stat option is grayed out and locked unless my total win count is a multiple of 5.
- Acceptance Criterion 4: Applying the point immediately reflects on my Dashboard character stats.

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[us_win_progression]]`
- **Test Names:** `TestUSProgressionScreenOnWin`, `TestUSMovementLockedBelow5Wins`

## EXPECTATION (For Testing)
- Win match -> Progression screen shows -> Player allocates to Attack -> Attack stat +1 on Dashboard.
- Win count = 3 -> Movement upgrade option is disabled/locked.
