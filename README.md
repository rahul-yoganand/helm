# Helm

Standalone, reusable **captain / firstmate / crew** agentic-workflow tool. Stamp a
git-backed markdown task board + Claude Code crew agents into any repo, then watch and
steer it from a desktop dashboard.

**Roles**: captain = you (approve/reject); firstmate = the main Claude Code session in the
target repo (spawns crew, monitors, relays); crew = dev subagents that each claim ONE task,
work in an isolated git worktree, and submit for review; researcher = drafts research briefs
and backlog tasks; reviewer = read-only no-mistakes gate enforced by a PostToolUse hook.

## Parts

- **`kit/`** — the portable workflow (board scripts, agent templates, review-gate hook/skill,
  presets). Source of truth for the board is markdown files in the *target* repo's git —
  no database anywhere.
- **`helm`** — stdlib-only Python CLI: `./helm init <repo> [--preset jarvis|kestrel|default|path.json]`,
  `./helm update <repo>` (re-stamps only files you haven't locally modified), `./helm list`.
- **`backend/`** — FastAPI service: reads any registered repo's board, streams changes over
  WebSocket, and runs board actions by shelling out to that repo's own `tasks/*.sh` scripts.
- **`frontend/`** — Flutter desktop dashboard: kanban board, task detail, agent/worktree
  status, activity feed, claim/approve/reject/unclaim buttons.

## Quickstart

```bash
./helm init ~/Projects/MyRepo --preset default   # install the workflow
cd backend && pip install -r requirements.txt && uvicorn app.main:app --port 8642
cd frontend && flutter run -d macos              # the dashboard
```

Orchestration stays in Claude Code: open a Claude session in the target repo and say
"run the next two ready tasks in parallel" — the dashboard shows it all live.
