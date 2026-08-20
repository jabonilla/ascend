"""Reading what a person actually typed.

Every function here is pure and total: it returns an interpretation, never raises at
the user. PRD Feature 4 is explicit that an unrecognized reply gets the keyword help
message and never a dead end, and that starts with parsing that shrugs rather than
throws.
"""

from __future__ import annotations

import enum
import re
from typing import Final

from iwp.money import Money
from iwp.voice import fold

__all__ = ["Intent", "extract_amount", "interpret", "parse_amount", "parse_choice"]

# Keywords are Spanish-only per PRD Feature 4, case-insensitive, and matched after
# accent folding so "SÍ" and "si" are the same. The English words are accepted too:
# a bilingual sender typing YES should not hit a dead end over it.
_YES: Final = frozenset({"si", "sí", "s", "yes", "y", "ok", "dale", "aprobar", "aceptar"})
_NO: Final = frozenset({"no", "n", "ahorita no", "rechazar", "decline"})
_URGENT: Final = frozenset({"urgente", "urgent", "emergencia", "emergency"})
_HELP: Final = frozenset({"ayuda", "help", "?", "menu", "menú"})
_SUMMARY: Final = frozenset({"resumen", "summary", "estado"})

# Strict: the whole message is an amount, give or take a currency marker. Anything
# looser and "hola 500 hola" reads as a request for five hundred dollars.
_AMOUNT_RE: Final = re.compile(
    r"^(?:q\.?|\$|us\$)?\s*([\d][\d.,]*)\s*(?:usd|gtq|q|dolares|quetzales)?$"
)

# Lenient: find an amount inside a longer sentence. Only used where the intent is
# already known from a keyword, e.g. "URGENTE 500 para la medicina".
_EMBEDDED_AMOUNT_RE: Final = re.compile(r"\d[\d.,]*")
_CHOICE_RE: Final = re.compile(r"^([1-9]\d?)$")


class Intent(enum.Enum):
    """What a message means, before knowing the conversation's state."""

    YES = "yes"
    NO = "no"
    URGENT = "urgent"
    HELP = "help"
    SUMMARY = "summary"
    AMOUNT = "amount"
    CHOICE = "choice"
    UNKNOWN = "unknown"


def interpret(body: str, button_payload: str = "") -> tuple[Intent, str]:
    """Classify a message. Returns the intent and the token it was read from.

    A tapped button wins over typed text: if the user tapped ``Aprobar`` and the client
    also sent the label as the body, they meant the button.

    ``AMOUNT`` and ``CHOICE`` are both returned for a bare small number, with ``CHOICE``
    winning here — the caller resolves the ambiguity against conversation state, which
    is where the PRD says it belongs.
    """
    raw = (button_payload or body or "").strip()
    folded = fold(raw)
    if not folded:
        return Intent.UNKNOWN, raw

    if folded in _YES:
        return Intent.YES, raw
    if folded in _NO:
        return Intent.NO, raw
    if folded in _HELP:
        return Intent.HELP, raw
    if folded in _SUMMARY:
        return Intent.SUMMARY, raw
    # URGENTE may lead a longer message ("URGENTE 500 para la medicina").
    first_word = folded.split()[0]
    if first_word in _URGENT:
        return Intent.URGENT, raw

    if _CHOICE_RE.match(folded):
        return Intent.CHOICE, raw
    if parse_amount(folded, "USD") is not None:
        return Intent.AMOUNT, raw

    return Intent.UNKNOWN, raw


def parse_choice(body: str, *, options: int) -> int | None:
    """A 1-based menu selection, or None."""
    match = _CHOICE_RE.match(fold(body).strip())
    if match is None:
        return None
    value = int(match.group(1))
    return value if 1 <= value <= options else None


def parse_amount(body: str, currency: str) -> Money | None:
    """Read a typed amount, or None if it is not one.

    Separator handling is the fiddly part, and getting it wrong turns Q1.500 into one
    quetzal fifty. The rule: with both separators present the *last* one is decimal;
    with one separator, three trailing digits mean thousands and one or two mean
    decimal. That covers both the 1.500,00 and 1,500.00 conventions, which both appear
    in this corridor.
    """
    match = _AMOUNT_RE.match(fold(body).strip())
    if match is None:
        return None

    digits = match.group(1)
    if not any(ch.isdigit() for ch in digits):
        return None

    last_dot = digits.rfind(".")
    last_comma = digits.rfind(",")
    decimal_at = max(last_dot, last_comma)

    if decimal_at == -1:
        whole, fraction = digits, ""
    else:
        trailing = len(digits) - decimal_at - 1
        if trailing == 3 and (last_dot == -1 or last_comma == -1):
            # A single separator with exactly three digits after it is a thousands
            # separator, not a decimal point.
            whole, fraction = digits.replace(".", "").replace(",", ""), ""
        elif 1 <= trailing <= 2:
            whole = digits[:decimal_at].replace(".", "").replace(",", "")
            fraction = digits[decimal_at + 1 :]
        else:
            return None

    whole = whole.replace(".", "").replace(",", "")
    if not whole.isdigit() or (fraction and not fraction.isdigit()):
        return None

    try:
        amount = Money.parse(f"{whole}.{fraction or '0'}", currency)
    except (ValueError, TypeError):
        return None
    return amount if amount.is_positive else None


def extract_amount(body: str, currency: str) -> Money | None:
    """Find an amount inside a longer message.

    Used only once the intent is already established by a keyword — "URGENTE 500 para
    la medicina" is unambiguously a request for 500. Never used to *decide* whether a
    message is an amount; :func:`parse_amount` does that, strictly, because a sentence
    that merely contains a number is not a request for money.
    """
    for token in _EMBEDDED_AMOUNT_RE.findall(fold(body)):
        amount = parse_amount(token, currency)
        if amount is not None:
            return amount
    return None
