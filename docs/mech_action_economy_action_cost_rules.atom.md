---
id: mech_action_economy_action_cost_rules
human_name: Action Cost Rules Mechanic
type: MECHANIC
version: 1.0
status: DRAFT
priority: CORE
tags: []
parents: 
  - [[mech_action_economy]]
dependents: []
---

# Action Cost Rules Mechanic

## INTENT
Defines the delay costs for different actions during a turn.

## THE RULE / LOGIC
- Move: +20 delay cost per tile moved.
- Attack: +100 delay cost.
- Pass: +300 delay cost.

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[mech_action_economy_action_cost_rules]]`
