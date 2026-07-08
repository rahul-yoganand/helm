from __future__ import annotations

import json
from pathlib import Path

from fastapi import HTTPException

from .config import settings


def load() -> dict:
    if not settings.registry_path.exists():
        return {"projects": [], "active": None}
    return json.loads(settings.registry_path.read_text())


def save(reg: dict) -> None:
    settings.registry_path.parent.mkdir(parents=True, exist_ok=True)
    settings.registry_path.write_text(json.dumps(reg, indent=2) + "\n")


def resolve(proj_id: str) -> Path:
    """Registry id -> repo path. Only registered ids are ever accepted over HTTP,
    so a request can never point the backend at an arbitrary filesystem path."""
    for p in load()["projects"]:
        if p["id"] == proj_id:
            path = Path(p["path"])
            if not (path / "tasks").is_dir():
                raise HTTPException(409, f"project '{proj_id}' has no tasks/ board at {path}")
            return path
    raise HTTPException(404, f"unknown project '{proj_id}' — register it with `helm init`")


def set_active(proj_id: str) -> dict:
    reg = load()
    if not any(p["id"] == proj_id for p in reg["projects"]):
        raise HTTPException(404, f"unknown project '{proj_id}'")
    reg["active"] = proj_id
    save(reg)
    return reg
