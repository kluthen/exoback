# Issue: Missing sliding TTL for Sanctum tokens

**ID:** `20260316_sanctum_token_sliding_ttl`
**Ref:** `ISS-021`
**Date:** 2026-03-16
**Severity:** Medium
**Status:** Resolved
**Component:** `battleui/app/Http/Controllers/API/AuthController.php`
**Affects:** All authenticated API routes in `battleui/routes/api.php`

---

## Summary

The current implementation of Laravel Sanctum does not enforce a token expiration or a proactive renewal mechanism. Tokens remain valid indefinitely (or until manually revoked/deleted), which violates the security requirement for a 15-minute TTL with a proactive renewal window.

---

## Technical Description

### Background
The system uses Laravel Sanctum for API authentication. Personal Access Tokens are issued upon login and registration. The security requirement specifies that these tokens should expire after 15 minutes of inactivity, with each request renewing the 15-minute window.

### The Problem Scenario
1. A user logs in and receives a token (Token A).
2. The user makes a request with Token A after 11 minutes of creation.
3. **Current Behavior:** Token A is still valid and no new token is issued.
4. **Expected Behavior:** 
   - A new token (Token B) is issued and returned in `meta.token`.
   - Token A is marked to expire in 20 seconds.
   - Any further requests using Token A during its 20s grace period SHOULD NOT trigger more renewals.

### Where This Pattern Exists Today
- `battleui/config/sanctum.php`: `'expiration' => null` (line 50).
- `battleui/app/Http/Controllers/API/AuthController.php`: Tokens are created without expiration.
- `battleui/routes/api.php`: Authenticated routes do not have a sliding window middleware applied.

---

## Risk Assessment

| Factor              | Value  |
| ------------------- | ------ |
| Likelihood          | High   |
| Impact if triggered | Medium |
| Detectability       | Medium |
| Current mitigant    | None   |

---

## Recommended Fix

**Short term:** Update `AuthController` to set a 15-minute `expires_at` on initial token creation.
**Medium term:** Implement `SanctumTokenRenewal` middleware that:
- Identifies tokens older than 10 minutes.
- Issues a new token and returns it in response metadata.
- Sets a 20-second grace period on the old token.
- Prevents double-renewal during the grace period.
**Long term:** Ensure all API clients are updated to handle the `meta.token` field for seamless session continuity.

---

## References

- [req_security.atom.md](../../docs/req_security.atom.md)
- [req_security_token_ttl.atom.md](../../docs/req_security_token_ttl.atom.md)
- [AuthController.php](../battleui/app/Http/Controllers/API/AuthController.php)
