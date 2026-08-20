"""A mock Business Solution Provider.

WaveLink is a fictional BSP. The name exists so the guardrail test that greps for BSP
names outside this directory has something to catch, and so the day a real BSP is
chosen the diff is one file plus one line in that test's token list.

Like the settlement mock, this is a hostile simulation rather than a stub: it can fail
transiently, fail permanently, silently drop a message, and deliver inbound webhooks
late, twice, and in the wrong order.
"""

from __future__ import annotations

import enum
import itertools
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import UTC, datetime
from typing import Any

from iwp.channels.adapter import (
    Channel,
    ChannelAdapter,
    ChannelError,
    DeliveryState,
    InboundMessage,
    OutboundReceipt,
    TransientChannelError,
)
from iwp.domain.phone import PhoneNumber, parse_phone

__all__ = ["WAVELINK_NAME", "MockChannelAdapter", "SendBehaviour", "SentMessage"]

WAVELINK_NAME = "wavelink"


class SendBehaviour(enum.Enum):
    """What the simulated network does with an outbound message."""

    ACCEPT = "accept"
    """Accepted and delivered."""

    ACCEPT_THEN_FAIL = "accept_then_fail"
    """Accepted, then reported failed by a later delivery receipt. The nastiest case,
    because the send looked fine."""

    TRANSIENT_FAILURE = "transient_failure"
    """Refused now; another channel or a retry may work. Triggers SMS fallback."""

    PERMANENT_FAILURE = "permanent_failure"
    """Refused for good — usually a number that is not reachable on this channel."""


@dataclass
class SentMessage:
    provider_message_id: str
    to: str
    body: str
    buttons: tuple[str, ...]
    template_key: str
    #: The locale variant the BSP was asked for. A real BSP approves a template per
    #: locale, so sending the wrong one is a rejection; recorded here so a test can
    #: assert we asked for the right one.
    locale: str
    is_template: bool
    idempotency_key: str
    sent_at: datetime
    delivery_state: DeliveryState
    history: list[DeliveryState] = field(default_factory=list)


class MockChannelAdapter(ChannelAdapter):
    """An in-process BSP. No network, deterministic, fully controllable."""

    name = WAVELINK_NAME

    def __init__(
        self,
        channel: Channel = Channel.WHATSAPP,
        *,
        behaviour: SendBehaviour = SendBehaviour.ACCEPT,
        clock: Callable[[], datetime] | None = None,
    ) -> None:
        self.channel = channel
        self._behaviour = behaviour
        self._clock = clock or (lambda: datetime.now(UTC))
        self._sent: dict[str, SentMessage] = {}
        self._by_idempotency_key: dict[str, str] = {}
        self._counter = itertools.count(1)
        self._scripted: dict[str, SendBehaviour] = {}

    # -- test controls -----------------------------------------------------------------

    def script(self, idempotency_key: str, behaviour: SendBehaviour) -> None:
        self._scripted[idempotency_key] = behaviour

    def set_behaviour(self, behaviour: SendBehaviour) -> None:
        self._behaviour = behaviour

    @property
    def sent(self) -> list[SentMessage]:
        return list(self._sent.values())

    def last_sent(self) -> SentMessage:
        if not self._sent:
            raise AssertionError("nothing has been sent on this adapter")
        return list(self._sent.values())[-1]

    def _next(self, prefix: str) -> str:
        return f"{prefix}-{next(self._counter):06d}"

    # -- interface ---------------------------------------------------------------------

    def send_template(
        self,
        *,
        to: PhoneNumber,
        template_key: str,
        locale: str,
        body: str,
        buttons: tuple[str, ...] = (),
        idempotency_key: str,
    ) -> OutboundReceipt:
        return self._send(
            to=to,
            body=body,
            buttons=buttons,
            template_key=template_key,
            locale=locale,
            is_template=True,
            idempotency_key=idempotency_key,
        )

    def send_freeform(
        self,
        *,
        to: PhoneNumber,
        body: str,
        buttons: tuple[str, ...] = (),
        idempotency_key: str,
    ) -> OutboundReceipt:
        return self._send(
            to=to,
            body=body,
            buttons=buttons,
            template_key="",
            locale="",
            is_template=False,
            idempotency_key=idempotency_key,
        )

    def _send(
        self,
        *,
        to: PhoneNumber,
        body: str,
        buttons: tuple[str, ...],
        template_key: str,
        locale: str,
        is_template: bool,
        idempotency_key: str,
    ) -> OutboundReceipt:
        if idempotency_key in self._by_idempotency_key:
            existing = self._sent[self._by_idempotency_key[idempotency_key]]
            return OutboundReceipt(
                provider_message_id=existing.provider_message_id,
                delivery_state=existing.delivery_state,
                accepted_at=existing.sent_at,
            )

        behaviour = self._scripted.get(idempotency_key, self._behaviour)
        if behaviour is SendBehaviour.TRANSIENT_FAILURE:
            raise TransientChannelError(f"{self.name} could not accept the message right now")
        if behaviour is SendBehaviour.PERMANENT_FAILURE:
            raise ChannelError(f"{self.name} cannot reach {to} on {self.channel.value}")

        now = self._clock()
        message_id = self._next("MSG")
        state = DeliveryState.SENT
        message = SentMessage(
            provider_message_id=message_id,
            to=to.e164,
            body=body,
            buttons=tuple(buttons),
            template_key=template_key,
            locale=locale,
            is_template=is_template,
            idempotency_key=idempotency_key,
            sent_at=now,
            delivery_state=state,
            history=[DeliveryState.SENT],
        )
        self._sent[message_id] = message
        self._by_idempotency_key[idempotency_key] = message_id
        return OutboundReceipt(
            provider_message_id=message_id, delivery_state=state, accepted_at=now
        )

    def parse_inbound(self, payload: dict[str, Any]) -> InboundMessage:
        return InboundMessage(
            channel=self.channel,
            provider_message_id=str(payload["id"]),
            from_phone=parse_phone(str(payload["from"])),
            body=str(payload.get("text", "")),
            button_payload=str(payload.get("button", "")),
            occurred_at=payload.get("timestamp") or self._clock(),
            raw=payload,
        )

    # -- simulation --------------------------------------------------------------------

    def deliver(self, provider_message_id: str) -> DeliveryState:
        """Advance a sent message to its next delivery state, as the BSP would report.

        Returns the new state so a test can feed it back through the gateway's
        delivery-receipt handler.
        """
        message = self._sent[provider_message_id]
        behaviour = self._scripted.get(message.idempotency_key, self._behaviour)
        if behaviour is SendBehaviour.ACCEPT_THEN_FAIL:
            message.delivery_state = DeliveryState.FAILED
        elif message.delivery_state is DeliveryState.SENT:
            message.delivery_state = DeliveryState.DELIVERED
        elif message.delivery_state is DeliveryState.DELIVERED:
            message.delivery_state = DeliveryState.READ
        message.history.append(message.delivery_state)
        return message.delivery_state

    def inbound(
        self,
        *,
        from_phone: str,
        text: str = "",
        button: str = "",
        message_id: str | None = None,
        at: datetime | None = None,
    ) -> InboundMessage:
        """Build an inbound message as the BSP would deliver it."""
        return self.parse_inbound(
            {
                "id": message_id or self._next("IN"),
                "from": from_phone,
                "text": text,
                "button": button,
                "timestamp": at or self._clock(),
            }
        )
