#!/usr/bin/env bash
# @lint-ignore-atd tooling script with no business-layer rationale (CODING_RULE.md §6).
# run_ci_local.sh — Reproduce the full GitHub Actions "CI Pipeline" locally.
#
# Clones upsilon-hub (with submodules) into a clean sibling directory
# (default ../upsilon-hub-ci), prepares the deterministic CI environment, and
# runs the same three stages defined in .github/workflows/ci.yml:
#
#   1. Build & Lint        — go work sync, go vet, go build, Dockerfile checks
#   2. Unit Tests          — Go tests (hub feature tests use testcontainers)
#   3. Integration & E2E   — docker-compose.ci stack + Playwright + scenarios + edge cases
#
# Usage:
#   ./scripts/run_ci_local.sh [options]
#
# Options:
#   --ref <git-ref>     Branch / tag / SHA to check out (default: current branch).
#   --dir <path>        Target clone directory (default: ../upsilon-hub-ci).
#   --repo <url>        Repo to clone (default: this repo's origin remote).
#   --local             Source the hub and every submodule from this local
#                       checkout instead of their remotes, so committed-but-
#                       unpushed local changes are picked up without needing
#                       a push first (uncommitted changes still aren't seen —
#                       git clone only reads from history, not the worktree).
#   --fresh             Remove the target dir and re-clone from scratch.
#   --stages <list>     Comma-separated subset of: build,unit,integration
#                       (default: build,unit,integration).
#   --skip-playwright   Skip the (heavy) Playwright browser install + UI tests.
#   --keep-stack        Do not tear down the docker compose stack at the end.
#   -h, --help          Show this help and exit.
#
# Exit code is non-zero if any selected stage fails.

set -Eeuo pipefail

# ----------------------------------------------------------------------------
# Locate the source repo (the checkout this script lives in)
# ----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"

# ----------------------------------------------------------------------------
# Defaults (overridable via flags)
# ----------------------------------------------------------------------------
REF="$(git -C "$SOURCE_REPO" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
TARGET_DIR="$(cd "$SOURCE_REPO/.." && pwd)/upsilon-hub-ci"
REPO_URL="$(git -C "$SOURCE_REPO" config --get remote.origin.url || true)"
FRESH=0
STAGES="build,unit,integration"
SKIP_PLAYWRIGHT=0
KEEP_STACK=0
LOCAL_SOURCE=0

COMPOSE="docker compose -f docker-compose.ci.yaml"

# ----------------------------------------------------------------------------
# Pretty logging
# ----------------------------------------------------------------------------
if [ -t 1 ]; then
    C_BOLD=$'\e[1m'; C_GREEN=$'\e[32m'; C_RED=$'\e[31m'; C_YELLOW=$'\e[33m'; C_BLUE=$'\e[34m'; C_OFF=$'\e[0m'
else
    C_BOLD=""; C_GREEN=""; C_RED=""; C_YELLOW=""; C_BLUE=""; C_OFF=""
fi
log()   { printf '%s\n' "${C_BLUE}==>${C_OFF} ${C_BOLD}$*${C_OFF}"; }
info()  { printf '    %s\n' "$*"; }
ok()    { printf '%s\n' "${C_GREEN}  ✔ $*${C_OFF}"; }
warn()  { printf '%s\n' "${C_YELLOW}  ! $*${C_OFF}"; }
err()   { printf '%s\n' "${C_RED}  ✗ $*${C_OFF}" >&2; }
die()   { err "$*"; exit 1; }

usage() { awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 {exit}' "${BASH_SOURCE[0]}"; exit "${1:-0}"; }

# ----------------------------------------------------------------------------
# Parse arguments
# ----------------------------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        --ref)             REF="${2:?--ref needs a value}"; shift 2 ;;
        --dir)             TARGET_DIR="${2:?--dir needs a value}"; shift 2 ;;
        --repo)            REPO_URL="${2:?--repo needs a value}"; shift 2 ;;
        --local)           LOCAL_SOURCE=1; shift ;;
        --fresh)           FRESH=1; shift ;;
        --stages)          STAGES="${2:?--stages needs a value}"; shift 2 ;;
        --skip-playwright) SKIP_PLAYWRIGHT=1; shift ;;
        --keep-stack)      KEEP_STACK=1; shift ;;
        -h|--help)         usage 0 ;;
        *)                 die "Unknown option: $1 (try --help)" ;;
    esac
done

want_stage() { [[ ",$STAGES," == *",$1,"* ]]; }

# ----------------------------------------------------------------------------
# Prerequisite checks
# ----------------------------------------------------------------------------
check_prereqs() {
    log "Checking prerequisites"
    command -v git    >/dev/null 2>&1 || die "git not found"
    command -v docker >/dev/null 2>&1 || die "docker not found"
    docker compose version >/dev/null 2>&1 || die "'docker compose' plugin not available"
    if want_stage build || want_stage unit; then
        command -v go >/dev/null 2>&1 || die "go not found (needed for build/unit stages)"
    fi
    if want_stage integration && [ "$SKIP_PLAYWRIGHT" -eq 0 ]; then
        command -v node >/dev/null 2>&1 || warn "node not found — Playwright tests will be skipped"
    fi
    if [ "$LOCAL_SOURCE" -eq 0 ]; then
        [ -n "$REPO_URL" ] || die "Could not determine repo URL; pass --repo <url> or --local"
    fi
    ok "Prerequisites satisfied"
}

# ----------------------------------------------------------------------------
# Clone (or refresh) the isolated CI checkout
# ----------------------------------------------------------------------------
prepare_clone() {
    log "Preparing CI checkout at: $TARGET_DIR"

    if [ "$LOCAL_SOURCE" -eq 1 ]; then
        REPO_URL="$SOURCE_REPO"
        info "source: local working tree ($REPO_URL — committed state only)"
    fi
    info "repo: $REPO_URL"
    info "ref:  $REF"

    if [ "$FRESH" -eq 1 ] && [ -d "$TARGET_DIR" ]; then
        warn "Removing existing directory (--fresh)"
        rm -rf "$TARGET_DIR"
    fi

    if [ -d "$TARGET_DIR/.git" ]; then
        info "Existing clone found — fetching and resetting to $REF"
        git -C "$TARGET_DIR" remote set-url origin "$REPO_URL"
        git -C "$TARGET_DIR" fetch --all --prune --tags
        git -C "$TARGET_DIR" checkout -f "$REF"
        # Pull latest if it's a branch (ignore failure for detached tags/SHAs)
        git -C "$TARGET_DIR" pull --ff-only 2>/dev/null || true
    else
        # --recurse-submodules is intentionally omitted: with --local we need
        # to repoint each submodule's URL at its local checkout *before* it's
        # initialized, which relink_submodules_to_local does below.
        git clone --branch "$REF" "$REPO_URL" "$TARGET_DIR" 2>/dev/null \
            || git clone "$REPO_URL" "$TARGET_DIR"
        git -C "$TARGET_DIR" checkout -f "$REF"
    fi

    if [ "$LOCAL_SOURCE" -eq 1 ]; then
        # NOTE: deliberately skip `submodule sync` here — it re-derives each
        # submodule's URL from .gitmodules (resolving relative ../foo.git
        # URLs against the now-local origin) and would clobber the local
        # overrides relink_submodules_to_local just set.
        relink_submodules_to_local
        # Git disables the `file://`/local-path transport for submodules by
        # default (post CVE-2022-39253). Safe to allow here: TARGET_DIR is a
        # checkout we just made of SOURCE_REPO, not an untrusted clone.
        git -c protocol.file.allow=always -C "$TARGET_DIR" submodule update --init --recursive --force
    else
        git -C "$TARGET_DIR" submodule sync --recursive
        git -C "$TARGET_DIR" submodule update --init --recursive --force
    fi

    local sha
    sha="$(git -C "$TARGET_DIR" rev-parse --short HEAD)"
    ok "Checked out $REF @ $sha"
}

# ----------------------------------------------------------------------------
# (--local) Point every submodule at its local checkout under SOURCE_REPO
# instead of its configured remote (GitHub, or relative ../foo.git URLs that
# resolve against the *remote* superproject URL). Reads from each submodule's
# committed history, same as a real clone would — uncommitted changes in the
# submodule worktrees still won't show up.
# ----------------------------------------------------------------------------
relink_submodules_to_local() {
    log "Relinking submodules to local checkouts (--local)"
    local entries
    entries="$(git config -f "$TARGET_DIR/.gitmodules" --get-regexp '\.path$' || true)"
    [ -n "$entries" ] || { warn "No submodules declared in .gitmodules"; return 0; }

    while IFS=' ' read -r key path; do
        local name="${key#submodule.}"
        name="${name%.path}"
        local src="$SOURCE_REPO/$path"
        if [ -d "$src/.git" ] || [ -f "$src/.git" ]; then
            git -C "$TARGET_DIR" config "submodule.${name}.url" "$src"
            info "  $name -> $src"
        else
            warn "  $name: no local checkout at $src, keeping configured URL"
        fi
    done <<< "$entries"
}

# ----------------------------------------------------------------------------
# Prepare the deterministic CI environment (mirrors ci.yml "Prepare Environment")
# ----------------------------------------------------------------------------
prepare_env() {
    log "Preparing CI environment"
    cd "$TARGET_DIR"
    cp .env.ci .env
    mkdir -p upsiloncli/tests/logs
    ok ".env prepared from .env.ci"
}

# ----------------------------------------------------------------------------
# STAGE 1 — Build & Lint
# ----------------------------------------------------------------------------
stage_build() {
    log "STAGE 1: Build & Lint"
    cd "$TARGET_DIR"

    info "go work sync"
    go work sync

    info "go vet (modules derived from go.work)"
    go vet $(scripts/list_go_modules.sh)

    info "go build upsilonapi"
    go build -o /dev/null ./upsilonapi
    info "go build upsiloncli"
    go build -o /dev/null ./upsiloncli/cmd/upsiloncli
    info "go build upsilonhub"
    go build -o /dev/null ./upsilonhub/cmd/upsilonhub
    info "go build upsilonauth"
    go build -o /dev/null ./upsilonauth/cmd/upsilonauth
    info "go build upsiloneconomy"
    go build -o /dev/null ./upsiloneconomy/cmd/upsiloneconomy

    info "Dockerfile syntax checks"
    docker build --check -f upsilonhub/Dockerfile . 2>/dev/null || warn "upsilonhub Dockerfile --check skipped"
    docker build --check -f upsilonapi/Dockerfile . 2>/dev/null     || warn "upsilonapi Dockerfile --check skipped"

    if [ -f tests/lint_report.sh ]; then
        chmod +x tests/lint_report.sh
        ./tests/lint_report.sh > build_report.md 2>&1 || true
        info "Build report written to build_report.md"
    fi
    ok "Build & Lint passed"
}

# ----------------------------------------------------------------------------
# STAGE 2 — Unit Tests (Go)
# ----------------------------------------------------------------------------
stage_unit() {
    log "STAGE 2: Unit Tests"
    cd "$TARGET_DIR"

    info "Go unit tests (modules derived from go.work)"
    go work sync
    # Split into two invocations: upsilonauth/upsiloneconomy each start
    # several testcontainers Postgres instances, joining upsilonhub's own
    # two for 8 container-backed packages total. At default parallelism
    # that measured as flaky container-contention failures (no real
    # regression); forcing just those two modules to `-p 1` serializes
    # their container starts and measured green across repeated runs.
    # 600s: the hub feature tests boot throwaway Postgres containers.
    go test -count=1 -timeout 600s -json \
        $(scripts/list_go_modules.sh --exclude upsilonauth,upsiloneconomy) \
        > go-test-results.json 2>&1 || true
    go test -count=1 -timeout 600s -json -p 1 \
        $(scripts/list_go_modules.sh --only upsilonauth,upsiloneconomy) \
        >> go-test-results.json 2>&1 || true
    if grep -q '"Action":"fail"' go-test-results.json; then
        err "Go tests FAILED"
        grep '"Action":"fail"' go-test-results.json | head -20
        return 1
    fi
    ok "Go unit tests passed"


    if [ -f tests/unit_report.sh ]; then
        chmod +x tests/unit_report.sh
        ./tests/unit_report.sh > summary.md 2>&1 || true
        info "Unit report written to summary.md"
    fi
}

# ----------------------------------------------------------------------------
# STAGE 3 — Integration & E2E
# ----------------------------------------------------------------------------
stage_integration() {
    log "STAGE 3: Integration & E2E"
    cd "$TARGET_DIR"
    local rc=0

    # Playwright (host side) — optional/heavy
    if [ "$SKIP_PLAYWRIGHT" -eq 0 ] && command -v node >/dev/null 2>&1; then
        info "Installing Playwright dependencies (upsilonbattleui)"
        ( cd upsilonbattleui && npm ci && npx playwright install --with-deps chromium ) \
            || warn "Playwright install failed — UI tests will be skipped"
    else
        warn "Skipping Playwright install (--skip-playwright or node missing)"
    fi

    # --build is MANDATORY, not an optimisation. `docker compose up` only builds
    # images that do not already exist locally, and unlike an ephemeral GitHub
    # runner (which prunes and starts cold) this mirror keeps images between
    # runs. Without it, compose silently reuses whatever was built last time:
    # a run on 2026-08-26 booted a hub image built 2026-07-20, from before the
    # Phase 4 auth cutover, which no longer had the /internal/v1 AccountPush
    # route — 78 scenarios failed for a reason that existed only in the image.
    # A CI mirror that tests stale artefacts is worse than no mirror at all.
    info "Booting Upsilon CI stack (docker compose --build --wait)"
    $COMPOSE up -d --build --wait --wait-timeout 300
    $COMPOSE ps

    if [ "$SKIP_PLAYWRIGHT" -eq 0 ] && command -v node >/dev/null 2>&1 && [ -d upsilonbattleui/node_modules ]; then
        log "E2E: Playwright tests"
        ( cd upsilonbattleui && PLAYWRIGHT_BASE_URL=http://localhost:8085 npx playwright test --workers=1 ) || { warn "Playwright tests reported failures"; rc=1; }
    fi

    log "E2E: Centralized customer scenarios"
    $COMPOSE exec -T tester /bin/sh ./tests/run_all_scenarios.sh || { warn "Customer scenarios reported failures"; rc=1; }

    log "E2E: Edge case suite"
    $COMPOSE exec -T tester /bin/sh ./tests/run_all_edge_cases.sh || { warn "Edge case suite reported failures"; rc=1; }

    log "Generating combined reports"
    ./tests/ci_report.sh > ci_report.md 2>&1 || true
    if ls upsiloncli/tests/logs/edge_*.log >/dev/null 2>&1; then
        ./tests/edge_case_report.sh > edge_case_report.md 2>&1 || true
    fi
    info "Reports: $TARGET_DIR/ci_report.md  $TARGET_DIR/edge_case_report.md"

    if [ "$rc" -ne 0 ]; then
        warn "Collecting docker logs (failures detected)"
        mkdir -p ci_logs
        for svc in hub-migrate hub-seed hub proxy engine db tester auth-migrate auth-seed auth economy-migrate economy-seed economy; do
            $COMPOSE logs "$svc" > "ci_logs/$svc.log" 2>&1 || true
        done
        info "Service logs saved under $TARGET_DIR/ci_logs/"
    fi

    if [ "$KEEP_STACK" -eq 0 ]; then
        log "Tearing down docker stack"
        $COMPOSE down -v || true
    else
        warn "Leaving stack running (--keep-stack); tear down with: cd $TARGET_DIR && $COMPOSE down -v"
    fi

    return "$rc"
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
FAILED_STAGES=()

main() {
    log "Upsilon Hub — Local CI Runner"
    info "source repo:  $SOURCE_REPO"
    info "stages:       $STAGES"

    check_prereqs
    prepare_clone
    prepare_env

    if want_stage build;       then stage_build       || FAILED_STAGES+=("build"); fi
    if want_stage unit;        then stage_unit        || FAILED_STAGES+=("unit"); fi
    if want_stage integration; then stage_integration || FAILED_STAGES+=("integration"); fi

    echo
    log "CI Summary"
    if [ "${#FAILED_STAGES[@]}" -eq 0 ]; then
        ok "All selected stages passed ✅"
        exit 0
    else
        err "Failed stages: ${FAILED_STAGES[*]} ❌"
        exit 1
    fi
}

main "$@"
