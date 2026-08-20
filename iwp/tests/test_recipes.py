"""Posting recipes — the account-level meaning of each business event.

Documented in ``docs/ledger-recipes.md``. These tests are the executable version of
that document: if a recipe changes, one of these fails and the doc has to change too.
"""

from __future__ import annotations

import uuid

import pytest
from sqlalchemy import Engine

from iwp.ledger import (
    AccountType,
    account_balance,
    ensure_account,
    post,
    trial_balance,
)
from iwp.ledger.recipes import (
    funding_committed,
    settlement_delivered,
    settlement_failed,
    settlement_reversed,
    transfer_cancelled,
)
from iwp.money import Money

pytestmark = pytest.mark.db

PRINCIPAL = Money(10000, "USD")
FEE = Money(200, "USD")


@pytest.fixture()
def ids() -> dict[str, uuid.UUID]:
    return {"txn": uuid.uuid4(), "rel": uuid.uuid4(), "prov": uuid.uuid4()}


def _balances(db: Engine, ids: dict[str, uuid.UUID]) -> dict[str, Money]:
    with db.begin() as conn:
        custody = ensure_account(conn, AccountType.PARTNER_CUSTODY, "USD", scope_id=ids["prov"])
        payable = ensure_account(conn, AccountType.RECIPIENT_PAYABLE, "USD", scope_id=ids["rel"])
        fees = ensure_account(conn, AccountType.FEE_REVENUE, "USD")
        return {
            "custody": account_balance(conn, custody.id),
            "payable": account_balance(conn, payable.id),
            "fees": account_balance(conn, fees.id),
        }


def _commit(db: Engine, ids: dict[str, uuid.UUID]) -> None:
    with db.begin() as conn:
        request = funding_committed(
            conn,
            business_txn_id=ids["txn"],
            relationship_id=ids["rel"],
            provider_id=ids["prov"],
            principal=PRINCIPAL,
            fee=FEE,
        )
    post(db, request)


def test_commitment_creates_the_obligation_and_recognises_the_fee(
    db: Engine, ids: dict[str, uuid.UUID]
) -> None:
    _commit(db, ids)
    balances = _balances(db, ids)
    assert balances["custody"] == Money(10200, "USD")
    assert balances["payable"] == PRINCIPAL
    assert balances["fees"] == FEE


def test_delivery_discharges_the_obligation_and_leaves_the_fee_as_revenue(
    db: Engine, ids: dict[str, uuid.UUID]
) -> None:
    _commit(db, ids)
    with db.begin() as conn:
        request = settlement_delivered(
            conn,
            business_txn_id=ids["txn"],
            relationship_id=ids["rel"],
            provider_id=ids["prov"],
            delivered=PRINCIPAL,
        )
    post(db, request)

    balances = _balances(db, ids)
    assert balances["payable"] == Money(0, "USD"), "the obligation is fully discharged"
    assert balances["custody"] == FEE, "the fee remains as realised revenue"
    assert balances["fees"] == FEE


def test_partial_delivery_leaves_the_remainder_on_the_payable(
    db: Engine, ids: dict[str, uuid.UUID]
) -> None:
    _commit(db, ids)
    with db.begin() as conn:
        request = settlement_delivered(
            conn,
            business_txn_id=ids["txn"],
            relationship_id=ids["rel"],
            provider_id=ids["prov"],
            delivered=Money(6000, "USD"),
            sequence=0,
        )
    post(db, request)

    assert _balances(db, ids)["payable"] == Money(4000, "USD")


def test_successive_partial_deliveries_each_need_their_own_sequence(
    db: Engine, ids: dict[str, uuid.UUID]
) -> None:
    _commit(db, ids)
    for seq, amount in enumerate([Money(6000, "USD"), Money(4000, "USD")]):
        with db.begin() as conn:
            request = settlement_delivered(
                conn,
                business_txn_id=ids["txn"],
                relationship_id=ids["rel"],
                provider_id=ids["prov"],
                delivered=amount,
                sequence=seq,
            )
        post(db, request)

    assert _balances(db, ids)["payable"] == Money(0, "USD")


def test_replaying_a_delivery_webhook_is_a_no_op(db: Engine, ids: dict[str, uuid.UUID]) -> None:
    # At-least-once delivery: the same webhook arriving twice must not pay twice.
    _commit(db, ids)
    for _ in range(3):
        with db.begin() as conn:
            request = settlement_delivered(
                conn,
                business_txn_id=ids["txn"],
                relationship_id=ids["rel"],
                provider_id=ids["prov"],
                delivered=PRINCIPAL,
            )
        post(db, request)
    assert _balances(db, ids)["payable"] == Money(0, "USD")


def test_failure_returns_the_principal_and_refunds_the_fee(
    db: Engine, ids: dict[str, uuid.UUID]
) -> None:
    _commit(db, ids)
    with db.begin() as conn:
        request = settlement_failed(
            conn,
            business_txn_id=ids["txn"],
            relationship_id=ids["rel"],
            provider_id=ids["prov"],
            principal=PRINCIPAL,
            fee=FEE,
        )
    post(db, request)

    balances = _balances(db, ids)
    assert balances["custody"] == Money(0, "USD"), "everything left custody"
    assert balances["payable"] == Money(0, "USD")
    assert balances["fees"] == Money(0, "USD"), "the fee was never earned"


def test_cancellation_moves_the_same_money_under_its_own_posting_type(
    db: Engine, ids: dict[str, uuid.UUID]
) -> None:
    _commit(db, ids)
    with db.begin() as conn:
        request = transfer_cancelled(
            conn,
            business_txn_id=ids["txn"],
            relationship_id=ids["rel"],
            provider_id=ids["prov"],
            principal=PRINCIPAL,
            fee=FEE,
        )
    assert request.posting_type == "transfer_cancelled"
    post(db, request)
    assert _balances(db, ids)["custody"] == Money(0, "USD")


def test_reversal_writes_new_entries_and_leaves_the_originals_intact(
    db: Engine, ids: dict[str, uuid.UUID]
) -> None:
    from sqlalchemy import text

    _commit(db, ids)
    with db.begin() as conn:
        request = settlement_delivered(
            conn,
            business_txn_id=ids["txn"],
            relationship_id=ids["rel"],
            provider_id=ids["prov"],
            delivered=PRINCIPAL,
        )
    delivery = post(db, request)

    with db.connect() as conn:
        before = conn.execute(
            text("SELECT id, amount, direction FROM ledger_entry WHERE transaction_id = :t"),
            {"t": delivery.transaction_id},
        ).all()

    with db.begin() as conn:
        request = settlement_reversed(
            conn,
            business_txn_id=ids["txn"],
            relationship_id=ids["rel"],
            provider_id=ids["prov"],
            reversed_amount=PRINCIPAL,
        )
    post(db, request)

    with db.connect() as conn:
        after = conn.execute(
            text("SELECT id, amount, direction FROM ledger_entry WHERE transaction_id = :t"),
            {"t": delivery.transaction_id},
        ).all()
    assert after == before, "the original delivery entries are untouched"
    assert _balances(db, ids)["payable"] == PRINCIPAL, "the obligation is live again"


def test_a_zero_fee_produces_no_fee_entry(db: Engine, ids: dict[str, uuid.UUID]) -> None:
    # An entry for zero would fail the positive-amount check, and a zero-amount row is
    # noise in the journal regardless.
    with db.begin() as conn:
        request = funding_committed(
            conn,
            business_txn_id=ids["txn"],
            relationship_id=ids["rel"],
            provider_id=ids["prov"],
            principal=PRINCIPAL,
            fee=Money(0, "USD"),
        )
    assert len(request.entries) == 2
    post(db, request)
    assert _balances(db, ids)["fees"] == Money(0, "USD")


def test_recipes_reject_a_mixed_currency_principal_and_fee(
    db: Engine, ids: dict[str, uuid.UUID]
) -> None:
    with db.begin() as conn, pytest.raises(ValueError, match="same currency"):
        funding_committed(
            conn,
            business_txn_id=ids["txn"],
            relationship_id=ids["rel"],
            provider_id=ids["prov"],
            principal=PRINCIPAL,
            fee=Money(200, "GTQ"),
        )


def test_every_recipe_leaves_the_trial_balance_at_zero(
    db: Engine, ids: dict[str, uuid.UUID]
) -> None:
    _commit(db, ids)
    with db.begin() as conn:
        delivered = settlement_delivered(
            conn,
            business_txn_id=ids["txn"],
            relationship_id=ids["rel"],
            provider_id=ids["prov"],
            delivered=PRINCIPAL,
        )
    post(db, delivered)
    with db.begin() as conn:
        reversal = settlement_reversed(
            conn,
            business_txn_id=ids["txn"],
            relationship_id=ids["rel"],
            provider_id=ids["prov"],
            reversed_amount=PRINCIPAL,
        )
    post(db, reversal)

    with db.connect() as conn:
        for currency_code, net in trial_balance(conn).items():
            assert net.is_zero, f"{currency_code} trial balance is {net}"
