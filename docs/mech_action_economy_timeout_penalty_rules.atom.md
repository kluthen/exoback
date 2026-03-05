---
id: mech_action_economy_timeout_penalty_rules
human_name: Timeout Penalty Rules Mechanic
type: MECHANIC
version: 1.0
status: DRAFT
priority: CORE
tags: []
parents: 
  - [[mech_action_economy]]
dependents: []
---

# Timeout Penalty Rules Mechanic

## INTENT
Applies penalties to turns that last exactly 30 seconds without completion.

## THE RULE / LOGIC
- If a turn lasts exactly 30 seconds without completion, an automatic "Pass" is triggered, and a strict penalty of +100 delay cost is added on top of the base Pass cost (Total +400).

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[mech_action_economy_timeout_penalty_rules]]`
