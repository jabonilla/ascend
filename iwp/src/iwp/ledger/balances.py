"""P1.4 — balances derived from entries.

There is no balance column anywhere in the schema. A balance is a ``SUM`` over
``ledger_entry`` and nothing else, so it cannot drift from the entries that produced
it. If a cache is ever added it must be reconstructible, and a test must compare it
against this derivation.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import text
from sqlalchemy.engine import Connection

from iwp.money import Money

__all__ = ["account_balance", "account_balance_history", "trial_balance"]

# For a debit-normal account the balance is debits - credits; for a credit-normal
# account it is credits - debits. Doing the sign flip in SQL keeps the whole
# computation one aggregate, which is what makes it safe to call inside a posting.
_BALANCE_SQL = """
SELECT
    a.currency AS currency,
    COALESCE(SUM(
        CASE
            WHEN e.direction = a.normal_balance THEN e.amount
            ELSE -e.amount
        END
    ), 0) AS balance
FROM account a
LEFT JOIN ledger_entry e
       ON e.account_id = a.id
      {as_of_clause}
WHERE a.id = :account_id
GROUP BY a.currency
"""


def account_balance(
    conn: Connection,
    account_id: uuid.UUID,
    *,
    as_of: datetime | None = None,
) -> Money:
    """The balance of one account, optionally as it stood at ``as_of``.

    Point-in-time derivation is possible because entries are never mutated: the state
    at any past instant is just the entries created up to it.
    """
    sql = _BALANCE_SQL.format(
        as_of_clause="AND e.created_at <= :as_of" if as_of is not None else ""
    )
    params: dict[str, object] = {"account_id": account_id}
    if as_of is not None:
        params["as_of"] = as_of
    row = conn.execute(text(sql), params).one_or_none()
    if row is None:
        raise LookupError(f"no such account: {account_id}")
    return Money(int(row.balance), row.currency)


def account_balance_history(
    conn: Connection, account_id: uuid.UUID
) -> list[tuple[datetime, Money]]:
    """Running balance after each entry, oldest first. For statements and audit."""
    rows = conn.execute(
        text(
            """
            SELECT
                e.created_at AS at,
                a.currency   AS currency,
                SUM(CASE WHEN e.direction = a.normal_balance THEN e.amount ELSE -e.amount END)
                    OVER (ORDER BY e.created_at, e.id) AS running
            FROM ledger_entry e
            JOIN account a ON a.id = e.account_id
            WHERE e.account_id = :account_id
            ORDER BY e.created_at, e.id
            """
        ),
        {"account_id": account_id},
    ).all()
    return [(row.at, Money(int(row.running), row.currency)) for row in rows]


def trial_balance(conn: Connection, *, as_of: datetime | None = None) -> dict[str, Money]:
    """Net of every debit against every credit, per currency.

    Every value must be zero. A non-zero entry means an unbalanced posting reached the
    database, which the posting function is built to make impossible — so this is the
    assertion that proves it, and it is what the P1.3 property test checks.
    """
    clause = "WHERE created_at <= :as_of" if as_of is not None else ""
    params: dict[str, object] = {}
    if as_of is not None:
        params["as_of"] = as_of
    rows = conn.execute(
        text(
            f"""
            SELECT currency,
                   COALESCE(SUM(CASE WHEN direction = 'debit' THEN amount ELSE -amount END), 0)
                       AS net
            FROM ledger_entry
            {clause}
            GROUP BY currency
            """
        ),
        params,
    ).all()
    return {row.currency: Money(int(row.net), row.currency) for row in rows}
