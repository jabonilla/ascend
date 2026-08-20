"""Chart of accounts.

The set of account types is small and closed on purpose. Adding one is a finance
decision, not a convenience: every new account type is a new way for a posting recipe
to be subtly wrong.

Custody-agnostic by construction (PRD §6): none of these types names a partner or a
custody model. Under model A the custody account simply carries a zero balance between
funding and settlement; under B and C it carries a real one. No caller branches on it.
"""

from __future__ import annotations

import enum
import uuid
from dataclasses import dataclass
from typing import Final

from sqlalchemy import text
from sqlalchemy.engine import Connection

from iwp.money import Currency
from iwp.money import currency as resolve_currency

__all__ = ["NIL_SCOPE_ID", "AccountRef", "AccountType", "NormalBalance", "ensure_account"]

NIL_SCOPE_ID: Final = uuid.UUID("00000000-0000-0000-0000-000000000000")


class NormalBalance(enum.Enum):
    """Which direction increases an account.

    Assets increase on debit; liabilities and revenue increase on credit.
    """

    DEBIT = "debit"
    CREDIT = "credit"


class ScopeKind(enum.Enum):
    """What an account belongs to."""

    SYSTEM = ""
    USER = "user"
    RELATIONSHIP = "relationship"
    PROVIDER = "provider"


@dataclass(frozen=True, slots=True)
class _TypeSpec:
    normal_balance: NormalBalance
    scope: ScopeKind
    description: str


class AccountType(enum.Enum):
    """The closed set of account types.

    See ``docs/ledger-recipes.md`` for how each is used, and which recipe touches it.
    """

    PARTNER_CUSTODY = "partner_custody"
    """Asset. Funds under the settlement partner's control on our instruction."""

    RECIPIENT_PAYABLE = "recipient_payable"
    """Liability. What we have committed to deliver on a relationship, undelivered."""

    SENDER_BALANCE = "sender_balance"
    """Liability. Stored value held for a sender. Only ever non-zero under custody
    model B; under A and C this account exists and stays at zero."""

    FEE_REVENUE = "fee_revenue"
    """Revenue. Fees recognised at commitment, reversed if the transfer fails."""

    FX_SPREAD_REVENUE = "fx_spread_revenue"
    """Revenue. Margin on the applied rate versus the rate we were quoted."""

    SUSPENSE = "suspense"
    """Asset. Where a reconciliation discrepancy is parked while a human decides.
    Never written automatically — P1.5 forbids auto-resolution."""

    @property
    def _spec(self) -> _TypeSpec:
        return _SPECS[self]

    @property
    def normal_balance(self) -> NormalBalance:
        return self._spec.normal_balance

    @property
    def scope(self) -> ScopeKind:
        return self._spec.scope


_SPECS: Final[dict[AccountType, _TypeSpec]] = {
    AccountType.PARTNER_CUSTODY: _TypeSpec(
        NormalBalance.DEBIT, ScopeKind.PROVIDER, "funds held at the settlement partner"
    ),
    AccountType.RECIPIENT_PAYABLE: _TypeSpec(
        NormalBalance.CREDIT, ScopeKind.RELATIONSHIP, "committed but undelivered"
    ),
    AccountType.SENDER_BALANCE: _TypeSpec(
        NormalBalance.CREDIT, ScopeKind.USER, "stored value held for a sender"
    ),
    AccountType.FEE_REVENUE: _TypeSpec(NormalBalance.CREDIT, ScopeKind.SYSTEM, "fees earned"),
    AccountType.FX_SPREAD_REVENUE: _TypeSpec(
        NormalBalance.CREDIT, ScopeKind.SYSTEM, "margin on the applied rate"
    ),
    AccountType.SUSPENSE: _TypeSpec(
        NormalBalance.DEBIT, ScopeKind.SYSTEM, "unresolved reconciliation discrepancy"
    ),
}


@dataclass(frozen=True, slots=True)
class AccountRef:
    """A resolved account: its id, and the facts a posting needs about it."""

    id: uuid.UUID
    account_type: AccountType
    currency: Currency
    normal_balance: NormalBalance
    scope_id: uuid.UUID


def ensure_account(
    conn: Connection,
    account_type: AccountType,
    currency_code: str | Currency,
    *,
    scope_id: uuid.UUID | None = None,
) -> AccountRef:
    """Return the account for this (type, currency, scope), creating it if absent.

    Idempotent under concurrency: the unique index on (type, currency, scope) means
    two callers racing to create the same account produce one row, and the loser reads
    it back rather than failing.
    """
    cur = resolve_currency(currency_code)
    spec = account_type._spec
    if spec.scope is ScopeKind.SYSTEM:
        if scope_id is not None:
            raise ValueError(f"{account_type.value} is a system account and takes no scope_id")
        effective_scope = NIL_SCOPE_ID
    else:
        if scope_id is None:
            raise ValueError(f"{account_type.value} requires a {spec.scope.value} scope_id")
        effective_scope = scope_id

    params = {
        "account_type": account_type.value,
        "normal_balance": spec.normal_balance.value,
        "currency": cur.code,
        "scope_type": spec.scope.value,
        "scope_id": effective_scope,
        "name": f"{account_type.value}:{cur.code}"
        + (f":{effective_scope}" if spec.scope is not ScopeKind.SYSTEM else ""),
    }

    conn.execute(
        text(
            """
            INSERT INTO account
                (account_type, normal_balance, currency, scope_type, scope_id, name)
            VALUES
                (:account_type, :normal_balance, :currency, :scope_type, :scope_id, :name)
            ON CONFLICT (account_type, currency, scope_type, scope_id) DO NOTHING
            """
        ),
        params,
    )
    account_id = conn.execute(
        text(
            """
            SELECT id FROM account
            WHERE account_type = :account_type
              AND currency = :currency
              AND scope_type = :scope_type
              AND scope_id = :scope_id
            """
        ),
        params,
    ).scalar_one()

    return AccountRef(
        id=account_id,
        account_type=account_type,
        currency=cur,
        normal_balance=spec.normal_balance,
        scope_id=effective_scope,
    )
