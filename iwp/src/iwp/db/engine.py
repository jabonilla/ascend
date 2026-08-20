"""Engine construction and transaction helpers."""

from __future__ import annotations

from collections.abc import Iterator
from contextlib import contextmanager
from typing import Literal

from sqlalchemy import Engine, create_engine
from sqlalchemy.engine import Connection

from iwp.config import settings

__all__ = ["IsolationLevel", "make_engine", "transaction"]

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
