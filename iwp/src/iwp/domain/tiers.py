"""P2.3 — trust tier classification.

A pure function. Same inputs, same tier, every time, with no database access and no
side effects — which is what makes it exhaustively testable and safe to run on every
channel, including inside a message handler that may be retried.

**It never rejects anything.** Every outcome is either "auto-approve" or "ask the
sender". PRD Feature 2 is explicit that a request over its recurring amount is
"flagged for manual approval, never auto-rejected", and the product framing (PRD §7)
is a shared agreement, not a gate that slams.

The caller assembles the snapshot from the plan version in force and the month-to-date
spend; this module never reads either for itself.
"""

from __future__ import annotations

import enum
from dataclasses import dataclass

from iwp.domain.plans import RuleStatus
from iwp.money import Money

__all__ = [
    "CategorySnapshot",
    "RuleSnapshot",
    "TierDecision",
    "TierInput",
    "TierReason",
    "TrustTier",
    "classify",
]


class TrustTier(enum.Enum):
    """PRD §7."""

    RECURRING = "recurring"
    """Pre-approved, on schedule, within parameters. Auto-approved."""

    PLANNED_INVESTMENT = "planned_investment"
    """Large, milestone-gated. **P1 — never returned at MVP.** PRD §7 marks the
    verification-and-release mechanism as P1, so classifying into this tier would route
    a request to a hold path that does not exist yet."""

    EMERGENCY = "emergency"
    """Marked urgent by the recipient. Priority notification, one-action approval."""

    UNRECOGNIZED = "unrecognized"
    """Outside the plan or over a limit. Flagged for approval — never rejected."""


class TierReason(enum.Enum):
    """Why a request landed in its tier.

    Carried onto the request row and into the message the sender sees, so "why am I
    being asked about this?" always has an answer.
    """

    EMERGENCY_MARKED = "emergency_marked"
    WITHIN_ACTIVE_RULE = "within_active_rule"
    OVER_RULE_AMOUNT = "over_rule_amount"
    OVER_MONTHLY_CAP = "over_monthly_cap"
    RULE_PAUSED = "rule_paused"
    NO_RULE_FOR_CATEGORY = "no_rule_for_category"
    CATEGORY_NOT_IN_PLAN = "category_not_in_plan"


@dataclass(frozen=True, slots=True)
class CategorySnapshot:
    """A category of the plan version in force, and its cap if it has one."""

    key: str
    monthly_cap: Money | None


@dataclass(frozen=True, slots=True)
class RuleSnapshot:
    """A recurring rule as it stands right now."""

    category_key: str
    amount: Money
    status: RuleStatus


@dataclass(frozen=True, slots=True)
class TierInput:
    amount: Money
    category_key: str | None
    is_emergency: bool
    categories: tuple[CategorySnapshot, ...]
    rules: tuple[RuleSnapshot, ...]
    month_to_date: Money
    """Already spent in this category this month, before this request."""


@dataclass(frozen=True, slots=True)
class TierDecision:
    tier: TrustTier
    reason: TierReason
    note: str
    """Plain-language, Guatemalan Spanish. Shown to the sender with the request."""

    @property
    def requires_approval(self) -> bool:
        """Everything except a recurring request waits for the sender.

        Emergency included: PRD Feature 3 makes emergency approval *one action*, not
        *no action*.
        """
        return self.tier is not TrustTier.RECURRING


def classify(data: TierInput) -> TierDecision:
    """Classify a request into a trust tier.

    Order matters. Emergency is checked first because PRD Feature 3 says emergency
    "removes the plan-match gate" — an urgent request is urgent whether or not it fits
    the plan.
    """
    _assert_one_currency(data)

    if data.is_emergency:
        return TierDecision(
            tier=TrustTier.EMERGENCY,
            reason=TierReason.EMERGENCY_MARKED,
            note="Marcado como urgente. Te avisamos de inmediato.",
        )

    category = _find_category(data)
    if category is None:
        return TierDecision(
            tier=TrustTier.UNRECOGNIZED,
            reason=TierReason.CATEGORY_NOT_IN_PLAN,
            note="Esta categoría no está en el plan. Necesita tu aprobación.",
        )

    # Cancelled rules are gone, not paused: a cancelled rule tells the recipient
    # nothing about when it might come back, so saying "paused" would be misleading.
    live = [
        r
        for r in data.rules
        if r.category_key == category.key and r.status is not RuleStatus.CANCELLED
    ]
    if not live:
        return TierDecision(
            tier=TrustTier.UNRECOGNIZED,
            reason=TierReason.NO_RULE_FOR_CATEGORY,
            note="No hay un envío programado para esta categoría. Necesita tu aprobación.",
        )

    active = [r for r in live if r.status is RuleStatus.ACTIVE]
    if not active:
        return TierDecision(
            tier=TrustTier.UNRECOGNIZED,
            reason=TierReason.RULE_PAUSED,
            note=(
                "La regla de esta categoría está pausada, así que esta solicitud "
                "necesita tu aprobación."
            ),
        )

    # A category may carry more than one rule — weekly groceries alongside a monthly
    # top-up. The request fits if it fits any of them.
    largest = max(active, key=lambda r: r.amount.minor_units)
    if data.amount > largest.amount:
        return TierDecision(
            tier=TrustTier.UNRECOGNIZED,
            reason=TierReason.OVER_RULE_AMOUNT,
            note=(
                f"Es más de lo programado ({largest.amount.to_decimal_string()}), "
                "así que necesita tu aprobación."
            ),
        )

    if category.monthly_cap is not None:
        after = data.month_to_date + data.amount
        if after > category.monthly_cap:
            return TierDecision(
                tier=TrustTier.UNRECOGNIZED,
                reason=TierReason.OVER_MONTHLY_CAP,
                note=(
                    "Con esta solicitud se pasa del límite del mes "
                    f"({category.monthly_cap.to_decimal_string()}), "
                    "así que necesita tu aprobación."
                ),
            )

    return TierDecision(
        tier=TrustTier.RECURRING,
        reason=TierReason.WITHIN_ACTIVE_RULE,
        note="Dentro de lo acordado. Se aprueba automáticamente.",
    )


def _find_category(data: TierInput) -> CategorySnapshot | None:
    if data.category_key is None:
        return None
    return next((c for c in data.categories if c.key == data.category_key), None)


def _assert_one_currency(data: TierInput) -> None:
    """Every amount in one classification must share a currency.

    A mismatch here is a programming error in the caller that assembled the snapshot,
    not a business outcome, so it raises rather than producing a tier. Letting it
    through would compare minor units across currencies and silently assume a rate of 1.
    """
    expected = data.amount.currency
    if data.month_to_date.currency is not expected:
        raise ValueError(
            "mixed currency in one classification: month_to_date is "
            f"{data.month_to_date.currency.code}, request is {expected.code}"
        )
    for category in data.categories:
        if category.monthly_cap is not None and category.monthly_cap.currency is not expected:
            raise ValueError(
                f"mixed currency in one classification: cap on category {category.key} "
                f"is {category.monthly_cap.currency.code}, request is {expected.code}"
            )
    for rule in data.rules:
        if rule.amount.currency is not expected:
            raise ValueError(
                f"mixed currency in one classification: rule for {rule.category_key} "
                f"is {rule.amount.currency.code}, request is {expected.code}"
            )
