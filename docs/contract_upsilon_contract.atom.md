---
id: contract_upsilon_contract
status: STABLE
version: 1.0
priority: 1
tags: [governance, contract, root]
parents: []
human_name: Upsilon Hub Contract
type: CONTRACT
layer: BUSINESS
dependents:
  - [[upsilonbattleui:contract_ui_contract]]
  - [[rule_code_health_monitoring]]
  - [[rule_dto_strict_typing]]
  - [[upsilonapi:contract_api_contract]]
  - [[upsilonbattle:contract_battle_contract]]
  - [[upsilonbattle:rule_ruler_test_robustness]]
  - [[upsiloncli:contract_cli_contract]]
  - [[upsilonmapdata:contract_mapdata_contract]]
  - [[upsilonmapmaker:contract_mapmaker_contract]]
  - [[upsilontools:contract_tools_contract]]
  - [[upsilontypes:contract_types_contract]]
---

# Upsilon Hub Contract

## INTENT
Establish the governance and quality standards for all sub-projects within the Upsilon Hub ecosystem.

## THE RULE / LOGIC
- **Modular Integrity:** Every sub-project must maintain its own `docs/` directory with `CONTRACT` and `VISION` atoms.
- **Quality Standards:**
  - Mandatory adherence to `[[rule_code_health_monitoring]]` (LOC limits, complexity, documentation density).
  - Strict ATD traceability: Every file must have `@spec-link` tags.
- **CI/CD Requirement:** No code shall be merged without passing the automated health checks and E2E battle simulations.
- **Project Structure:** Sub-projects are integrated via Git submodules and must remain independently buildable.

## TECHNICAL INTERFACE
- **Code Tag:** `@spec-link [[contract_upsilon_contract]]`
  - **Script:** `scripts/code_health_check.py`
  - **Related Atoms:** `[[rule_code_health_monitoring]]`, `[[vision_upsilon_vision]]`

## EXPECTATION
