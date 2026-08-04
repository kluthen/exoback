---
id: us_character_reroll
human_name: Character Reroll Story
type: USER_STORY
layer: BUSINESS
version: 1.0
status: STABLE
priority: 5
tags: []
parents:
  - [[shared:req_tech_debt_backlog]]
dependents:
  - [[upsilonapi:api_profile_character]]
---
# Character Reroll Story

## INTENT
As a player who has not yet played a match, I can reroll my starting roster up to three times to get a set I'm happy with, from my profile — this is not tied to a one-time registration-flow screen.

## THE RULE / LOGIC
A player's character roster can be limited-reroll while the account has not yet played a match. Acceptance criteria:
- A clear, noticeable "Reroll" action is present (on the account's profile/character panel).
- Clicking "Reroll" discards the current character set and regenerates three new characters.
- A visible counter shows the number of rerolls remaining (e.g. "Rerolls remaining: 2").
- After three successful rerolls the "Reroll" action is disabled to prevent further use.
- Reroll stops being available the moment the account has played its first match (win or loss), regardless of how many of the three rerolls were used.

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[us_character_reroll]]`
