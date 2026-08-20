"""Database access.

SQLAlchemy Core only — see ADR-001. There is no ORM session and no unit of work,
because a unit of work emits UPDATEs on your behalf and CLAUDE.md rule 2 says an
UPDATE against the ledger must be impossible to write by accident.
"""

from iwp.db.engine import make_engine, transaction
from iwp.db.migrate import apply_migrations

__all__ = ["apply_migrations", "make_engine", "transaction"]
