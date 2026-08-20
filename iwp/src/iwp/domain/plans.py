"""P2.2 — money plans with immutable versioning.

A plan is a shared agreement about what money is for (PRD Feature 1). It changes over
time, and the record of what it said *at the time* has to survive those changes —
otherwise a transaction from March gets explained by April's rules, and the whole
premise of "senders see what every dollar was for" quietly stops being true.

So:

* ``PlanVersion`` and ``Category`` rows are immutable, enforced by database trigger.
* Editing a plan writes a **new** version and moves a pointer on ``money_plan``. The
  active version is that pointer, never a flag on the version rows — a flag can be true
  on two rows at once.
* A request records the concrete ``category_id`` of the version in force when it was
  made, so "resolve against the plan version in effect at the time" is structural
  rather than something a query has to remember to do.
"""

from __future__ import annotations

import enum
import uuid
from dataclasses import dataclass
from datetime import datetime
from typing import Final

from sqlalchemy import Engine, text
from sqlalchemy.engine import Connection, RowMapping

from iwp.domain.audit import write_audit
from iwp.money import Money

__all__ = [
    "DEFAULT_CATEGORIES",
    "Cadence",
    "Category",
    "CategorySpec",
    "PlanError",
    "PlanVersion",
    "RecurringRule",
    "RuleStatus",
    "cancel_rule",
    "create_plan",
    "create_recurring_rule",
    "get_active_version",
    "get_version",
    "list_rules",
    "pause_rule",
    "plan_history",
    "plan_version_for_category",
    "resume_rule",
    "revise_plan",
]


class PlanError(Exception):
    """A plan could not be created or revised."""


class Cadence(enum.Enum):
    WEEKLY = "weekly"
    BIWEEKLY = "biweekly"
    MONTHLY = "monthly"


class RuleStatus(enum.Enum):
    ACTIVE = "active"
    PAUSED = "paused"
    CANCELLED = "cancelled"


@dataclass(frozen=True, slots=True)
class CategorySpec:
    """What a category should be. The input to creating a plan version."""

    key: str
    name: str
    icon: str = ""
    monthly_cap: Money | None = None
    is_system: bool = True

    def __post_init__(self) -> None:
        if not self.key or not self.key.islower() or " " in self.key:
            raise ValueError(f"category key must be a lowercase slug, got {self.key!r}")
        if not self.name:
            raise ValueError("category name is required")
        if self.monthly_cap is not None and not self.monthly_cap.is_positive:
            raise ValueError("a monthly cap must be positive; use None for no cap")


@dataclass(frozen=True, slots=True)
class Category:
    """A category as it exists in one plan version."""

    id: uuid.UUID
    plan_version_id: uuid.UUID
    key: str
    name: str
    icon: str
    monthly_cap: Money | None
    is_system: bool


@dataclass(frozen=True, slots=True)
class PlanVersion:
    id: uuid.UUID
    plan_id: uuid.UUID
    version_number: int
    created_by: uuid.UUID
    created_at: datetime
    change_note: str
    categories: tuple[Category, ...]

    def category(self, key: str) -> Category | None:
        return next((c for c in self.categories if c.key == key), None)


@dataclass(frozen=True, slots=True)
class RecurringRule:
    id: uuid.UUID
    plan_id: uuid.UUID
    category_key: str
    amount: Money
    cadence: Cadence
    status: RuleStatus
    next_run_at: datetime | None


# PRD Feature 1: "categories: Housing, Food, Business, Savings, Other". Caps are
# optional and set by the sender, so none is defined here.
DEFAULT_CATEGORIES: Final[tuple[CategorySpec, ...]] = (
    CategorySpec(key="housing", name="Vivienda", icon="house"),
    CategorySpec(key="food", name="Comida", icon="basket"),
    CategorySpec(key="business", name="Negocio", icon="shop"),
    CategorySpec(key="savings", name="Ahorro", icon="piggy-bank"),
    CategorySpec(key="other", name="Otro", icon="dots"),
)


# --------------------------------------------------------------------------------------
# creating and revising
# --------------------------------------------------------------------------------------


def create_plan(
    engine: Engine,
    *,
    relationship_id: uuid.UUID,
    created_by: uuid.UUID,
    categories: tuple[CategorySpec, ...] = DEFAULT_CATEGORIES,
    currency: str = "USD",
) -> PlanVersion:
    """Create a plan for a relationship with its first version.

    One plan per relationship (PRD §9). Called twice, the second call is an error
    rather than a second plan: two plans for one relationship would make "the" cap
    ambiguous.
    """
    with engine.begin() as conn:
        existing = conn.execute(
            text("SELECT id FROM money_plan WHERE relationship_id = :r"),
            {"r": relationship_id},
        ).scalar_one_or_none()
        if existing is not None:
            raise PlanError(f"relationship {relationship_id} already has a plan")

        plan_id = conn.execute(
            text("INSERT INTO money_plan (relationship_id) VALUES (:r) RETURNING id"),
            {"r": relationship_id},
        ).scalar_one()
        return _write_version(
            conn,
            plan_id=plan_id,
            created_by=created_by,
            categories=categories,
            currency=currency,
            change_note="plan created",
            version_number=1,
        )


def revise_plan(
    engine: Engine,
    *,
    plan_id: uuid.UUID,
    created_by: uuid.UUID,
    categories: tuple[CategorySpec, ...],
    change_note: str,
    currency: str = "USD",
) -> PlanVersion:
    """Write a new version. The previous version is untouched and stays queryable."""
    if not change_note.strip():
        raise PlanError("a plan revision must say what changed")

    with engine.begin() as conn:
        current = conn.execute(
            text(
                """
                SELECT COALESCE(MAX(version_number), 0) AS n
                FROM plan_version WHERE plan_id = :p
                """
            ),
            {"p": plan_id},
        ).scalar_one()
        if current == 0:
            raise PlanError(f"no such plan: {plan_id}")
        return _write_version(
            conn,
            plan_id=plan_id,
            created_by=created_by,
            categories=categories,
            currency=currency,
            change_note=change_note.strip(),
            version_number=int(current) + 1,
        )


def _write_version(
    conn: Connection,
    *,
    plan_id: uuid.UUID,
    created_by: uuid.UUID,
    categories: tuple[CategorySpec, ...],
    currency: str,
    change_note: str,
    version_number: int,
) -> PlanVersion:
    if not categories:
        raise PlanError("a plan version needs at least one category")
    keys = [c.key for c in categories]
    if len(set(keys)) != len(keys):
        raise PlanError(f"duplicate category keys in one version: {keys}")
    for spec in categories:
        if spec.monthly_cap is not None and spec.monthly_cap.currency.code != currency:
            raise PlanError(
                f"category {spec.key} has a {spec.monthly_cap.currency.code} cap on a "
                f"{currency} plan"
            )

    version_id = conn.execute(
        text(
            """
            INSERT INTO plan_version (plan_id, version_number, created_by, change_note)
            VALUES (:plan_id, :version_number, :created_by, :note)
            RETURNING id
            """
        ),
        {
            "plan_id": plan_id,
            "version_number": version_number,
            "created_by": created_by,
            "note": change_note,
        },
    ).scalar_one()

    for order, spec in enumerate(categories):
        conn.execute(
            text(
                """
                INSERT INTO category
                    (plan_version_id, category_key, name, icon, monthly_cap,
                     currency, is_system, display_order)
                VALUES (:v, :key, :name, :icon, :cap, :currency, :is_system, :order)
                """
            ),
            {
                "v": version_id,
                "key": spec.key,
                "name": spec.name,
                "icon": spec.icon,
                "cap": spec.monthly_cap.minor_units if spec.monthly_cap else None,
                "currency": currency,
                "is_system": spec.is_system,
                "order": order,
            },
        )

    # The pointer move is the only thing that makes this version active.
    conn.execute(
        text("UPDATE money_plan SET current_version_id = :v WHERE id = :p"),
        {"v": version_id, "p": plan_id},
    )
    write_audit(
        conn,
        action="plan.version_created",
        entity_type="money_plan",
        entity_id=plan_id,
        actor_id=created_by,
        after_state={
            "version_number": version_number,
            "version_id": str(version_id),
            "change_note": change_note,
            "categories": [
                {
                    "key": c.key,
                    "name": c.name,
                    "monthly_cap": c.monthly_cap.minor_units if c.monthly_cap else None,
                }
                for c in categories
            ],
        },
    )
    return _load_version(conn, version_id)


# --------------------------------------------------------------------------------------
# reading
# --------------------------------------------------------------------------------------

_VERSION_SQL = """
SELECT id, plan_id, version_number, created_by, created_at, change_note
FROM plan_version WHERE id = :id
"""


def _row_to_category(row: RowMapping) -> Category:
    cap = row["monthly_cap"]
    return Category(
        id=row["id"],
        plan_version_id=row["plan_version_id"],
        key=row["category_key"],
        name=row["name"],
        icon=row["icon"],
        monthly_cap=None if cap is None else Money(int(cap), str(row["currency"])),
        is_system=row["is_system"],
    )


def _load_version(conn: Connection, version_id: uuid.UUID) -> PlanVersion:
    row = conn.execute(text(_VERSION_SQL), {"id": version_id}).mappings().one_or_none()
    if row is None:
        raise LookupError(f"no such plan version: {version_id}")
    categories = (
        conn.execute(
            text(
                """
                SELECT id, plan_version_id, category_key, name, icon, monthly_cap,
                       currency, is_system
                FROM category WHERE plan_version_id = :v ORDER BY display_order, category_key
                """
            ),
            {"v": version_id},
        )
        .mappings()
        .all()
    )
    return PlanVersion(
        id=row["id"],
        plan_id=row["plan_id"],
        version_number=row["version_number"],
        created_by=row["created_by"],
        created_at=row["created_at"],
        change_note=row["change_note"],
        categories=tuple(_row_to_category(c) for c in categories),
    )


def get_version(conn: Connection, version_id: uuid.UUID) -> PlanVersion:
    return _load_version(conn, version_id)


def get_active_version(conn: Connection, plan_id: uuid.UUID) -> PlanVersion:
    """The version the pointer currently names."""
    version_id = conn.execute(
        text("SELECT current_version_id FROM money_plan WHERE id = :p"), {"p": plan_id}
    ).scalar_one_or_none()
    if version_id is None:
        raise LookupError(f"no active version for plan {plan_id}")
    return _load_version(conn, version_id)


def get_plan_for_relationship(conn: Connection, relationship_id: uuid.UUID) -> uuid.UUID | None:
    result: uuid.UUID | None = conn.execute(
        text("SELECT id FROM money_plan WHERE relationship_id = :r"), {"r": relationship_id}
    ).scalar_one_or_none()
    return result


def plan_history(conn: Connection, plan_id: uuid.UUID) -> list[PlanVersion]:
    """Every version of a plan, oldest first. Who changed what, when."""
    ids = (
        conn.execute(
            text("SELECT id FROM plan_version WHERE plan_id = :p ORDER BY version_number"),
            {"p": plan_id},
        )
        .scalars()
        .all()
    )
    return [_load_version(conn, version_id) for version_id in ids]


def plan_version_for_category(conn: Connection, category_id: uuid.UUID) -> PlanVersion:
    """The version a given category row belongs to.

    This is how a historical transaction resolves against the rules in force when it
    happened: it holds a category id, and a category id belongs to exactly one version.
    """
    version_id = conn.execute(
        text("SELECT plan_version_id FROM category WHERE id = :c"), {"c": category_id}
    ).scalar_one_or_none()
    if version_id is None:
        raise LookupError(f"no such category: {category_id}")
    return _load_version(conn, version_id)


# --------------------------------------------------------------------------------------
# recurring rules
# --------------------------------------------------------------------------------------


def _row_to_rule(row: RowMapping) -> RecurringRule:
    return RecurringRule(
        id=row["id"],
        plan_id=row["plan_id"],
        category_key=row["category_key"],
        amount=Money(int(row["amount"]), str(row["currency"])),
        cadence=Cadence(row["cadence"]),
        status=RuleStatus(row["status"]),
        next_run_at=row["next_run_at"],
    )


def create_recurring_rule(
    engine: Engine,
    *,
    plan_id: uuid.UUID,
    category_key: str,
    amount: Money,
    cadence: Cadence,
    actor_id: uuid.UUID,
    next_run_at: datetime | None = None,
) -> RecurringRule:
    """Create a schedule (PRD Feature 2).

    Keyed by ``category_key`` rather than a category id, because the rule has to
    survive the plan being revised.
    """
    if not amount.is_positive:
        raise PlanError("a recurring amount must be positive")

    with engine.begin() as conn:
        active = get_active_version(conn, plan_id)
        if active.category(category_key) is None:
            raise PlanError(
                f"category {category_key!r} is not in the active plan version; "
                "add it to the plan before scheduling against it"
            )
        rule_id = conn.execute(
            text(
                """
                INSERT INTO recurring_rule
                    (plan_id, category_key, amount, currency, cadence, next_run_at)
                VALUES (:p, :key, :amount, :currency, :cadence, :next_run_at)
                RETURNING id
                """
            ),
            {
                "p": plan_id,
                "key": category_key,
                "amount": amount.minor_units,
                "currency": amount.currency.code,
                "cadence": cadence.value,
                "next_run_at": next_run_at,
            },
        ).scalar_one()
        write_audit(
            conn,
            action="recurring_rule.created",
            entity_type="recurring_rule",
            entity_id=rule_id,
            actor_id=actor_id,
            after_state={
                "category_key": category_key,
                "amount": amount.minor_units,
                "currency": amount.currency.code,
                "cadence": cadence.value,
                "status": RuleStatus.ACTIVE.value,
            },
        )
        return _load_rule(conn, rule_id)


def _load_rule(conn: Connection, rule_id: uuid.UUID) -> RecurringRule:
    row = (
        conn.execute(
            text(
                """
                SELECT id, plan_id, category_key, amount, currency, cadence, status,
                       next_run_at
                FROM recurring_rule WHERE id = :id
                """
            ),
            {"id": rule_id},
        )
        .mappings()
        .one_or_none()
    )
    if row is None:
        raise LookupError(f"no such recurring rule: {rule_id}")
    return _row_to_rule(row)


_LEGAL_RULE_TRANSITIONS: dict[RuleStatus, frozenset[RuleStatus]] = {
    RuleStatus.ACTIVE: frozenset({RuleStatus.PAUSED, RuleStatus.CANCELLED}),
    RuleStatus.PAUSED: frozenset({RuleStatus.ACTIVE, RuleStatus.CANCELLED}),
    RuleStatus.CANCELLED: frozenset(),
}


def _set_rule_status(
    engine: Engine, rule_id: uuid.UUID, target: RuleStatus, *, actor_id: uuid.UUID
) -> RecurringRule:
    with engine.begin() as conn:
        current = _load_rule(conn, rule_id)
        if current.status is target:
            return current
        if target not in _LEGAL_RULE_TRANSITIONS[current.status]:
            raise PlanError(
                f"cannot move rule {rule_id} from {current.status.value} to {target.value}"
            )
        conn.execute(
            text("UPDATE recurring_rule SET status = :s, updated_at = now() WHERE id = :id"),
            {"s": target.value, "id": rule_id},
        )
        write_audit(
            conn,
            action=f"recurring_rule.{target.value}",
            entity_type="recurring_rule",
            entity_id=rule_id,
            actor_id=actor_id,
            before_state={"status": current.status.value},
            after_state={"status": target.value},
        )
        return _load_rule(conn, rule_id)


def pause_rule(engine: Engine, rule_id: uuid.UUID, *, actor_id: uuid.UUID) -> RecurringRule:
    return _set_rule_status(engine, rule_id, RuleStatus.PAUSED, actor_id=actor_id)


def resume_rule(engine: Engine, rule_id: uuid.UUID, *, actor_id: uuid.UUID) -> RecurringRule:
    return _set_rule_status(engine, rule_id, RuleStatus.ACTIVE, actor_id=actor_id)


def cancel_rule(engine: Engine, rule_id: uuid.UUID, *, actor_id: uuid.UUID) -> RecurringRule:
    return _set_rule_status(engine, rule_id, RuleStatus.CANCELLED, actor_id=actor_id)


def list_rules(
    conn: Connection, plan_id: uuid.UUID, *, include_cancelled: bool = False
) -> list[RecurringRule]:
    clause = "" if include_cancelled else " AND status <> 'cancelled'"
    rows = (
        conn.execute(
            text(
                """
                SELECT id, plan_id, category_key, amount, currency, cadence, status,
                       next_run_at
                FROM recurring_rule WHERE plan_id = :p
                """
                + clause
                + " ORDER BY category_key"
            ),
            {"p": plan_id},
        )
        .mappings()
        .all()
    )
    return [_row_to_rule(row) for row in rows]
