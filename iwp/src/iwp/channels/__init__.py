"""P4 — the channel gateway.

WhatsApp and SMS are full transaction surfaces, not notification pipes (PRD Feature 4).
The recipient side of this product exists only here.

Import ``iwp.channels.adapters`` to register the adapters that ship with the project.
"""

from iwp.channels.adapter import (
    Channel,
    ChannelAdapter,
    ChannelError,
    DeliveryState,
    InboundMessage,
    OutboundReceipt,
    TransientChannelError,
)
from iwp.channels.conversations import InboundOutcome, handle_inbound
from iwp.channels.gateway import ChannelGateway, Dispatch, DispatchResult, delivery_audit
from iwp.channels.session import (
    Deliverability,
    SessionWindow,
    SessionWindowClosed,
    classify_delivery,
    note_inbound,
    window_for,
)

__all__ = [
    "Channel",
    "ChannelAdapter",
    "ChannelError",
    "ChannelGateway",
    "Deliverability",
    "DeliveryState",
    "Dispatch",
    "DispatchResult",
    "InboundMessage",
    "InboundOutcome",
    "OutboundReceipt",
    "SessionWindow",
    "SessionWindowClosed",
    "TransientChannelError",
    "classify_delivery",
    "delivery_audit",
    "handle_inbound",
    "note_inbound",
    "window_for",
]
