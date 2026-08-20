"""P1.4 — account model and balance derivation.

Invariants under test:
  * balance is always a function of ledger entries
  * if a cached balance exists it is reconstructible and verified against derivation

There is no cached balance. The second invariant is therefore met by making a cache
impossible rather than by reconciling one: ``test_no_table_stores_a_balance`` asserts
that no column anywhere in the schema holds one. If that test is ever changed to allow
a cache, the comparison test below it becomes mandatory.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from hypothesis import HealthCheck, given
from hypothesis import settings as hyp_settings
from hypothesis import strategies as st
from sqlalchemy import Engine, text

from iwp.ledger import (
    AccountType,
    NormalBalance,
    PostingRequest,
    account_balance,
    credit,
    debit,
    ensure_account,
    post,
)
from iwp.ledger.balances import account_balance_history
from iwp.money import Money

pytestmark = pytest.mark.db


@pytest.fixture()
def accts(db: Engine) -> dict[str, Any]:
    with db.begin() as conn:
        return {
            "custody": ensure_account(
                conn, AccountType.PARTNER_CUSTODY, "USD", scope_id=uuid.uuid4()
            ),
            "payable": ensure_account(
                conn, AccountType.RECIPIENT_PAYABLE, "USD", scope_id=uuid.uuid4()
            ),
        }


def _move(db: Engine, accts: dict[str, Any], amount: int, key: str) -> None:
    post(
        db,
        PostingRequest(
            idempotency_key=key,
            posting_type="test",
            entries=(
                debit(accts["custody"], Money(amount, "USD"), "in"),
                credit(accts["payable"], Money(amount, "USD"), "in"),
            ),
        ),
    )


# --------------------------------------------------------------------------------------
# normal balance direction
# --------------------------------------------------------------------------------------


def test_a_debit_normal_account_increases_on_debit(db: Engine, accts: dict[str, Any]) -> None:
    assert accts["custody"].normal_balance is NormalBalance.DEBIT
    _move(db, accts, 1000, "a")
    with db.connect() as conn:
        assert account_balance(conn, accts["custody"].id) == Money(1000, "USD")


def test_a_credit_normal_account_increases_on_credit(db: Engine, accts: dict[str, Any]) -> None:
    assert accts["payable"].normal_balance is NormalBalance.CREDIT
    _move(db, accts, 1000, "a")
    with db.connect() as conn:
        assert account_balance(conn, accts["payable"].id) == Money(1000, "USD")


def test_an_account_with_no_entries_has_a_zero_balance_not_an_error(
    db: Engine, accts: dict[str, Any]
) -> None:
    with db.connect() as conn:
        assert account_balance(conn, accts["custody"].id) == Money(0, "USD")


def test_balance_of_an_unknown_account_raises(db: Engine) -> None:
    with db.connect() as conn, pytest.raises(LookupError):
        account_balance(conn, uuid.uuid4())


def test_a_balance_can_go_negative_and_is_not_clamped(db: Engine, accts: dict[str, Any]) -> None:
    # Nothing in the ledger prevents a negative balance; that is what balance guards
    # on postings are for. Silently clamping would lose money.
    post(
        db,
        PostingRequest(
            idempotency_key="out",
            posting_type="test",
            entries=(
                credit(accts["custody"], Money(500, "USD"), "out"),
                debit(accts["payable"], Money(500, "USD"), "out"),
            ),
        ),
    )
    with db.connect() as conn:
        assert account_balance(conn, accts["custody"].id) == Money(-500, "USD")


# --------------------------------------------------------------------------------------
# point in time
# --------------------------------------------------------------------------------------


def test_balance_at_any_point_in_time_is_derivable(db: Engine, accts: dict[str, Any]) -> None:
    _move(db, accts, 1000, "one")
    with db.connect() as conn:
        after_first = conn.execute(text("SELECT max(created_at) FROM ledger_entry")).scalar_one()

    _move(db, accts, 2500, "two")

    with db.connect() as conn:
        assert account_balance(conn, accts["custody"].id) == Money(3500, "USD")
        assert account_balance(conn, accts["custody"].id, as_of=after_first) == Money(1000, "USD")
        before_everything = after_first - timedelta(seconds=1)
        assert account_balance(conn, accts["custody"].id, as_of=before_everything) == Money(
            0, "USD"
        )


def test_balance_as_of_the_future_equals_the_current_balance(
    db: Engine, accts: dict[str, Any]
) -> None:
    _move(db, accts, 700, "one")
    future = datetime.now(UTC) + timedelta(days=365)
    with db.connect() as conn:
        assert account_balance(conn, accts["custody"].id, as_of=future) == Money(700, "USD")


def test_running_balance_history_matches_the_final_balance(
    db: Engine, accts: dict[str, Any]
) -> None:
    for i, amount in enumerate([100, 250, 75]):
        _move(db, accts, amount, f"k{i}")
    with db.connect() as conn:
        history = account_balance_history(conn, accts["custody"].id)
        final = account_balance(conn, accts["custody"].id)
    assert [m.minor_units for _, m in history] == [100, 350, 425]
    assert history[-1][1] == final


# --------------------------------------------------------------------------------------
# no cached balance exists — the invariant, enforced
# --------------------------------------------------------------------------------------


def test_no_table_stores_a_balance(db: Engine) -> None:
    """A balance column is the failure mode P1.4 exists to prevent.

    If a cache is ever added deliberately, this test must be replaced by one that
    reconstructs the cache and compares it against the derivation under randomised
    posting sequences — not simply deleted.
    """
    with db.connect() as conn:
        offenders = conn.execute(
            text(
                """
                SELECT table_name, column_name
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND (column_name = 'balance' OR column_name LIKE '%_balance')
                  AND column_name <> 'normal_balance'
                """
            )
        ).all()
    assert offenders == [], f"a stored balance appeared in the schema: {offenders}"


@hyp_settings(
    max_examples=20,
    deadline=None,
    suppress_health_check=[HealthCheck.function_scoped_fixture],
)
@given(
    moves=st.lists(st.integers(min_value=1, max_value=10**6), min_size=1, max_size=15),
)
@pytest.mark.slow
def test_property_derived_balance_equals_the_sum_of_its_entries(
    db: Engine, moves: list[int]
) -> None:
    """Under randomised posting sequences the derivation matches the arithmetic sum."""
    run = uuid.uuid4()
    with db.begin() as conn:
        custody = ensure_account(conn, AccountType.PARTNER_CUSTODY, "USD", scope_id=run)
        payable = ensure_account(conn, AccountType.RECIPIENT_PAYABLE, "USD", scope_id=run)

    for i, amount in enumerate(moves):
        post(
            db,
            PostingRequest(
                idempotency_key=f"{run}-{i}",
                posting_type="test",
                entries=(
                    debit(custody, Money(amount, "USD"), "in"),
                    credit(payable, Money(amount, "USD"), "in"),
                ),
            ),
        )

    expected = Money(sum(moves), "USD")
    with db.connect() as conn:
        assert account_balance(conn, custody.id) == expected
        assert account_balance(conn, payable.id) == expected
        history = account_balance_history(conn, custody.id)
    assert history[-1][1] == expected
