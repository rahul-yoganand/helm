#!/usr/bin/env bash
# Render the task board, grouped by status (read from each task's frontmatter).
# Task files never move — status lives inside the file.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"

for st in backlog in-progress in-review changes-requested done; do
  printf "\n=== %s ===\n" "$st"
  n=0
  for f in "$TASKS_DIR"/phase-*/T-*.md; do
    [ -e "$f" ] || continue
    [ "$(fm "$f" status)" = "$st" ] || continue
    id="$(basename "$f" .md)"
    mark=""
    if [ "$st" = "backlog" ]; then
      if deps_done "$f"; then mark="[READY]"; else mark="[BLOCKED]"; fi
    fi
    owner="$(fm "$f" owner)"
    printf "  %-8s %-10s %-7s %-9s %-60s %s\n" "$id" "$(fm "$f" area)" "$(task_model "$f")" "$mark" "$(fm "$f" title)" "${owner:+@$owner}"
    n=$((n+1))
  done
  [ "$n" -eq 0 ] && echo "  (none)"
done
echo
exit 0
