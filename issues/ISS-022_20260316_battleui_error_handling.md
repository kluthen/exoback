# Issue: Improper major error handling in BattleUI

**ID:** `20260316_battleui_error_handling`
**Ref:** `ISS-022`
**Date:** 2026-03-16
**Severity:** High
**Status:** Open
**Component:** `battleui/bootstrap/app.php`
**Affects:** All API consumers (Vue frontend, Go engine)

---

## Summary

In BattleUI, major internal errors or unhandled exceptions currently return HTML content (often including a stack trace) instead of a clean, structured JSON response. This violates the `api_standard_envelope` requirement and can break client-side parsing.

---

## Technical Description

### Background
The system is required to use a standard JSON envelope for all API responses, as defined in `docs/api_standard_envelope.atom.md`. This includes error scenarios, which should return a JSON payload with `success: false`, a descriptive `message`, and the original `request_id`.

### The Problem Scenario
When a critical error occurs (e.g., database connection failure, syntax error in a controller, or an unhandled exception):
1. Laravel's default exception handler triggers.
2. Because the `withExceptions` block in `battleui/bootstrap/app.php` is empty, Laravel falls back to default behavior.
3. If the request doesn't explicitly header `Accept: application/json` or if the error happens early enough, Laravel may return an HTML "Whoops" page or a generic HTML error page.
4. **Current Behavior:** HTML stack trace or HTML error page is returned.
5. **Expected Behavior:** A JSON response conforming to `api_standard_envelope`.

### Where This Pattern Exists Today
- `battleui/bootstrap/app.php` (lines 22-24): The `withExceptions` configuration is empty.
- Lack of a global "Force JSON" or "Always Return JSON" middleware for the API prefix that wraps exceptions.

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | Medium |
| Impact if triggered | High |
| Detectability | High |
| Current mitigant | Some controllers manually use `response()->json(...)` but this doesn't cover global/unexpected crashes. |

---

## Recommended Fix

**Short term:** Update `battleui/bootstrap/app.php` to use the `shouldRenderJsonWhen` method or a custom renderer in the `withExceptions` block to ensure all exceptions on `/v1/*` routes return JSON.
**Medium term:** Implement a dedicated API Exception Handler that formats all exceptions into the `api_standard_envelope` structure.
**Long term:** Ensure all system components (Go, Laravel) share a common error-reporting library or middleware that strictly enforces the JSON envelope.

---

## References

- [api_standard_envelope.atom.md](../../docs/api_standard_envelope.atom.md)
- [bootstrap/app.php](../battleui/bootstrap/app.php)
