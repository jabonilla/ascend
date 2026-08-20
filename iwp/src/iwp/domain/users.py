"""P2.1 — users and relationships.

CLAUDE.md rule 9: relationships are many-to-many. One recipient may have several
senders; one sender may have several recipients. Nothing in this module assumes 1:1,
and ``tests/test_users.py`` proves it in both directions.

A user is identified by phone number and holds a *set* of roles. A recipient who starts
sending gains the sender role on the same account — they do not get a second one (PRD
Feature 0 edge case: "Recipient's number is already a sender in the system → link to
existing user, do not create a duplicate").
"""

from __future__ import annotations

import enum
import uuid
from dataclasses import dataclass
from datetime import datetime

from sqlalchemy import Engine, text
from sqlalchemy.engine import Connection

from iwp.domain.audit import ActorKind, write_audit
from iwp.domain.phone import PhoneNumber, parse_phone
from iwp.states import RelationshipStatus

__all__ = [
    "Relationship",
    "Role",
    "User",
    "activate_relationship",
    "get_user",
    "invite_recipient",
    "list_relationships",
    "pause_relationship",
    "terminate_relationship",
    "upsert_user",
]


class Role(enum.Enum):
    SENDER = "sender"
    RECIPIENT = "recipient"


class Channel(enum.Enum):
    APP = "app"
    WHATSAPP = "whatsapp"
    SMS = "sms"


@dataclass(frozen=True, slots=True)
class User:
    id: uuid.UUID
    phone: PhoneNumber
    roles: frozenset[Role]
    display_name: str
    locale: str
    preferred_channel: Channel

    def has_role(self, role: Role) -> bool:
        return role in self.roles


@dataclass(frozen=True, slots=True)
class Relationship:
    id: uuid.UUID
    sender_id: uuid.UUID
    recipient_id: uuid.UUID
    status: RelationshipStatus
    invited_at: datetime
    activated_at: datetime | None

    def other_party(self, user_id: uuid.UUID) -> uuid.UUID:
        if user_id == self.sender_id:
            return self.recipient_id
        if user_id == self.recipient_id:
            return self.sender_id
        raise ValueError(f"{user_id} is not a party to relationship {self.id}")


class RelationshipError(Exception):
    """A relationship could not be created or transitioned."""


# --------------------------------------------------------------------------------------
# users
# --------------------------------------------------------------------------------------


def upsert_user(
    conn: Connection,
    phone: str | PhoneNumber,
    *,
    role: Role,
    display_name: str | None = None,
    locale: str | None = None,
    preferred_channel: Channel | None = None,
    default_country: str | None = None,
) -> User:
    """Find the user with this phone number, or create them; then ensure they hold
    ``role``.

    Adding a role never removes one. This is the mechanism behind "a recipient can
    become a sender without a new account": the same row gains a second role.
    """
    number = (
        phone
        if isinstance(phone, PhoneNumber)
        else parse_phone(phone, default_country=default_country)
    )

    conn.execute(
        text(
            """
            INSERT INTO app_user (phone, roles, display_name, locale, preferred_channel)
            VALUES (:phone, ARRAY[:role]::TEXT[], :display_name, :locale, :channel)
            ON CONFLICT (phone) DO NOTHING
            """
        ),
        {
            "phone": number.e164,
            "role": role.value,
            "display_name": display_name or "",
            # Recipients default to Spanish (PRD Feature 0).
            "locale": locale or "es-GT",
            "channel": (preferred_channel or Channel.WHATSAPP).value,
        },
    )

    # array_append only when absent, so re-inviting an existing user is idempotent and
    # does not accumulate duplicate roles.
    conn.execute(
        text(
            """
            UPDATE app_user
            SET roles = array_append(roles, :role),
                display_name = CASE
                    WHEN display_name = '' THEN :display_name ELSE display_name END,
                updated_at = now()
            WHERE phone = :phone AND NOT (:role = ANY (roles))
            """
        ),
        {"phone": number.e164, "role": role.value, "display_name": display_name or ""},
    )

    return _load_user_by_phone(conn, number)


def _load_user_by_phone(conn: Connection, phone: PhoneNumber) -> User:
    row = (
        conn.execute(
            text(
                """
                SELECT id, phone, roles, display_name, locale, preferred_channel
                FROM app_user WHERE phone = :phone
                """
            ),
            {"phone": phone.e164},
        )
        .mappings()
        .one()
    )
    return _row_to_user(row)


def _row_to_user(row: object) -> User:
    data = dict(row)  # type: ignore[call-overload]
    return User(
        id=data["id"],
        phone=PhoneNumber(data["phone"]),
        roles=frozenset(Role(r) for r in data["roles"]),
        display_name=data["display_name"],
        locale=data["locale"],
        preferred_channel=Channel(data["preferred_channel"]),
    )


def get_user(conn: Connection, user_id: uuid.UUID) -> User:
    row = (
        conn.execute(
            text(
                """
                SELECT id, phone, roles, display_name, locale, preferred_channel
                FROM app_user WHERE id = :id
                """
            ),
            {"id": user_id},
        )
        .mappings()
        .one_or_none()
    )
    if row is None:
        raise LookupError(f"no such user: {user_id}")
    return _row_to_user(row)


# --------------------------------------------------------------------------------------
# relationships
# --------------------------------------------------------------------------------------


def invite_recipient(
    engine: Engine,
    *,
    sender_id: uuid.UUID,
    recipient_phone: str,
    recipient_display_name: str,
    default_country: str = "GT",
) -> tuple[Relationship, User, bool]:
    """Invite a recipient by phone number (PRD Feature 0).

    Returns the relationship, the recipient user, and whether the invitation is new.
    Re-inviting the same recipient returns the existing invitation rather than creating
    a second one — an at-least-once channel means the sender may well tap twice.
    """
    number = parse_phone(recipient_phone, default_country=default_country)

    with engine.begin() as conn:
        sender = get_user(conn, sender_id)
        recipient = upsert_user(
            conn,
            number,
            role=Role.RECIPIENT,
            display_name=recipient_display_name,
        )
        if recipient.id == sender.id:
            raise RelationshipError("a sender cannot invite themselves")

        existing = _find_relationship(conn, sender.id, recipient.id)
        if existing is not None:
            if existing.status is RelationshipStatus.TERMINATED:
                raise RelationshipError(
                    "this relationship was terminated; re-invitation is a deliberate act "
                    "and is not implemented at MVP"
                )
            return existing, recipient, False

        relationship_id = conn.execute(
            text(
                """
                INSERT INTO relationship (user_a_id, user_b_id, role_of_a, role_of_b, status)
                VALUES (:sender, :recipient, 'sender', 'recipient', 'invited')
                RETURNING id
                """
            ),
            {"sender": sender.id, "recipient": recipient.id},
        ).scalar_one()

        write_audit(
            conn,
            action="relationship.invited",
            entity_type="relationship",
            entity_id=relationship_id,
            actor_id=sender.id,
            after_state={"status": RelationshipStatus.INVITED.value},
        )
        relationship = _load_relationship(conn, relationship_id)

    return relationship, recipient, True


def _find_relationship(
    conn: Connection, sender_id: uuid.UUID, recipient_id: uuid.UUID
) -> Relationship | None:
    row = (
        conn.execute(
            text(
                """
                SELECT id, user_a_id, user_b_id, status, invited_at, activated_at
                FROM relationship WHERE user_a_id = :s AND user_b_id = :r
                """
            ),
            {"s": sender_id, "r": recipient_id},
        )
        .mappings()
        .one_or_none()
    )
    return None if row is None else _row_to_relationship(row)


def _row_to_relationship(row: object) -> Relationship:
    data = dict(row)  # type: ignore[call-overload]
    return Relationship(
        id=data["id"],
        sender_id=data["user_a_id"],
        recipient_id=data["user_b_id"],
        status=RelationshipStatus(data["status"]),
        invited_at=data["invited_at"],
        activated_at=data["activated_at"],
    )


def _load_relationship(conn: Connection, relationship_id: uuid.UUID) -> Relationship:
    row = (
        conn.execute(
            text(
                """
                SELECT id, user_a_id, user_b_id, status, invited_at, activated_at
                FROM relationship WHERE id = :id
                """
            ),
            {"id": relationship_id},
        )
        .mappings()
        .one_or_none()
    )
    if row is None:
        raise LookupError(f"no such relationship: {relationship_id}")
    return _row_to_relationship(row)


def get_relationship(conn: Connection, relationship_id: uuid.UUID) -> Relationship:
    return _load_relationship(conn, relationship_id)


# Which status changes are legal. Terminated is terminal: history stays viewable but no
# new requests are permitted (PRD §10).
_LEGAL_TRANSITIONS: dict[RelationshipStatus, frozenset[RelationshipStatus]] = {
    RelationshipStatus.INVITED: frozenset(
        {RelationshipStatus.ACTIVE, RelationshipStatus.TERMINATED}
    ),
    RelationshipStatus.ACTIVE: frozenset(
        {RelationshipStatus.PAUSED, RelationshipStatus.TERMINATED}
    ),
    RelationshipStatus.PAUSED: frozenset(
        {RelationshipStatus.ACTIVE, RelationshipStatus.TERMINATED}
    ),
    RelationshipStatus.TERMINATED: frozenset(),
}


def _transition(
    engine: Engine,
    relationship_id: uuid.UUID,
    target: RelationshipStatus,
    *,
    actor_id: uuid.UUID | None,
    actor_kind: ActorKind,
    channel: str | None,
    action: str,
) -> Relationship:
    with engine.begin() as conn:
        current = _load_relationship(conn, relationship_id)
        if current.status is target:
            return current  # idempotent: the same instruction twice is one transition
        if target not in _LEGAL_TRANSITIONS[current.status]:
            raise RelationshipError(
                f"cannot move relationship {relationship_id} from "
                f"{current.status.value} to {target.value}"
            )

        conn.execute(
            text(
                """
                UPDATE relationship
                SET status = :status,
                    activated_at = CASE
                        WHEN :status = 'active' AND activated_at IS NULL
                        THEN now() ELSE activated_at END,
                    terminated_at = CASE
                        WHEN :status = 'terminated' THEN now() ELSE terminated_at END
                WHERE id = :id
                """
            ),
            {"status": target.value, "id": relationship_id},
        )
        write_audit(
            conn,
            action=action,
            entity_type="relationship",
            entity_id=relationship_id,
            actor_id=actor_id,
            actor_kind=actor_kind,
            channel=channel,
            before_state={"status": current.status.value},
            after_state={"status": target.value},
        )
        return _load_relationship(conn, relationship_id)


def activate_relationship(
    engine: Engine,
    relationship_id: uuid.UUID,
    *,
    accepted_by: uuid.UUID,
    channel: str,
) -> Relationship:
    """The recipient accepted the invitation (PRD Feature 0)."""
    return _transition(
        engine,
        relationship_id,
        RelationshipStatus.ACTIVE,
        actor_id=accepted_by,
        actor_kind=ActorKind.USER,
        channel=channel,
        action="relationship.activated",
    )


def pause_relationship(
    engine: Engine, relationship_id: uuid.UUID, *, actor_id: uuid.UUID, channel: str = "app"
) -> Relationship:
    return _transition(
        engine,
        relationship_id,
        RelationshipStatus.PAUSED,
        actor_id=actor_id,
        actor_kind=ActorKind.USER,
        channel=channel,
        action="relationship.paused",
    )


def terminate_relationship(
    engine: Engine, relationship_id: uuid.UUID, *, actor_id: uuid.UUID, channel: str = "app"
) -> Relationship:
    """Either party can end it. History is retained and stays viewable (PRD §10)."""
    return _transition(
        engine,
        relationship_id,
        RelationshipStatus.TERMINATED,
        actor_id=actor_id,
        actor_kind=ActorKind.USER,
        channel=channel,
        action="relationship.terminated",
    )


def list_relationships(
    conn: Connection,
    user_id: uuid.UUID,
    *,
    as_role: Role | None = None,
    statuses: frozenset[RelationshipStatus] | None = None,
) -> list[Relationship]:
    """Every relationship this user is a party to, in either role.

    A recipient with three senders and a sender with three recipients both come back
    correctly from this one query — there is no "the" relationship for a user.
    """
    clauses = []
    params: dict[str, object] = {"user_id": user_id}
    if as_role is Role.SENDER:
        clauses.append("user_a_id = :user_id")
    elif as_role is Role.RECIPIENT:
        clauses.append("user_b_id = :user_id")
    else:
        clauses.append("(user_a_id = :user_id OR user_b_id = :user_id)")

    if statuses:
        clauses.append("status = ANY(:statuses)")
        params["statuses"] = [s.value for s in statuses]

    rows = (
        conn.execute(
            text(
                """
                SELECT id, user_a_id, user_b_id, status, invited_at, activated_at
                FROM relationship
                WHERE """
                + " AND ".join(clauses)
                + " ORDER BY invited_at"
            ),
            params,
        )
        .mappings()
        .all()
    )
    return [_row_to_relationship(row) for row in rows]
