# Upsilon Hub: Agent Reference Index

Welcome to Upsilon Hub. To ensure consistent and high-quality development, follow the specialized rulesets linked below in order of priority.

## 0. Universal Coding Standard ([CODING_RULE.md](CODING_RULE.md))
**TRANSVERSE — APPLIES IN EVERY UPSILON PROJECT (umbrella + all submodules), BEYOND ATD.**
The full standard is in [CODING_RULE.md](CODING_RULE.md); read it before writing or changing code. The seven non-negotiables, condensed so they are always in context:

1. **ATD adherence** — no business-layer change without its settled atom; one CONTRACT + one VISION per project; links atop functions; games never import games.
2. **OpenTelemetry native** — instrument HTTP/DB/outbound from day one; propagate `traceparent`; map `X-Request-ID` ⇄ trace; **never** call `time.Now()` or spawn ad-hoc goroutines/tickers (injected clock + durable jobs).
3. **Crash early / fail fast** — defaulting hides bugs; no silent failures or catch-all defaults in core logic; a clear panic beats undefined behavior.
4. **Strict API contract adherence** — honor the API/interface exactly; **no defaulting to "save the day"**; the envelope is a hard contract; cross-seam access only through the owning interface.
5. **Test-first on bugs** — reproduce the error as a failing test at the nearest module *before* fixing it; no test-only branches in production code.
6. **Zero-error code health** (`code_health_check.py`) — file ≤400/600 LOC, nesting ≤4, doc every function, 1–10 ATD links/file.
7. **Change discipline** — docs (`communication.md`, Postman, atoms) move with code; commit/push only when asked; binaries to `bin/`.

## 1. Project Map & Infrastructure ([UPSILON.md](.agent/rules/UPSILON.md))
**MANDATORY READING FOR GROUNDING.** UPSILON.md holds the full "Who's Who", port mappings, workflows, and testing toolkit. The landscape, condensed so it's always in context:

**Services (all Go unless noted):**
- **upsilonhub** — platform gateway: auth/identity, matchmaking, economy, admin, realtime **SSE**, DB schema + migrations/seed; serves the REST `/api/v1` and the built SPA. OTel-instrumented. Hub `:8090`, front door (Caddy) `:8085`.
- **upsilonbattleui** — Vue 3 / Vite standalone SPA (management UI + battle client + admin); talks to `/api/v1`, listens on SSE. Built and served by the hub. Dev `:5173`.
- **upsilonapi** — the "Bridge": high-performance JSON API for the engine. `:8081`.
- **upsilonbattle** — core engine (`BattleArena`), embedded in upsilonapi.
- **upsiloncli** — terminal, E2E testing, and bot orchestration (goja JS scenarios).

Post–Phase 6 the Laravel `battleui` and its Reverb WebSockets are **decommissioned**; the hub owns everything above.

**Umbrella folders** (each `upsilon*` is a Git submodule, except `upsilonserializer`, an in-tree Go module):
- `/upsilonhub` `/upsilonbattleui` `/upsilonapi` `/upsilonbattle` `/upsiloncli` — the services above.
- `/upsilontypes` `/upsilonserializer` `/upsilonmapdata` `/upsilonmapmaker` `/upsilontools` — shared Go libraries.
- `/upsilonaws` — AWS provisioning (`eu-west-3`).
- `/scripts` (dev/CI/deploy/code-health), `/docs` (ATD atoms), `/issues` (tracked debt), `/reporting` (architecture anchors + v3 platform docs), `go.work`.

**Hub v3 internals** (`upsilonhub/internal/…`) — the platform is assembled here by composition:
- `platform/` — substrate services, each an extraction candidate: `identity` (→ future `upsilonauth` SSO), `economy`, `character`, `clock` (injected — never `time.Now()`), `jobs` (durable — no ad-hoc goroutines/tickers).
- `games/` — game modules; today `battle`. **Games never import games** (cross-game flow via platform state, shared vocabularies, or the event bus).
- `gateway/` (HTTP surface + SSE + SPA), `events/` (domain event bus), `transport/`, `observability/` (OTel), `database/`, `seed/`, `config/`, `testutil/`.

The four-game v3.0 trajectory (battle/tycoon/spy/digital), service→project ownership, and contract/vision attribution live in [`reporting/v3_platform/service_map.md`](reporting/v3_platform/service_map.md).

## 2. Development Governance ([ATD.md](.agent/rules/ATD.md))
**CORE WORKFLOW.**
Defines the Atomic Traceable Documentation (ATD) lifecycle. Follow this for all feature development and bug fixes:
- **Atom Blueprint**: Strict structure for `.atom.md` files.
- **11 Types**: From CONTRACT/VISION to REQUIREMENT to MECHANIC.
- **Lifecycle Phases**: Discovery → Specification → Implementation → Verification.

## 3. Operational Guards & Standards ([COMMON.md](.agent/rules/COMMON.md))
**SAFETY & PROTOCOL.**
Standard rules for communication (API envelopes), error handling (Crash Early), and strict testing tool usage. Contains the "don'ts" of the project.

## 4. Issue Management ([issues.md](.agent/rules/issues.md) / [issue_management skill](.agent/skills/issue_management/SKILL.md))
**MAINTENANCE.**
Protocol for filing, tracking, and resolving technical debt, bugs, and risks in the `/workspace/issues/` directory using the system-wide `issues` command.

---

*Always prioritize these rules over generic assumptions. When in doubt, check CODING_RULE.md for how to write/change code, UPSILON.md for location, and ATD.md for intent.*