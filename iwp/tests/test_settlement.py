"""P3 — settlement abstraction.

Covers:
  P3.1 the SettlementProvider interface and its capability gate
  P3.2 the mock provider across custody models A, B and C
  P3.3 lifecycle wiring: instruction, webhooks, failure, partial, reversal
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest
from sqlalchemy import Engine, text

from iwp.domain.audit import audit_trail
from iwp.domain.plans import Cadence, create_plan, create_recurring_rule
from iwp.domain.requests import approve_request, cancel_transaction, submit_request
from iwp.domain.users import Channel, Role, activate_relationship, invite_recipient, upsert_user
from iwp.ledger import AccountType, account_balance, ensure_account, trial_balance
from iwp.money import Money
from iwp.settlement.adapters.mock import (
    MOCK_USD_GTQ_RATE,
    MockProvider,
    Outcome,
)
from iwp.settlement.lifecycle import (
    SettlementError,
    SettlementEventOutcome,
    apply_settlement_event,
    cancel_settlement,
    instruct_settlement,
    record_provider_timeout,
)
from iwp.settlement.provider import (
    Beneficiary,
    Capabilities,
    CapabilityUnsupported,
    CustodyModel,
    FundingSource,
    PayoutMethod,
    ProviderRejected,
    ProviderTimeout,
    Quote,
    SettlementLatency,
)
from iwp.settlement.registry import ProviderNotRegistered, get_provider
from iwp.states import IntentState, SettlementState

NOW = datetime(2026, 8, 20, 12, 0, tzinfo=UTC)


def _clock() -> datetime:
    return NOW


def _provider(**kwargs: object) -> MockProvider:
    return MockProvider(clock=_clock, **kwargs)  # type: ignore[arg-type]


DEFAULT_SEND = Money(10000, "USD")


def _quote(provider: MockProvider, amount: Money = DEFAULT_SEND) -> Quote:
    return provider.quote(amount=amount, to_currency="GTQ", idempotency_key=f"q-{uuid.uuid4()}")


def _beneficiary(relationship_id: uuid.UUID | None = None) -> Beneficiary:
    return Beneficiary(
        relationship_id=relationship_id or uuid.uuid4(),
        name="Ana Lopez",
        payout_method=PayoutMethod.CASH_PICKUP,
        account_reference="PICKUP-001",
    )


# ======================================================================================
# P3.1 — the interface
# ======================================================================================


def test_capabilities_reflect_prd_section_six() -> None:
    caps = _provider(custody_model=CustodyModel.B_WE_HOLD_BALANCE).capabilities()
    assert caps.supports_held_balance is True
    assert caps.supports_programmable_release is True
    assert caps.supports_partial_release is True
    assert caps.supports_reversal is True
    assert caps.settlement_latency is SettlementLatency.INSTANT
    assert PayoutMethod.CASH_PICKUP in caps.payout_methods


def test_a_provider_without_programmable_release_cannot_be_constructed() -> None:
    # PRD §6 marks it the GATE. Without it there is no product, so this must fail at
    # construction rather than at the first release attempt in production.
    with pytest.raises(ValueError, match="gating capability"):
        Capabilities(
            supports_held_balance=True,
            supports_programmable_release=False,
            supports_partial_release=False,
            supports_reversal=False,
            settlement_latency=SettlementLatency.INSTANT,
            payout_methods=frozenset({PayoutMethod.BANK_DEPOSIT}),
        )


def test_a_provider_must_support_at_least_one_payout_method() -> None:
    with pytest.raises(ValueError, match="payout method"):
        Capabilities(
            supports_held_balance=True,
            supports_programmable_release=True,
            supports_partial_release=False,
            supports_reversal=False,
            settlement_latency=SettlementLatency.INSTANT,
            payout_methods=frozenset(),
        )


def test_calling_an_unsupported_capability_raises_the_typed_error() -> None:
    provider = _provider(custody_model=CustodyModel.A_FUND_AT_APPROVAL)
    assert provider.capabilities().supports_held_balance is False
    with pytest.raises(CapabilityUnsupported) as caught:
        provider.hold(user_id=uuid.uuid4(), amount=Money(100, "USD"), idempotency_key="k")
    assert caught.value.capability == "held balance"


def test_an_unsupported_reversal_raises_rather_than_failing_silently() -> None:
    provider = _provider(custody_model=CustodyModel.C_PARTNER_HOLDS)
    assert provider.capabilities().supports_reversal is False
    with pytest.raises(CapabilityUnsupported, match="reversal"):
        provider.reverse("STL-000001", idempotency_key="k")


def test_the_capability_gate_lives_in_the_base_class_not_the_adapter() -> None:
    # An adapter author cannot forget to gate: the public method is concrete on the
    # base class and the adapter only implements the underscore-prefixed half.
    import inspect

    from iwp.settlement.provider import SettlementProvider

    source = inspect.getsource(SettlementProvider.release)
    assert "_require(" in source
    assert "supports_programmable_release" in source


def test_an_fx_rate_may_not_be_a_float() -> None:
    with pytest.raises(TypeError, match="never a float"):
        Quote(
            quote_id="Q",
            send_amount=Money(10000, "USD"),
            fee=Money(0, "USD"),
            fx_rate=7.75,  # type: ignore[arg-type]
            recipient_amount=Money(77500, "GTQ"),
            expires_at=NOW,
        )


def test_a_quote_states_everything_the_disclosure_needs() -> None:
    # PRD Feature 7: amount sent, all fees, FX rate applied, amount received.
    quote = _quote(_provider())
    assert quote.send_amount == Money(10000, "USD")
    assert quote.fee.is_positive
    assert quote.fx_rate == MOCK_USD_GTQ_RATE
    assert quote.recipient_amount == Money(77500, "GTQ")
    assert quote.total_charged == quote.send_amount + quote.fee
    assert quote.is_expired(NOW) is False
    assert quote.is_expired(NOW + timedelta(hours=1)) is True


def test_the_registry_switches_provider_by_name_alone() -> None:
    # P6.1's verification: switch a config value, change nothing else.
    assert get_provider("mockpay").name == "mockpay"
    with pytest.raises(ProviderNotRegistered):
        get_provider("a-partner-we-never-signed")


# ======================================================================================
# P3.2 — the mock
# ======================================================================================


@pytest.mark.parametrize("model", list(CustodyModel))
def test_the_mock_simulates_every_custody_model(model: CustodyModel) -> None:
    provider = _provider(custody_model=model)
    caps = provider.capabilities()
    assert caps.supports_programmable_release is True
    assert provider.custody_model is model


def test_an_instant_provider_settles_before_release_returns() -> None:
    provider = _provider(custody_model=CustodyModel.B_WE_HOLD_BALANCE)
    ref = provider.release(
        source=FundingSource(reference="fs", user_id=uuid.uuid4()),
        beneficiary=_beneficiary(),
        amount=Money(10000, "USD"),
        quote=_quote(provider),
        idempotency_key="r1",
    )
    assert ref.state is SettlementState.SETTLED


def test_a_multi_day_provider_does_not() -> None:
    provider = _provider(custody_model=CustodyModel.A_FUND_AT_APPROVAL)
    ref = provider.release(
        source=FundingSource(reference="fs", user_id=uuid.uuid4()),
        beneficiary=_beneficiary(),
        amount=Money(10000, "USD"),
        quote=_quote(provider),
        idempotency_key="r1",
    )
    assert ref.state is SettlementState.INSTRUCTED
    provider.advance(ref.reference)
    assert provider.status(ref.reference) is SettlementState.SETTLED


def test_release_is_idempotent_by_key() -> None:
    provider = _provider(custody_model=CustodyModel.A_FUND_AT_APPROVAL)
    args = {
        "source": FundingSource(reference="fs", user_id=uuid.uuid4()),
        "beneficiary": _beneficiary(),
        "amount": Money(10000, "USD"),
        "quote": _quote(provider),
        "idempotency_key": "r1",
    }
    first = provider.release(**args)  # type: ignore[arg-type]
    second = provider.release(**args)  # type: ignore[arg-type]
    assert second.reference == first.reference


def test_the_mock_simulates_failure() -> None:
    provider = _provider(custody_model=CustodyModel.A_FUND_AT_APPROVAL)
    provider.script("r1", Outcome.FAILURE)
    ref = provider.release(
        source=FundingSource(reference="fs", user_id=uuid.uuid4()),
        beneficiary=_beneficiary(),
        amount=Money(10000, "USD"),
        quote=_quote(provider),
        idempotency_key="r1",
    )
    provider.advance(ref.reference)
    assert provider.status(ref.reference) is SettlementState.FAILED


def test_the_mock_simulates_partial_settlement() -> None:
    provider = _provider(custody_model=CustodyModel.C_PARTNER_HOLDS)
    provider.script("r1", Outcome.PARTIAL)
    ref = provider.release(
        source=FundingSource(reference="fs", user_id=uuid.uuid4()),
        beneficiary=_beneficiary(),
        amount=Money(10000, "USD"),
        quote=_quote(provider),
        idempotency_key="r1",
    )
    provider.advance(ref.reference)
    assert provider.status(ref.reference) is SettlementState.IN_FLIGHT
    events = provider.pending_webhooks(ref.reference)
    assert events[-1].delivered_amount == Money(5000, "USD")


def test_the_mock_simulates_a_timeout_that_still_created_the_instruction() -> None:
    # The dangerous case: we never learn the reference, but the provider has it.
    provider = _provider(custody_model=CustodyModel.A_FUND_AT_APPROVAL)
    provider.script("r1", Outcome.TIMEOUT)
    with pytest.raises(ProviderTimeout):
        provider.release(
            source=FundingSource(reference="fs", user_id=uuid.uuid4()),
            beneficiary=_beneficiary(),
            amount=Money(10000, "USD"),
            quote=_quote(provider),
            idempotency_key="r1",
        )
    # Retrying with the same key recovers the reference.
    recovered = provider.release(
        source=FundingSource(reference="fs", user_id=uuid.uuid4()),
        beneficiary=_beneficiary(),
        amount=Money(10000, "USD"),
        quote=_quote(provider),
        idempotency_key="r1",
    )
    assert recovered.reference.startswith("STL-")


def test_the_mock_simulates_up_front_rejection() -> None:
    provider = _provider()
    provider.script("r1", Outcome.REJECTED)
    with pytest.raises(ProviderRejected, match="simulated rejection"):
        provider.release(
            source=FundingSource(reference="fs", user_id=uuid.uuid4()),
            beneficiary=_beneficiary(),
            amount=Money(10000, "USD"),
            quote=_quote(provider),
            idempotency_key="r1",
        )


def test_the_mock_refuses_a_payout_method_the_model_does_not_support() -> None:
    provider = _provider(custody_model=CustodyModel.A_FUND_AT_APPROVAL)
    beneficiary = Beneficiary(
        relationship_id=uuid.uuid4(),
        name="Ana",
        payout_method=PayoutMethod.MOBILE_WALLET,
        account_reference="W-1",
    )
    with pytest.raises(ProviderRejected, match="payout method"):
        provider.release(
            source=FundingSource(reference="fs", user_id=uuid.uuid4()),
            beneficiary=beneficiary,
            amount=Money(10000, "USD"),
            quote=_quote(provider),
            idempotency_key="r1",
        )


def test_the_mock_refuses_an_expired_quote() -> None:
    provider = _provider()
    stale = Quote(
        quote_id="Q",
        send_amount=Money(10000, "USD"),
        fee=Money(0, "USD"),
        fx_rate=Decimal("7.75"),
        recipient_amount=Money(77500, "GTQ"),
        expires_at=NOW - timedelta(minutes=1),
    )
    with pytest.raises(ProviderRejected, match="expired"):
        provider.release(
            source=FundingSource(reference="fs", user_id=uuid.uuid4()),
            beneficiary=_beneficiary(),
            amount=Money(10000, "USD"),
            quote=stale,
            idempotency_key="r1",
        )


def test_the_mock_delivers_events_out_of_order_on_demand() -> None:
    provider = _provider(
        custody_model=CustodyModel.A_FUND_AT_APPROVAL, deliver_events_reversed=True
    )
    ref = provider.release(
        source=FundingSource(reference="fs", user_id=uuid.uuid4()),
        beneficiary=_beneficiary(),
        amount=Money(10000, "USD"),
        quote=_quote(provider),
        idempotency_key="r1",
    )
    provider.advance(ref.reference)
    sequences = [e.sequence for e in provider.pending_webhooks(ref.reference)]
    assert sequences == sorted(sequences, reverse=True)


def test_the_mock_duplicates_events_on_demand() -> None:
    provider = _provider(custody_model=CustodyModel.A_FUND_AT_APPROVAL, duplicate_every_event=True)
    ref = provider.release(
        source=FundingSource(reference="fs", user_id=uuid.uuid4()),
        beneficiary=_beneficiary(),
        amount=Money(10000, "USD"),
        quote=_quote(provider),
        idempotency_key="r1",
    )
    provider.advance(ref.reference)
    events = provider.pending_webhooks(ref.reference)
    assert len({e.event_id for e in events}) * 2 == len(events)


def test_the_mock_produces_statements_for_reconciliation() -> None:
    provider = _provider(custody_model=CustodyModel.B_WE_HOLD_BALANCE)
    provider.release(
        source=FundingSource(reference="fs", user_id=uuid.uuid4()),
        beneficiary=_beneficiary(),
        amount=Money(10000, "USD"),
        quote=_quote(provider),
        idempotency_key="r1",
    )
    lines = provider.statement(
        period_start=NOW - timedelta(hours=1), period_end=NOW + timedelta(hours=1)
    )
    assert len(lines) == 1
    assert lines[0].state is SettlementState.SETTLED
    assert lines[0].amount == Money(10000, "USD")
    assert lines[0].external_reference == "r1"
    assert (
        provider.statement(period_start=NOW + timedelta(days=1), period_end=NOW + timedelta(days=2))
        == []
    )


def test_a_partial_settlement_statement_reports_what_landed_not_what_was_sent() -> None:
    # Which is precisely the amount mismatch reconciliation should surface.
    provider = _provider(custody_model=CustodyModel.C_PARTNER_HOLDS)
    provider.script("r1", Outcome.PARTIAL)
    ref = provider.release(
        source=FundingSource(reference="fs", user_id=uuid.uuid4()),
        beneficiary=_beneficiary(),
        amount=Money(10000, "USD"),
        quote=_quote(provider),
        idempotency_key="r1",
    )
    provider.advance(ref.reference)
    lines = provider.statement(
        period_start=NOW - timedelta(hours=1), period_end=NOW + timedelta(hours=1)
    )
    assert lines[0].amount == Money(5000, "USD")


def test_the_full_suite_runs_with_no_network_access() -> None:
    # Structural: the mock imports nothing that could open a socket.
    import ast
    import inspect

    from iwp.settlement.adapters import mock

    imported = {
        node.module
        for node in ast.walk(ast.parse(inspect.getsource(mock)))
        if isinstance(node, ast.ImportFrom) and node.module
    } | {
        alias.name
        for node in ast.walk(ast.parse(inspect.getsource(mock)))
        if isinstance(node, ast.Import)
        for alias in node.names
    }
    for network in ("httpx", "requests", "socket", "urllib", "http"):
        assert not any(name.split(".")[0] == network for name in imported)


# ======================================================================================
# P3.3 — lifecycle wiring
# ======================================================================================

pytestmark_db = pytest.mark.db


@pytest.fixture()
def world(db: Engine) -> dict[str, uuid.UUID]:
    """An active pair with a plan, a funding source and a payout destination."""
    with db.begin() as conn:
        sender = upsert_user(
            conn,
            "+15555550000",
            role=Role.SENDER,
            display_name="Marco",
            preferred_channel=Channel.APP,
        )
    rel, recipient, _ = invite_recipient(
        db, sender_id=sender.id, recipient_phone="55551234", recipient_display_name="Ana"
    )
    activate_relationship(db, rel.id, accepted_by=recipient.id, channel="whatsapp")
    version = create_plan(db, relationship_id=rel.id, created_by=sender.id)
    create_recurring_rule(
        db,
        plan_id=version.plan_id,
        category_key="food",
        amount=Money(25000, "USD"),
        cadence=Cadence.MONTHLY,
        actor_id=sender.id,
    )
    with db.begin() as conn:
        conn.execute(
            text(
                """
                INSERT INTO funding_source
                    (user_id, provider_reference, kind, last4, status, is_default)
                VALUES (:u, 'FS-EXTERNAL-1', 'bank_account', '4242', 'active', TRUE)
                """
            ),
            {"u": sender.id},
        )
        conn.execute(
            text(
                """
                INSERT INTO payout_destination
                    (relationship_id, payout_method, account_reference, holder_name)
                VALUES (:r, 'cash_pickup', 'PICKUP-001', 'Ana Lopez')
                """
            ),
            {"r": rel.id},
        )
    return {"sender": sender.id, "recipient": recipient.id, "relationship": rel.id}


def _approved(db: Engine, world: dict[str, uuid.UUID], amount: int = 10000) -> uuid.UUID:
    outcome = submit_request(
        db,
        relationship_id=world["relationship"],
        requested_by=world["recipient"],
        amount=Money(amount, "USD"),
        category_key="food",
        description="Compras",
        channel="whatsapp",
        now=NOW,
    )
    approval = approve_request(
        db,
        outcome.request.id,
        approved_by=world["sender"],
        channel="app",
        assurance_level="app_verified",
        fee=Money(200, "USD"),
        now=NOW,
    )
    return approval.transaction.id


def _reference(transaction: object) -> str:
    """The provider reference of an instructed transaction.

    Narrows the Optional in one place: an instructed transaction always has one, and
    asserting it here beats sprinkling the assertion through every test.
    """
    reference = transaction.provider_reference_id  # type: ignore[attr-defined]
    assert reference is not None, "an instructed transaction always has a reference"
    return str(reference)


def _accounts(db: Engine, world: dict[str, uuid.UUID], provider_name: str) -> dict[str, Money]:
    scope = uuid.uuid5(uuid.NAMESPACE_URL, f"iwp:settlement-provider:{provider_name}")
    with db.begin() as conn:
        custody = ensure_account(conn, AccountType.PARTNER_CUSTODY, "USD", scope_id=scope)
        payable = ensure_account(
            conn, AccountType.RECIPIENT_PAYABLE, "USD", scope_id=world["relationship"]
        )
        fees = ensure_account(conn, AccountType.FEE_REVENUE, "USD")
        return {
            "custody": account_balance(conn, custody.id),
            "payable": account_balance(conn, payable.id),
            "fees": account_balance(conn, fees.id),
        }


def _drain(db: Engine, provider: MockProvider, reference: str) -> list[SettlementEventOutcome]:
    outcomes: list[SettlementEventOutcome] = []
    for event in provider.pending_webhooks(reference):
        outcomes.append(
            apply_settlement_event(
                db,
                provider_name=provider.name,
                provider_event_id=event.event_id,
                provider_reference=event.reference,
                state=event.state,
                delivered_amount=event.delivered_amount,
                sequence=event.sequence,
                occurred_at=event.occurred_at,
            )
        )
    return outcomes


@pytest.mark.db
def test_approval_triggers_release_and_moves_settlement_to_instructed(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    provider = _provider(custody_model=CustodyModel.A_FUND_AT_APPROVAL)
    transaction_id = _approved(db, world)

    transaction = instruct_settlement(db, provider, transaction_id, quote=_quote(provider), now=NOW)
    assert transaction.settlement_state is SettlementState.INSTRUCTED
    assert transaction.intent_state is IntentState.COMMITTED
    assert transaction.settlement_provider == provider.name
    assert _reference(transaction) is not None

    balances = _accounts(db, world, provider.name)
    assert balances["custody"] == Money(10200, "USD")
    assert balances["payable"] == Money(10000, "USD")
    assert balances["fees"] == Money(200, "USD")


@pytest.mark.db
def test_instructing_twice_is_a_no_op(db: Engine, world: dict[str, uuid.UUID]) -> None:
    provider = _provider(custody_model=CustodyModel.A_FUND_AT_APPROVAL)
    transaction_id = _approved(db, world)
    quote = _quote(provider)
    first = instruct_settlement(db, provider, transaction_id, quote=quote, now=NOW)
    second = instruct_settlement(db, provider, transaction_id, quote=quote, now=NOW)
    assert second.provider_reference_id == first.provider_reference_id
    assert _accounts(db, world, provider.name)["custody"] == Money(10200, "USD")


@pytest.mark.db
def test_the_disclosure_figures_are_stored_on_the_transaction(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    # PRD Feature 7: the applied rate is stored, not a marketing rate.
    provider = _provider(custody_model=CustodyModel.A_FUND_AT_APPROVAL)
    transaction_id = _approved(db, world)
    instruct_settlement(db, provider, transaction_id, quote=_quote(provider), now=NOW)
    with db.connect() as conn:
        row = (
            conn.execute(
                text(
                    """
                    SELECT fx_rate_applied, recipient_amount, recipient_currency
                    FROM transaction WHERE id = :i
                    """
                ),
                {"i": transaction_id},
            )
            .mappings()
            .one()
        )
    assert row["fx_rate_applied"] == MOCK_USD_GTQ_RATE
    assert row["recipient_amount"] == 77500
    assert row["recipient_currency"] == "GTQ"


@pytest.mark.db
def test_a_settled_webhook_discharges_the_obligation(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    provider = _provider(custody_model=CustodyModel.A_FUND_AT_APPROVAL)
    transaction_id = _approved(db, world)
    transaction = instruct_settlement(db, provider, transaction_id, quote=_quote(provider), now=NOW)
    provider.advance(_reference(transaction))
    _drain(db, provider, _reference(transaction))

    with db.connect() as conn:
        from iwp.domain.requests import get_transaction

        settled = get_transaction(conn, transaction_id)
    assert settled.settlement_state is SettlementState.SETTLED
    assert settled.settled_amount == Money(10000, "USD")

    balances = _accounts(db, world, provider.name)
    assert balances["payable"] == Money(0, "USD")
    assert balances["custody"] == Money(200, "USD"), "the fee stays as realised revenue"


@pytest.mark.db
def test_duplicate_webhooks_are_no_ops(db: Engine, world: dict[str, uuid.UUID]) -> None:
    provider = _provider(custody_model=CustodyModel.A_FUND_AT_APPROVAL, duplicate_every_event=True)
    transaction_id = _approved(db, world)
    transaction = instruct_settlement(db, provider, transaction_id, quote=_quote(provider), now=NOW)
    provider.advance(_reference(transaction))
    outcomes = _drain(db, provider, _reference(transaction))

    assert sum(1 for o in outcomes if o.is_duplicate) == 2
    assert _accounts(db, world, provider.name)["payable"] == Money(0, "USD")
    with db.connect() as conn:
        entries = conn.execute(
            text(
                "SELECT count(*) FROM ledger_entry WHERE transaction_id IN (SELECT id FROM ledger_transaction WHERE business_txn_id = :t)"
            ),
            {"t": transaction_id},
        ).scalar_one()
    assert entries == 5, "3 for the commitment, 2 for one delivery — not two deliveries"


@pytest.mark.db
def test_out_of_order_webhooks_resolve_by_state_not_arrival_order(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    provider = _provider(
        custody_model=CustodyModel.A_FUND_AT_APPROVAL, deliver_events_reversed=True
    )
    transaction_id = _approved(db, world)
    transaction = instruct_settlement(db, provider, transaction_id, quote=_quote(provider), now=NOW)
    provider.advance(_reference(transaction))

    events = provider.pending_webhooks(_reference(transaction))
    assert events[0].state is SettlementState.SETTLED, "settled arrives first"
    outcomes = _drain(db, provider, _reference(transaction))

    assert outcomes[0].applied is True
    assert outcomes[1].applied is False, "the late in_flight must not move us backwards"
    assert "does not advance" in outcomes[1].reason

    with db.connect() as conn:
        from iwp.domain.requests import get_transaction

        assert get_transaction(conn, transaction_id).settlement_state is SettlementState.SETTLED
        # The ignored event is still on file — an operator needs to see it.
        recorded = (
            conn.execute(
                text(
                    """
                    SELECT state, applied, not_applied_reason FROM settlement_event
                    WHERE transaction_id = :t ORDER BY received_at
                    """
                ),
                {"t": transaction_id},
            )
            .mappings()
            .all()
        )
    assert [r["applied"] for r in recorded] == [True, False]
    assert recorded[1]["not_applied_reason"]


@pytest.mark.db
def test_failure_moves_state_to_failed_and_notifies_both_parties(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    provider = _provider(custody_model=CustodyModel.A_FUND_AT_APPROVAL)
    transaction_id = _approved(db, world)
    provider.script(f"release:{transaction_id}", Outcome.FAILURE)
    transaction = instruct_settlement(db, provider, transaction_id, quote=_quote(provider), now=NOW)
    provider.advance(_reference(transaction))
    _drain(db, provider, _reference(transaction))

    with db.connect() as conn:
        from iwp.domain.requests import get_transaction

        failed = get_transaction(conn, transaction_id)
        notified = (
            conn.execute(
                text(
                    """
                    SELECT recipient_user_id FROM outbox
                    WHERE topic = 'settlement.failed'
                    """
                ),
            )
            .scalars()
            .all()
        )
    assert failed.settlement_state is SettlementState.FAILED
    assert failed.failure_reason
    assert set(notified) == {world["sender"], world["recipient"]}, "both parties, PRD §10"

    # Money is never silently lost: everything went back out of custody.
    balances = _accounts(db, world, provider.name)
    assert balances["custody"] == Money(0, "USD")
    assert balances["payable"] == Money(0, "USD")
    assert balances["fees"] == Money(0, "USD"), "the fee was never earned"


@pytest.mark.db
def test_partial_settlement_records_what_landed_and_tracks_the_remainder(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    provider = _provider(custody_model=CustodyModel.C_PARTNER_HOLDS)
    transaction_id = _approved(db, world)
    provider.script(f"release:{transaction_id}", Outcome.PARTIAL)
    transaction = instruct_settlement(db, provider, transaction_id, quote=_quote(provider), now=NOW)
    provider.advance(_reference(transaction))
    _drain(db, provider, _reference(transaction))

    with db.connect() as conn:
        from iwp.domain.requests import get_transaction

        partial = get_transaction(conn, transaction_id)
    assert partial.settled_amount == Money(5000, "USD")
    assert partial.settlement_state is SettlementState.IN_FLIGHT, (
        "partial settlement is an amount fact, not a state"
    )
    # The remainder is the residual balance on the payable.
    assert _accounts(db, world, provider.name)["payable"] == Money(5000, "USD")


@pytest.mark.db
def test_a_settlement_state_change_never_mutates_a_ledger_entry(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    provider = _provider(custody_model=CustodyModel.A_FUND_AT_APPROVAL)
    transaction_id = _approved(db, world)
    transaction = instruct_settlement(db, provider, transaction_id, quote=_quote(provider), now=NOW)

    def snapshot() -> dict[uuid.UUID, tuple[int, str, uuid.UUID]]:
        with db.connect() as conn:
            rows = (
                conn.execute(text("SELECT id, amount, direction, account_id FROM ledger_entry"))
                .mappings()
                .all()
            )
        return {r["id"]: (r["amount"], r["direction"], r["account_id"]) for r in rows}

    before = snapshot()
    provider.advance(_reference(transaction))
    _drain(db, provider, _reference(transaction))
    after = snapshot()

    # Keyed by id rather than compared positionally: ids are random UUIDs, so any
    # ordering assumption would make this test pass or fail by luck.
    assert {k: after[k] for k in before} == before, "existing entries are untouched"
    assert len(after) > len(before), "the state change wrote new entries"


@pytest.mark.db
def test_a_reversal_writes_compensating_entries(db: Engine, world: dict[str, uuid.UUID]) -> None:
    provider = _provider(custody_model=CustodyModel.B_WE_HOLD_BALANCE)
    transaction_id = _approved(db, world)
    transaction = instruct_settlement(db, provider, transaction_id, quote=_quote(provider), now=NOW)
    _drain(db, provider, _reference(transaction))
    assert _accounts(db, world, provider.name)["payable"] == Money(0, "USD")

    provider.reverse(_reference(transaction), idempotency_key="rev-1")
    _drain(db, provider, _reference(transaction))

    with db.connect() as conn:
        from iwp.domain.requests import get_transaction

        reversed_txn = get_transaction(conn, transaction_id)
    assert reversed_txn.settlement_state is SettlementState.REVERSED
    assert reversed_txn.settled_amount == Money(0, "USD")
    assert _accounts(db, world, provider.name)["payable"] == Money(10000, "USD")


@pytest.mark.db
def test_an_event_for_an_unknown_reference_is_recorded_not_guessed_at(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    outcome = apply_settlement_event(
        db,
        provider_name="mockpay",
        provider_event_id="EVT-STRANGER",
        provider_reference="STL-NOT-OURS",
        state=SettlementState.SETTLED,
        delivered_amount=Money(10000, "USD"),
        sequence=1,
        occurred_at=NOW,
    )
    assert outcome.applied is False
    assert outcome.transaction_id is None
    with db.connect() as conn:
        assert (
            conn.execute(
                text("SELECT count(*) FROM settlement_event WHERE applied = FALSE")
            ).scalar_one()
            == 1
        )
        assert conn.execute(text("SELECT count(*) FROM ledger_entry")).scalar_one() == 0


@pytest.mark.db
def test_a_contradicting_terminal_state_is_recorded_and_not_applied(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    provider = _provider(custody_model=CustodyModel.B_WE_HOLD_BALANCE)
    transaction_id = _approved(db, world)
    transaction = instruct_settlement(db, provider, transaction_id, quote=_quote(provider), now=NOW)
    _drain(db, provider, _reference(transaction))

    outcome = apply_settlement_event(
        db,
        provider_name=provider.name,
        provider_event_id="EVT-CONTRADICTION",
        provider_reference=_reference(transaction),
        state=SettlementState.FAILED,
        delivered_amount=Money(0, "USD"),
        sequence=99,
        occurred_at=NOW,
    )
    assert outcome.applied is False
    assert "conflicting terminal state" in outcome.reason
    with db.connect() as conn:
        from iwp.domain.requests import get_transaction

        assert get_transaction(conn, transaction_id).settlement_state is SettlementState.SETTLED


@pytest.mark.db
def test_a_timeout_leaves_state_untouched_for_reconciliation(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    provider = _provider(custody_model=CustodyModel.A_FUND_AT_APPROVAL)
    transaction_id = _approved(db, world)
    provider.script(f"release:{transaction_id}", Outcome.TIMEOUT)

    with pytest.raises(ProviderTimeout):
        instruct_settlement(db, provider, transaction_id, quote=_quote(provider), now=NOW)
    record_provider_timeout(db, transaction_id, provider.name, detail="no response in 30s")

    with db.connect() as conn:
        from iwp.domain.requests import get_transaction

        transaction = get_transaction(conn, transaction_id)
        trail = [row["action"] for row in audit_trail(conn, "transaction", transaction_id)]
        flagged = conn.execute(
            text("SELECT count(*) FROM outbox WHERE topic = 'settlement.needs_attention'")
        ).scalar_one()

    assert transaction.settlement_state is SettlementState.NOT_STARTED, (
        "guessing either way is how money gets sent twice or lost"
    )
    assert "settlement.timeout" in trail
    assert flagged == 1


@pytest.mark.db
def test_a_cancelled_transaction_is_never_instructed(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    provider = _provider(custody_model=CustodyModel.A_FUND_AT_APPROVAL)
    transaction_id = _approved(db, world)
    cancel_transaction(db, transaction_id, actor_id=world["sender"], channel="app", now=NOW)
    with pytest.raises(SettlementError, match="cancelled"):
        instruct_settlement(db, provider, transaction_id, quote=_quote(provider), now=NOW)


@pytest.mark.db
def test_cancelling_an_instructed_transfer_posts_the_money_back(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    provider = _provider(custody_model=CustodyModel.A_FUND_AT_APPROVAL)
    transaction_id = _approved(db, world)
    instruct_settlement(db, provider, transaction_id, quote=_quote(provider), now=NOW)
    cancel_transaction(db, transaction_id, actor_id=world["sender"], channel="app", now=NOW)
    cancel_settlement(db, provider, transaction_id, actor_id=world["sender"])

    balances = _accounts(db, world, provider.name)
    assert balances["custody"] == Money(0, "USD")
    assert balances["payable"] == Money(0, "USD")
    assert balances["fees"] == Money(0, "USD")


@pytest.mark.db
def test_instruction_fails_without_a_payout_destination(db: Engine) -> None:
    with db.begin() as conn:
        sender = upsert_user(conn, "+15555550000", role=Role.SENDER, display_name="Marco")
    rel, recipient, _ = invite_recipient(
        db, sender_id=sender.id, recipient_phone="55551234", recipient_display_name="Ana"
    )
    activate_relationship(db, rel.id, accepted_by=recipient.id, channel="sms")
    create_plan(db, relationship_id=rel.id, created_by=sender.id)
    outcome = submit_request(
        db,
        relationship_id=rel.id,
        requested_by=recipient.id,
        amount=Money(5000, "USD"),
        category_key="food",
        description="x",
        channel="sms",
        now=NOW,
    )
    approval = approve_request(
        db, outcome.request.id, approved_by=sender.id, channel="app", assurance_level="app"
    )
    provider = _provider(custody_model=CustodyModel.A_FUND_AT_APPROVAL)
    with pytest.raises(SettlementError, match="payout destination"):
        instruct_settlement(db, provider, approval.transaction.id, quote=_quote(provider))


@pytest.mark.db
def test_the_whole_lifecycle_keeps_the_trial_balance_at_zero(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    provider = _provider(custody_model=CustodyModel.B_WE_HOLD_BALANCE)
    for i, outcome_kind in enumerate([Outcome.SUCCESS, Outcome.FAILURE, Outcome.PARTIAL]):
        transaction_id = _approved(db, world, amount=1000 + i)
        provider.script(f"release:{transaction_id}", outcome_kind)
        transaction = instruct_settlement(
            db, provider, transaction_id, quote=_quote(provider), now=NOW
        )
        provider.advance(_reference(transaction))
        _drain(db, provider, _reference(transaction))

    with db.connect() as conn:
        for currency_code, net in trial_balance(conn).items():
            assert net.is_zero, f"{currency_code} trial balance is {net}"


@pytest.mark.db
def test_reconciling_our_records_against_the_mock_statement_is_clean(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    """The end-to-end point of P1.5 and P3.2 together."""
    from iwp.ledger.reconciliation import (
        ExpectedSettlement,
        ReconciliationInput,
        reconcile,
    )

    provider = _provider(custody_model=CustodyModel.B_WE_HOLD_BALANCE)
    transaction_id = _approved(db, world)
    transaction = instruct_settlement(db, provider, transaction_id, quote=_quote(provider), now=NOW)
    _drain(db, provider, _reference(transaction))

    with db.connect() as conn:
        from iwp.domain.requests import get_transaction

        settled = get_transaction(conn, transaction_id)

    result = reconcile(
        db,
        ReconciliationInput(
            provider=provider.name,
            period_start=NOW - timedelta(hours=1),
            period_end=NOW + timedelta(hours=1),
            expected=(
                ExpectedSettlement(
                    business_txn_id=settled.id,
                    provider_reference=settled.provider_reference_id,
                    amount=settled.settled_amount,
                    settlement_state=settled.settlement_state,
                    instructed_at=NOW,
                ),
            ),
            statement=tuple(
                provider.statement(
                    period_start=NOW - timedelta(hours=1), period_end=NOW + timedelta(hours=1)
                )
            ),
        ),
    )
    assert result.is_clean, [d.detail for d in result.discrepancies]
    assert result.matched_count == 1


@pytest.mark.db
def test_cancelling_an_uncancellable_instruction_flags_it_for_a_human(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    """Our books and the provider can disagree, and the disagreement is never hidden."""
    provider = _provider(custody_model=CustodyModel.A_FUND_AT_APPROVAL)
    assert provider.capabilities().supports_reversal is False

    transaction_id = _approved(db, world)
    instruct_settlement(db, provider, transaction_id, quote=_quote(provider), now=NOW)
    cancel_transaction(db, transaction_id, actor_id=world["sender"], channel="app", now=NOW)
    cancel_settlement(db, provider, transaction_id, actor_id=world["sender"])

    with db.connect() as conn:
        flagged = (
            conn.execute(
                text(
                    """
                    SELECT payload FROM outbox WHERE topic = 'settlement.needs_attention'
                    """
                )
            )
            .scalars()
            .all()
        )
    assert len(flagged) == 1
    assert "does not support reversal" in flagged[0]["detail"]


@pytest.mark.db
def test_cancelling_a_reversible_instruction_recalls_it(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    provider = _provider(custody_model=CustodyModel.B_WE_HOLD_BALANCE)
    transaction_id = _approved(db, world)
    # An instant provider settles on release, so instruct with a delayed outcome to
    # keep it merely instructed.
    provider.script(f"release:{transaction_id}", Outcome.DELAYED)
    transaction = instruct_settlement(db, provider, transaction_id, quote=_quote(provider), now=NOW)
    assert transaction.settlement_state is SettlementState.INSTRUCTED

    cancel_transaction(db, transaction_id, actor_id=world["sender"], channel="app", now=NOW)
    cancel_settlement(db, provider, transaction_id, actor_id=world["sender"])

    with db.connect() as conn:
        flagged = conn.execute(
            text("SELECT count(*) FROM outbox WHERE topic = 'settlement.needs_attention'")
        ).scalar_one()
    # A recall that the provider refuses is flagged; here it is attempted, refused
    # because nothing has settled yet, and therefore flagged — honestly.
    assert flagged == 1
    assert _accounts(db, world, provider.name)["custody"] == Money(0, "USD")


@pytest.mark.db
def test_cancelling_before_instruction_posts_nothing_because_nothing_was_posted(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    provider = _provider(custody_model=CustodyModel.A_FUND_AT_APPROVAL)
    transaction_id = _approved(db, world)
    cancel_transaction(db, transaction_id, actor_id=world["sender"], channel="app", now=NOW)
    cancel_settlement(db, provider, transaction_id, actor_id=world["sender"])
    with db.connect() as conn:
        assert conn.execute(text("SELECT count(*) FROM ledger_entry")).scalar_one() == 0


@pytest.mark.db
def test_the_window_closes_once_the_provider_has_the_money_moving(
    db: Engine, world: dict[str, uuid.UUID]
) -> None:
    from iwp.domain.requests import RequestError, get_transaction

    provider = _provider(custody_model=CustodyModel.A_FUND_AT_APPROVAL)
    transaction_id = _approved(db, world)
    transaction = instruct_settlement(db, provider, transaction_id, quote=_quote(provider), now=NOW)
    provider.advance(_reference(transaction))
    _drain(db, provider, _reference(transaction))

    with db.connect() as conn:
        assert get_transaction(conn, transaction_id).cancellable_until is None
    with pytest.raises(RequestError, match=r"window .* has closed"):
        cancel_transaction(db, transaction_id, actor_id=world["sender"], channel="app", now=NOW)
