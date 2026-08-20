"""Engine construction and transaction helpers."""

from __future__ import annotations

from collections.abc import Callable, Iterator
from contextlib import contextmanager
from typing import Literal, TypeVar

from sqlalchemy import Engine, create_engine
from sqlalchemy.engine import Connection
from sqlalchemy.exc import DBAPIError

from iwp.config import settings
from iwp.retry import MAX_ATTEMPTS, backoff_sleep, is_retryable

__all__ = ["IsolationLevel", "make_engine", "run_serializable", "transaction"]

T = TypeVar("T")

IsolationLevel = Literal["READ COMMITTED", "REPEATABLE READ", "SERIALIZABLE"]


def make_engine(url: str | None = None, *, echo: bool = False) -> Engine:
    """Build an Engine.

    ``pool_pre_ping`` costs one round trip per checkout and buys us not serving a
    money request over a connection the database has already dropped.
    """
    return create_engine(
        url or settings().database_url,
        echo=echo,
        pool_pre_ping=True,
        future=True,
    )


@contextmanager
def transaction(
    engine: Engine,
    *,
    isolation_level: IsolationLevel = "READ COMMITTED",
) -> Iterator[Connection]:
    """Run a block in one database transaction at the requested isolation level.

    Ledger postings always pass ``SERIALIZABLE``; see ``ledger.posting``.
    """
    with (
        engine.connect().execution_options(isolation_level=isolation_level) as conn,
        conn.begin(),
    ):
        yield conn


def run_serializable(engine: Engine, work: Callable[[Connection], T]) -> T:
    """Run ``work`` in a SERIALIZABLE transaction, retrying transient conflicts.

    This is what a caller uses when a ledger posting has to be atomic with other
    writes: ``ledger.post`` owns isolation and retry for a posting on its own, and this
    owns them for a posting plus everything around it.

    ``work`` must be safe to run more than once — it will be, on a retry.
    """
    last_error: DBAPIError | None = None
    for attempt in range(MAX_ATTEMPTS):
        try:
            with (
                engine.connect().execution_options(isolation_level="SERIALIZABLE") as conn,
                conn.begin(),
            ):
                return work(conn)
        except DBAPIError as exc:
            if not is_retryable(exc):
                raise
            last_error = exc
            backoff_sleep(attempt)

    raise RuntimeError(
        f"transaction could not be serialised after {MAX_ATTEMPTS} attempts"
    ) from last_error
