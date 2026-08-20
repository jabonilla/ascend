"""P2.4 — request and approval state machine.

The only legal transitions are ``pending → approved | declined | expired``. There is no
path from a resolved request to any other state, and no path that produces a
``Transaction`` from a declined request.

Three properties this module is built around:

* **Idempotent.** Requests arrive over channels with at-least-once delivery, and a
  sender may tap Approve twice on a flaky connection. Every entry point tolerates
  repetition: submission is keyed by the inbound message id, and approval is keyed by
  a UNIQUE constraint on ``transaction.request_id`` rather than a check-then-insert.
* **Audited.** Every transition writes exactly one audit row carrying actor, channel
  and assurance level, in the same transaction as the transition.
* **Never a dead end.** Replying to a request that has already been resolved returns
  the resolution, not an error — the recipient on the far end of an SMS gets told what
  happened (PRD Feature 4).
"""

from __future__ import annotations

import secrets
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from sqlalchemy import Engine, text
from sqlalchemy.engine import Connection, RowMapping
from sqlalchemy.exc import IntegrityError

from iwp.domain.audit import ActorKind, write_audit
from iwp.domain.plans import get_active_version, get_plan_for_relationship, list_rules
from iwp.domain.tiers import (
    CategorySnapshot,
    RuleSnapshot,
    TierDecision,
    TierInput,
    TierReason,
    TrustTier,
    classify,
)
from iwp.money import Money
from iwp.settings_store import get_int
from iwp.states import IntentState, RelationshipStatus, RequestStatus, SettlementState

__all__ = [
    "ApprovalOutcome",
    "Request",
    "RequestError",
    "SubmissionOutcome",
    "Transaction",
    "approve_request",
    "cancel_transaction",
    "decline_request",
    "expire_due_requests",
    "get_request",
    "get_transaction",
    "list_requests",
    "submit_request",
]

# Customer-facing reference on receipts (PRD Feature 7). The prefix is deliberately
# neutral: the product name is an open question (PRD §13) and this string ends up
# printed on things.
_REFERENCE_PREFIX = "REF"
_REFERENCE_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"  # Crockford: no I, L, O, U


class RequestError(Exception):
    """A request could not be submitted or transitioned."""


@dataclass(frozen=True, slots=True)
class Request:
    id: uuid.UUID
    relationship_id: uuid.UUID
    requested_by: uuid.UUID
    amount: Money
    category_id: uuid.UUID | None
    description: str
    tier: TrustTier
    tier_reason: TierReason
    is_emergency: bool
    channel_of_origin: str
    status: RequestStatus
    resolved_by: uuid.UUID | None
    resolved_at: datetime | None
    decline_reason: str | None
    expires_at: datetime
    created_at: datetime


@dataclass(frozen=True, slots=True)
class Transaction:
    id: uuid.UUID
    request_id: uuid.UUID
    relationship_id: uuid.UUID
    amount: Money
    fee: Money
    intent_state: IntentState
    settlement_state: SettlementState
    approved_by: uuid.UUID
    approved_at: datetime
    assurance_level_at_approval: str
    approval_channel: str
    reference_number: str
    cancellable_until: datetime | None
    settled_amount: Money
    settlement_provider: str | None
    provider_reference_id: str | None
    failure_reason: str | None


@dataclass(frozen=True, slots=True)
class ApprovalOutcome:
    request: Request
    transaction: Transaction
    already_resolved: bool
    """True when this approval replayed an approval that had already happened."""


@dataclass(frozen=True, slots=True)
class SubmissionOutcome:
    request: Request
    decision: TierDecision
    is_duplicate: bool
    emergency_rate_limit_hit: bool
    """PRD Feature 3: past the limit both parties get a *soft warning*. The request is
    still created — a rate limit that blocked an emergency would be the product working
    against the person it exists for."""


# --------------------------------------------------------------------------------------
# reading
# --------------------------------------------------------------------------------------

_REQUEST_COLUMNS = """
    id, relationship_id, requested_by, amount, currency, category_id, description,
    tier, tier_reason, is_emergency, channel_of_origin, status, resolved_by,
    resolved_at, decline_reason, expires_at, created_at
"""


def _row_to_request(row: RowMapping) -> Request:
    return Request(
        id=row["id"],
        relationship_id=row["relationship_id"],
        requested_by=row["requested_by"],
        amount=Money(int(row["amount"]), str(row["currency"])),
        category_id=row["category_id"],
        description=row["description"],
        tier=TrustTier(row["tier"]),
        tier_reason=TierReason(row["tier_reason"]),
        is_emergency=row["is_emergency"],
        channel_of_origin=row["channel_of_origin"],
        status=RequestStatus(row["status"]),
        resolved_by=row["resolved_by"],
        resolved_at=row["resolved_at"],
        decline_reason=row["decline_reason"],
        expires_at=row["expires_at"],
        created_at=row["created_at"],
    )


def _load_request(conn: Connection, request_id: uuid.UUID, *, for_update: bool = False) -> Request:
    row = (
        conn.execute(
            text(
                f"SELECT {_REQUEST_COLUMNS} FROM request WHERE id = :id"
                + (" FOR UPDATE" if for_update else "")
            ),
            {"id": request_id},
        )
        .mappings()
        .one_or_none()
    )
    if row is None:
        raise LookupError(f"no such request: {request_id}")
    return _row_to_request(row)


def get_request(conn: Connection, request_id: uuid.UUID) -> Request:
    return _load_request(conn, request_id)


def list_requests(
    conn: Connection,
    relationship_id: uuid.UUID,
    *,
    statuses: frozenset[RequestStatus] | None = None,
    limit: int = 100,
) -> list[Request]:
    clause = ""
    params: dict[str, object] = {"r": relationship_id, "limit": limit}
    if statuses:
        clause = " AND status = ANY(:statuses)"
        params["statuses"] = [s.value for s in statuses]
    rows = (
        conn.execute(
            text(
                f"SELECT {_REQUEST_COLUMNS} FROM request WHERE relationship_id = :r"
                + clause
                + " ORDER BY created_at DESC LIMIT :limit"
            ),
            params,
        )
        .mappings()
        .all()
    )
    return [_row_to_request(row) for row in rows]


_TRANSACTION_COLUMNS = """
    id, request_id, relationship_id, amount, currency, fee_amount, settled_amount,
    intent_state, settlement_state, approved_by, approved_at,
    assurance_level_at_approval, approval_channel, reference_number, cancellable_until,
    settlement_provider, provider_reference_id, failure_reason
"""


def _row_to_transaction(row: RowMapping) -> Transaction:
    currency = str(row["currency"])
    return Transaction(
        id=row["id"],
        request_id=row["request_id"],
        relationship_id=row["relationship_id"],
        amount=Money(int(row["amount"]), currency),
        fee=Money(int(row["fee_amount"]), currency),
        intent_state=IntentState(row["intent_state"]),
        settlement_state=SettlementState(row["settlement_state"]),
        approved_by=row["approved_by"],
        approved_at=row["approved_at"],
        assurance_level_at_approval=row["assurance_level_at_approval"],
        approval_channel=row["approval_channel"],
        reference_number=row["reference_number"],
        cancellable_until=row["cancellable_until"],
        settled_amount=Money(int(row["settled_amount"]), currency),
        settlement_provider=row["settlement_provider"],
        provider_reference_id=row["provider_reference_id"],
        failure_reason=row["failure_reason"],
    )


def _load_transaction_by_request(conn: Connection, request_id: uuid.UUID) -> Transaction | None:
    row = (
        conn.execute(
            text(f"SELECT {_TRANSACTION_COLUMNS} FROM transaction WHERE request_id = :r"),
            {"r": request_id},
        )
        .mappings()
        .one_or_none()
    )
    return None if row is None else _row_to_transaction(row)


def get_transaction(conn: Connection, transaction_id: uuid.UUID) -> Transaction:
    row = (
        conn.execute(
            text(f"SELECT {_TRANSACTION_COLUMNS} FROM transaction WHERE id = :id"),
            {"id": transaction_id},
        )
        .mappings()
        .one_or_none()
    )
    if row is None:
        raise LookupError(f"no such transaction: {transaction_id}")
    return _row_to_transaction(row)


# --------------------------------------------------------------------------------------
# submission
# --------------------------------------------------------------------------------------


def submit_request(
    engine: Engine,
    *,
    relationship_id: uuid.UUID,
    requested_by: uuid.UUID,
    amount: Money,
    category_key: str | None,
    description: str,
    channel: str,
    is_emergency: bool = False,
    idempotency_key: str | None = None,
    now: datetime | None = None,
) -> SubmissionOutcome:
    """Submit a request and classify it (PRD Feature 1).

    ``idempotency_key`` is the inbound provider message id where there is one. Passing
    it makes a redelivered WhatsApp or SMS message produce one request, not two.
    """
    if not amount.is_positive:
        raise RequestError("a request amount must be positive")
    if len(description) > 200:
        raise RequestError("description is limited to 200 characters (PRD Feature 1)")

    moment = now or datetime.now(UTC)

    with engine.begin() as conn:
        if idempotency_key:
            existing = (
                conn.execute(
                    text(f"SELECT {_REQUEST_COLUMNS} FROM request WHERE idempotency_key = :k"),
                    {"k": idempotency_key},
                )
                .mappings()
                .one_or_none()
            )
            if existing is not None:
                request = _row_to_request(existing)
                return SubmissionOutcome(
                    request=request,
                    decision=TierDecision(tier=request.tier, reason=request.tier_reason, note=""),
                    is_duplicate=True,
                    emergency_rate_limit_hit=False,
                )

        status = conn.execute(
            text("SELECT status FROM relationship WHERE id = :r"), {"r": relationship_id}
        ).scalar_one_or_none()
        if status is None:
            raise LookupError(f"no such relationship: {relationship_id}")
        relationship_status = RelationshipStatus(status)
        if relationship_status is not RelationshipStatus.ACTIVE:
            raise RequestError(
                f"relationship {relationship_id} is {relationship_status.value}; "
                "no new requests are permitted"
            )

        decision, category_id = _classify_in_context(
            conn,
            relationship_id=relationship_id,
            amount=amount,
            category_key=category_key,
            is_emergency=is_emergency,
            now=moment,
        )

        rate_limited = False
        if is_emergency:
            rate_limited = _emergency_rate_limit_hit(conn, relationship_id, moment)

        expiry_key = "request.emergency_expiry_hours" if is_emergency else "request.expiry_hours"
        expires_at = moment + timedelta(hours=get_int(conn, expiry_key))

        request_id = conn.execute(
            text(
                """
                INSERT INTO request
                    (relationship_id, requested_by, amount, currency, category_id,
                     description, tier, tier_reason, is_emergency, channel_of_origin,
                     expires_at, idempotency_key)
                VALUES
                    (:relationship_id, :requested_by, :amount, :currency, :category_id,
                     :description, :tier, :tier_reason, :is_emergency, :channel,
                     :expires_at, :idempotency_key)
                RETURNING id
                """
            ),
            {
                "relationship_id": relationship_id,
                "requested_by": requested_by,
                "amount": amount.minor_units,
                "currency": amount.currency.code,
                "category_id": category_id,
                "description": description,
                "tier": decision.tier.value,
                "tier_reason": decision.reason.value,
                "is_emergency": is_emergency,
                "channel": channel,
                "expires_at": expires_at,
                "idempotency_key": idempotency_key,
            },
        ).scalar_one()

        write_audit(
            conn,
            action="request.submitted",
            entity_type="request",
            entity_id=request_id,
            actor_id=requested_by,
            channel=channel,
            after_state={
                "status": RequestStatus.PENDING.value,
                "tier": decision.tier.value,
                "tier_reason": decision.reason.value,
                "amount": amount.minor_units,
                "currency": amount.currency.code,
                "is_emergency": is_emergency,
            },
        )
        request = _load_request(conn, request_id)

    return SubmissionOutcome(
        request=request,
        decision=decision,
        is_duplicate=False,
        emergency_rate_limit_hit=rate_limited,
    )


def _classify_in_context(
    conn: Connection,
    *,
    relationship_id: uuid.UUID,
    amount: Money,
    category_key: str | None,
    is_emergency: bool,
    now: datetime,
) -> tuple[TierDecision, uuid.UUID | None]:
    """Assemble the tier snapshot from the plan in force and classify.

    All the reading happens here; :func:`iwp.domain.tiers.classify` stays pure.
    """
    plan_id = get_plan_for_relationship(conn, relationship_id)
    if plan_id is None:
        return (
            classify(
                TierInput(
                    amount=amount,
                    category_key=category_key,
                    is_emergency=is_emergency,
                    categories=(),
                    rules=(),
                    month_to_date=Money.zero(amount.currency),
                )
            ),
            None,
        )

    version = get_active_version(conn, plan_id)
    category = version.category(category_key) if category_key else None
    rules = list_rules(conn, plan_id)

    month_to_date = (
        _month_to_date(conn, relationship_id, category_key, amount.currency.code, now)
        if category_key
        else Money.zero(amount.currency)
    )

    decision = classify(
        TierInput(
            amount=amount,
            category_key=category_key,
            is_emergency=is_emergency,
            categories=tuple(
                CategorySnapshot(key=c.key, monthly_cap=c.monthly_cap) for c in version.categories
            ),
            rules=tuple(
                RuleSnapshot(category_key=r.category_key, amount=r.amount, status=r.status)
                for r in rules
            ),
            month_to_date=month_to_date,
        )
    )
    return decision, category.id if category else None


def _month_to_date(
    conn: Connection,
    relationship_id: uuid.UUID,
    category_key: str,
    currency: str,
    now: datetime,
) -> Money:
    """Committed spend in this category, this calendar month.

    Counts *committed* transactions rather than settled ones: a cap is a promise about
    what the sender agreed to, and the money is agreed at approval. Cancelled
    transactions do not count, because their intent was withdrawn.
    """
    month_start = now.astimezone(UTC).replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    total = conn.execute(
        text(
            """
            SELECT COALESCE(SUM(t.amount), 0)
            FROM transaction t
            JOIN request r ON r.id = t.request_id
            JOIN category c ON c.id = r.category_id
            WHERE t.relationship_id = :rel
              AND c.category_key = :key
              AND t.currency = :currency
              AND t.intent_state = 'committed'
              AND t.approved_at >= :month_start
            """
        ),
        {
            "rel": relationship_id,
            "key": category_key,
            "currency": currency,
            "month_start": month_start,
        },
    ).scalar_one()
    return Money(int(total), currency)


def _emergency_rate_limit_hit(conn: Connection, relationship_id: uuid.UUID, now: datetime) -> bool:
    """PRD Feature 3: max 3 emergency requests per relationship per 7 days.

    Counted, not enforced. Past the limit both parties get a soft warning; the request
    is still created.
    """
    limit = get_int(conn, "request.emergency_limit_per_7_days")
    recent = conn.execute(
        text(
            """
            SELECT count(*) FROM request
            WHERE relationship_id = :r AND is_emergency AND created_at >= :since
            """
        ),
        {"r": relationship_id, "since": now - timedelta(days=7)},
    ).scalar_one()
    return int(recent) >= limit


# --------------------------------------------------------------------------------------
# resolution
# --------------------------------------------------------------------------------------


def _reference_number() -> str:
    body = "".join(secrets.choice(_REFERENCE_ALPHABET) for _ in range(10))
    return f"{_REFERENCE_PREFIX}-{body[:5]}-{body[5:]}"


def approve_request(
    engine: Engine,
    request_id: uuid.UUID,
    *,
    approved_by: uuid.UUID,
    channel: str,
    assurance_level: str,
    fee: Money | None = None,
    now: datetime | None = None,
) -> ApprovalOutcome:
    """Approve a pending request, creating a committed Transaction.

    Approving an already-approved request is a no-op that returns the original
    transaction: the sender tapping twice, or a webhook redelivering, must not move
    money twice.
    """
    moment = now or datetime.now(UTC)

    with engine.begin() as conn:
        request = _load_request(conn, request_id, for_update=True)

        if request.status is RequestStatus.APPROVED:
            existing = _load_transaction_by_request(conn, request_id)
            if existing is None:  # pragma: no cover - the UNIQUE constraint prevents it
                raise RequestError(
                    f"request {request_id} is approved but has no transaction; "
                    "this is a data integrity failure, not a retryable condition"
                )
            return ApprovalOutcome(request=request, transaction=existing, already_resolved=True)

        if request.status is not RequestStatus.PENDING:
            raise RequestError(
                f"request {request_id} is {request.status.value} and cannot be approved"
            )

        fee_amount = fee or Money.zero(request.amount.currency)
        if fee_amount.currency is not request.amount.currency:
            raise RequestError("fee currency must match the request currency")

        cancellation_minutes = get_int(conn, "transfer.cancellation_window_minutes")

        conn.execute(
            text(
                """
                UPDATE request
                SET status = 'approved', resolved_by = :by, resolved_at = :at
                WHERE id = :id
                """
            ),
            {"by": approved_by, "at": moment, "id": request_id},
        )

        try:
            transaction_id = conn.execute(
                text(
                    """
                    INSERT INTO transaction
                        (request_id, relationship_id, amount, currency, fee_amount,
                         intent_state, settlement_state, approved_by, approved_at,
                         assurance_level_at_approval, approval_channel,
                         cancellable_until, reference_number)
                    VALUES
                        (:request_id, :relationship_id, :amount, :currency, :fee,
                         'committed', 'not_started', :approved_by, :approved_at,
                         :assurance, :channel, :cancellable_until, :reference)
                    RETURNING id
                    """
                ),
                {
                    "request_id": request_id,
                    "relationship_id": request.relationship_id,
                    "amount": request.amount.minor_units,
                    "currency": request.amount.currency.code,
                    "fee": fee_amount.minor_units,
                    "approved_by": approved_by,
                    "approved_at": moment,
                    "assurance": assurance_level,
                    "channel": channel,
                    "cancellable_until": moment + timedelta(minutes=cancellation_minutes),
                    "reference": _reference_number(),
                },
            ).scalar_one()
        except IntegrityError as exc:  # pragma: no cover - guarded by FOR UPDATE above
            raise RequestError(f"request {request_id} already has a transaction") from exc

        write_audit(
            conn,
            action="request.approved",
            entity_type="request",
            entity_id=request_id,
            actor_id=approved_by,
            assurance_level=assurance_level,
            channel=channel,
            before_state={"status": RequestStatus.PENDING.value},
            after_state={
                "status": RequestStatus.APPROVED.value,
                "transaction_id": str(transaction_id),
                "intent_state": IntentState.COMMITTED.value,
                "settlement_state": SettlementState.NOT_STARTED.value,
            },
        )

        return ApprovalOutcome(
            request=_load_request(conn, request_id),
            transaction=get_transaction(conn, transaction_id),
            already_resolved=False,
        )


def decline_request(
    engine: Engine,
    request_id: uuid.UUID,
    *,
    declined_by: uuid.UUID,
    reason: str,
    channel: str,
    assurance_level: str,
    now: datetime | None = None,
) -> Request:
    """Decline a pending request. A declined request never becomes a Transaction.

    A reason is required (PRD Feature 1) and is limited to 200 characters. Declining an
    already-declined request returns it unchanged.
    """
    if not reason.strip():
        raise RequestError("declining requires a reason (PRD Feature 1)")
    if len(reason) > 200:
        raise RequestError("decline reason is limited to 200 characters")

    moment = now or datetime.now(UTC)

    with engine.begin() as conn:
        request = _load_request(conn, request_id, for_update=True)
        if request.status is RequestStatus.DECLINED:
            return request
        if request.status is not RequestStatus.PENDING:
            raise RequestError(
                f"request {request_id} is {request.status.value} and cannot be declined"
            )

        conn.execute(
            text(
                """
                UPDATE request
                SET status = 'declined', resolved_by = :by, resolved_at = :at,
                    decline_reason = :reason
                WHERE id = :id
                """
            ),
            {"by": declined_by, "at": moment, "reason": reason.strip(), "id": request_id},
        )
        write_audit(
            conn,
            action="request.declined",
            entity_type="request",
            entity_id=request_id,
            actor_id=declined_by,
            assurance_level=assurance_level,
            channel=channel,
            before_state={"status": RequestStatus.PENDING.value},
            after_state={
                "status": RequestStatus.DECLINED.value,
                "decline_reason": reason.strip(),
            },
        )
        return _load_request(conn, request_id)


def expire_due_requests(engine: Engine, *, now: datetime | None = None) -> list[uuid.UUID]:
    """Expire every pending request past its window. Returns the ids expired.

    Safe to run concurrently: ``FOR UPDATE SKIP LOCKED`` means two workers split the
    work rather than fighting over it.
    """
    moment = now or datetime.now(UTC)
    expired: list[uuid.UUID] = []

    with engine.begin() as conn:
        due = (
            conn.execute(
                text(
                    """
                    SELECT id FROM request
                    WHERE status = 'pending' AND expires_at <= :now
                    FOR UPDATE SKIP LOCKED
                    """
                ),
                {"now": moment},
            )
            .scalars()
            .all()
        )
        for request_id in due:
            conn.execute(
                text(
                    """
                    UPDATE request SET status = 'expired', resolved_at = :at
                    WHERE id = :id AND status = 'pending'
                    """
                ),
                {"at": moment, "id": request_id},
            )
            write_audit(
                conn,
                action="request.expired",
                entity_type="request",
                entity_id=request_id,
                actor_kind=ActorKind.SYSTEM,
                before_state={"status": RequestStatus.PENDING.value},
                after_state={"status": RequestStatus.EXPIRED.value},
            )
            expired.append(request_id)

    return expired


def cancel_transaction(
    engine: Engine,
    transaction_id: uuid.UUID,
    *,
    actor_id: uuid.UUID,
    channel: str,
    now: datetime | None = None,
) -> Transaction:
    """Cancel a committed transfer inside its cancellation window (PRD Feature 7).

    Only intent moves here. The compensating ledger posting and the instruction to the
    provider are the settlement layer's business (P3.3) — this is the intent half of
    CLAUDE.md rule 4.
    """
    moment = now or datetime.now(UTC)

    with engine.begin() as conn:
        transaction = get_transaction(conn, transaction_id)
        if transaction.intent_state is IntentState.CANCELLED:
            return transaction
        # The window is the whole gate. It is opened at approval and closed by the
        # settlement layer the moment the provider has the money in motion
        # (`_advance` nulls it at in_flight and settled), so there is no second
        # state check here that could disagree with it.
        if transaction.cancellable_until is None or moment > transaction.cancellable_until:
            raise RequestError(
                f"the cancellation window for transaction {transaction_id} has closed"
            )

        conn.execute(
            text(
                """
                UPDATE transaction
                SET intent_state = 'cancelled', updated_at = now()
                WHERE id = :id
                """
            ),
            {"id": transaction_id},
        )
        write_audit(
            conn,
            action="transaction.cancelled",
            entity_type="transaction",
            entity_id=transaction_id,
            actor_id=actor_id,
            channel=channel,
            before_state={"intent_state": IntentState.COMMITTED.value},
            after_state={"intent_state": IntentState.CANCELLED.value},
        )
        return get_transaction(conn, transaction_id)
