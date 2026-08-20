"""P1.1 — the money primitive.

Rule 1 of ``CLAUDE.md``: money is integer minor units. This module is the only place in
the codebase permitted to convert between a human decimal representation and an amount,
and it never does so via a float.

Design notes
------------
* ``Money`` holds ``minor_units: int`` plus a ``Currency``. There is no major-unit field
  and no ``Decimal`` field to drift out of sync with it.
* Every operation that cannot be exact takes an explicit ``Rounding``. There is no
  default rounding mode anywhere in this module, on purpose: a default is a silent
  rounding policy, and silent rounding policies are how ledgers lose cents.
* ``allocate`` uses largest-remainder distribution, which conserves every minor unit for
  positive and negative amounts alike.
"""

from __future__ import annotations

import enum
import re
from dataclasses import dataclass
from decimal import (
    ROUND_CEILING,
    ROUND_DOWN,
    ROUND_FLOOR,
    ROUND_HALF_EVEN,
    ROUND_HALF_UP,
    Decimal,
    localcontext,
)
from decimal import ROUND_UP as DEC_ROUND_UP
from fractions import Fraction
from typing import Final, Self

__all__ = [
    "GTQ",
    "USD",
    "Currency",
    "CurrencyMismatch",
    "Money",
    "MoneyError",
    "Rounding",
    "UnknownCurrency",
    "currency",
]


class MoneyError(Exception):
    """Base class for every error raised by this module."""


class CurrencyMismatch(MoneyError):
    """Raised when an operation would mix two currencies.

    Never coerce. A cross-currency conversion is a settlement event with a quoted rate,
    not an arithmetic operator.
    """

    def __init__(self, left: Currency, right: Currency) -> None:
        super().__init__(f"cannot combine {left.code} with {right.code}")
        self.left = left
        self.right = right


class UnknownCurrency(MoneyError):
    """Raised for a currency code that is not in the registry."""


@dataclass(frozen=True, slots=True)
class Currency:
    """An ISO 4217 currency and the number of decimal places its minor unit has."""

    code: str
    exponent: int
    name: str

    @property
    def minor_units_per_major(self) -> int:
        return int(10**self.exponent)

    def __str__(self) -> str:
        return self.code


USD: Final = Currency(code="USD", exponent=2, name="US Dollar")
GTQ: Final = Currency(code="GTQ", exponent=2, name="Guatemalan Quetzal")

# Extend deliberately. A currency the product has not been designed for should raise
# rather than be assumed to have two decimal places — JPY and KWD do not.
_REGISTRY: Final[dict[str, Currency]] = {c.code: c for c in (USD, GTQ)}

_DECIMAL_STRING: Final = re.compile(r"^[+-]?\d+(\.\d+)?$")


def currency(code: str | Currency) -> Currency:
    """Resolve a currency code to a :class:`Currency`.

    Case is normalised; nothing else is guessed.
    """
    if isinstance(code, Currency):
        return code
    if not isinstance(code, str):
        raise TypeError(f"currency code must be a string, got {type(code).__name__}")
    try:
        return _REGISTRY[code.strip().upper()]
    except KeyError:
        raise UnknownCurrency(f"unknown currency code: {code!r}") from None


class Rounding(enum.Enum):
    """Rounding modes. There is deliberately no default."""

    HALF_UP = ROUND_HALF_UP
    """Ties away from zero. Conventional for consumer-facing money."""

    HALF_EVEN = ROUND_HALF_EVEN
    """Ties to even (banker's rounding). Minimises drift over many operations."""

    DOWN = ROUND_DOWN
    """Toward zero (truncate)."""

    UP = DEC_ROUND_UP
    """Away from zero."""

    FLOOR = ROUND_FLOOR
    """Toward negative infinity."""

    CEILING = ROUND_CEILING
    """Toward positive infinity."""


def _reject_non_integer(value: object, what: str) -> None:
    """Reject floats, bools and Decimals where an exact integer is required.

    ``bool`` is an ``int`` subclass, so ``isinstance(value, int)`` alone would let
    ``Money(True, "USD")`` through as one minor unit.
    """
    if isinstance(value, bool):
        raise TypeError(f"{what} must be an int, got bool — refusing to treat it as 0/1")
    if isinstance(value, float):
        raise TypeError(
            f"{what} must be an int minor-unit amount, got float. "
            "Floating point is never permitted on a money path (CLAUDE.md rule 1). "
            "Use Money.parse('10.00', 'USD') for a decimal string."
        )
    if isinstance(value, Decimal):
        raise TypeError(
            f"{what} must be an int minor-unit amount, got Decimal — ambiguous. "
            "Use Money.parse() for a decimal string, or int(...) for minor units."
        )
    if not isinstance(value, int):
        raise TypeError(f"{what} must be an int, got {type(value).__name__}")


@dataclass(frozen=True, slots=True, order=False)
class Money:
    """An exact amount of a single currency, held as integer minor units.

    ``Money(1000, "USD")`` is ten US dollars.
    """

    minor_units: int
    currency: Currency

    def __init__(self, minor_units: int, currency_code: str | Currency) -> None:
        _reject_non_integer(minor_units, "minor_units")
        object.__setattr__(self, "minor_units", int(minor_units))
        object.__setattr__(self, "currency", currency(currency_code))

    # -- construction ------------------------------------------------------------------

    @classmethod
    def zero(cls, currency_code: str | Currency) -> Self:
        return cls(0, currency_code)

    @classmethod
    def parse(cls, text: str, currency_code: str | Currency) -> Self:
        """Build from an exact decimal string such as ``"10.00"``.

        Raises if the string carries more precision than the currency's minor unit can
        represent — silently dropping a third decimal place is exactly the class of bug
        this type exists to prevent.
        """
        if not isinstance(text, str):
            raise TypeError(
                f"Money.parse expects a decimal string, got {type(text).__name__}. "
                "Floats are never accepted on a money path."
            )
        cur = currency(currency_code)
        cleaned = text.strip()
        if not _DECIMAL_STRING.match(cleaned):
            raise ValueError(f"not an exact decimal string: {text!r}")
        _, _, frac = cleaned.partition(".")
        if len(frac) > cur.exponent:
            raise ValueError(
                f"{text!r} has more precision than {cur.code} "
                f"(exponent {cur.exponent}) can represent"
            )
        with localcontext() as ctx:
            ctx.prec = 60
            scaled = Decimal(cleaned) * cur.minor_units_per_major
        return cls(int(scaled), cur)

    # -- rendering ---------------------------------------------------------------------

    def to_decimal(self) -> Decimal:
        """Exact decimal representation. For display and disclosure only."""
        with localcontext() as ctx:
            ctx.prec = 60
            return Decimal(self.minor_units) / self.currency.minor_units_per_major

    def to_decimal_string(self) -> str:
        sign = "-" if self.minor_units < 0 else ""
        units = abs(self.minor_units)
        per = self.currency.minor_units_per_major
        if self.currency.exponent == 0:
            return f"{sign}{units}"
        return f"{sign}{units // per}.{units % per:0{self.currency.exponent}d}"

    def __str__(self) -> str:
        return f"{self.currency.code} {self.to_decimal_string()}"

    def __repr__(self) -> str:
        return f"Money({self.minor_units!r}, {self.currency.code!r})"

    # -- predicates --------------------------------------------------------------------

    @property
    def is_zero(self) -> bool:
        return self.minor_units == 0

    @property
    def is_positive(self) -> bool:
        return self.minor_units > 0

    @property
    def is_negative(self) -> bool:
        return self.minor_units < 0

    # -- arithmetic --------------------------------------------------------------------

    def _same_currency(self, other: Money) -> None:
        if self.currency is not other.currency:
            raise CurrencyMismatch(self.currency, other.currency)

    def __add__(self, other: Money) -> Money:
        if not isinstance(other, Money):
            return NotImplemented
        self._same_currency(other)
        return Money(self.minor_units + other.minor_units, self.currency)

    def __sub__(self, other: Money) -> Money:
        if not isinstance(other, Money):
            return NotImplemented
        self._same_currency(other)
        return Money(self.minor_units - other.minor_units, self.currency)

    def __neg__(self) -> Money:
        return Money(-self.minor_units, self.currency)

    def __abs__(self) -> Money:
        return Money(abs(self.minor_units), self.currency)

    def __mul__(self, factor: int) -> Money:
        """Multiply by a whole number. Exact, so no rounding mode is needed.

        Anything inexact — an FX rate, a percentage fee — goes through :meth:`scale`,
        which demands an explicit rounding mode.
        """
        _reject_non_integer(factor, "multiplication factor")
        return Money(self.minor_units * factor, self.currency)

    __rmul__ = __mul__

    def scale(self, factor: Decimal | Fraction | int, rounding: Rounding) -> Money:
        """Multiply by an exact rational factor, rounding as instructed.

        ``rounding`` is positional and required. Callers must state the policy.
        """
        if isinstance(factor, bool | float):
            raise TypeError(
                "scale factor must be Decimal, Fraction or int — never float (CLAUDE.md rule 1)"
            )
        if not isinstance(rounding, Rounding):
            raise TypeError("rounding must be a Rounding member")
        exact = Fraction(self.minor_units) * Fraction(factor)
        return Money(_round_fraction(exact, rounding), self.currency)

    def divide(self, divisor: int, rounding: Rounding) -> Money:
        """Divide by a whole number, rounding as instructed.

        This is *not* how you split an amount between parties — it loses or invents
        minor units by design. Use :meth:`allocate` or :meth:`split` for that.
        """
        _reject_non_integer(divisor, "divisor")
        if divisor == 0:
            raise ZeroDivisionError("cannot divide Money by zero")
        if not isinstance(rounding, Rounding):
            raise TypeError("rounding must be a Rounding member")
        return Money(_round_fraction(Fraction(self.minor_units, divisor), rounding), self.currency)

    # -- allocation --------------------------------------------------------------------

    def allocate(self, ratios: list[int] | tuple[int, ...]) -> list[Money]:
        """Split across ``ratios`` conserving every minor unit.

        Largest-remainder distribution: each part gets the floor of its exact share, and
        the leftover minor units are handed out one at a time from the front. The parts
        always sum exactly to ``self``, for positive and negative amounts alike.
        """
        ratios = list(ratios)
        if not ratios:
            raise ValueError("allocate needs at least one ratio")
        for r in ratios:
            _reject_non_integer(r, "ratio")
            if r < 0:
                raise ValueError("ratios must be non-negative")
        total = sum(ratios)
        if total <= 0:
            raise ValueError("ratios must sum to a positive number")

        shares = [self.minor_units * r // total for r in ratios]  # floor division
        remainder = self.minor_units - sum(shares)
        # ``remainder`` is in [0, len(ratios)) for a positive amount and, because floor
        # division rounds toward -inf, also non-negative for a negative amount.
        for i in range(remainder):
            shares[i % len(shares)] += 1
        return [Money(s, self.currency) for s in shares]

    def split(self, parts: int) -> list[Money]:
        """Split evenly into ``parts``, conserving every minor unit."""
        _reject_non_integer(parts, "parts")
        if parts <= 0:
            raise ValueError("parts must be positive")
        return self.allocate([1] * parts)

    # -- ordering ----------------------------------------------------------------------

    def __eq__(self, other: object) -> bool:
        # Stays total so Money is usable as a dict key / in a set.
        if not isinstance(other, Money):
            return NotImplemented
        return self.minor_units == other.minor_units and self.currency is other.currency

    def __hash__(self) -> int:
        return hash((self.minor_units, self.currency.code))

    def __lt__(self, other: Money) -> bool:
        if not isinstance(other, Money):
            return NotImplemented
        self._same_currency(other)
        return self.minor_units < other.minor_units

    def __le__(self, other: Money) -> bool:
        if not isinstance(other, Money):
            return NotImplemented
        self._same_currency(other)
        return self.minor_units <= other.minor_units

    def __gt__(self, other: Money) -> bool:
        if not isinstance(other, Money):
            return NotImplemented
        self._same_currency(other)
        return self.minor_units > other.minor_units

    def __ge__(self, other: Money) -> bool:
        if not isinstance(other, Money):
            return NotImplemented
        self._same_currency(other)
        return self.minor_units >= other.minor_units


def _round_fraction(value: Fraction, rounding: Rounding) -> int:
    """Round an exact rational to an integer under the named policy.

    Goes through ``Decimal`` with enough precision to be exact for any amount this
    system will see, so the six modes behave exactly as ``decimal`` documents them.
    """
    with localcontext() as ctx:
        ctx.prec = 80
        quotient = Decimal(value.numerator) / Decimal(value.denominator)
        return int(quotient.quantize(Decimal(1), rounding=rounding.value))


def total(amounts: list[Money] | tuple[Money, ...], currency_code: str | Currency) -> Money:
    """Sum a collection, with the currency stated by the caller.

    The currency is required so that summing an empty list still yields a typed zero
    rather than raising or guessing.
    """
    result = Money.zero(currency_code)
    for amount in amounts:
        result = result + amount
    return result
