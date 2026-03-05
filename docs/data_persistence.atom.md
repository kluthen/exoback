---
id: data_persistence
human_name: PostgreSQL Database Persistence
type: DATA
version: 1.0
status: REVIEW
priority: CORE
tags: [database, postgresql, state]
parents: []
dependents:
  - [[entity_player]]
  - [[entity_character]]
---

# PostgreSQL Database Persistence

## INTENT
Serve as the centralized, persistent source of truth for accounts, characters, and historical match statistics.

## THE RULE / LOGIC
- Technology Stack: Must be strictly deployed on PostgreSQL.
- Primary Entities Supported:
  - Players (credentials, wins, losses, ratio calculation material).
  - Characters (HP, Movement, Attack, Defense stats linked to a Player).
  - Active Games (state serialization, if asynchronous or recoverable).
- Integration Note: Since Laravel orchestrates authentication and Go orchestrates active combat, both services may require explicit interface schemas or distinct responsibility bounded contexts inside this PostgreSQL instance.

## TECHNICAL INTERFACE (The Bridge)
- **Code Tag:** `@spec-link [[data_persistence]]`
- **Test Names:** `TestPostgresPlayerSchema`, `TestPostgresCharacterSchema`

## EXPECTATION (For Testing)
- Game Ends via Go API -> Service updates Player Win/Loss record in PostgreSQL -> Laravel queries updated stats for the Leaderboard.
