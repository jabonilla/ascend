"""Provider selection.

P6.1's verification is "switch a config value from mock to real; nothing else changes".
This module is that config value. Adapters register themselves by name; the rest of the
codebase asks for *the* provider and never names one.
"""

from __future__ import annotations

import os
from collections.abc import Callable

from iwp.settlement.provider import SettlementProvider

__all__ = ["ProviderNotRegistered", "active_provider", "get_provider", "register_provider"]

_FACTORIES: dict[str, Callable[[], SettlementProvider]] = {}


class ProviderNotRegistered(KeyError):
    """No adapter is registered under that name."""


def register_provider(name: str, factory: Callable[[], SettlementProvider]) -> None:
    """Register an adapter factory. Called from the adapter module itself."""
    _FACTORIES[name] = factory


def get_provider(name: str) -> SettlementProvider:
    try:
        factory = _FACTORIES[name]
    except KeyError:
        raise ProviderNotRegistered(
            f"no settlement adapter registered as {name!r}; registered: {sorted(_FACTORIES)}"
        ) from None
    return factory()


def active_provider() -> SettlementProvider:
    """The provider this deployment uses.

    One environment variable. Changing partner is this line and an adapter — nothing
    in the product above it.
    """
    return get_provider(os.environ.get("IWP_SETTLEMENT_PROVIDER", "mock"))
