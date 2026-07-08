"""Helm dashboard backend.

Reads any registered repo's markdown task board (files in git are the source of
truth — no database), streams change events over WebSocket, and runs board
actions by shelling out to that repo's own tasks/*.sh scripts.

Run: uvicorn app.main:app --port 8642 --reload
"""
from __future__ import annotations

from fastapi import FastAPI

from .api.routes import router

app = FastAPI(title="Helm", version="0.1.0")
app.include_router(router)
