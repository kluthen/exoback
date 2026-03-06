# UpsilonBattle: Tactical RPG

**UpsilonBattle** is a simple, turn-based Tactical RPG (TRPG) designed for concurrent multiplayer combat and AI skirmishes. Designed entirely around the Atomic Documentation (ATD) framework, its concepts separates game logic, mechanics, and architectural boundaries into standalone, single-responsibility specifications.

## The Game At a Glance
- **Play Modes:** 1v1 (PvE or PvP) and 2v2 (PvE or PvP).
- **The Board:** A randomly generated rectangular grid (5-15 tiles per dimension, absolute minimum area of 50 tiles) containing up to 10% randomly placed impassable obstacles.
- **Victory Condition:** Eliminate all characters on the opposing team. **Friendly Fire is strictly disabled.**
- **The Roster:** Every player commands a roster of exactly 3 characters.

## Character System & Progression
- **Initial Core Roll:** New characters are allocated exactly 10 initial attribute points. A minimum of 3 points must govern **HP (Health Points)**, with the remaining 7 randomly distributed among **HP**, **Movement (Squares)**, **Attack**, and **Defense**.
- **The Reroll Mechanic:** During account registration, players are granted an option to completely re-randomize their 3 initial character stat blocks. This reroll can be executed a strict maximum of **3 times**.
- **Stat Progression:** Securing a match victory rewards a player with 1 Attribute Point. This point can be allocated to HP, Attack, or Defense freely. Upgrading the Movement attribute is heavily throttled and locked to once every 5 accumulated wins.

## Combat Mechanics
- **Initiative & Delay:** Turn order is non-linear. Characters roll a pre-initiative value ranging from `1-500`. Active turns fire when the ticker hits `0`. 
- **Action Economy:** During a turn, a character may perform a maximum of **1 Move** (`+20/tile`), **1 Attack** (`+100`), or safely **Pass** (`+300`). Performing actions accumulates a numerical "Delay Cost," mathematically extending the wait time until that character's next sequence.
- **The Shot Clock:** Active combat turns mandate a strict **30-second limit** per character. Failing to confirm an action manually results in an auto-pass forced by the server, accompanied by a penalty of `+100` (Total `+400` delay).

## Technical Architecture Overview
The system relies on a strictly separated logic implementation:

1. **Frontend (`BattleUI` - Laravel / Vue.js / Tailwind):**
   - Operates as the user-facing client.
   - Manages Player Sessions natively, distributing and securing gameplay boundaries via stateless **JWT Authentication**.
   - Orchestrates Player Queuing (`1v1 PVE, 1v1 PVP, 2V2 PVE, 2V2 PVP`) and matches clients cleanly before instantiating the combat sequence.
   - Renders the Global Leaderboard tracking Win/Loss volumes and derived ratio metrics.

2. **Backend (`UpsilonBattle` - Go JSON API):**
   - The isolated, calculating brain behind active skirmishes.
   - Fully governs the math of active battles (HP reduction, board coordinate generation, initiative delay math, and step validation).
   - Entirely ignores matchmaking queues, interacting strictly through validated combat payloads.

3. **Database (PostgreSQL):**
   - Persistent, serialized memory holding Player access credentials, individual Character state logs, match resolutions, and leaderboard calculations.

## Specification (ATD) Maps
All fundamental mechanics, structural constraints, entities, and network rules that form the game are housed individually in `/workspace/docs/`. These Atoms serve as the uncompromising basis for evaluating developer implementation logic.

## Open Issues

| Name | Date | Status | Severity | Oneliner |
|---|---|---|---|---|
| [Transition WebSocket Events to Private Channels](issues/ISS-008_20260306_websocket_private_channel_transition.md) | 2026-03-06 | Open | High | WebSocket events, specifically the `BattleUpdated` event, are currently broad... |
| [Implement Laravel API Gateway Endpoints](issues/ISS-007_20260305_laravel_api_endpoints.md) | 2026-03-05 | Open | High | The Laravel API needs to implement the proxy and meta-game HTTP endpoints def... |
| [Implement HTTP Controller for UpsilonBattle](issues/ISS-006_20260305_upsilonbattle_http_controller.md) | 2026-03-05 | Open | High | To support the Proxied Communication architecture, the Go engine needs an HTT... |
| [Implement Laravel WebSocket Communication Layer](issues/ISS-005_20260305_laravel_websockets.md) | 2026-03-05 | Open | High | To avoid aggressive REST polling, the system requires a real-time WebSocket l... |
| [Map Generation ignores specifications](issues/ISS-004_20260305_upsilonbattle_mapgen_ignores_spec.md) | 2026-03-05 | Open | Medium | In `upsilonbattle/battlearena/ruler.go`, the `NewRuler` function hardcodes th... |
| [UpsilonBattle missing team handling](issues/ISS-003_20260305_upsilonbattle_missing_teams.md) | 2026-03-05 | Open | High | The `upsilonbattle` engine currently lacks any concept of "teams" or alliance... |
| [Missing JSON REST API & Webhook Dispatcher in Go Engine](issues/ISS-002_20260305_upsilonbattle_api_gap.md) | 2026-03-05 | Open | High | The current `upsilonbattle` Go engine lacks a JSON REST API and a webhook dis... |
| [UpsilonBattle Mechanics Gap Analysis](issues/ISS-001_20260305_upsilonbattle_mechanics_gap.md) | 2026-03-05 | Open | Medium | There are multiple inconsistencies between the high-level specifications (REA... |

