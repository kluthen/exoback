# Issue: Human player turns in PVE matches sometimes silently auto-passed by the engine

**ID:** `20260622_pve_human_turn_silently_autopassed`
**Ref:** `ISS-101`
**Date:** 2026-06-22
**Severity:** High
**Status:** Resolved — the structural gap (entities allowed to exist without a controller) is closed and enforced at both `AddEntity` and `handTurn`; the reported symptom (silent auto-pass with no notification) is now structurally impossible regardless of cause. The exact path by which the original `1v1_PVE` match's player entity acquired a Nil `ControllerID` in production was never forensically pinned down, but that is moot given the fix — see "Fix Implemented" below
**Component:** `upsilonbattle/battlearena/ruler/ruler_turn.go`
**Affects:** `upsilonbattle/battlearena/ruler/behavior/behavior.go`, `upsilonbattle/battlearena/ruler/ruler.go` (AddEntity — no controller validation), `upsilontypes/entity/entity.go` (entity.New defaults ControllerID to uuid.Nil), `upsilonapi/bridge/bridge_start.go` (StartArena/setupControllers sequencing — original, now-secondary suspect), `upsiloncli/tests/scenarios/*.js` (9 edge-case scripts), real players using `1v1_PVE`/`2v2_PVE` practice matches

---

## Summary

In some `1v1_PVE` matches, the human player's queued turns are silently auto-passed by the engine without ever notifying the WS client, while the PVE AI continues to act normally. The player's team can be wiped having taken zero actions, with no error, no shot clock, and no "your turn" event ever sent. This was discovered while debugging CI flakiness (GitHub Actions run `27952883421`), but the underlying mechanism is engine-side and would affect real players in practice/PVE matches too, not just test bots.

---

## Technical Description

### Background

Turn order is managed by `Turner` (`upsilonbattle/battlearena/ruler/turner/turner.go`): a queue of `EntityTurn{EntityId, Delay}` sorted ascending by delay. `Turner.NextTurn()` pops the lowest-delay entry, normalizes the rest, and sets `CurrentEntityTurn`. `Ruler.handTurn(entID)` (`ruler_turn.go:73`) is then responsible for either:
- dispatching to an automated `Behavior` (for controller-less entities like traps), or
- notifying the entity's real `Controller` (human WS client or AI archetype controller) and starting the shot clock.

### The Problem Scenario

Observed turn-queue evolution from a single failing CI match (`edge_movement_path_too_long`, see Extra Data below for the full trace):

```
snapshot 5/6  queue (sorted by delay):
   delay=39   entity=019eef5c... (PLAYER, is_self=true)   <- lowest delay, should be next
   delay=151  entity=7fa232ef... (enemy, is_self=false)
   delay=226  entity=a9e9c3bc... (enemy, is_self=false)
   delay=251  entity=019eef5c... (PLAYER, is_self=true)

snapshot 7    queue:
   delay=151  entity=7fa232ef... (enemy)      <- current_entity_id! (higher delay than the player's 39)
   delay=226  entity=a9e9c3bc... (enemy)
   delay=251  entity=019eef5c... (PLAYER)

   -> the delay=39 PLAYER entity vanished from the queue without ever
      appearing as current_entity_id anywhere in the match.
```

The CLI client log never contains a single `"My Turn!"` line for any of the player's 3 entities throughout the entire match, while all 3 enemy entities take repeated, normal turns (moves/attacks) until the player's team is wiped (`DEFEAT... WINNER: TEAM 2`), with the player having issued zero `game_action` calls.

The mechanism that would produce exactly this symptom is `handTurn()` in `ruler_turn.go:90`:

```go
behaviorProp := ent.GetProperty(property.AIBehavior)
behaviorSlug := "none"
if behaviorProp != nil {
    behaviorSlug = behaviorProp.Get().(string)
}

if behaviorSlug != "none" || ent.ControllerID == uuid.Nil {
    // automated branch: behavior.GetBehavior(behaviorSlug) for "none" resolves
    // to ExpirationBehavior, whose Decide() just returns an EndOfTurn message,
    // self-dispatched 50ms later (ruler_turn.go:96-99). No shot clock is
    // started, and NO controller is ever notified.
    b := behavior.GetBehavior(behaviorSlug)
    msg := b.Decide(r.GameState, ent)
    r.SelfDispatchMessageDelayed(msg, 50*time.Millisecond)
    return
}
// ... only entities that DON'T hit the branch above reach
// r.startShotClock() + ctrl.NotifyActor(ControllerNextTurn{...})
```

If this branch fires for a human player's entity, their turn resolves as an instant no-op pass roughly every time it's their turn, which is indistinguishable (from the WS client's perspective) from "never gets a turn at all" — matching the observed behavior exactly.

### Where This Pattern Exists Today

- `upsilonbattle/battlearena/ruler/ruler_turn.go:90-100` — the automated-vs-controlled branch in `handTurn`.
- `upsilonbattle/battlearena/ruler/behavior/behavior.go:36-47` — `ExpirationBehavior`, documented as "the default behavior for entities that just wait to die" / intended "for simple non-actor entities that do not have their own Controller" (see doc comment on the `Behavior` interface, lines 22-30). It is not supposed to apply to player characters.
- Entity creation paths were checked and **do** set `ControllerID` correctly for both human and AI entities:
  - `upsilonapi/bridge/bridge_start.go:159-164` (`addExplicitEntity`, human players) — `ControllerID: playerID`.
  - `upsilonapi/bridge/bridge_start_archetype.go:159-165` (`generateEntityFromArchetype`, AI/auto-gen entities) — `ControllerID: controllerID` (also `playerID`).
  - `AIBehavior` property defaults to `"none"` for every entity (`upsilontypes/property/def/entity.go:86-87`), so `behaviorSlug != "none"` should normally be false for both player and AI characters (AI opponents are driven by a real `Controller` implementation — `upsilonbattle/battlearena/controller/controllers/aggressive.go` — not this ruler-level behavior fallback).
- This means the exact trigger for `ent.ControllerID == uuid.Nil` (or `behaviorSlug` reading as non-`"none"`) on a human player's entity, at the moment `handTurn` runs, is **not yet root-caused**. The leading suspect is sequencing in `StartArena` (`upsilonapi/bridge/bridge_start.go:78-81`):
  ```go
  battleArena.Ruler.Start()                                  // line 78 — may begin dispatching turns
  if err := b.setupControllers(...); err != nil { ... }       // line 79 — registers controllers async via SendActor+respChan
  ```
  `Ruler.Start()` runs before controller registration is confirmed complete. If `triggerFirstTurn`/`handTurn` can run before a given player's `AddController` message has been processed by the Ruler's actor, that's a plausible race window — but the precise code path that would make `ent.ControllerID` itself read back as `uuid.Nil` (it's set at entity-creation time, before `Ruler.Start()`, so it shouldn't be empty) is still unconfirmed. This needs either added instrumentation or a debugger-attached repro to pin down with certainty.

### Downstream symptom in CI

9 scenario test scripts in `upsiloncli/tests/scenarios/` share a `waitNextTurn()` → `if (!board) upsilon.assert(false, "ERROR: Match ended unexpectedly")` pattern on their very first turn wait:

```
edge_attack_target_no_entity.js
edge_movement_path_not_adjacent.js
edge_attack_skill_cooldown.js
edge_attack_target_not_in_range.js
edge_attack_target_out_of_grid.js
edge_movement_path_too_long.js
edge_movement_grid_boundaries.js
edge_movement_obstacle_collision.js
edge_movement_jump_limitations.js
```

When this bug triggers during one of these scripts' `1v1_PVE` match, the script hard-fails with that assertion (since the match ends in defeat with the player never having had a turn), even though the script's actual test logic was never exercised. Two different scripts from this list hit exactly this failure mode in GitHub Actions run `27952883421` (`edge_movement_path_not_adjacent`, `edge_movement_path_too_long`), distinct from a previously-fixed pair of unrelated scenario-script bugs.

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | Medium — observed twice in one CI run (~2/55 sequential `1v1_PVE` matches), so plausibly a real-world race rather than a one-off fluke |
| Impact if triggered | High — a real player can lose a PVE practice match having never been able to act, with zero error/feedback |
| Detectability | Low — silent: no error, no log on the client side, no shot-clock event; only detectable by reconstructing the turn queue / cross-referencing `current_entity_id` across snapshots, as done here |
| Current mitigant | None. The affected test scripts just hard-fail; there is no retry or detection in production |

---

## Reproduction (added 2026-06-22, inverted same day once the fix landed)

`upsilonbattle/battlearena/ruler/ruler_iss101_test.go` turned this from a log-archaeology finding into an on-demand, deterministic repro, then into a permanent regression guard once fixed:

- Originally: `TestRulerControlledEntitySilentlyAutoPassedWhenControllerIDNil` proved the *symptom* mechanism (silent auto-pass via `ExpirationBehavior`, zero notification), and `TestRulerAddEntityAcceptsNilControllerIDWithNoValidation` proved the deeper *structural* gap (nothing rejected a Nil `ControllerID` anywhere). Both passed, characterizing the broken behavior.
- After the fix (see "Fix Implemented" below), both were inverted into `TestRulerAddEntityRejectsNilControllerID` and `TestRulerHandTurnRejectsNilControllerID`, which now assert that both choke points (`AddEntity`, `handTurn`) panic on a Nil `ControllerID` instead of silently accepting/routing it.

## Deeper Root Cause (revised 2026-06-22)

The original framing ("why did a human player's `ControllerID` momentarily read `uuid.Nil`?") was too narrow. The real problem is structural: **the engine has no enforced invariant that every entity must have an owning controller**, and it overloads `uuid.Nil` as a meaningful sentinel for "this entity is automated." Specifically:

- `entity.New()` (`upsilontypes/entity/entity.go:61-72`) explicitly defaults `ControllerID: uuid.Nil`.
- `Ruler.AddEntity` (`ruler.go:180-195`) — the generic "put this entity on the board" API — never validates or rejects a Nil `ControllerID`. Confirmed via `TestRulerAddEntityAcceptsNilControllerIDWithNoValidation`: it's accepted, queued into the Turner, and stored as-is.
- `behavior.go`'s doc comment and `docs/mech_ruler_behavior.atom.md` (status: **DRAFT**) describe Nil `ControllerID` as the *intentional* signal for "non-actor" entities — traps, turrets, simple summons.
- But **no production code path actually creates such entities today.** `entity.Type` values `TimeBased`/`Trap`/`AreaEffect`/`Obstacle` are defined but never instantiated outside tests; "traps" today are `PositionalEffect`s keyed by grid position (`battlearena/ruler/rules/positionaleffect.go`), not `entity.Entity` instances, so they have no `ControllerID` field to begin with. And the one test that exercises the closest real mechanic, `rules_iss066_test.go: TestRuleEntityExpiration`, assigns its `TimeBased` entity a **real, non-nil** `ControllerID` — contradicting the documented design.

So "Nil-controller-as-automated" is aspirational/unenforced intent, not a tested invariant. This means *any* bug, anywhere, that ever leaves an entity's `ControllerID` unset — a missed assignment, a partially-initialized entity, test scaffolding like `NewCompleteRuler` (`ruler.go:111-127`, which never explicitly sets `ControllerID` on its generated entities) — silently and irrecoverably falls into the broken auto-pass path with nothing catching it earlier. This is exactly the kind of silent defaulting this project's own doctrine rejects (`.agent/rules/COMMON.md`: *"Crash Early: Defaulting hides critical errors... Fail Fast: clear panics or rejections are better than undefined behavior"*).

The exact path by which a real `1v1_PVE` match's player entity ended up with a Nil `ControllerID` is still unconfirmed — but per the above, that may be the wrong question. The more defensible fix is to make it *impossible* for any entity to exist without a real controller in the first place, regardless of how it happens.

## Recommended Fix (revised)

**Short term:** Add defensive logging in `ruler_turn.go`'s automated branch (around line 90-100) whenever an entity with a Nil `ControllerID` reaches `handTurn` at all — currently this path is completely silent. That will catch the next live occurrence with full context (entity ID, behaviorSlug, timestamp) instead of requiring log archaeology after the fact.

**Medium term:** Stop using `ent.ControllerID == uuid.Nil` as a routing signal in `handTurn`/`triggerFirstTurn` altogether. Automated-vs-controlled behavior should be driven **exclusively** by the `AIBehavior` property (`behaviorSlug != "none"`). A Nil `ControllerID` reaching turn-handoff should be treated as a bug, not a legitimate case — log/alarm loudly (or panic, per Crash Early) rather than silently resolving via `ExpirationBehavior`.

**Long term:** Eliminate `uuid.Nil` as a legitimate `ControllerID` value entirely. Every entity — including any future trap/bomb/hazard/summon entity — must be assigned an explicit, non-nil `ControllerID` at creation: either inherited from a caster/owner, or a dedicated system/"GameMaster" controller (no such constant currently exists and would need to be introduced). Enforce this at the narrowest choke point, `Ruler.AddEntity` and/or `entity.New()`, per "Reproduce Error as Test First" / Crash Early: reject (panic or error) entity creation/registration that doesn't supply a controller, rather than deferring the failure to a much later, silent turn-skip.

## Fix Implemented (2026-06-22)

Both the Medium- and Long-term recommendations above are now in place:

- **`Ruler.AddEntity`** (`ruler.go:179-199`) now panics immediately if `e.ControllerID == uuid.Nil`, before any state mutation. This is the single sanctioned entry point for putting an entity on the board (confirmed: `bridge_start.go`'s `addExplicitEntity`/`addAutoGenEntity` already only ever go through `ba.Ruler.AddEntity(e)`, never touch `GameState.Entities` directly — production callers are unaffected since they already set a real `ControllerID`).
- **`handTurn`** (`ruler_turn.go:73-127`) no longer treats `ent.ControllerID == uuid.Nil` as a signal for automated behavior. The condition is now `if behaviorSlug != "none"` only; a Nil `ControllerID` reaching `handTurn` at all now panics immediately, as a defense-in-depth backstop independent of `AddEntity`.
- Two existing tests that relied on the old "Nil ControllerID == automated" convention were updated to match the new reality: `TestRulerAggressiveBehavior` (`ruler_behavior_test.go`) now gives its automated monster a real `ControllerID` (automation is driven by `AIBehavior` alone), and `TestInitRace` (`ruler_race_test.go`) now supplies a `ControllerID` for its test entity.
- The two reproduction tests in `ruler_iss101_test.go` were inverted from "prove the bug reproduces" to "prove the bug is now rejected": `TestRulerAddEntityRejectsNilControllerID` and `TestRulerHandTurnRejectsNilControllerID` both assert a panic, recovering it to verify no entity with a Nil `ControllerID` survives either choke point.
- Full `upsilonbattle` and `upsilonapi` module test suites pass after the change (including `go build ./...` for both). Some pre-existing, intermittent data races surface under `-race` on full-suite runs (`TestRulerAggressiveBehavior`, `TestRulerEntityLeak`, `TestShotClockRace`/ISS-047) — confirmed via `git stash` that these predate this fix and are unrelated to it.

**What remains open:** the exact mechanism by which the original production `1v1_PVE` match's player entity acquired a Nil `ControllerID` was never confirmed (no instrumentation or debugger repro was attempted — the structural fix made the question moot for this specific failure mode). If a *new* "AddEntity panicked in production" incident ever fires from this guard, that crash report will finally pin down the real trigger.

**Follow-up noted by reviewer (2026-06-22):** now that Nil-controller entities are forbidden, revisit how time-based effects (`entity.TimeBased`, currently unused in production — see "Deeper Root Cause" above) are intended to be modeled going forward. The reviewer's recollection is that these should be entity-based with their own distinct controller (e.g. a system/GameMaster controller, still TBD — see Long-term fix above) rather than relying on the now-removed Nil-controller-as-automated convention. Needs its own investigation/issue once picked back up.

---

## Extra Data

Full turn-queue trace reconstructed from `edge_movement_path_too_long.log` (artifact of GitHub Actions run `27952883421`, job "Integration & E2E Tests" → "E2E: Run Edge Case Suite"):

```
snapshot 0/1  current=00000000 (pre-game)
   delay=1007 entity=a9e9c3bc (enemy)
   delay=1201 entity=00cc5b49 (enemy)
   delay=1237 entity=019eef5c (player #1)
   delay=1240 entity=019eef5c (player #2)
   delay=1352 entity=7fa232ef (enemy)
   delay=1452 entity=019eef5c (player #3)

snapshot 2-4  current=a9e9c3bc (enemy, correctly popped: lowest delay 1007)
   delay=194  00cc5b49 (enemy) | 230 019eef5c(p) | 233 019eef5c(p) | 345 7fa232ef(enemy) | 445 019eef5c(p)

snapshot 5/6  current=00cc5b49 (enemy, correctly popped: lowest delay 194)
   delay=39   019eef5c (PLAYER) | 151 7fa232ef(enemy) | 226 a9e9c3bc(enemy) | 251 019eef5c(PLAYER)
   -> player entity has the LOWEST delay (39); should be popped next.

snapshot 7    current=7fa232ef (enemy, delay was 151 — NOT the lowest)
   delay=151  7fa232ef(enemy) | 226 a9e9c3bc(enemy) | 251 019eef5c(PLAYER)
   -> the delay=39 player entity is gone. Never appeared as current_entity_id.
      No "My Turn!" was ever logged client-side for any player entity, in
      this snapshot or any other in the match.

... (pattern continues: only enemy entity IDs ever appear as current_entity_id
    for the remainder of the match) ...

Match ends: "DEFEAT... WINNER: TEAM 2", all 3 player entities at hp:0,
2 of 3 enemy entities still alive. Player issued zero game_action calls
the entire match (confirmed via the CLI bot's own request log).
```

Player team composition at match start: Saboteur/Artificer/Sentinel, all hp 30/30, `attack: 10`. Enemy (`Scrap-812`): Echo_502a (hp 50), DeathXCore_Bot (hp 40), NeonZero_Alpha (hp 90).

---

## References

- `upsilonbattle/battlearena/ruler/ruler_turn.go` (handTurn, lines 73-119)
- `upsilonbattle/battlearena/ruler/turner/turner.go` (Turner.NextTurn, AddEntity)
- `upsilonbattle/battlearena/ruler/behavior/behavior.go` (ExpirationBehavior, GetBehavior)
- `upsilonapi/bridge/bridge_start.go` (StartArena, configureArenaEntities, setupControllers)
- `upsilonapi/bridge/bridge_start_archetype.go` (generateEntityFromArchetype)
- `upsiloncli/internal/script/bridge_battle.go` (jsWaitNextTurn — client-side symptom)
- `upsilontypes/entity/entity.go` (entity.New, ControllerID defaults to uuid.Nil)
- `upsilonbattle/battlearena/ruler/ruler.go` (AddEntity — no ControllerID validation; NewCompleteRuler — test scaffolding that doesn't set ControllerID either)
- `upsilonbattle/battlearena/ruler/ruler_iss101_test.go` (reproduction tests — both currently pass, characterizing the present broken behavior)
- `upsilonbattle/battlearena/ruler/rules/rules_iss066_test.go` (TestRuleEntityExpiration — contradicts the documented Nil-controller-for-TimeBased-entities design by assigning a real ControllerID)
- `docs/mech_ruler_behavior.atom.md` (status: DRAFT — documents the unenforced Nil-as-automated convention)
- Affected test scripts: see list in "Downstream symptom in CI" above
- GitHub Actions run: `27952883421` (job "Integration & E2E Tests")
