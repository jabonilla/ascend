"""P2.1 — users and many-to-many relationships.

Acceptance criteria under test:
  * one recipient can be linked to three senders, each with an independent plan
  * one sender can be linked to three recipients
  * a recipient can become a sender without a new account
  * relationship states: invited, active, paused, terminated
"""

from __future__ import annotations

import pytest
from sqlalchemy import Engine, text

from iwp.domain.audit import audit_trail
from iwp.domain.phone import GUATEMALA, UNITED_STATES, parse_phone
from iwp.domain.users import (
    Channel,
    RelationshipError,
    Role,
    User,
    activate_relationship,
    get_user,
    invite_recipient,
    list_relationships,
    pause_relationship,
    terminate_relationship,
    upsert_user,
)
from iwp.states import RelationshipStatus

pytestmark = pytest.mark.db


def _sender(db: Engine, phone: str, name: str = "Sender") -> User:
    with db.begin() as conn:
        return upsert_user(
            conn, phone, role=Role.SENDER, display_name=name, preferred_channel=Channel.APP
        )


# --------------------------------------------------------------------------------------
# phone numbers — no database needed
# --------------------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("raw", "country", "expected"),
    [
        ("+50255551234", None, "+50255551234"),
        ("5555 1234", "GT", "+50255551234"),
        ("(555) 555-1234", "US", "+15555551234"),
        ("+1 555 555 1234", None, "+15555551234"),
        ("0050255551234", None, "+50255551234"),
    ],
)
def test_phone_numbers_normalise_to_e164(raw: str, country: str | None, expected: str) -> None:
    assert parse_phone(raw, default_country=country).e164 == expected


def test_a_national_number_without_a_country_raises_rather_than_guessing() -> None:
    # An 8-digit Guatemalan number would otherwise become a plausible-looking US number.
    with pytest.raises(ValueError, match="Refusing to guess"):
        parse_phone("55551234")


def test_a_national_number_of_the_wrong_length_raises() -> None:
    with pytest.raises(ValueError, match="digits"):
        parse_phone("5555123", default_country="GT")


def test_country_metadata_is_what_the_corridor_needs() -> None:
    assert (UNITED_STATES.dialling_code, UNITED_STATES.national_length) == ("1", 10)
    assert (GUATEMALA.dialling_code, GUATEMALA.national_length) == ("502", 8)


# --------------------------------------------------------------------------------------
# users
# --------------------------------------------------------------------------------------


def test_a_recipient_can_become_a_sender_without_a_new_account(db: Engine) -> None:
    with db.begin() as conn:
        first = upsert_user(conn, "+50255551234", role=Role.RECIPIENT, display_name="Ana")
    with db.begin() as conn:
        second = upsert_user(conn, "+50255551234", role=Role.SENDER)

    assert second.id == first.id
    assert second.roles == frozenset({Role.RECIPIENT, Role.SENDER})
    with db.connect() as conn:
        assert conn.execute(text("SELECT count(*) FROM app_user")).scalar_one() == 1


def test_adding_a_role_twice_does_not_duplicate_it(db: Engine) -> None:
    for _ in range(3):
        with db.begin() as conn:
            user = upsert_user(conn, "+50255551234", role=Role.RECIPIENT)
    assert user.roles == frozenset({Role.RECIPIENT})
    with db.connect() as conn:
        roles = conn.execute(text("SELECT roles FROM app_user")).scalar_one()
    assert list(roles) == ["recipient"]


def test_a_recipients_language_defaults_to_spanish(db: Engine) -> None:
    with db.begin() as conn:
        user = upsert_user(conn, "+50255551234", role=Role.RECIPIENT)
    assert user.locale == "es-GT"


def test_an_existing_users_display_name_is_not_overwritten_by_a_later_invitation(
    db: Engine,
) -> None:
    with db.begin() as conn:
        upsert_user(conn, "+50255551234", role=Role.RECIPIENT, display_name="Ana Lopez")
    with db.begin() as conn:
        user = upsert_user(conn, "+50255551234", role=Role.SENDER, display_name="ana")
    assert user.display_name == "Ana Lopez"


# --------------------------------------------------------------------------------------
# many-to-many
# --------------------------------------------------------------------------------------


def test_one_sender_can_be_linked_to_three_recipients(db: Engine) -> None:
    sender = _sender(db, "+15555550000")
    for i in range(3):
        invite_recipient(
            db,
            sender_id=sender.id,
            recipient_phone=f"5555000{i}",
            recipient_display_name=f"Recipient {i}",
        )
    with db.connect() as conn:
        found = list_relationships(conn, sender.id, as_role=Role.SENDER)
    assert len(found) == 3
    assert len({r.recipient_id for r in found}) == 3


def test_one_recipient_can_be_linked_to_three_senders(db: Engine) -> None:
    recipient_phone = "+50255559999"
    recipient_id = None
    for i in range(3):
        sender = _sender(db, f"+1555555000{i}", name=f"Sender {i}")
        _, recipient, created = invite_recipient(
            db,
            sender_id=sender.id,
            recipient_phone=recipient_phone,
            recipient_display_name="Ana",
        )
        assert created is True
        recipient_id = recipient.id

    assert recipient_id is not None
    with db.connect() as conn:
        found = list_relationships(conn, recipient_id, as_role=Role.RECIPIENT)
        assert conn.execute(text("SELECT count(*) FROM app_user")).scalar_one() == 4
    assert len(found) == 3
    assert len({r.sender_id for r in found}) == 3


def test_a_recipient_already_in_the_system_is_linked_not_duplicated(db: Engine) -> None:
    # PRD Feature 0 edge case: the number is already a sender.
    existing = _sender(db, "+50255551234", name="Ana")
    sender = _sender(db, "+15555550000")
    _, recipient, _ = invite_recipient(
        db, sender_id=sender.id, recipient_phone="+50255551234", recipient_display_name="Ana"
    )
    assert recipient.id == existing.id
    assert recipient.roles == frozenset({Role.SENDER, Role.RECIPIENT})


def test_re_inviting_the_same_recipient_returns_the_existing_invitation(db: Engine) -> None:
    sender = _sender(db, "+15555550000")
    first, _, created_first = invite_recipient(
        db, sender_id=sender.id, recipient_phone="55551234", recipient_display_name="Ana"
    )
    second, _, created_second = invite_recipient(
        db, sender_id=sender.id, recipient_phone="55551234", recipient_display_name="Ana"
    )
    assert created_first is True
    assert created_second is False
    assert second.id == first.id
    with db.connect() as conn:
        assert conn.execute(text("SELECT count(*) FROM relationship")).scalar_one() == 1


def test_a_sender_cannot_invite_themselves(db: Engine) -> None:
    sender = _sender(db, "+15555550000")
    with pytest.raises(RelationshipError, match="themselves"):
        invite_recipient(
            db,
            sender_id=sender.id,
            recipient_phone="+15555550000",
            recipient_display_name="Me",
        )


def test_other_party_resolves_from_either_side(db: Engine) -> None:
    sender = _sender(db, "+15555550000")
    rel, recipient, _ = invite_recipient(
        db, sender_id=sender.id, recipient_phone="55551234", recipient_display_name="Ana"
    )
    assert rel.other_party(sender.id) == recipient.id
    assert rel.other_party(recipient.id) == sender.id


# --------------------------------------------------------------------------------------
# relationship states
# --------------------------------------------------------------------------------------


def test_relationship_moves_invited_active_paused_active_terminated(db: Engine) -> None:
    sender = _sender(db, "+15555550000")
    rel, recipient, _ = invite_recipient(
        db, sender_id=sender.id, recipient_phone="55551234", recipient_display_name="Ana"
    )
    assert rel.status is RelationshipStatus.INVITED
    assert rel.activated_at is None

    active = activate_relationship(db, rel.id, accepted_by=recipient.id, channel="whatsapp")
    assert active.status is RelationshipStatus.ACTIVE
    assert active.activated_at is not None

    paused = pause_relationship(db, rel.id, actor_id=sender.id)
    assert paused.status is RelationshipStatus.PAUSED

    reactivated = activate_relationship(db, rel.id, accepted_by=sender.id, channel="app")
    assert reactivated.status is RelationshipStatus.ACTIVE
    assert reactivated.activated_at == active.activated_at, "first activation time is kept"

    ended = terminate_relationship(db, rel.id, actor_id=recipient.id)
    assert ended.status is RelationshipStatus.TERMINATED


def test_a_terminated_relationship_cannot_be_revived(db: Engine) -> None:
    sender = _sender(db, "+15555550000")
    rel, recipient, _ = invite_recipient(
        db, sender_id=sender.id, recipient_phone="55551234", recipient_display_name="Ana"
    )
    terminate_relationship(db, rel.id, actor_id=sender.id)
    with pytest.raises(RelationshipError, match="cannot move"):
        activate_relationship(db, rel.id, accepted_by=recipient.id, channel="whatsapp")


def test_re_inviting_a_terminated_relationship_is_refused_rather_than_silently_reopened(
    db: Engine,
) -> None:
    sender = _sender(db, "+15555550000")
    rel, _, _ = invite_recipient(
        db, sender_id=sender.id, recipient_phone="55551234", recipient_display_name="Ana"
    )
    terminate_relationship(db, rel.id, actor_id=sender.id)
    with pytest.raises(RelationshipError, match="terminated"):
        invite_recipient(
            db, sender_id=sender.id, recipient_phone="55551234", recipient_display_name="Ana"
        )


def test_repeating_a_transition_is_idempotent(db: Engine) -> None:
    sender = _sender(db, "+15555550000")
    rel, recipient, _ = invite_recipient(
        db, sender_id=sender.id, recipient_phone="55551234", recipient_display_name="Ana"
    )
    first = activate_relationship(db, rel.id, accepted_by=recipient.id, channel="whatsapp")
    second = activate_relationship(db, rel.id, accepted_by=recipient.id, channel="whatsapp")
    assert second.activated_at == first.activated_at
    with db.connect() as conn:
        transitions = [
            row["action"]
            for row in audit_trail(conn, "relationship", rel.id)
            if row["action"] == "relationship.activated"
        ]
    assert len(transitions) == 1, "a repeated instruction is one transition, one audit row"


def test_every_relationship_transition_writes_an_audit_row(db: Engine) -> None:
    sender = _sender(db, "+15555550000")
    rel, recipient, _ = invite_recipient(
        db, sender_id=sender.id, recipient_phone="55551234", recipient_display_name="Ana"
    )
    activate_relationship(db, rel.id, accepted_by=recipient.id, channel="whatsapp")
    pause_relationship(db, rel.id, actor_id=sender.id)
    terminate_relationship(db, rel.id, actor_id=sender.id)

    with db.connect() as conn:
        trail = audit_trail(conn, "relationship", rel.id)
    assert [row["action"] for row in trail] == [
        "relationship.invited",
        "relationship.activated",
        "relationship.paused",
        "relationship.terminated",
    ]
    activation = trail[1]
    assert activation["actor_id"] == recipient.id
    assert activation["channel"] == "whatsapp"
    assert activation["before_state"] == {"status": "invited"}
    assert activation["after_state"] == {"status": "active"}


def test_listing_can_be_filtered_by_status(db: Engine) -> None:
    sender = _sender(db, "+15555550000")
    rel_a, recipient_a, _ = invite_recipient(
        db, sender_id=sender.id, recipient_phone="55550001", recipient_display_name="A"
    )
    invite_recipient(
        db, sender_id=sender.id, recipient_phone="55550002", recipient_display_name="B"
    )
    activate_relationship(db, rel_a.id, accepted_by=recipient_a.id, channel="sms")

    with db.connect() as conn:
        active = list_relationships(
            conn, sender.id, statuses=frozenset({RelationshipStatus.ACTIVE})
        )
    assert [r.id for r in active] == [rel_a.id]


def test_a_system_actor_may_not_carry_an_actor_id(db: Engine) -> None:
    from iwp.domain.audit import ActorKind, write_audit

    sender = _sender(db, "+15555550000")
    with db.begin() as conn, pytest.raises(ValueError, match="no actor_id"):
        write_audit(
            conn,
            action="x",
            entity_type="user",
            entity_id=sender.id,
            actor_id=sender.id,
            actor_kind=ActorKind.SYSTEM,
        )


def test_a_user_action_must_name_the_user(db: Engine) -> None:
    from iwp.domain.audit import write_audit

    sender = _sender(db, "+15555550000")
    with db.begin() as conn, pytest.raises(ValueError, match="which user"):
        write_audit(conn, action="x", entity_type="user", entity_id=sender.id)


def test_get_user_raises_for_an_unknown_id(db: Engine) -> None:
    import uuid

    with db.connect() as conn, pytest.raises(LookupError):
        get_user(conn, uuid.uuid4())
