from __future__ import annotations

import asyncio
from collections import defaultdict
from pathlib import Path

from fastapi import HTTPException

# One lock per project: the board scripts run `git add tasks && git commit` on the
# shared main checkout, so two simultaneous GUI actions could race the git index.
# (Races with a terminal-side agent remain possible but end in a clean script error.)
_locks: dict[str, asyncio.Lock] = defaultdict(asyncio.Lock)

ALLOWED = {"claim.sh", "approve.sh", "reject.sh", "unclaim.sh"}


async def run_script(repo: Path, script: str, args: list[str]) -> dict:
    """Run one of the repo's own tasks/*.sh scripts and relay its output verbatim.

    The GUI is a skin over the scripts — never reimplement their logic, so a
    failure here reads exactly like it would in a terminal.
    """
    if script not in ALLOWED:
        raise HTTPException(400, f"script '{script}' is not an allowed board action")
    path = repo / "tasks" / script
    if not path.exists():
        raise HTTPException(409, f"{path} missing — re-run `helm init`/`helm update`")

    async with _locks[str(repo)]:
        proc = await asyncio.create_subprocess_exec(
            str(path), *args, cwd=repo,
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
        try:
            stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=60)
        except asyncio.TimeoutError:
            proc.kill()
            raise HTTPException(504, f"{script} timed out after 60s")

    result = {"ok": proc.returncode == 0, "exit_code": proc.returncode,
              "stdout": stdout.decode(errors="replace"),
              "stderr": stderr.decode(errors="replace")}
    if not result["ok"]:
        # Script refusals (CANNOT CLAIM, wrong status, unmerged PR) are state
        # conflicts, not server errors — surface the script's own words.
        raise HTTPException(409, detail=result)
    return result
