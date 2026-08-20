"""P1.1 — money primitive.

Invariants under test (build guide P1.1):
  * stored as integer minor units + ISO currency code
  * arithmetic between different currencies raises, never coerces
  * no constructor accepts a float
  * division specifies a rounding mode explicitly; no silent rounding
"""

from __future__ import annotations

from decimal import Decimal
from fractions import Fraction

import pytest
from hypothesis import given
from hypothesis import strategies as st

from iwp.money import (
    GTQ,
    USD,
    CurrencyMismatch,
    Money,
    Rounding,
    UnknownCurrency,
)

# --------------------------------------------------------------------------------------
# construction
# --------------------------------------------------------------------------------------


def test_money_is_integer_minor_units() -> None:
    m = Money(1000, "USD")
    assert m.minor_units == 1000
    assert m.currency is USD
    assert str(m) == "USD 10.00"


def test_constructing_from_a_float_raises() -> None:
    with pytest.raises(TypeError):
        Money(10.00, "USD")  # type: ignore[arg-type]
    with pytest.raises(TypeError):
        Money(1000.0, "USD")  # type: ignore[arg-type]


def test_constructing_from_a_bool_raises() -> None:
    # bool is an int subclass; it must not slip through as 0/1 minor units.
    with pytest.raises(TypeError):
        Money(True, "USD")  # mypy sees bool as int; the runtime check is what stops it


def test_constructing_from_a_decimal_raises() -> None:
    # Decimal is exact but ambiguous: 10 minor units or 10 dollars? Force the caller
    # to use the named constructor.
    with pytest.raises(TypeError):
        Money(Decimal("10.00"), "USD")  # type: ignore[arg-type]


def test_unknown_currency_raises() -> None:
    with pytest.raises(UnknownCurrency):
        Money(100, "XYZ")


def test_currency_code_is_normalised_but_not_guessed() -> None:
    assert Money(100, "usd").currency is USD


def test_parse_from_exact_decimal_string() -> None:
    assert Money.parse("10.00", "USD") == Money(1000, "USD")
    assert Money.parse("10", "USD") == Money(1000, "USD")
    assert Money.parse("-0.01", "USD") == Money(-1, "USD")
    assert Money.parse("1234.56", "GTQ") == Money(123456, "GTQ")


def test_parse_rejects_more_precision_than_the_currency_has() -> None:
    with pytest.raises(ValueError, match="precision"):
        Money.parse("10.005", "USD")


def test_parse_rejects_a_float() -> None:
    with pytest.raises(TypeError):
        Money.parse(10.00, "USD")  # type: ignore[arg-type]


def test_zero_helper() -> None:
    assert Money.zero("USD") == Money(0, "USD")
    assert Money.zero("USD").is_zero


# --------------------------------------------------------------------------------------
# arithmetic
# --------------------------------------------------------------------------------------


def test_addition_of_same_currency() -> None:
    assert Money(1000, "USD") + Money(250, "USD") == Money(1250, "USD")


def test_adding_usd_to_gtq_raises() -> None:
    with pytest.raises(CurrencyMismatch):
        Money(1000, "USD") + Money(1000, "GTQ")


def test_subtracting_across_currencies_raises() -> None:
    with pytest.raises(CurrencyMismatch):
        Money(1000, "USD") - Money(1000, "GTQ")


def test_comparing_across_currencies_raises() -> None:
    with pytest.raises(CurrencyMismatch):
        _ = Money(1000, "USD") < Money(1000, "GTQ")


def test_equality_across_currencies_is_false_not_an_error() -> None:
    # __eq__ must stay total: dict/set membership depends on it.
    assert Money(1000, "USD") != Money(1000, "GTQ")


def test_negation_and_absolute() -> None:
    assert -Money(1000, "USD") == Money(-1000, "USD")
    assert abs(Money(-1000, "USD")) == Money(1000, "USD")


def test_multiplication_by_an_integer_is_exact() -> None:
    assert Money(333, "USD") * 3 == Money(999, "USD")


def test_multiplication_by_a_float_raises() -> None:
    with pytest.raises(TypeError):
        _ = Money(1000, "USD") * 1.05  # type: ignore[operator]


def test_scaling_requires_an_explicit_rounding_mode() -> None:
    with pytest.raises(TypeError):
        Money(1000, "USD").scale(Decimal("1.05"))  # type: ignore[call-arg]


def test_scaling_with_explicit_rounding() -> None:
    m = Money(1000, "USD")
    assert m.scale(Decimal("1.055"), Rounding.HALF_UP) == Money(1055, "USD")
    assert m.scale(Fraction(1, 3), Rounding.DOWN) == Money(333, "USD")
    assert m.scale(Fraction(1, 3), Rounding.UP) == Money(334, "USD")


def test_scale_rejects_a_float_factor() -> None:
    with pytest.raises(TypeError):
        Money(1000, "USD").scale(1.05, Rounding.HALF_UP)  # type: ignore[arg-type]


def test_division_requires_an_explicit_rounding_mode() -> None:
    with pytest.raises(TypeError):
        Money(1000, "USD").divide(3)  # type: ignore[call-arg]


def test_division_with_explicit_rounding() -> None:
    assert Money(1000, "USD").divide(3, Rounding.DOWN) == Money(333, "USD")
    assert Money(1000, "USD").divide(3, Rounding.UP) == Money(334, "USD")
    assert Money(1000, "USD").divide(3, Rounding.HALF_EVEN) == Money(333, "USD")


def test_division_by_zero_raises() -> None:
    with pytest.raises(ZeroDivisionError):
        Money(1000, "USD").divide(0, Rounding.HALF_UP)


def test_rounding_modes_on_a_negative_amount() -> None:
    m = Money(-1000, "USD")
    assert m.divide(3, Rounding.DOWN) == Money(-333, "USD")  # toward zero
    assert m.divide(3, Rounding.UP) == Money(-334, "USD")  # away from zero
    assert m.divide(3, Rounding.FLOOR) == Money(-334, "USD")  # toward -inf
    assert m.divide(3, Rounding.CEILING) == Money(-333, "USD")  # toward +inf


# --------------------------------------------------------------------------------------
# allocation
# --------------------------------------------------------------------------------------


def test_allocate_100_three_ways() -> None:
    parts = Money(100, "USD").split(3)
    assert [p.minor_units for p in parts] == [34, 33, 33]
    assert sum(p.minor_units for p in parts) == 100


def test_allocate_by_ratio() -> None:
    parts = Money(500, "USD").allocate([3, 7])
    assert [p.minor_units for p in parts] == [150, 350]


def test_allocate_by_ratio_with_a_remainder_favours_the_earlier_ratio() -> None:
    parts = Money(5, "USD").allocate([3, 7])
    assert [p.minor_units for p in parts] == [2, 3]
    assert sum(p.minor_units for p in parts) == 5


def test_allocate_rejects_an_empty_or_zero_ratio_list() -> None:
    with pytest.raises(ValueError, match="ratio"):
        Money(100, "USD").allocate([])
    with pytest.raises(ValueError, match="ratio"):
        Money(100, "USD").allocate([0, 0])
    with pytest.raises(ValueError, match="ratio"):
        Money(100, "USD").allocate([-1, 2])


def test_split_rejects_non_positive_parts() -> None:
    with pytest.raises(ValueError):
        Money(100, "USD").split(0)


# --------------------------------------------------------------------------------------
# property tests — required by P1.1
# --------------------------------------------------------------------------------------

amounts = st.integers(min_value=-(10**12), max_value=10**12)
part_counts = st.integers(min_value=1, max_value=64)
ratio_lists = st.lists(st.integers(min_value=0, max_value=10**6), min_size=1, max_size=32).filter(
    lambda rs: sum(rs) > 0
)


@given(amount=amounts, n=part_counts)
def test_property_split_conserves_every_minor_unit(amount: int, n: int) -> None:
    """For any split of any amount into any number of parts, the parts sum exactly."""
    parts = Money(amount, "USD").split(n)
    assert len(parts) == n
    assert sum(p.minor_units for p in parts) == amount
    assert all(p.currency is USD for p in parts)


@given(amount=amounts, ratios=ratio_lists)
def test_property_allocate_conserves_every_minor_unit(amount: int, ratios: list[int]) -> None:
    parts = Money(amount, "USD").allocate(ratios)
    assert len(parts) == len(ratios)
    assert sum(p.minor_units for p in parts) == amount


@given(amount=amounts, n=part_counts)
def test_property_split_parts_differ_by_at_most_one_minor_unit(amount: int, n: int) -> None:
    parts = [p.minor_units for p in Money(amount, "USD").split(n)]
    assert max(parts) - min(parts) <= 1


@given(a=amounts, b=amounts)
def test_property_addition_is_associative_and_exact(a: int, b: int) -> None:
    assert Money(a, "USD") + Money(b, "USD") == Money(a + b, "USD")


@given(amount=amounts)
def test_property_parse_round_trips_through_the_decimal_string(amount: int) -> None:
    m = Money(amount, "USD")
    assert Money.parse(m.to_decimal_string(), "USD") == m


@given(
    amount=amounts,
    divisor=st.integers(min_value=1, max_value=1000),
    rounding=st.sampled_from(list(Rounding)),
)
def test_property_division_never_moves_by_more_than_one_minor_unit(
    amount: int, divisor: int, rounding: Rounding
) -> None:
    got = Money(amount, "USD").divide(divisor, rounding).minor_units
    exact = Fraction(amount, divisor)
    assert abs(Fraction(got) - exact) < 1


def test_gtq_and_usd_are_distinct_currency_objects() -> None:
    assert USD is not GTQ
    assert USD.code == "USD"
    assert GTQ.code == "GTQ"
    assert USD.exponent == GTQ.exponent == 2
