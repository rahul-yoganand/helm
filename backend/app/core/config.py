from __future__ import annotations

from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Backend settings. Override with HELM_* env vars (e.g. HELM_PORT=9000)."""

    model_config = SettingsConfigDict(env_prefix="HELM_")

    port: int = 8642  # not 8000: Kestrel's backend already owns that locally
    registry_path: Path = Path.home() / ".helm" / "projects.json"
    # How long a `gh pr view` result is reused before re-querying (seconds).
    pr_cache_ttl: float = 30.0


settings = Settings()
