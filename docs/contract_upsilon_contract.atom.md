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
dependents: []
---

# Upsilon Hub Contract

## INTENT
Establish the governance and quality standards for all sub-projects within the Upsilon Hub ecosystem.

## THE RULE / LOGIC
- **Modular Integrity:** Every sub-project must maintain its own `docs/` directory with `CONTRACT` and `VISION` atoms.
- **ATD Traceability:** Every function, route handler, or entity that implements a settled atom must carry an `@spec-link` tag directly above it. Tooling, scripts, and infrastructure files that have no atom of their own to trace to may instead carry `@lint-ignore-atd` rather than being tagged to an atom that doesn't actually govern them.
- **CI/CD Requirement:** No code shall be merged without passing automated tests and E2E battle simulations.
- **Project Structure:** Sub-projects are integrated via Git submodules and must remain independently buildable.

## TECHNICAL INTERFACE
- **Code Tag:** `@spec-link [[contract_upsilon_contract]]`
  - **Related Atoms:** `[[vision_upsilon_vision]]`

## EXPECTATION
