"""Runtime settings — values that change without a deploy.

PRD Feature 5 requires the step-up thresholds to be configurable without a deploy, and
PRD §13 lists their values as open questions. Anything in that shape belongs here.

Reads take a live ``Connection`` so a value is read inside the transaction that acts on
it: a threshold that changes mid-approval must not produce an approval checked against
one value and recorded against another.
"""

from __future__ import annotations

import json
import uuid
from typing import Any

from sqlalchemy import text
from sqlalchemy.engine import Connection

from iwp.money import Money

__all__ = ["SettingNotFound", "get_int", "get_money", "get_setting", "set_setting"]


class SettingNotFound(KeyError):
    """No such runtime setting. Never silently defaulted — a missing threshold would
    quietly become "no threshold"."""


def get_setting(conn: Connection, key: str) -> Any:
    value = conn.execute(
        text("SELECT value FROM runtime_setting WHERE key = :k"), {"k": key}
    ).scalar_one_or_none()
    if value is None:
        raise SettingNotFound(key)
    return value


def get_int(conn: Connection, key: str) -> int:
    value = get_setting(conn, key)
    if not isinstance(value, int) or isinstance(value, bool):
        raise TypeError(f"setting {key!r} is {type(value).__name__}, expected int")
    return value


def get_money(conn: Connection, key: str, currency: str) -> Money:
    """A money setting, stored as integer minor units like everything else."""
    return Money(get_int(conn, key), currency)


def set_setting(
    conn: Connection,
    key: str,
    value: Any,
    *,
    changed_by: uuid.UUID | None = None,
    description: str | None = None,
) -> None:
    """Change a setting, recording what it was.

    The history row is written in the same transaction as the change, so a value can
    always be explained by the row that produced it.
    """
    old = conn.execute(
        text("SELECT value FROM runtime_setting WHERE key = :k"), {"k": key}
    ).scalar_one_or_none()

    conn.execute(
        text(
            """
            INSERT INTO runtime_setting (key, value, description, updated_by, updated_at)
            VALUES (:k, CAST(:v AS JSONB), COALESCE(:d, ''), :by, now())
            ON CONFLICT (key) DO UPDATE
            SET value = EXCLUDED.value,
                description = COALESCE(NULLIF(EXCLUDED.description, ''),
                                       runtime_setting.description),
                updated_by = EXCLUDED.updated_by,
                updated_at = now()
            """
        ),
        {"k": key, "v": json.dumps(value), "d": description, "by": changed_by},
    )
    conn.execute(
        text(
            """
            INSERT INTO runtime_setting_history (key, old_value, new_value, changed_by)
            VALUES (:k, CAST(:old AS JSONB), CAST(:new AS JSONB), :by)
            """
        ),
        {
            "k": key,
            "old": json.dumps(old) if old is not None else None,
            "new": json.dumps(value),
            "by": changed_by,
        },
    )
