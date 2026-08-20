"""P1.5 — reconciliation.

The build guide calls this the heart of the system, and the reason is the asymmetry it
has to hold onto:

    our ledger is authoritative for **intent**
    the provider is authoritative for **settlement**

Neither side gets to overwrite the other. When they disagree the disagreement is
written down, with both sides recorded verbatim, and a person decides what it means.

Three things follow, and each is enforced rather than merely intended:

1. **This module cannot write to the ledger.** It does not import the posting
   function and never names ``ledger_entry``. A correcting entry is a separate,
   deliberate act by a person, made through the ordinary posting path; its
   transaction id is then recorded against the discrepancy.
2. **Re-running is safe.** Every discrepancy has a deterministic key derived from
   what it is, not when it was found. Running the same period twice over the same
   data records the problem once.
3. **A resolution never edits the discrepancy.** Resolutions are appended, so the
   history of who said what survives, and a recurrence cannot quietly overwrite the
   note explaining the last one.
"""

from __future__ import annotations

import enum
import hashlib
import uuid
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from datetime import datetime, timedelta

from sqlalchemy import Engine, text
from sqlalchemy.engine import Connection, RowMapping

from iwp.money import Money
from iwp.states import SettlementState

__all__ = [
    "DEFAULT_TIMING_TOLERANCE",
    "Discrepancy",
    "DiscrepancyKind",
    "ExpectedSettlement",
    "ProviderStatementLine",
    "ReconciliationInput",
    "ReconciliationResult",
    "discrepancies_for_run",
    "open_discrepancies",
    "reconcile",
    "record_resolution",
    "resolution_status",
]

# How far a provider's value date may sit from our instruction before it is reported.
# Chosen to accommodate the slowest custody model in PRD §6 (multi-day, ACH-class)
# without accommodating a transfer that has quietly stalled.
DEFAULT_TIMING_TOLERANCE = timedelta(days=5)

_RESOLUTION_STATUSES = frozenset({"acknowledged", "resolved", "reopened"})


class DiscrepancyKind(enum.Enum):
    """The five kinds named in build guide P1.5. There is no sixth."""

    MISSING = "missing"
    """We expected a settlement; the statement does not show it."""

    UNEXPECTED = "unexpected"
    """The statement shows a settlement we have no record of."""

    AMOUNT_MISMATCH = "amount_mismatch"
    """Matched, but the amounts differ."""

    STATE_MISMATCH = "state_mismatch"
    """Matched, but the settlement states differ."""

    TIMING = "timing"
    """Matched and agreeing, but the value date is implausible against our
    instruction — too late to be healthy, or earlier than the instruction itself."""


@dataclass(frozen=True, slots=True)
class ExpectedSettlement:
    """What our ledger says should have happened at the provider.

    Built from our own records. Authoritative for *intent* only.
    """

    business_txn_id: uuid.UUID
    provider_reference: str | None
    amount: Money
    settlement_state: SettlementState
    instructed_at: datetime


@dataclass(frozen=True, slots=True)
class ProviderStatementLine:
    """One line of a provider statement. Authoritative for *settlement*.

    ``external_reference`` is our own identifier echoed back, where the provider
    carries one. It is the fallback match key for transfers whose provider reference
    we only learn from the statement itself.
    """

    provider_reference: str
    external_reference: str | None
    amount: Money
    state: SettlementState
    value_date: datetime


@dataclass(frozen=True, slots=True)
class ReconciliationInput:
    provider: str
    period_start: datetime
    period_end: datetime
    expected: tuple[ExpectedSettlement, ...]
    statement: tuple[ProviderStatementLine, ...]
    timing_tolerance: timedelta = DEFAULT_TIMING_TOLERANCE


@dataclass(frozen=True, slots=True)
class Discrepancy:
    id: uuid.UUID
    kind: DiscrepancyKind
    business_txn_id: uuid.UUID | None
    provider_reference: str | None
    our_amount: Money | None
    our_state: SettlementState | None
    provider_amount: Money | None
    provider_state: SettlementState | None
    detail: str
    first_seen_at: datetime


@dataclass(frozen=True, slots=True)
class ReconciliationResult:
    run_id: uuid.UUID
    expected_count: int
    statement_count: int
    matched_count: int
    discrepancies: tuple[Discrepancy, ...]

    @property
    def is_clean(self) -> bool:
        return not self.discrepancies


# --------------------------------------------------------------------------------------
# a finding, before it is a row
# --------------------------------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class _Finding:
    kind: DiscrepancyKind
    business_txn_id: uuid.UUID | None
    provider_reference: str | None
    our_amount: Money | None
    our_state: SettlementState | None
    provider_amount: Money | None
    provider_state: SettlementState | None
    detail: str

    def key(self) -> str:
        """Identity of the disagreement itself, independent of when it was noticed.

        Includes both sides' values, so a discrepancy that *changes* between runs is a
        new finding rather than a silent overwrite of the old one — the old note still
        describes the old numbers.
        """
        parts = [
            self.kind.value,
            str(self.business_txn_id or ""),
            self.provider_reference or "",
            _money_key(self.our_amount),
            self.our_state.value if self.our_state else "",
            _money_key(self.provider_amount),
            self.provider_state.value if self.provider_state else "",
        ]
        return hashlib.sha256("|".join(parts).encode("utf-8")).hexdigest()


def _money_key(amount: Money | None) -> str:
    return "" if amount is None else f"{amount.minor_units}:{amount.currency.code}"


# --------------------------------------------------------------------------------------
# matching
# --------------------------------------------------------------------------------------


def _match(
    expected: Sequence[ExpectedSettlement], statement: Sequence[ProviderStatementLine]
) -> tuple[
    list[tuple[ExpectedSettlement, ProviderStatementLine]],
    list[ExpectedSettlement],
    list[ProviderStatementLine],
]:
    """Pair expectations with statement lines.

    Two passes on purpose. The provider's reference is the stronger key and is tried
    first for every expectation; only then do we fall back to our own reference echoed
    back. Interleaving the two would let a weak match consume a line that a later
    expectation could have matched strongly.
    """
    by_provider_ref: dict[str, ProviderStatementLine] = {}
    by_external_ref: dict[str, ProviderStatementLine] = {}
    for line in statement:
        by_provider_ref.setdefault(line.provider_reference, line)
        if line.external_reference:
            by_external_ref.setdefault(line.external_reference, line)

    consumed: set[str] = set()
    pairs: list[tuple[ExpectedSettlement, ProviderStatementLine]] = []
    unmatched_expected: list[ExpectedSettlement] = []

    pending: list[ExpectedSettlement] = []
    for exp in expected:
        strong = by_provider_ref.get(exp.provider_reference) if exp.provider_reference else None
        if strong is not None and strong.provider_reference not in consumed:
            consumed.add(strong.provider_reference)
            pairs.append((exp, strong))
        else:
            pending.append(exp)

    for exp in pending:
        weak = by_external_ref.get(str(exp.business_txn_id))
        if weak is not None and weak.provider_reference not in consumed:
            consumed.add(weak.provider_reference)
            pairs.append((exp, weak))
        else:
            unmatched_expected.append(exp)

    unmatched_lines = [ln for ln in statement if ln.provider_reference not in consumed]
    return pairs, unmatched_expected, unmatched_lines


def _compare(
    exp: ExpectedSettlement, line: ProviderStatementLine, tolerance: timedelta
) -> list[_Finding]:
    """Compare one matched pair. A pair may disagree in more than one way."""
    findings: list[_Finding] = []

    amounts_agree = exp.amount == line.amount
    states_agree = exp.settlement_state is line.state

    if not amounts_agree:
        findings.append(
            _Finding(
                kind=DiscrepancyKind.AMOUNT_MISMATCH,
                business_txn_id=exp.business_txn_id,
                provider_reference=line.provider_reference,
                our_amount=exp.amount,
                our_state=exp.settlement_state,
                provider_amount=line.amount,
                provider_state=line.state,
                detail=(f"we recorded {exp.amount}; the provider statement shows {line.amount}"),
            )
        )

    if not states_agree:
        findings.append(
            _Finding(
                kind=DiscrepancyKind.STATE_MISMATCH,
                business_txn_id=exp.business_txn_id,
                provider_reference=line.provider_reference,
                our_amount=exp.amount,
                our_state=exp.settlement_state,
                provider_amount=line.amount,
                provider_state=line.state,
                detail=(
                    f"we recorded settlement state {exp.settlement_state.value}; "
                    f"the provider statement shows {line.state.value}. The provider is "
                    "authoritative for settlement, but adopting its value is a decision "
                    "for a person, not for this run."
                ),
            )
        )

    # Timing is only meaningful where the pair otherwise agrees. Reporting it alongside
    # an amount or state mismatch would be noise attached to a problem already raised.
    if amounts_agree and states_agree:
        drift = line.value_date - exp.instructed_at
        if drift < timedelta(0) or drift > tolerance:
            findings.append(
                _Finding(
                    kind=DiscrepancyKind.TIMING,
                    business_txn_id=exp.business_txn_id,
                    provider_reference=line.provider_reference,
                    our_amount=exp.amount,
                    our_state=exp.settlement_state,
                    provider_amount=line.amount,
                    provider_state=line.state,
                    detail=(
                        f"instructed at {exp.instructed_at.isoformat()}, provider value "
                        f"date {line.value_date.isoformat()} ({drift}) — outside the "
                        f"{tolerance} tolerance"
                        if drift >= timedelta(0)
                        else (
                            f"provider value date {line.value_date.isoformat()} precedes "
                            f"our instruction at {exp.instructed_at.isoformat()}; the "
                            "provider cannot have settled a transfer we had not sent"
                        )
                    ),
                )
            )

    return findings


def _findings(data: ReconciliationInput) -> tuple[list[_Finding], int]:
    pairs, unmatched_expected, unmatched_lines = _match(data.expected, data.statement)

    findings: list[_Finding] = []
    for exp, line in pairs:
        findings.extend(_compare(exp, line, data.timing_tolerance))

    for exp in unmatched_expected:
        findings.append(
            _Finding(
                kind=DiscrepancyKind.MISSING,
                business_txn_id=exp.business_txn_id,
                provider_reference=exp.provider_reference,
                our_amount=exp.amount,
                our_state=exp.settlement_state,
                provider_amount=None,
                provider_state=None,
                detail=(
                    f"we recorded {exp.amount} in state {exp.settlement_state.value}, "
                    "instructed at "
                    f"{exp.instructed_at.isoformat()}; the provider statement for this "
                    "period has no matching line"
                ),
            )
        )

    for line in unmatched_lines:
        findings.append(
            _Finding(
                kind=DiscrepancyKind.UNEXPECTED,
                business_txn_id=None,
                provider_reference=line.provider_reference,
                our_amount=None,
                our_state=None,
                provider_amount=line.amount,
                provider_state=line.state,
                detail=(
                    f"the provider statement shows {line.amount} in state "
                    f"{line.state.value} with reference {line.provider_reference}; "
                    "we have no record of instructing it"
                ),
            )
        )

    return findings, len(pairs)


# --------------------------------------------------------------------------------------
# the run
# --------------------------------------------------------------------------------------


def reconcile(engine: Engine, data: ReconciliationInput) -> ReconciliationResult:
    """Compare our expected settlement state against a provider statement.

    Records a run, and records each disagreement it has not already recorded. Returns
    only the discrepancies *this* run was the first to see; ones carried over from an
    earlier run stay attached to the run that found them, and are available through
    :func:`open_discrepancies`.
    """
    if data.period_end <= data.period_start:
        raise ValueError("period_end must be after period_start")

    findings, matched_count = _findings(data)

    with engine.begin() as conn:
        run_id = conn.execute(
            text(
                """
                INSERT INTO reconciliation_run
                    (provider, period_start, period_end,
                     expected_count, statement_count, matched_count)
                VALUES (:provider, :start, :end, :expected, :statement, :matched)
                RETURNING id
                """
            ),
            {
                "provider": data.provider,
                "start": data.period_start,
                "end": data.period_end,
                "expected": len(data.expected),
                "statement": len(data.statement),
                "matched": matched_count,
            },
        ).scalar_one()

        recorded: list[uuid.UUID] = []
        for finding in findings:
            # ON CONFLICT DO NOTHING on the deterministic key is what makes the run
            # idempotent: a problem already on file is not filed again, and its
            # existing resolution history is left untouched.
            new_id = conn.execute(
                text(
                    """
                    INSERT INTO reconciliation_discrepancy
                        (run_id, kind, business_txn_id, provider_reference,
                         our_amount, our_currency, our_state,
                         provider_amount, provider_currency, provider_state,
                         detail, discrepancy_key)
                    VALUES
                        (:run_id, :kind, :business_txn_id, :provider_reference,
                         :our_amount, :our_currency, :our_state,
                         :provider_amount, :provider_currency, :provider_state,
                         :detail, :key)
                    ON CONFLICT (discrepancy_key) DO NOTHING
                    RETURNING id
                    """
                ),
                {
                    "run_id": run_id,
                    "kind": finding.kind.value,
                    "business_txn_id": finding.business_txn_id,
                    "provider_reference": finding.provider_reference,
                    "our_amount": finding.our_amount.minor_units if finding.our_amount else None,
                    "our_currency": (
                        finding.our_amount.currency.code if finding.our_amount else None
                    ),
                    "our_state": finding.our_state.value if finding.our_state else None,
                    "provider_amount": (
                        finding.provider_amount.minor_units if finding.provider_amount else None
                    ),
                    "provider_currency": (
                        finding.provider_amount.currency.code if finding.provider_amount else None
                    ),
                    "provider_state": (
                        finding.provider_state.value if finding.provider_state else None
                    ),
                    "detail": finding.detail,
                    "key": finding.key(),
                },
            ).scalar_one_or_none()
            if new_id is not None:
                recorded.append(new_id)

        discrepancies = _load(conn, recorded)

    return ReconciliationResult(
        run_id=run_id,
        expected_count=len(data.expected),
        statement_count=len(data.statement),
        matched_count=matched_count,
        discrepancies=tuple(discrepancies),
    )


_SELECT_DISCREPANCY = """
SELECT id, kind, business_txn_id, provider_reference,
       our_amount, our_currency, our_state,
       provider_amount, provider_currency, provider_state,
       detail, first_seen_at
FROM reconciliation_discrepancy
"""


def _row_to_discrepancy(row: RowMapping) -> Discrepancy:
    """Build a Discrepancy from a row mapping.

    Reads through ``.mappings()`` rather than Row attributes so the field access is
    typed rather than ``Any``, and a renamed column fails here instead of silently
    yielding None.
    """

    def money(amount_key: str, currency_key: str) -> Money | None:
        amount = row[amount_key]
        return None if amount is None else Money(int(amount), str(row[currency_key]))

    def state(key: str) -> SettlementState | None:
        value = row[key]
        return None if value is None else SettlementState(value)

    return Discrepancy(
        id=row["id"],
        kind=DiscrepancyKind(row["kind"]),
        business_txn_id=row["business_txn_id"],
        provider_reference=row["provider_reference"],
        our_amount=money("our_amount", "our_currency"),
        our_state=state("our_state"),
        provider_amount=money("provider_amount", "provider_currency"),
        provider_state=state("provider_state"),
        detail=row["detail"],
        first_seen_at=row["first_seen_at"],
    )


def _load(conn: Connection, ids: Iterable[uuid.UUID]) -> list[Discrepancy]:
    id_list = list(ids)
    if not id_list:
        return []
    rows = (
        conn.execute(
            text(_SELECT_DISCREPANCY + " WHERE id = ANY(:ids) ORDER BY first_seen_at, id"),
            {"ids": id_list},
        )
        .mappings()
        .all()
    )
    return [_row_to_discrepancy(row) for row in rows]


def discrepancies_for_run(engine: Engine, run_id: uuid.UUID) -> list[Discrepancy]:
    """Discrepancies this run was the first to record."""
    with engine.connect() as conn:
        rows = (
            conn.execute(
                text(_SELECT_DISCREPANCY + " WHERE run_id = :run ORDER BY first_seen_at, id"),
                {"run": run_id},
            )
            .mappings()
            .all()
        )
    return [_row_to_discrepancy(row) for row in rows]


def open_discrepancies(engine: Engine) -> list[Discrepancy]:
    """Every discrepancy whose latest resolution is not ``resolved``.

    This is the list a human works from, and the one P6.2's daily alert counts.
    """
    with engine.connect() as conn:
        rows = (
            conn.execute(
                text(
                    _SELECT_DISCREPANCY
                    + """
                    WHERE COALESCE((
                        SELECT r.status
                        FROM reconciliation_resolution r
                        WHERE r.discrepancy_id = reconciliation_discrepancy.id
                        ORDER BY r.created_at DESC, r.id DESC
                        LIMIT 1
                    ), 'open') <> 'resolved'
                    ORDER BY first_seen_at, id
                    """
                )
            )
            .mappings()
            .all()
        )
    return [_row_to_discrepancy(row) for row in rows]


# --------------------------------------------------------------------------------------
# resolution — always by a person, always appended
# --------------------------------------------------------------------------------------


def record_resolution(
    engine: Engine,
    discrepancy_id: uuid.UUID,
    *,
    actor_id: uuid.UUID,
    status: str,
    note: str,
    compensating_txn_id: uuid.UUID | None = None,
) -> uuid.UUID:
    """Append a resolution to a discrepancy.

    ``compensating_txn_id`` records a correcting posting that a person has *already*
    made through the ordinary posting path. Nothing here creates one.
    """
    if status not in _RESOLUTION_STATUSES:
        raise ValueError(f"status must be one of {sorted(_RESOLUTION_STATUSES)}, got {status!r}")
    if not note.strip():
        raise ValueError("a note is required: a resolution has to say why")

    with engine.begin() as conn:
        resolution_id: uuid.UUID = conn.execute(
            text(
                """
                INSERT INTO reconciliation_resolution
                    (discrepancy_id, actor_id, status, note, compensating_txn_id)
                VALUES (:d, :a, :s, :n, :c)
                RETURNING id
                """
            ),
            {
                "d": discrepancy_id,
                "a": actor_id,
                "s": status,
                "n": note.strip(),
                "c": compensating_txn_id,
            },
        ).scalar_one()
        return resolution_id


def resolution_status(engine: Engine, discrepancy_id: uuid.UUID) -> str:
    """The current status of a discrepancy: its latest resolution, or ``open``."""
    with engine.connect() as conn:
        status = conn.execute(
            text(
                """
                SELECT status FROM reconciliation_resolution
                WHERE discrepancy_id = :d
                ORDER BY created_at DESC, id DESC
                LIMIT 1
                """
            ),
            {"d": discrepancy_id},
        ).scalar_one_or_none()
    return status or "open"
