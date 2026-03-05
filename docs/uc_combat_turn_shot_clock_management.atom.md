---
id: uc_combat_turn_shot_clock_management
human_name: Shot Clock Management Logic
type: USECASE
version: 1.0
status: DRAFT
priority: CORE
tags: []
parents: 
  - [[uc_combat_turn]]
dependents: []
---

# Shot Clock Management Logic

## INTENT
Manage the shot clock to enforce turn timeouts

## THE RULE / LOGIC
The board highlights the active character and starts the 30-second shot clock (`mech_action_economy`).

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[uc_combat_turn_shot_clock_management]]`
