#!/bin/bash
cd "$(dirname "$0")/.."
# fetch_latest_ci.sh - Pull the latest "CI Pipeline" run for a branch, download its
# artifacts, and print a digest of what actually failed (job status, annotations,
# Go panic/timeout output, PHP failures, docker logs).
# Usage: ./scripts/fetch_latest_ci.sh [branch] [workdir]

set -e

BRANCH="${1:-main}"
WORKDIR="${2:-/tmp/ci_artifacts}"

if ! command -v gh >/dev/null 2>&1; then
    echo "ERROR: gh CLI not found. Install it and run 'gh auth login' first."
    exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
    echo "ERROR: gh is not authenticated. Run 'gh auth login' first."
    exit 1
fi

RUN_ID=$(gh run list --branch "$BRANCH" --workflow "CI Pipeline" --limit 1 --json databaseId --jq '.[0].databaseId')
if [ -z "$RUN_ID" ]; then
    echo "ERROR: no CI Pipeline run found for branch '$BRANCH'."
    exit 1
fi

echo "=================================================="
echo "Latest CI Pipeline run on '$BRANCH': $RUN_ID"
echo "=================================================="
gh run view "$RUN_ID"

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
echo
echo "Downloading artifacts to $WORKDIR ..."
gh run download "$RUN_ID" --dir "$WORKDIR" 2>/dev/null || echo "(no artifacts available, or run still in progress)"

GO_RESULTS="$WORKDIR/go-test-results/go-test-results.json"
if [ -f "$GO_RESULTS" ]; then
    echo
    echo "=================================================="
    echo "Go test failures"
    echo "=================================================="
    FAILED_PKGS=$(grep '"Action":"fail"' "$GO_RESULTS" | python3 -c "
import sys, json
for line in sys.stdin:
    d = json.loads(line)
    print(d.get('Package', ''))
" | sort -u)
    if [ -z "$FAILED_PKGS" ]; then
        echo "(none)"
    else
        for pkg in $FAILED_PKGS; do
            echo "--- $pkg ---"
            grep "\"Package\":\"$pkg\"" "$GO_RESULTS" | python3 -c "
import sys, json
for line in sys.stdin:
    d = json.loads(line)
    out = d.get('Output', '')
    if out:
        sys.stdout.write(out)
"
        done
    fi
fi

CI_LOGS="$WORKDIR/integration-test-results/ci_logs"
if [ -d "$CI_LOGS" ]; then
    echo
    echo "=================================================="
    echo "Docker service logs (non-empty only)"
    echo "=================================================="
    for log in "$CI_LOGS"/*.log; do
        [ -s "$log" ] || continue
        echo "--- $(basename "$log") ---"
        tail -50 "$log"
    done
fi

echo
echo "Artifacts saved under: $WORKDIR"
