---
id: uc_combat_turn_initiative_evaluation
human_name: Initiative Evaluation Logic
type: USECASE
version: 1.0
status: DRAFT
priority: CORE
tags: []
parents: 
  - [[uc_combat_turn]]
dependents: []
---

# Initiative Evaluation Logic

## INTENT
Evaluate the initiative ticker to determine an active character

## THE RULE / LOGIC
System evaluates the initiative ticker for all characters in the sequence. The character with a value of `0` becomes active.

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[uc_combat_turn_initiative_evaluation]]`
