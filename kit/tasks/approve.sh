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
branch="task/$id"
git -C "$ROOT" rev-parse --verify -q "$branch" >/dev/null || die "branch $branch not found"

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

sed_i "$f" \
  -e "s/^status:.*/status: done/" \
  -e "s/^approved_at:.*/approved_at: $(now)/"

# Clean up the worktree and branch (force-delete is safe: the work is merged).
git -C "$ROOT" worktree remove "$WORKTREES/$id" 2>/dev/null || git -C "$ROOT" worktree remove --force "$WORKTREES/$id" 2>/dev/null || true
git -C "$ROOT" branch -D "$branch" >/dev/null
has_origin && git -C "$ROOT" push origin --delete "$branch" 2>/dev/null || true

# Snapshot the board state on main (includes any accumulated status flips).
board_commit "[board] $id approved → done"

echo "APPROVED $id → done. Dependent tasks are now unblocked (./next.sh)."
