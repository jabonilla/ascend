"""P4.3 — conversational state machines.

The recipient's entire experience of this product happens here. They will never install
an app (PRD §2), so WhatsApp and SMS are not a notification channel, they are *the*
interface — for asking for money, for accepting an invitation, for finding out what
happened.

Four properties this module is built to hold:

* **State lives in the database, not in memory.** The process handling this message is
  not the one that handled the last. Every decision reads ``conversation.state_name``
  and ``state_data`` and writes them back in the same transaction.
* **Order is resolved against state, not arrival.** ``2`` means "the second category"
  while we are asking about categories, and "two dollars" when we are not. That is not
  a heuristic, it is the PRD's rule (Feature 4 edge cases) and it is why the same text
  can safely mean different things.
* **Duplicates do nothing twice.** Inbound messages are recorded under a UNIQUE
  constraint on the provider's message id, and a redelivery returns the original
  outcome without re-running it.
* **Never a dead end.** Every path that does not understand the message replies with
  the keyword help. A recipient waiting on money must never be met with silence.
"""

from __future__ import annotations

import json
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import Engine, text
from sqlalchemy.engine import Connection
from sqlalchemy.exc import IntegrityError

from iwp.channels.adapter import Channel, InboundMessage
from iwp.channels.gateway import ChannelGateway, Dispatch
from iwp.channels.parsing import Intent, extract_amount, interpret, parse_amount, parse_choice
from iwp.channels.session import note_inbound
from iwp.domain.plans import get_active_version, get_plan_for_relationship
from iwp.domain.requests import (
    RequestError,
    approve_request,
    decline_request,
    list_requests,
    submit_request,
)
from iwp.domain.tiers import TrustTier
from iwp.domain.users import Relationship, Role, activate_relationship, get_user, list_relationships
from iwp.money import Money
from iwp.states import RelationshipStatus, RequestStatus

__all__ = [
    "ConversationState",
    "InboundOutcome",
    "handle_inbound",
]

# A decline over a channel is one action (PRD Feature 1: "approve or decline in one
# action from any channel") but a reason is still required. So NO selects this preset
# reason rather than opening a second exchange to collect one. It is a *selected*
# reason, which is what Feature 1 allows.
PRESET_DECLINE_REASON = "Ahorita no puedo"

# The default plan currency. Requests are denominated in the plan's currency so that
# caps and recurring amounts compare meaningfully; see docs/open-questions.md for why
# a recipient typing "500" meaning quetzales is a real unresolved product problem.
_PLAN_CURRENCY = "USD"


class ConversationState:
    """The states a conversation can be in. Strings, because they are persisted."""

    IDLE = "idle"
    AWAITING_PAIRING = "awaiting_pairing"
    AWAITING_CATEGORY = "awaiting_category"
    AWAITING_EMERGENCY_AMOUNT = "awaiting_emergency_amount"

    ALL = frozenset({IDLE, AWAITING_PAIRING, AWAITING_CATEGORY, AWAITING_EMERGENCY_AMOUNT})


@dataclass(frozen=True, slots=True)
class InboundOutcome:
    """What handling a message did."""

    handled: bool
    outcome: str
    is_duplicate: bool = False
    state_before: str = ""
    state_after: str = ""
    replied_with: str = ""
    request_id: uuid.UUID | None = None


# --------------------------------------------------------------------------------------
# entry point
# --------------------------------------------------------------------------------------


def handle_inbound(
    engine: Engine,
    gateway: ChannelGateway,
    message: InboundMessage,
    *,
    now: datetime | None = None,
) -> InboundOutcome:
    """Handle one inbound message. Safe to call twice with the same message."""
    moment = now or datetime.now(UTC)

    recorded, existing_outcome = _record_inbound(engine, message)
    if not recorded:
        return InboundOutcome(handled=True, outcome=existing_outcome, is_duplicate=True)

    with engine.begin() as conn:
        user_row = conn.execute(
            text("SELECT id FROM app_user WHERE phone = :p"),
            {"p": message.from_phone.e164},
        ).scalar_one_or_none()

    if user_row is None:
        # Someone we have no record of. Recorded and ignored: replying to an unknown
        # number is how a messaging identity gets reported for spam, and there is no
        # relationship for the message to be about.
        _set_outcome(engine, message, "unknown_sender")
        return InboundOutcome(handled=False, outcome="unknown_sender")

    user_id: uuid.UUID = user_row

    with engine.begin() as conn:
        note_inbound(conn, user_id, message.channel, now=moment)
        state_name, state_data = _load_state(conn, user_id, message.channel)

    intent, token = interpret(message.body, message.button_payload)
    context = _Context(
        engine=engine,
        gateway=gateway,
        message=message,
        user_id=user_id,
        state_name=state_name,
        state_data=state_data,
        intent=intent,
        token=token,
        now=moment,
    )

    outcome = _dispatch(context)
    _set_outcome(engine, message, outcome.outcome)
    return outcome


@dataclass
class _Context:
    engine: Engine
    gateway: ChannelGateway
    message: InboundMessage
    user_id: uuid.UUID
    state_name: str
    state_data: dict[str, Any]
    intent: Intent
    token: str
    now: datetime


def _dispatch(ctx: _Context) -> InboundOutcome:
    """Route by state first, then by intent.

    State first is the whole design: the same ``2`` is a category choice or an amount
    depending on where the conversation is, and no amount of cleverness about the text
    itself can decide that.
    """
    if ctx.intent is Intent.HELP:
        return _reply_help(ctx, "help.keywords", "help")

    if ctx.state_name == ConversationState.AWAITING_PAIRING:
        return _handle_pairing(ctx)
    if ctx.state_name == ConversationState.AWAITING_CATEGORY:
        return _handle_category(ctx)
    if ctx.state_name == ConversationState.AWAITING_EMERGENCY_AMOUNT:
        return _handle_emergency_amount(ctx)
    return _handle_idle(ctx)


# --------------------------------------------------------------------------------------
# pairing (PRD Feature 0)
# --------------------------------------------------------------------------------------


def _handle_pairing(ctx: _Context) -> InboundOutcome:
    relationship_id = ctx.state_data.get("relationship_id")
    if relationship_id is None:  # pragma: no cover - state written with the id
        _set_state(ctx, ConversationState.IDLE, {})
        return _reply_help(ctx, "help.unrecognized", "pairing_lost_context")

    relationship_uuid = uuid.UUID(str(relationship_id))

    if ctx.intent is Intent.YES:
        activate_relationship(
            ctx.engine,
            relationship_uuid,
            accepted_by=ctx.user_id,
            channel=ctx.message.channel.value,
        )
        with ctx.engine.connect() as conn:
            relationship = _relationship(conn, relationship_uuid)
            sender = get_user(conn, relationship.sender_id)
            recipient = get_user(conn, ctx.user_id)

        _send(
            ctx,
            to_user_id=ctx.user_id,
            template="pairing.accepted_recipient",
            variables={"sender_name": sender.display_name},
        )
        _send(
            ctx,
            to_user_id=sender.id,
            template="pairing.accepted_sender",
            variables={"recipient_name": recipient.display_name},
            channel_override=sender.preferred_channel,
            to_phone=sender.phone,
        )
        _set_state(ctx, ConversationState.IDLE, {})
        return InboundOutcome(
            handled=True,
            outcome="pairing_accepted",
            state_before=ctx.state_name,
            state_after=ConversationState.IDLE,
            replied_with="pairing.accepted_recipient",
        )

    if ctx.intent is Intent.NO:
        from iwp.domain.users import terminate_relationship

        terminate_relationship(ctx.engine, relationship_uuid, actor_id=ctx.user_id)
        with ctx.engine.connect() as conn:
            relationship = _relationship(conn, relationship_uuid)
            sender = get_user(conn, relationship.sender_id)
            recipient = get_user(conn, ctx.user_id)
        _send(
            ctx,
            to_user_id=sender.id,
            template="pairing.declined_sender",
            variables={"recipient_name": recipient.display_name},
            channel_override=sender.preferred_channel,
            to_phone=sender.phone,
        )
        _set_state(ctx, ConversationState.IDLE, {})
        return InboundOutcome(
            handled=True,
            outcome="pairing_declined",
            state_before=ctx.state_name,
            state_after=ConversationState.IDLE,
            replied_with="pairing.declined_sender",
        )

    # Anything else while we are waiting on an invitation: help, and stay put. The
    # invitation is still open.
    return _reply_help(ctx, "help.unrecognized", "pairing_unrecognized")


# --------------------------------------------------------------------------------------
# idle
# --------------------------------------------------------------------------------------


def _handle_idle(ctx: _Context) -> InboundOutcome:
    if ctx.intent is Intent.SUMMARY:
        return _reply_summary(ctx)

    if ctx.intent in (Intent.YES, Intent.NO):
        return _resolve_pending_request(ctx)

    if ctx.intent is Intent.URGENT:
        # The keyword already established the intent, so an amount buried in the rest
        # of the sentence is unambiguous here.
        amount = extract_amount(ctx.token, _PLAN_CURRENCY)
        if amount is None:
            _set_state(ctx, ConversationState.AWAITING_EMERGENCY_AMOUNT, {})
            # A template rather than freeform: the person may be messaging us for the
            # first time in days, and freeform outside a session window does not send.
            # An emergency is the worst possible moment to discover that.
            _send(
                ctx,
                to_user_id=ctx.user_id,
                template="request.ask_emergency_amount",
                variables={},
            )
            return InboundOutcome(
                handled=True,
                outcome="emergency_awaiting_amount",
                state_before=ctx.state_name,
                state_after=ConversationState.AWAITING_EMERGENCY_AMOUNT,
                replied_with="request.ask_emergency_amount",
            )
        return _submit(ctx, amount=amount, category_key=None, emergency=True)

    if ctx.intent in (Intent.AMOUNT, Intent.CHOICE):
        # In idle, a bare number is an amount. This is the other half of the rule that
        # makes "2" a category choice when we are asking about categories.
        amount = parse_amount(ctx.token, _PLAN_CURRENCY)
        if amount is None:
            return _reply_help(ctx, "help.unrecognized", "unrecognized")
        return _ask_for_category(ctx, amount)

    return _reply_help(ctx, "help.unrecognized", "unrecognized")


def _handle_emergency_amount(ctx: _Context) -> InboundOutcome:
    amount = extract_amount(ctx.token, _PLAN_CURRENCY)
    if amount is None:
        return _reply_help(ctx, "help.unrecognized", "emergency_amount_unrecognized")
    return _submit(ctx, amount=amount, category_key=None, emergency=True)


# --------------------------------------------------------------------------------------
# request submission (PRD Feature 1)
# --------------------------------------------------------------------------------------


def _ask_for_category(ctx: _Context, amount: Money) -> InboundOutcome:
    relationship = _active_relationship_as(ctx, Role.RECIPIENT)
    if relationship is None:
        return _reply_help(ctx, "help.unrecognized", "no_active_relationship")

    categories = _categories(ctx, relationship)
    if not categories:
        # No plan yet: submit uncategorised rather than blocking. The sender will be
        # asked to approve it, which is the correct outcome for "outside the plan".
        return _submit(ctx, amount=amount, category_key=None, emergency=False)

    names = [name for _, name in categories]
    _set_state(
        ctx,
        ConversationState.AWAITING_CATEGORY,
        {
            "amount_minor_units": amount.minor_units,
            "currency": amount.currency.code,
            "relationship_id": str(relationship.id),
            "category_keys": [key for key, _ in categories],
            "category_names": names,
        },
    )

    if ctx.message.channel.supports_buttons:
        # The options are buttons, not text to type (PRD Feature 4).
        template = "request.ask_category_buttons"
        _send(
            ctx,
            to_user_id=ctx.user_id,
            template=template,
            variables={},
            buttons=tuple(names),
        )
    else:
        template = "request.ask_category"
        listing = "\n".join(f"{i + 1}. {name}" for i, name in enumerate(names))
        _send(
            ctx,
            to_user_id=ctx.user_id,
            template=template,
            variables={"category_list": listing},
        )

    return InboundOutcome(
        handled=True,
        outcome="awaiting_category",
        state_before=ctx.state_name,
        state_after=ConversationState.AWAITING_CATEGORY,
        replied_with=template,
    )


def _handle_category(ctx: _Context) -> InboundOutcome:
    keys: list[str] = list(ctx.state_data.get("category_keys") or [])
    names: list[str] = list(ctx.state_data.get("category_names") or [])

    # A tapped button carries the category's name, a typed SMS carries its number.
    # Both resolve to the same key; the conversation does not care which channel the
    # person is on.
    tapped = _match_category_name(ctx.token, names)
    if tapped is not None:
        amount = Money(int(ctx.state_data["amount_minor_units"]), str(ctx.state_data["currency"]))
        return _submit(ctx, amount=amount, category_key=keys[tapped], emergency=False)

    choice = parse_choice(ctx.token, options=len(keys)) if keys else None
    if choice is not None:
        amount = Money(int(ctx.state_data["amount_minor_units"]), str(ctx.state_data["currency"]))
        return _submit(ctx, amount=amount, category_key=keys[choice - 1], emergency=False)

    # A fresh amount replaces the pending one rather than being rejected. People
    # correct themselves; a state machine that refuses is a dead end.
    replacement = parse_amount(ctx.token, _PLAN_CURRENCY)
    if replacement is not None:
        return _ask_for_category(ctx, replacement)

    if ctx.intent is Intent.URGENT:
        amount = extract_amount(ctx.token, _PLAN_CURRENCY) or Money(
            int(ctx.state_data["amount_minor_units"]), str(ctx.state_data["currency"])
        )
        return _submit(ctx, amount=amount, category_key=None, emergency=True)

    return _reply_help(ctx, "help.unrecognized", "category_unrecognized")


def _match_category_name(token: str, names: list[str]) -> int | None:
    """Index of the category whose name the user tapped, or None."""
    from iwp.voice import fold

    folded = fold(token.strip())
    for index, name in enumerate(names):
        if folded == fold(name):
            return index
    return None


def _submit(
    ctx: _Context, *, amount: Money, category_key: str | None, emergency: bool
) -> InboundOutcome:
    relationship = _active_relationship_as(ctx, Role.RECIPIENT)
    if relationship is None:
        return _reply_help(ctx, "help.unrecognized", "no_active_relationship")

    description = ctx.message.body.strip()[:200]

    try:
        submission = submit_request(
            ctx.engine,
            relationship_id=relationship.id,
            requested_by=ctx.user_id,
            amount=amount,
            category_key=category_key,
            description=description,
            channel=ctx.message.channel.value,
            is_emergency=emergency,
            idempotency_key=f"{ctx.message.channel.value}:{ctx.message.provider_message_id}",
            now=ctx.now,
        )
    except RequestError as exc:
        _set_state(ctx, ConversationState.IDLE, {})
        _send_freeform(ctx, f"No pude registrar el pedido: {exc}")
        return InboundOutcome(handled=False, outcome="submit_refused")

    _set_state(ctx, ConversationState.IDLE, {})

    with ctx.engine.connect() as conn:
        sender = get_user(conn, relationship.sender_id)
        recipient = get_user(conn, ctx.user_id)
        category_name = _category_name(conn, submission.request.category_id) or "Otro"

    request = submission.request

    # PRD Feature 2: within the agreement, it just happens. No sender action.
    if request.tier is TrustTier.RECURRING:
        approve_request(
            ctx.engine,
            request.id,
            approved_by=relationship.sender_id,
            channel="system",
            assurance_level="recurring_rule",
            now=ctx.now,
        )
        _send(
            ctx,
            to_user_id=ctx.user_id,
            template="request.auto_approved",
            variables={"amount": amount.to_decimal_string(), "category": category_name},
        )
        return InboundOutcome(
            handled=True,
            outcome="request_auto_approved",
            state_before=ctx.state_name,
            state_after=ConversationState.IDLE,
            replied_with="request.auto_approved",
            request_id=request.id,
        )

    template = (
        "request.emergency_sender" if request.is_emergency else "request.needs_approval_sender"
    )
    _send(
        ctx,
        to_user_id=sender.id,
        template=template,
        variables={
            "recipient_name": recipient.display_name,
            "recipient_name_upper": recipient.display_name.upper(),
            "amount": amount.to_decimal_string(),
            "category": category_name,
            "note": submission.decision.note,
            "description": description or "—",
        },
        channel_override=sender.preferred_channel,
        to_phone=sender.phone,
        parallel=request.is_emergency,
        related=("request", request.id),
    )
    _send(
        ctx,
        to_user_id=ctx.user_id,
        template="request.submitted",
        variables={
            "sender_name": sender.display_name,
            "amount": amount.to_decimal_string(),
            "category": category_name,
        },
    )

    if submission.emergency_rate_limit_hit:
        # PRD Feature 3: a soft warning to both parties, never a block.
        count_variables = {"count": 3}
        for party in (ctx.user_id, sender.id):
            _send(
                ctx,
                to_user_id=party,
                template="emergency.rate_limit_warning",
                variables=count_variables,
                channel_override=(sender.preferred_channel if party == sender.id else None),
                to_phone=sender.phone if party == sender.id else None,
            )

    return InboundOutcome(
        handled=True,
        outcome="request_submitted",
        state_before=ctx.state_name,
        state_after=ConversationState.IDLE,
        replied_with="request.submitted",
        request_id=request.id,
    )


# --------------------------------------------------------------------------------------
# approval over a channel (PRD Feature 1, one action)
# --------------------------------------------------------------------------------------


def _resolve_pending_request(ctx: _Context) -> InboundOutcome:
    relationship = _active_relationship_as(ctx, Role.SENDER)
    if relationship is None:
        return _reply(ctx, "request.none_pending", {}, "no_pending_request")

    with ctx.engine.connect() as conn:
        pending = list_requests(
            conn, relationship.id, statuses=frozenset({RequestStatus.PENDING}), limit=1
        )
        if not pending:
            # Replying to something already resolved must say so clearly, not go quiet
            # (PRD Feature 4 edge case).
            recent = list_requests(conn, relationship.id, limit=1)
            if recent:
                return _reply(
                    ctx,
                    "request.already_resolved",
                    {"status": _status_word(recent[0].status)},
                    "request_already_resolved",
                )
            return _reply(ctx, "request.none_pending", {}, "no_pending_request")
        request = pending[0]
        recipient = get_user(conn, relationship.recipient_id)
        sender = get_user(conn, ctx.user_id)
        category_name = _category_name(conn, request.category_id) or "Otro"

    if ctx.intent is Intent.YES:
        approve_request(
            ctx.engine,
            request.id,
            approved_by=ctx.user_id,
            channel=ctx.message.channel.value,
            assurance_level="channel_verified",
            now=ctx.now,
        )
        _send(
            ctx,
            to_user_id=recipient.id,
            template="request.approved_recipient",
            variables={
                "sender_name": sender.display_name,
                "amount": request.amount.to_decimal_string(),
                "category": category_name,
            },
            channel_override=recipient.preferred_channel,
            to_phone=recipient.phone,
            related=("request", request.id),
        )
        return InboundOutcome(
            handled=True,
            outcome="request_approved",
            replied_with="request.approved_recipient",
            request_id=request.id,
        )

    decline_request(
        ctx.engine,
        request.id,
        declined_by=ctx.user_id,
        reason=PRESET_DECLINE_REASON,
        channel=ctx.message.channel.value,
        assurance_level="channel_verified",
        now=ctx.now,
    )
    _send(
        ctx,
        to_user_id=recipient.id,
        template="request.declined_recipient",
        variables={
            "sender_name": sender.display_name,
            "reason": PRESET_DECLINE_REASON,
        },
        channel_override=recipient.preferred_channel,
        to_phone=recipient.phone,
        related=("request", request.id),
    )
    return InboundOutcome(
        handled=True,
        outcome="request_declined",
        replied_with="request.declined_recipient",
        request_id=request.id,
    )


# --------------------------------------------------------------------------------------
# summary and help
# --------------------------------------------------------------------------------------


def _reply_summary(ctx: _Context) -> InboundOutcome:
    with ctx.engine.connect() as conn:
        relationships = list_relationships(
            conn, ctx.user_id, statuses=frozenset({RelationshipStatus.ACTIVE})
        )
        lines: list[str] = []
        for relationship in relationships[:3]:
            for request in list_requests(conn, relationship.id, limit=3):
                lines.append(
                    f"{request.amount.to_decimal_string()} — {_status_word(request.status)}"
                )
    body = "\n".join(lines[:5]) or "Todavía no hay movimientos."
    return _reply(ctx, "summary.recent", {"summary_lines": body}, "summary")


def _reply_help(ctx: _Context, template: str, outcome: str) -> InboundOutcome:
    return _reply(ctx, template, {}, outcome)


def _reply(ctx: _Context, template: str, variables: dict[str, Any], outcome: str) -> InboundOutcome:
    _send(ctx, to_user_id=ctx.user_id, template=template, variables=variables)
    return InboundOutcome(
        handled=True,
        outcome=outcome,
        state_before=ctx.state_name,
        state_after=ctx.state_name,
        replied_with=template,
    )


# --------------------------------------------------------------------------------------
# plumbing
# --------------------------------------------------------------------------------------


def _record_inbound(engine: Engine, message: InboundMessage) -> tuple[bool, str]:
    """Write the inbound message. Returns (is_new, existing outcome if not).

    The UNIQUE constraint is the idempotency mechanism, so a redelivery loses the
    insert rather than being detected by a check that could race.
    """
    try:
        with engine.begin() as conn:
            conn.execute(
                text(
                    """
                    INSERT INTO inbound_message
                        (channel, provider_message_id, from_phone, body,
                         button_payload, occurred_at)
                    VALUES (:channel, :message_id, :phone, :body, :button, :occurred_at)
                    """
                ),
                {
                    "channel": message.channel.value,
                    "message_id": message.provider_message_id,
                    "phone": message.from_phone.e164,
                    "body": message.body,
                    "button": message.button_payload,
                    "occurred_at": message.occurred_at,
                },
            )
    except IntegrityError:
        with engine.connect() as conn:
            outcome = conn.execute(
                text(
                    """
                    SELECT COALESCE(o.outcome, '')
                    FROM inbound_message m
                    LEFT JOIN inbound_message_outcome o
                           ON o.channel = m.channel
                          AND o.provider_message_id = m.provider_message_id
                    WHERE m.channel = :c AND m.provider_message_id = :m
                    """
                ),
                {"c": message.channel.value, "m": message.provider_message_id},
            ).scalar_one()
        return False, str(outcome)
    return True, ""


def _set_outcome(engine: Engine, message: InboundMessage, outcome: str) -> None:
    """Record what handling produced.

    ``inbound_message`` is append-only, so this is a separate small table rather than
    an UPDATE — the message as it arrived and what we did about it are two facts, and
    the first one never changes.
    """
    with engine.begin() as conn:
        conn.execute(
            text(
                """
                INSERT INTO inbound_message_outcome (channel, provider_message_id, outcome)
                VALUES (:c, :m, :o)
                ON CONFLICT (channel, provider_message_id) DO NOTHING
                """
            ),
            {
                "c": message.channel.value,
                "m": message.provider_message_id,
                "o": outcome,
            },
        )


def _load_state(
    conn: Connection, user_id: uuid.UUID, channel: Channel
) -> tuple[str, dict[str, Any]]:
    row = (
        conn.execute(
            text(
                """
                SELECT state_name, state_data FROM conversation
                WHERE user_id = :u AND channel = :c
                """
            ),
            {"u": user_id, "c": channel.value},
        )
        .mappings()
        .one_or_none()
    )
    if row is None:
        return ConversationState.IDLE, {}
    return str(row["state_name"]), dict(row["state_data"] or {})


def _set_state(ctx: _Context, state_name: str, state_data: dict[str, Any]) -> None:
    if state_name not in ConversationState.ALL:
        raise ValueError(f"unknown conversation state: {state_name!r}")
    with ctx.engine.begin() as conn:
        conn.execute(
            text(
                """
                UPDATE conversation
                SET state_name = :name, state_data = CAST(:data AS JSONB),
                    last_applied_event_at = GREATEST(
                        conversation.last_applied_event_at, :occurred_at
                    ),
                    updated_at = now()
                WHERE user_id = :u AND channel = :c
                """
            ),
            {
                "name": state_name,
                "data": json.dumps(state_data, default=str),
                "occurred_at": ctx.message.occurred_at,
                "u": ctx.user_id,
                "c": ctx.message.channel.value,
            },
        )
    ctx.state_data = state_data


def _send(
    ctx: _Context,
    *,
    to_user_id: uuid.UUID,
    template: str,
    variables: dict[str, Any],
    channel_override: Any = None,
    to_phone: Any = None,
    parallel: bool = False,
    related: tuple[str, uuid.UUID] | None = None,
    buttons: tuple[str, ...] | None = None,
) -> None:
    with ctx.engine.connect() as conn:
        user = get_user(conn, to_user_id)
    channel = channel_override or ctx.message.channel
    if not isinstance(channel, Channel):
        channel = Channel(getattr(channel, "value", channel))

    ctx.gateway.send(
        Dispatch(
            user_id=to_user_id,
            to=to_phone or user.phone,
            template_key=template,
            locale=user.locale,
            variables=variables,
            related_entity_type=related[0] if related else "",
            related_entity_id=related[1] if related else None,
            parallel=parallel,
            buttons=buttons,
        ),
        preferred=channel,
        idempotency_key=f"{ctx.message.provider_message_id}:{template}:{to_user_id}",
    )


def _send_freeform(ctx: _Context, body: str) -> None:
    with ctx.engine.connect() as conn:
        user = get_user(conn, ctx.user_id)
    ctx.gateway.send_freeform(
        user_id=ctx.user_id,
        to=user.phone,
        channel=ctx.message.channel,
        body=body,
        idempotency_key=f"{ctx.message.provider_message_id}:freeform",
    )


def _relationship(conn: Connection, relationship_id: uuid.UUID) -> Relationship:
    from iwp.domain.users import get_relationship

    return get_relationship(conn, relationship_id)


def _active_relationship_as(ctx: _Context, role: Role) -> Relationship | None:
    """The relationship this message is about.

    At MVP a message resolves to the single active relationship in that role. A
    recipient with several senders needs disambiguation — PRD §10 says they see
    requests grouped by sender — and that is not built here; see
    docs/open-questions.md.
    """
    with ctx.engine.connect() as conn:
        found = list_relationships(
            conn,
            ctx.user_id,
            as_role=role,
            statuses=frozenset({RelationshipStatus.ACTIVE}),
        )
    return found[0] if found else None


def _categories(ctx: _Context, relationship: Relationship) -> list[tuple[str, str]]:
    with ctx.engine.connect() as conn:
        plan_id = get_plan_for_relationship(conn, relationship.id)
        if plan_id is None:
            return []
        version = get_active_version(conn, plan_id)
        return [(c.key, c.name) for c in version.categories]


def _category_name(conn: Connection, category_id: uuid.UUID | None) -> str | None:
    if category_id is None:
        return None
    name: str | None = conn.execute(
        text("SELECT name FROM category WHERE id = :c"), {"c": category_id}
    ).scalar_one_or_none()
    return name


def _status_word(status: RequestStatus) -> str:
    return {
        RequestStatus.PENDING: "pendiente",
        RequestStatus.APPROVED: "aprobado",
        RequestStatus.DECLINED: "no aprobado",
        RequestStatus.EXPIRED: "vencido",
    }[status]
