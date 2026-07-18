#!/usr/bin/env bash
# HUMAN ONLY. Request changes on a submitted task.  Usage: ./reject.sh <task-id> "reason"
#
# The task is NOT sent back to backlog: it keeps its owner, branch, and worktree,
# and moves to `changes-requested`. The owning agent resumes in the same worktree,
# addresses the feedback, and re-runs submit.sh (which updates the same PR).
set -euo pipefail
source "$(dirname "$0")/_lib.sh"

id="${1:?usage: reject.sh <task-id> \"reason\"}"
reason="${2:-no reason given}"

f="$(find_task "$id")"
[ -n "$f" ] || die "unknown task: $id"
[ "$(fm "$f" status)" = "in-review" ] || die "cannot reject: $id has status '$(fm "$f" status)' (expected in-review)"
feat="$(task_feature "$f")"
featdir="$(task_feature_dir "$f")"

# Rejecting a feature task rejects the feature's single PR: every in-review
# sibling goes back to changes-requested with the owner and worktree intact.
files="$f"; ids="$id"
if [ -n "$feat" ]; then
  files=""; ids=""
  for sf in $(feature_files "$featdir"); do
    [ "$(fm "$sf" status)" = "in-review" ] || continue
    files="$files $sf"; ids="$ids$(basename "$sf" .md) "
  done
  ids="${ids% }"
fi

for sf in $files; do
  sed_i "$sf" -e "s/^status:.*/status: changes-requested/"
  printf '\n- CHANGES REQUESTED %s: %s\n' "$(now)" "$reason" >> "$sf"
done

board_commit "[board] $ids → changes-requested"

echo "CHANGES REQUESTED on $ids (owner: $(fm "$f" owner) keeps the work)."
echo "Agent: resume in $(task_wt "$f"), address the feedback, then re-run $TASKS_DIR/submit.sh $id"
