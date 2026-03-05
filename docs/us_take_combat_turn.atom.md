---
id: us_take_combat_turn
human_name: Taking a Combat Turn Story
type: USER_STORY
version: 1.0
status: REVIEW
priority: CORE
tags: [combat, turn, board]
parents:
  - [[uc_combat_turn]]
dependents:
  - [[mech_action_economy]]
  - [[mech_initiative]]
---

# Taking a Combat Turn Story

## INTENT
Capture the experience of an active player controlling a character in combat within fair time constraints.

## THE RULE / LOGIC
**As an** active player during my character's turn,  
**I want** to move, attack, or pass with a visible countdown  
**so that** I can make tactical decisions efficiently while the game remains paced for all players.

- Acceptance Criterion 1: The board highlights my active character and shows a visible 30-second countdown.
- Acceptance Criterion 2: I can select Move (up to my Movement stat in squares) and/or Attack (against an enemy) before my turn ends.
- Acceptance Criterion 3: If I do not act within 30 seconds, my turn auto-ends and my character incurs a +400 delay penalty (300 for pass + 100 penalty).
- Acceptance Criterion 4: I cannot target allied characters for attacks.

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[us_take_combat_turn]]`
- **Test Names:** `TestUSTurnTimerVisible`, `TestUSTurnAutoPassPenalty`, `TestUSFriendlyFireBlocked`

## EXPECTATION (For Testing)
- Active character highlighted -> Timer counts down -> Player clicks attack on enemy -> HP reduced -> Turn ends and delay calculated.
- Timer hits 0 with no action -> Auto-pass applied -> +100 delay added to character's timer.
