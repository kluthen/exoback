# Issue: Missing JSON REST API & Webhook Dispatcher in Go Engine

**ID:** `20260305_upsilonbattle_api_gap`
**Ref:** `ISS-002`
**Date:** 2026-03-05
**Severity:** High
**Status:** Resolved
**Component:** `upsilonbattle/api` (needs creation)
**Affects:** `laravel-api-gateway`

---

## Summary

The current `upsilonbattle` Go engine lacks a JSON REST API and a webhook dispatcher. It operates purely on internal `actor` messages or CLI. To integrate into the broader ecosystem via the Proxied Approach (Vue ↔ Laravel ↔ Go), it must accept HTTP REST commands from Laravel and dispatch state changes back to Laravel via webhooks.

---

## Technical Description

### Background
Currently, UpsilonBattle rules are driven by internal data structures (`messagequeue`). There is no network-facing interface. 

### The Problem Scenario
When Laravel attempts to start a match (`POST /internal/arena/start`) or forward a player move (`POST /internal/arena/{id}/action`), the Go engine has no HTTP server to receive these instructions. Furthermore, when Go updates the board, it has no mechanism to push this data back to Laravel's cache.

### Where This Pattern Exists Today
This is a completely missing subsystem in the Go repository.

---

## Risk Assessment

| Factor              | Value                                   |
| ------------------- | --------------------------------------- |
| Likelihood          | High (100% required for architecture)   |
| Impact if triggered | High (System will simply not integrate) |
| Detectability       | High                                    |
| Current mitigant    | None                                    |

---

## Recommended Fix

**Short term:** Define the API boundaries using ATD Atoms (`api_go_battle_engine`).
**Medium term:** Implement a basic standard library `net/http` router or use a lightweight framework (like Fiber/Gin) to expose the endpoints in a new `/api` or `/server` package within the Go engine. Implement a simple HTTP client to POST state deltas to a provided `callback_url`.
**Long term:** N/A

---

## References

- `@spec-link [[api_go_battle_engine]]`
- `communication.md` Architecture Document
