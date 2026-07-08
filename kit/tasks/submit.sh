#!/usr/bin/env bash
# Submit a claimed task for review.  Usage: ./submit.sh <task-id> [--local]
#
# Commits any pending work on the task branch, pushes it, and opens a PR
# (when `gh` is installed). Merging is gated on the human approving the PR.
# --local: skip push/PR (offline / smoke-testing); review happens via git diff.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"

id="${1:?usage: submit.sh <task-id> [--local]}"
local_mode="${2:-}"

f="$(find_task "$id")"
[ -n "$f" ] || die "unknown task: $id"
wt="$WORKTREES/$id"
[ -d "$wt" ] || die "no worktree for $id — claim it first (./claim.sh $id <agent>)"
st="$(fm "$f" status)"
case "$st" in
  in-progress|changes-requested) ;;
  *) die "cannot submit from status '$st'" ;;
esac

title="$(fm "$f" title)"

# Commit anything still pending in the worktree (agents may have committed already).
if [ -n "$(git -C "$wt" status --porcelain)" ]; then
  git -C "$wt" add -A
  git -C "$wt" commit -q -m "$id: $title"
fi

# Refuse an empty submission.
commits="$(git -C "$wt" log --oneline "$MAIN_BRANCH..task/$id")"
[ -n "$commits" ] || die "no commits on task/$id — nothing to submit"
echo "Commits on task/$id:"; echo "$commits" | sed 's/^/  /'

# If main moved since the claim, ask for a rebase so the merge stays clean.
if [ "$(git -C "$ROOT" rev-parse "$MAIN_BRANCH")" != "$(git -C "$wt" merge-base "$MAIN_BRANCH" "task/$id")" ]; then
  echo "WARNING: $MAIN_BRANCH has moved since this task was claimed."
  echo "         Rebase before merge:  git -C $wt rebase $MAIN_BRANCH"
fi

review_hint="review locally:  git diff $MAIN_BRANCH...task/$id"
if [ "$local_mode" != "--local" ] && has_origin; then
  git -C "$wt" push -u origin "task/$id"
  if has_gh; then
    pr_url="$( (cd "$wt" && gh pr create --base "$MAIN_BRANCH" --head "task/$id" \
      --title "$id: $title" \
      --body "Implements task \`$id\` — see \`$f\`.") )"
    review_hint="PR opened: $pr_url"
  else
    # Derive the web URL from origin (handles both git@ and https remotes) so the
    # printed link is clickable even without the gh CLI.
    web="$(git -C "$ROOT" remote get-url origin | sed -E 's#^git@github\.com:#https://github.com/#; s#\.git$##')"
    review_hint="branch pushed — open the PR (install gh to automate): ${web}/pull/new/task/$id"
  fi
fi

sed_i "$f" \
  -e "s/^status:.*/status: in-review/" \
  -e "s/^completed_at:.*/completed_at: $(now)/"
board_commit "[board] $id → in-review"

echo "SUBMITTED $id → in-review"
echo "  $review_hint"
echo "Gate: run the safety/quality reviewer before merging  →  /no-mistakes $id"
echo "Human: approve & merge the PR, then run  $TASKS_DIR/approve.sh $id"
echo "       or request changes with          $TASKS_DIR/reject.sh $id \"reason\""
