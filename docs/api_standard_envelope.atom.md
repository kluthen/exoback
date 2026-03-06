---
id: api_standard_envelope
human_name: Standard JSON Message Envelope
type: API
version: 1.0
status: DRAFT
priority: CORE
tags: [api, json, envelope, standard]
parents: []
dependents:
  - [[api_laravel_gateway]]
  - [[api_go_battle_engine]]
---

# Standard JSON Message Envelope

## INTENT
To establish a universal, predictable structure for all JSON exchanges between entities (Vue, Laravel, Go) to guarantee tracability, consistent error handling, and extensibility.

## THE RULE / LOGIC
Every JSON payload transmitted over HTTP or WebSocket between system units MUST conform to the following root structure:

```json
{
  "request_id": "018f5a...", // String: UUIDv7. Identifies the specific transaction flow.
  "message": "...",         // String: A one-liner intent, status summary, or error message.
  "success": true,          // Boolean: Indicates if the operation was successful.
  "data": {},               // Object/Array: The core JSON payload of the query or response.
  "meta": {}                // Object: Arbitrary, undocumented side information (e.g., for testing or debug).
}
```

### Constraints:
*   **Originator generates the ID:** The entity taking the primary initiative generates the `request_id` (a UUID v7). 
    *   *Vue* generates it for user-driven interactions.
    *   *Laravel* forwards this exact ID to the Go engine when proxying.
    *   *Go* maintains this ID in its immediate `200 Accepted` reply.
    *   *Go* generates an entirely *new* `request_id` when it initiates asynchronous webhooks/notifications back to Laravel.

## TECHNICAL INTERFACE (The Bridge)
*   **API Endpoint:** Universal (Global Request/Response Middleware)
*   **Code Tag:** `@spec-link [[api_standard_envelope]]`
*   **Related Issues:** None
*   **Test Names:** `TestJsonEnvelopeValidation`, `TestProxyMaintainsRequestId`

## EXPECTATION (For Testing)
*   A request received lacking a `request_id` should either automatically generate one in middleware or immediately return a `success: false` HTTP 400 bad request, depending on strictness.
*   The literal key names `request_id`, `message`, `success`, `data`, and `meta` must always exist in a response, even if null/empty.
