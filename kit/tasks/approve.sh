#!/usr/bin/env bash
# HUMAN ONLY. Finalize an approved task.  Usage: ./approve.sh <task-id> [--local]
#
# GitHub mode (default when a remote exists): run AFTER you approved and merged
#   the PR on GitHub — this verifies the merge, fast-forwards main, and cleans up.
#   It REFUSES if the PR isn't merged yet: approval happens on GitHub, not here.
# Local mode (--local, or no remote): running this IS the approval — it merges
#   the task branch into main with --no-ff after you reviewed the diff.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"

id="${1:?usage: approve.sh <task-id> [--local]}"
mode="${2:-}"

f="$(find_task "$id")"
[ -n "$f" ] || die "unknown task: $id"
[ "$(fm "$f" status)" = "in-review" ] || die "cannot approve: $id has status '$(fm "$f" status)' (expected in-review)"
feat="$(task_feature "$f")"
featdir="$(task_feature_dir "$f")"
branch="$(task_branch "$f")"
git -C "$ROOT" rev-parse --verify -q "$branch" >/dev/null || die "branch $branch not found"

# Approving any task of a feature approves the feature's single PR — every
# in-review sibling flips to done together (they shipped in the same diff).
done_ids="$id"
if [ -n "$feat" ]; then
  done_ids="$(feature_ids_in "$featdir" in-review)"; done_ids="${done_ids% }"
fi

if [ "$mode" != "--local" ] && has_origin; then
  git -C "$ROOT" fetch origin
  merged=no
  # Prefer the PR state (robust to squash/rebase merges), fall back to ancestry.
  if has_gh; then
    [ "$(gh pr view "$branch" --json state -q .state 2>/dev/null || true)" = "MERGED" ] && merged=yes
  fi
  if [ "$merged" = no ] && git -C "$ROOT" merge-base --is-ancestor "$branch" "origin/$MAIN_BRANCH" 2>/dev/null; then
    merged=yes
  fi
  [ "$merged" = yes ] || die "PR for $id is NOT merged on origin/$MAIN_BRANCH yet — approve & merge it on GitHub first"
  git -C "$ROOT" pull --ff-only origin "$MAIN_BRANCH" \
    || die "could not fast-forward $MAIN_BRANCH — pull/rebase manually, then re-run"
else
  # Local approval gate: the human running this command is the approval.
  [ "$(git -C "$ROOT" branch --show-current)" = "$MAIN_BRANCH" ] || die "main checkout must be on $MAIN_BRANCH"
  git -C "$ROOT" merge --no-ff "$branch" -m "Merge $branch: $(fm "$f" title)"
fi

# Flip status → done, tear down the worktree/branch, snapshot the board.
finalize_done "$id" "$f" "$branch" "[board] $done_ids approved → done"

echo "APPROVED $done_ids → done. Dependent tasks are now unblocked (./next.sh)."
