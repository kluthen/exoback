#!/bin/bash
# tests/edge_case_report.sh — Edge Case Report Generator
# Generates a human-readable markdown summary of edge case test runs.
# Usage: ./tests/edge_case_report.sh > edge_case_report.md

set -euo pipefail

COMMIT_SHA="${GITHUB_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo 'local')}"
BRANCH="${GITHUB_REF_NAME:-$(git branch --show-current 2>/dev/null || echo 'unknown')}"
DATE=$(date -u +"%Y-%m-%d %H:%M UTC")

echo "# Upsilon Battle — Edge Case Test Report"
echo ""
echo "| Field | Value |"
echo "|---|---|"
echo "| **Date** | $DATE |"
echo "| **Commit** | \`$COMMIT_SHA\` |"
echo "| **Branch** | \`$BRANCH\` |"
echo ""

# --- Edge Case Results ---
echo "## Edge Case Test Results"
echo ""
echo "| EC ID | Test Name | Result | ATD Atom |"
echo "|---|---|---|---|"

EDGE_LOG_DIR="upsiloncli/tests/logs"

# Helper function to check and report edge case
check_edge() {
    local ec_id=$1
    local name=$2
    local atom=$3
    local log="edge_${4}.log"

    if [ -f "$EDGE_LOG_DIR/$log" ]; then
        if grep -q "\[SCENARIO_RESULT: PASSED\]" "$EDGE_LOG_DIR/$log" 2>/dev/null; then
            echo "| **$ec_id** | $name | ✅ PASS | \`$atom\` |"
        else
            echo "| **$ec_id** | $name | ❌ FAIL | \`$atom\` |"
        fi
    else
        echo "| **$ec_id** | $name | ⏭️ SKIP | \`$atom\` |"
    fi
}

# --- Phase 1: Movement & Authentication ---
echo "### Phase 1: Movement & Authentication"
echo ""
check_edge "EC-01" "Movement on Obstacle Tiles" "[[mech_move_validation]]" "movement_obstacle_collision"
check_edge "EC-02" "Movement on Entity Collision" "[[mech_move_validation]]" "movement_entity_collision"
check_edge "EC-03" "Movement Already Attacked" "[[mech_move_validation]]" "movement_already_attacked"
check_edge "EC-04" "Movement Path Too Long" "[[mech_move_validation]]" "movement_path_too_long"
check_edge "EC-05" "Movement Path Not Adjacent" "[[mech_move_validation]]" "movement_path_not_adjacent"
# EC-06 scenario disabled (edge_movement_out_of_turn_with_2.js.disabled, ISS-107 audit) — atom left
# as-is (matches the disabled file's own still-unaudited tag); not a live SKIP/PASS row.
check_edge "EC-06" "Movement Out of Turn" "[[mech_move_validation_move_validation_turn_mismatch]]" "movement_out_of_turn"
check_edge "EC-07" "Movement Wrong Controller" "[[mech_move_validation]]" "movement_wrong_controller"
check_edge "EC-08" "Movement Grid Boundaries" "[[mech_move_validation]]" "movement_grid_boundaries"
check_edge "EC-09" "Movement Jump Limitations" "[[mech_move_validation]]" "movement_jump_limitations"
check_edge "EC-20" "Password Policy Full Coverage" "[[rule_password_policy]]" "auth_password_policy_full"
check_edge "EC-21" "Invalid Credentials" "[[api_auth_login]]" "auth_invalid_credentials"
check_edge "EC-22" "Session Timeout / Expired Token" "[[req_security_token_ttl]]" "auth_session_timeout"
check_edge "EC-23" "Missing Token" "[[req_security]]" "auth_missing_token"
check_edge "EC-24" "Admin Non-Admin Access" "[[uc_admin_login]]" "auth_non_admin_access"
echo ""

# --- Phase 2: Attack Validation ---
echo "### Phase 2: Attack Validation"
echo ""
# EC-10 scenario disabled (edge_attack_out_of_turn_with_2.js.disabled, ISS-107 audit) — atom left
# as-is (matches the disabled file's own still-unaudited tag); not a live SKIP/PASS row.
check_edge "EC-10" "Attack Out of Turn" "[[mech_skill_validation_turn_controller_identity_verification]]" "attack_out_of_turn"
check_edge "EC-11" "Attack Wrong Controller" "[[mech_move_validation]]" "attack_wrong_controller"
# EC-12 "attack_friendly_fire": no edge_attack_friendly_fire.js (active or .disabled) exists in
# upsiloncli/tests/scenarios — status/atom unconfirmed, left as-is pending orchestrator triage
# (see report). Friendly fire is otherwise covered by e2e_friendly_fire_prevention.js /
# e2e_friendly_fire_skill_test.js and CR-07 in tests/ci_report.sh.
check_edge "EC-12" "Attack Friendly Fire" "[[rule_friendly_fire]]" "attack_friendly_fire"
check_edge "EC-13" "Attack Target Not in Range" "[[rule_combat_range_validation]]" "attack_target_not_in_range"
check_edge "EC-14" "Attack Target Out of Grid" "[[entity_grid]]" "attack_target_out_of_grid"
# EC-15 retired 2026-04-25: the "invalid cell type" notion no longer maps onto
# the trimmed Cell DTO (only `obstacle` + `height` exposed). Per maintainer
# decision the test was deleted rather than weakened.
check_edge "EC-16" "Attack No Entity" "[[mechanic_multi_entity_cell_system]]" "attack_target_no_entity"
check_edge "EC-17" "Attack Already Acted" "[[mech_action_economy]]" "attack_already_acted"
check_edge "EC-18" "Attack Skill Cooldown" "[[mech_skill_validation]]" "attack_skill_cooldown"
# EC-19 "attack_targeting_rules": no edge_attack_targeting_rules.js (active or .disabled) exists in
# upsiloncli/tests/scenarios — status/atom unconfirmed, left as-is pending orchestrator triage
# (see report).
check_edge "EC-19" "Attack Targeting Rules" "[[mech_skill_validation_entity_targeting_rules_verification]]" "attack_targeting_rules"
echo ""

# --- Phase 3: Character & Matchmaking ---
echo "### Phase 3: Character & Matchmaking"
echo ""
check_edge "EC-25" "Character Reroll Limit" "[[upsilonbattle:mech_character_reroll]]" "char_reroll_limit"
check_edge "EC-26" "Reroll After Match" "[[mech_character_reroll]]" "char_reroll_post_match"
# EC-27 scenario disabled (edge_prog_allocation_no_wins.js.disabled, ISS-107 audit) — atom left
# as-is (matches the disabled file's own still-unaudited tag); not a live SKIP/PASS row.
check_edge "EC-27" "Progression Without Wins" "[[rule_progression]]" "prog_allocation_no_wins"
check_edge "EC-28" "Progression Attribute Cap" "[[rule_progression]]" "prog_attribute_cap"
check_edge "EC-29" "Progression Movement Gate" "[[rule_progression]]" "prog_movement_gate"
check_edge "EC-30" "Progression Negative Value" "[[rule_progression]]" "prog_negative_value"
check_edge "EC-31" "Queue While Already Queued" "[[upsilonapi:rule_matchmaking_single_queue]]" "match_queue_while_queued"
check_edge "EC-32" "Queue While in Match" "[[rule_matchmaking_single_queue]]" "match_queue_while_in_match"
check_edge "EC-33" "Invalid Game Mode" "[[shared:req_matchmaking]]" "match_invalid_game_mode"
check_edge "EC-34" "Leave Queue Not Queued" "[[api_matchmaking]]" "match_leave_not_queued"
echo ""

# --- Phase 4: Match Resolution ---
echo "### Phase 4: Match Resolution"
echo ""
check_edge "EC-35" "Forfeit Out of Turn" "[[rule_forfeit_battle]]" "match_forfeit_out_of_turn"
# EC-36 scenario disabled (edge_match_action_after_end_with_2.js.disabled, ISS-107 audit) — atom
# already matches the disabled file's own tag.
check_edge "EC-36" "Action After Match End" "[[uc_match_resolution]]" "match_action_after_end"
echo ""

# --- Phase 5: API & Communication ---
echo "### Phase 5: API & Communication"
echo ""
check_edge "EC-37" "Missing Request ID" "[[upsilonapi:api_request_id]]" "api_missing_request_id"
check_edge "EC-38" "Invalid UUID Format" "[[upsilonapi:api_profile_character]]" "api_invalid_uuid"
check_edge "EC-39" "Malformed JSON" "[[shared:rule_progression]]" "api_malformed_json"
check_edge "EC-40" "5xx Error Handling" "[[upsilonapi:api_standard_envelope]]" "api_5xx_error_handling"
echo ""

# --- Phase 6: Leaderboard ---
echo "### Phase 6: Leaderboard"
echo ""
check_edge "EC-41" "Invalid Game Mode" "[[upsilonapi:api_leaderboard]]" "leaderboard_invalid_mode"
check_edge "EC-42" "Over Pagination" "[[upsilonapi:api_leaderboard]]" "leaderboard_over_pagination"
echo ""

# --- Phase 7: Admin ---
echo "### Phase 7: Admin"
echo ""
check_edge "EC-43" "Admin View Private Data" "[[upsilonapi:rule_admin_access_restriction]]" "admin_private_data_access"
check_edge "EC-44" "Anonymize Non-Existent" "[[upsilonapi:uc_admin_user_management]]" "admin_anonymize_nonexistent"
check_edge "EC-45" "Soft Delete Non-Existent" "[[upsilonapi:uc_admin_user_management]]" "admin_delete_nonexistent"
echo ""

# --- Phase 8: WebSocket ---
echo "### Phase 8: WebSocket"
echo ""
check_edge "EC-46" "Connection Without Token" "[[api_websocket]]" "ws_connection_no_token"
check_edge "EC-47" "Wrong Channel" "[[upsilonapi:api_websocket]]" "ws_wrong_channel"
check_edge "EC-48" "Ping/pong Timeout" "[[api_websocket]]" "ws_ping_timeout"
echo ""

# --- Summary Statistics ---
echo "## Summary Statistics"
echo ""

total_tests=48
passed_tests=0
failed_tests=0
skipped_tests=0

for logfile in "$EDGE_LOG_DIR"/edge_*.log; do
    if [ ! -f "$logfile" ]; then continue; fi
    if grep -q "\[SCENARIO_RESULT: PASSED\]" "$logfile" 2>/dev/null; then
        ((passed_tests++))
    else
        ((failed_tests++))
    fi
done

# Count skipped (not yet implemented)
skipped_tests=$((total_tests - passed_tests - failed_tests))

echo "| Metric | Value |"
echo "|---|---|"
echo "| **Total Tests** | $total_tests |"
echo "| **Passed** | ✅ $passed_tests |"
echo "| **Failed** | ❌ $failed_tests |"
echo "| **Skipped** | ⏭️ $skipped_tests |"
echo "| **Pass Rate** | $(awk "BEGIN {printf \"%.1f%%\", ($passed_tests / $total_tests) * 100}") |"
echo ""

# --- Coverage by Category ---
echo "## Coverage by Category"
echo ""
echo "| Category | Total | Implemented | Status |"
echo "|---|---|---|---|"

count_category() {
    local count=$1
    local implemented=$2
    local percentage=$(awk "BEGIN {printf \"%.1f%%\", ($implemented / $count) * 100}")
    local status=""
    if [ "$implemented" -eq 0 ]; then
        status="🔴 Not Started"
    elif [ "$implemented" -lt "$count" ]; then
        status="🟡 In Progress"
    else
        status="🟢 Complete"
    fi
    echo "| $3 | $count | $implemented | $percentage | $status |"
}

count_category 9 2 "Movement Validation"  # EC-01 to EC-09
count_category 10 2 "Attack Validation"  # EC-10 to EC-19
count_category 6 0 "Character & Progression"  # EC-25 to EC-30
count_category 4 1 "Matchmaking"  # EC-31 to EC-34
count_category 2 0 "Match Resolution"  # EC-35 to EC-36
count_category 4 0 "API & Communication"  # EC-37 to EC-40
count_category 2 0 "Leaderboard"  # EC-41 to EC-42
count_category 3 0 "Admin"  # EC-43 to EC-45
count_category 3 0 "WebSocket"  # EC-46 to EC-48
count_category 5 1 "Authentication"  # EC-20 to EC-24
echo ""

echo "---"
echo "*Generated by \`tests/edge_case_report.sh\` at $DATE*"
echo "*Based on \`atd_investigation/edge_case_testing_battery.md\`*"
