# Issue: Implement Laravel API Gateway Endpoints

**ID:** `20260305_laravel_api_endpoints`
**Ref:** `ISS-007`
**Date:** 2026-03-05
**Severity:** High
**Status:** Open
**Component:** `laravel/routes/api`
**Affects:** `vue-frontend`, `upsilonbattle`

---

## Summary

The Laravel API needs to implement the proxy and meta-game HTTP endpoints defined in the communication specs. This includes matchmaking queues, handling REST actions from Vue, and receiving webhook state updates from the Go engine to update the local Redis cache.

---

## Technical Description

### Background
Laravel acts as the primary API Gateway. It must validate user bear tokens and route game commands to the protected internal Go API.

### The Problem Scenario
Vue clients currently have no functional Laravel endpoints to interact with for launching or playing a match. Furthermore, Laravel needs an internal un-throttled endpoint to receive Webhook payloads from the Go engine when board state changes.

### Where This Pattern Exists Today
This is a new subsystem implementation.

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

**Short term:** Scaffold the empty Controllers and Routes for the API gateway.
**Medium term:** Implement the `MatchmakingController` logic to pair players. Implement the `BattleProxyController` to simply forward Vue's authenticated REST payloads to the internal Go IP. Implement the `WebhookController` to ingest the Go engine's updates, update the Redis board cache, and trigger the broadcasting events.
**Long term:** N/A

---

## References

- `@spec-link [[api_laravel_gateway]]`
- `@spec-link [[api_standard_envelope]]`
- `communication.md` Architecture Document
