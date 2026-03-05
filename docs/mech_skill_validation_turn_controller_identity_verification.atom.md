---
id: mech_skill_validation_turn_controller_identity_verification
human_name: Turn/Controller Identity Verification
type: MECHANIC
version: 1.0
status: DRAFT
priority: CORE
tags: []
parents: 
  - [[mech_skill_validation]]
dependents: []
---

# Turn/Controller Identity Verification

## INTENT
Verify that the entity is on its active turn and owns the controller issuing the command.

## THE RULE / LOGIC
entity.turn.missmatch, entity.controller.missmatch

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[mech_skill_validation_turn_controller_identity_verification]]`
