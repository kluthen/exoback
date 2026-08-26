#!/bin/bash
# @lint-ignore-atd tooling script with no business-layer rationale (CODING_RULE.md §6).
cd "$(dirname "$0")/.."

# run_all_unit_tests.sh - Comprehensive Unit Test Runner for UpsilonBattle

# Setup colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "--- Running All Unit Tests ---\n"

echo ">>> Executing Go Tests..."
# Module list is derived from go.work (scripts/list_go_modules.sh) instead of
# hand-maintained here — it drifted twice when services were extracted from
# the hub (ISS-123, ISS-132), leaving upsilonauth/upsiloneconomy/upsilonserializer
# unexercised. upsilonauth and upsiloneconomy are run separately at -p 1:
# together with upsilonhub they start 8 testcontainers Postgres packages, and
# at default parallelism that measured as flaky container-contention
# failures (no real regression) — see ISS-132.
go test $(scripts/list_go_modules.sh --exclude upsilonauth,upsiloneconomy)
GO_EXIT=$?

if [ "$GO_EXIT" -eq 0 ]; then
    go test -p 1 $(scripts/list_go_modules.sh --only upsilonauth,upsiloneconomy)
    GO_EXIT=$?
fi

echo -e "\n=== SANCTIONS ==="

if [ $GO_EXIT -eq 0 ]; then
    echo -e "GO: ${GREEN}PASSED${NC}"
else
    echo -e "GO: ${RED}FAILED${NC}"
fi

exit $GO_EXIT
