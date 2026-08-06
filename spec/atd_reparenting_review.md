# ATD Re-Parenting Review — CONTRACT/VISION Parent Removal

**Trigger:** Bastien's ruling that CONTRACT and VISION atoms must carry no `parents:`/`dependents:` — they are
guard/reference artifacts (breaking-change check / scope-drift check), not nodes in the traceability graph.
Removing the 25 `contract_*`/`vision_*` parent links leaves the 25 atoms below without a BUSINESS-layer
ancestor, which `ATD.md` §3.1 ("No Parent, No Code") requires.

**Scope of this document:** review only. No `.atom.md` file was modified to produce it — see "Verification" at
the bottom for a `git status` confirmation. Everything under "Suggested parent" / "Proposed ruling" is a
proposal for Bastien to confirm; nothing has been applied via `atd update`.

---

## Summary

| Ruling | Count |
|---|---|
| `RE-PARENT-EXISTING` | 15 |
| `NEEDS-NEW-BUSINESS-ATOM` | 7 (collapsing to **2 distinct new atoms**, each shared by several children) |
| `RECLASSIFY` | 2 |
| `ESCALATE` | 1 |
| `RETIRE` | 0 (one *adjacent* retire candidate surfaced as a side-finding, not one of the 25 — see upsilonmapdata section) |
| **Total atoms reviewed** | **25** |

**New BUSINESS atoms proposed (2 total, both DRAFT, both pending Bastien's sign-off):**
1. `requirement_identity_account_lifecycle` (upsilonauth) — parent for `mech_account_push`, `mech_service_registrations`, `mech_token_introspection`.
2. `requirement_economy_wallet_ledger_core` (upsiloneconomy) — parent for `mechanic_award_idempotency`, `mechanic_gdpr_purge`, `mechanic_purchase_transaction`, `mechanic_wallet_lazy_create`.

**Needs Bastien's sign-off regardless of ruling** (touching a BUSINESS-layer atom, or a STABLE atom, is never this
agent's call to make unilaterally):

- **STABLE atoms in this batch (5 — flagged prominently in their table rows below):** `rule_ruler_test_robustness`,
  `entity_grid`, `rule_mapmaker_seed_determinism`, `requirement_observability_logging`, `mech_entity_properties`.
  Of these, `rule_mapmaker_seed_determinism` and `requirement_observability_logging` are **also BUSINESS-layer**,
  so they trip the CLI's STABLE+BUSINESS `--force` guard directly — that guard should not be bypassed without
  Bastien's explicit word.
- **DRAFT BUSINESS-layer atoms being re-parented** (`rule_api_bridge_orchestration`, `rule_mapdata_grid_standard`,
  `rule_mapmaker_board_generation_constraints`): not STABLE, so no CLI guard fires, but any BUSINESS-layer edit
  still needs explicit sign-off per lifecycle discipline.
- Both new-atom proposals (identity, economy) — DRAFT is the ceiling; nothing self-promotes.
- The `rule_ruler_test_robustness` ESCALATE — see its row for the precise question.
- The `entity_grid` / `entity_mapdata_3d_grid` apparent duplication (upsilonmapdata section) — a side-finding,
  not part of the 25, but worth a decision.

---

## Type/name mismatches encountered (separate from the parenting question)

These don't change the "does it have a parent" problem directly, but several of them change *what kind* of
parent is correct, so they're called out before the table:

- **`module_skill_sandbox`** — `id`/`human_name` say "module"/"sandbox", but `type: MECHANIC`, `layer:
  IMPLEMENTATION`. Its actual content (a fluent test-harness builder over `GameState`) is testing
  infrastructure, not a game mechanic. Ruled `RECLASSIFY` below (→ `type: MODULE`, `layer: ARCHITECTURE`).
- **`mech_entity_properties`** — `id` uses the `mech_` shorthand but `type: MODULE`. The *type* is actually
  correct for its content (an aggregator over two child property atoms); the `id` just doesn't follow the
  `<type>_<slug>` naming convention (should read `module_entity_properties`). Flagged for a cosmetic rename,
  not a `RECLASSIFY`.
- **`rule_api_bridge_orchestration`** — `layer: BUSINESS`, while every sibling `RULE` atom in this batch
  (`rule_code_health_monitoring`, `rule_dto_strict_typing`, `rule_ruler_test_robustness`, `rule_item_pricing_simple`)
  is `layer: ARCHITECTURE`. Its content (ruler registry, HTTP-to-engine request proxying, webhook event
  forwarding) reads as architecture, not business policy. Ruled `RECLASSIFY` below.
- **`mechanic_award_idempotency` / `mechanic_gdpr_purge` / `mechanic_purchase_transaction` /
  `mechanic_wallet_lazy_create`** (upsiloneconomy) spell out `mechanic_` in full, while
  **`mech_account_push` / `mech_service_registrations` / `mech_token_introspection`** (upsilonauth) and several
  `upsilontypes`/`upsilonbattle` atoms abbreviate to `mech_` — both are `type: MECHANIC`. This is a project-level
  naming-convention drift (not one this review's ruling changes), noted for a future lint pass.

---

## upsilonauth

No BUSINESS-layer atom exists in this project besides `contract_auth_service` and `vision_auth` — both excluded
as parent targets. All three atoms below are genuine, load-bearing identity mechanics (not "no direct user
story" infra), so the tech-debt escape hatch would be the wrong home; they need a real new BUSINESS atom. Note
also: unlike every other submodule in this batch, **upsilonauth has no `req_tech_debt_backlog` atom at all** —
a separate, smaller gap worth noting to whoever last ran `atd init`/`atd init --upgrade` here.

| Atom | Type / Layer / Status | Current parent | Intent (concise) | Suggested parent | Proposed ruling |
|---|---|---|---|---|---|
| `mech_account_push` | MECHANIC / IMPLEMENTATION / DRAFT | `[[contract_auth_service]]` | Durably propagate every account-lifecycle mutation (create/rename/soft-delete/anonymize) to the hub's denormalized identity columns via a River job, idempotent by construction. | `[[requirement_identity_account_lifecycle]]` (new) | `NEEDS-NEW-BUSINESS-ATOM` — see proposal below; shared by all three upsilonauth atoms. |
| `mech_service_registrations` | MECHANIC / IMPLEMENTATION / DRAFT | `[[contract_auth_service]]` | Record, per account, which platform services (games) it has enrolled in, so login/lookup/introspection can answer "what can this account do" without cross-service queries; auth never initiates enrollment, only records it. | `[[requirement_identity_account_lifecycle]]` (new) | `NEEDS-NEW-BUSINESS-ATOM` — same proposal. |
| `mech_token_introspection` | MECHANIC / IMPLEMENTATION / DRAFT | `[[contract_auth_service]]` | Resolve one bearer plaintext to its live principal at the trust seam, performing sliding renewal in the same step, so every consumer authenticates against auth's judgment alone. | `[[requirement_identity_account_lifecycle]]` (new) | `NEEDS-NEW-BUSINESS-ATOM` — same proposal. |

**Proposed new atom:**
- `id: requirement_identity_account_lifecycle`
- `human_name: "Identity, Session & Enrollment Authority"`
- `type: REQUIREMENT`, `layer: BUSINESS`, `status: DRAFT`
- **INTENT draft:** "Auth is the platform's single, authoritative source of identity: it durably propagates
  every account-lifecycle mutation to the services that denormalize identity data, resolves and renews bearer
  tokens at one trust seam, and records — but never initiates — each account's per-game service enrollment. No
  other service maintains its own copy of who a user is, whether their session is currently valid, or which
  games they've joined."
- This directly restates `vision_auth`'s own "Identity is a substrate, not a feature" commitment as a concrete,
  settled BUSINESS-layer rule rather than a vision statement — it is not a manufactured placeholder; all three
  mechanics genuinely implement exactly this claim and nothing else currently states it as a rule.

---

## upsiloneconomy

Same shape as upsilonauth: only `contract_economy_service`/`vision_economy` exist in-project, both excluded.
All four atoms are core wallet/ledger mechanics — real business logic, not infra debt — so, again, a new
BUSINESS atom is warranted rather than the tech-debt anchor. **upsiloneconomy also has no
`req_tech_debt_backlog` atom**, same gap as upsilonauth.

| Atom | Type / Layer / Status | Current parent | Intent (concise) | Suggested parent | Proposed ruling |
|---|---|---|---|---|---|
| `mechanic_award_idempotency` | MECHANIC / IMPLEMENTATION / **REVIEW** | `[[contract_economy_service]]` | Give durable-retry callers (outbox/job queue) an exactly-once credit grant via an idempotency-key-guarded ledger insert, without the caller needing to deduplicate itself. | `[[requirement_economy_wallet_ledger_core]]` (new) | `NEEDS-NEW-BUSINESS-ATOM` — see proposal below; shared by all four upsiloneconomy atoms. |
| `mechanic_gdpr_purge` | MECHANIC / IMPLEMENTATION / **REVIEW** | `[[contract_economy_service]]` | Let auth's account-termination fan-out zero a user's wallet exactly once, however many times the durable job retries the call; the wallet row itself is never deleted (audit trail). | `[[requirement_economy_wallet_ledger_core]]` (new) | `NEEDS-NEW-BUSINESS-ATOM` — same proposal. |
| `mechanic_purchase_transaction` | MECHANIC / IMPLEMENTATION / **REVIEW** | `[[contract_economy_service]]` | Buy N units of a catalog item for a player as one all-or-nothing transaction (lock wallet → validate item/stock/cap/balance → debit → upsert inventory → write both ledgers), wholly inside this service's own database. | `[[requirement_economy_wallet_ledger_core]]` (new) | `NEEDS-NEW-BUSINESS-ATOM` — same proposal. |
| `mechanic_wallet_lazy_create` | MECHANIC / IMPLEMENTATION / **REVIEW** | `[[contract_economy_service]]` | Guarantee a wallet read or mutation never fails for a live user UUID (lazy-create at default balance), while every mutating path still serializes through a row lock. | `[[requirement_economy_wallet_ledger_core]]` (new) | `NEEDS-NEW-BUSINESS-ATOM` — same proposal. |

**Proposed new atom:**
- `id: requirement_economy_wallet_ledger_core`
- `human_name: "Wallet & Ledger Core Guarantees"`
- `type: REQUIREMENT`, `layer: BUSINESS`, `status: DRAFT`
- **INTENT draft:** "Every account holds exactly one economy-service-owned credit wallet, and every
  balance-changing action — awarding credits, purchasing a shop item, or closing a wallet on account deletion —
  is recorded as an idempotent, append-only ledger transaction applied at most once per idempotency key. The
  wallet and its ledger are the platform's single source of truth for a user's spendable credits and purchase
  history, so no other service computes or stores its own copy of a balance."
- Directly restates `vision_economy`'s "one currency and one inventory truth... the append-only ledgers are the
  platform's economic history" as a settled rule. All four REVIEW-status mechanics are concrete implementations
  of exactly this guarantee, which is currently unstated anywhere at BUSINESS layer in this project.

All four of these atoms are `REVIEW` (closer to promotion than most of this batch) — re-parenting them promptly
matters more here than elsewhere, since a REVIEW→STABLE promotion decision shouldn't happen while they're
floating without a real BUSINESS ancestor.

---

## upsilonbattle

| Atom | Type / Layer / Status | Current parent | Intent (concise) | Suggested parent | Proposed ruling |
|---|---|---|---|---|---|
| `mech_movement_reposition` | MECHANIC / IMPLEMENTATION / DRAFT | `[[contract_battle_contract]]` | Let skills displace a subject (caster or target) along the casting ray, with the defining trait that tiles flown over don't fire positional effects — only the landing tile does. | `[[upsilonapi:domain_skill_system]]` | `RE-PARENT-EXISTING` — `domain_skill_system`'s own INTENT ("Effect Computing: what property computations the Ruler should trigger", targeting mechanisms) is exactly the domain reposition belongs to; this cross-project pattern (`upsilonbattle:* → upsilonapi:domain_skill_system`) is already established elsewhere (e.g. `upsilonbattle:rule_credit_earning → upsilonapi:domain_credit_economy`). |
| `module_skill_sandbox` | **MECHANIC** (id says "module") / IMPLEMENTATION / DRAFT | `[[contract_battle_contract]]` | Provide a deterministic, service-free fluent-builder harness (`battletest.Scenario`) for driving the battle engine in unit tests, replacing ad-hoc per-package test helpers. | `[[req_tech_debt_backlog]]` (upsilonbattle's own) | `RECLASSIFY` — this is pure test tooling, not a game mechanic: retype to `MODULE`, relayer to `ARCHITECTURE`. Once reclassified, it fits the tech-debt anchor's own stated "acceptable scenario: infrastructure atoms with no direct user story" precisely — it has no business rationale of its own, only a supporting one to the mechanics it tests. This is the sanctioned escape hatch, not a manufactured parent. |
| `rule_ruler_test_robustness` | RULE / ARCHITECTURE / **STABLE** ⚠ | `[[shared:contract_upsilon_contract]]` | Prevent flaky tests when validating Ruler logic with multi-controller scenarios and randomized initiative (don't assume controller order; watch all inboxes). | *(unresolved — see ruling)* | `ESCALATE` — same "infrastructure atom, no user story" shape as `module_skill_sandbox` above, and `req_tech_debt_backlog` would be the mechanically honest fallback. But that anchor's own text says atoms parented there "must be groomed... during scheduled tech-debt cycles" — language written for atoms *awaiting* real classification, not for a rule that is already `STABLE` and permanently enforced. Filing a STABLE, deliberately-permanent engineering rule under a nominally-temporary anchor is a real category mismatch. **Question for Bastien:** should `req_tech_debt_backlog` be used anyway (accepting the semantic mismatch), or does ATD need a second, permanent "engineering governance" anchor for STABLE rules like this one and `rule_code_health_monitoring` that have no business rationale but also aren't debt to be groomed away? |

---

## upsilonapi

| Atom | Type / Layer / Status | Current parent | Intent (concise) | Suggested parent | Proposed ruling |
|---|---|---|---|---|---|
| `rule_api_bridge_orchestration` | RULE / **BUSINESS** / DRAFT | `[[contract_api_contract]]` | Define the orchestration logic bridging HTTP requests to the battle engine: maintain a ruler registry, proxy JSON payloads into engine commands, forward engine events to registered webhooks. | `[[domain_upsilon_engine]]` (same project) | `RECLASSIFY` — content is architecture (registry/proxying/event-forwarding mechanics), not business policy, and its `layer: BUSINESS` is the one outlier among this batch's `RULE` atoms (siblings are all `ARCHITECTURE`). Relayer to `ARCHITECTURE`. Its content also **substantially overlaps** `domain_upsilon_engine`'s own INTENT ("engine accepts independent client Controllers... each controller drives one participant through the exposed battle-rule surface") — worth Bastien confirming these are genuinely two atoms and not a near-duplicate pair before re-parenting. If they stay distinct, `domain_upsilon_engine` is the correct same-layer, same-project parent. |

*(`rule_api_bridge_orchestration` is the only upsilonapi atom in the 25; `domain_upsilon_engine` and
`domain_skill_system`/`domain_credit_economy` referenced throughout this document already exist in
`upsilonapi/docs/` and are read-only reference points here, not touched.)*

---

## upsilonmapdata

| Atom | Type / Layer / Status | Current parent | Intent (concise) | Suggested parent | Proposed ruling |
|---|---|---|---|---|---|
| `entity_grid` | ENTITY / ARCHITECTURE / **STABLE** ⚠ | `[[contract_mapdata_contract]]` | Manage a 3D spatial collection of cells, with utilities for navigation (A\*), entity placement/movement, and vertical layout (top/lowest ground lookups), plus boundary validation. | `[[rule_mapdata_grid_standard]]` (same project) | `RE-PARENT-EXISTING` — `rule_mapdata_grid_standard` is the in-project BUSINESS rule mandating exactly the structural properties (Width/Length/Height, cell mapping, verticality, obstacle distinction) this entity implements; its sibling atom `entity_mapdata_3d_grid` *already* correctly parents there. **Side-finding (not one of the 25, flagged anyway):** `entity_mapdata_3d_grid` (DRAFT, zero dependents) describes the same `Width/Length/Height` + `Cells` map structure as `entity_grid` (STABLE, has a real dependent `mechanic_multi_entity_cell_system`), just far less completely. This looks like a stale duplicate of `entity_grid` rather than a distinct atom — worth a `RETIRE` decision on `entity_mapdata_3d_grid` in its own pass, separate from this reparenting exercise. |
| `rule_mapdata_grid_standard` | RULE / **BUSINESS** / DRAFT | `[[contract_mapdata_contract]]` | Define the mandatory structural properties for tactical grids in Upsilon: explicit Width/Length/Height, unique cell-per-coordinate mapping, multi-layer verticality, and walkable/obstacle distinction. | `[[shared:req_trpg_game_definition]]` | `RE-PARENT-EXISTING` — this rule is itself the top-of-project BUSINESS atom (nothing else in `upsilonmapdata/docs/` outranks it besides the excluded contract/vision), so its parent must come from the root. `req_trpg_game_definition`'s own text ("Board: A procedurally generated rectangular grid... with obstacle tiles") states the exact same grid concept this rule specifies structurally — a genuine fit, not an invented one. |

---

## upsilonmapmaker

| Atom | Type / Layer / Status | Current parent | Intent (concise) | Suggested parent | Proposed ruling |
|---|---|---|---|---|---|
| `rule_mapmaker_board_generation_constraints` | RULE / BUSINESS / DRAFT | `[[contract_mapmaker_contract]]` | Ensure generated maps are tactical and manageable within engine performance limits: 5–15 tile dimension, ≥50 walkable tiles, ≤10% obstacle density, at least one ground level. | `[[shared:req_trpg_game_definition]]` | `RE-PARENT-EXISTING` — the "5-15 tiles per side" board-size figure in `req_trpg_game_definition` is the literal source of this rule's own size bound; this is close to a direct implementation, not a stretch. |
| `rule_mapmaker_seed_determinism` | RULE / BUSINESS / **STABLE** ⚠ | `[[contract_mapmaker_contract]]` | Ensure procedural map generation is perfectly deterministic given a specific seed — every random choice derives from the seed, same seed ⇒ bit-identical grids. | `[[shared:req_trpg_game_definition]]` | `RE-PARENT-EXISTING` — like `rule_mapdata_grid_standard` above, this is the top-of-project BUSINESS atom with nowhere in-project to parent to; `req_trpg_game_definition`'s "procedurally generated" board is the umbrella requirement this rule's determinism property specializes. (Its own child, `mechanic_mapmaker_seed_determinism`, is *already* correctly parented here — this row just closes the same gap one level up.) STABLE + BUSINESS: sign-off and the CLI's own guard both apply. |

---

## upsilontools

Three of the four atoms here are the most severe case in this batch: root `[[shared:vision_upsilon_vision]]` was
their *only* link, skipping both the project's own BUSINESS layer and its ARCHITECTURE layer entirely — a
two-layer skip straight to the platform-wide VISION atom.

| Atom | Type / Layer / Status | Current parent | Intent (concise) | Suggested parent | Proposed ruling |
|---|---|---|---|---|---|
| `mechanic_math_core_utils` | MECHANIC / IMPLEMENTATION / DRAFT | `[[shared:vision_upsilon_vision]]` ⚠ **2-layer skip** | Provide fundamental reusable math operations (Abs/AbsFloat, Min/Max, LinearProgressionAt) for consistency across the engine. | `[[req_tech_debt_backlog]]` (upsilontools's own) | `RE-PARENT-EXISTING` — a generic math-utility library has no business rationale of its own; this is the tech-debt anchor's own "infrastructure atom, no direct user story" case, used honestly rather than manufacturing a fake "business" reason for `Min`/`Max`. |
| `mechanic_randomization_helpers` | MECHANIC / IMPLEMENTATION / DRAFT | `[[shared:vision_upsilon_vision]]` ⚠ **2-layer skip** | Provide a centralized interface for deterministic (seeded) and non-deterministic random number generation, with a test-injectable RNG. | `[[req_tech_debt_backlog]]` (upsilontools's own) | `RE-PARENT-EXISTING` — same reasoning as above. |
| `mechanic_spatial_distance_calculations` | MECHANIC / IMPLEMENTATION / DRAFT | `[[shared:vision_upsilon_vision]]` ⚠ **2-layer skip** | Provide standardized Manhattan-distance calculations in 2D and 3D, for both integer and float coordinates. | `[[req_tech_debt_backlog]]` (upsilontools's own) | `RE-PARENT-EXISTING` — same reasoning as above. |
| `requirement_observability_logging` | REQUIREMENT / BUSINESS / **STABLE** ⚠ | `[[contract_tools_contract]]` | Ensure uniform observability across all Upsilon services via a standardized, centralized logging interface (console + JSON file output, contextual sub-loggers for concurrent traceability). | `[[shared:req_logging_traceability]]` | `RE-PARENT-EXISTING` — root's `req_logging_traceability` ("guarantee every log entry maps back to the specific request... zero-gap observability") is the platform-wide requirement this atom's shared logging *library* exists to serve; a strong, non-manufactured fit. **Additional finding, independent of parenting:** this atom's own `## TECHNICAL INTERFACE` and `## EXPECTATION` sections are both empty — it fails the atom-completeness bar regardless of the parent question. Worth a follow-up pass once re-parented. STABLE + BUSINESS: sign-off and the CLI guard both apply. |

*(Note: the math/random/distance atoms above deliberately do **not** consolidate into one new BUSINESS
requirement — per the trap warned against in the brief, three unrelated utility grab-bags don't share one real
business reason to exist together; `req_tech_debt_backlog`, used correctly per its own stated scope, is the
honest answer rather than manufacturing an umbrella "utilities" business atom that traces nothing.)*

---

## upsilontypes

No BUSINESS-layer atom exists in this project besides `contract_types_contract`/`vision_types_vision`. Rather
than invent new BUSINESS atoms here, every atom below has a genuine cross-project fit in `upsilonapi`'s existing
`domain_skill_system` or `domain_credit_economy` — both DOMAIN/BUSINESS atoms already established as legitimate
cross-project parents for `upsilontypes` content (e.g. `upsilontypes:entity_shop_item` already parents to
`[[upsilonapi:domain_credit_economy]]`, and `upsilontypes:rule_character_skill_slots` already parents
cross-project to `upsilonapi`). `domain_skill_system` currently has **zero** real dependents (`dependents: []`
in its own frontmatter) despite existing specifically to govern this kind of content — these four atoms are
the fit it was seemingly created for but never wired to.

| Atom | Type / Layer / Status | Current parent | Intent (concise) | Suggested parent | Proposed ruling |
|---|---|---|---|---|---|
| `mechanic_effect_caster_tracking` | MECHANIC / IMPLEMENTATION / DRAFT | `[[contract_types_contract]]` | Every combat effect remembers its original caster (`CasterID`) until the effect ends, for credit attribution, interruption mechanics, and support-play credit earning; a per-effect flag controls whether it expires with its caster. | `[[upsilonapi:domain_credit_economy]]` | `RE-PARENT-EXISTING` — the atom's own "Credit and Economic Attribution" section (damage/heal/shield credits routed to `CasterID`, including post-mortem attribution) is a direct, explicit implementation of `domain_credit_economy`'s credit-sources rules ("Damage Dealing: 1 HP = 1 credit", "Status Effects: SkillWeight/10 credits", etc.). Note: this atom's own `## EXPECTATION` section is empty — a completeness gap independent of parenting. |
| `mech_positional_effects` | MECHANIC / IMPLEMENTATION / DRAFT | `[[contract_types_contract]]` | Attach effects to grid positions instead of entities (zones, traps, terrain modifiers) that persist independent of any character, with a full creation/removal/caster-death-cleanup lifecycle. | `[[upsilonapi:domain_skill_system]]` | `RE-PARENT-EXISTING` — `domain_skill_system`'s own "Effect Computing" and AoE/targeting language is exactly the domain positional effects belong to. Note: this atom's own `## EXPECTATION` section is also empty. |
| `mech_entity_properties` | **MODULE** / ARCHITECTURE / **STABLE** ⚠ | `[[contract_types_contract]]` | Aggregate the constituent property-declaration rules for both Items and Skills in the game engine (parent of `mech_entity_properties_item_properties` and `mech_entity_properties_skill_properties`). | `[[upsilonapi:domain_skill_system]]` **and** `[[upsilonapi:domain_credit_economy]]` (multi-parent) | `RE-PARENT-EXISTING` — this atom aggregates two genuinely different domains (skill properties, item properties); a single parent would misrepresent it as belonging to only one. Both target domains already have established precedent as parents for `upsilontypes` content. STABLE — sign-off required before any multi-parent edit; remember `--set '"parents=[[upsilonapi:domain_skill_system]],[[upsilonapi:domain_credit_economy]]"'`-style quoting if this is ever applied, so the CSV `--set` parser doesn't silently drop the second parent. Separately: `id` doesn't follow the naming convention for its own `type: MODULE` (should read `module_entity_properties`, not `mech_entity_properties`) — a cosmetic rename to raise alongside the sign-off, not a `RECLASSIFY` (the type itself is already correct). |
| `rule_item_pricing_simple` | RULE / ARCHITECTURE / DRAFT | `[[contract_types_contract]]` | Establish a simple fixed-credit pricing model for shop items in the V2 testing phase (Armor 200 / Weapon 300 / Movement 150 / Utility 100), by item type rather than the full Skill Weight system, plus purchase validation rules. | `[[upsilonapi:domain_credit_economy]]` | `RE-PARENT-EXISTING` — same pattern already used by `upsilontypes:entity_shop_item`, which parents directly to `domain_credit_economy`; item pricing is squarely inside that domain's existing scope ("spend them on skills and equipment"). |

---

## Root (`/docs`)

| Atom | Type / Layer / Status | Current parent | Intent (concise) | Suggested parent | Proposed ruling |
|---|---|---|---|---|---|
| `rule_code_health_monitoring` | RULE / ARCHITECTURE / DRAFT | `[[contract_upsilon_contract]]` | Enforce codebase maintainability limits — file LOC, function nesting depth, documentation coverage, and ATD-link density/validity — as a pre-commit gate (`code_health_check.py`). | `[[req_tech_debt_backlog]]` | `RE-PARENT-EXISTING` — this is a pure engineering-governance rule (linting thresholds) with no user-facing business rationale to trace to; manufacturing one would be exactly the dishonest move the brief warns against. `req_tech_debt_backlog`'s own scope ("infrastructure atoms with no direct user story") is a genuine, sanctioned fit, and this atom is still `DRAFT`, so there's no STABLE/temporary-anchor tension here (contrast with `rule_ruler_test_robustness` above). |
| `rule_dto_strict_typing` | RULE / ARCHITECTURE / DRAFT | `[[contract_upsilon_contract]]` | Forbid `any`/`interface{}` in DTOs; every field must have a concrete type, with custom strict unmarshalers where an external system's JSON is inconsistent. | `[[requirement_customer_api_first]]` | `RE-PARENT-EXISTING` — unlike `rule_code_health_monitoring`, this one has a real business tie: `requirement_customer_api_first`'s own commitment to a "self-documenting", "fully playable via API" surface depends on the API actually being predictably and strongly typed for third-party consumers — that's the business reason strict typing exists, not just internal taste. |

---

## Verification

No `.atom.md` file was modified, and no `atd update`/`atd weave`/mutating command was run while producing this
review — confirmed via `git status --porcelain`:

```
 M CLAUDE.md
 M CODING_RULE.md
 M README.md
 M TODO.md
 M docs/rule_code_health_monitoring.atom.md
 M issues/ISS-126_20260804_skills_go_atd_link_cap.md
 M issues/README.md
 M scripts/code_health_check.py
 M upsilonhub
?? issues/ISS-127_20260805_user_flows_spec_atd_link_cap.md
?? spec/atd_reparenting_review.md
```

The only `.atom.md` entry (`docs/rule_code_health_monitoring.atom.md`) was already modified in the working tree
**before this session started** (it was present in the git status snapshot at the top of this conversation) —
this review only ever `Read` that file, never `Edit`/`Write`d it; `git diff -- docs/rule_code_health_monitoring.atom.md`
shows exactly one pre-existing one-line insertion (a "Counting basis" clarification clause), unrelated to and
untouched by this parenting review. Every other line above (CLAUDE.md, CODING_RULE.md, README.md, TODO.md, the
two `issues/` files, `scripts/code_health_check.py`, the `upsilonhub` submodule pointer) is likewise pre-existing,
unrelated working-tree state — none of it touched by this task. The only new artifact this task produced is
`spec/atd_reparenting_review.md` itself (`??`, untracked) — a plain markdown note, not an atom, so it required
no `atd` operation to create.
