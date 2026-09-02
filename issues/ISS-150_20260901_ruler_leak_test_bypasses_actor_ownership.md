# Issue: `TestRulerEntityLeak` mutates `GameState` directly after `Start()`, racing the actor loop and aborting the whole `ruler` test binary

**ID:** ISS-150_20260901_ruler_leak_test_bypasses_actor_ownership
**Ref:** ISS-150
**Date:** 2026-09-01
**Severity:** Medium
**Status:** Open
**Component:** `upsilonbattle/battlearena/ruler/ruler_leak_test.go`
**Affects:**
- `upsilonbattle/battlearena/ruler/ruler_leak_test.go:37-40` — the direct write (**confirmed violation**)
- `upsilonbattle/battlearena/ruler/ruler_leak_test.go:42,56` — direct `Turner` reads, same violation class
- `upsilonbattle/battlearena/ruler/ruler_state.go:68` — `Ruler.getEntitiesState`, the concurrent reader (production, **not at fault**)
- `upsilonbattle/battlearena/ruler/ruler_fake_controller_test.go:63-72` — `testingFetchEntities`, the race-free helper that already exists and is not used here
- `upsilonbattle/battlearena/ruler/ruler_actions.go:36` — `addController`'s fire-and-forget `NotifyActor(SetQueue{...})`, the async trigger
- `docs/domain_ruler_state.atom.md` — the ownership invariant being violated
- **12 further `*_test.go` files in the same package reference `r.GameState` directly** — unaudited, see Scope

---

## Summary

Running `go test ./...` in `upsilonbattle` can abort the entire `battlearena/ruler` package with:

```
fatal error: concurrent map iteration and map write
```

`TestRulerEntityLeak` writes `r.GameState.Entities` **from the test goroutine** after `r.Start()` has
already transferred ownership of `GameState` to the Ruler's actor loop. A production reader,
`Ruler.getEntitiesState`, iterates that same map concurrently on the actor goroutine.

This is **pre-existing** and independent of any current work. It was surfaced incidentally during the
property-key-unification round (Movement default `5/5 -> 3/3`) and formally attributed as unrelated —
see Attribution below.

---

## Problem Scenario

### The violation

`ruler_leak_test.go:18-40`:

```go
func TestRulerEntityLeak(t *testing.T) {
	r := NewCompleteRuler()
	r.Start()                      // <-- ownership of GameState passes to the actor loop here
	defer r.Stop()
	...
	// 2. Intentionally mess up the ControllerID of all entities to trigger the leak guard
	for id, ent := range r.GameState.Entities {   // line 37 — read from TEST goroutine
		ent.ControllerID = uuid.Nil
		r.GameState.Entities[id] = ent            // line 39 — WRITE from TEST goroutine
	}
```

The concurrent reader is ordinary production code, `ruler_state.go:68`, which ranges
`r.GameState.Entities` while servicing a `GetEntitiesState` message. That message arrives legitimately:
`addController` (`ruler_actions.go:36`) fires `NotifyActor(SetQueue{...})` at the controller's own
actor loop **without synchronising against the `AddControllerReply` the test waits on**, so the
handshake is still in flight while the test body proceeds to mutate the map.

**Production code is not at fault.** It correctly assumes single-writer/owner semantics once the actor
is running. The test breaks that contract.

### The codebase already documents this exact anti-pattern

`ruler_fake_controller_test.go:63-72`:

```go
// testingFetchEntities performs a race-free round trip through the actor's
// message queue to read back a running Ruler's entity/turn state. Once
// Start() has been called the Ruler takes true ownership of GameState (see
// domain_ruler_state.atom.md); reading r.GameState directly from a test at
// that point races with the actor loop. ...
```

A safe helper exists. `ruler_leak_test.go` references it **zero** times.

### Why this matters more than a flaky test

A Go `fatal error` is **not recoverable and not a test failure** — it kills the test binary outright.
Every remaining test in `battlearena/ruler` therefore never reports. Observed effect: the package's
counted passes dropped from **189 to 175** in one run. Those 14 tests were not broken; they never ran.

**The failure mode is a silently truncated test count.** In CI this can mask a genuine regression in
any test scheduled after the abort, and the drop looks like arbitrary flakiness rather than a
structural problem.

---

## Reproduction

**Poor.** Observed **once in 56 runs**. It requires the host-load and scheduling conditions of a full
parallel `./...` build across the workspace; single-package stress cannot force it.

| Configuration | Runs | Reproduced |
|---|---|---|
| `go test -count=1 -run TestRulerEntityLeak ./battlearena/ruler/` | 8 | 0 |
| `go test -count=1 ./battlearena/ruler/` | 5 | 0 |
| `go test -race -count=5 ./battlearena/ruler/` | 5 | 0 |
| `go test -count=1 ./...` (upsilonbattle) | 38 | **1** |

Notably `-race` did **not** flag it, because the racing pair only co-occurs under the contended
scheduling of a full workspace build.

---

## Attribution — not caused by the Movement change

Ruled out at code level, not merely by the null stress result:

- The leak test's entities come from `GenerateRandomEntity()`, which seeds the property from
  `def.Movement()` and then immediately calls `.Set(r.Random())` over `IntRange{3,7}`.
- `DefaultIntCounterProperty.Set` (`upsilontypes/property/defaultproperty/defaultproperty.go:146`) is a
  bare `d.Value = p.(int)` with **no clamping to `MaxValue`**.
- So the constructor's `3` vs `5` is overwritten before any gameplay, turn-order, or message-timing
  code observes it, and cannot perturb the scheduling of the racing pair.
- A/B confirmed this: 20 clean `./...` runs at `3,3`, 10 clean at `5,5`.

---

## Risk Assessment

**Medium.** No production impact — the racing write exists only in test code, and the production
reader is correct. The cost is CI trust: a rare, load-dependent abort that truncates a package's test
results without an obvious failure signal. Left alone it will keep resurfacing as unexplained
flakiness and could conceal a real regression.

---

## Recommended Fix

1. **Test-first per CODING_RULE §5** is awkward here (the race is not reliably reproducible), so
   instead assert the invariant structurally: make the fix a *pattern* change and verify no
   post-`Start()` direct access remains in the touched file.
2. **Route the `ControllerID` mutation through the actor queue.** The test's intent — "entities are
   not yet fully assigned when `triggerFirstTurn` is called" — should be expressed as a message the
   Ruler processes, or by mutating `GameState` **before** `r.Start()`, which is legal and likely
   sufficient for this test's purpose.
3. **Replace the direct `Turner` reads** at lines 42 and 56 with the existing `testingFetchEntities`
   round trip.
4. **Audit the remaining 12 files** (see Scope) and convert any post-`Start()` direct accesses.
5. Consider a **lint or CI guard** rejecting `r.GameState` access in `*_test.go` after a `Start()` call
   in the same function — this class of bug is otherwise invisible until it fires.

---

## Scope — the pattern is likely not confined to one file

`grep -l "r\.GameState" upsilonbattle/battlearena/ruler/*_test.go` returns **13 files**:
`ruler_leak_test.go`, `ruler_dead_entity_next_turn_test.go`, `ruler_cold_start_test.go`,
`ruler_forfeit_trigger_test.go`, `ruler_channeling_test.go`, `ruler_shotclock_test.go`,
`ruler_victory_test.go`, `ruler_test.go`, `ruler_race_test.go`, `ruler_fake_controller_test.go`,
`ruler_move_attack_test.go`, `ruler_fullgame_test.go`, `ruler_iss101_test.go`.

**Only `ruler_leak_test.go` is confirmed to access it post-`Start()`.** Access *before* `Start()` is
legal, and `ruler_fake_controller_test.go` is the helper's own home. The other 11 need per-file
checking before any claim is made about them — this is a scoping note, **not** a violation count.

---

## References

- `docs/domain_ruler_state.atom.md` — the actor-ownership invariant
- `upsilonbattle/battlearena/ruler/ruler_fake_controller_test.go:63-72` — `testingFetchEntities`, the prescribed race-free pattern
- `issues/ISS-136_20260826_e2e_friendly_fire_skill_test_flaky.md` — sibling case of non-deterministic test failure
- `CODING_RULE.md` §2 — no ad-hoc goroutines; actor-owned state
- `CODING_RULE.md` §5 — test-first on bugs (partially inapplicable, see Recommended Fix 1)

---

## Change Log

- **2026-09-01** — Filed at user request. Surfaced during the property-key-unification round and
  **formally attributed as pre-existing and independent** (0/30 dedicated stress runs, 0/5 under
  `-race`, plus a code-level proof that the Movement constant is overwritten by an unclamped `Set`
  before any timing-sensitive read). Root cause verified directly against source: direct map write at
  `ruler_leak_test.go:37-40` after `Start()`, racing `getEntitiesState` at `ruler_state.go:68`.
