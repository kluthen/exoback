#!/usr/bin/env bash
# @lint-ignore-atd tooling script with no business-layer rationale (CODING_RULE.md §6).
# run_local_ci_reports.sh — run the local CI mirror and collect every report
# into one timestamped, reviewable bundle inside this checkout.
#
# Why this exists: scripts/run_ci_local.sh already mirrors the three CI stages
# and writes ci_report.md / edge_case_report.md, but
#   * it leaves every artefact inside the throwaway clone (../upsilon-hub-ci),
#   * its Playwright run uses the repo's configured reporters (list + html
#     only), so there is no machine-readable result file to diff or summarise.
# This wrapper therefore runs the mirror with --skip-playwright, drives
# Playwright itself with list+html+json+junit reporters against the kept
# stack, and copies everything back under pipeline_output/local_ci/<stamp>/.
#
# Playwright is deliberately NOT gated here: a red suite must still produce a
# full report bundle, so every step is failure-tolerant and the exit code is
# reported in SUMMARY.md rather than aborting collection.
#
# Usage:
#   ./scripts/run_local_ci_reports.sh [options]
#
# Options:
#   --fresh             Re-clone the CI mirror from scratch (slower, cleanest).
#   --stages <list>     Passed through to run_ci_local.sh
#                       (default: build,unit,integration).
#   --grep <pattern>    Only run Playwright specs matching this pattern.
#   --keep-stack        Leave the docker stack up after the run (default:
#                       kept, so the report can be re-generated; pass
#                       --teardown to override).
#   --teardown          Tear the docker stack down when finished.
#   -h, --help          Show this help.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CI_DIR="$(cd "$REPO_ROOT/.." && pwd)/upsilon-hub-ci"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="$REPO_ROOT/pipeline_output/local_ci/$STAMP"

FRESH_ARG=""
STAGES="build,unit,integration"
GREP_ARG=""
TEARDOWN=0
BASE_URL="http://localhost:8085"

while [ $# -gt 0 ]; do
    case "$1" in
        --fresh)      FRESH_ARG="--fresh"; shift ;;
        --stages)     STAGES="$2"; shift 2 ;;
        --grep)       GREP_ARG="$2"; shift 2 ;;
        --keep-stack) shift ;;
        --teardown)   TEARDOWN=1; shift ;;
        -h|--help)    sed -n '2,32p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

mkdir -p "$OUT_DIR"
RUN_LOG="$OUT_DIR/run.log"

log()  { printf '\n\e[1m\e[34m==> %s\e[0m\n' "$*" | tee -a "$RUN_LOG"; }
info() { printf '    %s\n' "$*" | tee -a "$RUN_LOG"; }

log "Local CI + Playwright report bundle"
info "stamp:    $STAMP"
info "bundle:   $OUT_DIR"
info "ci clone: $CI_DIR"
info "stages:   $STAGES"

# ---------------------------------------------------------------------------
# 1. CI mirror (build / unit / integration). Playwright is skipped here and
#    driven below so we control the reporters. --keep-stack is mandatory: the
#    Playwright run needs the stack alive afterwards.
# ---------------------------------------------------------------------------
log "STAGE A: run_ci_local.sh (--skip-playwright --keep-stack)"
mirror_rc=0
"$SCRIPT_DIR/run_ci_local.sh" \
    --local $FRESH_ARG \
    --stages "$STAGES" \
    --skip-playwright \
    --keep-stack 2>&1 | tee -a "$RUN_LOG" || mirror_rc=${PIPESTATUS[0]}
info "run_ci_local.sh exit: $mirror_rc"

# ---------------------------------------------------------------------------
# 2. Playwright, with a machine-readable report alongside the HTML one.
# ---------------------------------------------------------------------------
pw_rc=0
pw_ran=0
if [ -d "$CI_DIR/upsilonbattleui" ]; then
    log "STAGE B: Playwright (list + html + json + junit)"
    (
        cd "$CI_DIR/upsilonbattleui"
        npm ci
        # NOT --with-deps: that shells out to sudo apt-get and hangs an
        # unattended run on a box without passwordless sudo. The browser
        # binaries are what we actually need and they cache in ~/.cache.
        npx playwright install chromium
    ) 2>&1 | tee -a "$RUN_LOG" || info "Playwright install reported a problem — continuing"

    if [ -d "$CI_DIR/upsilonbattleui/node_modules" ]; then
        pw_ran=1
        set +e
        ( cd "$CI_DIR/upsilonbattleui" \
            && CI=1 \
               PLAYWRIGHT_BASE_URL="$BASE_URL" \
               PLAYWRIGHT_JSON_OUTPUT_NAME="playwright-results.json" \
               PLAYWRIGHT_JUNIT_OUTPUT_NAME="playwright-junit.xml" \
               npx playwright test --workers=1 \
                   ${GREP_ARG:+--grep "$GREP_ARG"} \
                   --reporter=list,html,json,junit ) 2>&1 | tee -a "$RUN_LOG"
        pw_rc=${PIPESTATUS[0]}
        set -e
        info "playwright exit: $pw_rc"
    else
        info "node_modules missing — Playwright did not run"
    fi
else
    info "no upsilonbattleui in $CI_DIR — Playwright skipped"
fi

# ---------------------------------------------------------------------------
# 3. Collect every artefact into the bundle.
# ---------------------------------------------------------------------------
log "STAGE C: collecting artefacts"
mkdir -p "$OUT_DIR/playwright"
for f in playwright-report playwright-results.json playwright-junit.xml; do
    if [ -e "$CI_DIR/upsilonbattleui/$f" ]; then
        cp -r "$CI_DIR/upsilonbattleui/$f" "$OUT_DIR/playwright/" && info "collected playwright/$f"
    fi
done
for f in ci_report.md edge_case_report.md; do
    [ -f "$CI_DIR/$f" ] && cp "$CI_DIR/$f" "$OUT_DIR/" && info "collected $f"
done
[ -d "$CI_DIR/ci_logs" ] && cp -r "$CI_DIR/ci_logs" "$OUT_DIR/" && info "collected ci_logs/"
if ls "$CI_DIR"/upsiloncli/tests/logs/*.log >/dev/null 2>&1; then
    mkdir -p "$OUT_DIR/scenario_logs"
    cp "$CI_DIR"/upsiloncli/tests/logs/*.log "$OUT_DIR/scenario_logs/" && info "collected scenario_logs/"
fi

# ---------------------------------------------------------------------------
# 4. SUMMARY.md — the file to open first.
# ---------------------------------------------------------------------------
JSON="$OUT_DIR/playwright/playwright-results.json"
{
    echo "# Local CI run — $STAMP"
    echo
    echo "| Stage | Result |"
    echo "|---|---|"
    echo "| run_ci_local.sh (\`$STAGES\`, playwright skipped) | exit $mirror_rc |"
    if [ "$pw_ran" -eq 1 ]; then
        echo "| Playwright | exit $pw_rc |"
    else
        echo "| Playwright | did not run |"
    fi
    echo
    if [ -f "$JSON" ]; then
        python3 - "$JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
rows, tally = [], {}
def walk(suite, trail):
    name = trail + ([suite['title']] if suite.get('title') else [])
    for spec in suite.get('specs', []):
        st = 'passed' if spec.get('ok') else 'FAILED'
        for t in spec.get('tests', []):
            st = t.get('status', st)
            if t.get('status') == 'expected': st = 'passed'
            elif t.get('status') == 'unexpected': st = 'FAILED'
            elif t.get('status') == 'flaky': st = 'flaky'
            elif t.get('status') == 'skipped': st = 'skipped'
        tally[st] = tally.get(st, 0) + 1
        rows.append((st, ' › '.join(name + [spec['title']])))
    for s in suite.get('suites', []):
        walk(s, name)
for s in d.get('suites', []):
    walk(s, [])
print("## Playwright results\n")
print(" · ".join(f"**{k}**: {v}" for k, v in sorted(tally.items())) or "no tests reported")
print("\n| Status | Test |")
print("|---|---|")
for st, title in sorted(rows, key=lambda r: (r[0] != 'FAILED', r[1])):
    print(f"| {st} | {title} |")
PY
    else
        echo "## Playwright results"
        echo
        echo "_No JSON report produced — see \`run.log\`._"
    fi
    echo
    echo "## Files"
    echo
    echo '```'
    (cd "$OUT_DIR" && find . -maxdepth 2 | sort | sed 's|^\./||' | grep -v '^\.$')
    echo '```'
    echo
    echo "HTML report: \`playwright/playwright-report/index.html\`"
} > "$OUT_DIR/SUMMARY.md" 2>&1

if [ "$TEARDOWN" -eq 1 ]; then
    log "Tearing down stack"
    ( cd "$CI_DIR" && docker compose -f docker-compose.ci.yaml down -v ) || true
else
    info "Stack left running: cd $CI_DIR && docker compose -f docker-compose.ci.yaml down -v"
fi

log "DONE — bundle: $OUT_DIR"
info "open $OUT_DIR/SUMMARY.md"
exit 0
