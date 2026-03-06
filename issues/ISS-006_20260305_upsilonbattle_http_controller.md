# Issue: Implement HTTP Controller for UpsilonBattle

**ID:** `20260305_upsilonbattle_http_controller`
**Ref:** `ISS-006`
**Date:** 2026-03-05
**Severity:** High
**Status:** Open
**Component:** `upsilonbattle/api`
**Affects:** `upsilonbattle/engine`

---

## Summary

To support the Proxied Communication architecture, the Go engine needs an HTTP `Controller` that acts as a bridge to the internal engine, translating incoming REST API payloads into native `actor` messages, and translating engine broadcasts into outgoing webhook calls. Additional external libraries may need to be imported or refactored for the HTTP layer to work.

---

## Technical Description

### Background
The existing system interacts purely over internal `messagequeue` actors or the CLI. We need an HTTP controller implementation that accepts game commands from the API Gateway and routes them into the game loop.

### The Problem Scenario
Without this HTTP Controller proxying commands, there is no way for the Laravel API to trigger game actions or receive game updates. The HTTP Controller must handle both receiving action POSTs and tracking the `callback_url` for async state updates.

### Where This Pattern Exists Today
This does not exist in the current application.

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

**Short term:** Define the interfaces and create a placeholder HTTP Controller that implements the required player/controller signature.
**Medium term:** Implement the HTTP router (e.g., standard `net/http`) and the outbound webhook dispatcher. Ensure necessary cross-domain libraries are moved/available in the Go workspace. Validate that the controller successfully bridges `POST` requests and `AddController` requirements.
**Long term:** N/A

---

## References

- `@spec-link [[api_go_battle_engine]]`
- `communication.md` Architecture Document
