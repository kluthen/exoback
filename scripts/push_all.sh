#!/usr/bin/env bash
# scripts/push_all.sh — push every submodule, then the umbrella, in that order.
#
# Submodules must land on their remotes before the umbrella, since the umbrella
# commit records gitlink pointers into submodule commits — pushing the umbrella
# first can publish a pointer to a commit nobody else can fetch yet.
#
# For each repo (submodules from .gitmodules, in listed order, then "." last):
#   - skip if the working tree is dirty (uncommitted changes) — refuse, don't stash
#   - skip if there's no upstream tracking branch — refuse, don't guess a remote
#   - skip if already up-to-date (nothing to push)
#   - otherwise `git push` (or just print the command under --dry-run)
#
# Exits non-zero if any repo was dirty, lacked an upstream, or the push itself
# failed — so a clean run means everything that had commits is now pushed.
#
# Usage:
#   scripts/push_all.sh            # push everything that needs it
#   scripts/push_all.sh --dry-run  # print what would be pushed, push nothing
#   scripts/push_all.sh --fetch    # `git fetch` each repo first for accurate ahead/behind

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || { echo "cannot cd to repo root" >&2; exit 2; }

DRY_RUN=0
DO_FETCH=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --fetch) DO_FETCH=1 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

if [ -t 1 ]; then USE_COLOR=1; else USE_COLOR=0; fi
BOLD=$'\033[1m'; RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; RST=$'\033[0m'
paint() { if [ "$USE_COLOR" = 1 ] && [ -n "$1" ]; then printf '%s%s%s' "$1" "$2" "$RST"; else printf '%s' "$2"; fi; }

# Submodule paths straight out of .gitmodules, in file order; umbrella (".") pushed last.
SUBS=$(git config --file .gitmodules --get-regexp '\.path$' 2>/dev/null | awk '{print $2}')
REPOS="$SUBS ."

problems=0
pushed=0

for repo in $REPOS; do
    if [ "$repo" = "." ]; then name="upsilonumbrella (umbrella)"; else name="$repo"; fi

    if [ ! -e "$repo/.git" ]; then
        paint "$RED" "[$name] uninitialized — run: git submodule update --init"; echo
        problems=$((problems + 1)); continue
    fi

    [ "$DO_FETCH" = 1 ] && git -C "$repo" fetch -q --all 2>/dev/null

    dirty=$(git -C "$repo" status --porcelain 2>/dev/null | grep -c . || true)
    if [ "$dirty" != 0 ]; then
        paint "$RED" "[$name] dirty working tree ($dirty changed) — commit or stash before pushing"; echo
        problems=$((problems + 1)); continue
    fi

    if ! git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
        paint "$RED" "[$name] no upstream tracking branch — refusing to guess a remote"; echo
        problems=$((problems + 1)); continue
    fi

    set -- $(git -C "$repo" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null)
    behind=${1:-0}; ahead=${2:-0}

    if [ "$ahead" = 0 ]; then
        paint "$GRN" "[$name] up-to-date, nothing to push"; echo
        continue
    fi

    if [ "$behind" != 0 ]; then
        paint "$RED" "[$name] diverged (ahead $ahead / behind $behind) — pull/rebase first"; echo
        problems=$((problems + 1)); continue
    fi

    branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)

    if [ "$DRY_RUN" = 1 ]; then
        paint "$YEL" "[$name] would push $branch ($ahead commit(s) ahead): git -C $repo push"; echo
        continue
    fi

    paint "$BOLD" "[$name] pushing $branch ($ahead commit(s) ahead)..."; echo
    if git -C "$repo" push; then
        pushed=$((pushed + 1))
    else
        paint "$RED" "[$name] push failed"; echo
        problems=$((problems + 1))
    fi
done

echo
if [ "$problems" = 0 ]; then
    paint "$GRN" "OK — $pushed repo(s) pushed, rest already up-to-date."; echo
    exit 0
else
    paint "$YEL" "$problems repo(s) need attention (dirty / no-upstream / diverged / push failed)."; echo
    exit 1
fi
