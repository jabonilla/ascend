"""P5 — sender application surfaces.

  P5.1 auth and assurance levels
  P5.3 disclosures, receipts, cancellation

P5.2 (core screens) is not built: it is specified as "build against the design system",
and the design system was not supplied. See docs/COMPANION-DOCS.md.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest
from sqlalchemy import Engine, text

from iwp.app.auth import (
    AssuranceLevel,
    AuthoritySuspended,
    CodeExpired,
    CodeIncorrect,
    StepUpRequired,
    TooManyAttempts,
    authorize_approval,
    change_phone,
    issue_verification_code,
    required_assurance_for,
    restore_after_verification,
    session_for_token,
    start_session,
    verify_code,
)
from iwp.app.disclosures import (
    cancellation_window,
    disclosure_for,
    issue_receipt,
    receipt_for_transaction,
    record_disclosure,
    render_disclosure,
)
from iwp.domain.audit import audit_trail
from iwp.domain.plans import create_plan
from iwp.domain.requests import approve_request, submit_request
from iwp.domain.users import Channel, Role, activate_relationship, invite_recipient, upsert_user
from iwp.money import Money
from iwp.settings_store import set_setting
from iwp.settlement.adapters.mock import MockProvider
from iwp.settlement.lifecycle import instruct_settlement
from iwp.settlement.provider import CustodyModel, SettlementLatency

pytestmark = pytest.mark.db

NOW = datetime(2026, 8, 20, 12, 0, tzinfo=UTC)


def _clock() -> datetime:
    return NOW


@pytest.fixture()
def world(db: Engine) -> dict[str, uuid.UUID]:
    with db.begin() as conn:
        sender = upsert_user(
            conn,
            "+15555550000",
            role=Role.SENDER,
            display_name="Marco",
            preferred_channel=Channel.APP,
        )
    relationship, recipient, _ = invite_recipient(
        db, sender_id=sender.id, recipient_phone="55551234", recipient_display_name="Ana"
    )
    activate_relationship(db, relationship.id, accepted_by=recipient.id, channel="whatsapp")
    create_plan(db, relationship_id=relationship.id, created_by=sender.id)
    with db.begin() as conn:
        conn.execute(
            text(
                """
                INSERT INTO funding_source
                    (user_id, provider_reference, kind, status, is_default)
                VALUES (:u, 'FS-1', 'bank_account', 'active', TRUE)
                """
            ),
            {"u": sender.id},
        )
        conn.execute(
            text(
                """
                INSERT INTO payout_destination
                    (relationship_id, payout_method, account_reference, holder_name)
                VALUES (:r, 'cash_pickup', 'PICKUP-1', 'Ana Lopez')
                """
            ),
            {"r": relationship.id},
        )
    return {"sender": sender.id, "recipient": recipient.id, "relationship": relationship.id}


# ======================================================================================
# P5.1 — assurance levels and thresholds
# ======================================================================================


def test_assurance_levels_are_ordered() -> None:
    # A threshold comparison is only meaningful against a ranked scale.
    assert AssuranceLevel.NONE < AssuranceLevel.CHANNEL_VERIFIED
    assert AssuranceLevel.CHANNEL_VERIFIED < AssuranceLevel.DEVICE_VERIFIED
    assert AssuranceLevel.DEVICE_VERIFIED < AssuranceLevel.APP_VERIFIED
    assert AssuranceLevel.APP_VERIFIED >= AssuranceLevel.NONE


def test_a_small_approval_may_complete_in_channel(db: Engine) -> None:
    with db.connect() as conn:
        assert required_assurance_for(conn, Money(5000, "USD")) is AssuranceLevel.CHANNEL_VERIFIED


def test_step_up_triggers_above_the_first_threshold(db: Engine) -> None:
    with db.connect() as conn:
        assert required_assurance_for(conn, Money(50000, "USD")) is AssuranceLevel.DEVICE_VERIFIED


def test_the_app_is_required_above_the_second_threshold(db: Engine) -> None:
    with db.connect() as conn:
        assert required_assurance_for(conn, Money(500000, "USD")) is AssuranceLevel.APP_VERIFIED


def test_the_thresholds_change_without_a_deploy(db: Engine) -> None:
    # PRD Feature 5. The values are an open question (PRD §13), so they must be data.
    with db.begin() as conn:
        set_setting(conn, "approval.step_up_threshold_minor_units", 100)
    with db.connect() as conn:
        assert required_assurance_for(conn, Money(5000, "USD")) is AssuranceLevel.DEVICE_VERIFIED


def test_approving_below_the_required_level_raises(db: Engine, world: dict[str, uuid.UUID]) -> None:
    with db.connect() as conn, pytest.raises(StepUpRequired) as caught:
        authorize_approval(
            conn,
            user_id=world["sender"],
            amount=Money(500000, "USD"),
            presented=AssuranceLevel.CHANNEL_VERIFIED,
        )
    assert caught.value.required is AssuranceLevel.APP_VERIFIED
    assert caught.value.presented is AssuranceLevel.CHANNEL_VERIFIED


def test_authorize_returns_the_bar_that_was_cleared_not_just_a_boolean(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    with db.connect() as conn:
        required = authorize_approval(
            conn,
            user_id=world["sender"],
            amount=Money(5000, "USD"),
            presented=AssuranceLevel.APP_VERIFIED,
        )
    assert required is AssuranceLevel.CHANNEL_VERIFIED


# ======================================================================================
# P5.1 — sender-set limits
# ======================================================================================


def test_a_per_transaction_limit_blocks_an_approval_over_it(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    with db.begin() as conn:
        conn.execute(
            text("UPDATE relationship SET per_transaction_limit = 10000 WHERE id = :r"),
            {"r": world["relationship"]},
        )
    with db.connect() as conn, pytest.raises(StepUpRequired):
        authorize_approval(
            conn,
            user_id=world["sender"],
            amount=Money(20000, "USD"),
            presented=AssuranceLevel.APP_VERIFIED,
            relationship_id=world["relationship"],
        )


def test_a_per_day_limit_counts_what_has_already_been_committed_today(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    with db.begin() as conn:
        conn.execute(
            text("UPDATE relationship SET per_day_limit = 30000 WHERE id = :r"),
            {"r": world["relationship"]},
        )
    outcome = submit_request(
        db,
        relationship_id=world["relationship"],
        requested_by=world["recipient"],
        amount=Money(20000, "USD"),
        category_key="food",
        description="x",
        channel="app",
        now=NOW,
    )
    approve_request(
        db,
        outcome.request.id,
        approved_by=world["sender"],
        channel="app",
        assurance_level="app_verified",
        now=NOW,
    )
    with db.connect() as conn:
        # 200 already committed, 150 more would exceed the 300 daily cap.
        with pytest.raises(StepUpRequired):
            authorize_approval(
                conn,
                user_id=world["sender"],
                amount=Money(15000, "USD"),
                presented=AssuranceLevel.APP_VERIFIED,
                relationship_id=world["relationship"],
                now=NOW,
            )
        # But 50 more still fits.
        authorize_approval(
            conn,
            user_id=world["sender"],
            amount=Money(5000, "USD"),
            presented=AssuranceLevel.APP_VERIFIED,
            relationship_id=world["relationship"],
            now=NOW,
        )


def test_a_limit_in_another_currency_raises_rather_than_being_compared(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    with db.begin() as conn:
        conn.execute(
            text(
                """
                UPDATE relationship
                SET per_transaction_limit = 10000, limit_currency = 'GTQ'
                WHERE id = :r
                """
            ),
            {"r": world["relationship"]},
        )
    with db.connect() as conn, pytest.raises(ValueError, match="GTQ"):
        authorize_approval(
            conn,
            user_id=world["sender"],
            amount=Money(5000, "USD"),
            presented=AssuranceLevel.APP_VERIFIED,
            relationship_id=world["relationship"],
        )


# ======================================================================================
# P5.1 — phone verification
# ======================================================================================


def test_a_correct_code_verifies(db: Engine) -> None:
    _, code = issue_verification_code(db, "+15555550000", now=NOW)
    verify_code(db, "+15555550000", code, now=NOW)


def test_the_plaintext_code_is_never_stored(db: Engine) -> None:
    _, code = issue_verification_code(db, "+15555550000", now=NOW)
    with db.connect() as conn:
        stored = conn.execute(text("SELECT code_hash FROM verification_code")).scalar_one()
    assert code not in stored


def test_a_wrong_code_is_rejected_and_counted(db: Engine) -> None:
    issue_verification_code(db, "+15555550000", now=NOW)
    with pytest.raises(CodeIncorrect):
        verify_code(db, "+15555550000", "000000", now=NOW)
    with db.connect() as conn:
        assert conn.execute(text("SELECT attempts FROM verification_code")).scalar_one() == 1


def test_too_many_wrong_codes_locks_the_code_out(db: Engine) -> None:
    issue_verification_code(db, "+15555550000", now=NOW)
    for _ in range(5):
        with pytest.raises(CodeIncorrect):
            verify_code(db, "+15555550000", "000000", now=NOW)
    with pytest.raises(TooManyAttempts):
        verify_code(db, "+15555550000", "000000", now=NOW)


def test_an_expired_code_is_rejected(db: Engine) -> None:
    _, code = issue_verification_code(db, "+15555550000", now=NOW)
    with pytest.raises(CodeExpired):
        verify_code(db, "+15555550000", code, now=NOW + timedelta(hours=1))


def test_a_code_can_only_be_used_once(db: Engine) -> None:
    _, code = issue_verification_code(db, "+15555550000", now=NOW)
    verify_code(db, "+15555550000", code, now=NOW)
    with pytest.raises(CodeExpired, match="already been used"):
        verify_code(db, "+15555550000", code, now=NOW)


def test_verifying_with_no_code_issued_raises(db: Engine) -> None:
    with pytest.raises(CodeExpired, match="no verification code"):
        verify_code(db, "+15555550000", "123456", now=NOW)


# ======================================================================================
# P5.1 — sessions
# ======================================================================================


def test_a_session_authenticates_a_token(db: Engine, world: dict[str, uuid.UUID]) -> None:
    session, token = start_session(db, user_id=world["sender"], device_id="dev-1", now=NOW)
    found = session_for_token(db, token, now=NOW)
    assert found is not None
    assert found.id == session.id


def test_a_second_device_invalidates_the_prior_session(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    # PRD Feature 5. On a shared handset (PRD §2) this is the difference between the
    # account being yours and being whoever used the phone last.
    _, first_token = start_session(db, user_id=world["sender"], device_id="dev-1", now=NOW)
    _, second_token = start_session(db, user_id=world["sender"], device_id="dev-2", now=NOW)

    assert session_for_token(db, first_token, now=NOW) is None
    assert session_for_token(db, second_token, now=NOW) is not None
    with db.connect() as conn:
        reason = conn.execute(
            text("SELECT revoked_reason FROM device_session WHERE device_id = 'dev-1'")
        ).scalar_one()
    assert "superseded" in reason


def test_an_expired_session_does_not_authenticate(db: Engine, world: dict[str, uuid.UUID]) -> None:
    _, token = start_session(db, user_id=world["sender"], device_id="dev-1", now=NOW)
    assert session_for_token(db, token, now=NOW + timedelta(days=200)) is None


def test_an_unknown_token_authenticates_nothing(db: Engine) -> None:
    assert session_for_token(db, "not-a-token", now=NOW) is None


def test_starting_a_session_is_audited(db: Engine, world: dict[str, uuid.UUID]) -> None:
    start_session(db, user_id=world["sender"], device_id="dev-1", now=NOW)
    with db.connect() as conn:
        trail = audit_trail(conn, "app_user", world["sender"])
    assert trail[-1]["action"] == "session.started"
    assert trail[-1]["assurance_level"] == "device_verified"


# ======================================================================================
# P5.1 — number changes
# ======================================================================================


def test_a_number_change_strips_approval_authority_until_re_verified(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    start_session(db, user_id=world["sender"], device_id="dev-1", now=NOW)
    change_phone(db, world["sender"], "+15555559999", now=NOW)

    with db.connect() as conn, pytest.raises(AuthoritySuspended) as caught:
        # Even a small amount, and even presenting the app level: the authority is gone
        # until the new number is proved. AuthoritySuspended rather than StepUpRequired
        # because the remedy is a different flow, not a stronger proof.
        authorize_approval(
            conn,
            user_id=world["sender"],
            amount=Money(100, "USD"),
            presented=AssuranceLevel.APP_VERIFIED,
        )
    assert "phone number changed" in caught.value.reason


def test_a_number_change_revokes_every_session(db: Engine, world: dict[str, uuid.UUID]) -> None:
    _, token = start_session(db, user_id=world["sender"], device_id="dev-1", now=NOW)
    change_phone(db, world["sender"], "+15555559999", now=NOW)
    assert session_for_token(db, token, now=NOW) is None


def test_re_verification_restores_approval_authority(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    change_phone(db, world["sender"], "+15555559999", now=NOW)
    _, code = issue_verification_code(db, "+15555559999", purpose="phone_change", now=NOW)
    verify_code(db, "+15555559999", code, purpose="phone_change", now=NOW)
    restore_after_verification(db, world["sender"], device_id="dev-2", now=NOW)

    with db.connect() as conn:
        authorize_approval(
            conn,
            user_id=world["sender"],
            amount=Money(100, "USD"),
            presented=AssuranceLevel.DEVICE_VERIFIED,
        )


def test_a_number_change_is_audited_with_both_numbers(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    change_phone(db, world["sender"], "+15555559999", now=NOW)
    with db.connect() as conn:
        trail = [
            r
            for r in audit_trail(conn, "app_user", world["sender"])
            if r["action"] == "user.phone_changed"
        ]
    assert trail[0]["before_state"]["phone"] == "+15555550000"
    assert trail[0]["after_state"]["phone"] == "+15555559999"


def test_changing_the_number_of_an_unknown_user_raises(db: Engine) -> None:
    with pytest.raises(LookupError):
        change_phone(db, uuid.uuid4(), "+15555559999")


# ======================================================================================
# P5.3 — disclosures
# ======================================================================================


def _quote(db: Engine) -> tuple[MockProvider, object]:
    provider = MockProvider(custody_model=CustodyModel.A_FUND_AT_APPROVAL, clock=_clock)
    quote = provider.quote(amount=Money(10000, "USD"), to_currency="GTQ", idempotency_key="q1")
    return provider, quote


def test_the_disclosure_shows_every_figure_prd_feature_seven_requires(db: Engine) -> None:
    _, quote = _quote(db)
    disclosure = disclosure_for(quote, latency=SettlementLatency.MULTI_DAY)  # type: ignore[arg-type]

    assert disclosure.send_amount == Money(10000, "USD")
    assert disclosure.fee.is_positive
    assert disclosure.total_charged == disclosure.send_amount + disclosure.fee
    assert disclosure.fx_rate == Decimal("7.75")
    assert disclosure.recipient_amount == Money(77500, "GTQ")
    assert disclosure.estimated_availability


def test_the_rendered_disclosure_names_all_five_required_figures(db: Engine) -> None:
    _, quote = _quote(db)
    text_out = render_disclosure(
        disclosure_for(quote, latency=SettlementLatency.INSTANT)  # type: ignore[arg-type]
    )
    assert "USD 100.00" in text_out  # amount sent
    assert "USD 1.99" in text_out  # the fee
    assert "USD 101.99" in text_out  # total charged
    assert "7.75" in text_out  # the applied rate
    assert "GTQ 775.00" in text_out  # what the recipient gets
    assert "minutos" in text_out  # estimated availability


def test_availability_is_described_by_latency_and_never_promised(db: Engine) -> None:
    # PRD §6: urgent buys the sender's attention faster, never faster settlement.
    _, quote = _quote(db)
    for latency in SettlementLatency:
        text_out = render_disclosure(
            disclosure_for(quote, latency=latency)  # type: ignore[arg-type]
        )
        assert "Normalmente" in text_out, "hedged, not promised"


def test_the_disclosure_renders_in_english_too(db: Engine) -> None:
    _, quote = _quote(db)
    text_out = render_disclosure(
        disclosure_for(quote, latency=SettlementLatency.INSTANT, locale="en-US")  # type: ignore[arg-type]
    )
    assert "You send" in text_out
    assert "They receive" in text_out


def test_a_disclosure_is_recorded_with_the_channel_it_was_shown_on(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    # PRD Feature 7: shown on every channel where a transfer can be committed. The
    # obligation is to have shown it, so the showing is recorded.
    _, quote = _quote(db)
    outcome = submit_request(
        db,
        relationship_id=world["relationship"],
        requested_by=world["recipient"],
        amount=Money(10000, "USD"),
        category_key="food",
        description="x",
        channel="whatsapp",
        now=NOW,
    )
    disclosure = disclosure_for(quote, latency=SettlementLatency.MULTI_DAY)  # type: ignore[arg-type]
    for channel in ("app", "whatsapp", "sms"):
        record_disclosure(
            db,
            disclosure,
            request_id=outcome.request.id,
            user_id=world["sender"],
            channel=channel,
        )
    with db.connect() as conn:
        channels = (
            conn.execute(
                text("SELECT channel FROM disclosure_record WHERE request_id = :r"),
                {"r": outcome.request.id},
            )
            .scalars()
            .all()
        )
    assert set(channels) == {"app", "whatsapp", "sms"}


def test_a_disclosure_record_cannot_be_rewritten(db: Engine, world: dict[str, uuid.UUID]) -> None:
    from sqlalchemy.exc import DBAPIError

    _, quote = _quote(db)
    outcome = submit_request(
        db,
        relationship_id=world["relationship"],
        requested_by=world["recipient"],
        amount=Money(10000, "USD"),
        category_key="food",
        description="x",
        channel="app",
        now=NOW,
    )
    disclosure_id = record_disclosure(
        db,
        disclosure_for(quote, latency=SettlementLatency.INSTANT),  # type: ignore[arg-type]
        request_id=outcome.request.id,
        user_id=world["sender"],
        channel="app",
    )
    with pytest.raises(DBAPIError, match="append-only"), db.begin() as conn:
        conn.execute(
            text("UPDATE disclosure_record SET fee_amount = 0 WHERE id = :i"),
            {"i": disclosure_id},
        )


def test_an_expired_quote_makes_the_disclosure_expired(db: Engine) -> None:
    _, quote = _quote(db)
    disclosure = disclosure_for(quote, latency=SettlementLatency.INSTANT)  # type: ignore[arg-type]
    assert disclosure.is_expired(NOW) is False
    assert disclosure.is_expired(NOW + timedelta(hours=1)) is True


# ======================================================================================
# P5.3 — receipts
# ======================================================================================


def _instructed(db: Engine, world: dict[str, uuid.UUID]) -> uuid.UUID:
    provider, quote = _quote(db)
    outcome = submit_request(
        db,
        relationship_id=world["relationship"],
        requested_by=world["recipient"],
        amount=Money(10000, "USD"),
        category_key="food",
        description="x",
        channel="app",
        now=NOW,
    )
    approval = approve_request(
        db,
        outcome.request.id,
        approved_by=world["sender"],
        channel="app",
        assurance_level="app_verified",
        fee=Money(199, "USD"),
        now=NOW,
    )
    instruct_settlement(db, provider, approval.transaction.id, quote=quote, now=NOW)  # type: ignore[arg-type]
    return approval.transaction.id


def test_a_receipt_carries_a_reference_number_and_the_applied_rate(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    transaction_id = _instructed(db, world)
    receipt = issue_receipt(db, transaction_id)

    assert receipt.reference_number.startswith("REF-")
    assert receipt.send_amount == Money(10000, "USD")
    assert receipt.fee == Money(199, "USD")
    assert receipt.total_charged == Money(10199, "USD")
    assert receipt.fx_rate == Decimal("7.75")
    assert receipt.recipient_amount == Money(77500, "GTQ")
    assert receipt.reference_number in receipt.rendered_text


def test_a_receipt_is_issued_once_and_never_reissued_differently(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    transaction_id = _instructed(db, world)
    first = issue_receipt(db, transaction_id)
    second = issue_receipt(db, transaction_id)
    assert second == first
    with db.connect() as conn:
        assert conn.execute(text("SELECT count(*) FROM receipt")).scalar_one() == 1


def test_a_receipt_is_retrievable_afterwards(db: Engine, world: dict[str, uuid.UUID]) -> None:
    # PRD Feature 7: "Receipts are retrievable from history indefinitely."
    transaction_id = _instructed(db, world)
    issue_receipt(db, transaction_id)
    assert receipt_for_transaction(db, transaction_id) is not None


def test_no_receipt_exists_before_one_is_issued(db: Engine, world: dict[str, uuid.UUID]) -> None:
    transaction_id = _instructed(db, world)
    assert receipt_for_transaction(db, transaction_id) is None


def test_a_receipt_cannot_be_issued_before_a_rate_has_been_applied(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    # A receipt quoting a rate we have not applied would be a false statement.
    outcome = submit_request(
        db,
        relationship_id=world["relationship"],
        requested_by=world["recipient"],
        amount=Money(10000, "USD"),
        category_key="food",
        description="x",
        channel="app",
        now=NOW,
    )
    approval = approve_request(
        db,
        outcome.request.id,
        approved_by=world["sender"],
        channel="app",
        assurance_level="app_verified",
        now=NOW,
    )
    with pytest.raises(ValueError, match="no applied rate"):
        issue_receipt(db, approval.transaction.id)


def test_a_receipt_row_cannot_be_altered(db: Engine, world: dict[str, uuid.UUID]) -> None:
    from sqlalchemy.exc import DBAPIError

    transaction_id = _instructed(db, world)
    issue_receipt(db, transaction_id)
    with pytest.raises(DBAPIError, match="append-only"), db.begin() as conn:
        conn.execute(text("UPDATE receipt SET fee_amount = 0"))


def test_issuing_a_receipt_for_an_unknown_transaction_raises(db: Engine) -> None:
    with pytest.raises(LookupError):
        issue_receipt(db, uuid.uuid4())


# ======================================================================================
# P5.3 — cancellation window
# ======================================================================================


def test_the_cancellation_window_says_how_long_is_left(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    outcome = submit_request(
        db,
        relationship_id=world["relationship"],
        requested_by=world["recipient"],
        amount=Money(10000, "USD"),
        category_key="food",
        description="x",
        channel="app",
        now=NOW,
    )
    approval = approve_request(
        db,
        outcome.request.id,
        approved_by=world["sender"],
        channel="app",
        assurance_level="app_verified",
        now=NOW,
    )
    window = cancellation_window(db, approval.transaction.id, now=NOW + timedelta(minutes=10))
    assert window.is_open is True
    assert window.remaining == timedelta(minutes=20)
    assert "20 minutos" in window.describe()
    assert "20 more minutes" in window.describe("en-US")


def test_a_closed_window_says_so_plainly(db: Engine, world: dict[str, uuid.UUID]) -> None:
    outcome = submit_request(
        db,
        relationship_id=world["relationship"],
        requested_by=world["recipient"],
        amount=Money(10000, "USD"),
        category_key="food",
        description="x",
        channel="app",
        now=NOW,
    )
    approval = approve_request(
        db,
        outcome.request.id,
        approved_by=world["sender"],
        channel="app",
        assurance_level="app_verified",
        now=NOW,
    )
    window = cancellation_window(db, approval.transaction.id, now=NOW + timedelta(hours=2))
    assert window.is_open is False
    assert window.remaining == timedelta(0)
    assert "Ya no se puede cancelar" in window.describe()


def test_the_window_singular_is_grammatical(db: Engine, world: dict[str, uuid.UUID]) -> None:
    from iwp.app.disclosures import CancellationWindow

    window = CancellationWindow(closes_at=NOW + timedelta(seconds=90), now=NOW)
    assert "1 minuto" in window.describe()
    assert "1 more minute" in window.describe("en-US")
