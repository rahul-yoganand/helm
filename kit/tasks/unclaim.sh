#!/usr/bin/env bash
# Release a claim (crashed agent, mistaken claim).  Usage: ./unclaim.sh <task-id> [--force]
#
# Returns the task to backlog and removes its worktree + branch. Refuses if the
# branch already has commits unless --force is given (those commits are LOST).
set -euo pipefail
source "$(dirname "$0")/_lib.sh"

id="${1:?usage: unclaim.sh <task-id> [--force]}"
force="${2:-}"

f="$(find_task "$id")"
[ -n "$f" ] || die "unknown task: $id"
st="$(fm "$f" status)"
case "$st" in
  in-progress|in-review|changes-requested) ;;
  *) die "cannot unclaim: $id has status '$st'" ;;
esac

feat="$(task_feature "$f")"
branch="$(task_branch "$f")"
if git -C "$ROOT" rev-parse --verify -q "$branch" >/dev/null; then
  if [ -n "$(git -C "$ROOT" log --oneline "$MAIN_BRANCH..$branch" 2>/dev/null)" ] && [ "$force" != "--force" ]; then
    die "$branch has commits — they would be LOST. Re-run with --force to discard, or submit instead."
  fi
  git -C "$ROOT" worktree remove --force "$(task_wt "$f")" 2>/dev/null || true
  git -C "$ROOT" branch -D "$branch" >/dev/null
  has_origin && git -C "$ROOT" push origin --delete "$branch" 2>/dev/null || true
fi

# Unclaiming a feature task tears down the shared feature worktree, so every
# claimed (not-done) sibling goes back to backlog with it.
files="$f"; ids="$id"
if [ -n "$feat" ]; then
  files=""; ids=""
  for sf in $(feature_files "$feat"); do
    case "$(fm "$sf" status)" in backlog|done) continue ;; esac
    files="$files $sf"; ids="$ids$(basename "$sf" .md) "
  done
  ids="${ids% }"
fi

for sf in $files; do
  sed_i "$sf" \
    -e "s/^status:.*/status: backlog/" \
    -e "s/^owner:.*/owner:/" \
    -e "s/^claimed_at:.*/claimed_at:/" \
    -e "s/^completed_at:.*/completed_at:/"
  printf '\n- UNCLAIMED %s\n' "$(now)" >> "$sf"
done
board_commit "[board] $ids → backlog (unclaimed)"

echo "UNCLAIMED $ids → backlog (worktree and branch removed)."
