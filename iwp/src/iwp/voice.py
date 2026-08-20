"""Product voice rules that every surface shares.

The same copy system, banned words and voice apply to every channel (PRD Feature 4,
cross-channel). Keeping them here rather than inside the AI package means the channel
gateway and the assistant are held to one standard, and neither has to import the other.
"""

from __future__ import annotations

import re
import unicodedata
from typing import Final

__all__ = ["BANNED_WORDS", "banned_words_in", "fold", "is_within_line_budget"]

# Words the product never says to a user.
#
# PRD Feature 9 names the first four explicitly. The design system §6.2 list was not
# supplied to this build (see docs/COMPANION-DOCS.md) — **merge it into this tuple when
# it arrives**; this is the single place that has to change, and the eval gate in P7.2
# reads it from here.
#
# The reasoning behind them: a sender who has been quietly overcharged for years does
# not need to be reminded that they are being processed. Say what is happening in plain
# words instead.
BANNED_WORDS: Final[tuple[str, ...]] = (
    # PRD Feature 9, verbatim.
    "compliance",
    "kyc",
    "aml",
    "regulatory",
    # Conservative extension, in both languages, pending the design system list.
    "cumplimiento normativo",
    "regulatorio",
    "regulacion",
    "antilavado",
    "lavado de dinero",
    "money laundering",
    "sanctions screening",
    "risk score",
    "puntaje de riesgo",
    "flagged for review",
    "suspicious activity",
    "actividad sospechosa",
    "verificacion de identidad obligatoria",
)

_WORD_BOUNDARY_CACHE: dict[str, re.Pattern[str]] = {}


def fold(text: str) -> str:
    """Lowercase and strip accents.

    Guatemalan Spanish is typed with and without accents, on keyboards that make them
    awkward. Every comparison in the product folds first, so ``SÍ`` and ``si`` are the
    same word — and so a banned word cannot be smuggled past by dropping an accent.
    """
    decomposed = unicodedata.normalize("NFD", text.casefold())
    return "".join(ch for ch in decomposed if not unicodedata.combining(ch))


def _pattern(word: str) -> re.Pattern[str]:
    if word not in _WORD_BOUNDARY_CACHE:
        # Word boundaries so "aml" does not match inside "familia", which in Spanish
        # copy it otherwise would, constantly.
        _WORD_BOUNDARY_CACHE[word] = re.compile(rf"(?<!\w){re.escape(fold(word))}(?!\w)")
    return _WORD_BOUNDARY_CACHE[word]


def banned_words_in(text: str) -> list[str]:
    """Every banned word present in ``text``. Empty means the copy is clean."""
    folded = fold(text)
    return [word for word in BANNED_WORDS if _pattern(word).search(folded)]


def is_within_line_budget(body: str, *, max_lines: int = 3) -> bool:
    """PRD Feature 4: a WhatsApp message body never exceeds 3 lines before its buttons.

    The floor is 2G on a shared mid-tier Android (PRD §2). Three lines is not a style
    preference, it is what fits on the screen the recipient actually holds.
    """
    return len([line for line in body.strip().splitlines() if line.strip()]) <= max_lines
