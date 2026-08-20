"""P1.3 — the posting function.

This is the only place in the codebase that INSERTs into ``ledger_entry``. Everything
about it is arranged so that a wrong posting fails loudly rather than half-succeeding:

* the balance check runs before any write, and the whole posting is one database
  transaction, so an unbalanced posting writes nothing;
* debits and credits are compared **per currency**, never in aggregate — balancing a
  USD leg against a GTQ leg would silently assume a rate of 1;
* idempotency is the database's UNIQUE constraint on ``idempotency_key``, not a
  read-then-write check in application code, so concurrent replays cannot both win;
* replaying a key with a *different* payload raises rather than returning the original
  result, because that is a caller bug and hiding it loses money quietly;
* postings run at SERIALIZABLE, and serialization failures are retried here rather
  than surfacing to callers who would have to know to retry.
"""

from __future__ import annotations

import enum
import hashlib
import json
import random
import time
import uuid
from collections.abc import Sequence
from dataclasses import dataclass, field

from sqlalchemy import Engine, text
from sqlalchemy.engine import Connection
from sqlalchemy.exc import DBAPIError, IntegrityError

from iwp.ledger.accounts import AccountRef
from iwp.money import Money

__all__ = [
    "BalanceGuard",
    "Direction",
    "EntryRequest",
    "IdempotencyKeyReuse",
    "InsufficientBalance",
    "LedgerError",
    "PostingRequest",
    "PostingResult",
    "UnbalancedPosting",
    "credit",
    "debit",
    "post",
]

# PostgreSQL SQLSTATEs worth retrying: serialization_failure and deadlock_detected.
_RETRYABLE_SQLSTATES = frozenset({"40001", "40P01"})
_UNIQUE_VIOLATION = "23505"
_MAX_ATTEMPTS = 8


class LedgerError(Exception):
    """Base class for ledger errors."""


class UnbalancedPosting(LedgerError):
    """Debits did not equal credits. Nothing was written."""


class IdempotencyKeyReuse(LedgerError):
    """An idempotency key was replayed with a different payload."""


class InsufficientBalance(LedgerError):
    """A balance guard would have been violated. Nothing was written."""


class Direction(enum.Enum):
    DEBIT = "debit"
    CREDIT = "credit"


@dataclass(frozen=True, slots=True)
class EntryRequest:
    """One side of a posting."""

    account: AccountRef
    direction: Direction
    amount: Money
    entry_type: str

    def __post_init__(self) -> None:
        if not self.amount.is_positive:
            raise ValueError(
                f"entry amount must be positive (the sign lives in `direction`), got {self.amount}"
            )
        if self.amount.currency is not self.account.currency:
            raise ValueError(
                f"entry currency {self.amount.currency.code} does not match account "
                f"currency {self.account.currency.code}"
            )
        if not self.entry_type:
            raise ValueError("entry_type is required")


def debit(account: AccountRef, amount: Money, entry_type: str) -> EntryRequest:
    return EntryRequest(account, Direction.DEBIT, amount, entry_type)


def credit(account: AccountRef, amount: Money, entry_type: str) -> EntryRequest:
    return EntryRequest(account, Direction.CREDIT, amount, entry_type)


# (account id, minimum resulting balance). The posting is rejected if it would take the
# account's balance below the minimum.
BalanceGuard = tuple[uuid.UUID, Money]


@dataclass(frozen=True, slots=True)
class PostingRequest:
    idempotency_key: str
    posting_type: str
    entries: tuple[EntryRequest, ...]
    business_txn_id: uuid.UUID | None = None
    description: str = ""

    def __post_init__(self) -> None:
        if not self.idempotency_key:
            raise ValueError("idempotency_key is required")
        if not self.posting_type:
            raise ValueError("posting_type is required")

    def fingerprint(self) -> str:
        """A stable hash of what this posting does.

        Entry order is not part of the identity — the same postings listed in a
        different order are the same posting — so the entries are sorted first.
        """
        payload = {
            "posting_type": self.posting_type,
            "business_txn_id": str(self.business_txn_id) if self.business_txn_id else None,
            "entries": sorted(
                [
                    str(e.account.id),
                    e.direction.value,
                    str(e.amount.minor_units),
                    e.amount.currency.code,
                    e.entry_type,
                ]
                for e in self.entries
            ),
        }
        return hashlib.sha256(
            json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
        ).hexdigest()


@dataclass(frozen=True, slots=True)
class PostingResult:
    transaction_id: uuid.UUID
    entry_ids: tuple[uuid.UUID, ...]
    replayed: bool = field(default=False)


def _assert_balanced(request: PostingRequest) -> None:
    """Debits must equal credits, per currency. CLAUDE.md rule 3."""
    if len(request.entries) < 2:
        raise UnbalancedPosting(f"a posting needs at least two entries, got {len(request.entries)}")

    net: dict[str, int] = {}
    for entry in request.entries:
        code = entry.amount.currency.code
        signed = entry.amount.minor_units
        net[code] = net.get(code, 0) + (signed if entry.direction is Direction.DEBIT else -signed)

    unbalanced = {code: delta for code, delta in net.items() if delta != 0}
    if unbalanced:
        detail = ", ".join(
            f"{code}: debits exceed credits by {delta}"
            if delta > 0
            else f"{code}: credits exceed debits by {-delta}"
            for code, delta in sorted(unbalanced.items())
        )
        raise UnbalancedPosting(f"posting does not balance ({detail})")


def _sqlstate(exc: DBAPIError) -> str | None:
    return getattr(getattr(exc, "orig", None), "sqlstate", None)


def _is_retryable(exc: DBAPIError) -> bool:
    return _sqlstate(exc) in _RETRYABLE_SQLSTATES


def _is_idempotency_key_conflict(exc: IntegrityError) -> bool:
    """True when this is another poster having won the race for our idempotency key.

    Narrowed to the specific constraint: any other unique violation is a real error
    and must not be swallowed by the retry loop.
    """
    if _sqlstate(exc) != _UNIQUE_VIOLATION:
        return False
    diag = getattr(getattr(exc, "orig", None), "diag", None)
    constraint = getattr(diag, "constraint_name", None) or ""
    return "idempotency_key" in constraint


def post(
    engine: Engine,
    request: PostingRequest,
    *,
    guards: Sequence[BalanceGuard] = (),
) -> PostingResult:
    """Write a balanced set of ledger entries atomically and idempotently.

    Returns the original result — with ``replayed=True`` — if this idempotency key has
    already been used for an identical posting.
    """
    _assert_balanced(request)
    fingerprint = request.fingerprint()

    last_error: DBAPIError | None = None
    for attempt in range(_MAX_ATTEMPTS):
        try:
            with (
                engine.connect().execution_options(isolation_level="SERIALIZABLE") as conn,
                conn.begin(),
            ):
                return _post_once(conn, request, fingerprint, guards)
        except IntegrityError as exc:
            if not _is_idempotency_key_conflict(exc):
                raise
            # Another caller committed this key between our existence check and our
            # insert. Re-entering takes the replay path, which is also where the
            # fingerprint gets compared — so a racing *different* posting still raises.
            last_error = exc
            continue
        except DBAPIError as exc:
            if not _is_retryable(exc):
                raise
            last_error = exc
            # Full jitter: concurrent retries that back off identically just collide
            # again on the next attempt.
            time.sleep(random.uniform(0, 0.02 * (2**attempt)))

    raise LedgerError(
        f"posting {request.idempotency_key} could not be serialised after {_MAX_ATTEMPTS} attempts"
    ) from last_error


def _post_once(
    conn: Connection,
    request: PostingRequest,
    fingerprint: str,
    guards: Sequence[BalanceGuard],
) -> PostingResult:
    existing = _find_existing(conn, request.idempotency_key)
    if existing is not None:
        return _replay(conn, request, fingerprint, existing)

    # No try/except here: an idempotency-key collision means another caller committed
    # between the check above and this insert, and the only correct response is to
    # abandon this transaction and re-enter. `post` owns that decision.
    transaction_id = conn.execute(
        text(
            """
            INSERT INTO ledger_transaction
                (idempotency_key, posting_type, request_fingerprint,
                 business_txn_id, description)
            VALUES (:key, :posting_type, :fingerprint, :business_txn_id, :description)
            RETURNING id
            """
        ),
        {
            "key": request.idempotency_key,
            "posting_type": request.posting_type,
            "fingerprint": fingerprint,
            "business_txn_id": request.business_txn_id,
            "description": request.description,
        },
    ).scalar_one()

    entry_ids: list[uuid.UUID] = []
    for index, entry in enumerate(request.entries):
        entry_id = conn.execute(
            text(
                """
                INSERT INTO ledger_entry
                    (transaction_id, entry_index, account_id, direction, amount,
                     currency, entry_type)
                VALUES (:txn, :entry_index, :account, :direction, :amount,
                        :currency, :entry_type)
                RETURNING id
                """
            ),
            {
                "txn": transaction_id,
                "entry_index": index,
                "account": entry.account.id,
                "direction": entry.direction.value,
                "amount": entry.amount.minor_units,
                "currency": entry.amount.currency.code,
                "entry_type": entry.entry_type,
            },
        ).scalar_one()
        entry_ids.append(entry_id)

    _check_guards(conn, guards)
    return PostingResult(transaction_id=transaction_id, entry_ids=tuple(entry_ids))


def _find_existing(conn: Connection, idempotency_key: str) -> tuple[uuid.UUID, str] | None:
    row = conn.execute(
        text("SELECT id, request_fingerprint FROM ledger_transaction WHERE idempotency_key = :key"),
        {"key": idempotency_key},
    ).one_or_none()
    return None if row is None else (row.id, row.request_fingerprint)


def _replay(
    conn: Connection,
    request: PostingRequest,
    fingerprint: str,
    existing: tuple[uuid.UUID, str],
) -> PostingResult:
    transaction_id, stored_fingerprint = existing
    if stored_fingerprint != fingerprint:
        raise IdempotencyKeyReuse(
            f"idempotency key {request.idempotency_key!r} was already used for a "
            "different posting. Returning the original result would hide a caller bug."
        )
    entry_ids = (
        conn.execute(
            text("SELECT id FROM ledger_entry WHERE transaction_id = :t ORDER BY entry_index"),
            {"t": transaction_id},
        )
        .scalars()
        .all()
    )
    return PostingResult(transaction_id=transaction_id, entry_ids=tuple(entry_ids), replayed=True)


def _check_guards(conn: Connection, guards: Sequence[BalanceGuard]) -> None:
    """Assert each guarded account's resulting balance is at or above its floor.

    Runs after the entries are written and inside the same SERIALIZABLE transaction,
    so it reads the balance this posting produced. If a concurrent posting also moved
    the account, PostgreSQL aborts one of the two and `post` retries it.
    """
    from iwp.ledger.balances import account_balance

    for account_id, minimum in guards:
        resulting = account_balance(conn, account_id)
        if resulting < minimum:
            raise InsufficientBalance(
                f"account {account_id} would end at {resulting}, below the required "
                f"minimum of {minimum}"
            )
