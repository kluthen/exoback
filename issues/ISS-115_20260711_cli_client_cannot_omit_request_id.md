# Issue: CLI HTTP Client Unconditionally Injects Request ID — "Missing Request ID" Path Untestable via E2E

**ID:** `20260711_cli_client_cannot_omit_request_id`
**Ref:** `ISS-115`
**Date:** 2026-07-11
**Severity:** Low
**Status:** Open
**Component:** `upsiloncli/internal/api/client.go`
**Affects:** `upsiloncli/tests/scenarios/edge_api_missing_request_id.js` (EC-37, rewritten during this audit); any future E2E scenario intending to prove server-side behavior when `X-Request-ID` / envelope `request_id` is absent or malformed.

---

## Summary

`upsiloncli`'s HTTP client (`Client.Do` in `upsiloncli/internal/api/client.go:62-98`) always generates a fresh UUIDv7 and stamps it onto **both** the outgoing JSON envelope's `request_id` field **and** the `X-Request-ID` header, on every call, with no parameter or scripting primitive to suppress it. The JS scripting bridge (`upsiloncli/internal/script/bridge.go`, `jsCall`) drives every endpoint exclusively through this client — there is no raw/low-level HTTP escape hatch exposed to scenario scripts. This makes the server's actual "id is missing" fallback path (`upsilonhub/internal/gateway/respond/respond.go:RequestID`, which falls through body -> header -> `NewID()`) structurally unreachable from the CLI-based E2E suite, even though the server-side behavior is correct and already unit-tested at the Go layer.

This is a **different root cause** from ISS-112 (which is `bridge.go`'s admin-route guard blocking non-admin-as-caller-of-admin-route testing). This one is the API transport client's unconditional header/body injection — no relation to admin-section gating. Filed separately per the audit's own de-duplication guidance.

---

## Technical Description

### Background
Per atom `[[upsilonapi:api_request_id]]`, the request id is "SHOULD"-level on the wire (optional but recommended); the real contract is that the *Backend Gateway forwards the caller's id or generates a new one if missing* — never a rejection. `respond.RequestID()` implements this exactly:
1. cached context value,
2. `request_id` field of the JSON body,
3. `X-Request-ID` header,
4. a freshly generated UUIDv7 (`NewID()`), also format-agnostic — a malformed header value is echoed back verbatim, not rejected.

### The Problem Scenario
```
Scenario intent: prove the server generates a request id (rather than
                 rejecting) when the caller sends none.

Attempt:  upsilon.call("profile_get", {})
Result:   upsiloncli/internal/api/client.go:66-98 (Client.Do) has already
          unconditionally set envelope.RequestID = uuid.NewV7() and
          req.Header.Set("X-Request-ID", requestID) before the request is
          ever sent — every call through jsCall carries a valid id, always.

Net effect: no scripting path exists that sends a request with NO id at all;
            the CLI can only ever prove its own id round-trips, not that the
            server tolerates a missing one.
```
Confirmed deterministic (5/5 identical runs, this audit) — not RNG-dependent, a structural client-layer property.

Independently confirmed via raw `curl` (bypassing the CLI entirely) against this same stack:
```
$ curl -s -X POST http://localhost:8090/api/v1/auth/register -H "Content-Type: application/json" -d '{"account_name":"...", ...no request_id field...}'
# no X-Request-ID header sent either
-> HTTP 200, response request_id = a freshly generated UUIDv7 (e.g. 019f4fef-55ec-70f3-...)

$ curl ... -H "X-Request-ID: not-a-uuid-at-all"
-> HTTP 200, response request_id echoed back verbatim "not-a-uuid-at-all" (no format validation)
```
Both confirm the atom's documented fallback/no-rejection behavior exactly.

### Where This Pattern Exists Today
- `upsiloncli/internal/api/client.go:66-98` (`Client.Do`) — unconditional id generation + header/body injection, no bypass parameter.
- `upsiloncli/internal/script/bridge.go` (`jsCall`) — only entry point for scenario scripts to reach any endpoint; routes exclusively through `Client.Do` via `ep.ExecuteRaw`.
- Real (and already covered) server behavior: `upsilonhub/internal/gateway/respond/respond.go:138-160` (`RequestID`), unit-tested at `upsilonhub/internal/gateway/respond/respond_test.go:99-108` (`TestGeneratesFreshUUID7IfMissing`).

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | Certain — reproduces on every run, deterministically; not RNG-dependent. |
| Impact if triggered | Low — the guarded behavior (graceful fallback, not a security boundary) is independently verified correct via Go unit test and manual curl; this is a coverage/testability gap, not a live production risk. |
| Detectability | Low-Medium — a scenario asserting "missing id is handled" could easily mistake "the CLI's own id round-trips" for "the server tolerates a missing id," which is exactly the false-green the original EC-37 scenario embodied (though via a different, weaker mechanism: zero assertions at all). |
| Current mitigant | Go unit test (`TestGeneratesFreshUUID7IfMissing`) covers the real fallback path already; this issue only concerns E2E/CLI reachability. |

---

## Recommended Fix

**Short term:** Keep EC-37 rewritten to pin the one thing actually observable via this harness — that the CLI's own generated `request_id` round-trips unchanged through the full envelope, including on an error response — with an honest header comment documenting the limitation. Do not claim this scenario proves the server's missing-id fallback.

**Medium term:** None needed for correctness — the fallback already has Go unit coverage (`respond_test.go`). No production gap to close.

**Long term:** If genuine E2E coverage of the missing/malformed-id path is ever desired, add a scripting escape hatch to `upsiloncli` — e.g. an explicit low-level `upsilon.rawCall(method, path, body, {headers})` that bypasses `Client.Do`'s automatic envelope/header stamping — analogous to ISS-112's recommended `callAsNonAdmin` escape hatch, but for transport-header control rather than admin-session control.

---

## Extra Data

- The atom's own wording is permissive ("SHOULD... optional but highly recommended"), so unlike ISS-112 (a security-relevant untested negative path) this gap is low-stakes: the fallback is a graceful default, not a rejection, and is already unit-tested.
- The original EC-37 scenario's defect was actually worse than "hard to test": it made zero assertions about request-ID behavior at all and unconditionally logged PASSED, despite its own comment admitting the CLI can't omit the header. Rewritten during this audit (ISS-107) to assert the one real, observable, honest thing.

---

## References

- `upsiloncli/internal/api/client.go:62-98` (`Client.Do`, unconditional id injection)
- `upsiloncli/internal/script/bridge.go` (`jsCall`, sole scripting entry point)
- `upsilonhub/internal/gateway/respond/respond.go:138-174` (`RequestID`, `NewID`)
- `upsilonhub/internal/gateway/respond/respond_test.go:99-108` (`TestGeneratesFreshUUID7IfMissing`)
- `upsiloncli/tests/scenarios/edge_api_missing_request_id.js` (EC-37, rewritten during this audit)
- Related but distinct: `issues/ISS-112_20260710_admin_negative_path_untestable_via_cli.md` (same general class — CLI harness structurally blocks a negative-path E2E test — but a different mechanism/component)
