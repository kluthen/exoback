# Issue: Battle lifecycle SSE events never arrive after PvE match.found (60s dead air)

**ID:** `20260819_battle_sse_events_never_arrive`
**Ref:** `ISS-131`
**Date:** 2026-08-19
**Severity:** High
**Status:** Resolved
**Component:** `upsilonhub/internal/gateway` (SSE edge) / `upsilonhub/internal/games/battle`
**Affects:** `upsiloncli/tests/scenarios/e2e_skill_equip_battle.js`, any client waiting on post-match-found battle events

---

## Summary

`e2e_skill_equip_battle` joins a `1v1_PVE` match, receives `match.found` and
a healthy `GET /api/v1/game/{id}` response (`started_at` populated,
`game_finished: false`), then waits for any of `board.updated`,
`turn.started`, `game.started`, or `game.ended` over SSE. None arrive within
the 60s wait window and the scenario times out. This is a total SSE dead-air
failure, not the known instant-forfeit race window (ISS-102/ISS-119) — here
the client waits the full timeout with zero lifecycle events, suggesting the
engine never actually started the game loop for this arena, or the event
never reached the SSE edge. First observed in CI on 2026-08-19 (umbrella run
32230359259, commit `5a3e854`), the first CI execution to reach the E2E
suite since the Phase 4/5 auth/economy extraction was pushed.

---

## Technical Description

### Background

After `match.found`, the hub creates the arena on the engine and the engine
is expected to emit `game.started` (and subsequent turn/board events) which
the hub relays over its SSE edge. `WaitForAnyData(..., ["board.updated",
"turn.started", "game.started", "game.ended"], ...)` is the CLI's existing
wait primitive for this.

### The Problem Scenario

```
CLI                          hub                          engine
───                          ───                          ──────
matchmaking/join ───────────► ...
◄── WS MatchFound event ──────
GET /game/{id} ─────────────► 200 OK, started_at set, game_finished:false
                              (arena presumably created on engine)
wait for [board.updated | turn.started | game.started | game.ended]
  ... 60s pass, no event delivered ...
[INTERNAL_ERROR] Turn wait timed out or failed
```

Timestamps from CI (`upsiloncli/tests/logs/e2e_skill_equip_battle.log`):
`match.found` and the healthy `GET /api/v1/game/{id}` response both land at
`2026-08-19T08:24:51.69Z`; the timeout fires exactly 60s later at
`08:25:51.699Z` having received none of the four events.

### Where This Pattern Exists Today

- `upsiloncli/tests/scenarios/e2e_skill_equip_battle.js` — equips a skill,
  joins PvE, then waits for a turn.
- `upsiloncli/internal/script/bridge_battle.go:424` — `WaitForAnyData` (the
  same primitive ISS-119 recommends other scenarios adopt).
- `upsilonhub/internal/games/battle/matchmaking.go` — arena creation /
  `MatchFound` publish path.

---

## Risk Assessment

| Factor | Value |
|---|---|
| Likelihood | Unknown yet — one CI observation; needs a repro run to establish determinism vs. flake |
| Impact if triggered | High — a joined match silently never starts from the client's point of view; no error surfaces to the player, just a hang |
| Detectability | Medium — requires a full 60s wait to notice; no immediate error from the hub |
| Current mitigant | None known |

---

## Recommended Fix

**Short term:** Re-run this scenario in isolation against CI's docker
compose stack to establish whether it's deterministic or a one-off (check
engine/hub logs from this run — `ci_logs/engine.log`, `ci_logs/hub.log` —
for whether the engine ever received/started this specific arena
`a3995675-1ad3-4d18-af46-9644348a0c7b`).

**Medium term:** If the engine never started the arena, trace why (compare
against the ISS-102/ISS-119 known async-start window — this may be the same
root cause manifesting as total silence instead of a fast 400, if the
engine-start call itself failed rather than merely being slow). If the
engine did start but the event never reached the SSE edge, trace the
hub's event bus → SSE relay path for dropped events.

**Long term:** Same long-term direction as ISS-119: the hub should not
report a match as actionable/joined until the engine has confirmed start,
and that confirmation (or a bounded failure) should be observable by the
client instead of a bare timeout.

---

## Extra Data

- CI run: umbrella `32230359259`, commit `5a3e854e7743e68a59ed1102720865bc52c39747`,
  rerun after fixing an unrelated transient submodule-checkout race.
- This is the first CI run to reach the E2E suite since the Phase 4/5
  auth/economy extraction was pushed — the extraction's cutover runbook was
  never CI-verified before this.
- Filed alongside ISS-130 (auth) from the same CI run; ISS-102 and ISS-103
  already track the other two failures from this run (forfeit race,
  privacy-masking gap) and were not re-filed.

---

## References

- `upsiloncli/tests/scenarios/e2e_skill_equip_battle.js`
- `upsiloncli/tests/logs/e2e_skill_equip_battle.log` (2026-08-19 CI run)
- `upsiloncli/internal/script/bridge_battle.go`
- Related: ISS-102 (forfeit rejected in engine startup window), ISS-119
  (match-resolution scenarios race engine game-start)

---

## Correction (2026-08-26)

**Status changed Open -> Resolved.** The original title/framing blamed SSE event delivery, but SSE
was never at fault. The record is corrected here to the actual root cause: an engine
marshal/unmarshal asymmetry compounded by a hub silent-swallow, pre-existing and unrelated to
Phase 4/5.

**Actual root cause chain:**
1. `upsilontypes/property/def/skill.go:177-179` — `ZoneProperty.Get()` returns `*ZoneProperty`, not
   a primitive.
2. `upsilonapi/handler/skill_generate.go` — `serializeProperty` handled only
   `IntCounterProperty`/`int`/`bool`/`string`; anything else fell through returning a **zero
   `api.PropertyDTO`**.
3. `upsilonapi/api/input.go:36-41` — all `PropertyDTO` fields are `omitempty`, so a zero DTO
   marshals to `{}`.
4. `upsilonapi/api/input.go:52-83` — `PropertyDTO.UnmarshalJSON` **rejects `{}`** with
   `invalid property format: {}`.
5. `upsilonapi/handler/handler.go:22-27` — the bind failure produces a 400, which the hub silently
   swallowed, so the symptom surfaced far downstream as "no SSE events" rather than at its true
   origin.

**Fix as shipped (Options 1+2; Option 3 explicitly rejected):**
- **Hub** — `CreateMatch` (`upsilonhub/internal/games/battle/matchmaking.go`) now fails on
  `!result.Success` after the `err` check, restoring parity with its four sibling consumers. The
  fix belongs in the caller, not the transport, because the transport's non-2xx envelope
  passthrough is deliberate for the 412 rule-rejection path.
- **Engine** — `serializeProperty` made **total**: a `*def.ZoneProperty` branch serializing
  `PatternType`, a `float64` branch feeding the previously-never-written `FValue`, an explicit
  panic on `*def.EffectProperty` (no honest scalar wire mapping), and a panic on any unrecognized
  type. The panic is the point: it converts downstream archaeology into a failure at generation
  time, per CODING_RULE §3.
- **Option 3 (tolerantly accepting `{}`) was rejected as actively harmful**: it would let an AoE
  skill enter battle with its Zone pattern silently dropped and no area effect — trading a loud
  failure for a silent wrong-behavior bug, violating CODING_RULE §3 and §4. It was only ever
  justified as a compatibility shim for durable poisoned `character_skills.instance_data` rows;
  with the game not live and the DB flushable, that justification is gone.
- **Deployment note that must survive on record:** the `character_skills` (or full DB) flush must
  land on the same deploy as the engine change — pre-fix rows are undecodable by design once
  Option 3 is off the table.

**Regression coverage:** `upsilonapi/handler/skill_generate_test.go` now round-trips all 6
non-panicking `property.Property` implementations through marshal->unmarshal and asserts the
marshaled form is never `"{}"`, plus two panic tests. The implementation set was established closed
at exactly 7 types, and the tests were mutation-verified.
