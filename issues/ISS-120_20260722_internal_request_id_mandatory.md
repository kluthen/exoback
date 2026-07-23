# Issue: Internal S2S calls elide request_id — mandatory correlation id is empty on every internal message

**ID:** `20260722_internal_request_id_mandatory`
**Ref:** `ISS-120`
**Date:** 2026-07-22
**Severity:** High
**Status:** Fixed & CI-verified — unit+integration green across 4 repos; 6-image stack scenario suite 33/37 (the 4 = pre-existing ISS-119 race + privacy flakes, zero request_id rejections in cross-service logs)
**Component:** `upsilonplatform/httpx/httpx.go`
**Affects:** `upsilonhub/internal/transport/economyclient`, `upsilonhub/internal/transport/authclient` (Phase 4), `upsilonhub/internal/awards`, `upsiloneconomy/internal/api`, every future internal service chain

---

## Summary

Every service-to-service call the hub makes through `upsilonplatform/httpx` currently ships an **empty** `request_id` in the request envelope. `httpx` reads the id from the call context, but nothing ever puts one there: the hub never adopts its inbound `X-Request-ID` into the outbound context, and durable jobs (the award worker) run on a background context with no id at all. A `request_id` is **mandatory** — it must never be empty — so an internal exchange with no identifier is a defect. Today the exchanges are short (one hop), but as internal-only chains grow (Phase 4 introduces the authclient introspection hop and the enroll→auth push; more services follow) an unidentified chain is untraceable. This must be documented and rectified **before** building more internal call chains.

---

## Technical Description

### Background

The standard envelope carries `request_id` on both legs so a message can be correlated end-to-end (CODING_RULE §2: OTel-native, map `X-Request-ID` ⇄ trace). `upsilonplatform/httpx` is the single S2S client every service uses; it wraps each outbound request as `{request_id, data}`, taking the id from `RequestIDFromContext(ctx)`. Receivers (`upsiloneconomy`, `upsilonauth`) unwrap the envelope and adopt the id into their own request context.

### The Problem Scenario

```
1. Public request → hub. respond middleware assigns request_id R (= X-Request-ID).
2. Gateway handler calls economy via economyclient using c.Request.Context().
3. httpx.encodeRequest → RequestIDFromContext(ctx) == ""   ← R was never put in ctx
   → envelope ships {"request_id":"", "data":{...}}.  R is DROPPED; economy
     cannot correlate its work back to R.
4. Match settlement enqueues an award_credits River job. The worker drains it on
   a FRESH background context (correctly no inbound R). httpx again ships
   request_id:"" — but here there is no id at all, so the internal award
   exchange is wholly UNIDENTIFIED (should mint a new id).
```

The empty id is also what first manifested as a functional bug: `upsiloneconomy`'s envelope-unwrap keyed off a *non-empty* id and bailed on `""`, binding the outer envelope into every DTO (awards 422, shop-create 500). Fixed defensively in `ba61a64` (unwrap on the `data` key's presence, matching `upsilonauth`). That fix is correct and necessary — but it treats the receiver symptom; the root defect is the **sender never populating the id**.

### Where This Pattern Exists Today

- `upsilonplatform/httpx/httpx.go` `encodeRequest` — reads the ctx id, never mints when absent.
- `upsilonhub` gateway/economyclient call sites pass `c.Request.Context()` without `httpx.ContextWithRequestID` — no adoption of the inbound id.
- `upsilonhub/internal/awards` worker — background ctx, no id seeded on enqueue or drain.
- Contrast **ISS-115**: `upsiloncli` does the opposite extreme — *unconditionally* mints a fresh id per call. That also defeats chain correlation (each hop invents a new id). The correct rule is adopt-then-propagate, mint only at a true origin.
- Defensive receiver mitigation already in place: `upsiloneconomy/internal/api/middleware.go` unwraps regardless of id value (`ba61a64`).

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | High — every internal S2S call today ships an empty id |
| Impact if triggered | Medium/High — internal chains are untraceable by request_id; violates the OTel-native standard (CODING_RULE §2). No data loss (OTel `trace_id` still propagates via `traceparent` on synchronous hops). |
| Detectability | Low — silent; the field is simply blank in logs/envelopes, nothing errors |
| Current mitigant | Receivers tolerate empty id (`ba61a64`); OTel `trace_id` carries on sync hops via otelhttp (but not across the durable-job boundary) |

---

## Recommended Fix

**Short term:** Document the invariant (this issue): a `request_id` is mandatory on **every** message including internal-only and multi-hop internal chains; it is never empty. Gate Phase 4 design on it — the authclient hop and enroll→auth push must carry a correlation id from day one.

**Medium term:**
- **Enforce centrally in `httpx`:** if the call context has no request_id, mint one in `encodeRequest` (belt-and-suspenders) so no internal call is ever unidentified.
- **Adopt + propagate (sync path):** the hub must inject its inbound `X-Request-ID` into the outbound context (`httpx.ContextWithRequestID`) at the economyclient/authclient call sites, so a request→internal chain shares one id. Every receiver already adopts the id from the envelope; ensure each re-propagates it on its own outbound calls (multi-hop chains keep one id).
- **Durable jobs:** carry the originating request_id onto the River job at enqueue and restore it into the worker context on drain; a genuinely origin-less job mints a fresh id. Never empty. (Also carry the OTel trace context across the job boundary so the async award correlates to the settlement.)

**Long term:** A single correlation-context convention baked into the platform kit (`httpx` + `middleware` + `jobs`) so adopt/propagate/mint is automatic and structurally impossible to elide. Once senders always populate, tighten receivers to **reject** an empty request_id (crash-early) rather than tolerate it — resolving the ISS-115 tension too (kit owns the policy; the CLI stops unconditionally minting mid-chain).

---

## Extra Data

Discovered 2026-07-22 during the Phase-3 economy-swap finish: the empty id surfaced first as awards 422 / shop-create 500 (economy unwrap bailing on empty id), fixed defensively in `upsiloneconomy` `ba61a64`. Confirmed the hub has zero `httpx.ContextWithRequestID` usages, so the id is dropped on every internal call. OTel `trace_id` continuity confirmed present on sync hops (httpx otelhttp transport) but the durable award path is not trace-linked to its settlement.

---

## Resolution (2026-07-23, branch `iss-120-mandatory-request-id` on all four repos)

Adopt-then-propagate + central mint + reject-empty, baked into the platform kit so eliding the id is structurally hard:

**Senders always populate (never empty):**
- `upsilonplatform/httpx` — `do()` now calls `ensureRequestID(ctx)` (context.go) once per call, minting a UUIDv7 when the ctx carries none, so the envelope body and the `X-Request-ID` header always share the SAME non-empty id.
- `upsilonplatform/middleware.Envelope` — after resolving the id it injects it onto `c.Request`'s stdlib context via `httpx.ContextWithRequestID`, so EVERY gateway handler's `c.Request.Context()` auto-propagates the inbound id to its outbound S2S calls, no per-handler threading. (Fixes the root gap: gin's context value never reached `context.Context`.)
- `upsilonhub/internal/awards` — `Args` gains `RequestID`; `resolveRequestID` adopts the settlement ctx's id on enqueue (mints only for a genuinely origin-less enqueue); `Worker.Work` restores it onto the drain context. The async award now correlates to its settlement across the durable-job boundary.

**Receivers reject empty (crash-early — Bastien chose "tighten now"):**
- New shared `upsilonplatform/middleware.RequireRequestID()` + `CallerRequestID()` (header-only, unambiguous — does not read the gin context key which `respond.RequestID` also fills with a generated id). Mounted on `upsilonauth`'s `/internal/v1` group.
- `upsiloneconomy/internal/api.Envelope` rejects an internal call with no caller id (400) before generating one. The defensive unwrap-on-`data`-key (`ba61a64`) stays as belt-and-suspenders.

**Tests (test-first):** httpx mint-when-absent (POST body==header id, GET header); middleware adopt + mint into outbound ctx; RequireRequestID accept/reject; economy + auth internal reject-missing-id (400); awards resolve/adopt/mint + Worker propagates. All green; `go vet` clean; `code_health_check.py` errors 0.

**Deliberately deferred (follow-ups, not blocking):**
- OTel **trace-context** across the River job boundary (issue's medium-term; request_id correlation is done, trace propagation across jobs is a larger River-middleware piece).
- ISS-115 (`upsiloncli` unconditional mint) — under adopt-then-propagate the CLI is a true origin, so minting is correct; remains a Low testability gap only.
- Pre-existing CONTRACT-as-`@spec-link` debt across the kit (see ATD memory) and `api_request_id` atom relocation out of `upsilonapi` — separate cleanup.

## References

- `upsilonplatform/httpx/httpx.go` (`encodeRequest`, `RequestIDFromContext`, `ContextWithRequestID`)
- `upsilonhub/internal/transport/economyclient/client.go`
- `upsilonhub/internal/awards/awards.go` (enqueue + worker)
- `upsiloneconomy/internal/api/middleware.go` (`unwrapEnvelope`, defensive fix `ba61a64`)
- `upsilonauth/internal/gateway/internal.go` (`bindInternal` — reference unwrap)
- Related: **ISS-115** (`upsiloncli` unconditionally injects a fresh request id)
- CODING_RULE.md §2 (OpenTelemetry native; map `X-Request-ID` ⇄ trace)
