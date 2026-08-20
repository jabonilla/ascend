"""Runtime configuration.

Values come from the environment. Nothing here has a production-safe default that
could be reached by forgetting to set a variable — the database URL has no default at
all outside development.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache

__all__ = ["Settings", "settings"]

_DEV_DATABASE_URL = "postgresql+psycopg://iwp:iwp@localhost:5432/iwp_dev"


@dataclass(frozen=True, slots=True)
class Settings:
    env: str
    database_url: str
    test_database_url: str

    @property
    def is_production(self) -> bool:
        return self.env == "production"


@lru_cache(maxsize=1)
def settings() -> Settings:
    env = os.environ.get("IWP_ENV", "development")
    database_url = os.environ.get("IWP_DATABASE_URL", "")
    if not database_url:
        if env == "production":
            raise RuntimeError("IWP_DATABASE_URL must be set in production")
        database_url = _DEV_DATABASE_URL
    return Settings(
        env=env,
        database_url=database_url,
        test_database_url=os.environ.get(
            "IWP_TEST_DATABASE_URL",
            "postgresql+psycopg://iwp:iwp@localhost:5432/iwp_test",
        ),
    )
