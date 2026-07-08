from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path


def _run(args: list[str], cwd: Path, timeout: int = 10) -> str:
    try:
        out = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return out.stdout if out.returncode == 0 else ""
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return ""


def worktrees(repo: Path) -> list[dict]:
    """Task worktrees under .worktrees/ with their branch and last commit."""
    result = []
    block: dict = {}
    for line in _run(["git", "worktree", "list", "--porcelain"], repo).splitlines() + [""]:
        if not line:
            if block.get("worktree", "").startswith(str(repo / ".worktrees")):
                path = Path(block["worktree"])
                branch = block.get("branch", "").removeprefix("refs/heads/")
                last = _run(["git", "log", "-1", "--format=%h %s (%cr)", branch], repo).strip()
                result.append({"task_id": path.name, "path": str(path),
                               "branch": branch, "last_commit": last})
            block = {}
        else:
            key, _, val = line.partition(" ")
            block[key] = val
    return result


def activity(repo: Path, limit: int = 50) -> list[dict]:
    """The [board] commit stream on the main checkout = the board's audit log."""
    out = _run(["git", "log", f"--grep=^\\[board\\]", "-n", str(limit),
                "--format=%h%x09%cI%x09%s"], repo)
    return [dict(zip(("sha", "date", "message"), l.split("\t", 2)))
            for l in out.splitlines()]


# gh is slow (~0.5-2s per call); cache per (repo, task) briefly and only query
# from the task-detail endpoint, never from the board list.
_pr_cache: dict[tuple[str, str], tuple[float, dict | None]] = {}


def pr_status(repo: Path, task_id: str, ttl: float) -> dict | None:
    key = (str(repo), task_id)
    hit = _pr_cache.get(key)
    if hit and time.monotonic() - hit[0] < ttl:
        return hit[1]
    out = _run(["gh", "pr", "view", f"task/{task_id}", "--json", "state,url,title"],
               repo, timeout=8)
    pr = None
    if out:
        try:
            pr = json.loads(out)
        except json.JSONDecodeError:
            pr = None
    _pr_cache[key] = (time.monotonic(), pr)
    return pr


def gh_ok(repo: Path) -> bool:
    try:
        return subprocess.run(["gh", "auth", "status"], cwd=repo, capture_output=True,
                              timeout=8).returncode == 0
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False
