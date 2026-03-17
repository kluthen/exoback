---
id: mech_sanctum_token_renewal
human_name: Sanctum Token Renewal Mechanic
type: MECHANIC
version: 1.0
status: DRAFT
priority: CORE
tags: [auth, sanctum, middleware]
parents: 
  - [[req_security_token_ttl]]
dependents: []
---

# Sanctum Token Renewal Mechanic

## INTENT
To implement a proactive token renewal system that extends user sessions without requiring re-authentication, while ensuring security through short TTLs and grace periods.

## THE RULE / LOGIC
The renewal process follows these steps within the `SanctumTokenRenewal` middleware:

1. **Authentication:** The request must be authenticated via the `auth:sanctum` guard.
2. **Age Calculation:**
   - `CurrentAge = Now - Token.CreatedAt`
3. **Trigger Condition:**
   - If `CurrentAge >= 10 minutes` AND `CurrentAge < 15 minutes`:
     - **Check for Active Grace Period:** If `Token.ExpiresAt` is set and is in the near future (e.g., `< 20 seconds`), skip renewal (already in progress).
     - **Issue New Token:** Create a new Personal Access Token for the user with `ExpiresAt = Now + 15 minutes`.
     - **Set Grace Period:** Update the *current* token's `ExpiresAt` to `Now + 20 seconds`.
     - **Store for Response:** Save the new `plainTextToken` in the request context.
4. **Response Modification:**
   - Intercept the final JSON response.
   - If a new token was issued:
     - Inject into envelope: `meta.token = <NewToken>`
     - Inject into envelope: `meta.message = "Token renewed"`

## TECHNICAL INTERFACE (The Bridge)
- **Middleware:** `App\Http\Middleware\SanctumTokenRenewal`
- **Code Tag:** `@spec-link [[mech_sanctum_token_renewal]]`
- **Test Names:** `test_token_renewal_triggered_after_10_minutes`, `test_grace_period_allows_access_but_no_further_renewal`

## EXPECTATION (For Testing)
- Requests at T+9m -> No renewal.
- Requests at T+11m -> New token in meta, old token persists for 20s.
- Requests at T+11m05s (using old token) -> Normal response, no new renewal triggered.
- Requests at T+11m25s (using old token) -> 401 Unauthorized.
