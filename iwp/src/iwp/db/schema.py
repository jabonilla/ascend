"""SQLAlchemy Core table definitions.

These mirror ``migrations/*.sql``. The SQL is the source of truth for the schema; this
module exists so queries are typed and composable, not so it can create tables.
``tests/test_schema_matches_migrations.py`` asserts the two agree.
"""

from __future__ import annotations

from sqlalchemy import (
    BigInteger,
    Column,
    DateTime,
    ForeignKey,
    Index,
    MetaData,
    SmallInteger,
    String,
    Table,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID

__all__ = [
    "account",
    "audit_log",
    "ledger_entry",
    "ledger_transaction",
    "metadata",
]

metadata = MetaData()

account = Table(
    "account",
    metadata,
    Column("id", UUID(as_uuid=True), primary_key=True),
    Column("account_type", Text, nullable=False),
    Column("normal_balance", Text, nullable=False),
    Column("currency", String(3), nullable=False),
    Column("scope_type", Text, nullable=False, server_default=""),
    Column("scope_id", UUID(as_uuid=True), nullable=False),
    Column("name", Text, nullable=False),
    Column("created_at", DateTime(timezone=True), nullable=False, server_default=func.now()),
)

ledger_transaction = Table(
    "ledger_transaction",
    metadata,
    Column("id", UUID(as_uuid=True), primary_key=True),
    Column("idempotency_key", Text, nullable=False, unique=True),
    Column("posting_type", Text, nullable=False),
    Column("request_fingerprint", Text, nullable=False),
    Column("business_txn_id", UUID(as_uuid=True), nullable=True),
    Column("description", Text, nullable=False, server_default=""),
    Column("created_at", DateTime(timezone=True), nullable=False, server_default=func.now()),
)

ledger_entry = Table(
    "ledger_entry",
    metadata,
    Column("id", UUID(as_uuid=True), primary_key=True),
    Column(
        "transaction_id", UUID(as_uuid=True), ForeignKey("ledger_transaction.id"), nullable=False
    ),
    Column("entry_index", SmallInteger, nullable=False),
    Column("account_id", UUID(as_uuid=True), ForeignKey("account.id"), nullable=False),
    Column("direction", Text, nullable=False),
    Column("amount", BigInteger, nullable=False),
    Column("currency", String(3), nullable=False),
    Column("entry_type", Text, nullable=False),
    Column("created_at", DateTime(timezone=True), nullable=False, server_default=func.now()),
    Index("ledger_entry_transaction_idx", "transaction_id", "entry_index", unique=True),
    Index("ledger_entry_account_idx", "account_id", "created_at"),
)

audit_log = Table(
    "audit_log",
    metadata,
    Column("id", UUID(as_uuid=True), primary_key=True),
    Column("actor_id", UUID(as_uuid=True), nullable=True),
    Column("actor_kind", Text, nullable=False),
    Column("action", Text, nullable=False),
    Column("entity_type", Text, nullable=False),
    Column("entity_id", UUID(as_uuid=True), nullable=False),
    Column("assurance_level", Text, nullable=True),
    Column("channel", Text, nullable=True),
    Column("before_state", JSONB, nullable=True),
    Column("after_state", JSONB, nullable=True),
    Column("created_at", DateTime(timezone=True), nullable=False, server_default=func.now()),
)
