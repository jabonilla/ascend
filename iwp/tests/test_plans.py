"""P2.2 — money plans with immutable versioning.

Acceptance criteria under test:
  * editing a plan creates a new version and preserves the old one
  * historical transactions resolve against the plan version in effect at their time
  * plan history shows who changed what, when
"""

from __future__ import annotations

import uuid

import pytest
from sqlalchemy import Engine, text
from sqlalchemy.exc import DBAPIError

from iwp.domain.audit import audit_trail
from iwp.domain.plans import (
    DEFAULT_CATEGORIES,
    Cadence,
    CategorySpec,
    PlanError,
    RuleStatus,
    cancel_rule,
    create_plan,
    create_recurring_rule,
    get_active_version,
    get_version,
    list_rules,
    pause_rule,
    plan_history,
    plan_version_for_category,
    resume_rule,
    revise_plan,
)
from iwp.domain.users import Channel, Role, activate_relationship, invite_recipient, upsert_user
from iwp.money import Money

pytestmark = pytest.mark.db


@pytest.fixture()
def pair(db: Engine) -> dict[str, uuid.UUID]:
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
    return {"sender": sender.id, "recipient": recipient.id, "relationship": rel.id}


@pytest.fixture()
def plan(db: Engine, pair: dict[str, uuid.UUID]) -> uuid.UUID:
    version = create_plan(db, relationship_id=pair["relationship"], created_by=pair["sender"])
    return version.plan_id


# --------------------------------------------------------------------------------------
# creation
# --------------------------------------------------------------------------------------


def test_a_new_plan_starts_at_version_one_with_the_prd_categories(
    db: Engine, pair: dict[str, uuid.UUID]
) -> None:
    version = create_plan(db, relationship_id=pair["relationship"], created_by=pair["sender"])
    assert version.version_number == 1
    assert [c.key for c in version.categories] == [
        "housing",
        "food",
        "business",
        "savings",
        "other",
    ]
    assert all(c.monthly_cap is None for c in version.categories), "caps are optional"


def test_a_relationship_gets_one_plan_not_two(db: Engine, pair: dict[str, uuid.UUID]) -> None:
    create_plan(db, relationship_id=pair["relationship"], created_by=pair["sender"])
    with pytest.raises(PlanError, match="already has a plan"):
        create_plan(db, relationship_id=pair["relationship"], created_by=pair["sender"])


def test_each_relationship_has_its_own_independent_plan(
    db: Engine, pair: dict[str, uuid.UUID]
) -> None:
    # PRD §10: multiple recipients per sender, each a separate relationship with its
    # own plan.
    first = create_plan(db, relationship_id=pair["relationship"], created_by=pair["sender"])
    other_rel, other_recipient, _ = invite_recipient(
        db, sender_id=pair["sender"], recipient_phone="55559999", recipient_display_name="Luis"
    )
    activate_relationship(db, other_rel.id, accepted_by=other_recipient.id, channel="sms")
    second = create_plan(db, relationship_id=other_rel.id, created_by=pair["sender"])

    assert second.plan_id != first.plan_id
    revise_plan(
        db,
        plan_id=second.plan_id,
        created_by=pair["sender"],
        categories=(CategorySpec(key="housing", name="Vivienda", monthly_cap=Money(50000, "USD")),),
        change_note="cap housing",
    )
    with db.connect() as conn:
        assert get_active_version(conn, first.plan_id).version_number == 1
        assert get_active_version(conn, second.plan_id).version_number == 2


def test_a_version_needs_at_least_one_category(db: Engine, pair: dict[str, uuid.UUID]) -> None:
    with pytest.raises(PlanError, match="at least one category"):
        create_plan(
            db, relationship_id=pair["relationship"], created_by=pair["sender"], categories=()
        )


def test_duplicate_category_keys_in_one_version_are_refused(
    db: Engine, pair: dict[str, uuid.UUID]
) -> None:
    with pytest.raises(PlanError, match="duplicate category keys"):
        create_plan(
            db,
            relationship_id=pair["relationship"],
            created_by=pair["sender"],
            categories=(
                CategorySpec(key="food", name="Comida"),
                CategorySpec(key="food", name="Comida otra vez"),
            ),
        )


def test_a_cap_in_the_wrong_currency_is_refused(db: Engine, pair: dict[str, uuid.UUID]) -> None:
    with pytest.raises(PlanError, match="GTQ cap"):
        create_plan(
            db,
            relationship_id=pair["relationship"],
            created_by=pair["sender"],
            categories=(CategorySpec(key="food", name="Comida", monthly_cap=Money(1000, "GTQ")),),
            currency="USD",
        )


def test_a_category_key_must_be_a_slug() -> None:
    with pytest.raises(ValueError, match="lowercase slug"):
        CategorySpec(key="Housing Costs", name="x")


def test_a_zero_cap_is_refused_because_no_cap_is_spelled_none() -> None:
    with pytest.raises(ValueError, match="must be positive"):
        CategorySpec(key="food", name="Comida", monthly_cap=Money(0, "USD"))


# --------------------------------------------------------------------------------------
# immutability and versioning
# --------------------------------------------------------------------------------------


def test_editing_a_plan_creates_a_new_version_and_preserves_the_old_one(
    db: Engine, pair: dict[str, uuid.UUID], plan: uuid.UUID
) -> None:
    with db.connect() as conn:
        first = get_active_version(conn, plan)

    revised = revise_plan(
        db,
        plan_id=plan,
        created_by=pair["sender"],
        categories=(
            CategorySpec(key="housing", name="Vivienda", monthly_cap=Money(60000, "USD")),
            CategorySpec(key="food", name="Comida", monthly_cap=Money(30000, "USD")),
        ),
        change_note="added caps",
    )

    assert revised.version_number == 2
    assert revised.id != first.id

    with db.connect() as conn:
        # The old version is untouched and still readable.
        old = get_version(conn, first.id)
        assert [c.key for c in old.categories] == [c.key for c in first.categories]
        assert all(c.monthly_cap is None for c in old.categories)
        assert get_active_version(conn, plan).id == revised.id


def test_a_plan_version_row_cannot_be_updated(db: Engine, plan: uuid.UUID) -> None:
    with db.connect() as conn:
        version = get_active_version(conn, plan)
    with pytest.raises(DBAPIError, match="append-only"), db.begin() as conn:
        conn.execute(
            text("UPDATE plan_version SET change_note = 'rewritten' WHERE id = :i"),
            {"i": version.id},
        )


def test_a_category_row_cannot_be_updated(db: Engine, plan: uuid.UUID) -> None:
    # The tempting shortcut for "change the cap" is an UPDATE here. It has to fail, or
    # a March transaction gets explained by April's cap.
    with db.connect() as conn:
        version = get_active_version(conn, plan)
    with pytest.raises(DBAPIError, match="append-only"), db.begin() as conn:
        conn.execute(
            text("UPDATE category SET monthly_cap = 1 WHERE id = :i"),
            {"i": version.categories[0].id},
        )


def test_the_active_version_is_a_pointer_not_a_flag(db: Engine, plan: uuid.UUID) -> None:
    # There is no is_active column to be true on two rows at once.
    with db.connect() as conn:
        columns = (
            conn.execute(
                text(
                    """
                    SELECT column_name FROM information_schema.columns
                    WHERE table_name = 'plan_version'
                    """
                )
            )
            .scalars()
            .all()
        )
    assert not any("active" in c for c in columns)


def test_a_revision_must_say_what_changed(
    db: Engine, pair: dict[str, uuid.UUID], plan: uuid.UUID
) -> None:
    with pytest.raises(PlanError, match="what changed"):
        revise_plan(
            db,
            plan_id=plan,
            created_by=pair["sender"],
            categories=DEFAULT_CATEGORIES,
            change_note="   ",
        )


def test_revising_an_unknown_plan_raises(db: Engine, pair: dict[str, uuid.UUID]) -> None:
    with pytest.raises(PlanError, match="no such plan"):
        revise_plan(
            db,
            plan_id=uuid.uuid4(),
            created_by=pair["sender"],
            categories=DEFAULT_CATEGORIES,
            change_note="x",
        )


# --------------------------------------------------------------------------------------
# history and point-in-time resolution
# --------------------------------------------------------------------------------------


def test_plan_history_shows_who_changed_what_when(
    db: Engine, pair: dict[str, uuid.UUID], plan: uuid.UUID
) -> None:
    with db.begin() as conn:
        other_sender = upsert_user(conn, "+15555551111", role=Role.SENDER, display_name="Co")

    revise_plan(
        db,
        plan_id=plan,
        created_by=other_sender.id,
        categories=(CategorySpec(key="food", name="Comida", monthly_cap=Money(30000, "USD")),),
        change_note="trimmed to food only",
    )

    with db.connect() as conn:
        history = plan_history(conn, plan)
        trail = audit_trail(conn, "money_plan", plan)

    assert [v.version_number for v in history] == [1, 2]
    assert history[0].created_by == pair["sender"]
    assert history[1].created_by == other_sender.id
    assert history[1].change_note == "trimmed to food only"
    assert history[0].created_at <= history[1].created_at
    assert [row["action"] for row in trail] == [
        "plan.version_created",
        "plan.version_created",
    ]
    assert trail[1]["after_state"]["change_note"] == "trimmed to food only"


def test_a_category_id_resolves_to_the_version_it_belonged_to(
    db: Engine, pair: dict[str, uuid.UUID], plan: uuid.UUID
) -> None:
    """This is how a historical transaction resolves against the rules of its time."""
    with db.connect() as conn:
        v1 = get_active_version(conn, plan)
    v1_food = v1.category("food")
    assert v1_food is not None

    v2 = revise_plan(
        db,
        plan_id=plan,
        created_by=pair["sender"],
        categories=(CategorySpec(key="food", name="Comida", monthly_cap=Money(30000, "USD")),),
        change_note="capped food",
    )
    v2_food = v2.category("food")
    assert v2_food is not None
    assert v2_food.id != v1_food.id

    with db.connect() as conn:
        assert plan_version_for_category(conn, v1_food.id).version_number == 1
        assert plan_version_for_category(conn, v2_food.id).version_number == 2
        # The old category still reports no cap, because at the time there was none.
        historical = plan_version_for_category(conn, v1_food.id).category("food")
    assert historical is not None
    assert historical.monthly_cap is None


def test_resolving_an_unknown_category_raises(db: Engine) -> None:
    with db.connect() as conn, pytest.raises(LookupError):
        plan_version_for_category(conn, uuid.uuid4())


# --------------------------------------------------------------------------------------
# recurring rules
# --------------------------------------------------------------------------------------


def test_a_rule_survives_the_plan_being_revised(
    db: Engine, pair: dict[str, uuid.UUID], plan: uuid.UUID
) -> None:
    """Rules key off category_key, so an edit does not orphan them."""
    rule = create_recurring_rule(
        db,
        plan_id=plan,
        category_key="housing",
        amount=Money(40000, "USD"),
        cadence=Cadence.MONTHLY,
        actor_id=pair["sender"],
    )
    revise_plan(
        db,
        plan_id=plan,
        created_by=pair["sender"],
        categories=(CategorySpec(key="housing", name="Vivienda", monthly_cap=Money(60000, "USD")),),
        change_note="capped housing",
    )
    with db.connect() as conn:
        rules = list_rules(conn, plan)
    assert [r.id for r in rules] == [rule.id]
    assert rules[0].category_key == "housing"


def test_a_rule_cannot_be_created_for_a_category_not_in_the_plan(
    db: Engine, pair: dict[str, uuid.UUID], plan: uuid.UUID
) -> None:
    with pytest.raises(PlanError, match="not in the active plan version"):
        create_recurring_rule(
            db,
            plan_id=plan,
            category_key="yacht",
            amount=Money(40000, "USD"),
            cadence=Cadence.MONTHLY,
            actor_id=pair["sender"],
        )


def test_a_rule_can_be_paused_resumed_and_cancelled(
    db: Engine, pair: dict[str, uuid.UUID], plan: uuid.UUID
) -> None:
    rule = create_recurring_rule(
        db,
        plan_id=plan,
        category_key="food",
        amount=Money(20000, "USD"),
        cadence=Cadence.WEEKLY,
        actor_id=pair["sender"],
    )
    assert pause_rule(db, rule.id, actor_id=pair["sender"]).status is RuleStatus.PAUSED
    assert resume_rule(db, rule.id, actor_id=pair["sender"]).status is RuleStatus.ACTIVE
    assert cancel_rule(db, rule.id, actor_id=pair["sender"]).status is RuleStatus.CANCELLED

    with pytest.raises(PlanError, match="cannot move"):
        resume_rule(db, rule.id, actor_id=pair["sender"])

    with db.connect() as conn:
        assert list_rules(conn, plan) == []
        assert len(list_rules(conn, plan, include_cancelled=True)) == 1
        trail = audit_trail(conn, "recurring_rule", rule.id)
    assert [row["action"] for row in trail] == [
        "recurring_rule.created",
        "recurring_rule.paused",
        "recurring_rule.active",
        "recurring_rule.cancelled",
    ]


def test_pausing_an_already_paused_rule_is_idempotent(
    db: Engine, pair: dict[str, uuid.UUID], plan: uuid.UUID
) -> None:
    rule = create_recurring_rule(
        db,
        plan_id=plan,
        category_key="food",
        amount=Money(20000, "USD"),
        cadence=Cadence.WEEKLY,
        actor_id=pair["sender"],
    )
    pause_rule(db, rule.id, actor_id=pair["sender"])
    pause_rule(db, rule.id, actor_id=pair["sender"])
    with db.connect() as conn:
        paused = [
            r
            for r in audit_trail(conn, "recurring_rule", rule.id)
            if r["action"] == "recurring_rule.paused"
        ]
    assert len(paused) == 1


def test_a_recurring_amount_must_be_positive(
    db: Engine, pair: dict[str, uuid.UUID], plan: uuid.UUID
) -> None:
    with pytest.raises(PlanError, match="must be positive"):
        create_recurring_rule(
            db,
            plan_id=plan,
            category_key="food",
            amount=Money(0, "USD"),
            cadence=Cadence.WEEKLY,
            actor_id=pair["sender"],
        )
