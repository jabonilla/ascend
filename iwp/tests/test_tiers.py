"""P2.3 — trust tier classification.

Invariants under test:
  * deterministic and side-effect free
  * same inputs always produce the same tier
  * never auto-rejects — over-cap requests flag for approval

Table-driven and exhaustive, because it is a pure function and there is no excuse not
to be.
"""

from __future__ import annotations

import pytest
from hypothesis import given
from hypothesis import strategies as st

from iwp.domain.plans import RuleStatus
from iwp.domain.tiers import (
    CategorySnapshot,
    RuleSnapshot,
    TierInput,
    TierReason,
    TrustTier,
    classify,
)
from iwp.money import Money

USD = "USD"


def _input(
    *,
    amount: int = 20000,
    category_key: str | None = "food",
    is_emergency: bool = False,
    cap: int | None = None,
    rule_amount: int | None = 25000,
    rule_status: RuleStatus = RuleStatus.ACTIVE,
    month_to_date: int = 0,
    category_in_plan: bool = True,
) -> TierInput:
    categories = (
        (CategorySnapshot(key="food", monthly_cap=None if cap is None else Money(cap, USD)),)
        if category_in_plan
        else ()
    )
    rules = (
        (RuleSnapshot(category_key="food", amount=Money(rule_amount, USD), status=rule_status),)
        if rule_amount is not None
        else ()
    )
    return TierInput(
        amount=Money(amount, USD),
        category_key=category_key,
        is_emergency=is_emergency,
        categories=categories,
        rules=rules,
        month_to_date=Money(month_to_date, USD),
    )


# --------------------------------------------------------------------------------------
# the five acceptance criteria
# --------------------------------------------------------------------------------------


def test_within_an_active_recurring_rule_and_under_cap_is_recurring() -> None:
    decision = classify(_input(amount=20000, rule_amount=25000, cap=100000))
    assert decision.tier is TrustTier.RECURRING
    assert decision.reason is TierReason.WITHIN_ACTIVE_RULE
    assert decision.requires_approval is False


def test_a_recurring_category_over_cap_is_flagged_not_rejected() -> None:
    decision = classify(_input(amount=20000, rule_amount=25000, cap=30000, month_to_date=20000))
    assert decision.tier is TrustTier.UNRECOGNIZED
    assert decision.reason is TierReason.OVER_MONTHLY_CAP
    assert decision.requires_approval is True


def test_a_paused_recurring_rule_is_unrecognized_with_a_paused_note() -> None:
    decision = classify(_input(rule_status=RuleStatus.PAUSED))
    assert decision.tier is TrustTier.UNRECOGNIZED
    assert decision.reason is TierReason.RULE_PAUSED
    assert "pausada" in decision.note.lower() or "paused" in decision.note.lower()


def test_marked_urgent_by_the_recipient_is_emergency() -> None:
    decision = classify(_input(is_emergency=True))
    assert decision.tier is TrustTier.EMERGENCY
    assert decision.reason is TierReason.EMERGENCY_MARKED
    assert decision.requires_approval is True


def test_a_category_not_in_the_plan_is_unrecognized() -> None:
    decision = classify(_input(category_key="yacht"))
    assert decision.tier is TrustTier.UNRECOGNIZED
    assert decision.reason is TierReason.CATEGORY_NOT_IN_PLAN


# --------------------------------------------------------------------------------------
# emergency precedence
# --------------------------------------------------------------------------------------


@pytest.mark.parametrize(
    "kwargs",
    [
        {},
        {"category_key": "yacht"},
        {"rule_status": RuleStatus.PAUSED},
        {"rule_amount": None},
        {"amount": 999999, "cap": 100},
        {"category_in_plan": False},
    ],
)
def test_emergency_removes_the_plan_match_gate_whatever_else_is_true(
    kwargs: dict[str, object],
) -> None:
    # PRD Feature 3: "Emergency removes the plan-match gate."
    decision = classify(_input(is_emergency=True, **kwargs))  # type: ignore[arg-type]
    assert decision.tier is TrustTier.EMERGENCY


# --------------------------------------------------------------------------------------
# the rest of the decision table
# --------------------------------------------------------------------------------------


def test_no_rule_for_a_planned_category_is_unrecognized() -> None:
    decision = classify(_input(rule_amount=None))
    assert decision.tier is TrustTier.UNRECOGNIZED
    assert decision.reason is TierReason.NO_RULE_FOR_CATEGORY


def test_a_cancelled_rule_reads_as_no_rule_not_as_paused() -> None:
    decision = classify(_input(rule_status=RuleStatus.CANCELLED))
    assert decision.reason is TierReason.NO_RULE_FOR_CATEGORY


def test_over_the_rule_amount_is_flagged_not_rejected() -> None:
    # PRD Feature 2: "exceeding the approved amount are flagged for manual approval,
    # never auto-rejected".
    decision = classify(_input(amount=30000, rule_amount=25000))
    assert decision.tier is TrustTier.UNRECOGNIZED
    assert decision.reason is TierReason.OVER_RULE_AMOUNT
    assert decision.requires_approval is True


def test_exactly_the_rule_amount_is_within_the_rule() -> None:
    assert classify(_input(amount=25000, rule_amount=25000)).tier is TrustTier.RECURRING


def test_spending_exactly_up_to_the_cap_is_within_it() -> None:
    decision = classify(_input(amount=10000, rule_amount=25000, cap=30000, month_to_date=20000))
    assert decision.tier is TrustTier.RECURRING


def test_one_minor_unit_over_the_cap_is_flagged() -> None:
    decision = classify(_input(amount=10001, rule_amount=25000, cap=30000, month_to_date=20000))
    assert decision.reason is TierReason.OVER_MONTHLY_CAP


def test_no_cap_means_no_cap_check() -> None:
    decision = classify(_input(amount=25000, rule_amount=25000, cap=None, month_to_date=10**9))
    assert decision.tier is TrustTier.RECURRING


def test_a_missing_category_is_unrecognized_rather_than_an_error() -> None:
    # SMS requests may arrive without one. A dead end is never acceptable (PRD Feature 4).
    decision = classify(_input(category_key=None))
    assert decision.tier is TrustTier.UNRECOGNIZED
    assert decision.reason is TierReason.CATEGORY_NOT_IN_PLAN


def test_the_largest_fitting_rule_wins_when_a_category_has_several() -> None:
    data = TierInput(
        amount=Money(30000, USD),
        category_key="food",
        is_emergency=False,
        categories=(CategorySnapshot(key="food", monthly_cap=None),),
        rules=(
            RuleSnapshot(category_key="food", amount=Money(10000, USD), status=RuleStatus.ACTIVE),
            RuleSnapshot(category_key="food", amount=Money(40000, USD), status=RuleStatus.ACTIVE),
        ),
        month_to_date=Money(0, USD),
    )
    assert classify(data).tier is TrustTier.RECURRING


def test_over_every_rule_for_a_category_is_over_the_rule_amount() -> None:
    data = TierInput(
        amount=Money(50000, USD),
        category_key="food",
        is_emergency=False,
        categories=(CategorySnapshot(key="food", monthly_cap=None),),
        rules=(
            RuleSnapshot(category_key="food", amount=Money(10000, USD), status=RuleStatus.ACTIVE),
            RuleSnapshot(category_key="food", amount=Money(40000, USD), status=RuleStatus.ACTIVE),
        ),
        month_to_date=Money(0, USD),
    )
    decision = classify(data)
    assert decision.reason is TierReason.OVER_RULE_AMOUNT
    assert "400.00" in decision.note, "the note names the limit the request exceeded"


def test_a_paused_rule_alongside_an_active_one_does_not_mask_the_active_one() -> None:
    data = TierInput(
        amount=Money(20000, USD),
        category_key="food",
        is_emergency=False,
        categories=(CategorySnapshot(key="food", monthly_cap=None),),
        rules=(
            RuleSnapshot(category_key="food", amount=Money(90000, USD), status=RuleStatus.PAUSED),
            RuleSnapshot(category_key="food", amount=Money(25000, USD), status=RuleStatus.ACTIVE),
        ),
        month_to_date=Money(0, USD),
    )
    assert classify(data).tier is TrustTier.RECURRING


def test_rules_for_other_categories_are_ignored() -> None:
    data = TierInput(
        amount=Money(20000, USD),
        category_key="food",
        is_emergency=False,
        categories=(CategorySnapshot(key="food", monthly_cap=None),),
        rules=(
            RuleSnapshot(
                category_key="housing", amount=Money(90000, USD), status=RuleStatus.ACTIVE
            ),
        ),
        month_to_date=Money(0, USD),
    )
    assert classify(data).reason is TierReason.NO_RULE_FOR_CATEGORY


# --------------------------------------------------------------------------------------
# the classifier never rejects, and never has side effects
# --------------------------------------------------------------------------------------


@given(
    amount=st.integers(min_value=1, max_value=10**9),
    cap=st.one_of(st.none(), st.integers(min_value=1, max_value=10**6)),
    rule_amount=st.one_of(st.none(), st.integers(min_value=1, max_value=10**6)),
    rule_status=st.sampled_from(list(RuleStatus)),
    month_to_date=st.integers(min_value=0, max_value=10**9),
    is_emergency=st.booleans(),
    category_key=st.sampled_from(["food", "yacht", None]),
)
def test_property_classification_never_rejects_and_always_returns_a_tier(
    amount: int,
    cap: int | None,
    rule_amount: int | None,
    rule_status: RuleStatus,
    month_to_date: int,
    is_emergency: bool,
    category_key: str | None,
) -> None:
    data = _input(
        amount=amount,
        cap=cap,
        rule_amount=rule_amount,
        rule_status=rule_status,
        month_to_date=month_to_date,
        is_emergency=is_emergency,
        category_key=category_key,
    )
    decision = classify(data)
    assert isinstance(decision.tier, TrustTier)
    assert decision.note
    # Nothing is ever rejected outright: everything is either auto-approved or flagged
    # for a person.
    assert decision.requires_approval or decision.tier is TrustTier.RECURRING


@given(
    amount=st.integers(min_value=1, max_value=10**9),
    rule_amount=st.integers(min_value=1, max_value=10**6),
    month_to_date=st.integers(min_value=0, max_value=10**6),
)
def test_property_classification_is_deterministic(
    amount: int, rule_amount: int, month_to_date: int
) -> None:
    data = _input(amount=amount, rule_amount=rule_amount, month_to_date=month_to_date)
    assert classify(data) == classify(data) == classify(data)


def test_the_planned_investment_tier_is_never_returned_at_mvp() -> None:
    # PRD §7 marks it P1 ("Held, released on verification (P1)"). If the classifier
    # started returning it, requests would route to a hold path that does not exist.
    seen = set()
    for emergency in (True, False):
        for key in ("food", "yacht", None):
            for status in RuleStatus:
                for amount in (1, 20000, 10**9):
                    seen.add(
                        classify(
                            _input(
                                amount=amount,
                                is_emergency=emergency,
                                category_key=key,
                                rule_status=status,
                            )
                        ).tier
                    )
    assert TrustTier.PLANNED_INVESTMENT not in seen


def test_mixing_currencies_is_a_programming_error_not_a_tier() -> None:
    data = TierInput(
        amount=Money(20000, "GTQ"),
        category_key="food",
        is_emergency=False,
        categories=(CategorySnapshot(key="food", monthly_cap=Money(30000, USD)),),
        rules=(
            RuleSnapshot(category_key="food", amount=Money(25000, USD), status=RuleStatus.ACTIVE),
        ),
        month_to_date=Money(0, USD),
    )
    with pytest.raises(ValueError, match="currency"):
        classify(data)
