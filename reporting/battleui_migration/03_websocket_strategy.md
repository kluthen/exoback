# 03 — WebSocket Strategy (the core motivation)

The user's primary reason for this migration: *"as we use websocket, it introduced the need to
have multiple instances of the docker to handle the side ws communication."* This document is
the heart of the study.

## 1. Why there are multiple containers today

```
┌──────────┐  broadcast()   ┌──────────────┐   Pusher proto   ┌──────────┐
│  app     │ ─────────────▶ │  ws (Reverb) │ ◀──── WS ──────  │ Vue/Echo │
│ PHP-FPM  │  (broadcast    │  PHP daemon  │                  │ pusher-js│
│ REST API │   connection)  │  port 8080   │                  └──────────┘
└──────────┘                └──────────────┘
```

PHP-FPM handles one request per worker and tears the worker down afterwards — it physically
cannot hold thousands of open sockets. So Laravel's broadcasting model **requires a separate
long-lived daemon** (Reverb) speaking the **Pusher protocol**. Production therefore runs the
same image twice (`app` + `ws`). The API process *emits* events; Reverb *delivers* them.
`ShouldBroadcastNow` (used by `BoardUpdated`) makes delivery synchronous to avoid the queue,
but the two-process split remains.

## 2. Why Go removes the constraint

A Go HTTP server is a single process that handles requests **and** holds long-lived
goroutine-backed sockets simultaneously. The webhook handler can write to Postgres and then
call `hub.Publish(channelKey, payload)` **in the same process, same memory** — the fan-out is a
channel send, not a network hop to a broker. One binary, one container. The `app`/`ws`/`db-init`
trio collapses to a single `hub` service (+ a migrate step run on boot or as an init job).

```
┌──────────────────────────────────────────┐
│  hub (Go)                                  │
│  Gin REST  ──┐                             │   WS    ┌──────────┐
│              ├─▶ in-proc Hub ──goroutine──▶│────────▶│ frontend │
│  /webhook ───┘   (map[channelKey][]*conn)  │         └──────────┘
└──────────────────────────────────────────┘
```

## 3. The decision that drives frontend effort: transport protocol

The frontend currently uses `laravel-echo` + `pusher-js` against Reverb. **The Go service must
choose what it speaks.** Three options:

### Option A — Native WebSocket hub + thin client shim (recommended)
- Go exposes `/ws?token=...`; on connect, authenticate the Sanctum-equivalent token and the
  requested `user.{ws_channel_key}` / `arena.{matchId}` channel using the **existing channel
  auth rules** (`channels.php` logic ports directly).
- Replace `laravel-echo`/`pusher-js` on the client with a **small wrapper** exposing the same
  `Echo.private(channel).listen(event, cb)` surface the composables already use
  (`useBattleChannel`, `usePrivateChannel`, `useBoardState`). Because those composables are the
  only consumers, the blast radius is ~3 files + `bootstrap.js`.
- **Pros:** simplest, leanest server; drops `pusher-js` entirely; full control of framing/tracing.
- **Cons:** you write+maintain the client shim and reconnection/backoff logic Echo gave you free.

### Option B — Speak the Pusher protocol in Go (zero frontend change)
- Implement (or use a library implementing) the Pusher channels protocol so `laravel-echo` with
  `broadcaster: 'reverb'/'pusher'` connects unchanged. Go libraries exist but are less mature
  than the Laravel/Reverb pairing.
- **Pros:** frontend (`bootstrap.js`, composables, `VITE_REVERB_*`) untouched; lowest client risk.
- **Cons:** you inherit Pusher protocol complexity (channel auth handshake, ping/pong, event
  envelopes) just to preserve a dependency you're trying to shed. Carries the Pusher mental model
  into Go for little benefit.

### Option C — Server-Sent Events (SSE) for the realtime feed
- Game/board updates are **server→client only** (clients send moves via REST `POST /game/{id}/action`,
  not over the socket). That makes the realtime channel a natural fit for **SSE**, which is just
  HTTP and trivially traced by OpenTelemetry/`otelhttp`.
- **Pros:** dead-simple server + client (`EventSource`), auto-reconnect built in, no WS upgrade,
  proxy-friendly, first-class in OTel.
- **Cons:** unidirectional (fine here — confirm no future need for client→server push over the
  socket); some corporate proxies buffer SSE; need a heartbeat.

> **Recommendation:** **Option A** (native WS + thin shim) as the default, with **Option C (SSE)
> as a strong contender** precisely because today's realtime traffic is one-directional
> (engine → webhook → fan-out to spectators/players). SSE would make the observability story
> (doc 04) cleaner since every push is a normal HTTP span. Avoid Option B — re-implementing
> Pusher in Go preserves the exact dependency the migration aims to delete.

> **RESOLVED (2026-07-04, Bastien): Option C — SSE.** The gameplay strategy does not depend on
> high-speed bidirectional communication: client-issued requests stay on the plain REST API,
> and only a limited set of events needs server push.

### Implementation notes for Phase 3 (now the SSE phase)

- `GET /events` — authenticated like any API call; `text/event-stream`; heartbeat comment
  every ~25s (proxy-buffering guard); named events mirroring today's broadcasts
  (`board.updated`, `match.found`).
- **Per-recipient fog-of-war masking (§4) is unchanged**: one stream per user means the
  masked payload is rendered per connection exactly as it would have been per WS socket.
- `Last-Event-ID` + a short server-side replay buffer so a mid-match reconnect resumes
  seamlessly (EventSource retries automatically — the replay buffer is our half of the deal).
- Frontend: replace `laravel-echo`/`pusher-js` with a small `EventSource` wrapper keeping the
  `.private(channel).listen(event, cb)` surface the 3 composables use (~4 files, as scoped).
- Simplification candidate: with a token-authenticated per-user stream, the rotating
  `ws_channel_key` may retire (its job was Pusher channel auth). Decide in Phase 3; it touches
  the `users` schema and login flow, so if kept it must be for a reason, not inertia.
- Future client→server push (if ever needed) is a new REST/WebSocket endpoint *beside* SSE,
  not a rework of it — acceptable trade accepted with this decision.

## 4. Channel auth & masking carry over directly

Regardless of transport, the security model ports 1:1:
- **`user.{key}`**: authorize iff connecting user's `ws_channel_key == key` (rotated each login).
- **`arena.{matchId}`**: authorize iff requester is a `MatchParticipant` of the match.
- **Per-recipient masking:** `BoardUpdated` builds a *different* payload per participant via
  `BoardStateResource($payload, $recipient)` (fog-of-war). In Go the hub must fan out a
  **per-connection rendered payload**, not a single shared frame. Don't lose this — it is a
  gameplay-correctness and anti-cheat property, and it means you cannot naively broadcast one
  serialized message to a channel.

## 5. Scaling note (future, not now)

Today everything is single-node. The in-process hub scales vertically to a large socket count on
one box (Go handles this well). If you later need multiple `hub` replicas, reintroduce a fan-out
bus (Redis pub/sub or NATS) *between* replicas — but that is an explicit future scaling decision,
not a day-one requirement, and crucially it's then **your** choice rather than a constraint forced
by the framework. The migration's immediate win is going from "3 containers forced by PHP" to
"1 container, scale when you actually need to."
