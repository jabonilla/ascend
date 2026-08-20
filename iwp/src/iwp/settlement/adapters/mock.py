"""P3.2 — the mock settlement provider.

The build guide says to build this well because we will live in it for months, and it
is what lets Phases 4 and 5 proceed with no signed partner. It is not a stub: it is a
hostile simulation of a real payout network.

It can be configured to behave as any of the three custody models in PRD §6, and to
produce every failure the product has to survive:

    success · delay · failure · partial settlement · reversal · timeout ·
    out-of-order webhooks · duplicate webhooks

Everything is in-process and deterministic. No network, no clock dependency the caller
cannot control, no randomness that a test cannot pin.

MockPay is a fictional partner. The name exists so the guardrail test that greps for
partner names outside this directory has something to catch.
"""

from __future__ import annotations

import enum
import itertools
import uuid
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from decimal import Decimal

from iwp.ledger.reconciliation import ProviderStatementLine
from iwp.money import Money, Rounding
from iwp.settlement.provider import (
    Beneficiary,
    Capabilities,
    CustodyModel,
    FundingSource,
    HoldRef,
    PayoutMethod,
    ProviderRejected,
    ProviderTimeout,
    Quote,
    ReversalRef,
    SettlementLatency,
    SettlementProvider,
    SettlementRef,
)
from iwp.settlement.registry import register_provider
from iwp.states import SettlementState

__all__ = ["MOCKPAY_NAME", "MockProvider", "Outcome", "WebhookEvent", "capabilities_for"]

MOCKPAY_NAME = "mockpay"

# A fixed, obviously-fake rate. Real quoting is the partner's job; what matters here is
# that it is a Decimal, that it is stable across a test run, and that nobody mistakes it
# for a market rate.
MOCK_USD_GTQ_RATE = Decimal("7.75")
_MOCK_FEE_MINOR_UNITS = 199


class Outcome(enum.Enum):
    """What the simulated network does with an instruction."""

    SUCCESS = "success"
    """Settles cleanly."""

    DELAYED = "delayed"
    """Sits in flight until explicitly advanced. The common case for model A."""

    FAILURE = "failure"
    """Fails after being accepted — a bad account number, a rejected payout."""

    PARTIAL = "partial"
    """Delivers part of the amount and stalls. PRD §10 requires the remainder to be
    tracked and surfaced."""

    TIMEOUT = "timeout"
    """The call never returns. The instruction may or may not exist at the provider —
    the hardest case, and the reason reconciliation exists."""

    REJECTED = "rejected"
    """Refused up front, definitively. Nothing was created."""


def capabilities_for(model: CustodyModel) -> Capabilities:
    """Capabilities as each custody model in PRD §6 would present them.

    This function is in the adapter, not in the product. Nothing above this line knows
    that custody models exist.
    """
    if model is CustodyModel.A_FUND_AT_APPROVAL:
        return Capabilities(
            supports_held_balance=False,
            supports_programmable_release=True,
            supports_partial_release=False,
            supports_reversal=False,
            settlement_latency=SettlementLatency.MULTI_DAY,
            payout_methods=frozenset({PayoutMethod.BANK_DEPOSIT, PayoutMethod.CASH_PICKUP}),
        )
    if model is CustodyModel.B_WE_HOLD_BALANCE:
        return Capabilities(
            supports_held_balance=True,
            supports_programmable_release=True,
            supports_partial_release=True,
            supports_reversal=True,
            settlement_latency=SettlementLatency.INSTANT,
            payout_methods=frozenset(PayoutMethod),
        )
    return Capabilities(
        supports_held_balance=True,
        supports_programmable_release=True,
        supports_partial_release=True,
        supports_reversal=False,
        settlement_latency=SettlementLatency.INSTANT,
        payout_methods=frozenset({PayoutMethod.BANK_DEPOSIT, PayoutMethod.CASH_PICKUP}),
    )


@dataclass(frozen=True, slots=True)
class _Hold:
    """A hold, plus who it was placed for. A real provider scopes a hold to a customer;
    the mock keeps the same shape so a test can assert we held against the right one."""

    ref: HoldRef
    user_id: uuid.UUID


@dataclass(frozen=True, slots=True)
class WebhookEvent:
    """What the provider would POST to us.

    ``event_id`` is what makes handling idempotent; ``sequence`` is the provider's own
    ordering, which is what lets a handler resolve out-of-order delivery by state
    rather than by arrival order.

    ``delivered_amount`` is **cumulative**, not incremental: how much has reached the
    recipient as of this event. Cumulative because events arrive out of order and more
    than once, and a running total assembled from increments would be wrong under both.
    """

    event_id: str
    reference: str
    state: SettlementState
    delivered_amount: Money
    occurred_at: datetime
    sequence: int


@dataclass
class _Settlement:
    reference: str
    idempotency_key: str
    #: Where the money was charged from — a hold reference or a funding source. Kept so
    #: a test can assert the lifecycle picked the right one for the custody model.
    source_reference: str
    amount: Money
    beneficiary: Beneficiary
    outcome: Outcome
    created_at: datetime
    state: SettlementState
    delivered: Money
    events: list[WebhookEvent] = field(default_factory=list)


class MockProvider(SettlementProvider):
    """An in-process settlement network that misbehaves on demand."""

    name = MOCKPAY_NAME

    def __init__(
        self,
        *,
        custody_model: CustodyModel = CustodyModel.C_PARTNER_HOLDS,
        default_outcome: Outcome = Outcome.SUCCESS,
        clock: Callable[[], datetime] | None = None,
        deliver_events_reversed: bool = False,
        duplicate_every_event: bool = False,
        quote_ttl: timedelta = timedelta(minutes=15),
    ) -> None:
        self._custody_model = custody_model
        self._capabilities = capabilities_for(custody_model)
        self._default_outcome = default_outcome
        self._clock = clock or (lambda: datetime.now(UTC))
        self._deliver_events_reversed = deliver_events_reversed
        self._duplicate_every_event = duplicate_every_event
        self._quote_ttl = quote_ttl

        self._settlements: dict[str, _Settlement] = {}
        self._by_idempotency_key: dict[str, str] = {}
        self._holds: dict[str, _Hold] = {}
        self._reversals: dict[str, ReversalRef] = {}
        self._quotes: dict[str, Quote] = {}
        self._scripted: dict[str, Outcome] = {}
        self._counter = itertools.count(1)

    # -- test controls -----------------------------------------------------------------

    def hold_holder(self, idempotency_key: str) -> uuid.UUID:
        """Who a hold was placed for. **Tests only.**"""
        return self._holds[idempotency_key].user_id

    def source_used(self, reference: str) -> str:
        """Which funding source or hold a settlement was charged against. **Tests only.**"""
        return self._settlements[reference].source_reference

    def script(self, idempotency_key: str, outcome: Outcome) -> None:
        """Force a specific outcome for the release made under this key."""
        self._scripted[idempotency_key] = outcome

    @property
    def custody_model(self) -> CustodyModel:
        """Which model this instance is simulating. **Tests only.**"""
        return self._custody_model

    def _next(self, prefix: str) -> str:
        return f"{prefix}-{next(self._counter):06d}"

    # -- interface ---------------------------------------------------------------------

    def capabilities(self) -> Capabilities:
        return self._capabilities

    def quote(self, *, amount: Money, to_currency: str, idempotency_key: str) -> Quote:
        if idempotency_key in self._quotes:
            return self._quotes[idempotency_key]

        fee = Money(_MOCK_FEE_MINOR_UNITS, amount.currency)
        recipient_amount = (
            amount.scale(MOCK_USD_GTQ_RATE, Rounding.HALF_UP)
            if to_currency.upper() != amount.currency.code
            else amount
        )
        # scale() keeps the source currency, so restate the result in the target one.
        recipient = Money(recipient_amount.minor_units, to_currency)

        quote = Quote(
            quote_id=self._next("QUO"),
            send_amount=amount,
            fee=fee,
            fx_rate=(
                MOCK_USD_GTQ_RATE if to_currency.upper() != amount.currency.code else Decimal(1)
            ),
            recipient_amount=recipient,
            expires_at=self._clock() + self._quote_ttl,
        )
        self._quotes[idempotency_key] = quote
        return quote

    def _hold(self, *, user_id: uuid.UUID, amount: Money, idempotency_key: str) -> HoldRef:
        if idempotency_key in self._holds:
            return self._holds[idempotency_key].ref
        ref = HoldRef(reference=self._next("HLD"), amount=amount, created_at=self._clock())
        self._holds[idempotency_key] = _Hold(ref=ref, user_id=user_id)
        return ref

    def _release(
        self,
        *,
        source: HoldRef | FundingSource,
        beneficiary: Beneficiary,
        amount: Money,
        quote: Quote,
        idempotency_key: str,
    ) -> SettlementRef:
        if idempotency_key in self._by_idempotency_key:
            existing = self._settlements[self._by_idempotency_key[idempotency_key]]
            return SettlementRef(
                reference=existing.reference,
                state=existing.state,
                created_at=existing.created_at,
            )

        if beneficiary.payout_method not in self._capabilities.payout_methods:
            raise ProviderRejected(
                self.name,
                f"payout method {beneficiary.payout_method.value} is not supported",
                code="unsupported_payout_method",
            )
        if quote.is_expired(self._clock()):
            raise ProviderRejected(self.name, "quote has expired", code="quote_expired")

        outcome = self._scripted.get(idempotency_key, self._default_outcome)

        if outcome is Outcome.REJECTED:
            raise ProviderRejected(self.name, "simulated rejection", code="mock_rejected")

        now = self._clock()
        reference = self._next("STL")
        settlement = _Settlement(
            reference=reference,
            idempotency_key=idempotency_key,
            source_reference=source.reference,
            amount=amount,
            beneficiary=beneficiary,
            outcome=outcome,
            created_at=now,
            state=SettlementState.INSTRUCTED,
            delivered=Money.zero(amount.currency),
        )
        self._settlements[reference] = settlement
        self._by_idempotency_key[idempotency_key] = reference

        if outcome is Outcome.TIMEOUT:
            # The instruction exists at the provider, but the caller never learns its
            # reference. Retrying with the same key returns it; reconciliation finds it
            # otherwise. This asymmetry is the whole point of the case.
            raise ProviderTimeout(f"{self.name} did not respond in time")

        # An instant-settlement provider that is going to succeed does so before the
        # call returns. A multi-day one never does.
        if (
            outcome is Outcome.SUCCESS
            and self._capabilities.settlement_latency is SettlementLatency.INSTANT
        ):
            self._settle(settlement, amount, now)

        return SettlementRef(reference=reference, state=settlement.state, created_at=now)

    def status(self, reference: str) -> SettlementState:
        settlement = self._settlements.get(reference)
        if settlement is None:
            raise ProviderRejected(self.name, f"unknown settlement {reference}", code="not_found")
        return settlement.state

    def _reverse(self, reference: str, *, idempotency_key: str) -> ReversalRef:
        if idempotency_key in self._reversals:
            return self._reversals[idempotency_key]
        settlement = self._settlements.get(reference)
        if settlement is None:
            raise ProviderRejected(self.name, f"unknown settlement {reference}", code="not_found")
        if settlement.state is not SettlementState.SETTLED:
            raise ProviderRejected(
                self.name,
                f"cannot reverse a settlement in state {settlement.state.value}",
                code="not_reversible",
            )

        now = self._clock()
        settlement.state = SettlementState.REVERSED
        # Nothing is delivered after a reversal: the money came back.
        settlement.events.append(
            WebhookEvent(
                event_id=self._next("EVT"),
                reference=reference,
                state=SettlementState.REVERSED,
                delivered_amount=Money.zero(settlement.amount.currency),
                occurred_at=now,
                sequence=len(settlement.events) + 1,
            )
        )
        ref = ReversalRef(
            reference=self._next("REV"), settlement_reference=reference, created_at=now
        )
        self._reversals[idempotency_key] = ref
        return ref

    def statement(
        self, *, period_start: datetime, period_end: datetime
    ) -> list[ProviderStatementLine]:
        """The provider's own record, shaped for reconciliation (P1.5).

        Reports ``delivered`` rather than the instructed amount, because that is what
        the provider actually knows: a partially delivered transfer shows the part that
        landed, which is exactly the amount mismatch reconciliation should surface.
        """
        lines: list[ProviderStatementLine] = []
        for settlement in self._settlements.values():
            if not (period_start <= settlement.created_at < period_end):
                continue
            reported = (
                settlement.delivered if settlement.delivered.is_positive else settlement.amount
            )
            lines.append(
                ProviderStatementLine(
                    provider_reference=settlement.reference,
                    external_reference=settlement.idempotency_key,
                    amount=reported,
                    state=settlement.state,
                    value_date=settlement.created_at,
                )
            )
        return lines

    # -- simulation --------------------------------------------------------------------

    def advance(self, reference: str, *, now: datetime | None = None) -> None:
        """Run the scripted outcome for a settlement that is still in flight.

        Separate from ``release`` so a test can decide *when* the network gets around
        to it, which is what makes delay and out-of-order delivery testable.
        """
        settlement = self._settlements.get(reference)
        if settlement is None:
            raise ProviderRejected(self.name, f"unknown settlement {reference}", code="not_found")
        if settlement.state.is_terminal:
            return

        moment = now or self._clock()

        zero = Money.zero(settlement.amount.currency)
        if settlement.outcome in (Outcome.SUCCESS, Outcome.DELAYED, Outcome.TIMEOUT):
            self._emit(settlement, SettlementState.IN_FLIGHT, zero, moment)
            self._settle(settlement, settlement.amount, moment)
        elif settlement.outcome is Outcome.FAILURE:
            self._emit(settlement, SettlementState.IN_FLIGHT, zero, moment)
            settlement.state = SettlementState.FAILED
            self._emit(settlement, SettlementState.FAILED, zero, moment)
        elif settlement.outcome is Outcome.PARTIAL:
            part = settlement.amount.allocate([1, 1])[0]
            settlement.delivered = part
            # Still in flight: the remainder has not been delivered, and partial
            # settlement is an amount fact rather than a state (see iwp/states.py).
            settlement.state = SettlementState.IN_FLIGHT
            self._emit(settlement, SettlementState.IN_FLIGHT, part, moment)

    def _settle(self, settlement: _Settlement, amount: Money, now: datetime) -> None:
        settlement.delivered = amount
        settlement.state = SettlementState.SETTLED
        self._emit(settlement, SettlementState.SETTLED, amount, now)

    def _emit(
        self,
        settlement: _Settlement,
        state: SettlementState,
        delivered: Money,
        now: datetime,
    ) -> None:
        settlement.events.append(
            WebhookEvent(
                event_id=self._next("EVT"),
                reference=settlement.reference,
                state=state,
                delivered_amount=delivered,
                occurred_at=now,
                sequence=len(settlement.events) + 1,
            )
        )

    def pending_webhooks(self, reference: str) -> list[WebhookEvent]:
        """Events the provider would deliver, in the order it would deliver them.

        Reversed and/or duplicated according to how this instance was configured, so a
        handler can be tested against at-least-once, out-of-order delivery — which is
        what the real thing does (PRD Feature 4 edge cases).
        """
        settlement = self._settlements.get(reference)
        if settlement is None:
            raise ProviderRejected(self.name, f"unknown settlement {reference}", code="not_found")

        events = list(settlement.events)
        if self._deliver_events_reversed:
            events.reverse()
        if self._duplicate_every_event:
            events = [event for event in events for _ in range(2)]
        return events


register_provider(MOCKPAY_NAME, MockProvider)
