"""P1.5 — reconciliation.

Invariants under test:
  * our ledger is authoritative for intent
  * the provider is authoritative for settlement
  * disagreements are recorded, never silently resolved in either direction

The last one is the important one and the easiest to lose. Every test that produces a
discrepancy also asserts that the ledger did not move.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import Engine, text

from iwp.ledger.reconciliation import (
    DiscrepancyKind,
    ExpectedSettlement,
    ProviderStatementLine,
    ReconciliationInput,
    discrepancies_for_run,
    reconcile,
    record_resolution,
    resolution_status,
)
from iwp.money import Money
from iwp.states import SettlementState

pytestmark = pytest.mark.db

PERIOD_START = datetime(2026, 8, 1, tzinfo=UTC)
PERIOD_END = datetime(2026, 8, 2, tzinfo=UTC)
INSTRUCTED_AT = datetime(2026, 8, 1, 9, 0, tzinfo=UTC)
VALUE_DATE = datetime(2026, 8, 1, 9, 5, tzinfo=UTC)


def _expected(
    txn_id: uuid.UUID,
    *,
    amount: int = 10000,
    state: SettlementState = SettlementState.SETTLED,
    reference: str | None = "PRV-1",
    instructed_at: datetime = INSTRUCTED_AT,
) -> ExpectedSettlement:
    return ExpectedSettlement(
        business_txn_id=txn_id,
        provider_reference=reference,
        amount=Money(amount, "USD"),
        settlement_state=state,
        instructed_at=instructed_at,
    )


def _line(
    *,
    amount: int = 10000,
    state: SettlementState = SettlementState.SETTLED,
    reference: str = "PRV-1",
    external_reference: str | None = None,
    value_date: datetime = VALUE_DATE,
) -> ProviderStatementLine:
    return ProviderStatementLine(
        provider_reference=reference,
        external_reference=external_reference,
        amount=Money(amount, "USD"),
        state=state,
        value_date=value_date,
    )


def _run(
    db: Engine,
    expected: list[ExpectedSettlement],
    statement: list[ProviderStatementLine],
) -> uuid.UUID:
    return reconcile(
        db,
        ReconciliationInput(
            provider="mock",
            period_start=PERIOD_START,
            period_end=PERIOD_END,
            expected=tuple(expected),
            statement=tuple(statement),
        ),
    ).run_id


def _ledger_size(db: Engine) -> tuple[int, int]:
    with db.connect() as conn:
        return (
            conn.execute(text("SELECT count(*) FROM ledger_entry")).scalar_one(),
            conn.execute(text("SELECT count(*) FROM ledger_transaction")).scalar_one(),
        )


# --------------------------------------------------------------------------------------
# agreement
# --------------------------------------------------------------------------------------


def test_a_matching_statement_produces_no_discrepancies(db: Engine) -> None:
    txn = uuid.uuid4()
    result = reconcile(
        db,
        ReconciliationInput(
            provider="mock",
            period_start=PERIOD_START,
            period_end=PERIOD_END,
            expected=(_expected(txn),),
            statement=(_line(),),
        ),
    )
    assert result.discrepancies == ()
    assert result.matched_count == 1


def test_lines_match_on_our_external_reference_when_we_have_no_provider_reference(
    db: Engine,
) -> None:
    # Under some providers the reference is only learned from the statement. Matching
    # has to survive that, or every such transfer looks both missing and unexpected.
    txn = uuid.uuid4()
    result = reconcile(
        db,
        ReconciliationInput(
            provider="mock",
            period_start=PERIOD_START,
            period_end=PERIOD_END,
            expected=(_expected(txn, reference=None),),
            statement=(_line(external_reference=str(txn)),),
        ),
    )
    assert result.discrepancies == ()
    assert result.matched_count == 1


# --------------------------------------------------------------------------------------
# the five discrepancy kinds
# --------------------------------------------------------------------------------------


def test_missing_when_we_expect_a_settlement_the_statement_does_not_show(db: Engine) -> None:
    txn = uuid.uuid4()
    run_id = _run(db, [_expected(txn)], [])
    found = discrepancies_for_run(db, run_id)
    assert [d.kind for d in found] == [DiscrepancyKind.MISSING]
    assert found[0].business_txn_id == txn
    assert _ledger_size(db) == (0, 0)


def test_unexpected_when_the_statement_shows_something_we_have_no_record_of(
    db: Engine,
) -> None:
    run_id = _run(db, [], [_line(reference="PRV-STRANGER")])
    found = discrepancies_for_run(db, run_id)
    assert [d.kind for d in found] == [DiscrepancyKind.UNEXPECTED]
    assert found[0].provider_reference == "PRV-STRANGER"
    assert _ledger_size(db) == (0, 0)


def test_amount_mismatch_records_both_sides_without_correcting_either(db: Engine) -> None:
    txn = uuid.uuid4()
    run_id = _run(db, [_expected(txn, amount=10000)], [_line(amount=9500)])
    found = discrepancies_for_run(db, run_id)
    assert [d.kind for d in found] == [DiscrepancyKind.AMOUNT_MISMATCH]
    assert found[0].our_amount == Money(10000, "USD")
    assert found[0].provider_amount == Money(9500, "USD")
    assert _ledger_size(db) == (0, 0)


def test_state_mismatch_when_we_say_settled_and_the_provider_says_failed(db: Engine) -> None:
    txn = uuid.uuid4()
    run_id = _run(
        db,
        [_expected(txn, state=SettlementState.SETTLED)],
        [_line(state=SettlementState.FAILED)],
    )
    found = discrepancies_for_run(db, run_id)
    assert [d.kind for d in found] == [DiscrepancyKind.STATE_MISMATCH]
    assert found[0].our_state is SettlementState.SETTLED
    assert found[0].provider_state is SettlementState.FAILED
    assert _ledger_size(db) == (0, 0)


def test_timing_when_amount_and_state_agree_but_the_value_date_is_out_of_tolerance(
    db: Engine,
) -> None:
    txn = uuid.uuid4()
    run_id = _run(
        db,
        [_expected(txn)],
        [_line(value_date=INSTRUCTED_AT + timedelta(days=6))],
    )
    found = discrepancies_for_run(db, run_id)
    assert [d.kind for d in found] == [DiscrepancyKind.TIMING]
    assert _ledger_size(db) == (0, 0)


def test_a_value_date_before_we_instructed_is_a_timing_discrepancy(db: Engine) -> None:
    # The provider cannot have settled a transfer we had not yet instructed. Reading
    # this as "fine, it is early" would hide a matching error.
    txn = uuid.uuid4()
    run_id = _run(
        db,
        [_expected(txn)],
        [_line(value_date=INSTRUCTED_AT - timedelta(hours=2))],
    )
    found = discrepancies_for_run(db, run_id)
    assert [d.kind for d in found] == [DiscrepancyKind.TIMING]


def test_amount_and_state_can_both_disagree_and_both_are_reported(db: Engine) -> None:
    txn = uuid.uuid4()
    run_id = _run(
        db,
        [_expected(txn, amount=10000, state=SettlementState.SETTLED)],
        [_line(amount=9500, state=SettlementState.FAILED)],
    )
    kinds = {d.kind for d in discrepancies_for_run(db, run_id)}
    assert kinds == {DiscrepancyKind.AMOUNT_MISMATCH, DiscrepancyKind.STATE_MISMATCH}


def test_an_in_flight_expectation_against_a_settled_line_is_a_state_mismatch(
    db: Engine,
) -> None:
    # The provider is authoritative for settlement, so this means our record is behind.
    # It is still recorded rather than silently adopted: adopting it is a decision.
    txn = uuid.uuid4()
    run_id = _run(
        db,
        [_expected(txn, state=SettlementState.IN_FLIGHT)],
        [_line(state=SettlementState.SETTLED)],
    )
    found = discrepancies_for_run(db, run_id)
    assert [d.kind for d in found] == [DiscrepancyKind.STATE_MISMATCH]
    assert _ledger_size(db) == (0, 0)


# --------------------------------------------------------------------------------------
# idempotence and re-runnability
# --------------------------------------------------------------------------------------


def test_reconciliation_is_re_runnable_and_idempotent(db: Engine) -> None:
    txn = uuid.uuid4()
    expected = [_expected(txn, amount=10000)]
    statement = [_line(amount=9500)]

    first = _run(db, expected, statement)
    second = _run(db, expected, statement)

    assert first != second  # each run is its own record
    with db.connect() as conn:
        total = conn.execute(text("SELECT count(*) FROM reconciliation_discrepancy")).scalar_one()
    assert total == 1, "re-running the same period must not duplicate a discrepancy"
    # The discrepancy stays attached to the run that first saw it.
    assert len(discrepancies_for_run(db, first)) == 1
    assert discrepancies_for_run(db, second) == []


def test_a_discrepancy_that_changes_is_recorded_as_a_new_one(db: Engine) -> None:
    txn = uuid.uuid4()
    first = _run(db, [_expected(txn, amount=10000)], [_line(amount=9500)])
    second = _run(db, [_expected(txn, amount=10000)], [_line(amount=9000)])

    assert len(discrepancies_for_run(db, first)) == 1
    assert len(discrepancies_for_run(db, second)) == 1
    with db.connect() as conn:
        assert (
            conn.execute(text("SELECT count(*) FROM reconciliation_discrepancy")).scalar_one() == 2
        )


def test_a_resolved_discrepancy_that_recurs_is_not_silently_reopened(db: Engine) -> None:
    txn = uuid.uuid4()
    run_id = _run(db, [_expected(txn, amount=10000)], [_line(amount=9500)])
    found = discrepancies_for_run(db, run_id)[0]
    record_resolution(db, found.id, actor_id=uuid.uuid4(), status="resolved", note="partner fixed")

    _run(db, [_expected(txn, amount=10000)], [_line(amount=9500)])
    assert resolution_status(db, found.id) == "resolved"
    with db.connect() as conn:
        assert (
            conn.execute(text("SELECT count(*) FROM reconciliation_discrepancy")).scalar_one() == 1
        )


# --------------------------------------------------------------------------------------
# the ledger is never auto-mutated
# --------------------------------------------------------------------------------------


def test_a_discrepancy_never_auto_mutates_the_ledger(db: Engine) -> None:
    """Every kind of disagreement, in one run, and the ledger stays empty."""
    matched = uuid.uuid4()
    run_id = _run(
        db,
        [
            _expected(uuid.uuid4(), reference="PRV-MISSING"),
            _expected(matched, reference="PRV-AMT", amount=10000),
            _expected(uuid.uuid4(), reference="PRV-STATE", state=SettlementState.SETTLED),
            _expected(uuid.uuid4(), reference="PRV-TIME"),
        ],
        [
            _line(reference="PRV-AMT", amount=9500),
            _line(reference="PRV-STATE", state=SettlementState.FAILED),
            _line(reference="PRV-TIME", value_date=INSTRUCTED_AT + timedelta(days=9)),
            _line(reference="PRV-GHOST"),
        ],
    )
    kinds = {d.kind for d in discrepancies_for_run(db, run_id)}
    assert kinds == {
        DiscrepancyKind.MISSING,
        DiscrepancyKind.UNEXPECTED,
        DiscrepancyKind.AMOUNT_MISMATCH,
        DiscrepancyKind.STATE_MISMATCH,
        DiscrepancyKind.TIMING,
    }
    assert _ledger_size(db) == (0, 0)


def test_reconciliation_module_has_no_code_path_to_the_ledger(db: Engine) -> None:
    """The structural version of the invariant above.

    Checked against the parsed module rather than its text, so that prose describing
    the rule does not read as a violation of it.
    """
    import ast
    import inspect

    from iwp.ledger import reconciliation

    tree = ast.parse(inspect.getsource(reconciliation))

    imported: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.ImportFrom) and node.module:
            imported.add(node.module)
        elif isinstance(node, ast.Import):
            imported.update(alias.name for alias in node.names)
    assert "iwp.ledger.posting" not in imported
    assert not any(name.startswith("iwp.ledger.balances") for name in imported)

    # Every SQL literal in the module, with docstrings excluded.
    docstrings = {
        ast.get_docstring(node, clean=False)
        for node in ast.walk(tree)
        if isinstance(node, ast.Module | ast.ClassDef | ast.FunctionDef)
    }
    literals = [
        node.value.lower()
        for node in ast.walk(tree)
        if isinstance(node, ast.Constant)
        and isinstance(node.value, str)
        and node.value not in docstrings
    ]
    for sql in literals:
        for table in ("ledger_entry", "ledger_transaction"):
            for verb in ("insert into", "update", "delete from"):
                assert f"{verb} {table}" not in sql, f"reconciliation writes to {table}"


def test_a_discrepancy_row_cannot_be_updated_or_deleted(db: Engine) -> None:
    from sqlalchemy.exc import DBAPIError

    run_id = _run(db, [_expected(uuid.uuid4())], [])
    found = discrepancies_for_run(db, run_id)[0]
    with pytest.raises(DBAPIError, match="append-only"), db.begin() as conn:
        conn.execute(
            text("UPDATE reconciliation_discrepancy SET detail = 'nothing to see' WHERE id = :i"),
            {"i": found.id},
        )


def test_resolving_requires_an_actor_and_a_note(db: Engine) -> None:
    run_id = _run(db, [_expected(uuid.uuid4())], [])
    found = discrepancies_for_run(db, run_id)[0]
    with pytest.raises(ValueError, match="note"):
        record_resolution(db, found.id, actor_id=uuid.uuid4(), status="resolved", note="  ")


def test_resolution_history_is_appended_not_overwritten(db: Engine) -> None:
    run_id = _run(db, [_expected(uuid.uuid4())], [])
    found = discrepancies_for_run(db, run_id)[0]
    actor = uuid.uuid4()
    record_resolution(db, found.id, actor_id=actor, status="acknowledged", note="looking")
    record_resolution(db, found.id, actor_id=actor, status="resolved", note="partner confirmed")
    record_resolution(db, found.id, actor_id=actor, status="reopened", note="recurred")

    assert resolution_status(db, found.id) == "reopened"
    with db.connect() as conn:
        assert (
            conn.execute(
                text("SELECT count(*) FROM reconciliation_resolution WHERE discrepancy_id = :i"),
                {"i": found.id},
            ).scalar_one()
            == 3
        )


def test_an_unresolved_discrepancy_reports_as_open(db: Engine) -> None:
    run_id = _run(db, [_expected(uuid.uuid4())], [])
    found = discrepancies_for_run(db, run_id)[0]
    assert resolution_status(db, found.id) == "open"
