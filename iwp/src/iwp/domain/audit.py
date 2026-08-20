"""Audit logging.

CLAUDE.md rule 5: every state transition writes an audit log row. The table is
append-only at the database, so an audit row cannot be edited to say something else
later.

The writer takes a live ``Connection`` rather than an ``Engine`` so that the audit row
is written in the *same* transaction as the state change it records. If they were
separate transactions, a crash between them would leave a state change with no audit
trail — which on a financial record is worse than the crash.
"""

from __future__ import annotations

import enum
import uuid
from typing import Any

from sqlalchemy import text
from sqlalchemy.engine import Connection

__all__ = ["ActorKind", "audit_trail", "write_audit"]


class ActorKind(enum.Enum):
    USER = "user"
    SYSTEM = "system"
    PROVIDER = "provider"


def write_audit(
    conn: Connection,
    *,
    action: str,
    entity_type: str,
    entity_id: uuid.UUID,
    actor_id: uuid.UUID | None = None,
    actor_kind: ActorKind = ActorKind.USER,
    assurance_level: str | None = None,
    channel: str | None = None,
    before_state: dict[str, Any] | None = None,
    after_state: dict[str, Any] | None = None,
) -> uuid.UUID:
    """Append one audit row. Returns its id."""
    if actor_kind is ActorKind.USER and actor_id is None:
        raise ValueError("a user action must record which user took it")
    if actor_kind is not ActorKind.USER and actor_id is not None:
        raise ValueError(f"{actor_kind.value} actions have no actor_id")

    import json

    audit_id: uuid.UUID = conn.execute(
        text(
            """
            INSERT INTO audit_log
                (actor_id, actor_kind, action, entity_type, entity_id,
                 assurance_level, channel, before_state, after_state)
            VALUES
                (:actor_id, :actor_kind, :action, :entity_type, :entity_id,
                 :assurance_level, :channel, CAST(:before AS JSONB), CAST(:after AS JSONB))
            RETURNING id
            """
        ),
        {
            "actor_id": actor_id,
            "actor_kind": actor_kind.value,
            "action": action,
            "entity_type": entity_type,
            "entity_id": entity_id,
            "assurance_level": assurance_level,
            "channel": channel,
            "before": json.dumps(before_state) if before_state is not None else None,
            "after": json.dumps(after_state) if after_state is not None else None,
        },
    ).scalar_one()
    return audit_id


def audit_trail(conn: Connection, entity_type: str, entity_id: uuid.UUID) -> list[dict[str, Any]]:
    """Every audit row for one entity, oldest first."""
    rows = (
        conn.execute(
            text(
                """
                SELECT id, actor_id, actor_kind, action, assurance_level, channel,
                       before_state, after_state, created_at
                FROM audit_log
                WHERE entity_type = :t AND entity_id = :i
                ORDER BY created_at, id
                """
            ),
            {"t": entity_type, "i": entity_id},
        )
        .mappings()
        .all()
    )
    return [dict(row) for row in rows]
