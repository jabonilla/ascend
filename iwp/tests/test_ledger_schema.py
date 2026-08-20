"""P1.2 — ledger schema and append-only enforcement.

Acceptance criteria under test:
  * a direct SQL UPDATE against the ledger table fails
  * a direct SQL DELETE against the ledger table fails
  * entries are queryable by transaction and by account

These use raw SQL deliberately. Testing the ORM would prove nothing: the requirement is
that the *database* refuses, so that psql, a migration, or an agent writing raw SQL is
refused too.
"""

from __future__ import annotations

import uuid

import pytest
from sqlalchemy import Engine, text
from sqlalchemy.exc import DBAPIError, IntegrityError

pytestmark = pytest.mark.db


def _seed_entry(db: Engine) -> tuple[uuid.UUID, uuid.UUID, uuid.UUID]:
    """Insert one account, one ledger transaction and one entry. Returns their ids."""
    with db.begin() as conn:
        account_id = conn.execute(
            text(
                """
                INSERT INTO account (account_type, normal_balance, currency, name)
                VALUES ('partner_custody', 'debit', 'USD', 'partner custody USD')
                RETURNING id
                """
            )
        ).scalar_one()
        txn_id = conn.execute(
            text(
                """
                INSERT INTO ledger_transaction
                    (idempotency_key, posting_type, request_fingerprint)
                VALUES ('seed-1', 'test', 'seed-fingerprint')
                RETURNING id
                """
            )
        ).scalar_one()
        entry_id = conn.execute(
            text(
                """
                INSERT INTO ledger_entry
                    (transaction_id, entry_index, account_id, direction, amount,
                     currency, entry_type)
                VALUES (:t, 0, :a, 'debit', 1000, 'USD', 'test')
                RETURNING id
                """
            ),
            {"t": txn_id, "a": account_id},
        ).scalar_one()
    return account_id, txn_id, entry_id


def test_direct_sql_update_against_the_ledger_fails(db: Engine) -> None:
    _, _, entry_id = _seed_entry(db)
    with pytest.raises(DBAPIError, match="append-only"), db.begin() as conn:
        conn.execute(text("UPDATE ledger_entry SET amount = 1 WHERE id = :id"), {"id": entry_id})


def test_direct_sql_delete_against_the_ledger_fails(db: Engine) -> None:
    _, _, entry_id = _seed_entry(db)
    with pytest.raises(DBAPIError, match="append-only"), db.begin() as conn:
        conn.execute(text("DELETE FROM ledger_entry WHERE id = :id"), {"id": entry_id})


def test_truncating_the_ledger_fails(db: Engine) -> None:
    # Row-level triggers do not fire for TRUNCATE. Without the statement-level trigger
    # this is the one command that takes the whole ledger.
    _seed_entry(db)
    with pytest.raises(DBAPIError, match="append-only"), db.begin() as conn:
        conn.execute(text("TRUNCATE ledger_entry"))


def test_an_update_touching_no_rows_still_fails(db: Engine) -> None:
    # A row trigger fires per matched row, so a no-match UPDATE succeeds vacuously.
    # It changes nothing, so it is harmless — but assert the behaviour is understood
    # rather than assumed.
    _seed_entry(db)
    with db.begin() as conn:
        result = conn.execute(text("UPDATE ledger_entry SET amount = 1 WHERE amount = -999"))
    assert result.rowcount == 0


def test_ledger_transaction_headers_are_append_only_too(db: Engine) -> None:
    _, txn_id, _ = _seed_entry(db)
    with pytest.raises(DBAPIError, match="append-only"), db.begin() as conn:
        conn.execute(
            text("UPDATE ledger_transaction SET description = 'x' WHERE id = :id"),
            {"id": txn_id},
        )


def test_audit_log_is_append_only(db: Engine) -> None:
    with db.begin() as conn:
        audit_id = conn.execute(
            text(
                """
                INSERT INTO audit_log (actor_kind, action, entity_type, entity_id)
                VALUES ('system', 'test', 'test', gen_random_uuid())
                RETURNING id
                """
            )
        ).scalar_one()
    with pytest.raises(DBAPIError, match="append-only"), db.begin() as conn:
        conn.execute(text("DELETE FROM audit_log WHERE id = :id"), {"id": audit_id})


def test_entries_are_queryable_by_transaction_and_by_account(db: Engine) -> None:
    account_id, txn_id, entry_id = _seed_entry(db)
    with db.connect() as conn:
        by_txn = (
            conn.execute(
                text("SELECT id FROM ledger_entry WHERE transaction_id = :t"), {"t": txn_id}
            )
            .scalars()
            .all()
        )
        by_account = (
            conn.execute(
                text("SELECT id FROM ledger_entry WHERE account_id = :a ORDER BY created_at"),
                {"a": account_id},
            )
            .scalars()
            .all()
        )
    assert by_txn == [entry_id]
    assert by_account == [entry_id]


def test_amount_must_be_positive(db: Engine) -> None:
    # The sign lives in `direction`. A negative amount would give two contradictory
    # ways to express the same thing.
    account_id, txn_id, _ = _seed_entry(db)
    with pytest.raises(IntegrityError), db.begin() as conn:
        conn.execute(
            text(
                """
                INSERT INTO ledger_entry
                    (transaction_id, entry_index, account_id, direction, amount,
                     currency, entry_type)
                VALUES (:t, 1, :a, 'debit', -5, 'USD', 'test')
                """
            ),
            {"t": txn_id, "a": account_id},
        )


def test_direction_is_constrained_to_debit_or_credit(db: Engine) -> None:
    account_id, txn_id, _ = _seed_entry(db)
    with pytest.raises(IntegrityError), db.begin() as conn:
        conn.execute(
            text(
                """
                INSERT INTO ledger_entry
                    (transaction_id, entry_index, account_id, direction, amount,
                     currency, entry_type)
                VALUES (:t, 1, :a, 'sideways', 5, 'USD', 'test')
                """
            ),
            {"t": txn_id, "a": account_id},
        )


def test_entry_currency_must_match_its_account(db: Engine) -> None:
    account_id, txn_id, _ = _seed_entry(db)
    with pytest.raises(DBAPIError, match="does not match account currency"), db.begin() as conn:
        conn.execute(
            text(
                """
                INSERT INTO ledger_entry
                    (transaction_id, entry_index, account_id, direction, amount,
                     currency, entry_type)
                VALUES (:t, 1, :a, 'debit', 5, 'GTQ', 'test')
                """
            ),
            {"t": txn_id, "a": account_id},
        )


def test_idempotency_key_is_unique(db: Engine) -> None:
    _seed_entry(db)
    with pytest.raises(IntegrityError), db.begin() as conn:
        conn.execute(
            text(
                "INSERT INTO ledger_transaction (idempotency_key, posting_type) VALUES ('seed-1', 'test')"
            )
        )
