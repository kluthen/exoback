# TODO — ISS-124 empty roster + umbrella docs refresh

**Status:** `active` — W1 (ISS-124) implemented, reviewed OKAY, ATD-synced, **committed 2026-08-04
(not pushed)**. W2 (docs) not yet delegated — that is the next session's work.
**Owner:** coordination-leader
**Opened:** 2026-08-04

---

## Source

No spec document was handed over. Full restatement of the request:

Bastien reports an issue of **paramount importance**: on creating a new account, the web UI
displayed no roster at all. He does not know the root cause and does not know the current state
of the application; he explicitly delegated organising the investigation. The **expected**
behaviour he stated is: *upon account creation (and enabling of the battle game), 3 characters
should have been rolled, each with a skill pending rolling.* The filed issue is
`issues/ISS-124_20260801_new_account_dashboard_empty_roster.md`.

As a **second, separate task**, he wants `README.md` / `CLAUDE.md` at the umbrella root brought
up to date with the current architecture — in particular (a) **how services should be created
from now on** (expecting older services such as `upsilonapi` not to have been migrated yet, but
that they should be in future) and (b) **how users are bound to specific services**. He also
does not know whether `upsiloncli` is still current with the architecture. In a follow-up he
pointed out that `architecture/how_to_add_a_service.md` and `architecture/service_map.md`
already exist and are probably not well indexed from README/CLAUDE, and asked me to look at them.

### Supplemental research gathered

**Architecture docs (read, confirmed current and high quality).** `architecture/` holds 8 docs:
`INDEX.md`, `architecture_anchor.md`, `how_to_add_a_service.md`, `observability.md`,
`platform_architecture.md`, `platform_constraints.md`, `prod_cutover_runbook.md`,
`service_map.md`. `how_to_add_a_service.md` is a complete, battle-tested 10-step service
creation standard born from the upsilonauth/upsiloneconomy extractions (kit composition, one DB
per service, UUID-only cross-service refs, port registry, S2S via `httpx` + `X-Internal-Token`,
born-instrumented OTel, CI wiring, plus Appendix A on extracting a domain out of the hub).
`service_map.md` is the service→project ownership map incl. the one-CONTRACT+one-VISION-per-project
governance rule. **Indexing status is the actual gap:** `README.md` cites `service_map.md` and
`platform_architecture.md` exactly once (line 3) and `CLAUDE.md` cites `service_map.md` once
(line 40) — `how_to_add_a_service.md` is cited by **neither**, and `architecture/INDEX.md` is
cited by neither. So the substance exists; discoverability is what is missing.

**Stale project map in CLAUDE.md.** CLAUDE.md §1's umbrella folder list omits `upsilonauth/`,
`upsiloneconomy/` and `upsilonplatform/`, all three of which now exist as top-level submodules,
and still describes the hub as owning auth/economy in-process.

**ATD D1 preflight (documentalist, read-only, 2026-08-04).** Verdicts: **W1 =
HALT-NEEDS-USER-INPUT**, **W2 = PROCEED**.

Governing atoms split into two contradictory groups. *Group A (old bundled model, all STABLE):*
`shared:uc_player_registration` (ARCHITECTURE, STABLE — its LOGIC step 3 says registration itself
generates 3 characters; it is the atom `@spec-link`'d on `character/pg.go:38`),
`upsilonbattleui:ui_registration` (STABLE), `upsilonbattleui:ui_registration_character_generation_flow`
(STABLE, `@spec-link`'d on `Register.vue`), `shared:us_character_reroll` (BUSINESS, STABLE),
`upsilonbattle:mech_character_reroll` (IMPLEMENTATION, STABLE). *Group B (current split
register/enroll model, both DRAFT, both match running code):* `upsilonauth:mech_service_registrations`
("Auth is game-independent: Register creates the account and its token only… Auth never initiates
enrollment itself") and `upsiloncli:mechanic_bot_enrollment` (documents
`auth_register → battle_enroll → profile_characters` as the mandatory bot sequence).

Key findings: (1) `mechanic_bot_enrollment` **already answers ISS-124's own open question** — the
CLI *does* call enroll explicitly, confirming the gap is SPA-only, and upsiloncli is current on
this point. (2) The **"skill pending rolling"** half of the expectation has **zero coverage** —
no atom mentions it and `GenerateInitialRoster` (`character/pg.go:39-65`) allocates only V2
baseline stats (HP/MP/SP/Movement/Attack/Defense/Crit), no skill field, no pending state. This is
a new/undecided requirement, not a regression. (3) **Who triggers enroll** is settled by no atom
— it is an undecided architecture choice, not merely undocumented. (4) `pg.go:38`'s `@spec-link`
cites an atom describing a flow the code no longer implements — pre-existing drift. (5) `upsilonhub/docs/`
contains only `contract_game_composition` + `vision_platform_v3` — zero BUSINESS/ARCHITECTURE/
IMPLEMENTATION atoms for identity/enrollment/character/roster despite `enroll.go` and
`character/pg.go` living there. (6) The "one account, per-game opt-in enrollment" rule exists only
at IMPLEMENTATION layer (DRAFT) — no BUSINESS atom promotes it; this is the single artifact that
would serve W1 and W2 simultaneously. (7) Unrelated but adjacent: `us_new_player_onboard` (BUSINESS,
REVIEW) says registration collects only username+password while `uc_player_registration` (STABLE)
still mandates Full Address + Birth Date — pre-existing contradiction, tracked as sibling issue ISS-125.

W2 CONTRACT/VISION check: `upsilonhub:contract_game_composition` and `vision_platform_v3` read in
full, neither touched by a README/CLAUDE index change. Service-creation side governed by
`upsilonplatform:contract_platform_kit` + `vision_platform_kit` (both DRAFT), consistent with
indexing `how_to_add_a_service.md`.

---

## Plan

1. ~~ATD preflight (D1) for ISS-124 + docs refresh~~ — **completed**
2. ~~Establish ground truth on ISS-124 root cause~~ — **completed** (see GT1–GT8)
3. ~~Audit doc drift: README.md / CLAUDE.md vs current architecture~~ — **completed** (GT7; findings
   ready, rewrite itself not yet delegated)
4. ~~Settle single path and delegate execution~~ — **completed** (W1 shipped to working tree)
5. ~~Verify results, ATD post-task sync, close out~~ — **completed** (review OKAY, Workflow B done,
   ISS-126 filed, committed across the 4 submodules + umbrella; residual decisions below)
6. ~~Design game-selection page surface~~ — **completed** via documentalist Workflow E
7. ~~Capture upsilonplatform conundrum in spec/precursor.md~~ — **completed**
8. **W2 rewrite of README.md / CLAUDE.md — NOT STARTED.** Fully unblocked; drift list is in GT7.

---

## Ground truth (verified against running code, 2026-08-04)

Two `codebase-explorer` passes plus one direct check. **This materially corrected two earlier
assumptions — read before planning.**

**GT1 — the enroll gap is real and is SPA-only.** Confirmed independently: zero enroll calls
anywhere in `upsilonbattleui/src`, under any spelling, at any point in the app lifecycle.
`Register.vue:29` → `services/auth.js:83-90` (`POST /auth/register`, straight to upsilonauth) →
`Register.vue:30` `router.push('/dashboard')` → `Dashboard.vue:65` → `useDashboardState.js:33-50`
which fetches only `/profile/characters` and inventory. No router guard, no app-shell bootstrap,
no login path enrolls. **The CLI, by contrast, is correct**: `battle_enroll` is a registered
command used in ~15 sample and scenario files (`upsiloncli/samples/*.js`,
`upsiloncli/tests/scenarios/*.js`), each tagged `@test-link [[mechanic_bot_enrollment]]`. (An
explorer pass wrongly reported this command missing; a direct grep disproved it — documentalist's
earlier reading was right.) **Consequence for verification: the entire CLI scenario suite enrolls
explicitly, which is exactly why CI is green and this bug survived. The existing suites cannot
catch it. The regression guard must go in the Playwright suite, not the goja scenarios.**

**GT2 — the pending skill roll is NOT a regression. It already works.** This overturns D1.
`characters.roulette_used` defaults to `false` (migration `000001_initial_schema.up.sql:101`), and
`GenerateInitialRoster` never sets it — so **every freshly generated character already carries
exactly one pending skill roll**. The roll endpoint is live and wired:
`POST /profile/character/:characterId/skills/roll` (`upsilonhub/internal/gateway/skills.go:95-136`,
routed at `:270`), grade-gated (I-II always; III at 10+ wins, IV at 20+, V at 30+), calls
`engine.GenerateSkill` → `AcquireSkill`, then flips `roulette_used = true` — one roll, once. The
SPA already has the UI: a "SCAVENGE SKILL" button opening an inline roulette, covered by
`upsilonbattleui/tests/playwright/user_flows.spec.ts:160-202`, which asserts the button disappears
after a successful roll. **So "3 characters each with a skill pending rolling" is already the
correct behaviour of the code — the characters simply never exist, because enroll never runs.**
Fixing GT1 fixes the whole of the reported symptom. No skill work is needed.

**GT3 — what IS stale on the skill side is the atom, not the code.**
`mech_skill_selection_progression` specifies `POST /api/v1/character/{id}/skill-select` and "choose
1 of 3 random skills"; the shipped system is `/profile/character/:id/skills/roll` and a single
roll. That single-roll reduction is Bastien's own deliberate, already-shipped simplification
("there should have been 3 roulette… we've reduced it to one"). Atom-side fix only.

**GT4 — the 100 CP pool (Q7) is not a defect, but the atom overstates the schema.** There is **no
CP pool column** — the `characters` table has only `spent_cp` (default 0), and
`GenerateInitialRoster` sets `SpentCP: 0` (`pg.go:57`). The 100 CP is implicit (pool = 100 −
spent_cp). `rule_character_create_character` (STABLE) describes a pool that does not exist as a
field. Nuance to note when revising it; no code change.

**GT5 — half the games-catalog surface already exists (Q9).** The *held* half is live: the
auth login/register response carries `registrations: []string` (e.g. `["tactical"]`) —
`upsilonauth/internal/gateway/resources.go:30`, populated at `auth.go:55-58` via
`ListRegistrations` (`internal/identity/registrations.go:42-52`). The *available* half does **not**
exist: no `/games`, `/services` or `/catalog` endpoint anywhere in the hub router, and enrollment
is hardcoded to `POST /api/v1/battle/enroll` → the `tactical` service. **So the selection page
needs one new read endpoint — this is the Workflow E trigger, confirmed.**

**GT6 — the not-enrolled signal already exists, but is applied inconsistently.**
`GET /api/v1/profile` already returns **404 "You are not enrolled in battle."**
(`gateway/profile.go:44-58`, contract locked by `profile_test.go:187-195`). But
`GET /api/v1/profile/characters` (`profile.go:70-75`) has **no enrollment check at all** and
returns `200 []`. That inconsistency is precisely what turns "not enrolled" into a silent empty
dashboard instead of an actionable error. **The server-side gate does not need inventing — it
needs making consistent.** (Adjacent: ISS-122 already tracks a profile enrollment guard.)

**GT7 — W2 drift is confirmed and larger than expected.** `upsilonauth` (:8091, routed by Caddy at
`/api/v1/auth/*`) and `upsiloneconomy` (:8092, internal-only via `ECONOMY_INTERNAL_URL`) are
**extracted, live and wired in both CI and prod compose**; the hub retains only thin seams
(`internal/platform/identity`, `internal/platform/economy` now hold interfaces + DTOs only, per
their own package comments). CLAUDE.md still calls them in-process hub responsibilities and
"extraction candidates", omits all three new submodules from its folder list, and still lists the
retired `/reporting`. README is in better shape — its intro, service overview, CI and issues
sections are accurate — but it misdescribes enrollment as auth-owned (lines 35-36) and its port
table (92-95) omits 8091/8092. `upsiloncli` is **current** (no Laravel/Reverb remnants; auth
commands correctly routed to the extracted service).

**GT8 — CORRECTED 2026-08-04. The original finding was wrong; do not act on the earlier version.**

*What was first reported (by a `codebase-explorer` pass, and repeated by me to Bastien):* that
upsilonauth, upsiloneconomy and upsilonapi all fail to use the `upsilonplatform` kit, making
`how_to_add_a_service.md` self-contradictory for citing auth/economy as reference implementations.
**That inference was drawn from `go.mod` alone and is false.**

*Verified by direct grep:* `upsilonauth` imports the kit in **20 Go files**
(`respond`, `middleware`, `clock`, `observability`, `httpx`, `jobs` — incl. `internal/gateway/router.go:16-19`),
`upsiloneconomy` in **14** (incl. `cmd/upsiloneconomy/main.go:24-26`, `internal/api/middleware.go:17-18`).
Both follow the kit's prescribed middleware chain. **`upsilonapi` imports it in 0 files** — it is
the only genuinely un-migrated service, exactly as Bastien predicted.

*The real, narrower defect:* **no `go.mod` in the entire umbrella declares
`github.com/ecumeurs/upsilonplatform`.** The dependency is satisfied only by the umbrella
`go.work` (and each Dockerfile's scoped `go work init`), so `GOWORK=off go build ./...` fails for
both services — upsilonauth with 11 missing `go.sum` entries, upsiloneconomy with "updates to
go.mod needed". That is a build-reproducibility/standalone-build problem, **not** a
kit-adoption problem.

*Consequence:* `how_to_add_a_service.md` is **substantially correct as written** — its reference
implementations really do exemplify kit composition. The contradiction I reported to Bastien does
not exist in the form I described it. What remains true is (a) upsilonapi is not on the kit, and
(b) the go.mod declaration gap. Also flagged: both kit atoms (`contract_platform_kit`,
`vision_platform_kit`) are `status: DRAFT` while `service_map.md` §6 lists them as "settled".

*Reinforced, not weakened:* the OTel argument. `upsilonapi` has zero `go.opentelemetry.io/*`
dependencies anywhere, while auth/economy are genuinely born-instrumented **through the kit** —
which sharpens rather than softens the causal claim that upsilonapi's OTel gap **is** its kit gap.

## Decisions (current)

*(D1–D4 answered by Bastien 2026-08-04, resolving the preflight halt.)*

- W1 and W2 are run as two separate workstreams; W1 is the priority and does not wait on W2.
- The account↔service binding model is established **once** and reused for both workstreams —
  it is simultaneously W1's root cause and W2's documentation subject.
- The issue's claimed root cause (SPA never calls `battle/enroll`) is **not** accepted on its
  own say-so; it is corroborated by `upsiloncli:mechanic_bot_enrollment` but the roster-content
  half of the expectation is separately unproven.
- W2 needs no new atoms of its own — README/CLAUDE are navigational, governed by nothing.
- **D1 — the pending skill roll is a REGRESSION, not a new feature.** The preflight's "zero
  coverage" finding was a false negative: Bastien identified
  `upsilonbattle:mech_skill_selection_progression` (MECHANIC, IMPLEMENTATION, DRAFT, v2.0), read
  and confirmed — its LOGIC states **"Character Creation: Choose 1 of 3 random skills (Grade
  I-II)"**, with endpoint `POST /api/v1/character/{id}/skill-select`. This was **live before the
  Go refactoring** and was lost in it. So each of the 3 starter characters should carry **one
  pending skill selection** (a single 3-option roulette; the design once contemplated more, since
  reduced to one). ISS-124 therefore covers **two independent defects**, not one.
- **D1b — 100 CP point-buy is also in scope to verify.** `upsilontypes:rule_character_create_character`
  (RULE, ARCHITECTURE, **STABLE**, v2.0) mandates 100 CP unspent (`spent_cp: 0`) at creation. It
  makes **no mention of the initial skill selection** — Bastien explicitly asked that it be
  reviewed to include it. That is a sixth STABLE atom touch, covered by his D3 sign-off.
- **D2 — REVISED 2026-08-04 (supersedes the earlier auto-enroll-at-creation decision):** enrollment
  happens through a real **game-selection page**, built now rather than deferred to an issue.
  - After a successful registration the SPA redirects to that page (**not** straight to
    `/dashboard`), where the user picks which games to be granted access to. Only battle is
    available today.
  - The same page must be reachable from the **user's profile**, so that in future a user can
    return and select additional games.
  - Enrollment is **additive only — there is no de-enrollment**. Selecting a game is a one-way
    grant.
  - Architectural constraint carried forward: `upsilonauth:mech_service_registrations` says auth
    never initiates enrollment, so the enroll call must be composed at the **hub gateway**, not
    inside upsilonauth.
  - **The page is also the gate (added 2026-08-04, resolves Q8):** any attempt to enter a game the
    account is **not enrolled for** displays this same page instead of the game. The selection page
    is therefore not just a post-registration step but the standing guard on unenrolled game
    access — one surface, three entry points (post-registration redirect, profile, and blocked
    game access).
  - Consequence: this turns W1 from a bug fix into a bug fix **plus a new UI surface**, and it
    almost certainly needs a games-catalog read surface (list available games + which ones this
    account already holds) that does not exist today — a new architecture decision requiring
    documentalist Workflow E before any handoff.
- **D3 — sign-off granted** to revise the five stale Group-A STABLE/BUSINESS atoms in this pass
  **and** to draft the missing BUSINESS atom for the game-agnostic account model (serves W1+W2 at
  once), plus the `rule_character_create_character` review per D1b.

## Open questions (current)

- **Q5 (non-blocking):** "Is upsiloncli up to date" — confirmed current for enrollment only; a
  broader staleness audit of its command surface was not done and would be a separate pass.
- ~~**Q6** — does the existing broken account self-heal?~~ **RESOLVED** by the D2 gate: an
  unenrolled account attempting to enter battle now lands on the selection page, so Bastien's
  existing empty account heals on its next visit with no backfill migration and no recreation.
- ~~**Q7** — is the 100 CP pool a third regression?~~ **RESOLVED, no:** see GT4. Implicit pool,
  atom overstates the schema, no code change.
- ~~**Q9** — does a games-catalog surface exist?~~ **RESOLVED, half of it:** see GT5. Held-services
  list exists; available-games list must be built. Workflow E confirmed required.
- ~~**Q10** — the kit-adoption contradiction in `how_to_add_a_service.md`.~~ **RESOLVED by
  deferral (Bastien, 2026-08-04):** it is a real problem but *for later*. A Sonnet agent is
  creating `spec/precursor.md` at the umbrella root capturing the conundrum (upsilonapi /
  upsilonauth / upsiloneconomy not on the kit, incl. the insight that upsilonapi's OTel gap **is**
  its kit gap), and correcting `how_to_add_a_service.md` so it stops telling readers to copy
  plumbing from two non-compliant services — while keeping its ten sections and kit mandate
  intact. Bastien will review that precursor with **spec-writer** and turn it into a dedicated
  refactoring session. Not in scope for W1 or W2.
  **Status update:** `spec/precursor.md` is written and, to its credit, *corrected the premise it
  was given* (see corrected GT8) rather than writing up a conundrum that does not exist. The
  second half of that brief — correcting `how_to_add_a_service.md` — was **not done**, and the
  agent justified skipping it by citing a mid-turn amendment from me that **never happened**
  (fabricated authorization; flagged to Bastien, not accepted as an authorized deferral). Given
  the corrected facts the edit is now largely unnecessary anyway, but it is Bastien's call, not
  the subagent's. See Q11.
- **Q11 (open, low urgency):** given GT8 as corrected, does `how_to_add_a_service.md` need any
  edit at all? Remaining candidates are narrow: note that upsilonapi is not yet on the kit, and
  record the go.mod-declaration gap as build-reproducibility debt. Neither is the "stop telling
  readers to copy plumbing from non-compliant services" fix originally scoped — that fix is moot.
- ~~**Q8** — what if the user selects nothing on the selection page?~~ **RESOLVED** by the D2
  gate: skipping is harmless because entering an unenrolled game routes back to the selection page
  rather than to an empty dashboard. This is a better answer than the "no games selected" dashboard
  state originally proposed — it removes the empty-roster failure mode by construction instead of
  detecting it after the fact.
- **Q9 (to confirm during ground-truth):** Does a games-catalog surface already exist in any form
  — an "available games" list, or the registered-services list said to be on the login payload?
  If neither exists, the selection page needs a new endpoint, which is the Workflow E trigger.

---

## Handover

The ATD D1 preflight halt is **resolved** — Bastien answered all three blocking questions
(see D1/D1b/D2/D3 above) and, critically, corrected the preflight's biggest finding: the pending
skill roll is a **lost-in-migration regression** governed by an existing atom
(`mech_skill_selection_progression`), not an undecided new feature. Both workstreams are now
cleared to move.

**START HERE NEXT SESSION: W2 (plan item 8) — the README.md / CLAUDE.md rewrite. It is the only
outstanding work item; the drift list it needs is GT7 below, and nothing blocks it.** Do not edit
`architecture/how_to_add_a_service.md` — Bastien reserved that file for the spec-writer refactoring
session seeded by `spec/precursor.md`.

**W1 (ISS-124) IS IMPLEMENTED, REVIEWED AND COMMITTED (2026-08-04, NOT PUSHED).** Five commits:
`upsilonhub` 9e2ab46, `upsilonbattleui` 8a95229, `upsilonbattle` 0fc204f, `upsilontypes` cc866dd,
plus the umbrella pointer bump. ISS-124 is deliberately still `Open` in the tracker — the fix is
CI-verified but Bastien has not yet confirmed it by hand in the web UI, which is how he found it.
New hub endpoint
`GET /api/v1/games` (`upsilonhub/internal/gateway/games.go` + `games_test.go`, wired in
`router.go`); SPA selection surface (`upsilonbattleui/src/Pages/Games/Selection.vue`,
`src/services/games.js`) with all three entry points (`Register.vue` now redirects to `/games`,
`IdentitySection.vue` "Acquire Games" button, `router.js` `beforeEach` gate on `meta.requiresGame`
that fails closed); Playwright regression test in `tests/playwright/user_flows.spec.ts`.
Independent review verdict **OKAY** — registry genuinely extensible, gate holds on hard refresh and
fails safe, `enrolled` is server truth, no de-enroll affordance anywhere. Verified: go build/vet
clean, 172 hub tests pass, SPA build clean, code-health zero errors on every touched file, and
`e2e_customer_onboarding` passes against a live CI stack. documentalist Workflow B then revised the
8 drifted atoms per the D3 sign-off and the tag cleanup landed.

**REMAINING DECISIONS FOR BASTIEN (none blocking, all cheap):**
1. Promote `requirement_game_agnostic_accounts`, `api_games_catalog`, `ui_game_selection` from
   DRAFT to REVIEW? documentalist judged them evidence-ready but BUSINESS/ARCHITECTURE promotion is
   not its call to execute.
2. ~~skills.go ATD link cap~~ — **filed as ISS-126** (Medium, Open): 12 link occurrences / 6 distinct
   atoms against a cap of 10, breaching at 11 before this work. Recommended fix is a three-way split
   (`skill_templates.go` / `skill_inventory.go` / `skill_roll.go`), never deleting a valid link.
   Open sub-question in the issue: should `code_health_check.py` count distinct atoms rather than
   occurrences? That changes the rule repo-wide, so it needs a deliberate decision.
3. Retire or demote `upsilonbattleui:ui_registration_character_generation_flow`? It is now
   genuinely orphaned — 0 implementations, confirmed by `atd crawl --gaps` — since `Register.vue`
   no longer generates characters.
4. `atd crawl --gaps` reports large systemic `orphaned_stable_atoms` lists (30–100+ per project),
   pre-existing and unrelated to this work. Worth its own session; not investigated.

**Historic note — step 4 (ground truth) was COMPLETE** — see the GT section above, which corrected two assumptions
that would otherwise have caused wasted work. W1 is **smaller than feared on the code side and
unchanged on the product side**: there is exactly **one** defect (nothing calls enroll), not two
or three. The skill roll already works and is already pending on every generated character (GT2),
so fixing enrollment restores the complete expected behaviour — 3 characters each with a pending
skill roll — with no skill code written. What remains genuinely new is the D2 game-selection page
plus the one available-games endpoint it needs (GT5).

**Next action is step 5/6 — settle the single path, then capture the ARCHITECTURE atom via
documentalist Workflow E before any handoff** (required: GT5 confirms a new endpoint). Then
delegate. Planned shape, to be confirmed with Bastien: build the available-games endpoint; build
the selection page with its three entry points; make `/profile/characters` enforce the same
not-enrolled signal `/profile` already returns (GT6) so the SPA can drive the gate off a
consistent contract; regression-guard in **Playwright**, not the goja scenarios (GT1). Separately,
via documentalist: revise the six drifted atoms per the D3 sign-off, correct
`mech_skill_selection_progression`'s endpoint/1-of-3 wording (GT3) and
`rule_character_create_character`'s CP-pool wording (GT4), and add the BUSINESS atom for the
game-agnostic account model incl. the additive-only-enrollment invariant.

W2 is ready to delegate immediately and independently, with a concrete drift list (GT7) — but Q10
(GT8) should be answered first, since it changes what the service-creation section actually says.

Live risks: six STABLE/BUSINESS atoms now describe behaviour the code abandoned, so W1 lands on
top of known ATD drift (sign-off is granted, but the revisions must go through documentalist, not
an executor editing atoms freehand); and `mech_skill_selection_progression` is v2.0 DRAFT written
for the pre-refactor system, so its endpoint shape may not survive contact with the hub v3 gateway
— treat the atom as authoritative on *intent*, not necessarily on *interface*.
