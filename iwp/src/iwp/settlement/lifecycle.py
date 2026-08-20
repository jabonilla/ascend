"""P3.3 — settlement lifecycle.

Approval commits intent; this module carries out settlement and records what the
provider says happened. CLAUDE.md rule 4 in practice: ``intent_state`` is ours and
never changes here, ``settlement_state`` is the provider's and only changes here.

The hard part is not the happy path, it is delivery semantics. Webhooks arrive at least
once, out of order, and sometimes about a transfer we already consider finished. So:

* **Every event is recorded**, keyed by the provider's event id. A redelivery loses the
  insert race and becomes a no-op.
* **Order is resolved by state, not by arrival.** Each settlement state has a rank, and
  an event only moves us forward. A late ``in_flight`` arriving after ``settled``
  changes nothing — and is still written down, marked unapplied, because an event we
  chose to ignore is exactly what an operator needs when reconciliation disagrees.
* **Delivered amounts are cumulative and monotonic.** Partial settlement is tracked as
  an amount, never as a state (see ``iwp/states.py``), and taking the maximum makes
  duplicates and reordering harmless.
* **Ledger entries are never mutated.** Every settlement movement posts *new* balanced
  entries through the recipes in ``iwp.ledger.recipes``.
"""

from __future__ import annotations

import json
import uuid
from collections.abc import Mapping
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Final

from sqlalchemy import Engine, text
from sqlalchemy.engine import Connection
from sqlalchemy.exc import IntegrityError

from iwp.db.engine import run_serializable
from iwp.domain.audit import ActorKind, write_audit
from iwp.domain.requests import Transaction, get_transaction
from iwp.ledger.posting import post_within
from iwp.ledger.recipes import (
    funding_committed,
    settlement_delivered,
    settlement_failed,
    settlement_reversed,
    transfer_cancelled,
)
from iwp.money import Money
from iwp.settlement.provider import (
    Beneficiary,
    FundingSource,
    HoldRef,
    PayoutMethod,
    ProviderError,
    Quote,
    SettlementProvider,
)
from iwp.states import IntentState, SettlementState

__all__ = [
    "SettlementError",
    "SettlementEventOutcome",
    "apply_settlement_event",
    "cancel_settlement",
    "instruct_settlement",
    "record_provider_timeout",
]

# How far along a settlement is. An event may only move a transaction forward through
# these; anything else is recorded and ignored.
_RANK: Final[dict[SettlementState, int]] = {
    SettlementState.NOT_STARTED: 0,
    SettlementState.INSTRUCTED: 1,
    SettlementState.IN_FLIGHT: 2,
    SettlementState.SETTLED: 3,
    SettlementState.FAILED: 3,
    SettlementState.REVERSED: 4,
}


class SettlementError(Exception):
    """Settlement could not be instructed or advanced."""


@dataclass(frozen=True, slots=True)
class SettlementEventOutcome:
    transaction_id: uuid.UUID | None
    applied: bool
    reason: str
    previous_state: SettlementState | None
    new_state: SettlementState | None
    is_duplicate: bool


# --------------------------------------------------------------------------------------
# instructing
# --------------------------------------------------------------------------------------


def instruct_settlement(
    engine: Engine,
    provider: SettlementProvider,
    transaction_id: uuid.UUID,
    *,
    quote: Quote,
    now: datetime | None = None,
) -> Transaction:
    """Instruct the provider to pay out, and move settlement to ``instructed``.

    Called after approval (PRD Feature 1: "Approval triggers SettlementProvider.
    release(); the product never moves money directly").

    The ledger posting for the commitment happens here rather than at approval, in one
    transaction with the state change, so a crash cannot leave a committed transaction
    with no entries behind it.
    """
    moment = now or datetime.now(UTC)

    def work(conn: Connection) -> Transaction:
        transaction = _lock_transaction(conn, transaction_id)

        if transaction.intent_state is IntentState.CANCELLED:
            raise SettlementError(
                f"transaction {transaction_id} was cancelled and must not be instructed"
            )
        if transaction.settlement_state is not SettlementState.NOT_STARTED:
            # Already instructed. Idempotent by design: the sender may have tapped
            # twice, or a retry may be replaying the approval.
            return transaction

        beneficiary = _beneficiary_for(conn, transaction.relationship_id)
        source = _source_for(conn, transaction, provider)

        # The commitment posting first: if release() times out we must already have a
        # record that the money was committed, or reconciliation has nothing to match.
        post_within(
            conn,
            funding_committed(
                conn,
                business_txn_id=transaction.id,
                relationship_id=transaction.relationship_id,
                provider_id=_provider_scope(provider),
                principal=transaction.amount,
                fee=transaction.fee,
            ),
        )

        # A network call inside a database transaction, deliberately. The alternative —
        # release first, record after — has a window where the provider is paying and we
        # have no record of it. This way the window is the other way round: if the
        # transaction rolls back after release() succeeded, the retry calls release()
        # again with the same idempotency key and gets the same reference back. The
        # cost is a transaction held open across a network round trip, which is a real
        # cost and the reason the row lock is on one transaction rather than the table.
        settlement_ref = provider.release(
            source=source,
            beneficiary=beneficiary,
            amount=transaction.amount,
            quote=quote,
            idempotency_key=f"release:{transaction.id}",
        )

        conn.execute(
            text(
                """
                UPDATE transaction
                SET settlement_state = :state,
                    settlement_provider = :provider,
                    provider_reference_id = :reference,
                    fx_rate_applied = :fx_rate,
                    recipient_amount = :recipient_amount,
                    recipient_currency = :recipient_currency,
                    updated_at = now()
                WHERE id = :id
                """
            ),
            {
                "state": SettlementState.INSTRUCTED.value,
                "provider": provider.name,
                "reference": settlement_ref.reference,
                "fx_rate": quote.fx_rate,
                "recipient_amount": quote.recipient_amount.minor_units,
                "recipient_currency": quote.recipient_amount.currency.code,
                "id": transaction.id,
            },
        )
        write_audit(
            conn,
            action="settlement.instructed",
            entity_type="transaction",
            entity_id=transaction.id,
            actor_kind=ActorKind.SYSTEM,
            before_state={"settlement_state": SettlementState.NOT_STARTED.value},
            after_state={
                "settlement_state": SettlementState.INSTRUCTED.value,
                "provider_reference_id": settlement_ref.reference,
                # Reconciliation compares the provider's value date against when we
                # instructed (P1.5 timing discrepancies), and this row is where that
                # instant is on record.
                "instructed_at": moment.isoformat(),
            },
        )
        return get_transaction(conn, transaction.id)

    return run_serializable(engine, work)


def record_provider_timeout(
    engine: Engine, transaction_id: uuid.UUID, provider_name: str, *, detail: str
) -> None:
    """Record that an instruction timed out without a confirmed outcome.

    Deliberately does **not** move settlement state. A timeout means the instruction may
    or may not exist at the provider; guessing either way is how money gets sent twice
    or lost. It stays ``not_started`` and reconciliation (P1.5) decides, which is the
    whole reason reconciliation is built before the partner is chosen.
    """
    with engine.begin() as conn:
        write_audit(
            conn,
            action="settlement.timeout",
            entity_type="transaction",
            entity_id=transaction_id,
            actor_kind=ActorKind.SYSTEM,
            after_state={
                "provider": provider_name,
                "detail": detail,
                "resolution": "left for reconciliation; state deliberately unchanged",
            },
        )
        _enqueue(
            conn,
            topic="settlement.needs_attention",
            dedupe_key=f"timeout:{transaction_id}",
            recipient_user_id=None,
            payload={"transaction_id": str(transaction_id), "detail": detail},
        )


# --------------------------------------------------------------------------------------
# webhooks
# --------------------------------------------------------------------------------------


def apply_settlement_event(
    engine: Engine,
    *,
    provider_name: str,
    provider_event_id: str,
    provider_reference: str,
    state: SettlementState,
    delivered_amount: Money,
    sequence: int,
    occurred_at: datetime,
) -> SettlementEventOutcome:
    """Apply one provider webhook.

    Safe to call with the same event any number of times, in any order relative to
    other events for the same transfer.
    """

    def work(conn: Connection) -> SettlementEventOutcome:
        transaction_row = (
            conn.execute(
                text(
                    """
                    SELECT id FROM transaction
                    WHERE provider_reference_id = :ref AND settlement_provider = :provider
                    FOR UPDATE
                    """
                ),
                {"ref": provider_reference, "provider": provider_name},
            )
            .mappings()
            .one_or_none()
        )

        if transaction_row is None:
            # An event for something we have no record of. Recorded, never guessed at:
            # reconciliation will report it as `unexpected` (P1.5).
            recorded = _record_event(
                conn,
                provider_name=provider_name,
                provider_event_id=provider_event_id,
                transaction_id=None,
                provider_reference=provider_reference,
                state=state,
                delivered_amount=delivered_amount,
                sequence=sequence,
                occurred_at=occurred_at,
                applied=False,
                reason="no transaction matches this provider reference",
            )
            return SettlementEventOutcome(
                transaction_id=None,
                applied=False,
                reason="unknown provider reference",
                previous_state=None,
                new_state=None,
                is_duplicate=not recorded,
            )

        transaction = get_transaction(conn, transaction_row["id"])
        previous = transaction.settlement_state
        applied, reason = _should_apply(previous, state)

        recorded = _record_event(
            conn,
            provider_name=provider_name,
            provider_event_id=provider_event_id,
            transaction_id=transaction.id,
            provider_reference=provider_reference,
            state=state,
            delivered_amount=delivered_amount,
            sequence=sequence,
            occurred_at=occurred_at,
            applied=applied,
            reason=reason,
        )
        if not recorded:
            # We have seen this exact event before. Whatever it was going to do, it
            # already did.
            return SettlementEventOutcome(
                transaction_id=transaction.id,
                applied=False,
                reason="duplicate event",
                previous_state=previous,
                new_state=previous,
                is_duplicate=True,
            )

        if not applied:
            return SettlementEventOutcome(
                transaction_id=transaction.id,
                applied=False,
                reason=reason,
                previous_state=previous,
                new_state=previous,
                is_duplicate=False,
            )

        _advance(
            conn,
            transaction=transaction,
            new_state=state,
            delivered_amount=delivered_amount,
            sequence=sequence,
        )
        return SettlementEventOutcome(
            transaction_id=transaction.id,
            applied=True,
            reason="",
            previous_state=previous,
            new_state=state,
            is_duplicate=False,
        )

    return run_serializable(engine, work)


def _should_apply(current: SettlementState, incoming: SettlementState) -> tuple[bool, str]:
    """Decide by state, not by arrival order."""
    if incoming is SettlementState.REVERSED:
        # A reversal only makes sense against something that settled.
        if current is not SettlementState.SETTLED:
            return False, f"cannot reverse from {current.value}"
        return True, ""
    if _RANK[incoming] > _RANK[current]:
        return True, ""
    if _RANK[incoming] == _RANK[current] and incoming is not current:
        # settled vs failed for the same transfer: the provider is contradicting
        # itself. Never resolved here — recorded, and reconciliation reports it.
        return (
            False,
            f"conflicting terminal state: ours is {current.value}, event says {incoming.value}",
        )
    return False, f"event state {incoming.value} does not advance {current.value}"


def _advance(
    conn: Connection,
    *,
    transaction: Transaction,
    new_state: SettlementState,
    delivered_amount: Money,
    sequence: int,
) -> None:
    """Move settlement state and post the ledger entries the movement implies."""
    if delivered_amount.currency is not transaction.amount.currency:
        raise SettlementError(
            f"event delivered {delivered_amount.currency.code} against a "
            f"{transaction.amount.currency.code} transaction"
        )

    # Cumulative and monotonic, so duplicates and reordering cannot reduce it.
    settled_so_far = max(transaction.settled_amount, delivered_amount)
    if new_state is SettlementState.SETTLED:
        settled_so_far = max(settled_so_far, transaction.amount)
    if new_state in (SettlementState.FAILED, SettlementState.REVERSED):
        settled_so_far = Money.zero(transaction.amount.currency)

    newly_delivered = settled_so_far - transaction.settled_amount

    conn.execute(
        text(
            """
            UPDATE transaction
            SET settlement_state = :state,
                settled_amount = :settled,
                failure_reason = CASE WHEN :state = 'failed'
                    THEN COALESCE(NULLIF(failure_reason, ''), 'reported failed by provider')
                    ELSE failure_reason END,
                -- Once the provider has the money in motion there is nothing left to
                -- cancel from our side.
                cancellable_until = CASE WHEN :state IN ('in_flight', 'settled')
                    THEN NULL ELSE cancellable_until END,
                updated_at = now()
            WHERE id = :id
            """
        ),
        {
            "state": new_state.value,
            "settled": settled_so_far.minor_units,
            "id": transaction.id,
        },
    )

    if newly_delivered.is_positive:
        post_within(
            conn,
            settlement_delivered(
                conn,
                business_txn_id=transaction.id,
                relationship_id=transaction.relationship_id,
                provider_id=_provider_scope_by_name(transaction),
                delivered=newly_delivered,
                sequence=sequence,
            ),
        )

    if new_state is SettlementState.FAILED:
        post_within(
            conn,
            settlement_failed(
                conn,
                business_txn_id=transaction.id,
                relationship_id=transaction.relationship_id,
                provider_id=_provider_scope_by_name(transaction),
                principal=transaction.amount - transaction.settled_amount,
                fee=transaction.fee,
            ),
        )
    elif new_state is SettlementState.REVERSED and transaction.settled_amount.is_positive:
        post_within(
            conn,
            settlement_reversed(
                conn,
                business_txn_id=transaction.id,
                relationship_id=transaction.relationship_id,
                provider_id=_provider_scope_by_name(transaction),
                reversed_amount=transaction.settled_amount,
                sequence=sequence,
            ),
        )

    write_audit(
        conn,
        action=f"settlement.{new_state.value}",
        entity_type="transaction",
        entity_id=transaction.id,
        actor_kind=ActorKind.PROVIDER,
        before_state={
            "settlement_state": transaction.settlement_state.value,
            "settled_amount": transaction.settled_amount.minor_units,
        },
        after_state={
            "settlement_state": new_state.value,
            "settled_amount": settled_so_far.minor_units,
        },
    )
    _notify_parties(conn, transaction, new_state, settled_so_far)


def _notify_parties(
    conn: Connection,
    transaction: Transaction,
    new_state: SettlementState,
    settled: Money,
) -> None:
    """Queue notifications for both parties, in the same transaction as the change.

    PRD §10: on a partner payout failure "both parties notified with plain-language
    reason and next step. Funds are never silently lost." Enqueuing here rather than
    sending here is what makes that survive a crash.
    """
    interesting = {
        SettlementState.SETTLED: "settlement.settled",
        SettlementState.FAILED: "settlement.failed",
        SettlementState.REVERSED: "settlement.reversed",
    }
    topic = interesting.get(new_state)
    if topic is None and not (new_state is SettlementState.IN_FLIGHT and settled.is_positive):
        return
    if topic is None:
        topic = "settlement.partial"

    parties = (
        conn.execute(
            text("SELECT user_a_id, user_b_id FROM relationship WHERE id = :r"),
            {"r": transaction.relationship_id},
        )
        .mappings()
        .one()
    )
    payload = {
        "transaction_id": str(transaction.id),
        "reference_number": transaction.reference_number,
        "settlement_state": new_state.value,
        "amount_minor_units": transaction.amount.minor_units,
        "settled_minor_units": settled.minor_units,
        "currency": transaction.amount.currency.code,
    }
    for user_id in (parties["user_a_id"], parties["user_b_id"]):
        _enqueue(
            conn,
            topic=topic,
            dedupe_key=f"{topic}:{transaction.id}:{new_state.value}:{settled.minor_units}:{user_id}",
            recipient_user_id=user_id,
            payload=payload,
        )


def _enqueue(
    conn: Connection,
    *,
    topic: str,
    dedupe_key: str,
    recipient_user_id: uuid.UUID | None,
    payload: Mapping[str, object],
) -> None:
    conn.execute(
        text(
            """
            INSERT INTO outbox (topic, dedupe_key, recipient_user_id, payload)
            VALUES (:topic, :dedupe_key, :user_id, CAST(:payload AS JSONB))
            ON CONFLICT (dedupe_key) DO NOTHING
            """
        ),
        {
            "topic": topic,
            "dedupe_key": dedupe_key,
            "user_id": recipient_user_id,
            "payload": json.dumps(payload),
        },
    )


def _record_event(
    conn: Connection,
    *,
    provider_name: str,
    provider_event_id: str,
    transaction_id: uuid.UUID | None,
    provider_reference: str,
    state: SettlementState,
    delivered_amount: Money,
    sequence: int,
    occurred_at: datetime,
    applied: bool,
    reason: str,
) -> bool:
    """Write the event. Returns False if we had already seen it."""
    try:
        with conn.begin_nested():
            conn.execute(
                text(
                    """
                    INSERT INTO settlement_event
                        (provider, provider_event_id, transaction_id, provider_reference,
                         state, delivered_amount, currency, sequence, occurred_at,
                         applied, not_applied_reason)
                    VALUES
                        (:provider, :event_id, :transaction_id, :reference, :state,
                         :delivered, :currency, :sequence, :occurred_at, :applied, :reason)
                    """
                ),
                {
                    "provider": provider_name,
                    "event_id": provider_event_id,
                    "transaction_id": transaction_id,
                    "reference": provider_reference,
                    "state": state.value,
                    "delivered": delivered_amount.minor_units,
                    "currency": delivered_amount.currency.code,
                    "sequence": sequence,
                    "occurred_at": occurred_at,
                    "applied": applied,
                    "reason": reason,
                },
            )
    except IntegrityError:
        return False
    return True


# --------------------------------------------------------------------------------------
# cancellation
# --------------------------------------------------------------------------------------


def cancel_settlement(
    engine: Engine,
    provider: SettlementProvider,
    transaction_id: uuid.UUID,
    *,
    actor_id: uuid.UUID,
) -> Transaction:
    """Post the compensating entries for a cancelled transfer (PRD Feature 7).

    The intent half happens in ``domain.requests.cancel_transaction``; this is the money
    half. Kept separate because they answer to different authorities: intent is ours,
    settlement is the provider's.
    """

    def work(conn: Connection) -> Transaction:
        transaction = _lock_transaction(conn, transaction_id)
        if transaction.intent_state is not IntentState.CANCELLED:
            raise SettlementError(
                f"transaction {transaction_id} has not been cancelled; cancel intent first"
            )
        if transaction.settlement_state not in (
            SettlementState.NOT_STARTED,
            SettlementState.INSTRUCTED,
        ):
            raise SettlementError(
                f"transaction {transaction_id} is {transaction.settlement_state.value} "
                "and can no longer be pulled back from here"
            )

        if transaction.settlement_state is SettlementState.INSTRUCTED:
            post_within(
                conn,
                transfer_cancelled(
                    conn,
                    business_txn_id=transaction.id,
                    relationship_id=transaction.relationship_id,
                    provider_id=_provider_scope(provider),
                    principal=transaction.amount,
                    fee=transaction.fee,
                ),
            )
            _recall_from_provider(conn, provider, transaction)

        write_audit(
            conn,
            action="settlement.cancelled",
            entity_type="transaction",
            entity_id=transaction.id,
            actor_id=actor_id,
            before_state={"settlement_state": transaction.settlement_state.value},
            after_state={"settlement_state": transaction.settlement_state.value},
        )
        return get_transaction(conn, transaction.id)

    return run_serializable(engine, work)


# --------------------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------------------


def _recall_from_provider(
    conn: Connection, provider: SettlementProvider, transaction: Transaction
) -> None:
    """Try to stop an instruction the provider has already accepted.

    Our books say the money came back the moment the sender cancelled. Whether the
    *provider* can also be stopped is a capability question, and the two can disagree:

    * where reversal is supported, we ask for one;
    * where it is not, the payout may still go out. That is flagged for a human rather
      than assumed away, and reconciliation will report the settled line we no longer
      expect (P1.5) — which is exactly the disagreement it exists to catch.
    """
    reference = transaction.provider_reference_id
    if reference is None:  # pragma: no cover - instructed implies a reference
        return

    if not provider.capabilities().supports_reversal:
        _enqueue(
            conn,
            topic="settlement.needs_attention",
            dedupe_key=f"uncancellable:{transaction.id}",
            recipient_user_id=None,
            payload={
                "transaction_id": str(transaction.id),
                "provider_reference": reference,
                "detail": (
                    "the sender cancelled after the instruction was accepted, and this "
                    "provider does not support reversal. The payout may still complete."
                ),
            },
        )
        return

    try:
        provider.reverse(reference, idempotency_key=f"cancel-reverse:{transaction.id}")
    except ProviderError as exc:
        # A failed recall does not undo the cancellation on our side; it becomes a
        # discrepancy for a person, which is the honest outcome.
        _enqueue(
            conn,
            topic="settlement.needs_attention",
            dedupe_key=f"recall-failed:{transaction.id}",
            recipient_user_id=None,
            payload={
                "transaction_id": str(transaction.id),
                "provider_reference": reference,
                "detail": f"recall refused by the provider: {exc}",
            },
        )


def _lock_transaction(conn: Connection, transaction_id: uuid.UUID) -> Transaction:
    locked = conn.execute(
        text("SELECT id FROM transaction WHERE id = :id FOR UPDATE"), {"id": transaction_id}
    ).scalar_one_or_none()
    if locked is None:
        raise LookupError(f"no such transaction: {transaction_id}")
    return get_transaction(conn, transaction_id)


def _beneficiary_for(conn: Connection, relationship_id: uuid.UUID) -> Beneficiary:
    row = (
        conn.execute(
            text(
                """
                SELECT payout_method, account_reference, holder_name
                FROM payout_destination
                WHERE relationship_id = :r AND status = 'active' AND is_default
                """
            ),
            {"r": relationship_id},
        )
        .mappings()
        .one_or_none()
    )
    if row is None:
        raise SettlementError(f"relationship {relationship_id} has no active payout destination")
    return Beneficiary(
        relationship_id=relationship_id,
        name=row["holder_name"],
        payout_method=PayoutMethod(row["payout_method"]),
        account_reference=row["account_reference"],
    )


def _source_for(
    conn: Connection, transaction: Transaction, provider: SettlementProvider
) -> HoldRef | FundingSource:
    """Where the money comes from.

    This is the one place the two custody shapes differ, and it differs by *capability*,
    not by provider identity: a provider that holds balances gets a hold, one that does
    not gets the sender's funding source.
    """
    if provider.capabilities().supports_held_balance:
        return provider.hold(
            user_id=transaction.approved_by,
            amount=transaction.amount + transaction.fee,
            idempotency_key=f"hold:{transaction.id}",
        )

    reference = conn.execute(
        text(
            """
            SELECT provider_reference FROM funding_source
            WHERE user_id = :u AND status = 'active' AND is_default
            """
        ),
        {"u": transaction.approved_by},
    ).scalar_one_or_none()
    if reference is None:
        raise SettlementError(
            f"user {transaction.approved_by} has no active default funding source"
        )
    return FundingSource(reference=reference, user_id=transaction.approved_by)


def _provider_scope(provider: SettlementProvider) -> uuid.UUID:
    """A stable account scope id for a provider.

    Derived from the adapter name so the custody account is the same row across
    restarts, without a provider table the ledger would have to know about.
    """
    return uuid.uuid5(uuid.NAMESPACE_URL, f"iwp:settlement-provider:{provider.name}")


def _provider_scope_by_name(transaction: Transaction) -> uuid.UUID:
    """The custody account scope for the provider this transaction was instructed to.

    Read from the transaction rather than from the current configuration: entries must
    land on the account of the provider that actually holds the money, even if the
    deployment has since been switched to a different one.
    """
    if transaction.settlement_provider is None:
        raise SettlementError(
            f"transaction {transaction.id} has no settlement provider recorded; "
            "it cannot have a settlement event"
        )
    return uuid.uuid5(
        uuid.NAMESPACE_URL, f"iwp:settlement-provider:{transaction.settlement_provider}"
    )
