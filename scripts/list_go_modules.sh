#!/usr/bin/env bash
# @lint-ignore-atd tooling script with no business-layer rationale (CODING_RULE.md §6).
# scripts/list_go_modules.sh — print every go.work workspace module as a
# `./name/...` pattern, one per line.
#
# CI (.github/workflows/ci.yml), scripts/run_ci_local.sh and
# scripts/run_all_unit_tests.sh used to hand-maintain this module list as a
# literal, and it drifted twice when services were extracted from the hub
# (ISS-123, ISS-132): upsilonauth, upsiloneconomy and upsilonserializer went
# unlisted, so 17 real _test.go files were never executed by `go test`
# anywhere in the pipeline. Deriving the list from `go.work` via `go list -m`
# means a new `use` entry is picked up automatically by every caller.
#
# Usage:
#   scripts/list_go_modules.sh                              # all workspace modules
#   scripts/list_go_modules.sh --exclude upsilonauth,upsiloneconomy
#   scripts/list_go_modules.sh --only upsilonauth,upsiloneconomy
#
# --exclude/--only take a comma-separated list of module directory names
# (matched against the derived `./name/...` entries) — used to split the
# testcontainers-backed modules (upsilonauth, upsiloneconomy) into their own
# `-p 1` test invocation; see run_ci_local.sh / ci.yml / run_all_unit_tests.sh.
set -Eeuo pipefail
cd "$(dirname "$0")/.."

EXCLUDE=""
ONLY=""
while [ $# -gt 0 ]; do
    case "$1" in
        --exclude) EXCLUDE="${2:?--exclude needs a value}"; shift 2 ;;
        --only)    ONLY="${2:?--only needs a value}"; shift 2 ;;
        *) echo "list_go_modules.sh: unknown option: $1" >&2; exit 2 ;;
    esac
done

# `go list -m -f '{{.Dir}}'` in workspace mode (go.work present, no root
# go.mod) enumerates exactly the `use ()` block's modules, in the same order
# go.work does. Rewrite each absolute dir to a `./name/...` package pattern.
ALL="$(go list -m -f '{{.Dir}}' | sed "s|^$(pwd)/|./|; s|\$|/...|")"

if [ -n "$ONLY" ]; then
    pattern="$(echo "$ONLY" | sed 's/,/|/g')"
    echo "$ALL" | grep -E "$pattern"
elif [ -n "$EXCLUDE" ]; then
    pattern="$(echo "$EXCLUDE" | sed 's/,/|/g')"
    echo "$ALL" | grep -v -E "$pattern"
else
    echo "$ALL"
fi
