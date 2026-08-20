"""Retry policy for transient database conflicts.

One module, so there is one backoff policy rather than a copy per caller, and so the
guardrail test that forbids floating point on money paths has exactly one allowlisted
exception to point at. Nothing here touches an amount: the only float is a duration in
seconds, which is what ``time.sleep`` takes.
"""

from __future__ import annotations

import random
import time
from typing import Final

from sqlalchemy.exc import DBAPIError

__all__ = [
    "MAX_ATTEMPTS",
    "RETRYABLE_SQLSTATES",
    "backoff_sleep",
    "is_retryable",
    "sqlstate",
]

#: serialization_failure, deadlock_detected, unique_violation.
#:
#: unique_violation is retryable here because on this codebase's write paths it means
#: "another writer got there first with the same idempotency key", and re-entering takes
#: the replay path. Callers that can encounter an *unrelated* unique violation narrow it
#: further before retrying — see ``ledger.posting._is_idempotency_key_conflict``.
RETRYABLE_SQLSTATES: Final = frozenset({"40001", "40P01", "23505"})

MAX_ATTEMPTS: Final = 8

_BASE_DELAY_SECONDS: Final = 0.02


def sqlstate(exc: DBAPIError) -> str | None:
    """The PostgreSQL SQLSTATE behind a SQLAlchemy error, if there is one."""
    return getattr(getattr(exc, "orig", None), "sqlstate", None)


def is_retryable(exc: DBAPIError) -> bool:
    return sqlstate(exc) in RETRYABLE_SQLSTATES


def backoff_sleep(attempt: int) -> None:
    """Sleep before the next attempt, with full jitter.

    Full jitter rather than plain exponential: two transactions that back off by the
    same amount simply recreate their collision on the next attempt.
    """
    time.sleep(random.uniform(0, _BASE_DELAY_SECONDS * (2**attempt)))
