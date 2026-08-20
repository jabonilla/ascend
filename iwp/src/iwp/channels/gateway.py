"""P4.1 and P4.4 — the channel gateway.

Everything that must behave the same regardless of who carries the message lives here:
the session-window rule, the delivery audit, and the fallback chain.

The audit trail is the part that will feel like overhead right up until the first
dispute. PRD Feature 4 requires every outbound message to log channel, template and
delivery state; P4.4 requires that audit to be queryable per notification. A recipient
saying "you never told me it failed" is answered from these two tables or not at all.
"""

from __future__ import annotations

import json
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import Engine, text
from sqlalchemy.engine import Connection

from iwp.channels.adapter import (
    Channel,
    ChannelAdapter,
    ChannelError,
    DeliveryState,
    TransientChannelError,
)
from iwp.channels.copy import TEMPLATES, render
from iwp.channels.session import Deliverability, SessionWindowClosed, classify_delivery
from iwp.domain.phone import PhoneNumber
from iwp.voice import banned_words_in, is_within_line_budget

__all__ = [
    "ChannelGateway",
    "Dispatch",
    "DispatchResult",
    "delivery_audit",
]

# PRD Feature 4 and P4.4: a WhatsApp failure falls back to SMS. The order is the
# product's, not a provider's.
_FALLBACK_ORDER: dict[Channel, tuple[Channel, ...]] = {
    Channel.WHATSAPP: (Channel.SMS,),
    Channel.PUSH: (Channel.WHATSAPP, Channel.SMS),
    Channel.SMS: (),
    Channel.APP: (),
}


@dataclass(frozen=True, slots=True)
class Dispatch:
    """One notification to send, before a channel has been chosen."""

    user_id: uuid.UUID
    to: PhoneNumber
    template_key: str
    locale: str
    variables: dict[str, Any]
    related_entity_type: str = ""
    related_entity_id: uuid.UUID | None = None
    #: Set for emergencies: every channel at once rather than one with fallback.
    parallel: bool = False
    #: Overrides the template's static buttons. Used where the options are data — the
    #: categories of the plan version in force — rather than fixed copy.
    buttons: tuple[str, ...] | None = None


@dataclass(frozen=True, slots=True)
class DispatchResult:
    notification_ids: tuple[uuid.UUID, ...]
    delivered_on: tuple[Channel, ...]
    failed_on: tuple[Channel, ...]
    dispatch_group: uuid.UUID

    @property
    def reached_anyone(self) -> bool:
        return bool(self.delivered_on)


class ChannelGateway:
    """Sends product notifications over whichever channels are available."""

    def __init__(
        self,
        engine: Engine,
        adapters: dict[Channel, ChannelAdapter],
        *,
        clock: Any = None,
    ) -> None:
        self._engine = engine
        self._adapters = adapters
        self._clock = clock or (lambda: datetime.now(UTC))

    # -- sending -----------------------------------------------------------------------

    def send(
        self,
        dispatch: Dispatch,
        *,
        preferred: Channel,
        idempotency_key: str,
    ) -> DispatchResult:
        """Send on the preferred channel, falling back if it fails.

        PRD Feature 4: "WhatsApp delivery fails → SMS fallback within 60 seconds,
        logged." The fallback here is immediate — the 60 seconds is a ceiling, not a
        delay to honour, and a recipient waiting on money should not be made to wait
        out a timer.
        """
        group = uuid.uuid4()
        chain = (
            self._all_channels(preferred)
            if dispatch.parallel
            else (preferred, *_FALLBACK_ORDER.get(preferred, ()))
        )

        ids: list[uuid.UUID] = []
        delivered: list[Channel] = []
        failed: list[Channel] = []

        for channel in chain:
            adapter = self._adapters.get(channel)
            if adapter is None:
                continue
            notification_id, ok = self._send_one(
                dispatch,
                channel=channel,
                adapter=adapter,
                dispatch_group=group,
                idempotency_key=f"{idempotency_key}:{channel.value}",
                fallback_of=ids[-1] if ids and not dispatch.parallel else None,
            )
            ids.append(notification_id)
            (delivered if ok else failed).append(channel)

            # Emergency dispatch tries every channel; ordinary dispatch stops at the
            # first success (PRD Feature 3 vs Feature 4).
            if ok and not dispatch.parallel:
                break

        return DispatchResult(
            notification_ids=tuple(ids),
            delivered_on=tuple(delivered),
            failed_on=tuple(failed),
            dispatch_group=group,
        )

    def _all_channels(self, preferred: Channel) -> tuple[Channel, ...]:
        """Preferred first, then everything else we have an adapter for."""
        rest = [c for c in (Channel.PUSH, Channel.WHATSAPP, Channel.SMS) if c is not preferred]
        return (preferred, *rest)

    def _send_one(
        self,
        dispatch: Dispatch,
        *,
        channel: Channel,
        adapter: ChannelAdapter,
        dispatch_group: uuid.UUID,
        idempotency_key: str,
        fallback_of: uuid.UUID | None,
    ) -> tuple[uuid.UUID, bool]:
        body, buttons = render(dispatch.template_key, dispatch.locale, **dispatch.variables)
        if dispatch.buttons is not None:
            buttons = dispatch.buttons
        if not channel.supports_buttons:
            buttons = ()

        self._assert_copy_is_sendable(dispatch.template_key, channel, body)

        with self._engine.begin() as conn:
            mode = classify_delivery(conn, dispatch.user_id, channel, now=self._clock())
            use_template = mode is not Deliverability.SESSION_ELIGIBLE
            if use_template:
                self._assert_template_is_approved(dispatch.template_key, channel, dispatch.locale)

            notification_id = self._record_queued(
                conn,
                dispatch,
                channel=channel,
                body=body,
                is_template=use_template,
                dispatch_group=dispatch_group,
                fallback_of=fallback_of,
            )

        try:
            if use_template:
                receipt = adapter.send_template(
                    to=dispatch.to,
                    template_key=dispatch.template_key,
                    locale=dispatch.locale,
                    body=body,
                    buttons=buttons,
                    idempotency_key=idempotency_key,
                )
            else:
                receipt = adapter.send_freeform(
                    to=dispatch.to,
                    body=body,
                    buttons=buttons,
                    idempotency_key=idempotency_key,
                )
        except ChannelError as exc:
            self._record_delivery_state(
                notification_id,
                DeliveryState.FAILED,
                detail=f"{type(exc).__name__}: {exc}",
                transient=isinstance(exc, TransientChannelError),
            )
            return notification_id, False

        self._record_delivery_state(
            notification_id,
            receipt.delivery_state,
            detail="",
            provider_message_id=receipt.provider_message_id,
        )
        return notification_id, True

    # -- guards ------------------------------------------------------------------------

    def _assert_copy_is_sendable(self, template_key: str, channel: Channel, body: str) -> None:
        """Voice rules, checked before the message leaves rather than in review.

        Both of these are PRD requirements that are easy to violate by editing one
        string, and impossible to notice afterwards without reading every send.
        """
        offending = banned_words_in(body)
        if offending:
            raise ValueError(
                f"template {template_key!r} contains banned words {offending} "
                "(PRD Feature 9 / design system §6.2)"
            )
        if channel is Channel.WHATSAPP and not is_within_line_budget(body):
            raise ValueError(
                f"template {template_key!r} exceeds 3 lines before its buttons "
                "(PRD Feature 4). The design floor is a shared mid-tier Android on 2G."
            )

    def _assert_template_is_approved(
        self, template_key: str, channel: Channel, locale: str
    ) -> None:
        """Outside a session window only a BSP-approved template may go out."""
        if channel is not Channel.WHATSAPP:
            return
        template = TEMPLATES.get((template_key, locale)) or TEMPLATES.get((template_key, "es-GT"))
        if template is None:
            raise KeyError(f"no template for {template_key!r}")
        if not template.requires_bsp_approval:
            # A template marked as not needing approval is a conversational reply. It
            # has no business being sent outside a session window, and saying so is
            # better than sending something the BSP will reject.
            raise SessionWindowClosed(
                f"{template_key!r} is a conversational reply and there is no open "
                "session window. Use a template designed to be sent cold."
            )

    def assert_freeform_allowed(
        self, user_id: uuid.UUID, channel: Channel, *, now: datetime | None = None
    ) -> None:
        """Raise unless a freeform message may be sent right now.

        Exposed so a caller composing something bespoke can ask first, rather than
        discovering the answer from a provider error.
        """
        with self._engine.connect() as conn:
            mode = classify_delivery(conn, user_id, channel, now=now or self._clock())
        if mode is Deliverability.TEMPLATE_REQUIRED:
            raise SessionWindowClosed(
                f"no open session window for user {user_id} on {channel.value}; "
                "only an approved template may be sent"
            )

    def send_freeform(
        self,
        *,
        user_id: uuid.UUID,
        to: PhoneNumber,
        channel: Channel,
        body: str,
        idempotency_key: str,
        buttons: tuple[str, ...] = (),
    ) -> uuid.UUID:
        """Send arbitrary text, refusing outside a session window."""
        self.assert_freeform_allowed(user_id, channel)
        self._assert_copy_is_sendable("<freeform>", channel, body)
        adapter = self._adapters[channel]

        with self._engine.begin() as conn:
            notification_id = self._record_queued(
                conn,
                Dispatch(user_id=user_id, to=to, template_key="", locale="es-GT", variables={}),
                channel=channel,
                body=body,
                is_template=False,
                dispatch_group=uuid.uuid4(),
                fallback_of=None,
            )
        try:
            receipt = adapter.send_freeform(
                to=to,
                body=body,
                buttons=buttons if channel.supports_buttons else (),
                idempotency_key=idempotency_key,
            )
        except ChannelError as exc:
            self._record_delivery_state(notification_id, DeliveryState.FAILED, detail=str(exc))
            raise
        self._record_delivery_state(
            notification_id,
            receipt.delivery_state,
            detail="",
            provider_message_id=receipt.provider_message_id,
        )
        return notification_id

    # -- recording ---------------------------------------------------------------------

    def _record_queued(
        self,
        conn: Connection,
        dispatch: Dispatch,
        *,
        channel: Channel,
        body: str,
        is_template: bool,
        dispatch_group: uuid.UUID,
        fallback_of: uuid.UUID | None,
    ) -> uuid.UUID:
        notification_id: uuid.UUID = conn.execute(
            text(
                """
                INSERT INTO notification
                    (user_id, channel, template_key, is_template, locale, body,
                     payload_ref, delivery_state, dispatch_group, fallback_of_id,
                     related_entity_type, related_entity_id)
                VALUES
                    (:user_id, :channel, :template_key, :is_template, :locale, :body,
                     CAST(:payload AS JSONB), 'queued', :group, :fallback_of,
                     :entity_type, :entity_id)
                RETURNING id
                """
            ),
            {
                "user_id": dispatch.user_id,
                "channel": channel.value,
                "template_key": dispatch.template_key,
                "is_template": is_template,
                "locale": dispatch.locale,
                "body": body,
                "payload": json.dumps(dispatch.variables, default=str),
                "group": dispatch_group,
                "fallback_of": fallback_of,
                "entity_type": dispatch.related_entity_type,
                "entity_id": dispatch.related_entity_id,
            },
        ).scalar_one()
        conn.execute(
            text(
                """
                INSERT INTO notification_delivery_event (notification_id, delivery_state)
                VALUES (:n, 'queued')
                """
            ),
            {"n": notification_id},
        )
        return notification_id

    def _record_delivery_state(
        self,
        notification_id: uuid.UUID,
        state: DeliveryState,
        *,
        detail: str,
        provider_message_id: str | None = None,
        transient: bool = False,
    ) -> None:
        with self._engine.begin() as conn:
            conn.execute(
                text(
                    """
                    UPDATE notification
                    SET delivery_state = :state,
                        provider_message_id = COALESCE(:provider_id, provider_message_id),
                        sent_at = CASE WHEN :state IN ('sent', 'delivered', 'read')
                            THEN COALESCE(sent_at, now()) ELSE sent_at END,
                        delivered_at = CASE WHEN :state IN ('delivered', 'read')
                            THEN COALESCE(delivered_at, now()) ELSE delivered_at END,
                        failure_reason = CASE WHEN :state = 'failed' THEN :detail
                            ELSE failure_reason END,
                        updated_at = now()
                    WHERE id = :id
                    """
                ),
                {
                    "state": state.value,
                    "provider_id": provider_message_id,
                    "detail": detail,
                    "id": notification_id,
                },
            )
            conn.execute(
                text(
                    """
                    INSERT INTO notification_delivery_event
                        (notification_id, delivery_state, detail)
                    VALUES (:n, :state, :detail)
                    """
                ),
                {
                    "n": notification_id,
                    "state": state.value,
                    "detail": f"{detail} (transient)" if transient else detail,
                },
            )

    def record_delivery_receipt(
        self, *, provider_message_id: str, state: DeliveryState, detail: str = ""
    ) -> uuid.UUID | None:
        """Apply a BSP delivery receipt. Returns the notification it belonged to.

        A receipt for a message we do not know about is ignored rather than guessed at,
        the same as an unknown settlement event.
        """
        with self._engine.connect() as conn:
            notification_id: uuid.UUID | None = conn.execute(
                text("SELECT id FROM notification WHERE provider_message_id = :p"),
                {"p": provider_message_id},
            ).scalar_one_or_none()
        if notification_id is None:
            return None
        self._record_delivery_state(notification_id, state, detail=detail)
        return notification_id


def delivery_audit(conn: Connection, notification_id: uuid.UUID) -> list[dict[str, Any]]:
    """Every delivery-state change for one notification, oldest first.

    P4.4: "Delivery audit is queryable per notification — required for dispute
    resolution."
    """
    rows = (
        conn.execute(
            text(
                """
                SELECT delivery_state, detail, occurred_at
                FROM notification_delivery_event
                WHERE notification_id = :n
                ORDER BY occurred_at, id
                """
            ),
            {"n": notification_id},
        )
        .mappings()
        .all()
    )
    return [dict(row) for row in rows]
