---
id: vision_upsilon_vision
status: STABLE
human_name: Upsilon Hub Vision
priority: 1
tags: [governance, vision, root]
dependents:
  - [[upsilonbattleui:vision_ui_vision]]
  - [[upsilonapi:vision_api_vision]]
  - [[upsilonbattle:vision_battle_vision]]
  - [[upsiloncli:vision_cli_vision]]
  - [[upsilonmapdata:vision_mapdata_vision]]
  - [[upsilonmapmaker:vision_mapmaker_vision]]
  - [[upsilontools:mechanic_math_core_utils]]
  - [[upsilontools:mechanic_randomization_helpers]]
  - [[upsilontools:mechanic_spatial_distance_calculations]]
  - [[upsilontools:vision_tools_vision]]
  - [[upsilontypes:vision_types_vision]]
type: VISION
layer: BUSINESS
version: 1.0
parents: []
---

# Upsilon Hub Vision

## INTENT
Define Upsilon as a modular multiplayer platform that grows from a tactical battle arena into a persistent living world hosting multiple interconnected game experiences.

## THE RULE / LOGIC
- **North Star:** Upsilon evolves from a battle-only arena into a persistent "living world" (adventuring / defend-the-base) that hosts several interconnected game *sides* sharing one identity, one economy, and one world.
- **Game Sides (current + planned):**
  - **Battle** — tactical RPG arena (the existing product; the reference sub-engine).
  - **Commerce** — a tycoon / economic simulation.
  - **Intrigue** — a spy / asymmetric-information game.
- **World Engine (authoritative truth):** A central, persistent service that owns world-scale state — geography, player position, world resources, and large-scale events. It *configures* sub-engines from world state and *ingests* their outcomes.
- **Sub-Engines (configured simulations):** Each side runs as a simulation configured from the world and reporting results back. Their runtime shapes differ deliberately:
  - Battle = ephemeral, instanced, real-time; scales by sharding matches.
  - Commerce / Intrigue = persistent, tick/timer-driven; closer in shape to the World Engine itself.
- **Integration Contract:** Configuration flows *down* (command/RPC), outcomes flow *up* (events). The existing battle `startArena ↓ / webhook ↑` exchange is the prototype for this world↔engine protocol.
- **Shared Kernels:** Two cross-cutting substrates sit beneath every side — **Identity** (accounts, credentials, sessions) and **Economy** (the wallet/credit ledger shared by battle rewards, the market, and commerce). A new side plugs into these rather than reimplementing them.
- **Enduring Principles:** Atomic traceability; modularity split by *responsibility and load profile* (high-load battle + gateway scale out; low-load market / skill-generation stay flat); Go performance for millisecond tactical latency; observability-first (OpenTelemetry) as the connective tissue of a multi-engine mesh.

## TECHNICAL INTERFACE
- **Integration Pattern:** World↔Engine — config down (command/RPC), outcomes up (events); Identity and Economy as shared kernels.

## EXPECTATION
- A new game side (e.g. Commerce, Intrigue) can be introduced by implementing the world↔engine contract, without modifying Identity or Economy.
- Identity and Economy are consumed by every side as services — no side owns its own private copy of accounts or the credit ledger.
- Each engine scales independently along its own load profile (battle by match-sharding; world by region-sharding) without forcing the others to scale.
- The platform remains fully traceable: every shipped capability links back through atoms to this vision.
