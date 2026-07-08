#!/usr/bin/env bash
# Atomically claim a task.  Usage: ./claim.sh <task-id> <agent-id>
#
# The claim IS the creation of branch `task/<id>` (+ its worktree): git ref
# creation is atomic, so if two agents claim simultaneously exactly one wins.
# The loser gets CANNOT CLAIM and must pick another task. The task file itself
# never moves — only its `status:` frontmatter changes.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"

id="${1:?usage: claim.sh <task-id> <agent-id>}"
agent="${2:?usage: claim.sh <task-id> <agent-id>}"

f="$(find_task "$id")"
[ -n "$f" ] || die "unknown task: $id"
st="$(fm "$f" status)"
[ "$st" = "backlog" ] || die "cannot claim: $id has status '$st' (only backlog tasks are claimable)"
deps_done "$f" || die "BLOCKED: $id has unmet dependencies — pick another (./next.sh)"

mkdir -p "$WORKTREES"
# --- Atomic lock: branch creation fails if any other agent claimed first. ---
if ! git -C "$ROOT" worktree add -b "task/$id" "$WORKTREES/$id" "$MAIN_BRANCH" >/dev/null 2>&1; then
  die "CANNOT CLAIM: task/$id branch already exists (another agent won the race) — pick another (./next.sh)"
fi

sed_i "$f" \
  -e "s/^status:.*/status: in-progress/" \
  -e "s/^owner:.*/owner: ${agent}/" \
  -e "s/^claimed_at:.*/claimed_at: $(now)/"
# Commit the claim on main so it survives resets and is visible to every session
# (the branch above is the atomic lock; this makes the status flip durable too).
board_commit "[board] $id → in-progress (owner: $agent)"

if [ "$(fm "$f" kind)" = "epic" ]; then
  echo "NOTE: $id is an EPIC — decompose it into new task files under tasks/phase-*/; do not implement it directly."
fi

cat <<EOF
CLAIMED $id by $agent
  worktree: $WORKTREES/$id
  branch:   task/$id
Work ONLY inside the worktree. Commit on the task branch (never on $MAIN_BRANCH).
When done: $TASKS_DIR/submit.sh $id
EOF
