"""State vocabularies shared across layers.

CLAUDE.md rule 4: intent state and settlement state are separate fields and must never
be collapsed into one status enum. They answer different questions, they are owned by
different parties, and reconciliation is only possible while they are distinct:

    intent      — what the two people agreed to. **Our ledger is authoritative.**
    settlement  — what actually happened to the money. **The provider is authoritative.**

A transfer can be `committed` in intent and `failed` in settlement. That pair is not a
contradiction to be tidied away; it is the exact situation the product has to show
honestly (PRD §10, "funds are never silently lost").
"""

from __future__ import annotations

import enum

__all__ = ["IntentState", "RelationshipStatus", "RequestStatus", "SettlementState"]


class IntentState(enum.Enum):
    """What the parties agreed. PRD §9 Transaction.intent_state."""

    COMMITTED = "committed"
    CANCELLED = "cancelled"


class SettlementState(enum.Enum):
    """What the money did. PRD §9 Transaction.settlement_state.

    Partial settlement is deliberately *not* a member. PRD §10 says a partial payout is
    "recorded as partial settlement. Remainder tracked and surfaced" — which is an
    amount fact, not a new state. A transfer that has delivered some of its value is
    still ``in_flight``, with ``settled_amount`` below the instructed amount. Adding a
    seventh state here would be inventing a business rule the PRD does not specify, and
    would make every state comparison in reconciliation ambiguous.
    """

    NOT_STARTED = "not_started"
    INSTRUCTED = "instructed"
    IN_FLIGHT = "in_flight"
    SETTLED = "settled"
    FAILED = "failed"
    REVERSED = "reversed"

    @property
    def is_terminal(self) -> bool:
        return self in _TERMINAL_SETTLEMENT_STATES


_TERMINAL_SETTLEMENT_STATES = frozenset(
    {SettlementState.SETTLED, SettlementState.FAILED, SettlementState.REVERSED}
)


class RequestStatus(enum.Enum):
    """PRD §9 Request.status."""

    PENDING = "pending"
    APPROVED = "approved"
    DECLINED = "declined"
    EXPIRED = "expired"

    @property
    def is_resolved(self) -> bool:
        return self is not RequestStatus.PENDING


class RelationshipStatus(enum.Enum):
    """PRD §9 Relationship.status."""

    INVITED = "invited"
    ACTIVE = "active"
    PAUSED = "paused"
    TERMINATED = "terminated"
