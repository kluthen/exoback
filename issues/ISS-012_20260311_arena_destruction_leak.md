# Issue: Arena not destroyed on battle end

**ID:** `20260311_arena_destruction_leak`
**Ref:** `ISS-012`
**Date:** 2026-03-11
**Severity:** Medium
**Status:** Open
**Component:** `upsilonapi/bridge`
**Affects:** `upsilonapi/bridge/bridge.go`

---

## Summary

Arenas are added to the `ArenaBridge.arenas` map during startup but are never removed when the battle ends. This causes a memory leak as the number of battles increases.

---

## Technical Description

### Background
When a battle is started via `StartArena`, a new `BattleArena` is created and stored in the `ArenaBridge.arenas` map. This map is used to lookup arenas for subsequent actions.

### The Problem Scenario
1. A battle starts.
2. The `HTTPController` (or other controllers) receive a `rulermethods.BattleEnd` notification when the game finishes.
3. The `HTTPController` forwards this to the webhook.
4. The `ArenaBridge` map still contains the `BattleArena` object.
5. There is no mechanism to remove the `BattleArena` from the map, nor to stop any background processes associated with it (though `Ruler` might handle its own stop).

### Where This Pattern Exists Today
- `upsilonapi/bridge/bridge.go`: `arenas` map and `StartArena` function.
- `upsilonapi/bridge/http_controller.go`: Receives `BattleEnd` but doesn't trigger destruction.

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | High (every battle) |
| Impact if triggered | Medium (memory leak, potential performance degradation) |
| Detectability | Low (requires monitoring memory or checking map size) |
| Current mitigant | None |

---

## Recommended Fix

**Short term:** Add a `DestroyArena(uuid.UUID)` method to `ArenaBridge`.
**Medium term:** In `HTTPController.forwardToWebhook` (or a dedicated handler), check for `BattleEnd` and call `ArenaBridge.DestroyArena`.
**Long term:** Implement a more robust lifecycle management for arenas, possibly with a TTL or explicit cleanup command if the webhook fails.

---

## References

- [bridge.go](file:///workspace/upsilonapi/bridge/bridge.go)
- [http_controller.go](file:///workspace/upsilonapi/bridge/http_controller.go)
