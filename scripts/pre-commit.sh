#!/bin/bash

# Upsilon Pre-commit Verification Script
# This script runs all checks required for CI to pass.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}   Upsilon CI Pre-check Validator      ${NC}"
echo -e "${BLUE}=======================================${NC}"

# TRACKING
GO_SYNC="SKIP"
GO_VET="FAIL"
GO_TEST="FAIL"
HEALTH_CHECK="FAIL"

# Ensure we are in the root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.." || exit 1

# 0. CODE HEALTH CHECK
echo -e "\n${YELLOW}[0/4] Running Code Health Check (DISABLED)...${NC}"
# if ./scripts/code_health_check.py; then
#     HEALTH_CHECK="PASS"
#     echo -e "${GREEN}✓ Code health standards met${NC}"
# else
#     HEALTH_CHECK="FAIL"
#     echo -e "${RED}✗ Code health check failed${NC}"
# fi
HEALTH_CHECK="SKIP"

# 1. GO WORKSPACE SYNC
echo -e "\n${YELLOW}[1/4] Syncing Go Workspace...${NC}"
if go work sync; then
    GO_SYNC="PASS"
    echo -e "${GREEN}✓ Workspace synchronized${NC}"
else
    GO_SYNC="FAIL"
    echo -e "${RED}✗ Workspace sync failed${NC}"
fi

# 2. GO VET
echo -e "\n${YELLOW}[2/4] Running Go Vet...${NC}"
MODULES="./upsilonapi/... ./upsiloncli/... ./upsilonbattle/... ./upsilonhub/... ./upsilonmapdata/... ./upsilonmapmaker/... ./upsilontools/..."
if go vet $MODULES; then
    GO_VET="PASS"
    echo -e "${GREEN}✓ Go Vet passed${NC}"
else
    echo -e "${RED}✗ Go Vet found issues${NC}"
fi

# 3. GO TEST
# 300s: the hub feature tests boot throwaway Postgres containers.
echo -e "\n${YELLOW}[3/4] Running Go Unit Tests...${NC}"
if go test -timeout 300s $MODULES; then
    GO_TEST="PASS"
    echo -e "${GREEN}✓ Go Tests passed${NC}"
else
    echo -e "${RED}✗ Go Tests failed${NC}"
fi

# SUMMARY TABLE
echo -e "\n${BLUE}=======================================${NC}"
echo -e "${BLUE}           SUMMARY REPORT              ${NC}"
echo -e "${BLUE}=======================================${NC}"

format_status() {
    if [ "$1" == "PASS" ]; then
        echo -e "${GREEN}PASS${NC}"
    elif [ "$1" == "SKIP" ]; then
        echo -e "${BLUE}SKIP${NC}"
    elif [ "$1" == "NO_ENV" ] || [ "$1" == "MISSING" ]; then
        echo -e "${YELLOW}$1${NC}"
    else
        echo -e "${RED}FAIL${NC}"
    fi
}

echo -e "Code Health Check : $(format_status $HEALTH_CHECK)"
echo -e "Go Workspace Sync : $(format_status $GO_SYNC)"
echo -e "Go Linting (Vet)  : $(format_status $GO_VET)"
echo -e "Go Unit Tests     : $(format_status $GO_TEST)"
echo -e "${BLUE}=======================================${NC}"

if ([[ "$HEALTH_CHECK" =~ ^(PASS|SKIP)$ ]]) && [ "$GO_SYNC" == "PASS" ] && [ "$GO_VET" == "PASS" ] && [ "$GO_TEST" == "PASS" ]; then
    echo -e "\n${GREEN}READY TO COMMIT (Go checks passed)${NC}"
    exit 0
else
    echo -e "\n${RED}PLEASE FIX ERRORS BEFORE COMMITTING${NC}"
    exit 1
fi
