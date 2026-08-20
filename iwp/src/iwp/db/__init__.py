"""Database access.

SQLAlchemy Core only — see ADR-001. There is no ORM session and no unit of work,
because a unit of work emits UPDATEs on your behalf and CLAUDE.md rule 2 says an
UPDATE against the ledger must be impossible to write by accident.

``iwp.db.migrate`` is deliberately not re-exported here: it is also a ``__main__``
module, and importing it from the package initialiser makes ``python -m iwp.db.migrate``
load it twice.
"""

from iwp.db.engine import make_engine, transaction

__all__ = ["make_engine", "transaction"]
