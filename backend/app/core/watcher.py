from __future__ import annotations

import asyncio
import contextlib
import json
from pathlib import Path

from fastapi import WebSocket
from watchfiles import awatch


class BoardWatcher:
    """Per-project file watcher fanning thin change events out to websockets.

    Events are just {"type": "board_changed" | "worktrees_changed"}; clients
    refetch over REST. The watch task starts with the first subscriber and
    stops with the last, so an idle backend watches nothing.
    """

    def __init__(self) -> None:
        self._subs: dict[str, set[WebSocket]] = {}
        self._tasks: dict[str, asyncio.Task] = {}

    async def subscribe(self, proj: str, repo: Path, ws: WebSocket) -> None:
        self._subs.setdefault(proj, set()).add(ws)
        if proj not in self._tasks:
            self._tasks[proj] = asyncio.create_task(self._watch(proj, repo))

    async def unsubscribe(self, proj: str, ws: WebSocket) -> None:
        subs = self._subs.get(proj, set())
        subs.discard(ws)
        if not subs and proj in self._tasks:
            self._tasks.pop(proj).cancel()

    async def _watch(self, proj: str, repo: Path) -> None:
        tasks_dir = repo / "tasks"
        wt_dir = repo / ".worktrees"

        def keep(_change, path: str) -> bool:
            p = Path(path)
            if str(p).startswith(str(tasks_dir)):
                return p.suffix == ".md"
            # For .worktrees only top-level add/remove matters (a claim or a
            # cleanup); file churn inside a worktree while an agent works is noise.
            return p.parent == wt_dir
        watch_paths = [p for p in (tasks_dir, wt_dir) if p.exists()] or [tasks_dir.parent]
        with contextlib.suppress(asyncio.CancelledError):
            async for changes in awatch(*watch_paths, watch_filter=keep, step=300):
                kinds = {"worktrees_changed" if Path(p).parent == wt_dir else "board_changed"
                         for _, p in changes}
                for kind in kinds:
                    await self._broadcast(proj, {"type": kind})

    async def _broadcast(self, proj: str, event: dict) -> None:
        dead = []
        for ws in self._subs.get(proj, set()):
            try:
                await ws.send_text(json.dumps(event))
            except Exception:
                dead.append(ws)
        for ws in dead:
            self._subs[proj].discard(ws)


watcher = BoardWatcher()
