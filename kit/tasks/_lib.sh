# Shared helpers for the task board. Sourced by the board scripts — not executable.
#
# Design notes:
# - A task is ONE file (tasks/phase-N/T-XXX.md) that never moves. Its `status:`
#   frontmatter field is the single source of truth and is edited in place.
# - Claim atomicity comes from git: creating branch task/<id> is an atomic ref
#   operation, so two concurrent claimers get exactly one winner.
# - Every claimed task gets its own worktree (.worktrees/<id>), so independent
#   tasks can be worked on in parallel without touching each other's files.

# Resolve the MAIN checkout even when a script is invoked from inside a task
# worktree (worktree's --git-common-dir points at <main-root>/.git).
_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_common="$(git -C "$_here" rev-parse --path-format=absolute --git-common-dir)"
ROOT="$(dirname "$_common")"
TASKS_DIR="$ROOT/tasks"
WORKTREES="$ROOT/.worktrees"
MAIN_BRANCH="$(git -C "$ROOT" branch --show-current)"
[ -n "$MAIN_BRANCH" ] || MAIN_BRANCH=main

die() { echo "ERROR: $*" >&2; exit 1; }
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Read a frontmatter field: fm <file> <key>
fm() { grep -m1 "^$2:" "$1" 2>/dev/null | sed "s/^$2:[[:space:]]*//" || true; }

# Portable in-place sed (works with both GNU and BSD sed).
sed_i() { local f="$1"; shift; local t; t="$(mktemp)"; sed "$@" "$f" >"$t" && mv "$t" "$f"; }

# Locate a task file by id across all phase dirs.
find_task() { ls "$TASKS_DIR"/phase-*/"$1".md 2>/dev/null | head -1 || true; }

# Claude model a task should run on (model: frontmatter). Tasks created before
# model routing existed have no field — default to sonnet, the standard tier.
task_model() { local m; m=$(fm "$1" model); echo "${m:-sonnet}"; }

# All depends_on tasks must have status: done.
deps_done() {
  local deps d df
  deps=$(fm "$1" depends_on | tr -d '[]' | tr ',' ' ')
  for d in $deps; do
    d=$(echo "$d" | xargs); [ -z "$d" ] && continue
    df=$(find_task "$d"); [ -n "$df" ] || return 1
    [ "$(fm "$df" status)" = "done" ] || return 1
  done
  return 0
}

has_origin() { git -C "$ROOT" remote get-url origin >/dev/null 2>&1; }
has_gh() { command -v gh >/dev/null 2>&1; }

# Portable cross-process mutex: `mkdir` is atomic on every POSIX filesystem,
# so "the lock" is just "which process's mkdir won". Deliberately not `flock`
# — macOS ships no flock(1), and this needs zero extra dependencies.
_board_lock() {
  local lockdir="$ROOT/.git/board.lock" tries=0
  until mkdir "$lockdir" 2>/dev/null; do
    tries=$((tries + 1))
    [ "$tries" -le 100 ] || die "board lock held >10s (stale $lockdir from a crashed session?) — if no claim/submit/approve/reject is running, remove it: rmdir $lockdir"
    sleep 0.1
  done
}
_board_unlock() { rmdir "$ROOT/.git/board.lock" 2>/dev/null || true; }

# Durably record a board status change: commit the tasks/ edit on the MAIN
# checkout.  Usage: board_commit "<message>"
#
# WHY this must commit (not just leave a working-tree edit): status: lives in
# the task file. If a claim/submit only `sed`s the file without committing, the
# change is an uncommitted local edit — any `git reset`, `git checkout .`, or
# `git stash` in the main checkout silently reverts it, un-claiming the task so
# another session re-claims it. Committing makes the status the single durable
# source of truth every session reads. Only tasks/ is staged, so unrelated
# working-tree changes are never swept into the board commit.
#
# WHY the lock: claim/submit/approve/reject run concurrently by design (that's
# the whole point of parallel crew). Two concurrent `git commit` calls race on
# .git/index.lock — one loses. The old code masked that with a trailing
# `|| true`, which silently discarded the status edit while the caller still
# printed success. Serializing here (not a bigger redesign) keeps the fix
# small: only mkdir/rmdir are added, everything else behaves identically.
board_commit() {
  _board_lock
  trap _board_unlock EXIT
  git -C "$ROOT" add "$TASKS_DIR"
  if ! git -C "$ROOT" diff --cached --quiet -- "$TASKS_DIR"; then
    git -C "$ROOT" commit -q -m "$1" || die "board commit failed: $1"
  fi
  _board_unlock
  trap - EXIT
}
