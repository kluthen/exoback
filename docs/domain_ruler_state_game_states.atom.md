---
id: domain_ruler_state_game_states
human_name: Game States Split
type: DOMAIN
version: 1.0
status: DRAFT
priority: CORE
tags: []
parents: 
  - [[domain_ruler_state]]
dependents: []
---

# Game States Split

## INTENT
Manage distinct states for the Ruler's progression.

## THE RULE / LOGIC
The Ruler progresses through three immutable phases: WaitingForControllers, InProgress, and Finished.

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[domain_ruler_state_game_states]]`
