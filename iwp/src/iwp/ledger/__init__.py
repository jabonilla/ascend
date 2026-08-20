"""P1.3-P1.5 — the ledger.

``posting.post`` is the only function in the codebase permitted to INSERT into
``ledger_entry``. ``tests/test_guardrails.py`` enforces that.

``reconciliation`` deliberately has no import path to ``posting``: a discrepancy is
recorded and resolved by a person, never corrected automatically (P1.5).
"""

from iwp.ledger.accounts import AccountRef, AccountType, NormalBalance, ensure_account
from iwp.ledger.balances import account_balance, account_balance_history, trial_balance
from iwp.ledger.posting import (
    BalanceGuard,
    Direction,
    EntryRequest,
    IdempotencyKeyReuse,
    InsufficientBalance,
    LedgerError,
    PostingRequest,
    PostingResult,
    UnbalancedPosting,
    credit,
    debit,
    post,
)
from iwp.ledger.reconciliation import (
    Discrepancy,
    DiscrepancyKind,
    ExpectedSettlement,
    ProviderStatementLine,
    ReconciliationInput,
    ReconciliationResult,
    open_discrepancies,
    reconcile,
    record_resolution,
    resolution_status,
)

__all__ = [
    "AccountRef",
    "AccountType",
    "BalanceGuard",
    "Direction",
    "Discrepancy",
    "DiscrepancyKind",
    "EntryRequest",
    "ExpectedSettlement",
    "IdempotencyKeyReuse",
    "InsufficientBalance",
    "LedgerError",
    "NormalBalance",
    "PostingRequest",
    "PostingResult",
    "ProviderStatementLine",
    "ReconciliationInput",
    "ReconciliationResult",
    "UnbalancedPosting",
    "account_balance",
    "account_balance_history",
    "credit",
    "debit",
    "ensure_account",
    "open_discrepancies",
    "post",
    "reconcile",
    "record_resolution",
    "resolution_status",
    "trial_balance",
]
