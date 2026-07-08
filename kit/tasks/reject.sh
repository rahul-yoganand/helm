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

sed_i "$f" -e "s/^status:.*/status: changes-requested/"
printf '\n- CHANGES REQUESTED %s: %s\n' "$(now)" "$reason" >> "$f"

board_commit "[board] $id → changes-requested"

echo "CHANGES REQUESTED on $id (owner: $(fm "$f" owner) keeps the task)."
echo "Agent: resume in $WORKTREES/$id, address the feedback, then re-run $TASKS_DIR/submit.sh $id"
