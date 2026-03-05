---
id: uc_combat_turn_shot_clock_expiration
human_name: Shot Clock Expiration Logic
type: USECASE
version: 1.0
status: DRAFT
priority: CORE
tags: []
parents: 
  - [[uc_combat_turn]]
dependents: []
---

# Shot Clock Expiration Logic

## INTENT
Enforce shot clock expiration and auto-pass if necessary

## THE RULE / LOGIC
Shot Clock expires: If no action is confirmed within 30 seconds, the system forces a Pass (+300) and applies a `+100` penalty (Total `+400`).

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[uc_combat_turn_shot_clock_expiration]]`
