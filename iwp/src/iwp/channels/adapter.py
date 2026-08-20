"""P4.1 — the channel adapter interface.

Product logic is channel-agnostic; the gateway translates. Nothing above this line
knows which Business Solution Provider carries our WhatsApp traffic, and a guardrail
test greps for BSP brand names outside ``channels/adapters/`` to keep it that way
(CLAUDE.md rule 7 — PRD §12 says to expect to change providers).

An adapter does three things and nothing else:

* ``send_template``  — an approved template, sendable outside a session window
* ``send_freeform``  — arbitrary text, only inside one
* ``parse_inbound``  — a provider webhook body into a normalised ``InboundMessage``

Everything else — session windows, conversation state, fallback, the audit trail — is
gateway logic and lives above the adapter, because it must behave identically no matter
who is carrying the messages.
"""

from __future__ import annotations

import enum
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any

from iwp.domain.phone import PhoneNumber

__all__ = [
    "Channel",
    "ChannelAdapter",
    "ChannelError",
    "DeliveryState",
    "InboundMessage",
    "OutboundReceipt",
    "TemplateNotApproved",
    "TransientChannelError",
]


class ChannelError(Exception):
    """Base class for channel failures."""


class TransientChannelError(ChannelError):
    """The send failed in a way that may succeed on another channel or a retry.

    Distinct from a permanent failure because P4.4's fallback rule turns on it: a
    transient WhatsApp failure means try SMS, a permanent one usually means the number
    is wrong and SMS will fail too.
    """


class TemplateNotApproved(ChannelError):
    """A template that the BSP has not approved cannot be sent outside a session."""


class Channel(enum.Enum):
    """Where a message travels. ``APP`` is the sender's own client."""

    APP = "app"
    WHATSAPP = "whatsapp"
    SMS = "sms"
    PUSH = "push"

    @property
    def supports_buttons(self) -> bool:
        """PRD Feature 4: SMS has full functional parity, minus inline buttons."""
        return self in (Channel.WHATSAPP, Channel.APP)

    @property
    def has_session_window(self) -> bool:
        """Only WhatsApp has the 24-hour rule."""
        return self is Channel.WHATSAPP


class DeliveryState(enum.Enum):
    """PRD §9 Notification.delivery_state."""

    QUEUED = "queued"
    SENT = "sent"
    DELIVERED = "delivered"
    READ = "read"
    FAILED = "failed"

    @property
    def is_terminal(self) -> bool:
        return self in (DeliveryState.READ, DeliveryState.FAILED)


@dataclass(frozen=True, slots=True)
class OutboundReceipt:
    """What the provider said when we handed it a message."""

    provider_message_id: str
    delivery_state: DeliveryState
    accepted_at: datetime


@dataclass(frozen=True, slots=True)
class InboundMessage:
    """A message from a person, normalised.

    ``button_payload`` is set when the user tapped an inline button rather than typing.
    Both are carried because the same product action arrives either way depending on
    channel, and the conversation layer must not care which.
    """

    channel: Channel
    provider_message_id: str
    from_phone: PhoneNumber
    body: str
    occurred_at: datetime
    button_payload: str = ""
    raw: dict[str, Any] = field(default_factory=dict)


class ChannelAdapter(ABC):
    """Base class for every channel adapter."""

    #: Which channel this adapter carries.
    channel: Channel

    #: Adapter identity, for logging and the delivery audit. Never a business decision.
    name: str = "unnamed"

    @abstractmethod
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
        """Send an approved template. Valid inside or outside a session window."""

    @abstractmethod
    def send_freeform(
        self,
        *,
        to: PhoneNumber,
        body: str,
        buttons: tuple[str, ...] = (),
        idempotency_key: str,
    ) -> OutboundReceipt:
        """Send arbitrary text. Only valid inside an open session window.

        The window is enforced by the gateway, not here: an adapter that checked it
        would be a second place for the rule to live, and the two would drift.
        """

    @abstractmethod
    def parse_inbound(self, payload: dict[str, Any]) -> InboundMessage:
        """Normalise a provider webhook body."""
