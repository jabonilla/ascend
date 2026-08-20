"""P5.1 — authentication and assurance levels.

PRD Feature 5: "Approving a request moves money. Every approval is an authentication
event." The reason this is a feature rather than a login screen is in PRD §2: recipients
share devices and change numbers frequently, so possession of a phone number is evidence
about identity, not proof of it.

So the product does not ask "are you logged in?". It asks "how well do we know this is
you, and is that enough for *this* amount?" — and the answer is recorded on the approval
forever, because a year from now the question will be about a specific $600 and not
about the general state of our auth.

Thresholds live in ``runtime_setting`` and change without a deploy (PRD Feature 5), and
their values are an open question (PRD §13). Nothing here hardcodes one.
"""

from __future__ import annotations

import enum
import hashlib
import hmac
import secrets
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Final

from sqlalchemy import Engine, text
from sqlalchemy.engine import Connection

from iwp.domain.audit import ActorKind, write_audit
from iwp.domain.phone import PhoneNumber, parse_phone
from iwp.money import Money
from iwp.settings_store import get_int

__all__ = [
    "AssuranceLevel",
    "AuthError",
    "AuthoritySuspended",
    "CodeExpired",
    "CodeIncorrect",
    "DeviceSession",
    "StepUpRequired",
    "TooManyAttempts",
    "authorize_approval",
    "change_phone",
    "issue_verification_code",
    "required_assurance_for",
    "revoke_session",
    "session_for_token",
    "verify_code",
]

CODE_TTL: Final = timedelta(minutes=10)
SESSION_TTL: Final = timedelta(days=90)
_CODE_DIGITS: Final = 6


class AuthError(Exception):
    """Base class for authentication failures."""


class CodeExpired(AuthError):
    """The verification code is past its window, or already used."""


class CodeIncorrect(AuthError):
    """The verification code does not match."""


class TooManyAttempts(AuthError):
    """Too many wrong guesses against one code."""


class AuthoritySuspended(AuthError):
    """Approval authority has been withdrawn and not yet restored.

    Distinct from :class:`StepUpRequired` because the remedy is different: step-up means
    "prove yourself harder right now", suspension means "re-verify your new number
    first". Telling a user to try harder when the answer is a different flow entirely is
    how support tickets are made.
    """

    def __init__(self, reason: str, amount: Money) -> None:
        super().__init__(f"approval authority is suspended: {reason}")
        self.reason = reason
        self.amount = amount


class StepUpRequired(AuthError):
    """This approval needs a stronger proof of identity than was presented."""

    def __init__(self, required: AssuranceLevel, presented: AssuranceLevel, amount: Money):
        super().__init__(
            f"approving {amount} requires {required.value}; {presented.value} was presented"
        )
        self.required = required
        self.presented = presented
        self.amount = amount


class AssuranceLevel(enum.Enum):
    """How well we know the person acting is who they claim to be.

    Ordered. The order is the whole point: a threshold comparison is only meaningful
    against a ranked scale, and an unranked set of labels is how "verified" ends up
    meaning four different things.
    """

    NONE = "none"
    """We have a phone number and nothing else."""

    CHANNEL_VERIFIED = "channel_verified"
    """The reply came from the number we know, on a channel we control. Enough for a
    small, in-plan approval — and not enough for anything else."""

    DEVICE_VERIFIED = "device_verified"
    """A one-time code was entered on a device holding a live session."""

    APP_VERIFIED = "app_verified"
    """A live app session with a device credential (biometric or PIN) behind it."""

    @property
    def rank(self) -> int:
        return _RANK[self]

    def __lt__(self, other: AssuranceLevel) -> bool:
        return self.rank < other.rank

    def __ge__(self, other: AssuranceLevel) -> bool:
        return self.rank >= other.rank


_RANK: Final[dict[AssuranceLevel, int]] = {
    AssuranceLevel.NONE: 0,
    AssuranceLevel.CHANNEL_VERIFIED: 1,
    AssuranceLevel.DEVICE_VERIFIED: 2,
    AssuranceLevel.APP_VERIFIED: 3,
}


@dataclass(frozen=True, slots=True)
class DeviceSession:
    id: uuid.UUID
    user_id: uuid.UUID
    device_id: str
    assurance_level: AssuranceLevel
    expires_at: datetime
    revoked_at: datetime | None

    def is_live(self, now: datetime) -> bool:
        return self.revoked_at is None and now < self.expires_at


# --------------------------------------------------------------------------------------
# thresholds
# --------------------------------------------------------------------------------------


def required_assurance_for(conn: Connection, amount: Money) -> AssuranceLevel:
    """How well we must know the sender before they can approve this amount.

    PRD Feature 5: in-channel below one threshold, step-up above it, the app above a
    second. Both thresholds are runtime settings; PRD §13 lists their values as an
    open question, so no number appears here.
    """
    step_up = Money(get_int(conn, "approval.step_up_threshold_minor_units"), amount.currency)
    app_required = Money(
        get_int(conn, "approval.app_required_threshold_minor_units"), amount.currency
    )
    if amount <= step_up:
        return AssuranceLevel.CHANNEL_VERIFIED
    if amount <= app_required:
        return AssuranceLevel.DEVICE_VERIFIED
    return AssuranceLevel.APP_VERIFIED


def authorize_approval(
    conn: Connection,
    *,
    user_id: uuid.UUID,
    amount: Money,
    presented: AssuranceLevel,
    relationship_id: uuid.UUID | None = None,
    now: datetime | None = None,
) -> AssuranceLevel:
    """Check that this person may approve this amount right now.

    Returns the level that was required, so the caller records what the bar was rather
    than only what was cleared. Raises rather than returning a boolean: a caller that
    forgets to check a boolean approves everything.
    """
    moment = now or datetime.now(UTC)

    suspended = _authority_suspended(conn, user_id)
    if suspended is not None:
        # PRD Feature 5: "Number change requires re-verification before any approval
        # authority is restored." No presented level clears this — re-verification does.
        raise AuthoritySuspended(suspended, amount)

    required = required_assurance_for(conn, amount)
    if presented < required:
        raise StepUpRequired(required, presented, amount)

    if relationship_id is not None:
        _assert_within_limits(conn, relationship_id, amount, moment)
    return required


def _assert_within_limits(
    conn: Connection, relationship_id: uuid.UUID, amount: Money, now: datetime
) -> None:
    """PRD Feature 5: the sender's own per-transaction and per-day limits."""
    row = (
        conn.execute(
            text(
                """
                SELECT per_transaction_limit, per_day_limit, limit_currency
                FROM relationship WHERE id = :r
                """
            ),
            {"r": relationship_id},
        )
        .mappings()
        .one()
    )
    currency = str(row["limit_currency"])
    if currency != amount.currency.code:
        # A limit in another currency cannot be compared without a rate, and inventing
        # one silently is the failure this whole codebase is arranged against.
        raise ValueError(
            f"relationship limits are in {currency} but the approval is in {amount.currency.code}"
        )

    if row["per_transaction_limit"] is not None:
        limit = Money(int(row["per_transaction_limit"]), currency)
        if amount > limit:
            raise StepUpRequired(AssuranceLevel.APP_VERIFIED, AssuranceLevel.NONE, amount)

    if row["per_day_limit"] is not None:
        day_start = now.astimezone(UTC).replace(hour=0, minute=0, second=0, microsecond=0)
        so_far = conn.execute(
            text(
                """
                SELECT COALESCE(SUM(amount), 0) FROM transaction
                WHERE relationship_id = :r
                  AND intent_state = 'committed'
                  AND currency = :c
                  AND approved_at >= :since
                """
            ),
            {"r": relationship_id, "c": currency, "since": day_start},
        ).scalar_one()
        if Money(int(so_far), currency) + amount > Money(int(row["per_day_limit"]), currency):
            raise StepUpRequired(AssuranceLevel.APP_VERIFIED, AssuranceLevel.NONE, amount)


# --------------------------------------------------------------------------------------
# verification codes
# --------------------------------------------------------------------------------------


def _hash_code(phone: str, code: str) -> str:
    """Salted by the phone number so one leaked hash does not unlock another account."""
    return hashlib.sha256(f"{phone}:{code}".encode()).hexdigest()


def issue_verification_code(
    engine: Engine,
    phone: str | PhoneNumber,
    *,
    purpose: str = "login",
    now: datetime | None = None,
) -> tuple[uuid.UUID, str]:
    """Create a one-time code. Returns its id and the plaintext to send.

    The plaintext is returned rather than stored: the caller hands it to the channel
    gateway and forgets it. A database dump contains only hashes.
    """
    number = phone if isinstance(phone, PhoneNumber) else parse_phone(phone)
    moment = now or datetime.now(UTC)
    code = f"{secrets.randbelow(10**_CODE_DIGITS):0{_CODE_DIGITS}d}"

    with engine.begin() as conn:
        code_id: uuid.UUID = conn.execute(
            text(
                """
                INSERT INTO verification_code (phone, code_hash, purpose, expires_at)
                VALUES (:phone, :hash, :purpose, :expires)
                RETURNING id
                """
            ),
            {
                "phone": number.e164,
                "hash": _hash_code(number.e164, code),
                "purpose": purpose,
                "expires": moment + CODE_TTL,
            },
        ).scalar_one()
    return code_id, code


def verify_code(
    engine: Engine,
    phone: str | PhoneNumber,
    code: str,
    *,
    purpose: str = "login",
    now: datetime | None = None,
) -> None:
    """Check a code and consume it. Raises on any failure.

    Compared with ``hmac.compare_digest`` rather than ``==``: the timing difference is
    small, and so is the cost of not having it.
    """
    number = phone if isinstance(phone, PhoneNumber) else parse_phone(phone)
    moment = now or datetime.now(UTC)

    with engine.begin() as conn:
        row = (
            conn.execute(
                text(
                    """
                    SELECT id, code_hash, attempts, max_attempts, expires_at, consumed_at
                    FROM verification_code
                    WHERE phone = :phone AND purpose = :purpose
                    ORDER BY created_at DESC
                    LIMIT 1
                    FOR UPDATE
                    """
                ),
                {"phone": number.e164, "purpose": purpose},
            )
            .mappings()
            .one_or_none()
        )
        if row is None:
            raise CodeExpired("no verification code has been issued for this number")
        if row["consumed_at"] is not None:
            raise CodeExpired("this code has already been used")
        if moment >= row["expires_at"]:
            raise CodeExpired("this code has expired")
        if row["attempts"] >= row["max_attempts"]:
            raise TooManyAttempts("too many attempts against this code")

        correct = hmac.compare_digest(str(row["code_hash"]), _hash_code(number.e164, code))
        if correct:
            conn.execute(
                text("UPDATE verification_code SET consumed_at = :now WHERE id = :i"),
                {"now": moment, "i": row["id"]},
            )
        else:
            # Counted inside this transaction and committed by leaving the block
            # normally. Raising here instead would roll the increment back with the
            # exception, and the attempt limit would never bite — which is the whole
            # point of having one.
            conn.execute(
                text("UPDATE verification_code SET attempts = attempts + 1 WHERE id = :i"),
                {"i": row["id"]},
            )

    if not correct:
        raise CodeIncorrect("that code is not correct")


# --------------------------------------------------------------------------------------
# sessions
# --------------------------------------------------------------------------------------


def start_session(
    engine: Engine,
    *,
    user_id: uuid.UUID,
    device_id: str,
    assurance_level: AssuranceLevel = AssuranceLevel.DEVICE_VERIFIED,
    now: datetime | None = None,
) -> tuple[DeviceSession, str]:
    """Start a session, revoking every other one for this user.

    PRD Feature 5: "Same number appears on a second device → prior session invalidated,
    re-verification required." One live session per user, always. On a shared handset
    (PRD §2) that is the difference between the account being yours and being whoever
    used the phone last.
    """
    moment = now or datetime.now(UTC)
    token = secrets.token_urlsafe(32)

    with engine.begin() as conn:
        revoked = conn.execute(
            text(
                """
                UPDATE device_session
                SET revoked_at = :now, revoked_reason = 'superseded by a new device'
                WHERE user_id = :u AND revoked_at IS NULL
                RETURNING id
                """
            ),
            {"now": moment, "u": user_id},
        ).all()

        session_id: uuid.UUID = conn.execute(
            text(
                """
                INSERT INTO device_session
                    (user_id, device_id, token_hash, assurance_level, expires_at)
                VALUES (:u, :d, :t, :a, :expires)
                RETURNING id
                """
            ),
            {
                "u": user_id,
                "d": device_id,
                "t": hashlib.sha256(token.encode()).hexdigest(),
                "a": assurance_level.value,
                "expires": moment + SESSION_TTL,
            },
        ).scalar_one()

        conn.execute(
            text(
                """
                UPDATE app_user
                SET identity_assurance_level = :a,
                    approval_authority_suspended_at = NULL,
                    approval_authority_suspended_reason = '',
                    updated_at = now()
                WHERE id = :u
                """
            ),
            {"a": assurance_level.value, "u": user_id},
        )
        write_audit(
            conn,
            action="session.started",
            entity_type="app_user",
            entity_id=user_id,
            actor_id=user_id,
            assurance_level=assurance_level.value,
            after_state={
                "device_id": device_id,
                "sessions_revoked": len(revoked),
            },
        )
        session = _load_session(conn, session_id)
    return session, token


def session_for_token(
    engine: Engine, token: str, *, now: datetime | None = None
) -> DeviceSession | None:
    """The live session behind a token, or None."""
    moment = now or datetime.now(UTC)
    with engine.connect() as conn:
        row = (
            conn.execute(
                text(
                    """
                    SELECT id, user_id, device_id, assurance_level, expires_at, revoked_at
                    FROM device_session WHERE token_hash = :t
                    """
                ),
                {"t": hashlib.sha256(token.encode()).hexdigest()},
            )
            .mappings()
            .one_or_none()
        )
    if row is None:
        return None
    session = DeviceSession(
        id=row["id"],
        user_id=row["user_id"],
        device_id=row["device_id"],
        assurance_level=AssuranceLevel(row["assurance_level"]),
        expires_at=row["expires_at"],
        revoked_at=row["revoked_at"],
    )
    return session if session.is_live(moment) else None


def _load_session(conn: Connection, session_id: uuid.UUID) -> DeviceSession:
    row = (
        conn.execute(
            text(
                """
                SELECT id, user_id, device_id, assurance_level, expires_at, revoked_at
                FROM device_session WHERE id = :i
                """
            ),
            {"i": session_id},
        )
        .mappings()
        .one()
    )
    return DeviceSession(
        id=row["id"],
        user_id=row["user_id"],
        device_id=row["device_id"],
        assurance_level=AssuranceLevel(row["assurance_level"]),
        expires_at=row["expires_at"],
        revoked_at=row["revoked_at"],
    )


def revoke_session(
    engine: Engine, session_id: uuid.UUID, *, reason: str, now: datetime | None = None
) -> None:
    moment = now or datetime.now(UTC)
    with engine.begin() as conn:
        conn.execute(
            text(
                """
                UPDATE device_session
                SET revoked_at = COALESCE(revoked_at, :now), revoked_reason = :reason
                WHERE id = :i
                """
            ),
            {"now": moment, "reason": reason, "i": session_id},
        )


# --------------------------------------------------------------------------------------
# phone changes
# --------------------------------------------------------------------------------------


def change_phone(
    engine: Engine,
    user_id: uuid.UUID,
    new_phone: str | PhoneNumber,
    *,
    default_country: str | None = None,
    now: datetime | None = None,
) -> None:
    """Move a user to a new number, stripping their approval authority until re-verified.

    PRD Feature 5: "Number change requires re-verification before any approval authority
    is restored." The recipient persona changes numbers frequently (PRD §2), so this
    path is routine rather than exceptional — which is exactly why it must not quietly
    carry authority across.
    """
    number = (
        new_phone
        if isinstance(new_phone, PhoneNumber)
        else parse_phone(new_phone, default_country=default_country)
    )
    moment = now or datetime.now(UTC)

    with engine.begin() as conn:
        previous = conn.execute(
            text("SELECT phone FROM app_user WHERE id = :u FOR UPDATE"), {"u": user_id}
        ).scalar_one_or_none()
        if previous is None:
            raise LookupError(f"no such user: {user_id}")

        conn.execute(
            text(
                """
                UPDATE app_user
                SET phone = :phone,
                    identity_assurance_level = 'none',
                    approval_authority_suspended_at = :now,
                    approval_authority_suspended_reason = 'phone number changed',
                    updated_at = now()
                WHERE id = :u
                """
            ),
            {"phone": number.e164, "u": user_id, "now": moment},
        )
        conn.execute(
            text(
                """
                UPDATE device_session
                SET revoked_at = :now, revoked_reason = 'phone number changed'
                WHERE user_id = :u AND revoked_at IS NULL
                """
            ),
            {"now": moment, "u": user_id},
        )
        write_audit(
            conn,
            action="user.phone_changed",
            entity_type="app_user",
            entity_id=user_id,
            actor_id=user_id,
            before_state={"phone": previous, "identity_assurance_level": "unknown"},
            after_state={
                "phone": number.e164,
                "identity_assurance_level": AssuranceLevel.NONE.value,
                "note": "approval authority withheld until re-verification",
            },
        )


def _authority_suspended(conn: Connection, user_id: uuid.UUID) -> str | None:
    """Why this user's approval authority is suspended, or None.

    Read from a dedicated column rather than inferred from
    ``identity_assurance_level``: a brand new user and a user who changed their number
    both sit at ``none``, and only the second one has had authority *taken away*.
    Treating them the same makes the audit trail unreadable and the error message wrong.
    """
    reason = conn.execute(
        text(
            """
            SELECT approval_authority_suspended_reason FROM app_user
            WHERE id = :u AND approval_authority_suspended_at IS NOT NULL
            """
        ),
        {"u": user_id},
    ).scalar_one_or_none()
    return str(reason) if reason is not None else None


def restore_after_verification(
    engine: Engine,
    user_id: uuid.UUID,
    *,
    device_id: str,
    now: datetime | None = None,
) -> tuple[DeviceSession, str]:
    """Re-establish authority after a verified phone change."""
    session, token = start_session(engine, user_id=user_id, device_id=device_id, now=now)
    with engine.begin() as conn:
        write_audit(
            conn,
            action="user.reverified",
            entity_type="app_user",
            entity_id=user_id,
            actor_kind=ActorKind.SYSTEM,
            after_state={"identity_assurance_level": session.assurance_level.value},
        )
    return session, token
