#!/usr/bin/env bash
# Collect the facts a session handoff needs. Read-only: never commits, stashes or resets.
#
# Usage: gather.sh [root-dir]        (default: current directory)
# Env:   HANDOFF_BASE=origin/develop  force the base branch to compare against
#        HANDOFF_FETCH=0              skip `git fetch` (offline / slow remotes)
#
# Finds the git repo at root-dir plus any git repos one level below it,
# so it works for a single repo and for a multi-repo workspace alike.

set -u
ROOT="${1:-$PWD}"
cd "$ROOT" || { echo "cannot cd to $ROOT"; exit 1; }
ROOT=$(pwd -P)
TODAY=$(date +%F)
echo "# handoff facts  root=$ROOT  at=$(date '+%F %H:%M')"

repos=""
top=$(git rev-parse --show-toplevel 2>/dev/null) && repos="$top"
for d in */; do
  d="${d%/}"
  [ -e "$d/.git" ] && repos="$repos
$ROOT/$d"
done
repos=$(printf '%s\n' "$repos" | sed '/^$/d' | sort -u)

if [ -z "$repos" ]; then
  echo "(no git repository found at or directly below $ROOT)"
fi

base_ref() {
  local r=$1 b c
  if [ -n "${HANDOFF_BASE:-}" ]; then echo "$HANDOFF_BASE"; return; fi
  # On a long-lived branch itself, compare with its own remote copy.
  c=$(git -C "$r" branch --show-current 2>/dev/null)
  case "$c" in main|master|develop|dev)
    git -C "$r" rev-parse -q --verify "origin/$c" >/dev/null && { echo "origin/$c"; return; } ;;
  esac
  # Feature branch: prefer a develop-style integration branch, then the remote default branch.
  for c in origin/develop origin/dev; do
    git -C "$r" rev-parse -q --verify "$c" >/dev/null && { echo "$c"; return; }
  done
  b=$(git -C "$r" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)
  [ -n "$b" ] && { echo "$b"; return; }
  for c in origin/main origin/master; do
    git -C "$r" rev-parse -q --verify "$c" >/dev/null && { echo "$c"; return; }
  done
}

printf '%s\n' "$repos" | while IFS= read -r r; do
  [ -n "$r" ] || continue
  if [ "${HANDOFF_FETCH:-1}" != "0" ] && git -C "$r" remote get-url origin >/dev/null 2>&1; then
    GIT_TERMINAL_PROMPT=0 git -C "$r" fetch -q --no-tags origin 2>/dev/null \
      || echo "(fetch failed for $r — ahead/behind may be stale)"
  fi

  branch=$(git -C "$r" branch --show-current 2>/dev/null)
  [ -n "$branch" ] || branch="(detached $(git -C "$r" rev-parse --short HEAD 2>/dev/null))"
  base=$(base_ref "$r")
  pending=$(git -C "$r" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  stash=$(git -C "$r" stash list 2>/dev/null | wc -l | tr -d ' ')
  ahead=-; behind=-
  if [ -n "$base" ] && git -C "$r" rev-parse -q --verify HEAD >/dev/null; then
    ahead=$(git -C "$r" rev-list --count "$base..HEAD" 2>/dev/null)
    behind=$(git -C "$r" rev-list --count "HEAD..$base" 2>/dev/null)
  fi
  unpushed=-
  git -C "$r" rev-parse -q --verify '@{u}' >/dev/null 2>&1 \
    && unpushed=$(git -C "$r" rev-list --count '@{u}..HEAD' 2>/dev/null)

  # Skip repos with nothing to hand off.
  if [ "$pending$stash$ahead$behind" = "0000" ] && { [ "$unpushed" = "0" ] || [ "$unpushed" = "-" ]; }; then
    continue
  fi

  name="${r#"$ROOT"/}"; [ "$r" = "$ROOT" ] && name="$(basename "$r") (root)"
  echo
  echo "## $name  branch=$branch  base=${base:-?}  ahead=$ahead behind=$behind  unpushed=$unpushed  uncommitted=$pending  stash=$stash"

  if [ "$pending" != "0" ]; then
    echo "### uncommitted (count by area)"
    git -C "$r" status --porcelain | cut -c4- | sed 's/.* -> //' \
      | awk -F/ '{ print (NF > 2 ? $1 "/" $2 : $1) }' | sort | uniq -c | sort -rn | head -15
  fi
  if [ -n "$base" ] && [ "$ahead" != "0" ] && [ "$ahead" != "-" ]; then
    echo "### commits not in $base"
    git -C "$r" log --oneline "$base..HEAD" | head -15
  fi
  wt=$(git -C "$r" worktree list 2>/dev/null | wc -l | tr -d ' ')
  if [ "$wt" -gt 1 ]; then
    echo "### worktrees"
    git -C "$r" worktree list
  fi
  if command -v gh >/dev/null 2>&1 && git -C "$r" remote get-url origin 2>/dev/null | grep -q github; then
    prs=$(cd "$r" && gh pr list --author @me --state open --limit 10 \
      --json number,title,headRefName,isDraft \
      --jq '.[] | "#\(.number) \(if .isDraft then "draft" else "open" end) [\(.headRefName)] \(.title)"' 2>/dev/null)
    merged=$(cd "$r" && gh pr list --author @me --state merged --search "merged:>=$TODAY" --limit 10 \
      --json number,title --jq '.[] | "#\(.number) merged \(.title)"' 2>/dev/null)
    if [ -n "$prs$merged" ]; then
      echo "### my PRs (open + merged today)"
      [ -n "$prs" ] && echo "$prs"
      [ -n "$merged" ] && echo "$merged"
    fi
  fi
done

echo
echo "## previous handoffs in project"
if [ -d "$ROOT/.claude/handoffs" ]; then
  ls -t "$ROOT"/.claude/handoffs/*.md 2>/dev/null | head -3
else
  echo "(none in $ROOT/.claude/handoffs)"
fi
