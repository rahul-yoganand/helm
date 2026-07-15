#!/usr/bin/env bash
# FIRSTMATE path — auto-merge a LOW-RISK task after the reviewer gate passed.
# Usage: ./auto-approve.sh <task-id> <risk> [--local]
#
# This is the ONLY automated merge path, and it is deliberately hard to abuse:
#   1. It is OFF unless `auto_merge.enabled: true` in .helm-kit.json — the captain's
#      kill switch. Flip it off and every task reverts to manual approve.sh.
#   2. It refuses any risk tier other than `low`.
#   3. It INDEPENDENTLY re-scans the diff against the never-auto-merge deny-lists
#      (control-plane files + the project's high-blast-radius globs) and refuses on any
#      hit — no matter what the reviewer or firstmate claimed. The script, not the model,
#      is the final authority, so Claude cannot talk its way to a protected merge.
# On any refusal it exits non-zero and tells the firstmate to route the task to the captain.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"

id="${1:?usage: auto-approve.sh <task-id> <risk> [--local]}"
risk="${2:-}"
mode="${3:-}"

# Soft refusal: not an error in the task, just "not eligible for auto-merge — a human
# must approve it". Exit 2 so the firstmate can distinguish this from a hard failure.
defer() { echo "AUTO-MERGE DECLINED for $id: $* — route to the captain (approve.sh)." >&2; exit 2; }

[ "$(helm_kit_get auto_merge enabled)" = "true" ] || defer "auto-merge is disabled (auto_merge.enabled is not true in .helm-kit.json)"
[ "$risk" = "low" ] || defer "risk tier '${risk:-unset}' is not 'low'"

f="$(find_task "$id")"
[ -n "$f" ] || die "unknown task: $id"
[ "$(fm "$f" status)" = "in-review" ] || die "cannot auto-approve: $id has status '$(fm "$f" status)' (expected in-review)"
feat="$(task_feature "$f")"
branch="$(task_branch "$f")"
git -C "$ROOT" rev-parse --verify -q "$branch" >/dev/null || die "branch $branch not found"

# A feature merges as one PR: every in-review sibling finalizes together.
done_ids="$id"
if [ -n "$feat" ]; then
  done_ids="$(feature_ids_in "$feat" in-review)"; done_ids="${done_ids% }"
fi

# The hard guard: never auto-merge a diff that touches the control plane or a
# high-blast-radius path, regardless of the risk tier passed in.
denied="$(denied_paths "$branch")"
if [ -n "$denied" ]; then
  defer "diff touches protected paths (control-plane or high-blast-radius):
$(printf '%s\n' "$denied" | sed 's/^/      /')"
fi

# Merge. GitHub mode merges the PR via gh; local mode merges the branch directly.
if [ "$mode" != "--local" ] && has_origin; then
  has_gh || defer "no gh CLI available to merge the PR — approve it manually"
  ( cd "$ROOT" && gh pr merge "$branch" --squash ) || defer "gh pr merge failed (branch protection? no open PR?) — approve manually"
  git -C "$ROOT" fetch origin
  git -C "$ROOT" pull --ff-only origin "$MAIN_BRANCH" \
    || die "PR merged but could not fast-forward $MAIN_BRANCH — pull/rebase manually, then re-run finalize"
else
  [ "$(git -C "$ROOT" branch --show-current)" = "$MAIN_BRANCH" ] || die "main checkout must be on $MAIN_BRANCH"
  git -C "$ROOT" merge --no-ff "$branch" -m "Merge $branch: $(fm "$f" title)"
fi

# Supervision trail: one committed line per auto-merge so the captain can audit
# everything that merged without them. Lives under tasks/ so board_commit snapshots it.
merge_sha="$(git -C "$ROOT" rev-parse --short "$MAIN_BRANCH")"
printf '%s\t%s\trisk=%s\t%s\t%s\n' "$(now)" "$done_ids" "$risk" "$merge_sha" "$(fm "$f" title)" >> "$TASKS_DIR/auto-merge.log"

# Flip status → done, tear down the worktree/branch, snapshot the board (+ the log).
finalize_done "$id" "$f" "$branch" "[board] $done_ids auto-merged (risk=$risk) → done"

echo "AUTO-MERGED $done_ids → done (risk=$risk). Logged to tasks/auto-merge.log."
echo "Dependent tasks may now be unblocked (./next.sh)."
