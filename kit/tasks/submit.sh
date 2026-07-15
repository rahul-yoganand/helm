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
feat="$(task_feature "$f")"
branch="$(task_branch "$f")"
wt="$(task_wt "$f")"
[ -d "$wt" ] || die "no worktree for $id — claim it first (./claim.sh $id <agent>)"
st="$(fm "$f" status)"
case "$st" in
  in-progress|changes-requested) ;;
  *) die "cannot submit from status '$st'" ;;
esac

title="$(fm "$f" title)"

# A feature ships as ONE complete PR: every task of the feature must be
# implemented (claimed + worked in the shared worktree) before submitting.
# All of the feature's claimed tasks go to in-review together below.
submit_files="$f"
if [ -n "$feat" ]; then
  remaining="$(feature_ids_in "$feat" backlog)"
  [ -z "$remaining" ] || die "feature '$feat' is incomplete — still in backlog: ${remaining}(claim and implement them in $wt first; a feature opens ONE PR when whole)"
  submit_files=""
  for sf in $(feature_files "$feat"); do
    case "$(fm "$sf" status)" in
      in-progress|changes-requested) submit_files="$submit_files $sf" ;;
    esac
  done
fi

# Commit anything still pending in the worktree (agents may have committed already).
if [ -n "$(git -C "$wt" status --porcelain)" ]; then
  git -C "$wt" add -A
  git -C "$wt" commit -q -m "$id: $title"
fi

# Refuse an empty submission.
commits="$(git -C "$wt" log --oneline "$MAIN_BRANCH..$branch")"
[ -n "$commits" ] || die "no commits on $branch — nothing to submit"
echo "Commits on $branch:"; echo "$commits" | sed 's/^/  /'

# If main moved since the claim, merge it into the task branch now so the PR
# lands conflict-free. On a conflict, stop here: the calling agent resolves
# it in the worktree (using judgment — matching model, matching field types,
# etc. — not a script), commits, and re-runs this script.
if [ "$(git -C "$ROOT" rev-parse "$MAIN_BRANCH")" != "$(git -C "$wt" merge-base "$MAIN_BRANCH" "$branch")" ]; then
  echo "$MAIN_BRANCH has moved since this work was claimed — merging it into $branch..."
  if ! git -C "$wt" merge "$MAIN_BRANCH" --no-edit -q; then
    echo
    echo "MERGE CONFLICT merging $MAIN_BRANCH into $branch:"
    git -C "$wt" diff --name-only --diff-filter=U | sed 's/^/  /'
    echo
    echo "Resolve the conflicts in $wt (remove markers, pick/blend the right content —"
    echo "check whether the conflicting file was already independently duplicated by"
    echo "another task; if so the two copies are usually functionally identical and"
    echo "the choice is cosmetic), then:"
    echo "  git -C $wt add <resolved files>"
    echo "  git -C $wt commit --no-edit"
    echo "  $TASKS_DIR/submit.sh $id $local_mode   # re-run to push/open the PR"
    exit 1
  fi
  echo "merged cleanly."
fi

# PR title/body: one task, or the whole feature's task list.
pr_title="$id: $title"
pr_body="Implements task \`$id\` — see \`${f#$ROOT/}\`."
submitted_ids="$id"
if [ -n "$feat" ]; then
  submitted_ids=""
  pr_body="Implements feature \`$feat\` (one PR for the complete feature):"
  for sf in $submit_files; do
    sid="$(basename "$sf" .md)"
    submitted_ids="$submitted_ids$sid "
    pr_body="$pr_body
- \`$sid\` — $(fm "$sf" title) (\`${sf#$ROOT/}\`)"
  done
  submitted_ids="${submitted_ids% }"
  pr_title="feat($feat): $submitted_ids"
fi

review_hint="review locally:  git diff $MAIN_BRANCH...$branch"
if [ "$local_mode" != "--local" ] && has_origin; then
  git -C "$wt" push -u origin "$branch"
  if has_gh; then
    pr_url="$( (cd "$wt" && gh pr create --base "$MAIN_BRANCH" --head "$branch" \
      --title "$pr_title" \
      --body "$pr_body") )"
    review_hint="PR opened: $pr_url"
  else
    # Derive the web URL from origin (handles both git@ and https remotes) so the
    # printed link is clickable even without the gh CLI.
    web="$(git -C "$ROOT" remote get-url origin | sed -E 's#^git@github\.com:#https://github.com/#; s#\.git$##')"
    review_hint="branch pushed — open the PR (install gh to automate): ${web}/pull/new/$branch"
  fi
fi

for sf in $submit_files; do
  sed_i "$sf" \
    -e "s/^status:.*/status: in-review/" \
    -e "s/^completed_at:.*/completed_at: $(now)/"
done
board_commit "[board] $submitted_ids → in-review"

echo "SUBMITTED $submitted_ids → in-review"
echo "  $review_hint"
echo "Gate: run the safety/quality reviewer before merging  →  /no-mistakes $id"
echo "Human: approve & merge the PR, then run  $TASKS_DIR/approve.sh $id"
echo "       or request changes with          $TASKS_DIR/reject.sh $id \"reason\""
