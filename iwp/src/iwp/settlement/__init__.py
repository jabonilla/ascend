"""P3 — settlement.

The boundary that keeps the product custody-agnostic while PRD §6 stays undecided.
Import ``iwp.settlement.adapters`` to register the adapters that ship with the project.
"""

from iwp.settlement.provider import (
    Beneficiary,
    Capabilities,
    CapabilityUnsupported,
    CustodyModel,
    FundingSource,
    HoldRef,
    PayoutMethod,
    ProviderError,
    ProviderRejected,
    ProviderTimeout,
    Quote,
    ReversalRef,
    SettlementLatency,
    SettlementProvider,
    SettlementRef,
)
from iwp.settlement.registry import active_provider, get_provider, register_provider

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
    "active_provider",
    "get_provider",
    "register_provider",
]
