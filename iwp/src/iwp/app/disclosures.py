"""P5.3 — pre-commitment disclosures, receipts, and the cancellation window.

PRD Feature 7. The exact obligations are pending counsel's Reg E analysis, so what is
built here is the *surface*: the numbers, where they come from, when they are shown, and
the record that they were. Counsel finalises the wording; none of that changes the
shape.

Two things this file is careful about, because they are the ones that quietly go wrong:

* **Every figure is derived from the same quote.** The disclosure, the transaction and
  the receipt all read one ``Quote``. Recomputing the recipient amount for the receipt
  from a stored rate is how a receipt ends up one minor unit away from what the person
  was shown.
* **The rate disclosed is the rate applied.** PRD Feature 7: "FX rate presentation shows
  the actual rate applied, not a marketing rate." For a user who has been quietly
  overcharged for years, this is the trust surface.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from decimal import Decimal

from sqlalchemy import Engine, text
from sqlalchemy.engine import Connection

from iwp.money import Money
from iwp.settlement.provider import Quote, SettlementLatency

__all__ = [
    "CancellationWindow",
    "Disclosure",
    "Receipt",
    "cancellation_window",
    "disclosure_for",
    "issue_receipt",
    "receipt_for_transaction",
    "record_disclosure",
    "render_disclosure",
    "render_receipt",
]

# Plain-language availability, per settlement latency. Never a promise: PRD §6 is
# explicit that urgent requests buy the sender's *attention* faster, never a guarantee
# that money arrives faster, and all copy must reflect that.
_AVAILABILITY: dict[SettlementLatency, dict[str, str]] = {
    SettlementLatency.INSTANT: {
        "es-GT": "Normalmente en minutos",
        "en-US": "Usually within minutes",
    },
    SettlementLatency.SAME_DAY: {
        "es-GT": "Normalmente el mismo día",
        "en-US": "Usually the same day",
    },
    SettlementLatency.MULTI_DAY: {
        "es-GT": "Normalmente en 1 a 3 días hábiles",
        "en-US": "Usually 1 to 3 business days",
    },
}


@dataclass(frozen=True, slots=True)
class Disclosure:
    """Everything a sender must see before committing (PRD Feature 7)."""

    send_amount: Money
    fee: Money
    total_charged: Money
    fx_rate: Decimal
    recipient_amount: Money
    estimated_availability: str
    quote_expires_at: datetime
    locale: str

    def is_expired(self, now: datetime) -> bool:
        return now >= self.quote_expires_at


@dataclass(frozen=True, slots=True)
class Receipt:
    """What the sender gets after committing. Retrievable indefinitely."""

    transaction_id: uuid.UUID
    reference_number: str
    send_amount: Money
    fee: Money
    total_charged: Money
    fx_rate: Decimal
    recipient_amount: Money
    issued_at: datetime
    locale: str
    rendered_text: str


@dataclass(frozen=True, slots=True)
class CancellationWindow:
    """How long the sender has, and how long is left."""

    closes_at: datetime | None
    now: datetime

    @property
    def is_open(self) -> bool:
        return self.closes_at is not None and self.now < self.closes_at

    @property
    def remaining(self) -> timedelta:
        if self.closes_at is None or self.now >= self.closes_at:
            return timedelta(0)
        return self.closes_at - self.now

    def describe(self, locale: str = "es-GT") -> str:
        """Plain language, because "how long do I have" is the actual question.

        PRD Feature 7: the sender can cancel within the window "and see clearly how
        long they have".
        """
        if not self.is_open:
            return (
                "Ya no se puede cancelar."
                if locale.startswith("es")
                else "This can no longer be cancelled."
            )
        minutes = max(1, int(self.remaining.total_seconds() // 60))
        if locale.startswith("es"):
            unit = "minuto" if minutes == 1 else "minutos"
            return f"Puedes cancelar durante {minutes} {unit} más."
        unit = "minute" if minutes == 1 else "minutes"
        return f"You can cancel for {minutes} more {unit}."


# --------------------------------------------------------------------------------------
# building
# --------------------------------------------------------------------------------------


def disclosure_for(
    quote: Quote, *, latency: SettlementLatency, locale: str = "es-GT"
) -> Disclosure:
    """Build a disclosure from the quote the transfer will actually use."""
    availability = _AVAILABILITY[latency].get(locale) or _AVAILABILITY[latency]["es-GT"]
    return Disclosure(
        send_amount=quote.send_amount,
        fee=quote.fee,
        total_charged=quote.total_charged,
        fx_rate=quote.fx_rate,
        recipient_amount=quote.recipient_amount,
        estimated_availability=availability,
        quote_expires_at=quote.expires_at,
        locale=locale,
    )


def render_disclosure(disclosure: Disclosure) -> str:
    """Render for display. The same text goes on every channel.

    PRD Feature 7: "Disclosure is shown on every channel where a transfer can be
    committed." One renderer rather than one per surface, so a channel cannot end up
    showing three of the five required figures.
    """
    spanish = disclosure.locale.startswith("es")
    labels = (
        ("Envías", "Comisión", "Total que pagas", "Tipo de cambio", "Recibe", "Disponible")
        if spanish
        else ("You send", "Fee", "Total charged", "Exchange rate", "They receive", "Available")
    )
    return "\n".join(
        [
            f"{labels[0]}: {disclosure.send_amount}",
            f"{labels[1]}: {disclosure.fee}",
            f"{labels[2]}: {disclosure.total_charged}",
            f"{labels[3]}: 1 {disclosure.send_amount.currency.code} = "
            f"{disclosure.fx_rate.normalize()} {disclosure.recipient_amount.currency.code}",
            f"{labels[4]}: {disclosure.recipient_amount}",
            f"{labels[5]}: {disclosure.estimated_availability}",
        ]
    )


def record_disclosure(
    engine: Engine,
    disclosure: Disclosure,
    *,
    request_id: uuid.UUID,
    user_id: uuid.UUID,
    channel: str,
) -> uuid.UUID:
    """Record that this disclosure was shown, on this channel, at this moment.

    The obligation is to have shown it. "We would have shown that" is not evidence, and
    the row is append-only for the same reason.
    """
    with engine.begin() as conn:
        disclosure_id: uuid.UUID = conn.execute(
            text(
                """
                INSERT INTO disclosure_record
                    (request_id, user_id, channel, locale, send_amount, fee_amount,
                     currency, fx_rate, recipient_amount, recipient_currency,
                     estimated_availability, rendered_text, quote_expires_at)
                VALUES
                    (:request_id, :user_id, :channel, :locale, :send, :fee, :currency,
                     :rate, :recipient, :recipient_currency, :availability, :text,
                     :expires)
                RETURNING id
                """
            ),
            {
                "request_id": request_id,
                "user_id": user_id,
                "channel": channel,
                "locale": disclosure.locale,
                "send": disclosure.send_amount.minor_units,
                "fee": disclosure.fee.minor_units,
                "currency": disclosure.send_amount.currency.code,
                "rate": disclosure.fx_rate,
                "recipient": disclosure.recipient_amount.minor_units,
                "recipient_currency": disclosure.recipient_amount.currency.code,
                "availability": disclosure.estimated_availability,
                "text": render_disclosure(disclosure),
                "expires": disclosure.quote_expires_at,
            },
        ).scalar_one()
    return disclosure_id


# --------------------------------------------------------------------------------------
# receipts
# --------------------------------------------------------------------------------------


def render_receipt(
    *,
    reference_number: str,
    send_amount: Money,
    fee: Money,
    fx_rate: Decimal,
    recipient_amount: Money,
    locale: str,
) -> str:
    spanish = locale.startswith("es")
    header = "Comprobante" if spanish else "Receipt"
    reference_label = "Referencia" if spanish else "Reference"
    body = render_disclosure(
        Disclosure(
            send_amount=send_amount,
            fee=fee,
            total_charged=send_amount + fee,
            fx_rate=fx_rate,
            recipient_amount=recipient_amount,
            estimated_availability="",
            quote_expires_at=datetime.now(UTC),
            locale=locale,
        )
    )
    # Drop the availability line: a receipt describes what happened, not what is
    # expected to happen.
    lines = [line for line in body.splitlines() if not line.endswith(": ")]
    return "\n".join([f"{header} {reference_label}: {reference_number}", *lines])


def issue_receipt(
    engine: Engine,
    transaction_id: uuid.UUID,
    *,
    locale: str = "es-GT",
) -> Receipt:
    """Issue the receipt for a committed transaction, or return the one already issued.

    Idempotent: a receipt is issued once and never reissued with different numbers.
    A UNIQUE constraint on ``transaction_id`` makes that true even under a retry.
    """
    with engine.begin() as conn:
        existing = _load_receipt(conn, transaction_id)
        if existing is not None:
            return existing

        row = (
            conn.execute(
                text(
                    """
                    SELECT amount, currency, fee_amount, fx_rate_applied,
                           recipient_amount, recipient_currency, reference_number
                    FROM transaction WHERE id = :t
                    """
                ),
                {"t": transaction_id},
            )
            .mappings()
            .one_or_none()
        )
        if row is None:
            raise LookupError(f"no such transaction: {transaction_id}")
        if row["fx_rate_applied"] is None or row["recipient_amount"] is None:
            raise ValueError(
                f"transaction {transaction_id} has no applied rate yet; a receipt "
                "quoting a rate we have not applied would be a false statement"
            )

        send_amount = Money(int(row["amount"]), str(row["currency"]))
        fee = Money(int(row["fee_amount"]), str(row["currency"]))
        recipient_amount = Money(int(row["recipient_amount"]), str(row["recipient_currency"]))
        rendered = render_receipt(
            reference_number=str(row["reference_number"]),
            send_amount=send_amount,
            fee=fee,
            fx_rate=row["fx_rate_applied"],
            recipient_amount=recipient_amount,
            locale=locale,
        )

        conn.execute(
            text(
                """
                INSERT INTO receipt
                    (transaction_id, reference_number, locale, send_amount, fee_amount,
                     currency, fx_rate, recipient_amount, recipient_currency, rendered_text)
                VALUES
                    (:t, :reference, :locale, :send, :fee, :currency, :rate, :recipient,
                     :recipient_currency, :text)
                """
            ),
            {
                "t": transaction_id,
                "reference": row["reference_number"],
                "locale": locale,
                "send": send_amount.minor_units,
                "fee": fee.minor_units,
                "currency": send_amount.currency.code,
                "rate": row["fx_rate_applied"],
                "recipient": recipient_amount.minor_units,
                "recipient_currency": recipient_amount.currency.code,
                "text": rendered,
            },
        )
        issued = _load_receipt(conn, transaction_id)
        assert issued is not None  # just inserted
        return issued


def _load_receipt(conn: Connection, transaction_id: uuid.UUID) -> Receipt | None:
    row = (
        conn.execute(
            text(
                """
                SELECT transaction_id, reference_number, locale, send_amount, fee_amount,
                       currency, fx_rate, recipient_amount, recipient_currency,
                       rendered_text, issued_at
                FROM receipt WHERE transaction_id = :t
                """
            ),
            {"t": transaction_id},
        )
        .mappings()
        .one_or_none()
    )
    if row is None:
        return None
    send_amount = Money(int(row["send_amount"]), str(row["currency"]))
    fee = Money(int(row["fee_amount"]), str(row["currency"]))
    return Receipt(
        transaction_id=row["transaction_id"],
        reference_number=row["reference_number"],
        send_amount=send_amount,
        fee=fee,
        total_charged=send_amount + fee,
        fx_rate=row["fx_rate"],
        recipient_amount=Money(int(row["recipient_amount"]), str(row["recipient_currency"])),
        issued_at=row["issued_at"],
        locale=row["locale"],
        rendered_text=row["rendered_text"],
    )


def receipt_for_transaction(engine: Engine, transaction_id: uuid.UUID) -> Receipt | None:
    """Retrieve a receipt. Available for as long as the row exists — indefinitely."""
    with engine.connect() as conn:
        return _load_receipt(conn, transaction_id)


# --------------------------------------------------------------------------------------
# cancellation
# --------------------------------------------------------------------------------------


def cancellation_window(
    engine: Engine, transaction_id: uuid.UUID, *, now: datetime | None = None
) -> CancellationWindow:
    """How long the sender has left to cancel."""
    moment = now or datetime.now(UTC)
    with engine.connect() as conn:
        closes_at = conn.execute(
            text("SELECT cancellable_until FROM transaction WHERE id = :t"),
            {"t": transaction_id},
        ).scalar_one_or_none()
    return CancellationWindow(closes_at=closes_at, now=moment)
