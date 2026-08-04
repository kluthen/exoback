# Precursor — `upsilonplatform` Kit Adoption Gap

**Status:** Precursor document for spec-writer review — problem statement and evidence only.
Not a spec: it proposes no migration plan, ordering, or estimate.
**Date:** 2026-08-04. **Origin:** documentation audit performed during ISS-124 investigation.

---

## 0. Correction to the originating premise — read this first

This audit was commissioned on the premise that "the `upsilonplatform` shared kit is not
actually used by `upsilonapi`, `upsilonauth` or `upsiloneconomy`." That premise verifies fully
for **`upsilonapi` only**. For **`upsilonauth` and `upsiloneconomy`, it is false at the source
level**: both import and use the kit's `respond`, `middleware`, `clock`, `observability`,
`database` and (for `upsilonauth`) `jobs`/`httpx` packages extensively, and their router wiring
matches the kit's prescribed middleware chain exactly (verified below). The real, narrower,
verified problem for those two services is a **`go.mod`/`go.sum` declaration gap**, not
non-adoption. This document reports the problem as it actually is, not as originally briefed —
an inaccurate precursor would be worse than none, since it feeds a future spec.

---

## 1. The rule

`architecture/how_to_add_a_service.md` §3 (lines 70–74):

> Use the **`upsilonplatform` kit — never copy its code**: `respond` (envelope), `middleware`
> (envelope unwrap + error→envelope + recovery), `clock` (injected — `time.Now()` is forbidden
> in domain/gateway code), `observability` (OTel setup), `database` (pgxpool + otelpgx +
> migrate helpers taking your `embed.FS`), `jobs` (River, only if the service has background
> work), `httpx` (S2S client — see §7).

`architecture/service_map.md:45` describes the kit and its rationale:

> Shared mechanical kit extracted **verbatim** from `upsilonhub` on 2026-07-22: `respond`
> (envelope), `clock`, `observability`, `database`, `jobs` (River wrapper), plus new `httpx`
> (S2S client — traceparent, `X-Internal-Token`, `X-Request-ID`). Every new service composes on
> it; **copy nothing** — parity across serving processes can't survive copy-drift.

The kit's own governance atoms state the same intent. `upsilonplatform/docs/contract_platform_kit.atom.md` (INTENT):

> Establish upsilonplatform as the single mechanical source of the cross-cutting service
> plumbing — API envelope, injected clock, OTel observability, database pool/migrate, River
> jobs and the internal S2S HTTP client — so that no service reimplements or drifts from these
> mechanics.

`upsilonplatform/docs/vision_platform_kit.atom.md` (INTENT and RULE/LOGIC):

> Every Upsilon service is assembled from one mechanical kit, so cross-service parity — the
> same envelope, the same time, the same trace, the same trust seam — is a structural property
> of the platform rather than a discipline each team must uphold.
>
> Adding a service should mean writing its domain, not its plumbing.

## 2. The reality, per service

### 2.1 `upsilonapi` — zero adoption

`grep -rln "ecumeurs/upsilonplatform" upsilonapi --include="*.go"` returns **no matches**, and
`upsilonapi/go.mod` requires only `gin-gonic/gin`, `google/uuid`, `sirupsen/logrus`,
`stretchr/testify` — no `go.opentelemetry.io/*` dependency exists anywhere in the module (direct
or indirect).

Concretely, `upsilonapi` reimplements the kit's mechanics from scratch:

- **Envelope** — `upsilonapi/stdmessage/message.go` defines `StandardMessage[T, M]` with fields
  `RequestID, Message, Success, Data, Meta` in that order, plus `New`/`NewWithMeta`
  constructors. This is structurally identical to `upsilonplatform/respond.Envelope`
  (`RequestID, Message, Success, Data, Meta`, same field order, same "byte-compatible with the
  Laravel envelope" lineage per `respond.go`'s own doc comment) — two independently maintained
  copies of the same contract, exactly the copy-drift the kit exists to prevent. `upsilonapi/api/output.go`'s `NewSuccess`/`NewError` build on this local type, not on `respond`.
- **Gin wiring** — `upsilonapi/handler/handler.go` calls `c.JSON(...)` directly with no
  `otelgin.Middleware`, no `middleware.Envelope()`, no error/recovery middleware from the kit.
- **Time** — `upsilonapi/handler/handler.go:35` calls `time.Now()` directly
  (`bs := api.NewBoardState(id, g, entities, players, turner, time.Now(), time.Now().Add(30*time.Second), ...)`)
  instead of using the kit's injected `clock.Clock`.
- **No OTel setup at all** — no `observability.Setup`, no `otelpgx`, no `otelhttp`.

### 2.2 `upsilonauth` — kit-composed in source, undeclared in `go.mod`

`grep -rn "ecumeurs/upsilonplatform" upsilonauth --include="*.go"` returns 25 non-test hits
across `cmd/upsilonauth/main.go`, `internal/gateway/router.go`, `internal/gateway/auth.go`,
`internal/gateway/introspect.go`, `internal/gateway/compose_http.go`,
`internal/gateway/middleware/{auth,internal}.go`, `internal/identity/pg.go`,
`internal/accountpush/{accountpush,hubclient}.go`, `internal/seed/seed.go` and
`internal/testutil/postgres.go`. All seven kit packages are used: `respond`, `middleware`,
`clock`, `observability`, `database`, `jobs`, `httpx`.

`internal/gateway/router.go`'s middleware chain is, verified line-for-line, exactly the order
`how_to_add_a_service.md` §3 prescribes: `otelgin.Middleware` → `respond.SetDebug` →
`platformmw.Envelope()` → `observability.RequestIDSpanAttribute()` → `errDeps.Recovery()`.

**But** `upsilonauth/go.mod` does not list `github.com/ecumeurs/upsilonplatform` in its
`require` block (verified: `grep -n upsilonplatform upsilonauth/go.mod` returns nothing), and
there is no corresponding `go.sum` entry. Building the module standalone confirms this is a
real gap, not a false alarm: `cd upsilonauth && GOWORK=off go build ./...` fails with 11 errors,
all "missing go.sum entry" for the kit's transitive deps (`otelpgx`, `riverqueue/river`, gin
OTel contrib). The module only builds because (a) the umbrella `go.work` stitches
`upsilonplatform` in as local workspace source for `go build`/`go vet`/`go test` run from the
umbrella root, and (b) `upsilonauth/Dockerfile` runs its own scoped
`go work init ./upsilonplatform ./upsilontypes ./upsilonauth` before building. Both paths mask
the gap; neither is `go.mod` declaring the dependency it visibly imports.

### 2.3 `upsiloneconomy` — same pattern, plus one deliberate kit-limitation duplication

`grep -rn "ecumeurs/upsilonplatform" upsiloneconomy --include="*.go"` returns 17 non-test hits
across `cmd/upsiloneconomy/main.go`, `internal/api/{awards,gdpr,middleware,router,shopitems,purchases,wallets,helpers,inventory}.go`,
`internal/economy/pg.go` and `internal/testutil/postgres.go`. Packages used: `respond`,
`middleware`, `clock`, `observability`, `database`. (`jobs`/`httpx` are not used —
`upsiloneconomy` has no background jobs and is called, not caller, on the S2S seam.)

`internal/api/router.go`'s chain matches the same prescribed order as `upsilonauth`'s.

Same `go.mod` gap: no `require github.com/ecumeurs/upsilonplatform` line, no `go.sum` entry.
`GOWORK=off go build ./...` fails immediately: `go: updates to go.mod needed; to update it: go mod tidy`.

One additional, worth-flagging finding: `internal/api/middleware.go`'s `Envelope()` function
**deliberately re-implements** ~30 lines of the kit's request-unwrap logic, with its own
explanatory comment:

> The logic is intentionally duplicated rather than imported: the shared kit's prefix is fixed
> to the public surface, and this service must not modify it.

This is not carelessness — it is a genuine limitation of the kit surfaced by the first
internal-only consumer: `upsilonplatform/middleware.Envelope()` hardcodes the public `/api/v1`
prefix, so an internal-only service (`/internal/v1`) cannot reuse it as-is and has to hand-roll
the unwrap. This is a kit-side gap, not just an adopter-side one, and belongs in scope for the
eventual refactor.

### 2.4 No `go.mod` in the umbrella declares the kit, anywhere

`grep -rn "ecumeurs/upsilonplatform" */go.mod` across the whole umbrella repo returns zero
matches, including `upsilonhub/go.mod`. Nothing in this workspace formally, self-sufficiently
depends on `upsilonplatform` as a real Go module dependency — every consumer relies on `go.work`
(directly, or via a Dockerfile's scoped `go work init`) to resolve it silently.

## 3. The contradiction, correctly scoped

`how_to_add_a_service.md:8-10` names `upsilonauth` and `upsiloneconomy` as reference
implementations and instructs "Copy from them, not from memory." Given §2 above, this is
**not** the contradiction originally assumed (it does not tell readers to copy plumbing from
services that ignore the kit — they don't). The actual risk is narrower but real:

1. **Both named references already fail `go mod tidy`.** A reader who scaffolds a new service
   by literally copying `upsilonauth`'s or `upsiloneconomy`'s `go.mod` as a starting point
   inherits a `go.mod` that is already missing the one dependency the same document mandates
   using. The doc's own §2 step ("run `go work sync` afterwards and expect `go.mod`/`go.sum`
   churn") does not fix this — `go work sync` reconciles versions already declared across
   workspace modules, it does not discover and add a newly-imported module's `require` line;
   only `go mod tidy` run inside the service module does that, and it appears never to have
   been run for either service since the kit imports were added.
2. **The doc doesn't flag `upsiloneconomy`'s `Envelope()` duplication as a sanctioned
   exception.** A reader copying `internal/api/middleware.go` verbatim (reasonable, since it's
   held up as a reference) has no signal that this ~30-line block is the one place in that
   codebase where "never copy code" was knowingly broken, and why.
3. `upsilonapi` is correctly never named as a reference — no direct contradiction there — but
   the document also does not flag it as the negative example, even though it is the platform's
   only service with zero kit adoption and (§4 below) the direct cause of the platform's one
   OTel gap.

`how_to_add_a_service.md` itself is **out of scope for editing in this pass** — per
instruction, its correction (reference-implementation framing, a callout on the adoption gap,
and any staleness in the closing `<!-- Phases 3-6 -->` comment) is deferred to be delivered
correctly at the end of the spec-writer's review process, once the scope above is settled, not
patched ad hoc now.

## 4. Why it happened (history, not blame)

The kit was extracted **verbatim** from `upsilonhub` on 2026-07-22
(`architecture/service_map.md:45`), in the same window as the `upsilonauth`/`upsiloneconomy`
strangler extractions (`architecture/service_map.md` §2). Because of that shared timing,
`upsilonauth` and `upsiloneconomy` were built composing on the kit from day one — the source
evidence in §2.2/§2.3 shows correct, deep adoption, matching the doc's prescribed wiring order
exactly. What appears to have been skipped is the mechanical last step of formalizing that
adoption in each module's own `go.mod` (`go mod tidy`) — plausibly because every build/test/CI
path that exercises these modules (the umbrella `go.work`, and each service's own Dockerfile
`go work init` step) already resolves the import silently, so the gap never surfaced as a
build failure anywhere it would be noticed.

`upsilonapi` predates this entire effort. It is the original battle-engine bridge service, not
part of the 2026-07-22 platform/identity/economy strangler work (it appears nowhere in
`service_map.md` §2's extraction rows), and its envelope package traces back to an earlier,
pre-kit era: `respond.go`'s own doc comment describes the kit's envelope as "the Go port of
battleui's ApiResponder trait," the same lineage `upsilonapi/stdmessage`'s doc comment claims
independently ("defines the universal communication envelope for all Upsilon Hub services").
Both trace to the same Laravel-era origin but were ported separately and have since diverged
into two maintained copies.

## 5. The stakes

**(a) Copy-drift across serving processes** — the exact failure the kit exists to prevent
(`service_map.md:45`) — is a live, present-tense fact for `upsilonapi`: its
`stdmessage.StandardMessage[T, M]` and the kit's `respond.Envelope` are two independently
maintained structs with the same shape and the same "byte-compatible with Laravel" mandate.
Any future change to the envelope's wire behavior (the contract atom calls this "byte-frozen")
has to be made and verified in two places, with no mechanism forcing them to stay identical.

**(b) The OTel connection — this is the strongest argument in this document, and it is now
better-evidenced than originally assumed, not weaker.** `architecture/service_map.md` §1 and
§7 item 4 state that `upsilonapi` is the platform's one un-instrumented service, and that
`upsilonauth`/`upsiloneconomy` are "**born instrumented**: the `upsilonplatform` kit's
`observability` package (otelgin/otelpgx setup) and `httpx` (W3C traceparent propagation on S2S
calls) come for free at scaffold time, no separate instrumentation step needed." Section 2.2/2.3
above **independently verifies this claim as true** — both services really do import and call
`observability`/`otelgin` and get OTel "for free." The flip side is just as directly
verifiable: `upsilonapi` imports none of it, and has zero `go.opentelemetry.io/*` dependencies
anywhere in its module graph. Not being on the kit is not correlated with the OTel gap — it
**is** the OTel gap. `architecture/observability.md` (the design doc `service_map.md` calls
"doc 04") independently confirms this has been the approved, unexecuted design since before the
kit existed: its architecture diagram (§3) already shows `upsilonapi (Go) ──OTLP──▶` as a
target sender, and §2 explicitly calls for instrumenting `upsilonapi`'s HTTP client with
`otelhttp` — exactly what the kit's `httpx` package already provides for any service that
imports it.

**(c) Envelope byte-parity is called a hard contract**
(`how_to_add_a_service.md:104-105`: "byte-parity is a hard contract, which is why the envelope
lives in the kit"), yet `upsilonapi` reimplements it wholesale (§2.1), and `upsiloneconomy`
reimplements a slice of the kit's request-side handling for a legitimate but undocumented
reason (§2.3) — a genuine gap in the kit's own coverage (no story yet for an internal-only
service's request prefix) rather than an adopter mistake.

## 6. Scope of the eventual refactor (inventory only — no plan, no order, no estimate)

**Modules affected:**

- `upsilonapi` — full adoption gap: no kit import at all. Would need `respond` (replacing
  `stdmessage`), `middleware`/`observability` (replacing manual `gin.Engine` wiring, adding
  `otelgin`), `clock` (replacing the direct `time.Now()` calls in `handler/handler.go`), and a
  decision on `database`/`jobs`/`httpx` depending on whether `upsilonapi` gains a database or
  outbound S2S calls.
- `upsilonauth`, `upsiloneconomy` — already kit-composed in source; the gap is
  `go.mod`/`go.sum` declaration hygiene only (add an explicit `require
  github.com/ecumeurs/upsilonplatform ...` and matching `go.sum` entries so each module builds
  standalone with `GOWORK=off`, independent of the workspace/Dockerfile crutches).
- `upsilonplatform` (the kit itself) — `middleware.Envelope()`'s public-prefix assumption is a
  documented blocker for internal-only consumers; `upsiloneconomy`'s hand-rolled duplicate is
  the concrete symptom.

**Already compliant (source level):** `upsilonauth`, `upsiloneconomy` — pending the `go.mod`
fix in the previous bullet.

**Not yet checked / out of scope for this document:** whether any other umbrella module besides
the three named here (e.g. `upsilontypes`, `upsilonhub`) has the same undeclared-workspace-only
dependency pattern on `upsilonplatform` or on each other; this document makes no claim either
way and it should be swept for in the same pass if the refactor touches `go.mod` hygiene at all.

**What "compliant" would mean**, for the spec-writer to define precisely later:

1. `go.mod` declares `github.com/ecumeurs/upsilonplatform` as a real required module with
   matching `go.sum` entries; the module builds with `GOWORK=off`.
2. All envelope construction goes through `upsilonplatform/respond`; zero independently-defined
   envelope structs anywhere in the service.
3. `observability.Setup` + `otelgin` + `otelpgx` (where a database exists) are wired at boot.
4. All time in domain/gateway code comes from an injected `clock.Clock`; no direct `time.Now()`.
5. Any outbound S2S call uses `upsilonplatform/httpx`.

## Related, unresolved observation (not part of this document's scope to fix)

`upsilonplatform/docs/contract_platform_kit.atom.md` and `vision_platform_kit.atom.md` both
carry `status: DRAFT`, not `SETTLED`, despite `service_map.md` §6 listing
`contract_platform_kit`/`vision_platform_kit` as "settled" for the `upsilonplatform` project.
This is a discrepancy between the atom files and the map that references them; flagged here as
an observation only — ATD atoms are governed and out of scope for this document or its author
to alter.
