"""P2.4 — request and approval state machine.

Invariants under test:
  * legal transitions only: pending -> approved | declined | expired
  * a declined request never creates a Transaction
  * every transition writes an audit row with actor, channel, and assurance level
  * transitions are idempotent
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

import pytest
from hypothesis import HealthCheck, given
from hypothesis import settings as hyp_settings
from hypothesis import strategies as st
from sqlalchemy import Engine, text

from iwp.domain.audit import audit_trail
from iwp.domain.plans import Cadence, CategorySpec, create_plan, create_recurring_rule, revise_plan
from iwp.domain.requests import (
    RequestError,
    SubmissionOutcome,
    approve_request,
    cancel_transaction,
    decline_request,
    expire_due_requests,
    get_request,
    list_requests,
    submit_request,
)
from iwp.domain.tiers import TierReason, TrustTier
from iwp.domain.users import Channel, Role, activate_relationship, invite_recipient, upsert_user
from iwp.money import Money
from iwp.settings_store import set_setting
from iwp.states import IntentState, RequestStatus, SettlementState

pytestmark = pytest.mark.db

NOW = datetime(2026, 8, 20, 12, 0, tzinfo=UTC)


@pytest.fixture()
def world(db: Engine) -> dict[str, uuid.UUID]:
    """An active pair with a plan and an active monthly food rule of $250."""
    with db.begin() as conn:
        sender = upsert_user(
            conn,
            "+15555550000",
            role=Role.SENDER,
            display_name="Marco",
            preferred_channel=Channel.APP,
        )
    rel, recipient, _ = invite_recipient(
        db, sender_id=sender.id, recipient_phone="55551234", recipient_display_name="Ana"
    )
    activate_relationship(db, rel.id, accepted_by=recipient.id, channel="whatsapp")
    version = create_plan(db, relationship_id=rel.id, created_by=sender.id)
    create_recurring_rule(
        db,
        plan_id=version.plan_id,
        category_key="food",
        amount=Money(25000, "USD"),
        cadence=Cadence.MONTHLY,
        actor_id=sender.id,
    )
    return {
        "sender": sender.id,
        "recipient": recipient.id,
        "relationship": rel.id,
        "plan": version.plan_id,
    }


def _submit(
    db: Engine,
    world: dict[str, uuid.UUID],
    *,
    amount: int = 20000,
    category: str | None = "food",
    emergency: bool = False,
    channel: str = "whatsapp",
    key: str | None = None,
    now: datetime = NOW,
) -> SubmissionOutcome:
    return submit_request(
        db,
        relationship_id=world["relationship"],
        requested_by=world["recipient"],
        amount=Money(amount, "USD"),
        category_key=category,
        description="Compras del mes",
        channel=channel,
        is_emergency=emergency,
        idempotency_key=key,
        now=now,
    )


# --------------------------------------------------------------------------------------
# submission
# --------------------------------------------------------------------------------------


def test_a_request_within_the_rule_is_classified_recurring(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    outcome = _submit(db, world, amount=20000)
    assert outcome.request.tier is TrustTier.RECURRING
    assert outcome.request.tier_reason is TierReason.WITHIN_ACTIVE_RULE
    assert outcome.request.status is RequestStatus.PENDING


def test_a_request_over_the_rule_is_flagged_for_approval_not_rejected(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    outcome = _submit(db, world, amount=90000)
    assert outcome.request.tier is TrustTier.UNRECOGNIZED
    assert outcome.request.tier_reason is TierReason.OVER_RULE_AMOUNT
    assert outcome.decision.requires_approval is True


def test_a_request_records_the_category_of_the_version_in_force(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    from iwp.domain.plans import plan_version_for_category

    outcome = _submit(db, world)
    assert outcome.request.category_id is not None
    revise_plan(
        db,
        plan_id=world["plan"],
        created_by=world["sender"],
        categories=(CategorySpec(key="food", name="Comida", monthly_cap=Money(1, "USD")),),
        change_note="tightened",
    )
    with db.connect() as conn:
        version = plan_version_for_category(conn, outcome.request.category_id)
    assert version.version_number == 1, "the old request still resolves against version 1"


def test_a_redelivered_channel_message_produces_one_request(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    first = _submit(db, world, key="wamid.ABC123")
    second = _submit(db, world, key="wamid.ABC123")
    assert second.is_duplicate is True
    assert second.request.id == first.request.id
    with db.connect() as conn:
        assert conn.execute(text("SELECT count(*) FROM request")).scalar_one() == 1


def test_a_request_on_a_paused_relationship_is_refused(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    from iwp.domain.users import pause_relationship

    pause_relationship(db, world["relationship"], actor_id=world["sender"])
    with pytest.raises(RequestError, match="paused"):
        _submit(db, world)


def test_a_request_on_a_terminated_relationship_is_refused(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    # PRD §10: history is retained, but no new requests are permitted.
    from iwp.domain.users import terminate_relationship

    terminate_relationship(db, world["relationship"], actor_id=world["sender"])
    with pytest.raises(RequestError, match="terminated"):
        _submit(db, world)


def test_a_description_over_two_hundred_characters_is_refused(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    with pytest.raises(RequestError, match="200 characters"):
        submit_request(
            db,
            relationship_id=world["relationship"],
            requested_by=world["recipient"],
            amount=Money(1000, "USD"),
            category_key="food",
            description="x" * 201,
            channel="sms",
        )


def test_emergency_requests_expire_sooner_than_ordinary_ones(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    ordinary = _submit(db, world).request
    urgent = _submit(db, world, emergency=True).request
    assert ordinary.expires_at == NOW + timedelta(hours=72)
    assert urgent.expires_at == NOW + timedelta(hours=24)


def test_the_emergency_rate_limit_warns_and_never_blocks(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    # PRD Feature 3: max 3 per 7 days, "then a soft warning to both parties".
    outcomes = [_submit(db, world, emergency=True) for _ in range(4)]
    assert [o.emergency_rate_limit_hit for o in outcomes] == [False, False, False, True]
    assert all(o.request.tier is TrustTier.EMERGENCY for o in outcomes)
    with db.connect() as conn:
        assert conn.execute(text("SELECT count(*) FROM request")).scalar_one() == 4


def test_the_month_to_date_cap_counts_committed_transactions(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    revise_plan(
        db,
        plan_id=world["plan"],
        created_by=world["sender"],
        categories=(CategorySpec(key="food", name="Comida", monthly_cap=Money(30000, "USD")),),
        change_note="cap food at 300",
    )
    first = _submit(db, world, amount=20000)
    approve_request(
        db,
        first.request.id,
        approved_by=world["sender"],
        channel="app",
        assurance_level="app_verified",
        now=NOW,
    )
    second = _submit(db, world, amount=20000)
    assert second.request.tier_reason is TierReason.OVER_MONTHLY_CAP


# --------------------------------------------------------------------------------------
# approval
# --------------------------------------------------------------------------------------


def test_approving_a_pending_request_creates_a_committed_transaction(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    request = _submit(db, world).request
    outcome = approve_request(
        db,
        request.id,
        approved_by=world["sender"],
        channel="whatsapp",
        assurance_level="channel_verified",
        fee=Money(200, "USD"),
        now=NOW,
    )
    assert outcome.already_resolved is False
    assert outcome.request.status is RequestStatus.APPROVED
    assert outcome.transaction.intent_state is IntentState.COMMITTED
    assert outcome.transaction.settlement_state is SettlementState.NOT_STARTED
    assert outcome.transaction.amount == Money(20000, "USD")
    assert outcome.transaction.fee == Money(200, "USD")
    assert outcome.transaction.reference_number.startswith("REF-")


def test_intent_and_settlement_are_separate_columns(db: Engine) -> None:
    # CLAUDE.md rule 4, checked against the schema rather than against a value.
    with db.connect() as conn:
        columns = set(
            conn.execute(
                text(
                    """
                    SELECT column_name FROM information_schema.columns
                    WHERE table_name = 'transaction'
                    """
                )
            )
            .scalars()
            .all()
        )
    assert {"intent_state", "settlement_state"} <= columns
    assert "status" not in columns


def test_approving_an_already_approved_request_is_a_no_op(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    request = _submit(db, world).request
    first = approve_request(
        db, request.id, approved_by=world["sender"], channel="app", assurance_level="app", now=NOW
    )
    second = approve_request(
        db, request.id, approved_by=world["sender"], channel="app", assurance_level="app", now=NOW
    )
    assert second.already_resolved is True
    assert second.transaction.id == first.transaction.id
    assert second.transaction.reference_number == first.transaction.reference_number
    with db.connect() as conn:
        assert conn.execute(text("SELECT count(*) FROM transaction")).scalar_one() == 1


def test_a_fee_in_the_wrong_currency_is_refused(db: Engine, world: dict[str, uuid.UUID]) -> None:
    request = _submit(db, world).request
    with pytest.raises(RequestError, match="fee currency"):
        approve_request(
            db,
            request.id,
            approved_by=world["sender"],
            channel="app",
            assurance_level="app",
            fee=Money(200, "GTQ"),
        )


def test_reference_numbers_are_unique_across_transactions(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    references = set()
    for i in range(12):
        request = _submit(db, world, key=f"m{i}").request
        outcome = approve_request(
            db,
            request.id,
            approved_by=world["sender"],
            channel="app",
            assurance_level="app",
            now=NOW,
        )
        references.add(outcome.transaction.reference_number)
    assert len(references) == 12


# --------------------------------------------------------------------------------------
# decline
# --------------------------------------------------------------------------------------


def test_declining_requires_a_reason_and_creates_no_transaction(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    request = _submit(db, world).request
    declined = decline_request(
        db,
        request.id,
        declined_by=world["sender"],
        reason="Este mes ya enviamos lo del alquiler",
        channel="whatsapp",
        assurance_level="channel_verified",
        now=NOW,
    )
    assert declined.status is RequestStatus.DECLINED
    assert declined.decline_reason == "Este mes ya enviamos lo del alquiler"
    with db.connect() as conn:
        assert conn.execute(text("SELECT count(*) FROM transaction")).scalar_one() == 0


def test_declining_without_a_reason_is_refused(db: Engine, world: dict[str, uuid.UUID]) -> None:
    request = _submit(db, world).request
    with pytest.raises(RequestError, match="reason"):
        decline_request(
            db,
            request.id,
            declined_by=world["sender"],
            reason="   ",
            channel="app",
            assurance_level="app",
        )


def test_a_declined_request_can_never_become_a_transaction(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    request = _submit(db, world).request
    decline_request(
        db,
        request.id,
        declined_by=world["sender"],
        reason="no",
        channel="app",
        assurance_level="app",
    )
    with pytest.raises(RequestError, match="declined and cannot be approved"):
        approve_request(
            db, request.id, approved_by=world["sender"], channel="app", assurance_level="app"
        )
    with db.connect() as conn:
        assert conn.execute(text("SELECT count(*) FROM transaction")).scalar_one() == 0


def test_declining_twice_is_idempotent(db: Engine, world: dict[str, uuid.UUID]) -> None:
    request = _submit(db, world).request
    first = decline_request(
        db,
        request.id,
        declined_by=world["sender"],
        reason="no",
        channel="app",
        assurance_level="app",
    )
    second = decline_request(
        db,
        request.id,
        declined_by=world["sender"],
        reason="different reason",
        channel="app",
        assurance_level="app",
    )
    assert second.resolved_at == first.resolved_at
    assert second.decline_reason == "no", "the first reason stands"


def test_an_approved_request_cannot_be_declined(db: Engine, world: dict[str, uuid.UUID]) -> None:
    request = _submit(db, world).request
    approve_request(
        db, request.id, approved_by=world["sender"], channel="app", assurance_level="app"
    )
    with pytest.raises(RequestError, match="approved and cannot be declined"):
        decline_request(
            db,
            request.id,
            declined_by=world["sender"],
            reason="changed my mind",
            channel="app",
            assurance_level="app",
        )


# --------------------------------------------------------------------------------------
# expiry
# --------------------------------------------------------------------------------------


def test_requests_expire_after_the_configured_window(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    request = _submit(db, world).request
    assert expire_due_requests(db, now=NOW + timedelta(hours=71)) == []
    assert expire_due_requests(db, now=NOW + timedelta(hours=73)) == [request.id]
    with db.connect() as conn:
        assert get_request(conn, request.id).status is RequestStatus.EXPIRED


def test_the_expiry_window_changes_without_a_deploy(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    with db.begin() as conn:
        set_setting(conn, "request.expiry_hours", 1, changed_by=world["sender"])
    request = _submit(db, world).request
    assert request.expires_at == NOW + timedelta(hours=1)


def test_an_expired_request_cannot_be_approved(db: Engine, world: dict[str, uuid.UUID]) -> None:
    request = _submit(db, world).request
    expire_due_requests(db, now=NOW + timedelta(hours=73))
    with pytest.raises(RequestError, match="expired and cannot be approved"):
        approve_request(
            db, request.id, approved_by=world["sender"], channel="app", assurance_level="app"
        )


def test_expiry_only_touches_pending_requests(db: Engine, world: dict[str, uuid.UUID]) -> None:
    approved = _submit(db, world, key="a").request
    approve_request(
        db, approved.id, approved_by=world["sender"], channel="app", assurance_level="app"
    )
    pending = _submit(db, world, key="b").request
    assert expire_due_requests(db, now=NOW + timedelta(hours=73)) == [pending.id]


# --------------------------------------------------------------------------------------
# audit
# --------------------------------------------------------------------------------------


def test_every_transition_produces_exactly_one_audit_row(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    request = _submit(db, world).request
    approve_request(
        db,
        request.id,
        approved_by=world["sender"],
        channel="whatsapp",
        assurance_level="channel_verified",
        now=NOW,
    )
    # Replay: must not add a second audit row.
    approve_request(
        db,
        request.id,
        approved_by=world["sender"],
        channel="whatsapp",
        assurance_level="channel_verified",
        now=NOW,
    )

    with db.connect() as conn:
        trail = audit_trail(conn, "request", request.id)
    assert [row["action"] for row in trail] == ["request.submitted", "request.approved"]
    approval = trail[1]
    assert approval["actor_id"] == world["sender"]
    assert approval["channel"] == "whatsapp"
    assert approval["assurance_level"] == "channel_verified"


def test_an_expiry_is_recorded_as_a_system_action(db: Engine, world: dict[str, uuid.UUID]) -> None:
    request = _submit(db, world).request
    expire_due_requests(db, now=NOW + timedelta(hours=73))
    with db.connect() as conn:
        trail = audit_trail(conn, "request", request.id)
    expiry = trail[-1]
    assert expiry["action"] == "request.expired"
    assert expiry["actor_kind"] == "system"
    assert expiry["actor_id"] is None


# --------------------------------------------------------------------------------------
# cancellation (PRD Feature 7 — intent half)
# --------------------------------------------------------------------------------------


def test_a_transfer_can_be_cancelled_inside_its_window(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    request = _submit(db, world).request
    outcome = approve_request(
        db,
        request.id,
        approved_by=world["sender"],
        channel="app",
        assurance_level="app",
        now=NOW,
    )
    assert outcome.transaction.cancellable_until == NOW + timedelta(minutes=30)
    cancelled = cancel_transaction(
        db,
        outcome.transaction.id,
        actor_id=world["sender"],
        channel="app",
        now=NOW + timedelta(minutes=10),
    )
    assert cancelled.intent_state is IntentState.CANCELLED
    assert cancelled.settlement_state is SettlementState.NOT_STARTED, (
        "cancelling moves intent only; settlement is the provider's business"
    )


def test_cancelling_after_the_window_is_refused(db: Engine, world: dict[str, uuid.UUID]) -> None:
    request = _submit(db, world).request
    outcome = approve_request(
        db, request.id, approved_by=world["sender"], channel="app", assurance_level="app", now=NOW
    )
    with pytest.raises(RequestError, match=r"window .* has closed"):
        cancel_transaction(
            db,
            outcome.transaction.id,
            actor_id=world["sender"],
            channel="app",
            now=NOW + timedelta(hours=2),
        )


def test_cancelling_twice_is_idempotent(db: Engine, world: dict[str, uuid.UUID]) -> None:
    request = _submit(db, world).request
    outcome = approve_request(
        db, request.id, approved_by=world["sender"], channel="app", assurance_level="app", now=NOW
    )
    first = cancel_transaction(
        db, outcome.transaction.id, actor_id=world["sender"], channel="app", now=NOW
    )
    second = cancel_transaction(
        db, outcome.transaction.id, actor_id=world["sender"], channel="app", now=NOW
    )
    assert second == first
    with db.connect() as conn:
        cancels = [
            r
            for r in audit_trail(conn, "transaction", outcome.transaction.id)
            if r["action"] == "transaction.cancelled"
        ]
    assert len(cancels) == 1


# --------------------------------------------------------------------------------------
# property test — required by P2.4
# --------------------------------------------------------------------------------------

_ACTIONS = ["approve", "decline", "expire"]


@hyp_settings(
    max_examples=25,
    deadline=None,
    suppress_health_check=[HealthCheck.function_scoped_fixture],
)
@given(sequence=st.lists(st.sampled_from(_ACTIONS), min_size=1, max_size=8))
@pytest.mark.slow
def test_property_no_illegal_request_state_is_ever_reachable(
    db: Engine, world: dict[str, uuid.UUID], sequence: list[str]
) -> None:
    """Apply random transition sequences; assert the invariants hold throughout.

    The first action decides the outcome. Everything after it either replays that
    outcome or is refused — never a second resolution, and never a Transaction for a
    request that was not approved.
    """
    request = _submit(db, world, key=uuid.uuid4().hex).request
    resolved_as: RequestStatus | None = None

    for action in sequence:
        try:
            if action == "approve":
                approve_request(
                    db,
                    request.id,
                    approved_by=world["sender"],
                    channel="app",
                    assurance_level="app",
                    now=NOW,
                )
                resolved_as = resolved_as or RequestStatus.APPROVED
            elif action == "decline":
                decline_request(
                    db,
                    request.id,
                    declined_by=world["sender"],
                    reason="no",
                    channel="app",
                    assurance_level="app",
                    now=NOW,
                )
                resolved_as = resolved_as or RequestStatus.DECLINED
            else:
                expire_due_requests(db, now=NOW + timedelta(days=30))
                resolved_as = resolved_as or RequestStatus.EXPIRED
        except RequestError:
            # Refusing an illegal transition is correct behaviour, not a failure.
            pass

        with db.connect() as conn:
            current = get_request(conn, request.id)
            transaction_count = conn.execute(
                text("SELECT count(*) FROM transaction WHERE request_id = :r"),
                {"r": request.id},
            ).scalar_one()

        assert current.status in set(RequestStatus)
        if resolved_as is not None:
            assert current.status is resolved_as, "a resolved request never changes outcome"
        if current.status is not RequestStatus.APPROVED:
            assert transaction_count == 0, "only an approval creates a Transaction"
        else:
            assert transaction_count == 1, "an approval creates exactly one Transaction"

        # A resolved request always records when, and a pending one never does.
        assert (current.resolved_at is None) == (current.status is RequestStatus.PENDING)


def test_listing_requests_is_newest_first(db: Engine, world: dict[str, uuid.UUID]) -> None:
    # PRD Feature 8: reverse-chronological by default.
    older = _submit(db, world, key="a").request
    newer = _submit(db, world, key="b").request
    with db.connect() as conn:
        listed = list_requests(conn, world["relationship"])
    assert [r.id for r in listed] == [newer.id, older.id]


def test_listing_requests_can_be_filtered_by_status(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    pending = _submit(db, world, key="a").request
    resolved = _submit(db, world, key="b").request
    decline_request(
        db,
        resolved.id,
        declined_by=world["sender"],
        reason="no",
        channel="app",
        assurance_level="app",
    )
    with db.connect() as conn:
        found = list_requests(
            conn, world["relationship"], statuses=frozenset({RequestStatus.PENDING})
        )
    assert [r.id for r in found] == [pending.id]
