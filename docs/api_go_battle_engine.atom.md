---
id: api_go_battle_engine
human_name: Go UpsilonBattle JSON API & Webhook Dispatcher
type: API
version: 1.0
status: REVIEW
priority: CORE
tags: [api, golang, rest, webhooks]
parents:
  - [[api_ruler_methods]]
dependents: []
---

# Go UpsilonBattle JSON API & Webhook Dispatcher

## INTENT
To define the external JSON boundary for UpsilonBattle, allowing the Laravel Gateway to instantiate arenas, proxy commands, and receive asynchronous state updates via webhooks.

## THE RULE / LOGIC
**Internal Endpoint Authorization:**
- The Go HTTP API should only accept requests from known internal IP ranges or requiring a static shared internal secret key. No user-bearer tokens are verified here (Laravel handles that).

**API Contract (Ingest):**
- `POST /internal/arena/start`
  - Payload: `{ match_id: string, players: [ {id, entities...} ], callback_url: string }`
  - Action: Spawns a new battle arena, maps the `callback_url` to the game state. Starts the 30s [[rule_turn_clock]].
  - Returns: `{ arena_id: string, initial_state: object }`
- `POST /internal/arena/{id}/action`
  - Payload: `{ player_id: string, type: string, target_coords: {x,y} }`
  - Action: Translates REST payload to native [[api_ruler_methods]] messages (e.g., `ControllerMove`, `ControllerAttack`).
  - Returns: `200 Accepted` immediately. Does *not* wait for calculation. 

**Webhook Dispatch (Egest):**
Upon any Ruler broadcast event (`EntitiesStateChanged`, `ControllerNextTurn`, `BattleEnd`), the internal Go router must fire a `POST` request to the dynamically provided `callback_url`.
- Payload Format: `{ match_id: string, event_type: string, player_id: string, entity_id: string, data: object, timeout: string }`
- Must withstand failure (e.g., exponential backoff if Laravel webhook receiver is down).

## TECHNICAL INTERFACE (The Bridge)
- **API Endpoint:** `POST /internal/arena/*`
- **Code Tag:** `@spec-link [[api_go_battle_engine]]`
- **Related Issue:** `ISS-006`
- **Test Names:** `TestArenaStartHTTP`, `TestActionProxyHTTP`, `TestWebhookDispatcherFires`

## EXPECTATION (For Testing)
- Send `POST /internal/arena/{id}/action` with valid payload -> Go engine parses to `ControllerAttack` -> Ruler emits `EntitiesStateChanged` -> Dispatcher fires `POST {callback_url}` with updated HP payload.
