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

feat="$(task_feature "$f")"
featdir="$(task_feature_dir "$f")"
branch="$(task_branch "$f")"
wt="$(task_wt "$f")"

mkdir -p "$WORKTREES"
if [ -n "$feat" ] && git -C "$ROOT" rev-parse --verify -q "$branch" >/dev/null; then
  # Feature continuation: the shared feat/<slug> branch already exists, so this
  # task joins a feature already being worked. Up to 3 crew agents may share a
  # feature's worktree (they should stay on disjoint files — within-feature
  # depends_on ordering is the firstmate's job); a 4th agent is refused.
  owners="$(feature_owners "$featdir")"
  if ! printf '%s\n' "$owners" | grep -qx "$agent"; then
    n="$(printf '%s\n' "$owners" | grep -c . || true)"
    [ "$n" -lt 3 ] || die "CANNOT CLAIM: feature '$feat' already has 3 agents ($(echo $owners | tr '\n' ' ')) — the per-feature crew cap"
  fi
  [ -d "$wt" ] || die "branch $branch exists but its worktree is gone — unclaim a task of feature '$feat' to reset, or repair manually"
else
  # --- Atomic lock: branch creation fails if any other agent claimed first. ---
  if ! git -C "$ROOT" worktree add -b "$branch" "$wt" "$MAIN_BRANCH" >/dev/null 2>&1; then
    die "CANNOT CLAIM: $branch branch already exists (another agent won the race) — pick another (./next.sh)"
  fi
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
  worktree: $wt
  branch:   $branch
Work ONLY inside the worktree. Commit on the branch (never on $MAIN_BRANCH).
EOF
if [ -n "$feat" ]; then
  cat <<EOF
FEATURE '$feat': all of this feature's tasks are worked HERE (up to 3 crew may
share this worktree — stay on your task's files). Claim each task with
$TASKS_DIR/claim.sh before starting it. Submit ONCE — after the feature's LAST
task is implemented — with: $TASKS_DIR/submit.sh $id   (one PR for the whole feature)
Remaining tasks in this feature (backlog): $(feature_ids_in "$featdir" backlog)
EOF
else
  echo "When done: $TASKS_DIR/submit.sh $id"
fi
