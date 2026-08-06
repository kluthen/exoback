# Issues

> **Index reconciled 2026-06-19**: all `Resolved` issues (and the now-orphaned
> `ISS-054_investigation_report.md` companion doc) were deleted from this directory
> as part of a cleanup pass — this index now tracks **open issues only**. The
> project-root `README.md` carries an auto-generated table of active issues via
> `issues --update-readme`; **this file is maintained by hand**.

## Open / Active

| Ref | File | Severity | Status | Summary |
|---|---|---|---|---|
| ISS-129 | [ISS-129_20260806_atd_link_placement_file_headers.md](ISS-129_20260806_atd_link_placement_file_headers.md) | Medium | Open | ~60 Go files place `@spec-link`/`@test-link` in the file header instead of atop the function/type — but `CODING_RULE.md` §1 (absolute ban) and `.agent/rules/ATD.md` §252 (ban *unless* the atom covers the file's entire architectural pattern) **contradict each other**, so 60 is an upper bound, not a violation count; resolve the rule conflict first, then re-scan. Root cause behind the ISS-126/ISS-127 link-cap breaches |
| ISS-128 | [ISS-128_20260806_lint_ignore_naive_substring_match.md](ISS-128_20260806_lint_ignore_naive_substring_match.md) | Medium | Open | `code_health_check.py` matches `@lint-ignore-*` by naive whole-file substring, so any file merely *mentioning* a tag silently disables that check on itself — the checker currently skips its own source this way; anchor the match to comment lines and re-baseline |
| ISS-127 | [ISS-127_20260805_user_flows_spec_atd_link_cap.md](ISS-127_20260805_user_flows_spec_atd_link_cap.md) | Medium | Open | `tests/playwright/user_flows.spec.ts` carries 13 ATD link occurrences against the 10 cap (12 distinct atoms), pre-existing (not caused by commit `8a95229`); split the spec along flow boundaries rather than delete links |
| ISS-126 | [ISS-126_20260804_skills_go_atd_link_cap.md](ISS-126_20260804_skills_go_atd_link_cap.md) | Medium | Resolved | `gateway/skills.go` carried 12 ATD link occurrences against the 10 cap (5 distinct atoms) and conflated three concerns — template catalogue / skill inventory / roll-progression; split into `skill_templates.go` / `skill_inventory.go` / `skill_roll.go`, independently verified (link set 12→12 identical, routes byte-identical, tests 11→11 identical set) |
| ISS-125 | [ISS-125_20260801_registration_requires_address_birthdate.md](ISS-125_20260801_registration_requires_address_birthdate.md) | Medium | Open | Registration mandates `full_address` + `birth_date`, neither of which gameplay needs — deliberate scope reduction, but codified in a STABLE architecture atom so it needs a documented ATD change, not just a code edit |
| ISS-124 | [ISS-124_20260801_new_account_dashboard_empty_roster.md](ISS-124_20260801_new_account_dashboard_empty_roster.md) | High | Open | New account shows 0 characters — the SPA never called `POST /api/v1/battle/enroll`. Fix landed 2026-08-04 (game-selection page + catalog endpoint + router gate, CI-verified); awaiting user confirmation in the web UI before closing |
| ISS-123 | [ISS-123_20260724_host_side_ci_seed_scripts_superseded.md](ISS-123_20260724_host_side_ci_seed_scripts_superseded.md) | Medium | Open | Host-side seed/trigger scripts (seed_ci.sh + callers) assume a single hub-owned DB and expect `hub -seed` to seed accounts/catalog — false since the auth/economy extraction; superseded by the 6-image docker-compose CI stack. Retire or re-cut for multi-service |
| ISS-122 | [ISS-122_20260723_battleui_profile_requires_enrollment_guard.md](ISS-122_20260723_battleui_profile_requires_enrollment_guard.md) | Medium | Open | battleui reads /api/v1/profile after login without enrolling — now 404s under the game-agnostic model; SPA must enroll-on-entry or guard the 404 (part of battleui's pending phase-4 auth adaptation) |
| ISS-121 | [ISS-121_20260723_baseline_player_stats_not_idempotent.md](ISS-121_20260723_baseline_player_stats_not_idempotent.md) | High | Resolved | Migration 000004_player_stats's CREATE TABLE has no IF NOT EXISTS — database.Baseline() replaying migrations against an already-migrated DB fails outright; breaks TestBaselineAdoptsLaravelMigratedDatabase and any retried Phase-4 cutover deploy |
| ISS-120 | [ISS-120_20260722_internal_request_id_mandatory.md](ISS-120_20260722_internal_request_id_mandatory.md) | High | Open | Internal S2S calls ship an empty request_id — the hub never propagates its inbound X-Request-ID into httpx and durable jobs mint none; correlation id is mandatory (adopt-then-propagate, mint at origin). Gate before Phase-4 internal chains |
| ISS-119 | [Ref_20260722_match_start_race_local_env.md](Ref_20260722_match_start_race_local_env.md) | Low | Open | Four match-resolution E2E scenarios act on match.found before the engine's async game-start lands — deterministic local failure (pre-existing, verified on pristine pre-session tree), unobserved on CI runners |
| ISS-118 | [Ref_20260722_gdpr_export_per_game_gap.md](Ref_20260722_gdpr_export_per_game_gap.md) | Medium | Open | Game-agnostic accounts remodel narrows auth's GDPR export to account+registrations; per-game export fragments needed before the Phase-4 cutover leaves data portability incomplete |
| ISS-117 | [Ref_20260722_upsilonapi_dependabot_vulns.md](Ref_20260722_upsilonapi_dependabot_vulns.md) | High | Open | GitHub reports 15 Dependabot vulnerabilities (7 critical) on upsilonapi's default branch; no process surfaces alerts — triage, bump, and add govulncheck to CI |
| ISS-107 | [ISS-107_20260709_edge_case_scenario_suite_audit.md](ISS-107_20260709_edge_case_scenario_suite_audit.md) | Medium | Open | Audit the upsiloncli edge-case scenario suite — it's the scenarios (stale assertions, randomness, timing: ISS-102/103/105 + friendly-fire), not the mechanics, that redden CI; classify/disposition each and decide the edge-step CI policy |
| ISS-106 | [ISS-106_20260709_php_empty_array_skill_payload_start_failure.md](ISS-106_20260709_php_empty_array_skill_payload_start_failure.md) | Low | Open | Data half (PHP-era `[]` skill payloads 400 arena start) vanishes on the prod DB wipe; surviving half: hub `Join` answers `matched` even when engine-start fails, stranding the client on an arena-less match |
| ISS-105 | [ISS-105_20260709_cli_token_starvation_long_fights.md](ISS-105_20260709_cli_token_starvation_long_fights.md) | Low | Open | CLI scenarios idling > 15 min between requests 401 mid-fight (sliding renewal never engages; Sanctum never expired) — flakes `e2e_archetype_pve_full_fight` on long fights |
| ISS-104 | [ISS-104_20260708_matchmaking_parallel_join_queue_poison.md](ISS-104_20260708_matchmaking_parallel_join_queue_poison.md) | High | Open | Parallel matchmaking joins can strand a queue entry; the strand self-perpetuates, pairing every later 1v1_PVE joiner with the previous victim's match (403 on game state) |
| ISS-103 | [ISS-103_20260707_privacy_check_asserts_unimplemented_masking.md](ISS-103_20260707_privacy_check_asserts_unimplemented_masking.md) | Medium | Open | e2e_battle_starts_privacy_check asserts foe-loadout masking neither Laravel nor the hub ever implemented (ISS-077 contract) |
| ISS-102 | [ISS-102_20260707_forfeit_before_engine_start_window.md](ISS-102_20260707_forfeit_before_engine_start_window.md) | Medium | Open | Forfeit 400s (game.not.in.progress) in the engine's startup window right after match.found; hidden by Reverb latency, exposed by SSE |
| ISS-100 | [ISS-100_20260616_devcontainer_webgl_playwright_visual.md](ISS-100_20260616_devcontainer_webgl_playwright_visual.md) | Medium | Open | Devcontainer lost WebGL/SwiftShader; Playwright 3D visual specs can't render (env regression) |
| ISS-090 | [ISS-090_20260427_action_endpoint_segregation.md](ISS-090_20260427_action_endpoint_segregation.md) | Medium | Open | All tactical actions funneled through one endpoint; needs segregation |
| ISS-089 | [ISS-089_20260426_mechanic_random_shop_algorithm.md](ISS-089_20260426_mechanic_random_shop_algorithm.md) | Medium | Open | Deterministic daily rotating shop algorithm |
| ISS-087 | [ISS-087_20260426_grid_generator_tuning.md](ISS-087_20260426_grid_generator_tuning.md) | Medium | Open | Generated battle maps consistently mis-sized / mis-densified |
| ISS-082 | [ISS-082_20260425_frontend_playwright_test_seams.md](ISS-082_20260425_frontend_playwright_test_seams.md) | Medium | Open | Playwright HTML report now captured in CI; 2 specs fail + 2 hang (frontend, was tied to now-resolved ISS-084) |
| ISS-081 | [ISS-081_20260425_cross_stack_error_handling.md](ISS-081_20260425_cross_stack_error_handling.md) | Medium | Open | `error_key` only propagated on engine action paths; harmonize cross-stack |
| ISS-080 | [ISS-080_20260425_error_key_atd_and_envelope.md](ISS-080_20260425_error_key_atd_and_envelope.md) | Medium | Open | ATD for `error_key` taxonomy; possible promotion to envelope root |
| ISS-079 | [ISS-079_20260424_cell_access_y_major_standard.md](ISS-079_20260424_cell_access_y_major_standard.md) | Medium | Open | Standardize cell access on Y-major layout via shared helper |
| ISS-078 | [ISS-078_20260423_shielding_credit_attribution.md](ISS-078_20260423_shielding_credit_attribution.md) | Medium | Open | Robust credit attribution for damage mitigation (shield caster) |
| ISS-077 | [ISS-077_20260423_skill_inspection.md](ISS-077_20260423_skill_inspection.md) | Medium | Open | Skill inspection UI/CLI for detailed skill properties |
| ISS-072 | [ISS-072_20260423_pass_choose_facing.md](ISS-072_20260423_pass_choose_facing.md) | Medium | Open | "Pass" action should let player choose facing (anti-backstab) |
| ISS-055 | [ISS-055_20260420_actor_message_validation.md](ISS-055_20260420_actor_message_validation.md) | Low | Open | Actor should validate target message type |
| ISS-049 | [ISS-049_20260418_actor_generics_modernization.md](ISS-049_20260418_actor_generics_modernization.md) | Low | Open | Modernize actor library with Go generics |

---

### Index integrity notes (2026-06-19 cleanup, round 2)
- Additional issues closed and deleted: ISS-023, 036, 039, 040, 042, 083, 093,
  094, 095, 096, 098, 099. ISS-093 (admin self-destruction), ISS-096 (trap
  TriggerType enforcement), and ISS-099 (AoE zone parsing) were verified fixed
  in code before/at deletion; the others were removed by the maintainer directly.
- No dangling cross-references to these refs were found in the remaining
  issue files.

### Index integrity notes (2026-06-19 cleanup)
- All 16 `Resolved` issues (ISS-054, 065–067, 069–071, 073–074, 084–086, 088,
  091–092, 097) and the companion `ISS-054_investigation_report.md` were deleted.
  Resolved work is preserved in git history (see commits referencing each Ref)
  if it ever needs to be revisited.
- This index now tracks **open issues only**; there is no Resolved section to
  reconcile going forward — closing an issue means deleting its file and this
  line in the same change.

### Index integrity notes (2026-06-16 audit)
- The previous index linked dead `Ref_*` filenames (renamed to `ISS-NNN_*`) and
  several resolved issues whose files no longer exist (ISS-046/047/050–053/063),
  while omitting ~20 issues that do exist. All links above are verified present.
- **ISS-046** (turner hands turn to dead entity) was referenced by the old index
  but has **no file**; its tracking is lost. Not recreated here (per audit scope).
- The `issues` CLI builds links for the **root** README from each file's real
  name; this directory index is maintained by hand and was the stale artifact.
