#!/usr/bin/env bash
# scripts/repo_status.sh — one-shot health check of the umbrella + every submodule.
#
# For each repo (umbrella first, then all submodules listed in .gitmodules) it
# reports: current branch, short HEAD, push-sync vs the upstream tracking branch
# (ahead/behind), whether the umbrella's recorded submodule pointer matches the
# submodule's checked-out HEAD, and working-tree cleanliness.
#
# Exit status is 0 only when every repo is clean, fully pushed, and pointer-
# coherent — so it doubles as a pre-push / post-push preflight. Non-zero if any
# repo is dirty, has unpushed commits, lacks an upstream, or the umbrella points
# at a commit that isn't the submodule's current HEAD (pointer drift).
#
# Usage:
#   scripts/repo_status.sh            # fast, offline (uses local tracking refs)
#   scripts/repo_status.sh --fetch    # `git fetch` each repo first (network) for
#                                      # accurate ahead/behind against the remote

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || { echo "cannot cd to repo root" >&2; exit 2; }

DO_FETCH=0
[ "${1:-}" = "--fetch" ] && DO_FETCH=1

# Colour only when stdout is a real terminal (decided once, before any subshell).
if [ -t 1 ]; then USE_COLOR=1; else USE_COLOR=0; fi
BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; RST=$'\033[0m'

paint() { # paint <colour> <text>
    if [ "$USE_COLOR" = 1 ] && [ -n "$1" ]; then printf '%s%s%s' "$1" "$2" "$RST"; else printf '%s' "$2"; fi
}
cell() { # cell <text> <width> <colour>  — pad the PLAIN text first, then colour
    paint "$3" "$(printf '%-*s' "$2" "$1")"
}

# Umbrella (".") first, then submodule paths straight out of .gitmodules.
SUBS=$(git config --file .gitmodules --get-regexp '\.path$' 2>/dev/null | awk '{print $2}')
REPOS=". $SUBS"

problems=0

hdr="$(printf '%-17s %-10s %-9s %-14s %-16s %s' REPO BRANCH HEAD SYNC POINTER 'WORKING-TREE')"
paint "$BOLD" "$hdr"; echo
paint "$DIM" "----------------- ---------- --------- -------------- ---------------- ------------"; echo

for repo in $REPOS; do
    if [ ! -e "$repo/.git" ]; then
        printf '%s %s\n' "$(cell "$repo" 17 "")" "$(paint "$RED" 'uninitialized — run: git submodule update --init')"
        problems=$((problems + 1)); continue
    fi

    [ "$DO_FETCH" = 1 ] && git -C "$repo" fetch -q --all 2>/dev/null

    if [ "$repo" = "." ]; then name="upsilonumbrella"; else name="$repo"; fi
    branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)
    head=$(git -C "$repo" rev-parse --short HEAD 2>/dev/null)

    # --- push sync vs upstream ---
    if git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
        set -- $(git -C "$repo" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null)
        behind=${1:-0}; ahead=${2:-0}
        if [ "$ahead" = 0 ] && [ "$behind" = 0 ]; then
            sync_txt="up-to-date"; sync_col="$GRN"
        elif [ "$ahead" != 0 ] && [ "$behind" != 0 ]; then
            sync_txt="diverged $ahead/$behind"; sync_col="$RED"; problems=$((problems + 1))
        elif [ "$ahead" != 0 ]; then
            sync_txt="ahead $ahead"; sync_col="$YEL"; problems=$((problems + 1))
        else
            sync_txt="behind $behind"; sync_col="$YEL"
        fi
    else
        sync_txt="no-upstream"; sync_col="$RED"; problems=$((problems + 1))
    fi

    # --- submodule pointer coherence (umbrella HEAD gitlink vs submodule HEAD) ---
    if [ "$repo" = "." ]; then
        ptr_txt="-"; ptr_col="$DIM"
    else
        recorded=$(git ls-tree HEAD "$repo" 2>/dev/null | awk '{print $3}')
        actual=$(git -C "$repo" rev-parse HEAD 2>/dev/null)
        if [ -n "$recorded" ] && [ "$recorded" = "$actual" ]; then
            ptr_txt="tracked"; ptr_col="$GRN"
        else
            ptr_txt="DRIFT->${recorded:0:7}"; ptr_col="$RED"; problems=$((problems + 1))
        fi
    fi

    # --- working tree ---
    dirty=$(git -C "$repo" status --porcelain 2>/dev/null | grep -c . || true)
    if [ "$dirty" = 0 ]; then
        wt_txt="clean"; wt_col="$GRN"
    else
        wt_txt="$dirty changed"; wt_col="$RED"; problems=$((problems + 1))
    fi

    printf '%s %s %s %s %s %s\n' \
        "$(cell "$name" 17 "")" \
        "$(cell "$branch" 10 "")" \
        "$(cell "$head" 9 "")" \
        "$(cell "$sync_txt" 14 "$sync_col")" \
        "$(cell "$ptr_txt" 16 "$ptr_col")" \
        "$(cell "$wt_txt" 12 "$wt_col")"
done

echo
if [ "$problems" = 0 ]; then
    paint "$GRN" "OK — all repos clean, pushed, and pointer-coherent."; echo
    exit 0
else
    paint "$YEL" "$problems item(s) need attention (dirty / unpushed / no-upstream / pointer drift)."; echo
    exit 1
fi
