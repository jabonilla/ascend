"""P4 — channel gateway.

  P4.1 adapter interface and the outbound audit
  P4.2 the WhatsApp 24-hour session window
  P4.3 conversational state machines
  P4.4 fallback and delivery

The recipient never installs an app (PRD §2), so everything here is the product, not a
notification layer around it.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

import pytest
from hypothesis import HealthCheck, given
from hypothesis import settings as hyp_settings
from hypothesis import strategies as st
from sqlalchemy import Engine, text

from iwp.channels.adapter import Channel, DeliveryState, InboundMessage
from iwp.channels.adapters.mock_bsp import MockChannelAdapter, SendBehaviour
from iwp.channels.conversations import (
    PRESET_DECLINE_REASON,
    ConversationState,
    InboundOutcome,
    handle_inbound,
)
from iwp.channels.copy import APPROVAL_BUTTONS, SMS_KEYWORDS, TEMPLATES, render
from iwp.channels.gateway import ChannelGateway, Dispatch, delivery_audit
from iwp.channels.parsing import Intent, interpret, parse_amount, parse_choice
from iwp.channels.session import (
    Deliverability,
    SessionWindowClosed,
    classify_delivery,
    note_inbound,
    window_for,
)
from iwp.domain.phone import parse_phone
from iwp.domain.plans import Cadence, create_plan, create_recurring_rule
from iwp.domain.requests import list_requests
from iwp.domain.users import Channel as UserChannel
from iwp.domain.users import Role, invite_recipient, upsert_user
from iwp.money import Money
from iwp.states import RelationshipStatus, RequestStatus
from iwp.voice import banned_words_in, fold, is_within_line_budget

NOW = datetime(2026, 8, 20, 12, 0, tzinfo=UTC)


def _clock() -> datetime:
    return NOW


# ======================================================================================
# copy and voice — no database needed
# ======================================================================================


def test_approval_buttons_are_exactly_the_two_prd_labels_in_order() -> None:
    assert APPROVAL_BUTTONS == ("Aprobar", "Ahorita no")
    _, buttons = render(
        "request.needs_approval_sender",
        "es-GT",
        recipient_name="Ana",
        recipient_name_upper="ANA",
        amount="100.00",
        category="Comida",
        note="",
        description="x",
    )
    assert buttons == APPROVAL_BUTTONS


def test_every_whatsapp_template_fits_the_three_line_budget() -> None:
    # PRD Feature 4. The floor is a shared mid-tier Android on 2G (PRD §2).
    offenders = [
        f"{t.key}/{t.locale}" for t in TEMPLATES.values() if not is_within_line_budget(t.body)
    ]
    assert offenders == [], f"templates over 3 lines: {offenders}"


def test_no_template_contains_a_banned_word() -> None:
    offenders = {
        f"{t.key}/{t.locale}": banned_words_in(t.body)
        for t in TEMPLATES.values()
        if banned_words_in(t.body)
    }
    assert offenders == {}


def test_messages_to_a_recipient_open_with_the_senders_name() -> None:
    # PRD Feature 0 and Feature 4: never the product name. A message from an unknown
    # company asking about money reads as a scam; one from Marco does not.
    body, _ = render("pairing.invitation", "es-GT", sender_name="Marco")
    assert body.startswith("Marco")


def test_every_template_exists_in_spanish_and_english() -> None:
    keys = {t.key for t in TEMPLATES.values()}
    for key in keys:
        assert (key, "es-GT") in TEMPLATES, f"{key} has no Guatemalan Spanish"
        assert (key, "en-US") in TEMPLATES, f"{key} has no English"


def test_an_unknown_locale_falls_back_to_spanish_not_english() -> None:
    body, _ = render("pairing.invitation", "fr-FR", sender_name="Marco")
    assert "de forma segura" in body


def test_a_template_missing_a_variable_says_which_one() -> None:
    with pytest.raises(KeyError, match="sender_name"):
        render("pairing.invitation", "es-GT")


def test_accent_folding_makes_si_and_si_the_same_word() -> None:
    assert fold("SÍ") == fold("si") == "si"


def test_a_banned_word_cannot_hide_inside_a_longer_word() -> None:
    # "aml" inside "familia" must not trip the check, or half the Spanish copy fails.
    assert banned_words_in("Para la familia") == []
    assert banned_words_in("This is an AML review") == ["aml"]


def test_a_banned_word_cannot_be_smuggled_past_by_dropping_an_accent() -> None:
    assert banned_words_in("regulación") == ["regulacion"]


# ======================================================================================
# parsing
# ======================================================================================


@pytest.mark.parametrize(
    ("text_in", "expected"),
    [
        ("SI", Intent.YES),
        ("sí", Intent.YES),
        ("Si ", Intent.YES),
        ("NO", Intent.NO),
        ("no", Intent.NO),
        ("URGENTE", Intent.URGENT),
        ("urgente 500", Intent.URGENT),
        ("AYUDA", Intent.HELP),
        ("ayuda", Intent.HELP),
        ("RESUMEN", Intent.SUMMARY),
        ("resumen", Intent.SUMMARY),
        ("500", Intent.AMOUNT),
        ("2", Intent.CHOICE),
        ("qué tal", Intent.UNKNOWN),
        ("", Intent.UNKNOWN),
    ],
)
def test_keywords_are_case_insensitive_per_prd_feature_four(text_in: str, expected: Intent) -> None:
    assert interpret(text_in)[0] is expected


def test_every_documented_sms_keyword_is_understood() -> None:
    for keyword in SMS_KEYWORDS:
        assert interpret(keyword)[0] is not Intent.UNKNOWN, keyword
        assert interpret(keyword.lower())[0] is not Intent.UNKNOWN, keyword


def test_a_tapped_button_wins_over_the_typed_body() -> None:
    assert interpret("hola", button_payload="Aprobar")[0] is Intent.YES


@pytest.mark.parametrize(
    ("raw", "minor_units"),
    [
        ("500", 50000),
        ("Q500", 50000),
        ("$500.50", 50050),
        ("500,50", 50050),
        ("1.500", 150000),
        ("1,500.00", 150000),
        ("1.500,00", 150000),
    ],
)
def test_amounts_parse_under_both_separator_conventions(raw: str, minor_units: int) -> None:
    # Both 1.500,00 and 1,500.00 appear in this corridor. Reading Q1.500 as one fifty
    # would be a hundredfold error in the direction that hurts.
    amount = parse_amount(raw, "USD")
    assert amount is not None
    assert amount.minor_units == minor_units


@pytest.mark.parametrize("raw", ["abc", "0", "-5", "", "1.2345", "hola 500 hola"])
def test_non_amounts_return_none_rather_than_raising(raw: str) -> None:
    assert parse_amount(raw, "USD") is None


def test_a_choice_outside_the_menu_is_not_a_choice() -> None:
    assert parse_choice("3", options=5) == 3
    assert parse_choice("9", options=5) is None
    assert parse_choice("x", options=5) is None


# ======================================================================================
# P4.2 — session window
# ======================================================================================

pytestmark_db = pytest.mark.db


@dataclass(frozen=True)
class Pair:
    sender: uuid.UUID
    recipient: uuid.UUID
    relationship: uuid.UUID
    sender_phone: str
    recipient_phone: str


@pytest.fixture()
def pair(db: Engine) -> Pair:
    with db.begin() as conn:
        sender = upsert_user(
            conn,
            "+15555550000",
            role=Role.SENDER,
            display_name="Marco",
            preferred_channel=UserChannel.WHATSAPP,
        )
    relationship, recipient, _ = invite_recipient(
        db, sender_id=sender.id, recipient_phone="55551234", recipient_display_name="Ana"
    )
    return Pair(
        sender=sender.id,
        recipient=recipient.id,
        relationship=relationship.id,
        sender_phone="+15555550000",
        recipient_phone="+50255551234",
    )


@pytest.mark.db
def test_an_inbound_message_opens_a_twenty_four_hour_window(db: Engine, pair: Pair) -> None:
    with db.begin() as conn:
        window = note_inbound(conn, pair.recipient, Channel.WHATSAPP, now=NOW)
    assert window.expires_at == NOW + timedelta(hours=24)
    assert window.is_open(NOW + timedelta(hours=23)) is True
    assert window.is_open(NOW + timedelta(hours=25)) is False


@pytest.mark.db
def test_a_later_inbound_refreshes_the_window(db: Engine, pair: Pair) -> None:
    with db.begin() as conn:
        note_inbound(conn, pair.recipient, Channel.WHATSAPP, now=NOW)
        window = note_inbound(conn, pair.recipient, Channel.WHATSAPP, now=NOW + timedelta(hours=5))
    assert window.expires_at == NOW + timedelta(hours=29)


@pytest.mark.db
def test_an_out_of_order_older_inbound_never_shortens_the_window(db: Engine, pair: Pair) -> None:
    # Redelivery of an old message must not close a window a newer one opened.
    with db.begin() as conn:
        note_inbound(conn, pair.recipient, Channel.WHATSAPP, now=NOW + timedelta(hours=5))
        window = note_inbound(conn, pair.recipient, Channel.WHATSAPP, now=NOW)
    assert window.expires_at == NOW + timedelta(hours=29)


@pytest.mark.db
def test_with_no_record_the_window_is_closed(db: Engine, pair: Pair) -> None:
    # The safe default: no record means no window, so only templates go out.
    with db.connect() as conn:
        window = window_for(conn, pair.recipient, Channel.WHATSAPP)
        assert window.is_open(NOW) is False
        assert (
            classify_delivery(conn, pair.recipient, Channel.WHATSAPP, now=NOW)
            is Deliverability.TEMPLATE_REQUIRED
        )


@pytest.mark.db
def test_sms_has_no_window_concept_at_all(db: Engine, pair: Pair) -> None:
    with db.connect() as conn:
        assert (
            classify_delivery(conn, pair.recipient, Channel.SMS, now=NOW)
            is Deliverability.NO_WINDOW_CONCEPT
        )


@pytest.mark.db
def test_every_notification_is_classified_before_it_is_composed(db: Engine, pair: Pair) -> None:
    with db.begin() as conn:
        note_inbound(conn, pair.recipient, Channel.WHATSAPP, now=NOW)
    with db.connect() as conn:
        assert (
            classify_delivery(conn, pair.recipient, Channel.WHATSAPP, now=NOW)
            is Deliverability.SESSION_ELIGIBLE
        )
        assert (
            classify_delivery(conn, pair.recipient, Channel.WHATSAPP, now=NOW + timedelta(hours=25))
            is Deliverability.TEMPLATE_REQUIRED
        )


@pytest.mark.db
def test_a_freeform_message_outside_the_window_raises(db: Engine, pair: Pair) -> None:
    gateway = ChannelGateway(
        db, {Channel.WHATSAPP: MockChannelAdapter(Channel.WHATSAPP, clock=_clock)}, clock=_clock
    )
    with pytest.raises(SessionWindowClosed):
        gateway.send_freeform(
            user_id=pair.recipient,
            to=parse_phone(pair.recipient_phone),
            channel=Channel.WHATSAPP,
            body="hola",
            idempotency_key="k1",
        )


@pytest.mark.db
def test_a_freeform_message_inside_the_window_is_sent(db: Engine, pair: Pair) -> None:
    adapter = MockChannelAdapter(Channel.WHATSAPP, clock=_clock)
    gateway = ChannelGateway(db, {Channel.WHATSAPP: adapter}, clock=_clock)
    with db.begin() as conn:
        note_inbound(conn, pair.recipient, Channel.WHATSAPP, now=NOW)
    notification_id = gateway.send_freeform(
        user_id=pair.recipient,
        to=parse_phone(pair.recipient_phone),
        channel=Channel.WHATSAPP,
        body="hola",
        idempotency_key="k1",
    )
    assert adapter.last_sent().body == "hola"
    with db.connect() as conn:
        assert [e["delivery_state"] for e in delivery_audit(conn, notification_id)] == [
            "queued",
            "sent",
        ]


# ======================================================================================
# P4.1 / P4.4 — outbound audit, fallback, parallel dispatch
# ======================================================================================


def _gateway(
    db: Engine,
    *,
    whatsapp: SendBehaviour = SendBehaviour.ACCEPT,
    sms: SendBehaviour = SendBehaviour.ACCEPT,
) -> tuple[ChannelGateway, MockChannelAdapter, MockChannelAdapter]:
    wa = MockChannelAdapter(Channel.WHATSAPP, behaviour=whatsapp, clock=_clock)
    sm = MockChannelAdapter(Channel.SMS, behaviour=sms, clock=_clock)
    return (
        ChannelGateway(db, {Channel.WHATSAPP: wa, Channel.SMS: sm}, clock=_clock),
        wa,
        sm,
    )


def _dispatch(pair: Pair) -> Dispatch:
    return Dispatch(
        user_id=pair.recipient,
        to=parse_phone(pair.recipient_phone),
        template_key="pairing.invitation",
        locale="es-GT",
        variables={"sender_name": "Marco"},
    )


@pytest.mark.db
def test_every_outbound_message_logs_channel_template_and_delivery_state(
    db: Engine, pair: Pair
) -> None:
    gateway, _, _ = _gateway(db)
    result = gateway.send(_dispatch(pair), preferred=Channel.WHATSAPP, idempotency_key="k1")
    with db.connect() as conn:
        row = (
            conn.execute(
                text(
                    """
                    SELECT channel, template_key, is_template, delivery_state,
                           provider_message_id
                    FROM notification WHERE id = :i
                    """
                ),
                {"i": result.notification_ids[0]},
            )
            .mappings()
            .one()
        )
    assert row["channel"] == "whatsapp"
    assert row["template_key"] == "pairing.invitation"
    assert row["is_template"] is True
    assert row["delivery_state"] == "sent"
    assert row["provider_message_id"]


@pytest.mark.db
def test_a_whatsapp_failure_falls_back_to_sms_and_both_are_logged(db: Engine, pair: Pair) -> None:
    gateway, wa, sms = _gateway(db, whatsapp=SendBehaviour.TRANSIENT_FAILURE)
    result = gateway.send(_dispatch(pair), preferred=Channel.WHATSAPP, idempotency_key="k1")

    assert result.failed_on == (Channel.WHATSAPP,)
    assert result.delivered_on == (Channel.SMS,)
    assert result.reached_anyone is True
    assert wa.sent == []
    assert len(sms.sent) == 1

    with db.connect() as conn:
        rows = (
            conn.execute(
                text(
                    """
                    SELECT channel, delivery_state, fallback_of_id
                    FROM notification WHERE dispatch_group = :g ORDER BY created_at
                    """
                ),
                {"g": result.dispatch_group},
            )
            .mappings()
            .all()
        )
    assert [r["channel"] for r in rows] == ["whatsapp", "sms"]
    assert rows[0]["delivery_state"] == "failed"
    assert rows[1]["fallback_of_id"] == result.notification_ids[0], (
        "the fallback records what it was a fallback for"
    )


@pytest.mark.db
def test_the_fallback_is_recorded_as_transient_when_it_was(db: Engine, pair: Pair) -> None:
    gateway, _, _ = _gateway(db, whatsapp=SendBehaviour.TRANSIENT_FAILURE)
    result = gateway.send(_dispatch(pair), preferred=Channel.WHATSAPP, idempotency_key="k1")
    with db.connect() as conn:
        audit = delivery_audit(conn, result.notification_ids[0])
    assert audit[-1]["delivery_state"] == "failed"
    assert "TransientChannelError" in audit[-1]["detail"]
    assert "(transient)" in audit[-1]["detail"]


@pytest.mark.db
def test_when_every_channel_fails_that_is_recorded_rather_than_hidden(
    db: Engine, pair: Pair
) -> None:
    gateway, _, _ = _gateway(
        db,
        whatsapp=SendBehaviour.PERMANENT_FAILURE,
        sms=SendBehaviour.PERMANENT_FAILURE,
    )
    result = gateway.send(_dispatch(pair), preferred=Channel.WHATSAPP, idempotency_key="k1")
    assert result.reached_anyone is False
    assert result.failed_on == (Channel.WHATSAPP, Channel.SMS)


@pytest.mark.db
def test_an_emergency_dispatches_every_channel_in_parallel(db: Engine, pair: Pair) -> None:
    # PRD Feature 3: push, WhatsApp and SMS in parallel, not a fallback chain.
    gateway, wa, sms = _gateway(db)
    dispatch = Dispatch(
        user_id=pair.recipient,
        to=parse_phone(pair.recipient_phone),
        template_key="pairing.invitation",
        locale="es-GT",
        variables={"sender_name": "Marco"},
        parallel=True,
    )
    result = gateway.send(dispatch, preferred=Channel.WHATSAPP, idempotency_key="k1")
    assert set(result.delivered_on) == {Channel.WHATSAPP, Channel.SMS}
    assert len(wa.sent) == 1
    assert len(sms.sent) == 1


@pytest.mark.db
def test_an_ordinary_dispatch_stops_at_the_first_success(db: Engine, pair: Pair) -> None:
    gateway, wa, sms = _gateway(db)
    gateway.send(_dispatch(pair), preferred=Channel.WHATSAPP, idempotency_key="k1")
    assert len(wa.sent) == 1
    assert sms.sent == []


@pytest.mark.db
def test_the_delivery_audit_is_queryable_per_notification(db: Engine, pair: Pair) -> None:
    # P4.4: required for dispute resolution.
    gateway, wa, _ = _gateway(db)
    result = gateway.send(_dispatch(pair), preferred=Channel.WHATSAPP, idempotency_key="k1")
    provider_id = wa.last_sent().provider_message_id
    gateway.record_delivery_receipt(provider_message_id=provider_id, state=DeliveryState.DELIVERED)
    gateway.record_delivery_receipt(provider_message_id=provider_id, state=DeliveryState.READ)

    with db.connect() as conn:
        audit = delivery_audit(conn, result.notification_ids[0])
        row = (
            conn.execute(
                text("SELECT delivery_state, delivered_at FROM notification WHERE id = :i"),
                {"i": result.notification_ids[0]},
            )
            .mappings()
            .one()
        )
    assert [e["delivery_state"] for e in audit] == ["queued", "sent", "delivered", "read"]
    assert row["delivery_state"] == "read"
    assert row["delivered_at"] is not None


@pytest.mark.db
def test_a_delivery_receipt_for_an_unknown_message_is_ignored(db: Engine) -> None:
    gateway, _, _ = _gateway(db)
    assert (
        gateway.record_delivery_receipt(
            provider_message_id="MSG-NOT-OURS", state=DeliveryState.DELIVERED
        )
        is None
    )


@pytest.mark.db
def test_a_message_reported_failed_after_acceptance_is_recorded(db: Engine, pair: Pair) -> None:
    gateway, wa, _ = _gateway(db, whatsapp=SendBehaviour.ACCEPT_THEN_FAIL)
    result = gateway.send(_dispatch(pair), preferred=Channel.WHATSAPP, idempotency_key="k1")
    provider_id = wa.last_sent().provider_message_id
    state = wa.deliver(provider_id)
    gateway.record_delivery_receipt(provider_message_id=provider_id, state=state)

    with db.connect() as conn:
        audit = delivery_audit(conn, result.notification_ids[0])
    assert audit[-1]["delivery_state"] == "failed"


@pytest.mark.db
def test_sms_never_carries_buttons(db: Engine, pair: Pair) -> None:
    # PRD Feature 4: full parity, minus inline buttons.
    gateway, _, sms = _gateway(db, whatsapp=SendBehaviour.PERMANENT_FAILURE)
    gateway.send(_dispatch(pair), preferred=Channel.WHATSAPP, idempotency_key="k1")
    assert sms.last_sent().buttons == ()


@pytest.mark.db
def test_the_gateway_refuses_to_send_copy_containing_a_banned_word(db: Engine, pair: Pair) -> None:
    gateway, _, _ = _gateway(db)
    with db.begin() as conn:
        note_inbound(conn, pair.recipient, Channel.WHATSAPP, now=NOW)
    with pytest.raises(ValueError, match="banned words"):
        gateway.send_freeform(
            user_id=pair.recipient,
            to=parse_phone(pair.recipient_phone),
            channel=Channel.WHATSAPP,
            body="Your KYC review is pending",
            idempotency_key="k1",
        )


@pytest.mark.db
def test_the_gateway_refuses_a_whatsapp_body_over_three_lines(db: Engine, pair: Pair) -> None:
    gateway, _, _ = _gateway(db)
    with db.begin() as conn:
        note_inbound(conn, pair.recipient, Channel.WHATSAPP, now=NOW)
    with pytest.raises(ValueError, match="3 lines"):
        gateway.send_freeform(
            user_id=pair.recipient,
            to=parse_phone(pair.recipient_phone),
            channel=Channel.WHATSAPP,
            body="una\ndos\ntres\ncuatro",
            idempotency_key="k1",
        )


# ======================================================================================
# P4.3 — conversational state machines
# ======================================================================================


@dataclass(frozen=True)
class World:
    """An invited pair plus the channel plumbing, typed so the tests stay checkable."""

    sender: uuid.UUID
    recipient: uuid.UUID
    relationship: uuid.UUID
    gateway: ChannelGateway
    wa: MockChannelAdapter
    sms: MockChannelAdapter
    sender_phone: str
    recipient_phone: str


@pytest.fixture()
def world(db: Engine) -> World:
    """An invited pair, a WhatsApp adapter, and a gateway wired to both channels."""
    with db.begin() as conn:
        sender = upsert_user(
            conn,
            "+15555550000",
            role=Role.SENDER,
            display_name="Marco",
            preferred_channel=UserChannel.WHATSAPP,
        )
    relationship, recipient, _ = invite_recipient(
        db, sender_id=sender.id, recipient_phone="55551234", recipient_display_name="Ana"
    )
    # The invitation puts the recipient's conversation into the pairing state; the
    # invite flow in P5 does this, and here it is set up directly.
    with db.begin() as conn:
        note_inbound(conn, recipient.id, Channel.WHATSAPP, now=NOW)
        conn.execute(
            text(
                """
                UPDATE conversation
                SET state_name = 'awaiting_pairing',
                    state_data = CAST(:data AS JSONB)
                WHERE user_id = :u AND channel = 'whatsapp'
                """
            ),
            {"u": recipient.id, "data": f'{{"relationship_id": "{relationship.id}"}}'},
        )
    gateway, wa, sms = _gateway(db)
    return World(
        sender=sender.id,
        recipient=recipient.id,
        relationship=relationship.id,
        gateway=gateway,
        wa=wa,
        sms=sms,
        sender_phone="+15555550000",
        recipient_phone="+50255551234",
    )


def _inbound(
    world: World,
    text_in: str,
    *,
    from_recipient: bool = True,
    message_id: str | None = None,
    button: str = "",
    at: datetime | None = None,
) -> InboundMessage:
    return world.wa.inbound(
        from_phone=world.recipient_phone if from_recipient else world.sender_phone,
        text=text_in,
        button=button,
        message_id=message_id,
        at=at or NOW,
    )


def _handle(
    db: Engine, world: World, message: InboundMessage, at: datetime = NOW
) -> InboundOutcome:
    return handle_inbound(db, world.gateway, message, now=at)


def _state(db: Engine, user_id: uuid.UUID) -> str:
    with db.connect() as conn:
        state: str = conn.execute(
            text("SELECT state_name FROM conversation WHERE user_id = :u"), {"u": user_id}
        ).scalar_one()
    return state


def _plan(db: Engine, world: World, *, with_rule: bool = False) -> None:
    from iwp.domain.plans import PlanError, get_active_version, get_plan_for_relationship

    try:
        version = create_plan(db, relationship_id=world.relationship, created_by=world.sender)
    except PlanError:
        # Hypothesis reuses a function-scoped fixture across examples, so the plan may
        # already exist. Tolerated here rather than worked around, because the property
        # under test is about message delivery, not plan creation.
        with db.connect() as conn:
            plan_id = get_plan_for_relationship(conn, world.relationship)
            assert plan_id is not None
            version = get_active_version(conn, plan_id)
        return
    if with_rule:
        create_recurring_rule(
            db,
            plan_id=version.plan_id,
            category_key="food",
            amount=Money(25000, "USD"),
            cadence=Cadence.MONTHLY,
            actor_id=world.sender,
        )


# -- pairing (PRD Feature 0) -----------------------------------------------------------


@pytest.mark.db
def test_pairing_acceptance_completes_in_one_exchange(db: Engine, world: World) -> None:
    # PRD Feature 0 allows up to three; one is better.
    outcome = _handle(db, world, _inbound(world, "SI"))
    assert outcome.outcome == "pairing_accepted"
    assert _state(db, world.recipient) == ConversationState.IDLE
    with db.connect() as conn:
        status = conn.execute(
            text("SELECT status FROM relationship WHERE id = :r"),
            {"r": world.relationship},
        ).scalar_one()
    assert RelationshipStatus(status) is RelationshipStatus.ACTIVE


@pytest.mark.db
def test_pairing_acceptance_notifies_both_parties(db: Engine, world: World) -> None:
    _handle(db, world, _inbound(world, "SI"))
    with db.connect() as conn:
        templates = (
            conn.execute(text("SELECT template_key FROM notification ORDER BY created_at"))
            .scalars()
            .all()
        )
    assert "pairing.accepted_recipient" in templates
    assert "pairing.accepted_sender" in templates


@pytest.mark.db
def test_pairing_acceptance_works_by_button_too(db: Engine, world: World) -> None:
    outcome = _handle(db, world, _inbound(world, "", button="Aceptar"))
    assert outcome.outcome == "pairing_accepted"


@pytest.mark.db
def test_declining_an_invitation_notifies_the_sender_without_punishment(
    db: Engine, world: World
) -> None:
    outcome = _handle(db, world, _inbound(world, "NO"))
    assert outcome.outcome == "pairing_declined"
    body, _ = render("pairing.declined_sender", "es-GT", recipient_name="Ana")
    assert "más adelante" in body, "the copy leaves the door open"
    with db.connect() as conn:
        status = conn.execute(
            text("SELECT status FROM relationship WHERE id = :r"),
            {"r": world.relationship},
        ).scalar_one()
    assert RelationshipStatus(status) is RelationshipStatus.TERMINATED


@pytest.mark.db
def test_an_unrecognized_reply_during_pairing_is_never_a_dead_end(db: Engine, world: World) -> None:
    outcome = _handle(db, world, _inbound(world, "qué es esto"))
    assert outcome.outcome == "pairing_unrecognized"
    assert outcome.replied_with == "help.unrecognized"
    assert _state(db, world.recipient) == ConversationState.AWAITING_PAIRING, (
        "the invitation is still open"
    )


@pytest.mark.db
def test_asking_for_help_at_any_point_during_onboarding_works(db: Engine, world: World) -> None:
    # PRD Feature 0: "Recipient can request help at any point in onboarding via AYUDA."
    outcome = _handle(db, world, _inbound(world, "AYUDA"))
    assert outcome.replied_with == "help.keywords"
    assert _state(db, world.recipient) == ConversationState.AWAITING_PAIRING


# -- request submission ----------------------------------------------------------------


@pytest.mark.db
def test_a_request_takes_two_exchanges_over_whatsapp_buttons(db: Engine, world: World) -> None:
    _handle(db, world, _inbound(world, "SI"))
    _plan(db, world)

    first = _handle(db, world, _inbound(world, "500"))
    assert first.replied_with == "request.ask_category_buttons"
    assert _state(db, world.recipient) == ConversationState.AWAITING_CATEGORY

    assert world.wa.last_sent().buttons == ("Vivienda", "Comida", "Negocio", "Ahorro", "Otro")

    # The recipient taps a button rather than typing (PRD Feature 4).
    second = _handle(db, world, _inbound(world, "", button="Comida", message_id="m2"))
    assert second.outcome == "request_submitted"
    assert _state(db, world.recipient) == ConversationState.IDLE

    with db.connect() as conn:
        requests = list_requests(conn, world.relationship)
    assert len(requests) == 1
    assert requests[0].amount == Money(50000, "USD")


@pytest.mark.db
def test_a_request_takes_two_exchanges_over_sms(db: Engine, world: World) -> None:
    # SMS has full functional parity, minus buttons (PRD Feature 4), so the options go
    # in the body and the reply is a number.
    _handle(db, world, _inbound(world, "SI"))
    _plan(db, world)

    def sms_in(body: str, message_id: str) -> InboundMessage:
        return world.sms.inbound(
            from_phone=world.recipient_phone, text=body, message_id=message_id, at=NOW
        )

    first = _handle(db, world, sms_in("500", "s1"))
    assert first.replied_with == "request.ask_category"
    assert "1. Vivienda" in world.sms.last_sent().body
    assert world.sms.last_sent().buttons == ()

    second = _handle(db, world, sms_in("2", "s2"))
    assert second.outcome == "request_submitted"

    with db.connect() as conn:
        requests = list_requests(conn, world.relationship)
    assert len(requests) == 1
    assert requests[0].amount == Money(50000, "USD")


@pytest.mark.db
def test_the_same_text_means_different_things_in_different_states(db: Engine, world: World) -> None:
    """ "2" is a category while we are asking about categories, and an amount otherwise.

    This is the PRD's rule that out-of-order and ambiguous input resolves against
    conversation state, not against the text.
    """
    _handle(db, world, _inbound(world, "SI"))
    _plan(db, world)

    # In idle, "2" is two dollars.
    _handle(db, world, _inbound(world, "2", message_id="m-idle"))
    assert _state(db, world.recipient) == ConversationState.AWAITING_CATEGORY

    # In awaiting_category, "2" is the second category.
    _handle(db, world, _inbound(world, "2", message_id="m-cat"))
    with db.connect() as conn:
        requests = list_requests(conn, world.relationship)
    assert len(requests) == 1
    assert requests[0].amount == Money(200, "USD")


@pytest.mark.db
def test_a_recurring_request_auto_approves_with_no_sender_action(db: Engine, world: World) -> None:
    # PRD Feature 2.
    _handle(db, world, _inbound(world, "SI"))
    _plan(db, world, with_rule=True)

    _handle(db, world, _inbound(world, "200", message_id="m1"))
    outcome = _handle(db, world, _inbound(world, "2", message_id="m2"))

    assert outcome.outcome == "request_auto_approved"
    with db.connect() as conn:
        requests = list_requests(conn, world.relationship)
        approval_channel = conn.execute(
            text("SELECT approval_channel FROM transaction")
        ).scalar_one()
    assert requests[0].status is RequestStatus.APPROVED
    assert approval_channel == "system", (
        "auto-approval is not a channel the sender used; recording it as 'app' "
        "would misreport the channel-distribution metric in PRD §11"
    )


@pytest.mark.db
def test_an_over_cap_request_goes_to_the_sender_for_approval(db: Engine, world: World) -> None:
    _handle(db, world, _inbound(world, "SI"))
    _plan(db, world, with_rule=True)

    _handle(db, world, _inbound(world, "900", message_id="m1"))
    outcome = _handle(db, world, _inbound(world, "2", message_id="m2"))

    assert outcome.outcome == "request_submitted"
    with db.connect() as conn:
        templates = conn.execute(text("SELECT template_key FROM notification")).scalars().all()
    assert "request.needs_approval_sender" in templates


@pytest.mark.db
def test_urgente_with_an_amount_submits_an_emergency_immediately(db: Engine, world: World) -> None:
    _handle(db, world, _inbound(world, "SI"))
    _plan(db, world)
    outcome = _handle(db, world, _inbound(world, "URGENTE 500 para la medicina"))

    assert outcome.outcome == "request_submitted"
    with db.connect() as conn:
        requests = list_requests(conn, world.relationship)
        templates = conn.execute(text("SELECT template_key FROM notification")).scalars().all()
    assert requests[0].is_emergency is True
    assert requests[0].amount == Money(50000, "USD")
    assert "request.emergency_sender" in templates


@pytest.mark.db
def test_urgente_alone_asks_for_the_amount(db: Engine, world: World) -> None:
    _handle(db, world, _inbound(world, "SI"))
    _plan(db, world)
    _handle(db, world, _inbound(world, "URGENTE", message_id="m1"))
    assert _state(db, world.recipient) == ConversationState.AWAITING_EMERGENCY_AMOUNT

    outcome = _handle(db, world, _inbound(world, "300", message_id="m2"))
    assert outcome.outcome == "request_submitted"
    with db.connect() as conn:
        assert list_requests(conn, world.relationship)[0].is_emergency is True


@pytest.mark.db
def test_an_emergency_message_to_the_sender_leads_with_the_name_in_capitals(
    db: Engine, world: World
) -> None:
    # PRD Feature 4: "Emergency SMS is prefixed with the recipient's name in capitals."
    body, _ = render(
        "request.emergency_sender",
        "es-GT",
        recipient_name_upper="ANA",
        amount="500.00",
        description="medicina",
    )
    assert body.startswith("ANA")


@pytest.mark.db
def test_correcting_the_amount_mid_flow_is_not_a_dead_end(db: Engine, world: World) -> None:
    _handle(db, world, _inbound(world, "SI"))
    _plan(db, world)
    _handle(db, world, _inbound(world, "500", message_id="m1"))
    _handle(db, world, _inbound(world, "600", message_id="m2"))
    _handle(db, world, _inbound(world, "2", message_id="m3"))

    with db.connect() as conn:
        requests = list_requests(conn, world.relationship)
    assert len(requests) == 1
    assert requests[0].amount == Money(60000, "USD"), "the correction won"


@pytest.mark.db
def test_an_unrecognized_reply_while_choosing_a_category_re_offers_help(
    db: Engine, world: World
) -> None:
    _handle(db, world, _inbound(world, "SI"))
    _plan(db, world)
    _handle(db, world, _inbound(world, "500", message_id="m1"))
    outcome = _handle(db, world, _inbound(world, "no sé", message_id="m2"))
    assert outcome.replied_with == "help.unrecognized"
    assert _state(db, world.recipient) == ConversationState.AWAITING_CATEGORY


# -- approval over a channel -----------------------------------------------------------


def _pending_request(db: Engine, world: World) -> None:
    _handle(db, world, _inbound(world, "SI"))
    _plan(db, world)
    _handle(db, world, _inbound(world, "500", message_id="r1"))
    _handle(db, world, _inbound(world, "2", message_id="r2"))


@pytest.mark.db
def test_a_sender_approves_in_one_action_from_a_channel(db: Engine, world: World) -> None:
    _pending_request(db, world)
    outcome = _handle(db, world, _inbound(world, "SI", from_recipient=False, message_id="a1"))
    assert outcome.outcome == "request_approved"
    with db.connect() as conn:
        assert list_requests(conn, world.relationship)[0].status is RequestStatus.APPROVED


@pytest.mark.db
def test_declining_from_a_channel_records_a_selected_reason(db: Engine, world: World) -> None:
    # PRD Feature 1 wants one action AND a reason. NO selects a preset reason rather
    # than opening a second exchange.
    _pending_request(db, world)
    outcome = _handle(db, world, _inbound(world, "NO", from_recipient=False, message_id="d1"))
    assert outcome.outcome == "request_declined"
    with db.connect() as conn:
        request = list_requests(conn, world.relationship)[0]
    assert request.status is RequestStatus.DECLINED
    assert request.decline_reason == PRESET_DECLINE_REASON


@pytest.mark.db
def test_replying_to_a_stale_request_states_the_current_state_clearly(
    db: Engine, world: World
) -> None:
    # PRD Feature 4 edge case. Silence here is the failure mode.
    _pending_request(db, world)
    _handle(db, world, _inbound(world, "SI", from_recipient=False, message_id="a1"))
    outcome = _handle(db, world, _inbound(world, "SI", from_recipient=False, message_id="a2"))
    assert outcome.outcome == "request_already_resolved"
    assert outcome.replied_with == "request.already_resolved"


@pytest.mark.db
def test_replying_when_nothing_is_pending_says_so(db: Engine, world: World) -> None:
    _handle(db, world, _inbound(world, "SI"))
    outcome = _handle(db, world, _inbound(world, "SI", from_recipient=False, message_id="a1"))
    assert outcome.outcome == "no_pending_request"


@pytest.mark.db
def test_resumen_returns_a_summary_rather_than_silence(db: Engine, world: World) -> None:
    _pending_request(db, world)
    outcome = _handle(db, world, _inbound(world, "RESUMEN", message_id="s1"))
    assert outcome.outcome == "summary"


# -- idempotence, ordering, and reconstruction -----------------------------------------


@pytest.mark.db
def test_a_duplicate_inbound_message_causes_no_double_action(db: Engine, world: World) -> None:
    _handle(db, world, _inbound(world, "SI"))
    _plan(db, world)
    _handle(db, world, _inbound(world, "500", message_id="m1"))

    first = _handle(db, world, _inbound(world, "2", message_id="m2"))
    second = _handle(db, world, _inbound(world, "2", message_id="m2"))

    assert first.is_duplicate is False
    assert second.is_duplicate is True
    assert second.outcome == first.outcome
    with db.connect() as conn:
        assert len(list_requests(conn, world.relationship)) == 1


@pytest.mark.db
def test_a_duplicate_approval_message_approves_once(db: Engine, world: World) -> None:
    _pending_request(db, world)
    for _ in range(4):
        _handle(db, world, _inbound(world, "SI", from_recipient=False, message_id="a1"))
    with db.connect() as conn:
        assert conn.execute(text("SELECT count(*) FROM transaction")).scalar_one() == 1


@pytest.mark.db
def test_state_reconstructs_from_storage_not_memory(db: Engine, world: World) -> None:
    """Each message is handled as if by a process that has never seen the others."""
    _handle(db, world, _inbound(world, "SI"))
    _plan(db, world)
    _handle(db, world, _inbound(world, "500", message_id="m1"))

    # A brand new gateway and adapter: nothing carried over except the database.
    fresh_gateway, _, _ = _gateway(db)
    fresh_adapter = MockChannelAdapter(Channel.WHATSAPP, clock=_clock)
    message = fresh_adapter.inbound(
        from_phone=world.recipient_phone, text="2", message_id="m2", at=NOW
    )
    outcome = handle_inbound(db, fresh_gateway, message, now=NOW)

    assert outcome.outcome == "request_submitted"
    with db.connect() as conn:
        assert list_requests(conn, world.relationship)[0].amount == Money(50000, "USD")


@pytest.mark.db
def test_a_message_from_an_unknown_number_is_recorded_and_ignored(db: Engine) -> None:
    gateway, wa, _ = _gateway(db)
    message = wa.inbound(from_phone="+50255559999", text="hola", message_id="x1")
    outcome = handle_inbound(db, gateway, message, now=NOW)
    assert outcome.handled is False
    assert outcome.outcome == "unknown_sender"
    with db.connect() as conn:
        assert conn.execute(text("SELECT count(*) FROM inbound_message")).scalar_one() == 1
        assert conn.execute(text("SELECT count(*) FROM notification")).scalar_one() == 0


@pytest.mark.db
def test_every_inbound_message_is_recorded_with_what_it_produced(db: Engine, world: World) -> None:
    _handle(db, world, _inbound(world, "SI", message_id="m1"))
    with db.connect() as conn:
        row = (
            conn.execute(
                text(
                    """
                    SELECT m.body, o.outcome
                    FROM inbound_message m
                    JOIN inbound_message_outcome o
                      ON o.channel = m.channel
                     AND o.provider_message_id = m.provider_message_id
                    WHERE m.provider_message_id = 'm1'
                    """
                )
            )
            .mappings()
            .one()
        )
    assert row["body"] == "SI"
    assert row["outcome"] == "pairing_accepted"


# -- property test — required by P4.3 --------------------------------------------------


@hyp_settings(
    max_examples=25,
    deadline=None,
    suppress_health_check=[HealthCheck.function_scoped_fixture],
)
@given(
    duplicates=st.lists(st.integers(min_value=0, max_value=2), min_size=0, max_size=4),
    shuffle_seed=st.integers(min_value=0, max_value=10**6),
)
@pytest.mark.slow
@pytest.mark.db
def test_property_replaying_with_duplicates_and_reordering_ends_correctly(
    db: Engine, world: World, duplicates: list[int], shuffle_seed: int
) -> None:
    """Replay a message sequence with duplicates and reordering; the end state is right.

    "Right" means three things, each of which the product depends on:
      * the conversation is always in a legal state;
      * a script that submits one request never submits two, however it is delivered;
      * a message delivered out of order is interpreted against the state it finds,
        not the state its sender assumed — so it is either handled or refused, never
        silently mis-applied.
    """
    import random

    _handle(db, world, _inbound(world, "SI"))
    _plan(db, world)

    # A fresh id prefix per example. Hypothesis reuses the function-scoped fixture, and
    # reused message ids would make every example after the first a duplicate — the
    # test would pass without exercising anything.
    run = uuid.uuid4().hex[:8]
    script = [(f"{run}-m1", "500"), (f"{run}-m2", "2")]
    with db.connect() as conn:
        before = len(list_requests(conn, world.relationship))
    delivery = list(script)
    for index in duplicates:
        if index < len(script):
            delivery.append(script[index])
    random.Random(shuffle_seed).shuffle(delivery)

    for message_id, body in delivery:
        _handle(db, world, _inbound(world, body, message_id=message_id))
        assert _state(db, world.recipient) in ConversationState.ALL

    # Whatever the delivery order, the sequence carries at most one request-creating
    # message, so this example added at most one request.
    with db.connect() as conn:
        after_delivery = len(list_requests(conn, world.relationship))
    assert after_delivery <= before + 1

    # And delivering the script in order afterwards always converges on a submitted
    # request: no delivery order can leave the conversation permanently stuck.
    for message_id, body in script:
        _handle(db, world, _inbound(world, body, message_id=f"final-{message_id}"))
    with db.connect() as conn:
        final = len(list_requests(conn, world.relationship))
    assert final > after_delivery or after_delivery == before + 1, (
        "the conversation is never left in a state it cannot recover from"
    )
    assert _state(db, world.recipient) == ConversationState.IDLE


@pytest.mark.db
def test_a_reordered_delivery_is_interpreted_against_the_state_it_finds(
    db: Engine, world: World
) -> None:
    """The category choice arriving before the amount must not create a request."""
    _handle(db, world, _inbound(world, "SI"))
    _plan(db, world)

    # "2" arrives first, out of order. In idle it reads as an amount, not a category.
    _handle(db, world, _inbound(world, "2", message_id="m2"))
    with db.connect() as conn:
        assert list_requests(conn, world.relationship) == []
    assert _state(db, world.recipient) == ConversationState.AWAITING_CATEGORY
