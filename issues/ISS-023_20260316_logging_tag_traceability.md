# Issue: Ensure all logs are tagged with Request ID

**ID:** `20260316_logging_tag_traceability`
**Ref:** `ISS-023`
**Date:** 2026-03-16
**Severity:** High
**Status:** Open
**Component:** `infra/logging`
**Affects:** `battleui`, `go-engine`, `laravel-gateway`

---

## Summary

The system currently lacks a strictly enforced requirement to tag every log entry with its originating `request_id`. This makes cross-service debugging and transaction tracing difficult, as logs from Laravel and Go cannot be easily interleaved per-request.

---

## Technical Description

### Background
We use [[api_request_id]] to uniquely identify flows. The standard envelope [[api_standard_envelope]] and tracing rule [[rule_tracing_logging]] define how these IDs move, but we lack a formal requirement and implementation verification that *every* log follows this.

### The Problem Scenario
A request arrives at Laravel, gets an ID, and logs its receipt. It proxies to Go. Go fails silently or with an error that doesn't include the ID in the log. Searching for the ID in centralized logs only shows the Laravel half of the journey.

### Where This Pattern Exists Today
- Laravel standard `storage/logs/laravel.log` (standard format).
- Go Engine stdout.
- See [[req_logging_traceability]] for the defined requirement.

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | High |
| Impact if triggered | High |
| Detectability | Medium — manifests as "blind spots" in logs |
| Current mitigant | Partial implementation in [[rule_tracing_logging]] |

---

## Recommended Fix

**Short term:** Update logging middleware in Laravel and Go to always inject the `request_id` (from `X-Request-ID` or payload) into the log context.
**Medium term:** Implement a centralized log collector that validates the presence of the ID.
**Long term:** Use a tracing library (e.g., OpenTelemetry) to automate this at the span level.

---

## References

- [[api_request_id]]
- [[req_logging_traceability]]
- [[rule_tracing_logging]]
