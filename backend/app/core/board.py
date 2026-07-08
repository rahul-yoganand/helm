from __future__ import annotations

import re
from pathlib import Path

from fastapi import HTTPException

# Statuses a task file may carry; `blocked` is computed, never stored —
# exactly like tasks/_lib.sh's deps_done().
STATUSES = ["backlog", "in-progress", "in-review", "changes-requested", "done"]

_FM_RE = re.compile(r"^---\n(.*?)\n---\n?", re.DOTALL)


def parse_frontmatter(text: str) -> tuple[dict, str]:
    """Parse the flat `key: value` frontmatter the board uses.

    Hand-rolled on purpose (mirrors _lib.sh's `fm()` grep): the format is flat
    scalars plus one `[a, b]` list, so a YAML dependency would be overkill.
    Returns (fields, body-after-frontmatter).
    """
    m = _FM_RE.match(text)
    if not m:
        return {}, text
    fields: dict = {}
    for line in m.group(1).splitlines():
        if ":" not in line or line.lstrip().startswith("#"):
            continue
        key, _, val = line.partition(":")
        val = val.split("#", 1)[0].strip() if "#" in val else val.strip()
        if key.strip() == "depends_on":
            val = [d.strip() for d in val.strip("[]").split(",") if d.strip()]
        fields[key.strip()] = val
    return fields, text[m.end():]


def task_files(repo: Path) -> list[Path]:
    return sorted((repo / "tasks").glob("phase-*/T-*.md"))


def scan(repo: Path) -> list[dict]:
    """All tasks with computed `blocked` (backlog task with any dep not done)."""
    tasks = []
    for f in task_files(repo):
        fields, _ = parse_frontmatter(f.read_text())
        fields["id"] = fields.get("id") or f.stem
        fields["phase_dir"] = f.parent.name
        tasks.append(fields)
    done = {t["id"] for t in tasks if t.get("status") == "done"}
    known = {t["id"] for t in tasks}
    for t in tasks:
        deps = t.get("depends_on") or []
        t["blocked"] = t.get("status") == "backlog" and any(
            d not in done or d not in known for d in deps
        )
    return tasks


def detail(repo: Path, task_id: str) -> dict:
    for f in task_files(repo):
        if f.stem == task_id:
            fields, body = parse_frontmatter(f.read_text())
            fields["id"] = fields.get("id") or task_id
            fields["phase_dir"] = f.parent.name
            # The "## Agent log" section is where owners append progress notes.
            log = ""
            if "## Agent log" in body:
                log = body.split("## Agent log", 1)[1].lstrip("\n")
            done = {t["id"] for t in scan(repo) if t.get("status") == "done"}
            deps = fields.get("depends_on") or []
            fields["blocked"] = fields.get("status") == "backlog" and any(d not in done for d in deps)
            return {**fields, "body": body, "agent_log": log, "path": str(f.relative_to(repo))}
    raise HTTPException(404, f"unknown task '{task_id}'")
