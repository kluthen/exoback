# Issue: BattleUI ApiResponder Inconsistency and Underuse

**ID:** `20260316_battleui_api_responder_inconsistency`
**Ref:** `ISS-024`
**Date:** 2026-03-16
**Severity:** Medium
**Status:** Resolved
**Component:** `battleui/app/Http/Controllers/API`
**Affects:** All Laravel-based API consumers (Vue frontend)

---

## Summary

The `battleui` Laravel application contains several API controllers that manually construct JSON responses using `response()->json()` instead of utilizing the `ApiResponder` trait. Furthermore, the existing `ApiResponder` trait does not fully comply with the `api_standard_envelope` and `api_request_id` ATD specifications, particularly regarding field naming and `request_id` resolution logic.

---

## Technical Description

### Background
The system defines a standard JSON envelope in [[api_standard_envelope]] which includes `request_id`, `success`, `message`, `data`, and `meta`. 
[[api_request_id]] specifies that `request_id` should be a UUIDv7 and that the Laravel gateway should forward the ID from the requester or generate a new one.

### The Problem Scenario
1.  **Manual Construction:** Controllers like `AuthController`, `MatchMakingController`, and others manually build response arrays. Check `AuthController@login` or `MatchMakingController@joinMatch`.
2.  **Trait Inconsistency:** The `App\Traits\ApiResponder` trait:
    -   Uses `errors` field instead of standardizing failure messages or using `meta`.
    -   Missing `request_id` and `meta` fields.
    -   Currently implemented as:
        ```php
        protected function success(mixed $data, string $message , int $code = 200): JsonResponse {
            return response()->json([
                'success' => true,
                'message' => $message,
                'errors' => '',
                'data'    => $data,
            ], $code);
        }
        ```
3.  **Incorrect Request ID Resolution:** Currently, where `request_id` is implemented (e.g., manually in `AuthController`), it uses:
    `'request_id' => $request->header('X-Request-ID', (string) str()->uuid()),`
    This ignores the requirement to check the payload's `request_id` first and uses UUIDv4 instead of UUIDv7.

### Where This Pattern Exists Today
-   [AuthController.php](file:///home/bastien/work/upsilon/projbackend/battleui/app/Http/Controllers/API/AuthController.php)
-   [MatchMakingController.php](file:///home/bastien/work/upsilon/projbackend/battleui/app/Http/Controllers/API/MatchMakingController.php)
-   [ApiResponder.php](file:///home/bastien/work/upsilon/projbackend/battleui/app/Traits/ApiResponder.php)

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | High |
| Impact if triggered | Medium (Tracability/Standardization issues) |
| Detectability | High |
| Current mitigant | None (manual implementation is inconsistent) |

---

## Recommended Fix

**Short term:** 
1.  Update `ApiResponder` trait to include `request_id` and `meta` fields.
2.  Implement a `resolveRequestId(Request $request)` helper in the trait or a middleware that follows the priority: payload `request_id` > header `X-Request-ID` > fresh UUIDv7.
3.  Align field names with [[api_standard_envelope]].

**Medium term:** 
Refactor all `battleui` controllers to use the `ApiResponder` trait's `success()` and `error()` methods.

**Long term:** 
Implement a global middleware in Laravel to automatically wrap all API responses in the standard envelope if not already wrapped, ensuring 100% compliance.

---

## References

- [api_standard_envelope.atom.md](file:///home/bastien/work/upsilon/projbackend/docs/api_standard_envelope.atom.md)
- [api_request_id.atom.md](file:///home/bastien/work/upsilon/projbackend/docs/api_request_id.atom.md)
- [ApiResponder.php](file:///home/bastien/work/upsilon/projbackend/battleui/app/Traits/ApiResponder.php)
