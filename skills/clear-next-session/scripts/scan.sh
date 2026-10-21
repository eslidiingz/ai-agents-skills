#!/usr/bin/env bash
# List next-session handoff files with the facts needed to decide what to clear.
# Read-only: never moves or deletes anything.
#
# Usage: scan.sh <dir> [<dir> ...]
#   Each dir is a place handoffs live: a memory directory and/or <project>/.claude/handoffs.
#
# Output, one block per directory, newest first:
#   <file>  date=<YYYY-MM-DD>  age=<N>d  newest=<yes|no>
#     prs: owner/repo#N=MERGED ...   (needs `gh`; UNKNOWN when it can't be checked)
#     bare-refs: #N ...              (PR numbers without a repo — can't be checked)

set -u
[ $# -gt 0 ] || { echo "usage: scan.sh <dir> [<dir> ...]"; exit 1; }

has_gh=0
command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 && has_gh=1

to_epoch() { date -j -f %F "$1" +%s 2>/dev/null || date -d "$1" +%s 2>/dev/null; }
mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null; }
today=$(to_epoch "$(date +%F)")

pr_state() {
  [ "$has_gh" = 1 ] || { echo UNKNOWN; return; }
  gh pr view "$2" --repo "$1" --json state -q .state 2>/dev/null || echo UNKNOWN
}

[ "$has_gh" = 1 ] || echo "(gh not available or not logged in — PR states will be UNKNOWN)"

for dir in "$@"; do
  echo
  echo "## $dir"
  [ -d "$dir" ] || { echo "(not found)"; continue; }

  # date<TAB>seq<TAB>path, newest first. Date comes from the file name, else from mtime;
  # seq is the -2, -3 … suffix used for several handoffs on one day.
  list=$(for f in "$dir"/next-session-*.md; do
    [ -f "$f" ] || continue
    d=$(basename "$f" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
    [ -n "$d" ] || d=$(date -r "$(mtime "$f")" +%F 2>/dev/null || date -d "@$(mtime "$f")" +%F)
    seq=$(basename "$f" .md | grep -oE -- '-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]+$' | grep -oE '[0-9]+$')
    printf '%s\t%s\t%s\n' "$d" "${seq:-1}" "$f"
  done | sort -t "$(printf '\t')" -k1,1r -k2,2nr)

  [ -n "$list" ] || { echo "(no handoff files)"; continue; }

  first=1
  printf '%s\n' "$list" | while IFS="$(printf '\t')" read -r d _ f; do
    e=$(to_epoch "$d"); age=$(( (today - ${e:-$today} + 43200) / 86400 ))
    newest=no; [ "$first" = 1 ] && newest=yes; first=0
    echo "$(basename "$f")  date=$d  age=${age}d  newest=$newest"

    refs=$( { grep -oE 'github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/pull/[0-9]+' "$f" \
                | sed -E 's#github\.com/([^/]+)/([^/]+)/pull/#\1/\2\##'
              grep -oE '[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#[0-9]+' "$f"; } | sort -u)
    if [ -n "$refs" ]; then
      line=""
      for r in $refs; do line="$line ${r}=$(pr_state "${r%#*}" "${r##*#}")"; done
      echo "  prs:$line"
    fi
    bare=$(grep -oE '(^|[^A-Za-z0-9_./-])#[0-9]+' "$f" | grep -oE '#[0-9]+' | sort -u | tr '\n' ' ')
    if [ -n "$bare" ]; then echo "  bare-refs: $bare"; fi
  done
done
