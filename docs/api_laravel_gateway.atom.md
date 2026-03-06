---
id: api_laravel_gateway
human_name: Laravel API Gateway & WebSockets Hub
type: API
version: 1.0
status: REVIEW
priority: CORE
tags: [api, gateway, websockets, proxy, laravel-reverb]
parents: []
dependents:
  - [[api_go_battle_engine]]
---

# Laravel API Gateway & WebSockets Hub

## INTENT
To define how the Vue.js frontend communicates with the overall ecosystem via Laravel, utilizing HTTP REST for actions/queries and WebSockets (Laravel Reverb) for real-time state streaming.

## THE RULE / LOGIC
**Authentication (HTTP):**
- All HTTP routes originating from Vue must carry a valid Bearer Token.
- WebSockets channels are private (`arena.{id}`); users must authorize to subscribe via Reverb logic.

**Meta-game Actions (HTTP):**
- `POST /api/v1/auth/login` -> Trades credentials for a Token.
- `GET /api/v1/characters` -> Delivers roster state to UI.
- `POST /api/v1/matchmaking/join` -> Enqueues the player.

**Battle State & Proxying (HTTP & Websocket):**
- `GET /api/v1/battle/{arena_id}/state` -> Returns the *cached* board state from Redis (avoids querying Go).
- `POST /api/v1/battle/{arena_id}/action` -> Payloads standard commands (move, attack). Laravel proxies this to Go.
- *Webhooks Receiving:* Laravel must expose an internal, un-rate-limited callback url (e.g. `/api/internal/webhook`) for Go to push state updates via POST. Upon receiving, update cache and broadcast.

**Event Broadcasting (Websocket -> Vue via Laravel Reverb):**
- Event `game.started`: Broadcasted when Go initially creates an arena. Payload: `arena_id`.
- Event `turn.started`: Broadcasted when the 30s clock begins. Payload: `active_player_id`.
- Event `board.updated`: Broadcasted upon state mutation (move, attack, aura trigger). Payload: `delta_changes` or `full_state`.
- Event `game.ended`: Broadcasted upon win condition met. Payload: `winner_id`, `post_game_stats`.

## TECHNICAL INTERFACE (The Bridge)
- **API Endpoint:** `/api/v1/*` and Laravel Reverb Channels.
- **Code Tag:** `@spec-link [[api_laravel_gateway]]`
- **Related Issue:** `ISS-005`, `ISS-007`
- **Test Names:** `TestLoginRoute`, `TestProxyAction`, `TestWebhookUpdatesCacheAndBroadcasts`, `TestReverbBroadcasting`

## EXPECTATION (For Testing)
- Vue hits `/action` -> Laravel proxies to Go -> Go validates and pushes to `/webhook` -> Laravel updates Redis -> Laravel Broadcasts `board.updated` -> Vue receives event via WebSocket.
