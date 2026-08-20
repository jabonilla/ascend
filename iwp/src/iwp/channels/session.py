"""P4.2 — WhatsApp 24-hour session window.

WhatsApp lets a business send arbitrary text only within 24 hours of the user's last
inbound message. Outside that window, only templates the BSP has pre-approved may go
out (PRD Feature 4).

Getting this wrong is not a rejected API call, it is a recipient who never hears back
about their own money request. So the rule is enforced here, once, above every adapter,
and the window is queryable *before* a message is composed — because discovering it
after composing means either sending nothing or sending the wrong thing.

The safe default is closed: no window record means no window.
"""

from __future__ import annotations

import enum
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Final

from sqlalchemy import text
from sqlalchemy.engine import Connection

from iwp.channels.adapter import Channel

__all__ = [
    "SESSION_WINDOW",
    "Deliverability",
    "SessionWindow",
    "SessionWindowClosed",
    "classify_delivery",
    "note_inbound",
    "window_for",
]

SESSION_WINDOW: Final = timedelta(hours=24)


class SessionWindowClosed(Exception):
    """A freeform message was attempted outside an open session window."""


class Deliverability(enum.Enum):
    """How a given notification may be sent right now.

    P4.2 requires every product notification to be classified as one of these before
    it is composed.
    """

    SESSION_ELIGIBLE = "session_eligible"
    """A window is open: freeform or template, whichever reads better."""

    TEMPLATE_REQUIRED = "template_required"
    """No window: only an approved template may go out."""

    NO_WINDOW_CONCEPT = "no_window_concept"
    """SMS, push, and the app have no session rule at all."""


@dataclass(frozen=True, slots=True)
class SessionWindow:
    user_id: uuid.UUID
    channel: Channel
    expires_at: datetime | None

    def is_open(self, now: datetime) -> bool:
        return self.expires_at is not None and now < self.expires_at

    def remaining(self, now: datetime) -> timedelta:
        if self.expires_at is None or now >= self.expires_at:
            return timedelta(0)
        return self.expires_at - now


def window_for(conn: Connection, user_id: uuid.UUID, channel: Channel) -> SessionWindow:
    """The session window for one conversation. Queryable before composing."""
    if not channel.has_session_window:
        return SessionWindow(user_id=user_id, channel=channel, expires_at=None)
    expires_at = conn.execute(
        text(
            """
            SELECT session_expires_at FROM conversation
            WHERE user_id = :u AND channel = :c
            """
        ),
        {"u": user_id, "c": channel.value},
    ).scalar_one_or_none()
    return SessionWindow(user_id=user_id, channel=channel, expires_at=expires_at)


def classify_delivery(
    conn: Connection, user_id: uuid.UUID, channel: Channel, *, now: datetime | None = None
) -> Deliverability:
    """Say how a notification to this person on this channel may be sent."""
    if not channel.has_session_window:
        return Deliverability.NO_WINDOW_CONCEPT
    moment = now or datetime.now(UTC)
    window = window_for(conn, user_id, channel)
    return (
        Deliverability.SESSION_ELIGIBLE
        if window.is_open(moment)
        else Deliverability.TEMPLATE_REQUIRED
    )


def note_inbound(
    conn: Connection,
    user_id: uuid.UUID,
    channel: Channel,
    *,
    now: datetime | None = None,
) -> SessionWindow:
    """Record an inbound message, opening or refreshing the window.

    Called for every inbound message on every channel; on channels without a session
    concept it just records the timestamp. Creates the conversation row if this is the
    first thing we have ever heard from this person on this channel.
    """
    moment = now or datetime.now(UTC)
    expires_at = moment + SESSION_WINDOW if channel.has_session_window else None

    conn.execute(
        text(
            """
            INSERT INTO conversation (user_id, channel, last_inbound_at, session_expires_at)
            VALUES (:u, :c, :now, :expires)
            ON CONFLICT (user_id, channel) DO UPDATE
            SET last_inbound_at = EXCLUDED.last_inbound_at,
                -- Refresh forward only. An out-of-order redelivery of an older message
                -- must not shorten a window that a newer message already extended.
                session_expires_at = GREATEST(
                    conversation.session_expires_at, EXCLUDED.session_expires_at
                ),
                updated_at = now()
            """
        ),
        {"u": user_id, "c": channel.value, "now": moment, "expires": expires_at},
    )
    return window_for(conn, user_id, channel)
