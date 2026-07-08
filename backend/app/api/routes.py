from __future__ import annotations

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from pydantic import BaseModel

from ..core import actions, board, gitinfo, registry
from ..core.config import settings
from ..core.watcher import watcher

router = APIRouter(prefix="/api/v1")


@router.get("/health")
def health() -> dict:
    return {"status": "ok"}


@router.get("/projects")
def projects() -> dict:
    reg = registry.load()
    for p in reg["projects"]:
        try:
            tasks = board.scan(registry.resolve(p["id"]))
            p["counts"] = {st: sum(1 for t in tasks if t.get("status") == st)
                           for st in board.STATUSES}
        except Exception:
            p["counts"] = None  # missing/uninitialized repo still shows in the list
    return reg


@router.post("/projects/{proj}/activate")
def activate(proj: str) -> dict:
    return registry.set_active(proj)


@router.get("/projects/{proj}/board")
def get_board(proj: str) -> dict:
    repo = registry.resolve(proj)
    return {"tasks": board.scan(repo), "statuses": board.STATUSES}


@router.get("/projects/{proj}/tasks/{task_id}")
def get_task(proj: str, task_id: str) -> dict:
    repo = registry.resolve(proj)
    t = board.detail(repo, task_id)
    wts = {w["task_id"]: w for w in gitinfo.worktrees(repo)}
    t["worktree"] = wts.get(task_id)
    # PR lookup only here (never in the board list): gh is slow.
    t["pr"] = gitinfo.pr_status(repo, task_id, settings.pr_cache_ttl) \
        if t.get("status") in ("in-review", "changes-requested") else None
    return t


@router.get("/projects/{proj}/agents")
def get_agents(proj: str) -> dict:
    repo = registry.resolve(proj)
    owned = {t["id"]: t for t in board.scan(repo) if t.get("owner")}
    wts = gitinfo.worktrees(repo)
    for w in wts:
        t = owned.get(w["task_id"], {})
        w["owner"] = t.get("owner")
        w["status"] = t.get("status")
        w["title"] = t.get("title")
    return {"worktrees": wts, "gh_authenticated": gitinfo.gh_ok(repo)}


@router.get("/projects/{proj}/activity")
def get_activity(proj: str) -> dict:
    return {"events": gitinfo.activity(registry.resolve(proj))}


class ClaimBody(BaseModel):
    agent: str


class ApproveBody(BaseModel):
    local: bool = False


class RejectBody(BaseModel):
    reason: str


class UnclaimBody(BaseModel):
    force: bool = False


@router.post("/projects/{proj}/tasks/{task_id}/claim")
async def claim(proj: str, task_id: str, body: ClaimBody) -> dict:
    return await actions.run_script(registry.resolve(proj), "claim.sh", [task_id, body.agent])


@router.post("/projects/{proj}/tasks/{task_id}/approve")
async def approve(proj: str, task_id: str, body: ApproveBody) -> dict:
    args = [task_id] + (["--local"] if body.local else [])
    return await actions.run_script(registry.resolve(proj), "approve.sh", args)


@router.post("/projects/{proj}/tasks/{task_id}/reject")
async def reject(proj: str, task_id: str, body: RejectBody) -> dict:
    return await actions.run_script(registry.resolve(proj), "reject.sh", [task_id, body.reason])


@router.post("/projects/{proj}/tasks/{task_id}/unclaim")
async def unclaim(proj: str, task_id: str, body: UnclaimBody) -> dict:
    args = [task_id] + (["--force"] if body.force else [])
    return await actions.run_script(registry.resolve(proj), "unclaim.sh", args)


@router.websocket("/projects/{proj}/ws")
async def ws_endpoint(ws: WebSocket, proj: str) -> None:
    repo = registry.resolve(proj)
    await ws.accept()
    await watcher.subscribe(proj, repo, ws)
    try:
        while True:  # inbound messages are ignored; the socket is push-only
            await ws.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        await watcher.unsubscribe(proj, ws)
