"""E.164 phone numbers.

The recipient persona "changes phone numbers frequently" (PRD §2) and reaches us over
WhatsApp and SMS, where a number arrives in whatever shape the sender typed it. This
module normalises that into one canonical form, and refuses to guess.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Final

__all__ = ["GUATEMALA", "UNITED_STATES", "CountryCode", "PhoneNumber", "parse_phone"]

_E164: Final = re.compile(r"^\+[1-9]\d{6,14}$")
_STRIPPABLE: Final = re.compile(r"[\s()\-.]")


@dataclass(frozen=True, slots=True)
class CountryCode:
    """A country's dialling code and the national number length we expect from it."""

    iso: str
    dialling_code: str
    national_length: int


UNITED_STATES: Final = CountryCode(iso="US", dialling_code="1", national_length=10)
GUATEMALA: Final = CountryCode(iso="GT", dialling_code="502", national_length=8)

_COUNTRIES: Final[dict[str, CountryCode]] = {c.iso: c for c in (UNITED_STATES, GUATEMALA)}


@dataclass(frozen=True, slots=True)
class PhoneNumber:
    """A validated E.164 number. Construct through :func:`parse_phone`."""

    e164: str

    def __post_init__(self) -> None:
        if not _E164.match(self.e164):
            raise ValueError(f"not a valid E.164 number: {self.e164!r}")

    def __str__(self) -> str:
        return self.e164


def parse_phone(raw: str, *, default_country: str | None = None) -> PhoneNumber:
    """Normalise a typed phone number to E.164.

    ``default_country`` is how a national-format number becomes international, and it
    has no default value. Guessing the country from the shape of a number is how a
    Guatemalan 8-digit number silently becomes a US area code.
    """
    if not isinstance(raw, str):
        raise TypeError(f"phone number must be a string, got {type(raw).__name__}")

    cleaned = _STRIPPABLE.sub("", raw.strip())
    if not cleaned:
        raise ValueError("phone number is empty")

    # 00 is the international access prefix used across much of Latin America.
    if cleaned.startswith("00"):
        cleaned = "+" + cleaned[2:]

    if cleaned.startswith("+"):
        return PhoneNumber(cleaned)

    if default_country is None:
        raise ValueError(
            f"{raw!r} has no country code and no default_country was given. "
            "Refusing to guess which country a national number belongs to."
        )
    country = _COUNTRIES.get(default_country.upper())
    if country is None:
        raise ValueError(f"unsupported default_country: {default_country!r}")

    digits = cleaned.lstrip("0")
    if not digits.isdigit():
        raise ValueError(f"not a phone number: {raw!r}")
    if len(digits) != country.national_length:
        raise ValueError(
            f"{raw!r} is {len(digits)} digits; a {country.iso} national number is "
            f"{country.national_length}"
        )
    return PhoneNumber(f"+{country.dialling_code}{digits}")
