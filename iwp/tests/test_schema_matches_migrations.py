"""The Core table definitions must describe the schema the migrations actually build.

``src/iwp/db/schema.py`` exists so queries are typed and composable. The SQL is the
source of truth. When the two drift, queries compile against a table shape that does
not exist — and on a money path that surfaces as a runtime error in production rather
than a failure here.
"""

from __future__ import annotations

import pytest
from sqlalchemy import Engine, inspect

from iwp.db.schema import metadata

pytestmark = pytest.mark.db


def test_every_declared_table_exists_in_the_database(db: Engine) -> None:
    actual = set(inspect(db).get_table_names())
    declared = set(metadata.tables)
    assert declared <= actual, f"declared but not migrated: {sorted(declared - actual)}"


def test_declared_columns_match_the_migrated_columns(db: Engine) -> None:
    inspector = inspect(db)
    mismatches: list[str] = []
    for name, table in metadata.tables.items():
        actual = {col["name"] for col in inspector.get_columns(name)}
        declared = {col.name for col in table.columns}
        if missing := actual - declared:
            mismatches.append(f"{name}: in the database but not declared: {sorted(missing)}")
        if extra := declared - actual:
            mismatches.append(f"{name}: declared but not in the database: {sorted(extra)}")
    assert mismatches == [], "\n".join(mismatches)


def test_declared_nullability_matches(db: Engine) -> None:
    inspector = inspect(db)
    mismatches: list[str] = []
    for name, table in metadata.tables.items():
        actual = {col["name"]: col["nullable"] for col in inspector.get_columns(name)}
        for column in table.columns:
            if column.name in actual and actual[column.name] != column.nullable:
                mismatches.append(
                    f"{name}.{column.name}: database nullable={actual[column.name]}, "
                    f"declared nullable={column.nullable}"
                )
    assert mismatches == [], "\n".join(mismatches)
