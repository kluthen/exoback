#!/bin/bash
cd "$(dirname "$0")/.."

# run_all_unit_tests.sh - Comprehensive Unit Test Runner for UpsilonBattle

# Setup colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "--- Running All Unit Tests ---\n"

echo ">>> Executing Go Tests..."
# We target specific modules to ensure coverage across the workspace.
# upsilonhub feature tests boot throwaway Postgres containers (testcontainers).
go test ./upsilonapi/... ./upsilonbattle/... ./upsiloncli/... ./upsilonhub/... ./upsilonmapdata/... ./upsilonmapmaker/... ./upsilontools/... ./upsilontypes/...
GO_EXIT=$?

echo -e "\n=== SANCTIONS ==="

if [ $GO_EXIT -eq 0 ]; then
    echo -e "GO: ${GREEN}PASSED${NC}"
else
    echo -e "GO: ${RED}FAILED${NC}"
fi

exit $GO_EXIT
