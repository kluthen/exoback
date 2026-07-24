# 04 — Observability: OpenTelemetry Integration Design

> In scope: **integration design** — how the new Go service is instrumented and how telemetry
> threads through the existing stack. Out of scope (deferred): exploitation — choosing/operating
> backends, dashboards, SLOs, alerting. This document gets the signals *emitted and correlated*;
> what consumes them is a later decision.

## 1. The gap today

There is effectively **no distributed tracing** in the project. battleui has a good
*structured-logging convention* — `[[rule_tracing_logging]]` emits `[ts] [ref_id] [endpoint] msg`
and `request_id` (UUIDv7) is threaded from client → API → engine via `X-Request-ID`. That
`request_id` is a **proto-trace-id**: a correlation key already flowing across service boundaries
but not attached to spans or exported anywhere. OpenTelemetry formalises exactly this.

## 2. Three signals, one design

### Traces (the priority)
- **Bootstrap:** OTel Go SDK with an OTLP exporter (gRPC/HTTP) to a collector. Service resource
  attributes: `service.name=upsilon-hub`, `service.version`, `deployment.environment`.
- **Auto-instrument the edges:**
  - `otelgin` middleware → a server span per HTTP request.
  - `otelpgx` (or GORM OTel plugin) → DB query spans.
  - `otelhttp` transport on the `upsilonapi` client → client spans for every engine call.
- **Bridge the existing correlation id:** adopt **W3C `traceparent`** propagation, and map the
  current `X-Request-ID` to it — either set `request_id = trace_id` or record `request_id` as a
  span attribute (`upsilon.request_id`) so existing logs/Postman flows stay correlatable.
  Inject `traceparent` on outbound calls to `upsilonapi`; **instrument `upsilonapi` to continue
  the trace** so a player action becomes one end-to-end trace: `Gin handler → engine HTTP →
  engine internals → webhook callback → WS/SSE fan-out`.
- **Custom spans for domain operations** that today are invisible: `matchmaking.join`,
  `arena.start`, `arena.resurrect` (ISS-054 — high-value to trace, it's the flakiest path),
  `webhook.ingest`, `board.broadcast` (with per-recipient child spans), `credits.award`.

### Metrics
- HTTP (rate/latency/status via `otelgin`), DB pool stats, engine-call latency/error rate.
- **Domain gauges/counters** the team actually wants: active WS/SSE connections, players in
  queue per mode, active matches, matches concluded, resurrection attempts/successes/failures,
  credits awarded, token renewals. These answer real operational questions the current stack
  can't.

### Logs
- Keep the `[[rule_tracing_logging]]` format but emit **structured** (slog/zap JSON) with
  `trace_id`/`span_id` fields so logs auto-correlate to traces. The existing `ref_id` (first 8 of
  request_id) stays as a human-friendly handle.

## 3. Architecture

```
upsilon-hub (Go) ──OTLP──┐
upsilonapi  (Go) ──OTLP──┼──▶ OpenTelemetry Collector ──▶ [backend TBD — deferred]
(future: cli)   ──OTLP──┘        (batching, sampling)
```

Stand up a **collector** as the single export seam. The hub and engine send OTLP to it; what the
collector forwards (Jaeger/Tempo/Honeycomb/etc.) is the deferred "exploitation" decision and can
change without touching app code. Add it as one service in `docker-compose*.yaml` (it replaces
none of the collapsed containers — net container count after migration is still well below today).

## 4. Why doing this *during* the rewrite is the right call

- **Greenfield instrumentation is cheap; retrofitting is expensive.** Adding `otelgin`/`otelpgx`/
  `otelhttp` while writing the handlers costs near-zero; bolting it onto mature code later is a
  project of its own.
- **The correlation backbone already exists** (`request_id`/`X-Request-ID`) — OTel formalises a
  pattern the team already believes in, rather than imposing a new one.
- **It validates the migration itself.** End-to-end traces during side-by-side running are the
  best evidence that the Go path reproduces the Laravel path (latency, call counts, error shapes).
- **Go has the better OTel story.** The instrumentation libraries are first-party and mature;
  this is a concrete reason the Go target *improves* on Laravel rather than just matching it.

## 5. Concrete first steps (Phase 0 deliverable)

1. Add OTel SDK + OTLP exporter; wrap Gin with `otelgin`; one collector in compose.
2. Map `X-Request-ID` ⇄ `traceparent`; record `upsilon.request_id` span attribute.
3. Instrument the `upsilonapi` client (`otelhttp`) and propagate context.
4. Convert logging to structured slog with `trace_id`/`span_id`.
5. Add a `matchmaking.join` custom span as the reference example for the team.

> Everything beyond emitting + correlating these signals (sampling policy, backend, dashboards,
> alerts) is intentionally left for the later "exploitation" phase the user flagged.
