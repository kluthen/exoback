# TODO — CI-blocking issues ISS-102 / ISS-103 / ISS-130 / ISS-131

**Status:** active — step 9 essentially DONE (Half A mutation-verified; Half B 36/37 + 52/52, all 6 targets green). Characterizing 1 unrelated pre-existing scenario failure, then steps 10-12.
**Owner:** coordination-leader
**Opened:** 2026-08-19

---

## Source

User request (restated in full): "Check out issues 102 103 130 and 131 (these are the
most recent blocking the CI run); spawn agents to investigate, present me solutions,
organize solution implementation."

These four issues are the failures from umbrella CI run `32230359259`, commit `5a3e854`
— the first CI run to reach the E2E suite since the Phase 4/5 auth/economy extraction
was pushed. Issue files live in `issues/`. The umbrella repo has ATD wired up (`.atd`
at root, docs in `docs/`), so documentalist preflight/architecture-capture/post-sync
apply.

### The four, by class (triage completed 2026-08-19)

- **ISS-130 — revoked token not rejected (High, real bug, security boundary).**
  After `auth_logout` revokes a token, reusing it on `GET /api/v1/profile` returns
  404 "-- DEBUG MODE -- You are not enrolled in battle." instead of 401. That message
  means the request reached battle-enrollment logic, i.e. was treated as authenticated.
  Three live hypotheses: (a) the hub's 5s token-introspection cache in the
  `upsilonhub/internal/platform/identity` seam serves a stale-valid entry; (b) gateway
  middleware ordering lets the request reach the battle handler before auth
  short-circuits (suspect after Phase 4/5 + ISS-124 enroll-driven roster, `8b329c6`);
  (c) `auth_logout` never actually reaches `RevokeToken` in upsilonauth.
  Related atom `[[req_security_token_ttl]]`. Related issue ISS-105 (opposite direction).

- **ISS-131 — battle lifecycle SSE dead air (High, real bug, determinism unknown).**
  `e2e_skill_equip_battle` gets `match.found` and a healthy `GET /api/v1/game/{id}`
  (`started_at` set, `game_finished:false`), then receives none of `board.updated` /
  `turn.started` / `game.started` / `game.ended` for 60s. Arena
  `a3995675-1ad3-4d18-af46-9644348a0c7b`; `match.found` + GET at 08:24:51.69Z, timeout
  08:25:51.699Z. Distinct from the ISS-102/119 forfeit race (silence, not a fast 400).
  Candidates: engine never started the loop / engine events never reached the hub /
  hub received but SSE edge never delivered to this subscriber. Sharpest lead is the
  contrast with `match.found`, which DID arrive.

- **ISS-102 — forfeit in the engine startup window (Medium, known race, needs a scope
  decision not research).** Arena is created but not yet "in progress" engine-side, so
  an immediate `POST /game/{id}/forfeit` gets 400 `game.not.in.progress`. The window
  existed under Laravel too, masked by Reverb latency; SSE removed the mask. Options
  already on file: CLI-side bounded retry (test-only) / engine accepts forfeit from
  arena creation onward (behavior change) / define the arena lifecycle contract
  (created → starting → in_progress → concluded) as an atom.

- **ISS-103 — privacy check asserts unimplemented masking (Medium, contract gap, not a
  bug).** The scenario asserts foe entities expose no `equipped_skills`/`equipped_items`
  /`buffs`, but neither the Laravel `BoardStateResource` nor its Go port
  (`upsilonhub/internal/games/battle/masking.go`) ever stripped them — DB evidence from
  both eras confirms. Encodes ISS-077's designed-but-unimplemented privacy contract.
  Decision needed: implement foe-loadout stripping in `MaskBoardState`, or relax the
  assertion to WARN until ISS-077 lands. Atom in the area:
  `[[arch_api_id_masking_gateway]]`.

---

## Plan

- [x] 0. Resume check — no prior `TODO.md`; fresh task. `.atd` present.
- [x] 1. Triage the four issues into classes (done, above).
- [x] 2/3. ATD preflight (documentalist D1) + parallel root-cause investigation of
      ISS-130 and ISS-131. ALL THREE RETURNED. Findings below. Two of the four issue
      files turned out to have INCORRECT PREMISES — see "Investigation results".
- [x] 4. DONE. Findings folded into scope; documentalist D2 returned and materially
      revised the governing-atom sets for ISS-130 and ISS-131 (D1's topical atoms turned
      out NOT to be code-bound). See "D2 blast-radius refinement". All three investigator
      claims independently re-verified at source (see "Source verification").
- [x] 5. DONE. All four user decision points answered (see "User decisions"). Filing
      decision on the 8 pre-existing ATD defects adopted per recommendation: 7 filed
      separately as a dedicated cleanup pass, 1 (the broken
      `mechanic_mec_skill_payload_resolution` id) pulled INTO this task because Workflow E
      item 6 is unreachable without it.
- [x] 6. DONE. documentalist Workflow E returned 2026-08-24: 3 atoms created (DRAFT),
      4 edited, item 0's broken id fixed at all 11 sites, item 8 test-link corrected.
      Independently verified by the lead (see "Workflow E results").
- [x] 7. DONE. All four `coding-executor` handoffs returned and were independently
      lead-verified (see the handoff table + per-handoff verification notes). A=ISS-131
      engine, B=ISS-131 hub, C=ISS-103, D=ISS-130+ISS-102 scenarios.
- [x] 8. DONE. Reviewer verdict **OKAY, no blocking issues** (2026-08-26). ISS-130's
      downgrade independently re-traced and confirmed; panic confirmed unreachable; neither
      forbidden change was made. Its one actionable non-blocking note (CODING_RULE §6 doc
      errors on the new test stub) was fixed by the lead — `code_health_check.py` now reports
      0 errors / 0 warnings on that file. See "Reviewer verdict".
- [x] 8b. DONE 2026-08-26 — executor returned, lead-verified first-hand. **NEW (added 2026-08-26 by user): ISS-132** — auth/economy (and serializer)
      unit tests are never run by CI. Must land BEFORE step 9, because step 9 *is* a
      local-CI run and would otherwise re-run a knowingly-blind pipeline. Triage: Explicit
      class (known files, fix on file), but carries one real unknown — 17 never-executed
      test files may go red on first run. See "ISS-132" section below.
- [~] 9. IN PROGRESS. Half A (serialization unit tests) DONE + mutation-verified. Half B (live-stack E2E) next.
- [ ] 10. documentalist post-task papertrail sync (Workflow B).
- [ ] 11. Final report to user; set Status and Handover.
- [ ] 12. Cleanup pass — only after the user validates completion.

---

## ATD preflight verdicts (documentalist D1, returned 2026-08-20)

| Issue | Verdict | Governing atoms to carry into the handoff |
|---|---|---|
| ISS-130 | **PROCEED** | `uc_auth_logout`, `req_security_token_ttl`, `req_security`, `upsilonauth:requirement_identity_account_lifecycle`, `upsilonauth:mech_token_introspection` |
| ISS-131 | **PROCEED** | `upsilonapi:api_websocket`, `upsilonapi:api_websocket_game_events`, `upsilonapi:api_websocket_arena_updates` |
| ISS-102 | **PROCEED-WITH-SIGNOFF-PENDING** (path-dependent) | `upsilonbattle:rule_forfeit_battle`, `upsilonbattle:mechanic_arena_lifecycle`, `upsilonbattle:contract_battle_contract`, `upsilonapi:api_go_battle_forfeit`, `upsilonapi:api_go_battle_start` |
| ISS-103 | **HALT-NEEDS-USER-INPUT** | `requirement_customer_user_id_privacy`, `upsilonapi:arch_api_id_masking_gateway`, `upsilonapi:api_websocket_arena_updates`, `upsilonapi:rule_gdpr_compliance` |

Key findings beyond the verdicts:

- **ISS-130 is drift against an atom that already exists.** `uc_auth_logout` (STABLE) states
  in its own EXPECTATION: "Requests following logout with the old token return 401
  Unauthorized." The code violates a standing atom — no atom needs changing, the fix
  restores compliance. Also: `upsilonauth:requirement_identity_account_lifecycle` says
  revoked/expired/deleted verdicts are deliberately indistinguishable (`{active:false}`),
  and that consumers must resolve validity via introspection rather than locally.
- **ISS-131 is likewise drift against three STABLE atoms** (`api_websocket*`) that describe
  near-verbatim the `match.found` → `board.updated` → `game.started`/`turn.started`/
  `game.ended` lifecycle that is currently silent. Restoring conformance is in scope with
  no atom edit.
- **ISS-102's fix paths differ sharply in ATD cost.** `upsilonbattle:mechanic_arena_lifecycle`
  exists but covers only TEARDOWN — there is no created→starting→in_progress→concluded
  state machine on record. `upsilonbattle:rule_forfeit_battle` (STABLE) already says a player
  may forfeit "at any time during the match" — ambiguous as to whether the pre-tick setup
  window counts. Meanwhile `contract_battle_contract` (STABLE, CONTRACT) says "fail fast on
  illegal state transitions," which arguably makes today's 400 compliant-by-design. Real
  tension; the human weighs it.
- **ISS-103: no BUSINESS atom mandates foe-loadout privacy.** `requirement_customer_user_id_privacy`
  and `arch_api_id_masking_gateway` are scoped exclusively to IDENTIFIER/ownership masking —
  nothing about equipment/skill/buff content. ISS-077 is an open issue, not an atom.
  BUT: `upsilonapi:api_websocket_arena_updates` (STABLE) contains "Opponent/AI Characters:
  mask sensitive fields (attributes, logic) while leaving public identifiers" — vague enough
  to read as already promising foe-data stripping, and too vague to satisfy atom
  self-sufficiency. Either decision path should also tighten that wording.

Non-blocking gaps flagged by preflight:
- `upsilonhub/docs/` has NO atom for the hub's identity client seam or its 5s introspection
  cache (only 4 atoms exist there). Expect a Workflow E capture once ISS-130's fix shape is
  settled.
- The three `api_websocket*` atoms governing ISS-131 live under `upsilonapi/docs/` despite
  documenting hub-owned infrastructure (`upsilonhub/internal/gateway/sse`). Relocation
  candidate for a later pass.
- Root `.atd` has no semantic index built (`atd index` never run); preflight used grep/query.

---

## Investigation results (returned 2026-08-20) — BOTH OVERTURN THEIR ISSUE FILES

### ISS-130 — NOT a security bypass. Severity drops High → Low. Stale test scenario.

Confidence: HIGH (decisive CI artifact log, nothing inferred).

The scenario never reaches logout. `edge_auth_session_timeout.js:22` dies on its **first**
`profile_get` — made with a *fresh, valid* token right after `auth_register`. Post-Phase-4,
`auth_register` mints account + token ONLY (CI log shows `"registrations": []`, no
`characters`). `GET /api/v1/profile` is battle-scoped and reads the `player_stats` read
model, which only exists after `POST /api/v1/battle/enroll`
(`upsilonhub/internal/gateway/enroll.go:46-79`). No row → `playerstats.ErrNotFound` → a
DELIBERATE 404 at `upsilonhub/internal/gateway/profile.go:48-51`. `upsilon.call` throws on
any `success:false` envelope (`upsiloncli/internal/script/bridge.go:133-154`), so the script
aborts at line 22-23 — the try/catch at lines 46-51 is NEVER ENTERED.

**The scenario is simply stale**: it uses raw `auth_register` and was never updated with the
`battle_enroll` step the Phase-4 cutover introduced. Sibling `e2e_session_timeout` passes
because it uses `upsilon.bootstrapBot`, which DOES call `battle_enroll`
(`upsiloncli/internal/script/bridge_battle.go:307`). Only 10 of 97 scenarios call
`battle_enroll` directly; the rest rely on `bootstrapBot`.

All three filed hypotheses are FALSE:
- **The 5s introspection cache DOES NOT EXIST.** Never implemented — the design decision was
  recorded but not built. `authclient.AuthenticateToken`
  (`upsilonhub/internal/transport/authclient/client.go:56-65`) does a live
  `POST /internal/v1/introspect` on EVERY request. No memoization, no negative caching,
  nothing to evict. (NOTE: this contradicts the stored memory of "upsilonauth introspection
  + 5s cache" — that decision is unimplemented.)
- **Middleware ordering is CORRECT.** `mountProfile` wraps every profile route in
  `RequireAuth` (`profile.go:361-369`); `RequireAuth` `c.Abort()`s with 401 before `c.Next()`
  (`middleware/auth.go:42-48, 98-101`). The handler ran because the token was genuinely valid.
- **Logout path is SOUND** (and untested by this run): `logout` → `RevokeToken`
  (`upsilonauth/internal/gateway/auth.go:151-155`) → `DeleteToken`
  (`upsilonauth/internal/identity/pg.go:253-255`) → later `FindTokenByID` → `pgx.ErrNoRows`
  → `ErrUnauthenticated` → `{active:false}` → 401. Covered by `TestIntrospectRevokedToken`
  (`upsilonauth/internal/gateway/introspect_test.go:83-99`).

Corrections needed to the issue file itself: it cites
`upsilonhub/internal/gateway/token_renewal_test.go` as existing coverage — **that file no
longer exists** (middleware retired in the Phase-4 cutover; renewal now lives in
`upsilonauth/internal/gateway/middleware/auth.go:68-97`). `edge_auth_session_timeout.js:42-43`
cites the same dead file.

**Separate latent hole found, not the cause here — worth its own issue:** "logout during the
renewal window." If introspection performs sliding renewal on the very request that later logs
out, auth's `middleware.AuthToken` returns the OLD token and `RevokeToken` deletes only that
one, leaving the freshly-minted replacement live; `jsCall` syncs renewed tokens into the CLI
session (`bridge.go:168`). Renewal only fires between 10-15 min of token age
(`upsilonauth/internal/identity/identity.go:31-33`), so this sub-second scenario never trips it.

### ISS-131 — root cause found: engine marshal/unmarshal asymmetry + hub silent-swallow.

Confidence: HIGH. Every hop pinned to a log line or source line. NOT caused by Phase 4/5 —
pre-existing latent bug that run merely happened to precede in the CI calendar.

**The defect:** the engine emits a shape its own decoder refuses.
1. `upsilontypes/property/def/skill.go:177-179` — `ZoneProperty.Get()` returns `*ZoneProperty`,
   not a primitive.
2. `upsilonapi/handler/skill_generate.go:94-119` — `serializeProperty` handles only
   `IntCounterProperty`, `int`, `bool`, `string`; anything else falls through returning a
   **zero `api.PropertyDTO`**.
3. `upsilonapi/api/input.go:36-41` — all `PropertyDTO` fields are `omitempty`, so a zero DTO
   marshals to `{}`.
4. `upsilonapi/api/input.go:52-83` — `PropertyDTO.UnmarshalJSON` **REJECTS `{}`**:
   `invalid property format: {}`.
5. `upsilonapi/handler/handler.go:22-27` — bind failure → 400.

CI proof (`ci_logs/engine.log:1189-1190`, 08:24:51, exactly at `match.found`):
`HandleArenaStart bind error: invalid property format: {}` then
`400 | POST "/v1/arena/start"`. Arena `a3995675-…` appears NOWHERE else in engine.log except
the teardown forfeit at 08:25:51 returning **412 arena not found**. It never existed engine-side.
Trigger: the rolled skill `Flux Sear _I` (tags `dot`,`aoe`) carries `"Zone": {}` in targeting.

**The amplifier — why 60s of silence instead of an error (this is the real severity):**
- `upsilonhub/internal/transport/engineclient/client.go:302-313` — a non-2xx carrying a valid
  envelope with a `success` key is DELIBERATELY not an error (needed for the 412
  rule-rejection passthrough). So the engine's 400 returns
  `EngineResult{Success:false}` with `err == nil`.
- `upsilonhub/internal/games/battle/matchmaking.go:357-381` — `CreateMatch` checks ONLY `err`.
  **It never reads `result.Success`.** It is the ONLY engine-result consumer in the hub that
  doesn't: `gateway/matchmaking.go:138`, `gateway/game.go:146,181`, and
  `games/battle/matchmaking_status.go:152` all check it.
- So `CreateMatch` returns a match id with `err == nil`, and `Join` publishes `MatchFound`
  (`matchmaking.go:193`) for a phantom match with no engine backing — no error, no timeout,
  an orphan match row and a queue-blocking active match until teardown.

**`started_at` "looked healthy" but proves nothing** — it's written by the HUB's own
`CreateMatchRecord` (`games/battle/pg.go:331-336`) at `matchmaking.go:353`, BEFORE the engine
call at :357. The issue file misread it. The GET is actually the second smoking gun:
`game_state` came back EMPTY (`{"current_player_is_self":false,"game_finished":false}` — no
grid, no entities, no players, no turn) because `CacheState` was skipped.

**Event-path contrast (the sharpest lead, now resolved):** `match.found` is MANUFACTURED
IN-PROCESS BY THE HUB (`matchmaking.go:193` → `sse.go:169 handleMatchFound`), never touching
the engine. Every lifecycle event requires a live arena webhooking back
(engine → `/api/webhook/upsilon` → `gateway/webhook.go:32` → `games/battle/pg.go:114
IngestEvent` → `pg.go:163 bus.Publish` → `sse.go:124/135 handleBoardUpdated`). Same bus, same
socket, different ORIGIN — which is why transport looked fine while the game was dead.
This empirically RULES OUT hypotheses B and C.

**Deterministic vs flake: data-dependent, ~1-in-8 CI flake; 100% deterministic given an AoE
skill equipped into battle.** 38 arena starts in the run, exactly 1 failed. `"Zone": {}`
appears in exactly 2 of ~95 scenario logs — `e2e_skill_equip_battle` (FAIL) and
`e2e_skill_roll_naming` (PASS, because it rolls but never enters battle). Perfect correlation.
Other PvE scenarios got lifecycle events fine (`e2e_archetype_pve_full_fight` 23 hits,
`e2e_combat_turn_management` 13). Trigger rate ≈ 12-13% per roll at Grade I
(`skillgenerator.go:30-35,43`: aoe primary 1/11 ≈ 9%, plus Grade-I secondary ≈ 4%),
**higher at Grade II-V** where secondaryPct rises to 85%. Local
`upsiloncli/tests/logs/e2e_skill_equip_battle.log` is STALE (2026-07-24, passed — it just
rolled a non-AoE skill).

**Two more latent `{}` producers on the same gap** (unconfirmed in practice, latent on
inspection): `EffectProperty.Get()` (`upsilontypes/property/def/item.go:101-103`) and
`DefaultFloatProperty.Get()` returning float64
(`upsilontypes/property/defaultproperty/defaultproperty.go:256-258`) — note `PropertyDTO.FValue`
exists but `serializeProperty` never sets it.

**Recommended by the investigator: Options 1 + 2, with 3 as a compatibility shim.**
1. **Hub — honour the envelope in `CreateMatch`** (`matchmaking.go:361`): after the `err`
   check, fail on `!result.Success`. Smallest blast radius; DO THIS REGARDLESS. Restores
   consistency with every sibling consumer. NOTE CODING_RULE §4 tension: the transport's
   non-2xx passthrough is deliberate for 412, so the fix belongs in the CALLER, not the
   transport.
2. **Engine — make `serializeProperty` total** (`skill_generate.go:94-119`): add a
   `*def.ZoneProperty` branch (serialize `PatternType`, which commit `cd75926` added expressly
   for this) and a `float64` branch feeding `FValue`; then panic on unrecognised property type
   (Crash Early — would have caught this at generation time, not 40 min downstream). Blast
   radius: changes the wire shape of generated skills; already-persisted `instance_data` rows
   with `"Zone": {}` stay poisoned → needs a migration or a tolerant decoder alongside.
3. **Engine — accept `{}` in `PropertyDTO.UnmarshalJSON`** (`input.go:52-83`): cheapest
   unblock, restores marshal/unmarshal symmetry, fixes poisoned rows with no migration. But
   papers over the real bug — the Zone pattern is still silently lost, so an AoE skill enters
   battle with NO AREA EFFECT. **Only acceptable combined with Option 2.**

**Diagnostic gap worth fixing:** the CI hub container logs no HTTP access lines (only
River/gin-debug), so the hub's view of the failed StartArena is invisible. Option 1's ERROR
on non-Success would have made this a 30-second diagnosis instead of archaeology.

---

## Source verification (coordination-leader, direct read, 2026-08-20)

Every load-bearing investigator claim was re-checked against the actual code before
scoping. All three hold:

1. **ISS-131 hub side CONFIRMED.** `CreateMatch`
   (`upsilonhub/internal/games/battle/matchmaking.go:351-382`) checks only `err` after
   `m.Engine.StartArena`, then unmarshals `result.Data` for `initial_state`. `result.Success`
   is never read. When the engine 400s, `payload.InitialState` is nil, `CacheState` is
   silently skipped, and a match id is returned with `err == nil` — exactly the phantom
   match described. The function carries `@spec-link [[upsilonapi:api_go_battle_start]]`.
2. **ISS-131 engine side CONFIRMED, and the asymmetry is tighter than filed.**
   `serializeProperty` (`upsilonapi/handler/skill_generate.go:94-119`) handles
   `IntCounterProperty`, `int`, `bool`, `string` — and has NO else branch, so an
   unrecognized type returns the zero DTO silently. Ironically its own doc comment claims
   it "maintain[s] type safety per CODING_RULE.md §4". `PropertyDTO` (`upsilonapi/api/input.go:36-41`)
   is all-`omitempty` → `{}`. `UnmarshalJSON`'s structural branch requires at least one
   non-nil field, so `{}` fails it; all four primitive fallbacks also fail on `{}`; it
   returns `invalid property format: {}`. Note `FValue *float64` EXISTS in the DTO and is
   handled on the decode path, but `serializeProperty` never sets it — confirming the
   latent float64 hole. `PropertyDTO` carries `@spec-link [[mechanic_mec_skill_payload_resolution]]`.
3. **ISS-103 fix site CONFIRMED and smaller than expected.** `masking.go` is 152 LOC with a
   single funnel: `MaskBoardState:18` → `maskPlayers:50` → `maskEntities:76`. `maskEntities`
   already receives `isSelf` and already builds a per-entity copy, so foe-loadout stripping
   is a three-key delete inside the existing `!isSelf` path — no new plumbing, no signature
   change, no second masking point. `MaskBoardState` carries
   `@spec-link [[upsilonapi:arch_api_id_masking_gateway]]`.

### Two open questions CLOSED by direct inspection

**Q: "poisoned instance_data rows — do they exist anywhere we care about?" → YES, THEY ARE
DURABLE. This forces the fix shape.**
`character_skills.instance_data json NOT NULL` (`upsilonhub/db/migrations/000001_initial_schema.up.sql:70`)
is a HUB-side persisted column, not ephemeral engine state. The poisoning loop is closed:
`gateway/skill_roll.go:43` calls `GenerateSkill` → the engine's `serializeProperty` emits
`"targeting":{"Zone":{}}` → `characters.AcquireSkill(ctx, char.ID, result.Data)`
(`skill_roll.go:59`) stores the engine payload VERBATIM → `skillInstance.Targeting` is a
`json.RawMessage` passthrough (`platform/character/pg.go:77-87`) → `BattleLoadouts`
(`pg.go:~97`) replays it at battle start → engine `UnmarshalJSON` rejects `{}` → 400.
CONSEQUENCE: **Option 2 alone cannot fix already-rolled skills.** Every character in a
persistent environment that rolled an AoE skill holds a permanently battle-poisoned row.
Either a data migration or Option 3's tolerant decoder is MANDATORY alongside Option 2 —
this is no longer optional. `BattleLoadouts` carries `@spec-link [[upsilonapi:mechanic_skill_payload_resolution]]`
and `[[upsilonapi:entity_character_equipment]]`.

**Q: "is the silent-swallow a bug CLASS?" → NO — exactly ONE unguarded site. Scope shrinks.**
The hub has 6 engine call sites. 4 correctly check `result.Success`: `ArenaExists`
(`matchmaking_status.go:85`→check :112), `ResurrectArena` (:143→check :152), `SendAction`
(`gateway/game.go:132`→check :146), `Forfeit` (:176→check :181). The 5th, `GenerateSkill`
(`gateway/skill_roll.go:43`), does NOT check `.Success` but is NOT exposed: it goes through a
SEPARATE client (`transport/engineclient/client_skills.go`) that converts non-2xx into a real
`ErrGeneratorUnavailable` error (:55-57) rather than the generic client's envelope passthrough,
and it additionally guards `len(result.Data)==0`. So the generic swallow
(`client.go:302-313`) covers 5 methods and **`StartArena` at `matchmaking.go:357` is its only
unguarded consumer.** Revises the previous Handover's "bug CLASS, not one bug" — the shape
invites recurrence, but there is exactly one live instance. Option 1 is therefore a genuinely
small, low-risk fix, not the tip of an audit.

## D2 blast-radius refinement (documentalist, returned 2026-08-20)

Verdict: **PROCEED for all four** (D1 verdicts stand on the merits) — but with REFINED
governing-atom sets. The headline: for ISS-130 and ISS-131, **none of D1's topical atoms are
actually `@spec-link`-bound to the confirmed files.** D1's semantic search found the right
DOMAIN; D2 found the code actually in scope. Use the D2 sets in the handoffs, not the D1 sets.

**Actually-bound atoms per site:**
- **ISS-131 hub** - `api_go_battle_start` (on `CreateMatch`), `api_standard_envelope` (on
  `engineclient.send()`), `api_battle_proxy` + `api_go_battle_action` (on `gateway/game.go`
  action), `upsilonbattle:rule_forfeit_battle` (on `gateway/game.go` forfeit),
  `upsilonbattleui:ui_dashboard_match_statistics` (on `activeStats`).
  `matchmaking_status.go:resurrect` is **UNGOVERNED** (nearest tag sits on its caller).
  The three `api_websocket*` atoms from D1 are NOT bound here - they name
  `upsilonhub/internal/gateway/sse`, a different code path.
- **ISS-131 engine** - `api_skill_generation` (on `HandleSkillGenerate`);
  `mechanic_skill_payload_resolution` reached via a BROKEN id (below); `mech_actor_pattern`
  (type-level on `ZoneProperty`). `item.go` (`EffectProperty.Get`) and `defaultproperty.go`
  (`DefaultFloatProperty.Get`) are **UNGOVERNED - zero tags in either file.**
- **ISS-103** - `upsilonapi:arch_api_id_masking_gateway`, on `MaskBoardState` ONLY;
  `maskEntities` (the actual fix site) is untagged.
- **ISS-130** - `req_security_token_ttl` (test-link only, on the scenario file),
  `upsilonapi:api_profile_character` (on `getProfile`), `upsilonauth:contract_auth_service`
  (on `enroll`). None of `uc_auth_logout` / `req_security` /
  `requirement_identity_account_lifecycle` / `mech_token_introspection` bind these files.

**Why ISS-103 existed at all - now explained.** `arch_api_id_masking_gateway` (the only atom
on `masking.go`) covers IDENTIFIER masking exclusively - is_self flags, ws_channel_key
pseudonyms, winner_team_id, ownership checks. It says NOTHING about loadout/skill/item/buff
visibility. The atom that DOES verbally promise foe-field masking,
`api_websocket_arena_updates`, **is not `@spec-link`'d to `masking.go` anywhere.** The promise
and the enforcement point were never connected. That is the root cause of the contract gap,
not an oversight in the port.

**D2 corroborates the ISS-131 root cause independently.** Reading the code cold, documentalist
independently identified `CreateMatch` as the only one of six consumer sites omitting the
`.Success` check, and reached the same phantom-match/dead-air conclusion - flagged as
"candidate, unconfirmed". It is now CONFIRMED: the CI engine.log 400 + the empty `game_state`
+ the six-site enumeration close it. **Documentalist's escalation on this point is resolved.**

**Answer to (d) - the Option 2 wire-shape question, DECIDED by coordination-leader:**
- The `float64` branch is a **pure implementation fix**: it populates `FValue *float64`, which
  the DTO and the atom's own documented fallback chain ALREADY declare. No atom change.
- The `Zone` branch is **NOT** pure: `ZoneProperty.Get()` returns the property object itself,
  so serializing `PatternType` is genuinely new wire content the atom's LOGIC never discusses
  in either direction. -> **EDIT `mechanic_skill_payload_resolution`'s LOGIC/EXPECTATION**,
  folded into Workflow E scope at step 6.
- Note the atom's documented scope is the UNMARSHAL direction only; `serializeProperty` (the
  marshal side) is claimed by a doc comment but never actually covered. The edit should close
  that asymmetry too.

**Accepted D2 recommendation:** ISS-103 gets a companion NEW ARCHITECTURE atom for the masking
mechanism, `@spec-link`'d on `maskEntities` specifically - rather than overloading
`arch_api_id_masking_gateway` on `MaskBoardState`. Reusing the existing tag would conflate
ID-masking and loadout-privacy as one rule on one function, against Minimum Atomic Scale.

**Hard constraint for step 6:** the new arena-lifecycle ARCHITECTURE atom must NOT be parented
to `contract_battle_contract` - CONTRACT atoms are read for governance, never used as parents
or as link targets.

### Workflow E scope for step 6 (7 items, none applied yet)
1. NEW ARCHITECTURE - arena lifecycle state machine created->starting->in_progress->concluded
   + allowed-action set per state. Parent via the `mechanic_arena_lifecycle` chain to a
   BUSINESS ancestor; NOT `contract_battle_contract`.
2. EDIT (STABLE) - `upsilonbattle:rule_forfeit_battle` wording. Signed off by user decision 1.
3. NEW BUSINESS - `requirement_foe_loadout_privacy`, parent
   `requirement_customer_user_id_privacy`. Signed off by user decision 2.
4. NEW ARCHITECTURE - foe-loadout masking mechanism, child of (3), `@spec-link` on
   `maskEntities`.
5. EDIT (STABLE) - `upsilonapi:api_websocket_arena_updates` clause wording. Signed off by
   user decision 3. Plus a NEW `@spec-link` onto `masking.go` once the code lands - the edit
   alone does not close the loop.
6. EDIT - `mechanic_skill_payload_resolution` LOGIC/EXPECTATION for the Zone wire shape
   (per the (d) decision above).
7. EDIT (post-fix, non-blocking) - `api_go_battle_start` EXPECTATION to cover the
   engine-rule-rejection-with-valid-envelope case, once the `CreateMatch` fix lands.

### Pre-existing ATD defects found by D2 - OUT of this task's scope, need a filing decision
None of these were introduced by the planned fixes; all predate this task.
- **Broken atom id `mechanic_mec_skill_payload_resolution`** (extra `mec_` infix) at **11
  sites** - 6 `@spec-link` + 5 `@test-link`, across `upsilonapi` AND `upsilonbattle`. `atd
  trace` returns not-found. `atd check` reports "OK" via substring-tolerant matching - a FALSE
  POSITIVE that has been masking this. The real atom is `mechanic_skill_payload_resolution`.
  Interacts with Workflow E item 6: the id must be fixed for that edit to be reachable.
- **`contract_auth_service` used as an `@spec-link` target** at `enroll.go:45` and
  `authenticator.go:66` - hard-boundary violation (CONTRACT atoms are never link targets).
- **`mech_actor_pattern` mis-tag** on `ZoneProperty` (unprefixed; the prefixed
  `upsilontools:mech_actor_pattern` is a concurrency-actor atom, unrelated to AoE targeting).
- **`atd lint` failures** - `req_security` and `requirement_customer_user_id_privacy` both
  missing a mandatory `## EXPECTATION`. Note item 3 above parents a NEW atom to the latter.
- **`contract_auth_service` content drift** - its EXPECTATION describes a caller-side
  introspection cache bounded to seconds; `authclient/client.go` has NO cache at all. DRAFT
  atom, low stakes. (Also independently confirms the "5s cache" is unimplemented.)
- **`atd index` has never been run** in this workspace; `atd map`'s LLM fallback returns pure
  noise (Go symbol names as atom ids). All D2 findings were grep/read-verified instead.
- **`api_websocket*` atoms misplaced** under `upsilonapi/docs/` while documenting hub-owned
  SSE - urgency UNCHANGED/HIGHER: they are `@spec-link`'d to no real code at all today.
- **`edge_auth_session_timeout.js` test-link probably wrong** - points at
  `req_security_token_ttl` (TTL aging) but asserts verbatim `uc_auth_logout`'s EXPECTATION #1.
  Cheap to fix inside the ISS-130 handoff.

## Decisions (current)

- Investigation and implementation are kept separate: the two investigators are
  strictly read-only and report root cause + options; implementation goes to
  `coding-executor` only once each issue is bounded.
- ISS-102 and ISS-103 are deliberately NOT being investigated by agents — they are
  already fully analyzed on file and what's missing is a user decision on the contract,
  not more evidence.
- Phase discipline: stop and report at each step boundary; no rolling into the next
  phase without an explicit go-ahead.

## User decisions (answered 2026-08-20)

- **ISS-102 → "Define the arena lifecycle contract."** created → starting → in_progress →
  concluded, with an allowed-action set per state, as a NEW ARCHITECTURE atom via
  documentalist Workflow E (parented via the existing `rule_forfeit_battle` /
  `mechanic_arena_lifecycle` chain to a BUSINESS ancestor, likely `shared:us_take_combat_turn`).
  Largest scope of the three options, and the one that fixes ISS-102/119/131's shared
  structural root rather than one symptom at a time. Note this ALSO implies the STABLE
  `rule_forfeit_battle` wording ("at any time during the match") gets clarified — signoff
  granted by this choice.
- **ISS-103 → "Implement foe-loadout masking now."** Strip `equipped_skills` /
  `equipped_items` / `buffs` for foe entities in `MaskBoardState`
  (`upsilonhub/internal/games/battle/masking.go` — single masking point; SSE edge and game
  endpoint both route through it). Deliberate NEW BUSINESS scope: documentalist drafts
  `requirement_foe_loadout_privacy` parented to `requirement_customer_user_id_privacy`.
- **ISS-131 → Options 1 + 2, and explicitly NOT Option 3.** The user confirmed the game is
  not live and the database may be flushed as necessary. That removes the only argument for
  Option 3 (the tolerant `{}` decoder existed purely as a compatibility shim for durable
  poisoned `character_skills.instance_data` rows). With a flush available, Option 3 becomes
  actively HARMFUL and is rejected: accepting `{}` would let an AoE skill enter battle with
  its Zone pattern silently dropped and NO AREA EFFECT — a silent wrong-behavior bug replacing
  a loud one, violating CODING_RULE §3 (crash early, no silent failures) and §4 (strict
  contract adherence, no defaulting to "save the day"). No migration code is needed either;
  the fix ships with a documented "flush `character_skills`" (or full DB) step. Final shape:
    1. HUB — `CreateMatch` (`games/battle/matchmaking.go:361`) fails on `!result.Success`
       after the `err` check. Restores parity with the 4 sibling consumers. Fix belongs in the
       CALLER, not the transport, because the transport's non-2xx envelope passthrough is
       deliberate for the 412 rule-rejection path.
    2. ENGINE — `serializeProperty` (`upsilonapi/handler/skill_generate.go:94-119`) made
       TOTAL: add a `*def.ZoneProperty` branch serializing `PatternType` (the field commit
       `cd75926` added expressly for this), add a `float64` branch feeding the already-existing
       but never-written `FValue`, then PANIC on any unrecognized property type. The panic is
       the point — it converts a 40-minute downstream archaeology into a failure at generation
       time. Note `EffectProperty.Get()` returns a struct and is the third `{}` producer;
       the panic will surface it immediately, so it needs a branch too or an explicit decision.
  Deployment note: the DB flush must happen on the same deploy as the engine change, since
  pre-fix rows remain undecodable by design once Option 3 is off the table.
- **Atom wording → "Yes, tighten."** documentalist rewrites
  `upsilonapi:api_websocket_arena_updates`'s "mask sensitive fields (attributes, logic)"
  clause to name the actual in/out-of-scope fields, consistent with the ISS-103 decision.

## Open questions (current)

- (ISS-131 option choice CLOSED 2026-08-20 — see User decisions.)
- Whether the two newly-surfaced findings get filed as their own issues: (a) "logout during
  the renewal window" revocation hole; (b) the ~87 scenarios never calling `battle_enroll`
  directly — a systematic Phase-4 staleness class.
- Whether to correct ISS-130's and ISS-131's issue files (both have materially wrong
  premises on record) before or alongside the fixes.
- Whether any fix must land in a submodule (upsilonauth / upsilonapi / upsiloncli)
  rather than the hub — affects commit/push choreography across submodule pointers.
- (ATD-defect filing question CLOSED 2026-08-24 — recommendation adopted: the broken
  `mechanic_mec_skill_payload_resolution` id is fixed inside this task as Workflow E item 0;
  the other 7 defects are deferred to a dedicated cleanup issue, to be filed at step 11.)

---

## Workflow E results (documentalist, returned 2026-08-24; lead-verified)

**Created (all DRAFT — promotion left to a human/coding-leader):**
| Atom id | File | Type/Layer | Parent |
|---|---|---|---|
| `upsilonbattle:specification_arena_lifecycle` | `upsilonbattle/docs/` | SPECIFICATION / ARCHITECTURE | `[[shared:us_take_combat_turn]]` |
| `requirement_foe_loadout_privacy` (root/shared) | `docs/` | REQUIREMENT / BUSINESS | `[[requirement_customer_user_id_privacy]]` |
| `upsilonhub:module_foe_loadout_masking` | `upsilonhub/docs/` | MODULE / ARCHITECTURE | `[[shared:requirement_foe_loadout_privacy]]` |

The hard constraint held: `specification_arena_lifecycle` is parented to
`us_take_combat_turn` (verified sibling of `rule_forfeit_battle`), NOT to
`contract_battle_contract`. Its four-state machine was grounded in real engine source
(the `ArenaState` enum + the `game.not.in.progress` guard) rather than invented from the
issue text. All three report NO_IMPL, which is correct — the code does not exist yet.

**Edited (prior wording preserved inline as "superseded" notes, so the change is auditable):**
- `upsilonbattle:rule_forfeit_battle` (STABLE) — forfeit legality now tied to the
  `in_progress` state. **Consequence for ISS-102: the pre-tick 400 is now documented as
  COMPLIANT behavior, not a bug.** That is the atom's answer to the ambiguity, and it
  shapes the ISS-102 handoff.
- `upsilonapi:api_websocket_arena_updates` (ARCHITECTURE) — vague "mask sensitive fields"
  clause replaced with named fields (strip `equipped_skills`/`equipped_items`/`buffs`;
  keep `is_self`/position/type/`dead`). Still NO_IMPL — correctly flagging the very gap
  that produced ISS-103.
- `upsilonapi:mechanic_skill_payload_resolution` — new LOGIC point 4 + EXPECTATION covering
  the SERIALIZE direction (previously unmapped): primitives map directly, float64 -> FValue,
  Zone-typed properties emit `PatternType`, unmapped types must NOT silently serialize to `{}`.
- `upsilonapi:api_go_battle_start` — applied, not deferred. New EXPECTATION: callers must
  treat `Success:false` as failure regardless of HTTP status, and must never infer success
  from the absence of a transport error. This is the atom that makes the `CreateMatch` fix
  contractual rather than discretionary.

**Item 0 — broken id fixed at all 11 sites** (`mechanic_mec_skill_payload_resolution` ->
`mechanic_skill_payload_resolution`), comment-only: `upsilonapi/api/input.go:35`,
`api/output.go:23`, `api/output_test.go:4`, `api/property_test.go:4`,
`handler/skill_generate.go:69`, `bridge/bridge_utils.go:3,21`, `bridge/mapping_test.go:4`,
`bridge/equipment_test.go:4`, `bridge/test_helpers_test.go:4`,
`upsilonbattle/battlearena/ruler/rules/skill.go:17`. `atd trace` now resolves: 8 code / 6
test links, ancestry complete.

**Item 8 — test-link corrected.** `upsiloncli/tests/scenarios/edge_auth_session_timeout.js:2`
now `@test-link [[uc_auth_logout]]` (was `req_security_token_ttl`). Reasoning accepted: the
scenario asserts `status === 401`, which is `uc_auth_logout`'s EXPECTATION #1 verbatim, and
exercises none of the TTL atom's 10/15-min boundary or 20s grace logic.

### Tags that MUST be added to code at step 7 (acceptance criterion 7)
| # | Atom | File | Function |
|---|---|---|---|
| 1 | `[[mechanic_skill_payload_resolution]]` | `upsilonapi/handler/skill_generate.go` | `serializeProperty` (the type-switch itself — `serializePropertyMap` carries only a prose mention) |
| 2 | `[[module_foe_loadout_masking]]` | `upsilonhub/internal/games/battle/masking.go` | `maskEntities` |
| 3 | `[[upsilonapi:api_websocket_arena_updates]]` | `upsilonhub/internal/games/battle/masking.go` | `MaskBoardState` (NEW tag alongside the existing `arch_api_id_masking_gateway`) |

### Lead verification of the Workflow E result
- `grep` for the broken id across the tree: zero remaining hits in source (only an unrelated
  memory note). Count independently confirmed rather than trusting `atd check`'s
  substring-tolerant match, which had been false-positiving on this for months.
- All three new atom files exist at the reported paths.
- `git diff` filtered to non-comment lines across `upsilonapi`/`upsilonbattle`/`upsiloncli`:
  **empty** — the source changes are genuinely comment-only, no logic touched.
- Change set spans umbrella + 4 submodules (`upsilonapi`, `upsilonbattle`, `upsilonhub`,
  `upsiloncli`) — this ANSWERS the open question about submodule choreography: yes, submodule
  pointers will move. Nothing committed or pushed.
- `atd lint` failures reported afterward are all pre-existing (the deferred seven plus a
  wider `orphaned_stable_atoms` backlog); none newly introduced, none on the touched atoms.
- Transparency note self-flagged by documentalist: `--force` was passed on the
  `api_websocket_arena_updates` edit but was INERT (the STABLE guard fires only on
  layer==BUSINESS; that atom is ARCHITECTURE). Verified against `atd` source. No bypass occurred.

## Reviewer verdict (step 8, returned 2026-08-26): **OKAY — no blocking issues**

The reviewer did NOT take the executors' reasoning on faith; it re-walked each load-bearing
claim itself. What it independently confirmed:

**Priority 1 — the ISS-130 downgrade is CORRECT. No auth bypass exists.**
- No introspection cache anywhere in `platform/identity/` or `internal/transport/`;
  `authclient.AuthenticateToken` introspects live per request and deliberately does not even
  retry. The "5s cache" ISS-130 names as prime suspect was never built.
- `RequireAuth` (`middleware/auth.go:35-54`) aborts 401 BEFORE `c.Next()`, and `/api/v1/profile`
  is registered inside that group (`profile.go:361-362`) along with game/matchmaking/shop/
  skills/SSE. No unauthenticated route reaches the 404.
- Revocation chain sound end to end: `logout` -> `RevokeToken` -> `DeleteToken` ->
  `pgx.ErrNoRows` -> `ErrUnauthenticated` -> `active:false` -> 401, already pinned by a
  PASSING `TestIntrospectRevokedToken` (`introspect_test.go:86-99`).
- Sharp observation the lead had not made: the first and third `profile_get` emit the
  IDENTICAL 404 message, so the message alone cannot distinguish them — but only one is
  reachable. That is why the issue was misfiled in the first place.

**Priority 2 — the panic is safe.** Totality re-verified (7 `Get()` impls; a workspace-wide
grep outside `upsilontypes/property/` finds only the test's own stub). `EffectProperty` is
constructed at exactly one non-definition site, `bridge/bridge_start.go:207`, on the
equipment-buff path at battle start — `skillgenerator.Generate` never produces one, so
`sk.Effect.Properties` cannot contain one. The branch is a tripwire for a future wire-format
change, not a live path. `gin.Default()` Recovery confirmed.

**Neither forbidden change was made.** `api/input.go`'s diff is the single tag correction;
`PropertyDTO.UnmarshalJSON` still rejects `{}`. `upsilonhub/internal/transport/` is clean, so
`engineclient`'s 412 passthrough is intact.

**Priority 3 — acceptable to advance.** Both specific questions confirmed: goja's reflect
wrapper throws a `GoError` on `jsWaitForEvent`'s non-nil trailing error, so a never-started
arena aborts the scenario instead of falling through to the forfeit; AND events arriving before
the waiter registers are BUFFERED (`internal/ws/listener.go:528-534`), so the wait cannot be
missed by a race. `battle_enroll` is a bare POST with no body and does not touch session/token
state, so the logout assertion is unaffected.

**Collateral check the brief did not ask for:** every CLI consumer of `buffs`/`equipped_skills`/
`equipped_items` reads the viewer's OWN entity; the only foe-side reader is
`e2e_battle_starts_privacy_check.js:42-44`, which asserts the NEW behaviour. No regression from
the masking change.

### Reviewer's non-blocking notes, and their disposition
1. **CODING_RULE §6 doc errors** — 9 "missing documentation" errors on the `unmappedProperty`
   stub methods in `skill_generate_test.go`. **FIXED by the lead 2026-08-26**: all 9 methods
   documented, `gofmt` reapplied, handler tests re-run green, and
   `python3 scripts/code_health_check.py upsilonapi/handler/skill_generate_test.go` now reports
   **0 errors / 0 warnings**. (Note the check is commented out in `scripts/pre-commit.sh:28` and
   absent from CI, so this would not have failed the build — it was a genuine standard
   violation that no tooling would have caught.)
2. **ISS-130's file still reads Severity: High / Status: Open** and still names the nonexistent
   cache as suspect. Expected — the edit is gated on this review. Now unblocked; do it at
   step 11.
3. **DO NOT cite `upsiloncli/tests/logs/edge_auth_session_timeout.log` as evidence in the issue
   closure.** It is a stale 2026-07-07 PASSED log, not from run `32230359259`; the local
   artifact does not corroborate the symptom. The code-path proof stands on its own.
4. **The four scenario edits remain unexecuted.** Nothing wrong on inspection, but whether
   15000ms is the right window against real engine start latency is only provable by a run.
   Carried into step 9.

## Committed 2026-08-26 (NOT pushed — user asked for commit only)

Five commits, submodules first then the umbrella pointer commit. All four submodules were on
`main` (checked for detached HEAD before touching anything). ATD structural integrity check
ran green on 3 of the 5 commits via the pre-commit hook.

| Repo | Commit | Subject |
|---|---|---|
| `upsilonapi` | `250de60` | `fix(iss-131): make serializeProperty total` |
| `upsilonbattle` | `4830137` | `docs(iss-102): define the arena lifecycle state machine` |
| `upsilonhub` | `0aac6f4` | `fix(iss-131,iss-103): honour the engine envelope; mask foe loadouts` |
| `upsiloncli` | `c5dc3c6` | `test(iss-130,iss-102): repair two scenarios stale since the cutover` |
| umbrella | `3db0e9d` | `fix(iss-102,103,130,131): resolve the four CI-blocking issues` |

`origin/main..main` = 1 unpushed umbrella commit. **Nothing pushed.** Each submodule also has
1 unpushed commit; the umbrella pointer commit references them, so pushing the umbrella WITHOUT
first pushing all four submodules would leave the pointers dangling for anyone else. Push
submodules first, then umbrella.

**Deliberately left OUT of the commit:** `TODO.md`. It is session-continuity scratch for this
task and is due for deletion in the step-12 cleanup, so committing it would leave orphaned
bookkeeping in history. It remains the only dirty file in the tree.

**Folded IN:** the `README.md` / `issues/README.md` / ISS-102 / ISS-103 change-log edits and the
ISS-130 + ISS-131 issue files, all of which pre-dated this session's work but are the filings
for these same four issues.

Both the umbrella commit message and this file record what is NOT yet done, so the history is
honest about it: the five scenarios are unrun, the ISS-130/ISS-131 issue files still carry
their original incorrect premises, and the deploy needs a `character_skills` flush.

## STEP 9 SCOPE (lead-grounded 2026-08-26, all facts verified at source)

Step 9 splits cleanly in two. Half A is delegable and deterministic; Half B is a live-stack
run that is BLOCKED on a commit decision (see "Blocker" below).

### Half A — serialization unit tests (user-directed; delegate to coding-executor)

**The implementation set is CLOSED at exactly 7**, verified two independent ways: the
`Get()` implementations and the `GetType()` implementations match 1:1, and the only two
struct-embedding sites of `property.Property` (`def/item.go:69`, `def/skill.go:135`) are
EffectProperty and ZoneProperty themselves. So "all serialization cases" is a finite,
enumerable claim — which is exactly what makes the user's direction work.

| # | Type | Path | serializeProperty branch | Covered today? |
|---|---|---|---|---|
| 1 | `DefaultIntProperty` | `upsilontypes/property/defaultproperty` | `case int` → `Value` | **NO** |
| 2 | `DefaultIntCounterProperty` | idem | `IntCounterProperty` → `Value`+`Max` | **NO** |
| 3 | `DefaultFloatProperty` | idem | `case float64` → `FValue` | yes (`_FloatValue`) |
| 4 | `DefaultBoolProperty` | idem | `case bool` → `BValue` | **NO** |
| 5 | `DefaultStringProperty` | idem | `case string` → `SValue` | **NO** |
| 6 | `*def.ZoneProperty` | `upsilontypes/property/def/skill.go` | PatternType → `SValue` | yes (`_ZoneRoundTrip`) |
| 7 | `*def.EffectProperty` | `upsilontypes/property/def/item.go` | panics BY DESIGN | yes (`_PanicsOnEffectProperty`) |

`serializeProperty`'s own doc comment makes an explicit **totality claim** ("total across
every property.Property implementation reachable from upsilontypes/property"). That claim is
what the panic exists to enforce and it is currently untested as a set — 4 of 7 types have no
test at all.

**The assertion that matters is ROUND-TRIP, not just serialization.** ISS-131's actual failure
mode is `PropertyDTO.UnmarshalJSON` (`upsilonapi/api/input.go:52`) rejecting an all-nil DTO with
`invalid property format: {}`. Only `_ZoneRoundTrip` does serialize → Marshal → Unmarshal today.
Every non-panicking type needs that full loop, or the test set does not actually cover ISS-131.

**Also fix while in this file:** the `@test-link [[mechanic_skill_payload_resolution]]` on
line 3 sits in the PACKAGE HEADER. ATD.md ("NO Global Headers", Surgical Attachment Rules) and
the standing placement rule both require links atop the specific function. This defect was
introduced in step 7 and the step-8 reviewer missed it. Move it atop each test function.

### Half B — live-stack E2E (lead-driven)

Tooling already exists; nothing new to build. `scripts/run_ci_local.sh` `stage_integration`
boots `docker-compose.ci.yaml` and runs both suites:
- `tests/run_all_scenarios.sh` globs `e2e_*.js` → covers 5 of the 6 targets
  (`e2e_match_resolution_forfeit`, `e2e_match_resolution_standard_with_2`,
  `e2e_progression_constraints_with_2`, `e2e_progression_post_win_with_2`,
  `e2e_skill_equip_battle`), 180s timeout each, agent count from the `_with_N` suffix.
- `tests/run_all_edge_cases.sh` → covers the 6th, `edge_auth_session_timeout`.

Docker 29.7.2 + compose v5.4.0 confirmed present. Compose builds every service from local
context (`context: .`), so the committed fixes land in the images.

**The `character_skills` flush prerequisite does NOT apply to this run** — `stage_integration`
ends in `compose down -v`, so the CI DB is ephemeral and starts clean every time. The flush
remains a hard prerequisite for the real deploy; that is a step-11 note, not a step-9 blocker.

### BLOCKER — Half B cannot run until the ISS-132 change set is committed

`run_ci_local.sh` does NOT test the working tree. It clones into `../upsilon-hub-ci` and
`--local` sources submodules from local git HISTORY (its own help text says so: "git clone only
reads from history, not the worktree"). Consequences:
- The ISS-102/103/130/131 fixes ARE committed, so `--local` picks them up. Fine.
- The ISS-132 change set is UNCOMMITTED, so the clone will not have `scripts/list_go_modules.sh`
  — and `stage_build` runs `go vet $(scripts/list_go_modules.sh)` under `cd "$TARGET_DIR"`.
  That is a hard failure on the first command of stage 1.
- Half A's new unit tests would likewise be invisible to the run unless committed.

So the ordering is forced: **Half A → commit (ISS-132 set + new tests) → Half B.** Per
CODING_RULE.md §7 the lead does not commit unasked; this needs the user's explicit go-ahead.

**USER DECISION 2026-08-26: "yes, commit and push all once the executor returns and then run the
second half."** So the blocker is CLEARED. Sequence is now: executor returns → commit → push via
`scripts/push_all.sh` (submodules first, umbrella last) → run Half B.
Note this ordering is also LUCKY w.r.t. ISS-134: `go work sync` during the CI run dirties
`upsilonauth`/`upsiloneconomy`/`upsilonhub` go.mod/go.sum, which would make `push_all.sh` REFUSE.
Pushing BEFORE the CI run sidesteps that entirely. Do not reorder these two.

---

### Half A RESULT (executor returned 2026-08-26; LEAD-VERIFIED FIRST-HAND, not taken on trust)

Single file changed: `upsilonapi/handler/skill_generate_test.go` (+137/-35, now 212 LOC).
The two old tests `_FloatValue`/`_ZoneRoundTrip` were folded into one table-driven
`TestSerializeProperty_RoundTrip` covering all 6 non-panicking types; the 2 panic tests kept.

Lead-verified independently (all re-run by the lead, not quoted from the executor):
- `go test ./upsilonapi/... -count=1` → 45 passed across 5 packages.
- `code_health_check.py` on the file → 0 errors / 0 warnings. 212 LOC (limit 400).
- `git -C upsilonapi diff --stat` → ONLY the test file. Nothing staged, nothing committed by the executor.
- `@test-link [[mechanic_skill_payload_resolution]]` now atop each of the 3 test functions
  (lines 50/162/172) and ABSENT from the package header. ATD placement defect from step 7 fixed.

**MUTATION TESTING (the decisive evidence — a passing test proves nothing on its own):**
The lead temporarily mutated `serializeProperty` twice, confirmed the suite catches each, and
restored the source (verified clean + green afterward):
1. Zone branch made to return a zero-value DTO — the EXACT ISS-131 pre-fix behavior →
   `TestSerializeProperty_RoundTrip/ZoneProperty` FAILED at test line 122 (the non-`{}` assertion).
2. IntCounter branch made to drop `Max` → `.../DefaultIntCounterProperty` FAILED at test line 71.
Each mutation was caught by exactly the right subtest and nothing else.
**Conclusion: this suite would have caught ISS-131 at its root.** The ~1-in-8 flaky e2e is no
longer the only thing standing between a serialization regression and production.

---

### Half B ATTEMPT 1 (2026-08-26) — INVALID RUN, root-caused. Found a NEW bug: ISS-135 candidate.

Ran `run_ci_local.sh --fresh --stages build,unit,integration --skip-playwright` from a fresh
clone of the just-pushed remote (deliberately NOT `--local`, so the pushed gitlinks were proven
to resolve — they did).

- **STAGE 1 build + STAGE 2 unit: PASSED.** This is real, load-bearing evidence: it is the first
  time the ISS-132 fix ran in an actual CI clone rather than the worktree. All 12 go.work modules
  vetted and tested there. ISS-132 is confirmed fixed end-to-end.
- **STAGE 3 integration: 2/37 scenarios, 8/51 edge cases passed.** All six of this round's target
  scenarios among the failures.

**This run is INVALID — do not read anything into those scenario results.** Root cause found and
proven, and it is NOT a regression from this round's fixes:

`run_ci_local.sh:295` ran `docker compose up -d --wait` **without `--build`**. Compose only builds
images that do not already exist. Unlike an ephemeral GitHub runner (ci.yml:205 prunes all images
and starts cold), this mirror keeps images between runs. So:
- `upsilon-hub-ci-auth`/`-economy` had no cached image → built fresh 2026-08-26 14:39.
- `upsilon-hub-ci-hub`, `-engine`, `-tester` DID have images → silently reused from **2026-07-20**.

The July-20 hub predates the Phase 4 auth cutover. Proof from `ci_logs/hub.log`: the running hub
registered `/api/v1/auth/login`, `/api/v1/auth/register` etc. served by an in-hub `gateway.authAPI`
— routes the current source explicitly no longer mounts (router.go comment: "moved to upsilonauth
in the Phase 4 cutover ... the hub mounts none of it"). That stale hub also lacks `mountInternal`,
so all **489** hub errors were the single route `POST /internal/v1/players/<uuid>/account`
returning 404 to upsilonauth's AccountPush client (`upsilonauth/internal/accountpush/hubclient.go:38`).
No account push → registration/login broken → the entire suite cascades.

Ruled out along the way (each checked, not assumed): route missing from source (it exists,
`internal_consumer.go:38`); registrar never called (it is, `router.go:109`); mount condition
unmet (`S2S_TOKEN=ci-internal-token` IS set in compose, and `PlayerStats` is unconditionally
non-nil at `main.go:181`); wrong submodule commits in the clone (verified 9801c13 / hub 0aac6f4 /
api 9e5eb50).

**Severity: this is ISS-132's twin and arguably worse.** ISS-132 was "tests never run"; this is
"tests run against five-week-old artefacts and return a red/green signal that means nothing".
Every prior local-mirror E2E result is retrospectively suspect. GitHub CI is NOT affected.

**Fixes applied to `scripts/run_ci_local.sh` (uncommitted, pending user review):**
1. `up -d --build --wait` + a comment explaining why `--build` is mandatory, not an optimisation.
2. Log collection loop extended with `auth-migrate auth-seed auth economy-migrate economy-seed
   economy` — it still listed only the pre-extraction services, so an auth/economy failure left
   no evidence behind. ci.yml already collects these (lines 258-261); the mirror had drifted.

**Half B ATTEMPT 2 (after the `--build` fix) — THE ROUND IS VALIDATED.**

- **Scenarios: 36 passed / 1 failed** (was 2/37 on the stale images).
- **Edge cases: 52 passed / 0 failed** (was 8/51).
- **ALL SIX target scenarios PASSED**, i.e. the entire step-9 evidence gap is now closed with
  runtime evidence rather than static reasoning:
  `e2e_match_resolution_forfeit`, `e2e_match_resolution_standard_with_2`,
  `e2e_progression_constraints_with_2`, `e2e_progression_post_win_with_2`,
  `e2e_skill_equip_battle` (the ISS-131 scenario), `edge_auth_session_timeout`.
- Hub logged exactly **1** ERROR across the whole suite, and it is a deliberate edge-case probe
  (`/api/v1/profile/character/not-a-uuid` -> invalid UUID), i.e. a test passing correctly.
  Compare: 489 errors, all one route, on the stale-image run.
- The log-collection fix proved itself immediately: `auth.log` (341K) and `economy.log` were
  captured this time; on attempt 1 they did not exist.

**Caveat on `e2e_skill_equip_battle`:** it passed, but it remains a ~1-in-8 AoE-dependent flake,
so this single green is NOT by itself proof that ISS-131 is fixed. The real proof is the Half A
mutation testing. This is exactly the division of labour the user directed, and it worked.

### The one remaining failure: `e2e_friendly_fire_skill_test` — NOT a regression from this round

Assertion: "Fireball friendly-fire was never rejected within 3 matches" (scenario line 154).

Evidence it is unrelated to this round's changes:
1. **The scenario file was not touched by this round.** Last modified in `006a27f`; this round's
   upsiloncli commit is `c5dc3c6`.
2. **The bot never reached the Pyromancer check at all** — 0 occurrences of "Pyromancer
   attempting". It never got a turn: 30 of 33 match attempts failed with
   `Conflict: You are currently participating in an active match`, alongside 32x "not my turn
   yet" and 32x "Cleaning up session before retry". This is a session-cleanup / turn-starvation
   loop, not a serialization or masking failure.
3. **The ISS-103 over-masking hypothesis is DEAD.** It was the one plausible way this round could
   have caused this symptom (strip `equipped_skills` from self/allies -> bot never identifies as
   Pyromancer). Measured: `"equipped_skills"` appears 170x in the scenario log and is empty in
   only 9. Self/ally loadouts are intact; masking is behaving.
4. No existing issue covers this scenario.

**CHARACTERIZED (3 isolated runs against a freshly built stack): it is an INTERMITTENT FLAKE.**

| Run | Exit | `Conflict: already in an active match` | Cast attempts reached |
|-----|------|-----|-----|
| 1 | 0 (PASS) | 0 | 1 |
| 2 | 1 (FAIL) | 24 | 0 |
| 3 | 0 (PASS) | 0 | 1 |

The correlation is exact: when the bot leaves its match cleanly it reaches the Fireball cast and
passes; when it does not, it burns all 3 match attempts on `Conflict` and never reaches the check.
So the assertion text ("friendly-fire was never rejected") is misleading — friendly-fire rejection
is not what is broken. The defect is session/match cleanup between attempts, and roughly 1 run in
3 trips it even in isolation.

**Disposition: pre-existing, unrelated to this round, worth its own issue.** Proposed as ISS-136 at
step 11 (not filed yet — the user asked only for the CI issue to be filed). Suggested severity
Medium: it is a test-integrity defect that will keep producing false CI failures, and the
misleading assertion message will send the next investigator after the wrong subsystem.

---

## Handover  (REWRITTEN 2026-08-26, post-ISS-132, pre-compaction — replaces all prior handovers)

**Where things stand:** steps 0-8 and 8b are COMPLETE. Step 9 (verification) is NEXT and is the
only remaining substantive work; 10-12 follow it. This handover is written to survive a context
compaction — everything step 9 needs is below, assume nothing is in memory.

### Git state (READ THIS FIRST)
- Umbrella HEAD = `3db0e9d`, **1 unpushed commit**. Four submodules (`upsilonapi` `250de60`,
  `upsilonbattle` `4830137`, `upsilonhub` `0aac6f4`, `upsiloncli` `c5dc3c6`) each have 1 unpushed
  commit. **NOTHING HAS BEEN PUSHED.** Push submodules FIRST, then the umbrella, or the gitlink
  pointers dangle — `scripts/push_all.sh` does exactly this ordering.
- The ISS-102/103/130/131 fixes are IN those commits. Do not re-do them.
- **Uncommitted in the working tree right now** (the ISS-132 change set + bookkeeping):
  `.github/workflows/ci.yml`, `scripts/run_ci_local.sh`, `scripts/run_all_unit_tests.sh`,
  new tracked `scripts/list_go_modules.sh`, newly-tracked `scripts/push_all.sh`,
  `README.md`, `issues/README.md`, `TODO.md`, and untracked `issues/ISS-132`, `ISS-133`, `ISS-134`.
  All 13 submodules are CLEAN. Nothing from ISS-132 has been committed — user has not asked.

### STEP 9 — the plan, and the one real evidence gap

**Gap:** five `upsiloncli` scenario files were modified but **NEVER EXECUTED** (no stack was
available; the executor said so plainly rather than claiming a pass). Every other piece of the
committed change set has runtime evidence. Step 9 must run these against a live stack:
`edge_auth_session_timeout`, `e2e_match_resolution_forfeit`,
`e2e_match_resolution_standard_with_2`, `e2e_progression_constraints_with_2`,
`e2e_progression_post_win_with_2`. **Do not accept static reasoning as closure on these.**

**Also re-run `e2e_skill_equip_battle`** (the scenario that surfaced ISS-131). It is a
**~1-in-8 data-dependent flake** — it only fails when the skill roll produces an AoE skill
(~12-13% at Grade I, much higher at Grade II-V). A single green run proves nothing.

**USER'S DIRECTION ON THIS (2026-08-26), adopt it:** don't lean on the flaky e2e for proof.
Add a round of **unit tests covering ALL serialization cases**, and use the e2e only to validate
the scope at large. The lead confirmed the gap is real: `upsilonapi/handler/skill_generate_test.go`
today has exactly 4 tests — `TestSerializeProperty_ZoneRoundTrip`, `_FloatValue`,
`_PanicsOnUnrecognizedType`, `_PanicsOnEffectProperty`. Nothing enumerates every property type the
engine can emit and asserts each serializes. That totality claim is what the panic exists to
enforce and it is currently untested as a set. Unit tests make it deterministic; the e2e then only
has to prove the wiring. The user will review the e2e scenario themselves.

**Deployment prerequisite (hard, not a suggestion):** the `character_skills` flush (or full DB
flush) must happen on the same deploy as the engine change. Pre-fix rows carrying
`"targeting":{"Zone":{}}` are undecodable BY DESIGN now that the tolerant-decoder option was
rejected. The user confirmed the game is not live and the DB may be flushed.

**Before running local CI:** ISS-132 is fixed, so `go vet`/`go test` now cover all 12 `go.work`
modules. Lead-measured green: 654 pass / 0 fail, ~31s, via the split invocation (default `-p`
for 10 modules, `-p 1` for auth+economy). Do NOT run the full docker-compose E2E casually — it is
expensive; it is step 9's actual job.

### Steps 10-12
- **10** = documentalist Workflow B post-task papertrail sync. Must also confirm the 3 DRAFT atoms
  created at step 6 now have real `@spec-link` bindings and can advance toward REVIEW.
  **Scope note: this applies ONLY to the ISS-102/103/130/131 business-layer work.** ISS-132/133/134
  are CI/tooling and are OUT of ATD scope entirely per the user's 2026-08-26 ruling.
- **11** = final report + issue-file updates. Still owed: correct the ISS-130 and ISS-131 issue
  files (both carry materially WRONG premises on record); update ISS-102's for the
  compliant-by-contract reframing; mark ISS-132 resolved; file the deferred ATD-cleanup issue for
  the 7 pre-existing defects listed under "Pre-existing ATD defects found by D2"; decide whether to
  file the two newly-surfaced findings — (a) the "logout during the renewal window" revocation
  hole, (b) ~87 scenarios never calling `battle_enroll` directly, a systematic Phase-4 staleness
  class that ISS-130 is merely the first instance of.
- **12** = cleanup (delete `TODO.md` + orchestration scratch) — **ONLY after the user explicitly
  validates completion.** Never on the lead's own say-so.

### Live risks / assumptions
- The five scenarios are unrun. That is the single largest unknown in the whole round.
- ISS-133 (`upsilonserializer` in-tree, single consumer) — user said KEEP, solve later.
- ISS-134 (`go work sync` rewrites 3 submodules' `go.mod`/`go.sum`) — filed, Medium, NOT fixed.
  Note it interacts with step 9: running local CI executes `go work sync` and WILL dirty
  `upsilonauth`/`upsiloneconomy`/`upsilonhub`, which then makes `push_all.sh` refuse to push them.
  Revert with `git -C <mod> checkout -- go.mod go.sum` after a CI run.
- ATD tooling runs degraded (`atd index` never built for root or any submodule). User: "a me
  issue", do not work it.
