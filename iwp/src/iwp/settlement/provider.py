"""P3.1 — the SettlementProvider boundary.

This is the interface that keeps the product custody-agnostic (PRD §6). The custody
model — A fund-at-approval, B we hold the balance, C the partner holds in the sender's
name — is still an open decision, and the whole point of this file is that the decision
can land late without rewriting the product.

Three rules hold everything up:

1. **No caller branches on which provider is in use.** Not on its name, not on its
   class. A guardrail test greps for provider brand names outside
   ``settlement/adapters/`` and fails the build if it finds one.
2. **Capability flags gate behaviour, and the gate lives here.** ``release`` and friends
   are concrete methods on the base class that check the flag and then dispatch to an
   adapter's ``_release``. An adapter author cannot forget to gate, and an unsupported
   operation raises :class:`CapabilityUnsupported` rather than failing silently or,
   worse, half-working.
3. **Every call is idempotent by an externally supplied key.** Providers are reached
   over networks that lose responses, not requests.
"""

from __future__ import annotations

import enum
import uuid
from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal

from iwp.ledger.reconciliation import ProviderStatementLine
from iwp.money import Money
from iwp.states import SettlementState

__all__ = [
    "Beneficiary",
    "Capabilities",
    "CapabilityUnsupported",
    "CustodyModel",
    "FundingSource",
    "HoldRef",
    "PayoutMethod",
    "ProviderError",
    "ProviderRejected",
    "ProviderTimeout",
    "Quote",
    "ReversalRef",
    "SettlementLatency",
    "SettlementProvider",
    "SettlementRef",
]


class ProviderError(Exception):
    """Base class for everything a settlement provider can raise."""


class CapabilityUnsupported(ProviderError):
    """The provider does not support this operation.

    Typed, and raised before any side effect. A caller that meets this has asked for
    something the signed partner cannot do, and the product needs a different path —
    not a retry.
    """

    def __init__(self, provider: str, capability: str) -> None:
        super().__init__(f"{provider} does not support {capability}")
        self.provider = provider
        self.capability = capability


class ProviderTimeout(ProviderError):
    """The call did not come back in time.

    **The instruction may or may not have been created.** This is the most dangerous
    error in the file: retrying with the same idempotency key is safe, assuming failure
    is not. Anything unresolved is left for reconciliation to find (P1.5).
    """


class ProviderRejected(ProviderError):
    """The provider refused the instruction, definitively and with a reason."""

    def __init__(self, provider: str, reason: str, *, code: str = "") -> None:
        super().__init__(f"{provider} rejected the instruction: {reason}")
        self.provider = provider
        self.reason = reason
        self.code = code


class SettlementLatency(enum.Enum):
    """PRD §6."""

    INSTANT = "instant"
    SAME_DAY = "same_day"
    MULTI_DAY = "multi_day"


class PayoutMethod(enum.Enum):
    """PRD §6. The recipient is often unbanked (PRD §2), so cash pickup is not
    a fallback — for many pairs it is the only method that works."""

    BANK_DEPOSIT = "bank_deposit"
    CASH_PICKUP = "cash_pickup"
    MOBILE_WALLET = "mobile_wallet"


class CustodyModel(enum.Enum):
    """PRD §6 — the open decision this interface exists to survive.

    Named here so a *test* can say which model it is exercising. No production code
    path may branch on this value; that is what the capability flags are for.
    """

    A_FUND_AT_APPROVAL = "a_fund_at_approval"
    B_WE_HOLD_BALANCE = "b_we_hold_balance"
    C_PARTNER_HOLDS = "c_partner_holds"


@dataclass(frozen=True, slots=True)
class Capabilities:
    """What a provider can actually do, per PRD §6."""

    supports_held_balance: bool
    supports_programmable_release: bool
    supports_partial_release: bool
    supports_reversal: bool
    settlement_latency: SettlementLatency
    payout_methods: frozenset[PayoutMethod]

    def __post_init__(self) -> None:
        # PRD §6 marks programmable release as the GATE: without it there is no
        # product, only a remittance app. A provider that lacks it must not be
        # constructible in a state where a caller could discover that at runtime.
        if not self.supports_programmable_release:
            raise ValueError(
                "supports_programmable_release is the gating capability (PRD §6). "
                "A provider without it cannot back this product."
            )
        if not self.payout_methods:
            raise ValueError("a provider must support at least one payout method")


@dataclass(frozen=True, slots=True)
class Quote:
    """A priced transfer, valid until it expires.

    Everything the sender must be shown before committing (PRD Feature 7): what they
    send, every fee, the rate applied, what the recipient gets.
    """

    quote_id: str
    send_amount: Money
    fee: Money
    fx_rate: Decimal
    recipient_amount: Money
    expires_at: datetime

    def __post_init__(self) -> None:
        # mypy knows Decimal and float are disjoint, so it reads this as unreachable.
        # It is not: values reaching here from JSON, a provider SDK, or an untyped
        # caller are checked at runtime, and CLAUDE.md rule 1 is worth a redundant
        # guard.
        if isinstance(self.fx_rate, float):  # type: ignore[unreachable]
            raise TypeError("fx_rate must be a Decimal, never a float (CLAUDE.md rule 1)")
        if self.fx_rate <= 0:
            raise ValueError("fx_rate must be positive")
        if self.send_amount.currency is not self.fee.currency:
            raise ValueError("fee must be in the same currency as the send amount")

    @property
    def total_charged(self) -> Money:
        """What leaves the sender: principal plus fees."""
        return self.send_amount + self.fee

    def is_expired(self, now: datetime) -> bool:
        return now >= self.expires_at


@dataclass(frozen=True, slots=True)
class FundingSource:
    """Where the money comes from when there is no held balance (custody model A)."""

    reference: str
    user_id: uuid.UUID


@dataclass(frozen=True, slots=True)
class HoldRef:
    """Funds reserved at the provider (models B and C)."""

    reference: str
    amount: Money
    created_at: datetime


@dataclass(frozen=True, slots=True)
class Beneficiary:
    """Who is being paid, and how."""

    relationship_id: uuid.UUID
    name: str
    payout_method: PayoutMethod
    account_reference: str
    """Bank account, wallet id, or the pickup identifier. Opaque to us."""


@dataclass(frozen=True, slots=True)
class SettlementRef:
    reference: str
    state: SettlementState
    created_at: datetime


@dataclass(frozen=True, slots=True)
class ReversalRef:
    reference: str
    settlement_reference: str
    created_at: datetime


class SettlementProvider(ABC):
    """Base class for every settlement adapter.

    The public methods are concrete and final in spirit: they enforce the capability
    gate and then dispatch to the ``_``-prefixed method an adapter implements. That
    arrangement is deliberate — if gating were left to each adapter, the first adapter
    written under deadline would skip it.
    """

    #: Adapter identity. Used for logging, reconciliation runs and the account scope —
    #: never for a business decision.
    name: str = "unnamed"

    @abstractmethod
    def capabilities(self) -> Capabilities:
        """What this provider can do."""

    # -- quoting -----------------------------------------------------------------------

    @abstractmethod
    def quote(
        self,
        *,
        amount: Money,
        to_currency: str,
        idempotency_key: str,
    ) -> Quote:
        """Price a transfer. Required of every provider — a quote is what makes the
        pre-commitment disclosure possible, and PRD Feature 7 makes that mandatory."""

    # -- holding -----------------------------------------------------------------------

    def hold(self, *, user_id: uuid.UUID, amount: Money, idempotency_key: str) -> HoldRef:
        """Reserve funds. Only where ``supports_held_balance``."""
        self._require("held balance", self.capabilities().supports_held_balance)
        return self._hold(user_id=user_id, amount=amount, idempotency_key=idempotency_key)

    def _hold(self, *, user_id: uuid.UUID, amount: Money, idempotency_key: str) -> HoldRef:
        """Only reached when the adapter declared ``supports_held_balance`` and then
        did not implement this. That is an adapter bug, not an unsupported capability,
        so it is a NotImplementedError rather than a CapabilityUnsupported: the two
        mean different things and want different fixes."""
        raise NotImplementedError

    # -- releasing ---------------------------------------------------------------------

    def release(
        self,
        *,
        source: HoldRef | FundingSource,
        beneficiary: Beneficiary,
        amount: Money,
        quote: Quote,
        idempotency_key: str,
    ) -> SettlementRef:
        """Instruct a payout. The one operation every provider must support."""
        self._require("programmable release", self.capabilities().supports_programmable_release)
        return self._release(
            source=source,
            beneficiary=beneficiary,
            amount=amount,
            quote=quote,
            idempotency_key=idempotency_key,
        )

    @abstractmethod
    def _release(
        self,
        *,
        source: HoldRef | FundingSource,
        beneficiary: Beneficiary,
        amount: Money,
        quote: Quote,
        idempotency_key: str,
    ) -> SettlementRef:
        """Adapter implementation of :meth:`release`."""

    # -- status ------------------------------------------------------------------------

    @abstractmethod
    def status(self, reference: str) -> SettlementState:
        """Where a settlement stands, according to the provider.

        The provider is authoritative for settlement (P1.5). This is that authority.
        """

    # -- reversing ---------------------------------------------------------------------

    def reverse(self, reference: str, *, idempotency_key: str) -> ReversalRef:
        """Pull a settlement back. Only where ``supports_reversal``."""
        self._require("reversal", self.capabilities().supports_reversal)
        return self._reverse(reference, idempotency_key=idempotency_key)

    def _reverse(self, reference: str, *, idempotency_key: str) -> ReversalRef:
        """Only reached when the adapter declared ``supports_reversal`` and then did
        not implement this. See :meth:`_hold` for why this is not
        ``CapabilityUnsupported``."""
        raise NotImplementedError

    # -- statements --------------------------------------------------------------------

    @abstractmethod
    def statement(
        self, *, period_start: datetime, period_end: datetime
    ) -> list[ProviderStatementLine]:
        """The provider's own record for a period, for reconciliation (P1.5)."""

    # -- gate --------------------------------------------------------------------------

    def _require(self, capability: str, supported: bool) -> None:
        if not supported:
            raise CapabilityUnsupported(self.name, capability)
