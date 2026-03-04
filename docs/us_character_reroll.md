---
id: us_character_reroll
human_name: Character Reroll Story
type: USER_STORY
version: 1.0
status: REVIEW
priority: CORE
tags: [registration, character, reroll]
parents:
  - [[uc_player_registration]]
dependents:
  - [[mech_character_reroll]]
---

# Character Reroll Story

## INTENT
Capture the desire of a player to have a limited chance to re-randomize their starting roster during account creation.

## THE RULE / LOGIC
**As a** new player during account creation,  
**I want** the ability to reroll my 3 starting characters' stats  
**so that** I can begin the game with a roster I find strategically interesting, while being limited to prevent abuse.

- Acceptance Criterion 1: A "Reroll" button is clearly visible on the character creation screen.
- Acceptance Criterion 2: Clicking Reroll discards all 3 characters and regenerates 3 new ones.
- Acceptance Criterion 3: A visible counter tracks remaining rerolls (e.g., "Rerolls remaining: 2").
- Acceptance Criterion 4: After 3 rerolls the button is disabled; a 4th action is prevented at the UI and API level.

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[us_character_reroll]]`
- **Test Names:** `TestUSCharacterRerollCounter`, `TestUSCharacterRerollButtonLock`

## EXPECTATION (For Testing)
- New account flow -> Reroll clicked 3 times -> Button becomes disabled -> Stats are different from before.
