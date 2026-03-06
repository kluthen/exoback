# Issue: Transition WebSocket Events to Private Channels

**ID:** `20260306_websocket_private_channel_transition`
**Ref:** `ISS-008`
**Date:** 2026-03-06
**Severity:** High
**Status:** Open
**Component:** `battleui/app/Events/`
**Affects:** `battleui/resources/js/Pages/EventTest.vue`, `battleui/routes/channels.php`

---

## Summary

WebSocket events, specifically the `BattleUpdated` event, are currently broadcast on public channels for testing convenience. This allows any client with the channel name to listen to game state updates without authentication. These must be transitioned to private channels to ensure data privacy and enforce authorization rules (e.g., only players in the battle can receive updates).

---

## Technical Description

### Background
Laravel Echo and Reverb are used for real-time updates. Currently, `BattleUpdated` implements `ShouldBroadcastNow` and defines a public `Channel`.

### The Problem Scenario
1. A developer or malicious actor can open a WebSocket connection and listen to `battle.{id}`.
2. Since it's a `Channel` (not `PrivateChannel`), no authorization check is performed in `routes/channels.php`.
3. Sensitive game state data is exposed to non-participants.

```
Client (Unauthenticated) ----> Subscribes to 'battle.42' (Public)
Server (Broadcast) ----------> Pushes Event { battleData: [...] } to 'battle.42'
Client (Unauthenticated) <---- Receives Event (Data Leak)
```

### Where This Pattern Exists Today
- `app/Events/BattleUpdated.php:24`: `return new Channel('battle.' . $this->battleId);`
- `resources/js/Pages/EventTest.vue:10`: `window.Echo.channel('battle.42')`
- `routes/channels.php:6`: Placeholder `Broadcast::channel` that needs real logic.

---

## Risk Assessment

| Factor              | Value                                                    |
| ------------------- | -------------------------------------------------------- |
| Likelihood          | High                                                     |
| Impact if triggered | High                                                     |
| Detectability       | Medium — manifested as unauthorized access to game data. |
| Current mitigant    | None (explicitly set to public for testing).             |

---

## Recommended Fix

**Short term:**
- Change `broadcastOn()` in `BattleUpdated.php` to return `new PrivateChannel(...)`.
- Update `EventTest.vue` to use `window.Echo.private(...)`.
- Implement basic auth check in `routes/channels.php`.

**Medium term:**
- Ensure that the broadcast authentication route uses both `web` and `sanctum` middleware to support different client authentication methods.
- Refine authorization logic to check if `$user` is actually a participant in the `$battleId`.

**Long term:**
- Centralize channel name management to avoid magic strings between Vue and PHP.

---

## References

- `app/Events/BattleUpdated.php`
- `resources/js/Pages/EventTest.vue`
- `routes/channels.php`
- [Laravel Broadcasting Documentation](https://laravel.com/docs/broadcasting)
