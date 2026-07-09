#!/usr/bin/env bash
# List claimable tasks.  Usage: ./next.sh [--area <area>]
#
# READY  = status backlog + all depends_on tasks done (claim the first one).
# RESUME = changes-requested tasks; their owner resumes in the existing worktree.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"

area_filter=""
if [ "${1:-}" = "--area" ]; then area_filter="${2:?usage: next.sh [--area <area>]}"; fi

echo "READY to claim:"
found=0
for f in "$TASKS_DIR"/phase-*/T-*.md; do
  [ -e "$f" ] || continue
  [ "$(fm "$f" status)" = "backlog" ] || continue
  [ -n "$area_filter" ] && [ "$(fm "$f" area)" != "$area_filter" ] && continue
  if deps_done "$f"; then
    printf "  %-8s %-10s %-7s %s\n" "$(basename "$f" .md)" "$(fm "$f" area)" "$(task_model "$f")" "$(fm "$f" title)"
    found=1
  fi
done
[ "$found" -eq 0 ] && echo "  (none — backlog empty, filtered out, or blocked by deps)"

echo
echo "RESUME (changes requested — owner continues in existing worktree):"
found=0
for f in "$TASKS_DIR"/phase-*/T-*.md; do
  [ -e "$f" ] || continue
  [ "$(fm "$f" status)" = "changes-requested" ] || continue
  [ -n "$area_filter" ] && [ "$(fm "$f" area)" != "$area_filter" ] && continue
  printf "  %-8s %-10s %-7s %s (owner: %s)\n" "$(basename "$f" .md)" "$(fm "$f" area)" "$(task_model "$f")" "$(fm "$f" title)" "$(fm "$f" owner)"
  found=1
done
[ "$found" -eq 0 ] && echo "  (none)"
exit 0
