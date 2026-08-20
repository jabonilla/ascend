"""Shared fixtures.

Tests run against a real PostgreSQL. That is not incidental: P1.2 requires append-only
to be enforced *at the database*, and P1.3 requires a genuine concurrency test. Neither
can be demonstrated against SQLite or a fake.
"""

from __future__ import annotations

import os
import uuid
from collections.abc import Iterator

import pytest
from sqlalchemy import Engine, text

# Importing the adapters package registers every settlement adapter, which is
# what makes `get_provider("mockpay")` resolve in tests.
import iwp.settlement.adapters  # noqa: F401
from iwp.db.engine import make_engine
from iwp.db.migrate import apply_migrations, drop_everything

# Tables whose contents every test starts clean. Order matters: children first.
# ledger_entry and ledger_transaction are append-only and cannot be TRUNCATEd, so
# tests get a fresh schema rather than a truncate — see `db` below.
_TEST_DATABASE_URL = os.environ.get(
    "IWP_TEST_DATABASE_URL", "postgresql+psycopg://iwp:iwp@localhost:5432/iwp_test"
)


@pytest.fixture(scope="session")
def engine() -> Iterator[Engine]:
    eng = make_engine(_TEST_DATABASE_URL)
    try:
        with eng.connect() as conn:
            conn.execute(text("SELECT 1"))
    except Exception as exc:  # pragma: no cover - environment problem, not a test failure
        # Skipping the database tests is a developer convenience, never a CI outcome:
        # every P1 acceptance criterion lives in them. CI sets IWP_REQUIRE_DB=1 so a
        # missing database fails the pipeline instead of quietly passing it.
        message = f"no test database at {_TEST_DATABASE_URL}: {exc}"
        if os.environ.get("IWP_REQUIRE_DB") == "1":
            pytest.fail(message, pytrace=False)
        pytest.skip(message)
    drop_everything(eng)
    apply_migrations(eng)
    yield eng
    eng.dispose()


@pytest.fixture()
def db(engine: Engine) -> Iterator[Engine]:
    """A clean database for one test.

    The append-only triggers block DELETE and TRUNCATE — which is the point — so
    between tests the schema is dropped and rebuilt rather than emptied. Migrations
    are a few milliseconds of DDL; correctness of the guarantee is worth more.
    """
    drop_everything(engine)
    apply_migrations(engine)
    yield engine


@pytest.fixture()
def new_id() -> uuid.UUID:
    return uuid.uuid4()
