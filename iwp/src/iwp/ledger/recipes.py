"""Which accounts each business event touches.

The engine in ``posting.py`` enforces that a posting balances; it has no opinion about
what a posting should contain. That opinion lives here and in ``docs/ledger-recipes.md``,
in one place, so an accountant can review it without reading the rest of the codebase.

Every recipe returns a :class:`PostingRequest`. None of them writes anything — the
caller passes the result to ``post``. That split keeps the "what should happen"
decision reviewable separately from the "make it happen atomically" machinery.
"""

from __future__ import annotations

import uuid

from sqlalchemy.engine import Connection

from iwp.ledger.accounts import AccountRef, AccountType, ensure_account
from iwp.ledger.posting import PostingRequest, credit, debit
from iwp.money import Money

__all__ = [
    "funding_committed",
    "settlement_delivered",
    "settlement_failed",
    "settlement_reversed",
    "transfer_cancelled",
]


def _accounts(
    conn: Connection, *, relationship_id: uuid.UUID, provider_id: uuid.UUID, currency: str
) -> tuple[AccountRef, AccountRef, AccountRef]:
    return (
        ensure_account(conn, AccountType.PARTNER_CUSTODY, currency, scope_id=provider_id),
        ensure_account(conn, AccountType.RECIPIENT_PAYABLE, currency, scope_id=relationship_id),
        ensure_account(conn, AccountType.FEE_REVENUE, currency),
    )


def funding_committed(
    conn: Connection,
    *,
    business_txn_id: uuid.UUID,
    relationship_id: uuid.UUID,
    provider_id: uuid.UUID,
    principal: Money,
    fee: Money,
) -> PostingRequest:
    """Recipe 1 — the sender approved; funds are sourced and the obligation is created.

    The fee is recognised now rather than at delivery because that is when it is earned
    and disclosed (PRD Feature 7). :func:`settlement_failed` gives it back.
    """
    if principal.currency is not fee.currency:
        raise ValueError("principal and fee must be the same currency")
    if not principal.is_positive:
        raise ValueError("principal must be positive")
    if fee.is_negative:
        raise ValueError("fee cannot be negative")

    custody, payable, fees = _accounts(
        conn,
        relationship_id=relationship_id,
        provider_id=provider_id,
        currency=principal.currency.code,
    )
    entries = [
        debit(custody, principal + fee, "funding"),
        credit(payable, principal, "principal"),
    ]
    if fee.is_positive:
        entries.append(credit(fees, fee, "fee"))

    return PostingRequest(
        idempotency_key=f"funding_committed:{business_txn_id}",
        posting_type="funding_committed",
        entries=tuple(entries),
        business_txn_id=business_txn_id,
        description=f"commitment of {principal} plus {fee} fee",
    )


def settlement_delivered(
    conn: Connection,
    *,
    business_txn_id: uuid.UUID,
    relationship_id: uuid.UUID,
    provider_id: uuid.UUID,
    delivered: Money,
    sequence: int = 0,
) -> PostingRequest:
    """Recipes 2 and 3 — the partner confirmed delivery, in full or in part.

    A partial delivery is the same posting for a smaller amount; the residual balance
    on ``recipient_payable`` *is* the remainder. ``sequence`` distinguishes successive
    partial deliveries on one transfer so each gets its own idempotency key.
    """
    if not delivered.is_positive:
        raise ValueError("delivered amount must be positive")

    custody, payable, _ = _accounts(
        conn,
        relationship_id=relationship_id,
        provider_id=provider_id,
        currency=delivered.currency.code,
    )
    return PostingRequest(
        idempotency_key=f"settlement_delivered:{business_txn_id}:{sequence}",
        posting_type="settlement_delivered",
        entries=(
            debit(payable, delivered, "delivery"),
            credit(custody, delivered, "delivery"),
        ),
        business_txn_id=business_txn_id,
        description=f"delivery of {delivered}",
    )


def _return_to_sender(
    conn: Connection,
    *,
    posting_type: str,
    business_txn_id: uuid.UUID,
    relationship_id: uuid.UUID,
    provider_id: uuid.UUID,
    principal: Money,
    fee: Money,
    description: str,
) -> PostingRequest:
    if principal.currency is not fee.currency:
        raise ValueError("principal and fee must be the same currency")

    custody, payable, fees = _accounts(
        conn,
        relationship_id=relationship_id,
        provider_id=provider_id,
        currency=principal.currency.code,
    )
    entries = [debit(payable, principal, posting_type)]
    if fee.is_positive:
        # Debiting a credit-normal revenue account reduces it: the fee was never earned.
        entries.append(debit(fees, fee, "fee_refund"))
    entries.append(credit(custody, principal + fee, posting_type))

    return PostingRequest(
        idempotency_key=f"{posting_type}:{business_txn_id}",
        posting_type=posting_type,
        entries=tuple(entries),
        business_txn_id=business_txn_id,
        description=description,
    )


def settlement_failed(
    conn: Connection,
    *,
    business_txn_id: uuid.UUID,
    relationship_id: uuid.UUID,
    provider_id: uuid.UUID,
    principal: Money,
    fee: Money,
) -> PostingRequest:
    """Recipe 4 — the payout failed. Principal and fee both go back.

    PRD §10: funds are never silently lost.
    """
    return _return_to_sender(
        conn,
        posting_type="settlement_failed",
        business_txn_id=business_txn_id,
        relationship_id=relationship_id,
        provider_id=provider_id,
        principal=principal,
        fee=fee,
        description=f"failed settlement of {principal}; {fee} fee refunded",
    )


def transfer_cancelled(
    conn: Connection,
    *,
    business_txn_id: uuid.UUID,
    relationship_id: uuid.UUID,
    provider_id: uuid.UUID,
    principal: Money,
    fee: Money,
) -> PostingRequest:
    """Recipe 5 — the sender cancelled inside the window (PRD Feature 7).

    Same entries as a failure, different posting type: the money movement is identical
    but the reason is not, and the reason is what the receipt and history show.
    """
    return _return_to_sender(
        conn,
        posting_type="transfer_cancelled",
        business_txn_id=business_txn_id,
        relationship_id=relationship_id,
        provider_id=provider_id,
        principal=principal,
        fee=fee,
        description=f"cancelled transfer of {principal}; {fee} fee refunded",
    )


def settlement_reversed(
    conn: Connection,
    *,
    business_txn_id: uuid.UUID,
    relationship_id: uuid.UUID,
    provider_id: uuid.UUID,
    reversed_amount: Money,
    sequence: int = 0,
) -> PostingRequest:
    """Recipe 6 — a settled transfer is pulled back.

    New compensating entries. The original entries stay exactly as they were, because
    they are still true: the money did go out, and then it came back.
    """
    if not reversed_amount.is_positive:
        raise ValueError("reversed amount must be positive")

    custody, payable, _ = _accounts(
        conn,
        relationship_id=relationship_id,
        provider_id=provider_id,
        currency=reversed_amount.currency.code,
    )
    return PostingRequest(
        idempotency_key=f"settlement_reversed:{business_txn_id}:{sequence}",
        posting_type="settlement_reversed",
        entries=(
            debit(custody, reversed_amount, "reversal"),
            credit(payable, reversed_amount, "reversal"),
        ),
        business_txn_id=business_txn_id,
        description=f"reversal of {reversed_amount}",
    )
