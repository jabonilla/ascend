"""P1.3 — double-entry posting.

Invariants under test:
  * a posting writes all its entries in a single transaction, or none
  * sum of debits equals sum of credits, per transaction, always
  * postings are idempotent by an externally supplied key
"""

from __future__ import annotations

import uuid
from concurrent.futures import ThreadPoolExecutor
from typing import Any

import pytest
from hypothesis import HealthCheck, given
from hypothesis import settings as hyp_settings
from hypothesis import strategies as st
from sqlalchemy import Engine, text

from iwp.ledger import (
    AccountType,
    IdempotencyKeyReuse,
    InsufficientBalance,
    PostingRequest,
    UnbalancedPosting,
    account_balance,
    credit,
    debit,
    ensure_account,
    post,
    trial_balance,
)
from iwp.money import Money

pytestmark = pytest.mark.db


def _accounts(db: Engine, relationship_id: uuid.UUID, provider_id: uuid.UUID) -> dict[str, Any]:
    with db.begin() as conn:
        return {
            "custody": ensure_account(
                conn, AccountType.PARTNER_CUSTODY, "USD", scope_id=provider_id
            ),
            "payable": ensure_account(
                conn, AccountType.RECIPIENT_PAYABLE, "USD", scope_id=relationship_id
            ),
            "fees": ensure_account(conn, AccountType.FEE_REVENUE, "USD"),
        }


@pytest.fixture()
def accts(db: Engine) -> dict[str, Any]:
    return _accounts(db, uuid.uuid4(), uuid.uuid4())


# --------------------------------------------------------------------------------------
# balanced / unbalanced
# --------------------------------------------------------------------------------------


def test_a_balanced_posting_succeeds(db: Engine, accts: dict[str, Any]) -> None:
    result = post(
        db,
        PostingRequest(
            idempotency_key="commit-1",
            posting_type="funding_committed",
            entries=(
                debit(accts["custody"], Money(10200, "USD"), "funding"),
                credit(accts["payable"], Money(10000, "USD"), "principal"),
                credit(accts["fees"], Money(200, "USD"), "fee"),
            ),
        ),
    )
    assert result.replayed is False
    assert len(result.entry_ids) == 3
    with db.connect() as conn:
        count = conn.execute(
            text("SELECT count(*) FROM ledger_entry WHERE transaction_id = :t"),
            {"t": result.transaction_id},
        ).scalar_one()
    assert count == 3


def test_an_unbalanced_posting_raises_and_writes_nothing(db: Engine, accts: dict[str, Any]) -> None:
    with pytest.raises(UnbalancedPosting):
        post(
            db,
            PostingRequest(
                idempotency_key="bad-1",
                posting_type="funding_committed",
                entries=(
                    debit(accts["custody"], Money(10200, "USD"), "funding"),
                    credit(accts["payable"], Money(10000, "USD"), "principal"),
                ),
            ),
        )
    with db.connect() as conn:
        entries = conn.execute(text("SELECT count(*) FROM ledger_entry")).scalar_one()
        txns = conn.execute(text("SELECT count(*) FROM ledger_transaction")).scalar_one()
    assert entries == 0
    assert txns == 0


def test_balance_is_checked_per_currency_not_across_currencies(db: Engine) -> None:
    # A posting whose USD leg and GTQ leg happen to have equal minor-unit totals is
    # not balanced. Balancing across currencies would silently invent an FX rate of 1.
    rel = uuid.uuid4()
    with db.begin() as conn:
        usd = ensure_account(conn, AccountType.RECIPIENT_PAYABLE, "USD", scope_id=rel)
        gtq = ensure_account(conn, AccountType.RECIPIENT_PAYABLE, "GTQ", scope_id=rel)
    with pytest.raises(UnbalancedPosting, match="USD"):
        post(
            db,
            PostingRequest(
                idempotency_key="xcur-1",
                posting_type="test",
                entries=(
                    debit(usd, Money(1000, "USD"), "x"),
                    credit(gtq, Money(1000, "GTQ"), "y"),
                ),
            ),
        )


def test_a_posting_needs_at_least_two_entries(db: Engine, accts: dict[str, Any]) -> None:
    with pytest.raises(UnbalancedPosting):
        post(
            db,
            PostingRequest(
                idempotency_key="single-1",
                posting_type="test",
                entries=(debit(accts["custody"], Money(100, "USD"), "x"),),
            ),
        )


def test_a_zero_amount_entry_is_rejected(db: Engine, accts: dict[str, Any]) -> None:
    with pytest.raises(ValueError, match="positive"):
        debit(accts["custody"], Money(0, "USD"), "x")


def test_an_entry_whose_currency_differs_from_its_account_is_rejected(
    db: Engine, accts: dict[str, Any]
) -> None:
    with pytest.raises(ValueError, match="currency"):
        debit(accts["custody"], Money(100, "GTQ"), "x")


# --------------------------------------------------------------------------------------
# idempotency
# --------------------------------------------------------------------------------------


def _commit_request(accts: dict[str, Any], key: str = "commit-1") -> PostingRequest:
    return PostingRequest(
        idempotency_key=key,
        posting_type="funding_committed",
        entries=(
            debit(accts["custody"], Money(10200, "USD"), "funding"),
            credit(accts["payable"], Money(10000, "USD"), "principal"),
            credit(accts["fees"], Money(200, "USD"), "fee"),
        ),
    )


def test_replaying_an_idempotency_key_writes_nothing_and_returns_the_original(
    db: Engine, accts: dict[str, Any]
) -> None:
    first = post(db, _commit_request(accts))
    second = post(db, _commit_request(accts))

    assert second.replayed is True
    assert second.transaction_id == first.transaction_id
    assert second.entry_ids == first.entry_ids
    with db.connect() as conn:
        assert conn.execute(text("SELECT count(*) FROM ledger_entry")).scalar_one() == 3


def test_reusing_a_key_for_a_different_posting_raises(db: Engine, accts: dict[str, Any]) -> None:
    post(db, _commit_request(accts))
    different = PostingRequest(
        idempotency_key="commit-1",
        posting_type="funding_committed",
        entries=(
            debit(accts["custody"], Money(50000, "USD"), "funding"),
            credit(accts["payable"], Money(50000, "USD"), "principal"),
        ),
    )
    with pytest.raises(IdempotencyKeyReuse):
        post(db, different)


def test_concurrent_replays_of_one_key_produce_one_transaction(
    db: Engine, accts: dict[str, Any]
) -> None:
    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(lambda _: post(db, _commit_request(accts)), range(8)))

    txn_ids = {r.transaction_id for r in results}
    assert len(txn_ids) == 1
    assert sum(1 for r in results if not r.replayed) == 1
    with db.connect() as conn:
        assert conn.execute(text("SELECT count(*) FROM ledger_entry")).scalar_one() == 3


# --------------------------------------------------------------------------------------
# concurrency — required by P1.3
# --------------------------------------------------------------------------------------


@pytest.mark.slow
def test_concurrent_postings_to_one_account_do_not_corrupt_balances(
    db: Engine, accts: dict[str, Any]
) -> None:
    """N parallel postings against one account; final balance equals the expected sum."""
    n = 40
    per_posting = Money(250, "USD")

    def do(i: int) -> None:
        post(
            db,
            PostingRequest(
                idempotency_key=f"parallel-{i}",
                posting_type="funding_committed",
                entries=(
                    debit(accts["custody"], per_posting, "funding"),
                    credit(accts["payable"], per_posting, "principal"),
                ),
            ),
        )

    with ThreadPoolExecutor(max_workers=12) as pool:
        list(pool.map(do, range(n)))

    with db.connect() as conn:
        custody = account_balance(conn, accts["custody"].id)
        payable = account_balance(conn, accts["payable"].id)
    assert custody == per_posting * n
    assert payable == per_posting * n


@pytest.mark.slow
def test_a_balance_guard_holds_under_concurrency(db: Engine, accts: dict[str, Any]) -> None:
    """The guard must not let concurrent withdrawals drive a balance below its floor.

    This is what SERIALIZABLE is for: each posting reads the balance and writes on the
    strength of it, and read-then-write is exactly where a weaker isolation level lets
    two transactions both see "enough".
    """
    post(
        db,
        PostingRequest(
            idempotency_key="seed",
            posting_type="funding_committed",
            entries=(
                debit(accts["custody"], Money(1000, "USD"), "funding"),
                credit(accts["payable"], Money(1000, "USD"), "principal"),
            ),
        ),
    )

    def withdraw(i: int) -> bool:
        try:
            post(
                db,
                PostingRequest(
                    idempotency_key=f"withdraw-{i}",
                    posting_type="settlement_delivered",
                    entries=(
                        debit(accts["payable"], Money(300, "USD"), "delivery"),
                        credit(accts["custody"], Money(300, "USD"), "delivery"),
                    ),
                ),
                guards=((accts["custody"].id, Money(0, "USD")),),
            )
        except InsufficientBalance:
            return False
        return True

    with ThreadPoolExecutor(max_workers=8) as pool:
        outcomes = list(pool.map(withdraw, range(8)))

    assert sum(outcomes) == 3  # 3 x 300 fits under 1000; the fourth would go negative
    with db.connect() as conn:
        assert account_balance(conn, accts["custody"].id) == Money(100, "USD")


# --------------------------------------------------------------------------------------
# property test — required by P1.3
# --------------------------------------------------------------------------------------

_posting_amounts = st.integers(min_value=1, max_value=10**7)


@hyp_settings(
    max_examples=25,
    deadline=None,
    suppress_health_check=[HealthCheck.function_scoped_fixture],
)
@given(
    sequence=st.lists(
        st.tuples(_posting_amounts, _posting_amounts, st.sampled_from(["commit", "settle"])),
        min_size=1,
        max_size=12,
    )
)
@pytest.mark.slow
def test_property_global_debits_always_equal_global_credits(
    db: Engine, sequence: list[tuple[int, int, str]]
) -> None:
    """Generate random sequences of valid postings; assert the ledger stays balanced."""
    accts = _accounts(db, uuid.uuid4(), uuid.uuid4())
    run = uuid.uuid4().hex

    for i, (principal, fee, kind) in enumerate(sequence):
        entries: tuple[Any, ...]
        if kind == "commit":
            entries = (
                debit(accts["custody"], Money(principal + fee, "USD"), "funding"),
                credit(accts["payable"], Money(principal, "USD"), "principal"),
                credit(accts["fees"], Money(fee, "USD"), "fee"),
            )
        else:
            entries = (
                debit(accts["payable"], Money(principal, "USD"), "delivery"),
                credit(accts["custody"], Money(principal, "USD"), "delivery"),
            )
        post(
            db,
            PostingRequest(
                idempotency_key=f"{run}-{i}",
                posting_type=kind,
                entries=entries,
            ),
        )

        with db.connect() as conn:
            balances = trial_balance(conn)
        for currency_code, total in balances.items():
            assert total.is_zero, f"{currency_code} trial balance is {total}, not zero"


def test_losing_the_idempotency_race_replays_instead_of_failing(
    db: Engine, accts: dict[str, Any], monkeypatch: pytest.MonkeyPatch
) -> None:
    """A racing poster that commits our key first must leave us replaying, not erroring.

    The race is forced rather than hoped for: the existence check is stubbed to miss
    once, exactly as it would if another transaction committed between the check and
    the insert.
    """
    from iwp.ledger import posting as posting_module

    post(db, _commit_request(accts))  # the "other" caller, already committed

    real_find = posting_module._find_existing
    calls = {"n": 0}

    def find_missing_once(conn: Any, key: str) -> Any:
        calls["n"] += 1
        if calls["n"] == 1:
            return None
        return real_find(conn, key)

    monkeypatch.setattr(posting_module, "_find_existing", find_missing_once)

    result = post(db, _commit_request(accts))
    assert result.replayed is True
    assert calls["n"] >= 2  # the first attempt missed, the retry found it
    with db.connect() as conn:
        assert conn.execute(text("SELECT count(*) FROM ledger_entry")).scalar_one() == 3


def test_a_unique_violation_that_is_not_the_idempotency_key_is_not_swallowed(
    db: Engine, accts: dict[str, Any]
) -> None:
    # The retry loop narrows on the constraint name. If it matched any 23505 it would
    # spin on unrelated violations and then report a serialisation failure that never
    # happened.
    from sqlalchemy.exc import IntegrityError

    from iwp.ledger.posting import _is_idempotency_key_conflict

    with pytest.raises(IntegrityError) as caught, db.begin() as conn:
        conn.execute(
            text(
                """
                INSERT INTO account
                    (account_type, normal_balance, currency, scope_type, scope_id, name)
                VALUES ('fee_revenue', 'credit', 'USD', '',
                        '00000000-0000-0000-0000-000000000000', 'duplicate')
                """
            )
        )
    assert _is_idempotency_key_conflict(caught.value) is False
