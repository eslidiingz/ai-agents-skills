#!/usr/bin/env bash
# List next-session handoff files with the facts needed to decide what to clear.
# Read-only: never moves or deletes anything.
#
# Usage: scan.sh <dir> [<dir> ...]
#   Each dir is a place handoffs live: a memory directory and/or <project>/.claude/handoffs.
#
# A stream is one line of work: `stream:` in the file's frontmatter, else the topic slug in
# its name (next-session-<date>-<slug>[-N].md), else "default" for names without a slug.
#
# Output, one block per directory, grouped by stream, newest first:
#   <file>  stream=<slug>  date=<YYYY-MM-DD>  age=<N>d  newest=<yes|no>   (newest within its stream)
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

  # stream<TAB>date<TAB>seq<TAB>path, grouped by stream, newest first. Date comes from the
  # file name, else from mtime; seq is the -2, -3 … suffix for a name that was already taken.
  list=$(for f in "$dir"/next-session-*.md; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .md); rest=${name#next-session-}
    d=$(printf '%s' "$rest" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}')
    if [ -n "$d" ]; then rest=${rest#"$d"}; rest=${rest#-}; else
      d=$(date -r "$(mtime "$f")" +%F 2>/dev/null || date -d "@$(mtime "$f")" +%F); fi
    seq=1; slug=$rest
    if printf '%s' "$rest" | grep -qE '^[0-9]+$'; then seq=$rest; slug=""
    elif printf '%s' "$rest" | grep -qE -- '-[0-9]+$'; then seq=${rest##*-}; slug=${rest%-*}; fi
    fm=$(head -15 "$f" | grep -E '^[[:space:]]*stream:' | head -1 | sed -E 's/^[[:space:]]*stream:[[:space:]]*//; s/[[:space:]"]*$//; s/^"//')
    stream=${fm:-${slug:-default}}
    printf '%s\t%s\t%s\t%s\n' "$stream" "$d" "$seq" "$f"
  done | sort -t "$(printf '\t')" -k1,1 -k2,2r -k3,3nr)

  [ -n "$list" ] || { echo "(no handoff files)"; continue; }

  prev=""
  printf '%s\n' "$list" | while IFS="$(printf '\t')" read -r stream d _ f; do
    e=$(to_epoch "$d"); age=$(( (today - ${e:-$today} + 43200) / 86400 ))
    newest=no; [ "$stream" != "$prev" ] && newest=yes; prev=$stream
    echo "$(basename "$f")  stream=$stream  date=$d  age=${age}d  newest=$newest"

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
