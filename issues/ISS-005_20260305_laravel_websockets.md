# Issue: Implement Laravel WebSocket Communication Layer

**ID:** `20260305_laravel_websockets`
**Ref:** `ISS-005`
**Date:** 2026-03-05
**Severity:** High
**Status:** Open
**Component:** `laravel/broadcasting`
**Affects:** `vue-frontend`

---

## Summary

To avoid aggressive REST polling, the system requires a real-time WebSocket layer for pushing game state updates from the Laravel cache to the Vue.js clients. This will be handled using Laravel Reverb (or a similar broadcasting driver).

---

## Technical Description

### Background
Turn-based combat requires players to be immediately notified when their opponent starts their turn, makes a move, or when the 30-second clock naturally expires. 

### The Problem Scenario
Without WebSockets, the Vue clients would have to rapidly poll the Laravel API (`GET /api/v1/battle/{arena_id}/state`), which destroys performance and scalability. We require a persistent duplex connection where Laravel can push event deltas to subscribed users.

### Where This Pattern Exists Today
WebSocket infrastructure is currently missing.

---

## Risk Assessment

| Factor              | Value |
| ------------------- | ----- |
| Likelihood          | High  |
| Impact if triggered | High  |
| Detectability       | High  |
| Current mitigant    | None  |

---

## Recommended Fix

* [x] **Short term:** Install and configure Laravel Reverb (or Soketi) as the default broadcasting driver.
  * Reverb has been installed and tested. It's operationnal but see issue ISS-008. 
* [ ] **Medium term:** Define private broadcasting channels for `arena.{id}`. Ensure the authorization callbacks logic validates that only users actively participating in `arena.{id}` can subscribe. Create Laravel Event classes (`TurnStarted`, `BoardUpdated`, `GameEnded`) that implement `ShouldBroadcast`. Hook these events up to be fired by the `WebhookController` (from ISS-004).
* [ ] **Long term:** N/A

---

## References

- `@spec-link [[api_laravel_gateway]]`
- `communication.md` Architecture Document
