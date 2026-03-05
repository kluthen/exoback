---
id: api_ruler_methods
human_name: Ruler Message Methods API
type: API
version: 1.0
status: REVIEW
priority: CORE
tags: [api, messaging, queue]
parents:
  - [[domain_ruler_state]]
dependents: []
---

# Ruler Message Methods API

## INTENT
To define the explicit actor-message structures required to ingest data into the Ruler and extract state changes.

## THE RULE / LOGIC
Interaction with the backend engine is strictly channeled through `messagequeue` structs. 

**State Commands (Read & Init):**
- `AddController`: Ingests a new player. Replies with `AddControllerReply` containing Grid, Entities, and TurnState.
- `GetGridState`: Requests board data (`GetGridStateReply`). Optional filtering via `AsController`.
- `GetEntitiesState`: Requests live roster data (`GetEntitiesStateReply`).

**Action Commands (Write):**
- `ControllerMove`: Issues a navigation path. Replies `ControllerMoveReply` containing the updated Entity state.
- `ControllerAttack`: Issues a basic attack against a target node. Replies `ControllerAttackReply`.
- `ControllerUseSkill`: Issues a complex skill against a target node. Replies `ControllerUseSkillReply`.
- `EndOfTurn`: Manually completes an entity's turn segment.
- `ControllerQuit`: Disconnects the controller from the session loop.

**Broadcast Events (Engine to Clients):**
- `BattleStart`: Indicates the initial transition from setup to combat.
- `ControllerNextTurn`: Informs clients who just became the active entity.
- `EntitiesStateChanged`: Emits updated states after movement, damage, or healing.
- `ControllerSkillUsed` / `ControllerAttacked`: Specialized action notification for UX logging.
- `BattleEnd`: Fires upon victory condition met; defines the winning Controller UUID.

## TECHNICAL INTERFACE (The Bridge)
- **API Endpoint:** Implicit RPC/Message Queue over `actor` communication channels (e.g., `github.com/ecumeurs/upsilontools/tools/messagequeue/message`).
- **Code Tag:** `@spec-link [[api_ruler_methods]]`
- **Related Issue:** `#None`
- **Test Names:** `N/A` (Interface def)

## EXPECTATION (For Testing)
- Submit `ControllerMove` msg -> Validated by Ruler -> Broadcasts `EntitiesStateChanged` -> Returns `ControllerMoveReply` to caller.
