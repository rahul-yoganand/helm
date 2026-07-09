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

## Install

```bash
git clone https://github.com/<you>/helm.git
cd helm && ./install.sh          # symlinks `helm` onto PATH (~/.local/bin by default)
```

`helm` is now a global command — run it from inside *any* project, no need to `cd` here
first. The symlink points at this checkout, so `git pull` picks up updates with no
reinstall step.

## Quickstart

```bash
helm init ~/Projects/MyRepo --preset default     # install the workflow into a target repo
cd ~/Projects/MyRepo
git add tasks .claude docs CLAUDE.md AGENTS.md .helm-kit.json && git commit -m "Install Helm"
cp tasks/_TEMPLATE.md tasks/phase-0/T-001.md && $EDITOR tasks/phase-0/T-001.md
```

Then open a Claude Code session in the target repo and say "run the next ready task" (or
"run the next two ready tasks in parallel") — the firstmate claims, spawns crew, and
reports back. Optionally run the dashboard:

```bash
cd backend && pip install -r requirements.txt && uvicorn app.main:app --port 8642
cd frontend && flutter run -d macos              # the dashboard
```

### Customizing crew, reviewer, and researcher per project

`helm init` stamps `.claude/agents/<persona>.md`, `.claude/agents/reviewer.md`, and
`.claude/agents/researcher.md` into the target repo from the kit's templates + the chosen
preset (`kit/presets/*.json` — pick one, write your own, or pass a path). These are plain
files in the target repo after install: edit them freely to fit the project (stack notes,
safety rules, review checklist, extra personas). `helm update <repo>` re-stamps only the
kit files you *haven't* locally modified, so customizations are never clobbered — it tells
you exactly which files it skipped.

To add a new preset, copy `kit/presets/default.json` and adjust `personas` (one crew
member per `area`), `safety_context`/`safety_rules` (what the reviewer treats as
Priority-1), and `arch_notes` (what the reviewer's lint pass checks).
