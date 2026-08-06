# TODO — ISS-124 empty roster + umbrella docs refresh

**Status:** `active` — W1, W2, W3a, W3b **all landed and verified** (W1 committed 2026-08-04; W2/W3a/W3b
still uncommitted). Remaining scope is **W4 (code-health tooling: Q15 advisory wiring + Q14 `.ts`/`.tsx`)**
plus close-out bookkeeping. All of Bastien's outstanding decisions were answered 2026-08-05 (see D5–D7).
**Owner:** coordination-leader
**Opened:** 2026-08-04 · **Resumed:** 2026-08-05

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
8. **W2 rewrite of README.md / CLAUDE.md — SCOPED, not yet delegated.** Drift list is GT7 as
   **superseded/extended by GT9** (re-verified against the post-W1 tree, 2026-08-04).
9. ~~W3 — ISS-126 `skills.go` three-way split~~ — **completed** (W3b, landed + verified).
10. **W4 — code-health tooling (Q15 + Q14).** Advisory CI/pre-commit wiring + `.ts`/`.tsx` coverage.
    Scoped and measured (GT11); decisions D5/D6 answered. Task list #1, #2.
11. **Close-out bookkeeping.** File Q13 issue (#3), close ISS-126 + fix its 6→5 count (#4),
    Q16/Q17 atom fixes via documentalist (#5), promote W1 atoms DRAFT→REVIEW (#6), commit (#7).

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

**GT9 — W2 drift RE-VERIFIED 2026-08-04 against the post-W1 tree. Materially LARGER than GT7
recorded; use this list, not GT7 alone.** GT7 was gathered before W1 landed and before the kit
extraction was fully traced.

*CLAUDE.md §1 — the hub-internals map (lines 35-38) is the worst offender and is simply wrong now.*
It claims `platform/` holds `identity, economy, character, clock, jobs` and that `internal/` holds
`database/` and `observability/`. **Verified actual:** `upsilonhub/internal/` = `awards/ config/
events/ games/ gateway/ platform/ seed/ testutil/ transport/` — there is **no `database/` and no
`observability/`**; `platform/` = `character/ economy/ identity/ playerstats/` — **no `clock/`, no
`jobs/`**. All four (`clock`, `jobs`, `database`, `observability`) now live in the
**`upsilonplatform` kit** (verified: kit ships `clock/ database/ httpx/ jobs/ middleware/
observability/ respond/`). Two packages — `awards/` and `platform/playerstats/` — exist and are
documented **nowhere** in either file.

*CLAUDE.md §1 — folder list.* Declares 10 folders; `.gitmodules` declares **13 submodules**.
Missing: `upsilonauth`, `upsiloneconomy`, `upsilonplatform`. Still lists the **retired `/reporting`**
(confirmed absent from disk). Also undocumented but present at root: `/architecture`, `/spec`,
`/skills`, `/deploy`, `/tests`, `/bin`. Note `/architecture` replaced `/reporting` — that swap is
the single most useful correction for agent grounding.

*CLAUDE.md §1 — service list.* Still describes upsilonhub as owning "auth/identity … economy"
in-process. Both are extracted (`:8091`, `:8092` — both confirmed in config); hub keeps interface +
DTO seams only. `upsilonauth`, `upsiloneconomy`, `upsilonplatform` are absent from the service list
entirely.

*Indexing gap (the original W2 ask).* `architecture/` holds 8 docs. `how_to_add_a_service.md` — the
10-step service-creation standard, i.e. the literal answer to Bastien's "how should services be
created from now on" — is cited by **neither** README nor CLAUDE. `architecture/INDEX.md` likewise
cited by neither.

*README.md — narrower, mostly accurate.* Intro (line 3), the 10-item repo structure (incl.
`upsilonauth`/`upsiloneconomy`/`upsilonplatform`), CI section and compose component list are all
**correct and current**. Two real defects: (a) line 36 credits `upsilonauth` with owning
"enrollment" — under the game-agnostic model auth records registrations but **never initiates
enrollment**; enrollment is composed at the hub gateway (`mech_service_registrations`), and as of
W1 it is driven by the `/games` selection page; (b) the devcontainer port table (lines 92-95)
lists 8085/8090/8081/5173 but omits **8091 (auth)** and **8092 (economy)**.

*NEW — W1's own surface is undocumented in both files.* `GET /api/v1/games`
(`gateway/games.go` + `games_test.go`) and the SPA selection page
(`src/Pages/Games/Selection.vue`, `src/services/games.js`) landed in commit `8b329c6`. The
account↔service binding story — **the second half of Bastien's W2 ask** — now has a concrete
implementation to point at: register → `/games` selection → hub-composed enroll → roster.
Neither file mentions it.

**GT10 — ISS-126 issue doc verified accurate against the live file (2026-08-04).** Independent
count confirms every number in the issue: `skills.go` = **274 LOC, 10 funcs, 12 `@spec-link`
occurrences, 6 distinct atoms**. Link line numbers match the issue's map exactly (42, 56, 74,
93-95, 142, 170, 195, 214, 254-255). The three-concern split boundary is clean and function-aligned
— no function straddles two concerns. `gradeAllowed` (:236) is the only unlinked function and rides
with `roll` into CONCERN C. `mountSkills` (:256) carries the two links that would otherwise force a
4th file. **No re-scoping needed; the issue's Recommended Fix is directly executable as written.**

**GT11 — W4 measured 2026-08-05, BEFORE any change. The `.ts` result is far better than Q14 feared.**
Ran `code_health_check.py` directly over all 7 TS files (the full non-`node_modules`/`dist` surface):
**total +1 ERROR, +0 WARNINGS.** That single error is the already-known Q13
(`user_flows.spec.ts`, 12 distinct atoms) — i.e. adding `.ts`/`.tsx` surfaces **no new problem at all**
beyond one already filed. Q14's worry about "an unknown number of new pre-existing errors" is answered: zero.

*Why no tooling work is needed — verified, not assumed.* The existing `.js`/`.vue` parser branches
already cover TS syntax on every dimension: import-stripping (`clean.startswith('import ')` catches
`import type` too), `//` comments, the nesting keyword list, and the ATD regex. **Proof the parser is
live rather than silently inert on TS:** the ATD check *did* fire on `user_flows.spec.ts`, and effective-LOC
counting is demonstrably working — `user_flows.spec.ts` is 409 raw lines against `LOC_WARN = 400` and
correctly does **not** warn once imports are stripped. So `.ts`/`.tsx` is a genuine one-line change.
*Deliberate non-behaviour worth recording:* Playwright specs are written as arrow callbacks inside
`test(...)`, which `func_start_re` does not treat as named declarations — so the missing-documentation
rule does not fire on test blocks. That is correct and desirable (a doc-comment mandate on every
`test()` would be noise), and it is the same treatment `.js` already receives — not a gap.

*Q15 wiring facts:* `.github/workflows/ci.yml` has **no** reference to `code_health_check` (4 jobs:
`build`, `go-tests`, `unit-test-summary`, `integration-tests`). `scripts/pre-commit.sh:27-35` is the
sole caller and is commented out, hard-setting `HEALTH_CHECK="SKIP"`; note line 90's gate already
accepts `SKIP` as passing, so an advisory status slots in without restructuring the summary logic.

**GT12 — CODE HEALTH IS ENTANGLED WITH THE PROJECT CONTRACT ATOM. Found 2026-08-05 while acting on
Bastien's "code health shouldn't be on the ATD side" note. This BLOCKS the W4 README edit — read before
touching README.md.**

Bastien's instinct is structurally correct and the entanglement runs deeper than a single RULE atom.
`docs/contract_upsilon_contract.atom.md` — the project's one-per-project **CONTRACT atom, layer
BUSINESS** — carries code health in four places: line 12 lists `[[rule_code_health_monitoring]]` as a
**dependent**; line 37 mandates adherence to it; line 38 states *"Strict ATD traceability: Every file
must have `@spec-link` tags"*; line 44's TECHNICAL INTERFACE names `scripts/code_health_check.py` by
path.

*Consequence A — the untangling is a CONTRACT amendment, not a cleanup.* Retiring or relocating
`rule_code_health_monitoring` means editing a BUSINESS-layer CONTRACT atom, which ATD governance gates
behind explicit sign-off. Not close-out work.

*Consequence B — line 38 is the origin of the min-1 rule, and it is producing dishonest links.*
Evidence: `scripts/stress_test.py` carries `@spec-link [[rule_code_health_monitoring]]` (a stress-test
script claiming to implement the linting rule — a link of convenience), and `scripts/watch_services.go`
carries `@spec-link [[watch_services]]`, an atom named after the script itself. Both look invented to
satisfy min-1 rather than to record intent. **This is the concrete cost of governing tooling as if it
were business intent** — it manufactures traceability that traces nothing.

*Consequence C — TODAY'S DECISION CREATED A LIVE CONTRADICTION.* Line 39 reads: *"No code shall be
merged without passing the automated health checks and E2E battle simulations."* D5/D8 chose **no CI
gate and manual end-of-session runs**. So the CONTRACT now mandates an enforcement gate that does not
exist and that we have deliberately decided not to build. This is **not** pre-existing drift to shrug
at — the W4 README edit would write the contradiction down in prose. In ATD terms this is a
**HALT-NEEDS-CONTRACT-VISION-DECISION**.

**GT13 — `dependents:` IS AUTO-GENERATED. Bastien's "CONTRACT/VISION must have no dependents nor
parents" cannot be satisfied by editing those atoms. Verified 2026-08-05.**

`.agent/rules/ATD.md` line 95 and line 416: `dependents` is *"auto-populated by `atd weave`"*, which
*"Populate[s] the `dependents[]` array in all atoms by scanning `parents` references."* So the
`dependents:` blocks on `contract_upsilon_contract` (6 entries) and `vision_upsilon_vision` (15
entries) are **derived data**. Hand-deleting them is reverted by the next `atd weave`. **The fix must
be made at the `parents:` end of the referring atoms, not on the CONTRACT/VISION atoms themselves.**

*Half the rule is already satisfied:* both umbrella roots already carry `parents: []`. Only the
`dependents` half is violated.

*What produces those dependents:* all 13 project-level CONTRACT atoms declare
`parents: [[shared:contract_upsilon_contract]]`, and all 13 project VISION atoms declare
`parents: [[shared:vision_upsilon_vision]]`. Additionally three **leaf MECHANIC** atoms in
`upsilontools` (`mechanic_math_core_utils`, `mechanic_randomization_helpers`,
`mechanic_spatial_distance_calculations`) parent **directly to the root VISION**, skipping every
intermediate layer — a separate smell worth noting while we are in here.

*Tension to resolve before acting:* ATD.md line 212 and §3.1 ("No Parent, No Code") require leaf atoms
to have an ancestor in the **BUSINESS** layer. CONTRACT and VISION are both `layer: BUSINESS`, so today
they are frequently *the* satisfying ancestor — e.g. `upsilonauth:contract_auth_service` has
`mech_account_push`, `mech_service_registrations` and `mech_token_introspection` as dependents. A strict
no-dependents rule therefore forces intermediate BUSINESS atoms to be created across every project.
**This is why the scope of the rule must be pinned before any edit — see D11.**

*Incidental corroboration for D6:* `.atd` already lists `".ts": true` in `SupportedExtensions`. The ATD
tooling has covered TypeScript all along; only `code_health_check.py` lagged behind.

## Decisions (current)

*(D13–D14 raised 2026-08-05; D10–D11 2026-08-05; D8–D9 2026-08-05; D5–D7 2026-08-05; D1–D4 2026-08-04.)*

- **D13 — ENGINEERING RULES LEAVE ATD ENTIRELY (generalised from the ESCALATE).** Bastien on
  `rule_ruler_test_robustness`: *"probably more something of coding rules than something else; it doesn't
  belong to ATD. Might be added as a preface to the test themselves as a comment?"* This settles the
  ESCALATE **and** D9 as one principle: an atom that encodes an engineering/coding standard with no
  business rationale is **retired from ATD**, not parked under `req_tech_debt_backlog`. The tech-debt
  anchor is therefore *not* the escape hatch for this class — which removes the manufactured-traceability
  risk I flagged. Consequences measured, not assumed:
  - `rule_ruler_test_robustness` — **0 code links**. Clean retire; content → comment preface on the
    Ruler tests. Zero code-health fallout.
  - `rule_code_health_monitoring` — 2 links: `code_health_check.py` (genuine — the script *is* the rule's
    implementation) and `stress_test.py` (a link-of-convenience, exactly as suspected). **CODING_RULE.md
    §6 already carries the full standard verbatim** (LOC 400/600, nesting ≤4, doc coverage, atom density),
    so D9 is a *duplicate deletion*, not a content migration. Both files then need `@lint-ignore-atd` —
    the honest tag for tooling scripts with no business rationale.
  - `rule_dto_strict_typing` — same coding-rule shape by content, but **4 live `@spec-link`s** in
    upsilonapi (`stdmessage/message.go`, `api/input.go`, `handler/skill_generate.go`,
    `bridge/bridge_utils.go`). Genuine traceability, not links-of-convenience. **OPEN — Q20.**
  - Confirmed CODING_RULE.md covers *neither* DTO typing nor test robustness today, so any content moved
    there is additive, not duplicative.
- **D15 — Q20 RESOLVED: `rule_dto_strict_typing` RETIRES TOO**, applying D13 consistently. The cost I
  warned about **did not materialise**: all 4 linking files already carry a second, genuine `@spec-link`
  (`stdmessage/message.go` → `api_standard_envelope`; `api/input.go` → 7 others; `handler/skill_generate.go`
  → `api_skill_generation`; `bridge/bridge_utils.go` → `mechanic_mec_skill_payload_resolution`). So
  dropping the link orphans **nobody**, needs **zero** `@lint-ignore-atd`, and slightly *reduces* atom
  density (helping the cap pressure behind ISS-126/127). Only residue: two **prose** mentions of
  `[[rule_dto_strict_typing]]` in `handler/skill_generate.go` (lines 21, 94) must be reworded to cite
  CODING_RULE.md §4 instead — they are not `@spec-link`s so the checker ignores them, but they'd be stale
  references to a deleted atom.
- **D16 — RECLASSIFY approved** (`module_skill_sandbox` → MODULE/ARCHITECTURE; `rule_api_bridge_orchestration`
  → ARCHITECTURE).
- **D17 — `rule_mapmaker_seed_determinism` STAYS a true BUSINESS atom.** Bastien: *"we need this feature,
  it's a definite business requirement."* Seed determinism is product behaviour, not an engineering
  standard — so D13 does **not** apply to it. Detach from CONTRACT + re-parent per the table; keep
  BUSINESS/STABLE. The `--force` guard is fine here: the edit only removes a CONTRACT parent, which is the
  mechanical consequence of D11.
- **D18 — `requirement_observability_logging` IS a coding rule → RETIRES (4th retire under D13).**
  CODING_RULE.md §2 already covers observability comprehensively (OTel on all three edges, `traceparent`
  propagation, the `time.Now()`/ad-hoc-goroutine ban), so this is another **duplicate deletion**, exactly
  like code health. Cascade measured:
  - `upsilontools/tools/actor/actor.go` holds its only 2 links (lines 110, 113) — but the file also carries
    `mech_actor_pattern`, `mech_actor_lifecycle` ×3 and `mech_actor_dispatch_loop`, so it does **not**
    orphan.
  - **`mechanic_logger_initialization` (DRAFT, IMPLEMENTATION) parents *solely* to it** and would be
    orphaned. It anchors all 4 links in `upsilontools/logger/logger.go`, so it must **not** retire too.
    It describes real shipped code (Logrus initialisation), not a standard → re-parent to upsilontools'
    own `req_tech_debt_backlog`, the same treatment already accepted for the math/random/spatial trio.
- **D19 — `entity_mapdata_3d_grid` retires; `entity_grid` survives and must be completed.** ⚠ **The review
  agent under-called this one:** it reported "zero dependents", which is true only at the *atom* level —
  the atom actually has **10 live `@spec-link`s** across `upsilonmapdata/grid/`. So this is a
  **consolidation, not a deletion**: repoint those 10 links onto `entity_grid`, then retire. Safe to do —
  all 10 files carry a second link (`rule_mapdata_grid_standard` or others), so nothing orphans at any
  point. `upsilonmapdata/grid/grid.go` already links **both** atoms (lines 4 and 15), which is the
  duplication proven in a single file; there, just drop the stale line. `entity_grid` is the richer atom
  (A\* navigation, placement/movement, vertical layout, boundary validation) and already has a real atom
  dependent (`mechanic_multi_entity_cell_system`) plus its own links in `grid.go` and cross-project in
  `upsilonbattle/battlearena/ruler/rules/attack_checks.go` — so it is the correct survivor. Must be
  checked for completeness against the 10 files' actual behaviour before the repoint lands.
- **GT15 — free defect found while tracing D19:** `upsilonmapdata/grid/grid_test.go` and
  `.../pattern/pattern_test.go` use `@spec-link` where test files require `@test-link` — a standing
  code-health ERROR. The executor is editing those exact lines for D19 anyway, so fix in the same pass.
- **NET EFFECT of D13+D15 on the 25:** three rows leave the re-parenting problem entirely rather than
  being re-parented — `rule_ruler_test_robustness`, `rule_code_health_monitoring`, `rule_dto_strict_typing`.
  **22 atoms remain to re-parent**, and the STABLE set drops from 5 to 4.
- **D14 — BOTH NEW BUSINESS ATOMS APPROVED.** `requirement_identity_account_lifecycle` (upsilonauth,
  parent for `mech_account_push` / `mech_service_registrations` / `mech_token_introspection`) and
  `requirement_economy_wallet_ledger_core` (upsiloneconomy, parent for `mechanic_award_idempotency` /
  `mechanic_gdpr_purge` / `mechanic_purchase_transaction` / `mechanic_wallet_lazy_create`). DRAFT is the
  ceiling; nothing self-promotes. These two projects are the only ones lacking their own
  `req_tech_debt_backlog`, so the proposal was structurally forced rather than invented.

- **D10 — CONTRACT amendment APPROVED, and D9 IS IN SCOPE FOR THIS SESSION.** Bastien chose "README now
  + amend CONTRACT line 39", granting the CONTRACT sign-off. He then corrected the deferral: *"not sure
  it's a companion to the spec (which will be dedicated to some refactoring). Just add it to the stack
  of thing to do in this session."* So the code-health-leaves-ATD untangle is **not** deferred to a
  spec-writer session — it is this session's work. All atom edits go through **documentalist**, never an
  executor.
- **D11 — RESOLVED 2026-08-05: the STRICT reading.** Bastien: no atom anywhere may declare a CONTRACT
  or VISION as its parent. Scope measured immediately (GT14) rather than estimated.

**GT14 — STRICT-READING BLAST RADIUS, MEASURED 2026-08-05. 49 atoms declare a CONTRACT/VISION parent,
and they split into two very unequal halves.**

*Half 1 — 24 atoms: mechanical detach, low risk.* 12 CONTRACT + 12 VISION atoms (the project-level
pairs) simply drop their `parents: [[shared:...]]` line, becoming their own roots. This is consistent
with the established one-CONTRACT-one-VISION-per-project rule and needs no new atoms.

*Half 2 — 25 atoms: NOT mechanical. This is the real cost.* 14 MECHANIC, 8 RULE, 1 REQUIREMENT,
1 MODULE, 1 ENTITY currently hang off a CONTRACT. Because CONTRACT is `layer: BUSINESS`, that CONTRACT
is today **the atom satisfying ATD.md §3.1's "No Parent, No Code" BUSINESS-ancestor requirement**.
Detaching them without a replacement parent breaks that rule for all 25. They therefore need **new
intermediate BUSINESS atoms — roughly one per project across ~10 projects** (`shared` ×2 RULE,
upsilonapi ×1, upsilonauth ×3, upsilonbattle ×3, upsiloneconomy ×4, upsilonmapdata ×2, upsilonmapmaker
×2, upsilontools ×4, upsilontypes ×3).

*The trap to avoid, stated plainly:* those ~10 new BUSINESS atoms have to carry **real intent** — what
business requirement does `mech_token_introspection` actually serve? Generating them as thin
placeholders purely to satisfy the parent rule would manufacture traceability that traces nothing —
**exactly the disease D9 is trying to cure** (cf. GT12's links-of-convenience on `stress_test.py` and
`watch_services.go`). Done hastily, this change makes the papertrail worse, not better. It is design
work, not editing, and it is the reason this half should not be rushed alongside the close-out.

*Overlap worth noting:* 2 of the 8 RULE re-parents (`rule_code_health_monitoring`,
`rule_dto_strict_typing`) hang off the umbrella CONTRACT, so D9's untangle already covers part of
Half 2.

- **D12 — CONTRACT/VISION SEMANTICS, stated by Bastien 2026-08-05. Durable; carry this into every
  future ATD decision.**
  - **CONTRACT defines what the project does *as it stands*.** Its most potent use is as a
    **breaking-change check, analogous to API versioning**: if a proposed change breaks the current
    contract, then either the contract changes *and its version is bumped*, or the change is reworked
    so it does not break the contract.
  - **VISION exists to ensure we don't drift from the stated objective.**
  - **Therefore both are guard/reference artifacts, NOT nodes in the traceability graph.** This is the
    conceptual resolution of GT14's §3.1 tension: the 25 affected atoms were never genuinely
    "connected to business" — they were leaning on an artifact never meant to hold them. Re-parenting
    them is not damage repair, it is correcting a category error.
  - Bastien is in discussion with the **ATD team** to have the linter flag CONTRACT/VISION carrying
    `parents:`/`dependents:` as faulty; he reports it is already in ATD's own documentation. So this
    rule is expected to become tool-enforced — another reason not to hand-patch around it.

- **Review pass commissioned 2026-08-05.** A read-only `documentalist` side agent is producing
  `spec/atd_reparenting_review.md`: a per-project table over the 25 atoms giving each one's real INTENT
  (read from the atom, not guessed), a concrete suggested parent, and a ruling from
  `RE-PARENT-EXISTING` / `NEEDS-NEW-BUSINESS-ATOM` / `RECLASSIFY` / `RETIRE` / `ESCALATE`. It is
  briefed to prefer existing BUSINESS atoms, to consolidate several children under one new parent
  rather than inventing one each, and — explicitly — to answer `ESCALATE` rather than manufacture a
  plausible-looking placeholder parent. **Execution of the re-parenting is gated on Bastien reviewing
  that table.** Do not edit `spec/atd_reparenting_review.md` while the agent is running.

- **D8 — Q15 RESOLVED, and it SUPERSEDES D5's wiring plan.** Bastien, asked whether `pre-commit.sh`
  should become a git hook: *"just correct the readme.md explain that code health script is available
  and should be called upon at the end of each developpement session to ensure code quality doesn't
  degrade too much."* So: **no git hook, and no CI wiring either** — the "don't turn CI red" constraint
  from D5 is satisfied a fortiori by not wiring CI at all. The `--warn-only` flag D5 proposed is
  therefore **dropped as unnecessary**: with no automated caller, nothing reads the exit code.
  Code-health becomes a documented **human discipline**, run at the end of each dev session.
  - *Rejected alternatives, with reasons, so this is not relitigated:* (a) `pre-commit.sh` as a git
    hook — it runs `go vet` over 7 modules and `go test` booting throwaway Postgres containers, i.e.
    minutes per commit, which trains reflexive `--no-verify` and is worse than no hook; (b) a
    staged-files health-only hook — technically sound (**0.43s for the whole umbrella**, and the script
    already accepts a file path), but hooks are per-repo and untracked while the code lives in **13
    submodules**, so an umbrella hook fires on pointer-bump and docs commits, precisely where the code
    is not; (c) whole-repo advisory CI — the repo currently reports **602 errors / 92 warnings**, so it
    would print a wall of log noise that trains people to scroll past it.
- **D9 — RAISED by Bastien 2026-08-05, NOT YET RESOLVED: code health does not belong in ATD.** *"code
  health shouldn't be on the ATD side of thing (it's not related to a business decision truly, but a
  general software practice and coding rules...)."* Structurally right — ATD records product/business
  intent, whereas LOC ceilings and nesting limits are tooling policy whose natural home is
  `CODING_RULE.md`. **Blast radius is a CONTRACT atom — see GT12 — so this needs deliberate handling
  (documentalist + explicit sign-off, or a spec-writer session), not a drive-by edit.**
  - *Immediate effect on this close-out:* **Q16 and Q17 are both ON HOLD.** Q16 polishes
    `rule_code_health_monitoring`'s LOGIC; Q17 tweaks `contract_platform_kit`'s "1–10 ATD links/file"
    recap. Both are the exact category D9 questions. Polishing atoms that may be retired or relocated
    is wasted work, and Q17's granted sign-off is **not** consumed — it stays available.

- **D5 — Q15 resolved: wire the code-health gate in ADVISORY mode, NOT as a hard gate.** Bastien:
  *"ensure that this doesn't turn red the CI (warning is sufficient for now)."* So the checker gets
  wired into both CI and pre-commit but **must not fail the build** — the hub's ~67 pre-existing errors
  would otherwise turn main red immediately. Chosen shape: an explicit `--warn-only` flag on the script
  (still prints every ERROR, always exits 0) rather than a shell `|| true` or `continue-on-error:`,
  because the flag makes the advisory status legible at the call site and is a one-token flip to
  enforcing later once the error count reaches zero.
  - *Carries a documentation obligation:* `README.md:142` currently claims code health is *"verified
    locally via the pre-commit hook and in CI"*, which is false today. After this wiring it becomes
    true **only if worded as advisory** — it must not be left implying enforcement.
- **D6 — Q14 resolved: add `.ts`/`.tsx`; KEEP `.php`.** Bastien: *"It should work on ts/tsx file as well
  of course (with appropriate tooling i expect). leave the ability to work with php file, who knows if
  we will need it at a later date."* The "appropriate tooling" expectation is satisfied without new
  tooling — see GT11 for the evidence that the existing parser genuinely handles TS. `.php` is retained
  deliberately despite Laravel `battleui` being decommissioned; this reverses the earlier
  recommendation to drop it, and the reason (possible future use) should be recorded in the script so
  nobody "cleans it up" later.
- **D7 — the remaining close-out items are approved as proposed** ("ok for the rest"): file the Q13
  sibling issue, close ISS-126 and correct its 6→5 distinct-atom count, apply the Q16 and Q17 atom
  fixes (Q17's CONTRACT-atom sign-off is hereby **granted**), promote the three W1 atoms DRAFT→REVIEW,
  and commit everything outstanding. **Push remains a separate explicit confirmation** — it is a
  high-impact action across 5 repos and is not taken as covered by "ok for the rest".

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

- **D4 — ATD link cap counts DISTINCT ATOMS, not occurrences (Bastien, 2026-08-04).** Resolves
  ISS-126's long-term open sub-question. Implementation is a one-line change at
  `scripts/code_health_check.py:104` (`len(atd_links)` → `len(set(atd_links))`); the regex at :100
  already captures the atom ID as group 2, so no parsing change is needed. **The `min 1` check and
  the phantom-link check must keep their current semantics** — only the max/warn comparison moves to
  distinct counting.
  - *Consequence for W2:* this rule is stated in **three** places that W2 is already rewriting —
    `README.md:145`, `CLAUDE.md` §0 item 6, and `CODING_RULE.md` §6. They must all move together.
  - *Recommended sequencing (pending Bastien):* land the one-line counter change + the three doc
    wording updates **before** the main W2 rewrite, so W2 documents the rule as it actually is
    rather than as it will be. This pulls a small slice of W3 ahead of W2.
- **D4 blast radius — MEASURED repo-wide, 2026-08-04** (527 files carrying links). The change is
  far smaller and safer than feared: **only 2 files in the entire umbrella currently error** on the
  cap. Under distinct counting: `skills.go` 12 occ → **5 distinct** (drops out of ERROR entirely);
  `upsilonbattleui/tests/playwright/user_flows.spec.ts` 13 occ → **12 distinct** (**still ERRORs**).
  The WARN band (6-10) shrinks from **44 files to 15** — a real and desirable noise reduction, and
  the strongest evidence the occurrence count was measuring the wrong thing.

- **W3a — LANDED and independently verified 2026-08-04.** `git diff --stat` = exactly the 4 intended
  files (10 insertions / 8 deletions). Counter logic read and confirmed correct: `ATD_MIN` still
  compares raw `atd_count` (equivalent at the 0-link case, semantics unchanged), `ATD_ERROR_MAX` and
  `ATD_WARN_MAX` now compare `distinct_atd_count`, phantom-link and spec-link-in-test-file checks
  untouched. Messages reworded to "Too many/Many distinct ATD atoms". `skills.go` clears; 
  `user_flows.spec.ts` still errors at 12 distinct when invoked directly. Not committed.

- **W3b (ISS-126 split) — LANDED and independently verified 2026-08-04.** I re-verified every
  material claim rather than accepting the executor's report:
  - **Link preservation: 12 → 12, sets IDENTICAL** (script-extracted (function → atom) pairs from
    `HEAD:skills.go` vs the four new files). Nothing lost, nothing added.
  - **Routes byte-identical** — same 6 paths/methods before and after.
  - **No test lost: 11 → 11, identical set** across `skill_templates_test.go` /
    `skill_inventory_test.go` / `skill_roll_test.go`. (This was the real risk in redistributing a
    deleted test file; it is clean. Note the executor's own report miscounted the split as 3+2+7=12
    — the *set* is right, its arithmetic was off. Cosmetic.)
  - `go build ./...` and `go vet ./...` clean. Per-file distinct links: templates 1, inventory 2,
    roll 3, skills 2 — all far inside the cap.
  - Judgement call made by the executor and accepted: shared `skillFixture` relocated into the
    existing `phase5env_test.go` rather than a standalone fixture file, because a fixture-only file
    would carry 0 links and trip the min-1 rule. Correct reasoning — the alternative would have been
    inventing a dishonest `@test-link`.
  - Files: 4 source (`skill_templates.go`, `skill_inventory.go`, `skill_roll.go`, thin `skills.go`)
    + 3 test files created, `skill_test.go` deleted, `phase5env_test.go` modified. Not committed.
  - Independently confirms **Q12**: ISS-126's summary line saying "6 distinct atoms" is wrong; it is
    **5**. Correct this when closing the issue.

- **W2 (README/CLAUDE refresh) — LANDED and independently verified 2026-08-04.** Verified by me,
  not taken on report: `git diff --stat` = exactly `README.md` + `CLAUDE.md` (19 insertions / 11
  deletions). **Hard guardrail held — `architecture/` is untouched** (`git status` clean there), no
  `.atom.md` edited, W3a's "distinct ATD atoms" wording preserved verbatim in all three places.
  Zero `/reporting` references remain. **Every relative markdown link in both files resolves** to a
  real path (scripted check). `how_to_add_a_service.md` and `architecture/INDEX.md` are now cited
  from **both** files — the original discoverability ask, closed. CLAUDE.md's hub-internals map now
  matches `ls` output exactly (`platform/` = `character economy identity playerstats`; `clock`/
  `jobs`/`database`/`observability` correctly attributed to the `upsilonplatform` kit; `awards/`
  added). README's two defects fixed: the "auth owns enrollment" claim and the 8091/8092 port
  omission. Not committed.

- **D4 — INDEPENDENTLY REVIEWED, verdict OKAY (reviewer, 2026-08-04), no blocking issues.**
  - *The 44→15 WARN drop is evidence FOR the change, not against it* — the reviewer pulled the 29
    departing files and they are textbook single-concern: `accountpush.go` 7 occ → **1** distinct
    (`mech_account_push` ×7), `turner.go` 7 → **1** (`mech_initiative` ×7), etc. Because ATD mandates
    a link atop **every function**, the old metric was effectively counting *documented functions*,
    not spec breadth — a duplicate proxy for LOC/nesting with an absurd 10-function ceiling. The 29
    are retired false positives.
  - *`ATD_MIN` asymmetry is provably inert:* `len(s)==0 ⟺ len(set(s))==0`, so at `ATD_MIN = 1` the
    two comparisons agree on every possible input. **Caveat to remember: this holds only while
    `ATD_MIN == 1`** — raising it to 2 would silently reintroduce occurrence semantics at the floor.
    Worth an inline comment.
  - *All three prose statements verified to agree* with each other and the code.
  - *Correction to my figures:* `skills.go` was already split by the concurrent workstream, so the
    tree today has **0 cap errors under the old rule as well as the new**. D4's practical effect
    right now is WARN-band-only; the "12 → 5" figure describes the pre-split file.
  - Cosmetic, non-blocking: the min-branch message still says "Too few ATD **links**" while
    max/warn now say "distinct ATD **atoms**".

- **ATD close-out — DONE and verified 2026-08-04 (documentalist).**
  - *Task A:* `docs/rule_code_health_monitoring.atom.md` LOGIC item 4 gained a **Counting basis**
    bullet pinning distinct-atom semantics for the 5/10 thresholds **and** recording that the
    minimum-presence check still counts raw occurrences, with the reason they coincide at zero.
    Status left DRAFT. `atd weave` + `atd lint` clean. Verified present in the file by me.
  - *Task B:* per-file `@test-link` verification is **clean — no blanket-copy anywhere.**
    `skill_templates_test.go` claims 1 atom / 3 tests; `skill_inventory_test.go` 1 atom / 2 tests;
    `skill_roll_test.go` 2 atoms / 6 tests; pre-existing `skill_equip_test.go` 2 atoms / 8 tests,
    correctly scoped and rightly left alone. **3+2+6 = 11 confirms my own count** (and again the
    executor's 3+2+7 was the miscount). Notably `skill_roll_test.go` correctly omits
    `rule_character_skill_slots` even though `roll()` carries it — none of those 6 tests assert slot
    capacity, and the atom itself says rolling is uncapped. That is a genuinely accurate narrowing,
    which is exactly what ISS-126 asked for. No atom edits needed for the split.

- **Q16 (NEW, LOW — cheap fix, real drift).** `rule_code_health_monitoring` LOGIC line 35 states
  *"Error: < 2 ATD links"*, but the code is `ATD_MIN = 1` with the check `atd_count < ATD_MIN` —
  i.e. it errors only at **zero** links. **A file with exactly 1 link passes the checker but
  violates the atom as written.** Pre-existing, unrelated to D4, found while making the counting-basis
  edit and correctly flagged rather than silently folded in. One-line atom fix, DRAFT, no sign-off.

- **Q17 (NEW, awaiting Bastien's sign-off).** `upsilonplatform/docs/contract_platform_kit.atom.md`
  recaps "1–10 ATD links/file" among inherited non-negotiables and carries the **same ambiguity D4
  just closed** in the RULE atom. Documentalist judged materiality low (it is a terse recap, not the
  operative definition) but noted a CONTRACT atom should be self-sufficient rather than leaning on
  the RULE atom to disambiguate. Proposed minimal tweak: `1–10 distinct ATD atoms/file`.
  **Deliberately NOT edited — CONTRACT atoms need explicit sign-off.**

- **Q15 (NEW, HIGH — supersedes Q14 in importance; found by reviewer, verified by me 2026-08-04).**
  **The code-health gate has NO automated enforcement anywhere.** `CODING_RULE.md` §6 declares
  zero-error code health a *non-negotiable*, yet:
  - `scripts/pre-commit.sh:27-35` — the invocation is **commented out**, the step is literally
    labelled `[0/4] Running Code Health Check (DISABLED)`, and it hard-sets `HEALTH_CHECK="SKIP"`.
  - `.github/workflows/ci.yml` — **never references `code_health_check` at all**.
  - A repo-wide grep finds **exactly one caller: that commented-out line.** Nothing else invokes it.
  - **`README.md:142` therefore states something false:** *"These are verified locally via the
    pre-commit hook and in CI."* Neither is true.
  - *Consequence:* every code-health acceptance criterion imposed on executors this session was
    satisfied only because an agent ran the checker **by hand**. Nothing would have caught a
    regression. This also puts Q14 in perspective — the `.ts` extension list barely matters while
    nothing runs the checker at all. **Fix the wiring first, the extension list second.**
  - *Ownership note:* this README falsehood survived W2 because **I** guardrailed the executor away
    from the Code Health Standards section to protect W3a's wording. Correct call for isolation,
    but it means this line needs a deliberate follow-up edit — it will not have been swept up.

- **Q14 (NEW, MEDIUM-HIGH — arguably the most consequential finding of this session).**
  `scripts/code_health_check.py:12` declares `EXTENSIONS = {'.go', '.py', '.php', '.js', '.vue'}`.
  **`.ts`/`.tsx` are absent, so no TypeScript file is ever visited by a directory sweep.** Verified:
  the repo has **7 `.ts` files outside `node_modules`/`dist`, and every single one carries ATD
  links** — `playwright.config.ts` plus all 6 Playwright specs (`user_flows`, `components`,
  `battle_arena`, `battle_arena_sandbox`, `battle_debug`, `visual_smoke_test`). So the **entire
  Playwright suite is exempt from the zero-error standard** that CODING_RULE.md §6 declares
  non-negotiable — including the ISS-124 regression guard W1 just added.
  - This is *why* Q13's breach went unnoticed: `user_flows.spec.ts` only errors when the checker is
    invoked on the file path directly, never via CI's directory sweep.
  - Note `.php` is still in the set although Laravel `battleui` was decommissioned post-Phase 6 — a
    leftover to drop in the same pass.
  - **Not a W2 concern:** `README.md`:140 accurately scopes the claim to "(Go, Python, JS, Vue)", so
    the docs do not misrepresent this. It is a tooling-coverage gap, not a documentation drift.
  - Decision needed from Bastien: add `.ts`/`.tsx` (and drop `.php`)? Doing so will surface an
    unknown number of new pre-existing errors across the Playwright suite, so it should be measured
    before it is switched on — same measure-first approach that made D4 safe.

**W4-script (task #2) — LANDED and INDEPENDENTLY VERIFIED 2026-08-05.** I re-ran every measurement
rather than accepting the executor's report:
- `git diff --stat` = **1 file**, `scripts/code_health_check.py`. `.ts`/`.tsx` added, `.php` retained
  with the explanatory comment, docstring language list updated.
- **W3a's distinct-atom counting survived untouched** — re-read lines 104-111: `ATD_MIN` still compares
  raw `atd_count`, error/warn compare `distinct_atd_count`. (The diff-vs-HEAD shows that block because
  W3a is itself still uncommitted, not because the executor touched it.)
- Per-file TS re-run reproduces GT11 exactly: 6 files at 0/0, `user_flows.spec.ts` at 1 error.
- **Full-repo total went 602 → 603 errors**, i.e. exactly +1. That is the strongest evidence the change
  actually took effect *in the directory-sweep path* rather than only on direct invocation — the
  `user_flows.spec.ts` error is now reachable by a plain `code_health_check.py .` run, which is what
  Q14 said was impossible before.

**Q19 (NEW, MEDIUM — found while verifying task #2, 2026-08-05). The `@lint-ignore-*` detection is a
naive whole-file substring match, so merely MENTIONING a tag disables checking.**
`check_file` tests `if '@lint-ignore-all' in content:` against the entire file body (line ~51). It does
not require the tag to appear in a comment, at file top, or in any particular form. **Consequence: any
file that mentions the string anywhere — in a comment, a docstring, a string literal, documentation, or
a test asserting on the feature — is silently skipped in full.**

*Demonstrated, not theorised:* `python3 scripts/code_health_check.py scripts/code_health_check.py`
prints `Skipping scripts/code_health_check.py (@lint-ignore-all found)`. The checker exempts **itself** —
and not by a deliberate tag. Confirmed there is no standalone `@lint-ignore` comment in the file; it is
skipped purely because its own detection code contains the string literal. *(The task-#2 executor
reported the self-skip but attributed it to an intentional tag. The observation was right, the reason
wrong — hence verifying rather than accepting reports.)*

*Why it matters:* this is a silent false-negative vector, and it makes README's documented "Exemptions"
section materially more trigger-happy than it states. Cheap fix: require the tag to appear in a comment
line, or anchor it to the file's first N lines. **File this once executor B releases `issues/`** — do
not race it.

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
- **Q12 (NEW, low urgency) — ISS-126 overstates skills.go's distinct-atom count as 6; it is 5.**
  Verified by `sort -u` on the atom IDs: `api_character_skill_inventory`, `api_skill_template_browse`,
  `mech_skill_selection_progression`, `req_skill_generation`, `rule_character_skill_slots`. Does not
  change the issue's conclusion (the three-concern split argument is unaffected), but the issue doc
  should be corrected when W3 closes it out.
- **Q13 (NEW, medium) — `user_flows.spec.ts` is a second, unrelated cap breach that D4 does NOT
  fix.** 13 occurrences / **12 distinct** atoms, so it errors under either counting rule. **Verified
  pre-existing, not caused by W1:** commit `8a95229` added 66 lines to the file but **zero** link
  lines. This is exactly the "over-broad claim about what a single test proves" failure ISS-126 §3
  describes, one layer up — a single Playwright spec file asserting coverage of 12 atoms. Needs its
  own split along flow boundaries. Recommend filing as a sibling issue rather than absorbing it into
  W3, whose scope is `skills.go`.
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

## ATD preflight D1 — re-run 2026-08-04 (post-W1, covering W2 + W3a + W3b)

**All three verdicts: PROCEED.** None touches a STABLE **BUSINESS** atom or a CONTRACT/VISION atom,
so no `--force` guard and no sign-off question arises.

- **W3a — PROCEED.** Governing atom `rule_code_health_monitoring` (RULE, ARCHITECTURE, **DRAFT**,
  `docs/`). Its LOGIC states the 1/5/10 thresholds but **does not pin occurrence-vs-distinct
  counting** — so D4 *resolves an ambiguity it leaves open* rather than contradicting it. Revision
  is a normal DRAFT edit, **no sign-off needed**, but must go through documentalist, not an
  executor. `README.md`/`CLAUDE.md`/`CODING_RULE.md` carry **no ATD tags at all** — prose-only,
  ungoverned, free to edit. `upsilonplatform:contract_platform_kit` (CONTRACT, DRAFT) echoes the
  "1–10 links" figure among inherited non-negotiables but is **not invalidated** — the bound is
  unchanged, only what is counted. No other atom mentions the cap.
- **W2 — PROCEED** (prior verdict confirmed). No atom's TECHNICAL INTERFACE names `README.md` or
  `CLAUDE.md`; they remain purely navigational. W1's three atoms (`requirement_game_agnostic_accounts`,
  `upsilonhub:api_games_catalog`, `upsilonbattleui:ui_game_selection`, all DRAFT) were verified to
  have their `@spec-link`s actually placed in shipped code — **described behaviour is real, not
  aspirational**, so W2 may document them. DRAFT status does not gate this: README/CLAUDE are not
  ATD artifacts. Independently confirmed both W2 defect claims: README:36's "auth owns enrollment"
  genuinely contradicts `requirement_game_agnostic_accounts` ("no game module or service may assume
  registration implies enrollment"), and the port table does omit 8091/8092.
- **W3b — PROCEED.** Five governing atoms; three are **STABLE** (`api_skill_template_browse`,
  `api_character_skill_inventory`, `rule_character_skill_slots`). Not a blocker: the STABLE guard
  governs *editing an atom*, not moving code beneath an unchanged tag.
  - **CORRECTION to a live risk carried since last session:** `mech_skill_selection_progression` is
    **already reconciled, not stale**. Its v2.0 INTENT/LOGIC/INTERFACE now correctly describe the
    single grade-gated roll and the shipped `POST /api/v1/profile/character/{id}/skills/roll`,
    matching `roll()` exactly — landed in commit `0fc204f`. GT3 and the old Handover's "may not
    survive contact with the hub v3 gateway" warning are **superseded**. Nothing to reconcile.
  - Post-split watch item (Workflow B): ensure each new test file's `@test-link` header claims only
    the atoms it actually exercises — do not blanket-copy all 4 into all 3 files.

**Loose end to not forget:** `rule_code_health_monitoring`'s LOGIC needs one explicit sentence
pinning "distinct atom IDs, not tag occurrences" once W3a lands. Documentalist, DRAFT edit.

---

## Handover

**AS OF 2026-08-06 — ATD GRAPH SURGERY COMPLETE AND INDEPENDENTLY VERIFIED. ALL AGENT LANES CLOSED.**

### What landed and what I verified myself (not taken on agent report)

**documentalist (retry, 6 stages) — COMPLETE.** Independently re-verified by me across all 327 `.atom.md`:
- 5 deletions confirmed absent: `rule_ruler_test_robustness`, `rule_code_health_monitoring`,
  `rule_dto_strict_typing`, `requirement_observability_logging`, `entity_mapdata_3d_grid`.
- **0** dangling references to those 5 ids in any atom; **0** dangling `@spec-link`/`@test-link` in any
  source file (.go/.py/.ts/.tsx/.vue).
- **26** CONTRACT/VISION atoms, **all** with empty `parents:` AND empty `dependents:` (D11 satisfied).
- **0** atoms anywhere parent to a `contract_*`/`vision_*` (D11 strict reading satisfied).
- **0** phantom parent refs graph-wide.
- 2 new BUSINESS atoms exist (`requirement_identity_account_lifecycle`,
  `requirement_economy_wallet_ledger_core`); 21 re-parents, 2 reclassifies, CONTRACT amendment,
  `entity_grid` enrichment (verified against all 10 linked source files), `atd weave` (24 files updated).
- **No source code touched by documentalist** — verified: the non-atom modified-file set across all 13
  repos matches the executor lane exactly, with nothing added.

**reviewer — OKAY** on the landed code-side diff (all 9 tasks correct, no logic touched, single Ruler
comment block, no stale refs), with 2 non-blocking notes. Note 2 acted on: see phantom fix below.

**codebase-explorer — inventory delivered** (per-repo file table + 6-phase commit order). ⚠ It ran
*concurrently* with the documentalist, so its atom-side rows are partly speculative ("assume it landed") and
are now superseded by the verification above. Its **source-side** inventory and commit ordering are sound.

### Fixes I made by hand this round
- `scripts/stress_test.py` line 7 carried `[[mechanic_mech_battle_engine_stress_testing]]` — a **phantom**
  (pre-existing typo in HEAD; the real id is `mechanic_battle_engine_stress_testing`, and the `mech_`
  variant exists nowhere). Corrected. Re-ran the checker: **zero ATD/phantom errors** on that file. The 16
  remaining errors there (nesting 21 in `consolidate`, missing function docs) are **pre-existing quality
  debt, unrelated to this change set and out of scope.**

### RESOLVED this round (Bastien: "they should still follow the ATD schema so fix it, otherwise continue")
- **D20 ACCEPTED** — `mechanic_skill_payload_resolution` re-parent to `[[shared:requirement_customer_api_first]]`
  stands (documentalist deviation, judged sound: API-resilience mechanic, legitimate BUSINESS parent, and
  leaving it would have orphaned a live atom under ATD §3.1).
- **D21 — both new BUSINESS atoms brought to ATD schema by hand.** The defect was wider than the H1:
  - H1 `# New Atom` → the atom's `human_name` (per the ATD.md §1.2 template).
  - `tags:` plain comma scalar → flow list `[a, b]` — matching the ATD template and 293 of 327 atoms
    (only 16 use the plain-scalar outlier form).
  - All 4 mandatory sections (INTENT / THE RULE / LOGIC / TECHNICAL INTERFACE / EXPECTATION) confirmed present.
  Hand-edited rather than routed through documentalist because it reported no `atd` subcommand can set
  either field; `atd lint` re-run clean on both.

### TASK #5 — DONE
- **Q16 MOOT** — its host atom `rule_code_health_monitoring` was deleted under D13.
- **Q17 DID NOT LAND** despite being reported as landed (codebase-explorer speculation, not documentalist
  fact — a good reason the report was verified rather than trusted). Fixed by hand:
  `upsilonplatform/docs/contract_platform_kit.atom.md:27` "1–10 ATD links/file" → "1–10 distinct ATD
  atoms/file". Repo-wide re-scan: **0** residual instances of the stale phrasing. `CLAUDE.md` §0.6,
  `README.md:147` and `CODING_RULE.md` §6 were already correct.

### TASK #6 — DONE
- Promoted DRAFT → REVIEW via `atd update --set status=REVIEW`: `requirement_game_agnostic_accounts`
  (1 code link), `upsilonhub:api_games_catalog` (4), `upsilonbattleui:ui_game_selection` (4). REVIEW is the
  correct stop — not STABLE — because ISS-124 remains Open pending Bastien's web-UI confirmation.
- **`ui_registration_character_generation_flow` is NOT orphaned.** The task item was based on a stale
  reading: it carries a pre-existing parent `[[ui_registration]]` (which exists), and `git diff` on it is
  empty — untouched this session. Nothing to decide.

### Post-change verification (re-run after every edit above)
`atd weave` → 0 files changed (graph already consistent). `atd lint` → **12** `Missing ## EXPECTATION`
+ **1** Traceability Gap — identical to the pre-change baseline, nothing new introduced. D11 invariant
re-confirmed across all 327 atoms: **0** atoms parent to a `contract_*`/`vision_*`; **0** CONTRACT/VISION
atoms carry parents or dependents.

### Pre-existing findings surfaced, deliberately NOT touched
`contract_upsilon_contract`'s empty `## EXPECTATION` (1 of 12 repo-wide `Missing ## EXPECTATION` lint
findings, all pre-existing); 4 pre-existing orphaned-STABLE atoms per `atd crawl --gaps`; malformed YAML
frontmatter (`priority=5` instead of `priority: 5`) in `upsilonbattle/docs/mechanic_weapon_as_skill_system.atom.md`;
one unqualified `[[entity_grid]]` ref in `upsilonbattle/battlearena/ruler/rules/attack_checks.go:46`.

### Task #7 — COMMITTED 2026-08-06 (NOT PUSHED)

All 12 submodules committed first, then the umbrella with the pointer bumps. The ATD structural
integrity pre-commit check ran and **passed** on every submodule that carries it. `go build ./...`
green on all five submodules with source changes (upsilonapi, upsilonbattle, upsilonhub,
upsilonmapdata, upsilontools) immediately before committing.

| repo | sha | subject |
|---|---|---|
| upsilonapi | dc9f783 | detach contract/vision, retire rule_dto_strict_typing |
| upsilonauth | e52fc00 | detach contract/vision, add identity account lifecycle requirement |
| upsilonbattle | cedfba4 | detach contract/vision, retire rule_ruler_test_robustness |
| upsilonbattleui | ade8fb2 | detach contract/vision, promote ui_game_selection to REVIEW |
| upsiloncli | b6ee55c | detach contract/vision from the atom graph |
| upsiloneconomy | 2b1622c | detach contract/vision, add wallet/ledger core requirement |
| upsilonhub | 8543cb6 | split skills.go by concern (ISS-126); detach contract/vision |
| upsilonmapdata | 0e082af | consolidate entity_mapdata_3d_grid into entity_grid |
| upsilonmapmaker | 7ba29ce | detach contract/vision, re-parent seed determinism rule |
| upsilonplatform | 5acdaf8 | detach contract/vision, correct ATD density wording |
| upsilontools | 03236d1 | detach contract/vision, retire requirement_observability_logging |
| upsilontypes | fba5902 | detach contract/vision, re-parent orphaned mechanics |
| **umbrella** | see git log | ATD graph surgery + code-health tooling + docs + issues + pointer bumps |

## Status: done (uncommitted work: none) — **NOTHING PUSHED. Push is a separate ask.**

### If picking this up cold, the live follow-ups are
- **ISS-124** stays Open until Bastien confirms the enroll flow in the web UI; the three W1 atoms sit
  at REVIEW and only move to STABLE after that.
- **ISS-127 / ISS-128 / ISS-129** filed this session, all Open, none fixed. ISS-129 is blocking in the
  sense that its rule contradiction (CODING_RULE.md §1 vs .agent/rules/ATD.md §252) must be settled
  before anyone cleans up the ~60 header-placed links.
- **1 traceability gap repo-wide**: `mechanic_battle_engine_stress_testing` has a `@spec-link` but no
  `@test-link`. Now the only one, so it is cheap to close.
- **12 pre-existing `Missing ## EXPECTATION` lint findings**, including on `contract_upsilon_contract`
  itself. Untouched all session; not introduced here.
- Malformed YAML frontmatter (`priority=5` instead of `priority: 5`) in
  `upsilonbattle/docs/mechanic_weapon_as_skill_system.atom.md`; 4 pre-existing orphaned-STABLE atoms
  per `atd crawl --gaps`.
