---
id: rule_progression
human_name: Character Progression Rule
type: RULE
version: 1.0
status: REVIEW
priority: CORE
tags: [progression, character]
parents:
  - [[entity_character]]
dependents: []
---

# Character Progression Rule

## INTENT
Governs how character attributes improve after participating in a successful game.

## THE RULE / LOGIC
- Post-Win Reward: After each game win, the player can allocate exactly 1 attribute point to a character in their roster.
- Standard Attributes: The point can be allocated to HP, Attack, or Defense freely.
- Movement Restriction: A point can only be allocated to the Movement attribute once every 5 accumulated wins.

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[rule_progression]]`
- **Test Names:** `TestPostWinStatAllocation`, `TestMovementProgressionRestriction`

## EXPECTATION (For Testing)
- Character wins a game -> Gains 1 point.
- Player assigns point to HP -> HP increases by 1.
- Player tries to assign point to Movement after 3 wins -> Operation rejected.
