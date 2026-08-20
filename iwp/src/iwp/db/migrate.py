"""Migration runner.

Migrations are plain ``.sql`` files applied in filename order and recorded in
``schema_migration``. Plain SQL rather than a Python DSL on purpose (ADR-001): a money
schema should be readable as SQL by someone auditing it who does not read our code.
"""

from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

from sqlalchemy import Engine, text

__all__ = ["MIGRATIONS_DIR", "apply_migrations", "drop_everything"]

MIGRATIONS_DIR = Path(__file__).resolve().parents[3] / "migrations"

_MIGRATION_TABLE = """
CREATE TABLE IF NOT EXISTS schema_migration (
    filename    TEXT PRIMARY KEY,
    checksum    TEXT        NOT NULL,
    applied_at  TIMESTAMPTZ NOT NULL DEFAULT now()
)
"""


def _migration_files(directory: Path) -> list[Path]:
    return sorted(p for p in directory.glob("*.sql") if p.is_file())


def apply_migrations(engine: Engine, directory: Path | None = None) -> list[str]:
    """Apply every not-yet-applied migration. Returns the filenames applied.

    An already-applied migration whose contents changed is an error, not a silent
    no-op: editing an applied migration means the database and the repository
    disagree about the schema, and on a ledger that has to be loud.
    """
    directory = directory or MIGRATIONS_DIR
    applied: list[str] = []

    with engine.begin() as conn:
        conn.execute(text(_MIGRATION_TABLE))

    with engine.connect() as conn:
        rows = conn.execute(text("SELECT filename, checksum FROM schema_migration")).all()
    known = {row.filename: row.checksum for row in rows}

    for path in _migration_files(directory):
        sql = path.read_text(encoding="utf-8")
        checksum = hashlib.sha256(sql.encode("utf-8")).hexdigest()
        if path.name in known:
            if known[path.name] != checksum:
                raise RuntimeError(
                    f"migration {path.name} has already been applied but its contents "
                    "have changed. Add a new migration instead of editing an applied one."
                )
            continue
        # Each migration is its own transaction: a failure leaves the ones before it
        # applied and recorded, and nothing half-applied.
        with engine.begin() as conn:
            conn.execute(text(sql))
            conn.execute(
                text("INSERT INTO schema_migration (filename, checksum) VALUES (:f, :c)"),
                {"f": path.name, "c": checksum},
            )
        applied.append(path.name)

    return applied


def drop_everything(engine: Engine) -> None:
    """Drop and recreate the public schema. Development and tests only."""
    from iwp.config import settings

    if settings().is_production:
        raise RuntimeError("refusing to drop the schema in production")
    with engine.begin() as conn:
        conn.execute(text("DROP SCHEMA public CASCADE"))
        conn.execute(text("CREATE SCHEMA public"))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Apply IWP database migrations.")
    parser.add_argument("--reset", action="store_true", help="drop the schema first")
    parser.add_argument("--url", default=None, help="database URL override")
    args = parser.parse_args(argv)

    from iwp.db.engine import make_engine

    engine = make_engine(args.url)
    if args.reset:
        drop_everything(engine)
    applied = apply_migrations(engine)
    if applied:
        for name in applied:
            print(f"applied {name}")
    else:
        print("no migrations to apply")
    return 0


if __name__ == "__main__":
    sys.exit(main())
