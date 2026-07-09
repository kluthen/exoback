---
id: req_tech_debt_backlog
human_name: Technical Debt Backlog
type: REQUIREMENT
layer: BUSINESS
version: 1.0
status: STABLE
priority: 3
tags: [tech-debt, escape-hatch, governance]
parents: []
dependents:
  - [[upsilonbattleui:ui_leaderboard]]
  - [[req_matchmaking]]
  - [[req_security]]
  - [[us_character_reroll]]
  - [[upsilonapi:api_request_id]]
  - [[upsilonapi:data_persistence]]
  - [[upsilonapi:domain_ruler_state]]
  - [[upsilonapi:domain_upsilon_engine]]
  - [[upsilonapi:entity_equipment_system]]
  - [[upsilonbattle:mech_action_economy]]
  - [[upsilonbattle:mech_behavior_system]]
  - [[upsilonbattle:mech_move_validation]]
  - [[upsilonbattle:module_backend]]
  - [[upsilonbattle:module_game]]
  - [[upsilonbattle:rule_credit_action_communication_layer]]
  - [[upsilonbattle:rule_skill_grading_system]]
  - [[upsiloncli:script_farm]]
  - [[upsilontypes:entity_character]]
  - [[upsilontypes:entity_skill_template]]
  - [[upsilontypes:mechanic_temporary_entity_system]]
---
# Technical Debt Backlog

## INTENT
Acts as a temporary anchor for implementation atoms created without formal business requirements.

## THE RULE / LOGIC
Any ARCHITECTURE or IMPLEMENTATION atom that cannot yet be traced to a real business requirement must declare `[[upsilontools:req_tech_debt_backlog]]` as its parent rather than being committed without traceability. These atoms must be groomed and re-parented to proper business atoms during scheduled tech-debt cycles.

- **This is not a free pass.** Using this anchor must be intentional and visible to reviewers.
- **Cycle responsibility:** The team must periodically query `parents: [[upsilontools:req_tech_debt_backlog]]` and groom those atoms toward real requirements.
- **Acceptable scenarios:** rapid prototyping, emergency fixes, infrastructure atoms with no direct user story.

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[upsilontools:req_tech_debt_backlog]]` — do not use in source code; this is documentation-only.
- **Query:** `atd query --field parents --search req_tech_debt_backlog` to list all tech debt atoms.

## EXPECTATION (For Testing)
- No atom at ARCHITECTURE or IMPLEMENTATION layer is committed with an empty `parents` list.
- The count of atoms pointing here decreases over time, not increases.
