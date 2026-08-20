"""Structural guardrails.

CLAUDE.md tells an agent what the rules are. These tests are what make the rules
mechanically true. They read the source tree rather than exercising behaviour, because
the failure modes they catch — a float on a money path, a provider name leaking out of
its adapter, the AI layer reaching for the database — are the ones that pass every
behavioural test right up until they cost someone money.

Each guardrail has a narrow, documented allowlist. Adding to an allowlist should be
uncomfortable; that is the point.
"""

from __future__ import annotations

import ast
from pathlib import Path

import pytest

SRC = Path(__file__).resolve().parents[1] / "src" / "iwp"


def _modules() -> list[Path]:
    return sorted(p for p in SRC.rglob("*.py") if "__pycache__" not in p.parts)


def _rel(path: Path) -> str:
    return str(path.relative_to(SRC))


def _parse(path: Path) -> ast.Module:
    return ast.parse(path.read_text(encoding="utf-8"), filename=str(path))


def _imported_modules(tree: ast.Module) -> set[str]:
    names: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.ImportFrom) and node.module:
            names.add(node.module)
        elif isinstance(node, ast.Import):
            names.update(alias.name for alias in node.names)
    return names


def _docstrings(tree: ast.Module) -> set[str]:
    return {
        text
        for node in ast.walk(tree)
        if isinstance(node, ast.Module | ast.ClassDef | ast.FunctionDef | ast.AsyncFunctionDef)
        for text in [ast.get_docstring(node, clean=False)]
        if text is not None
    }


def _sql_literals(tree: ast.Module) -> list[str]:
    docs = _docstrings(tree)
    return [
        node.value.lower()
        for node in ast.walk(tree)
        if isinstance(node, ast.Constant) and isinstance(node.value, str) and node.value not in docs
    ]


# --------------------------------------------------------------------------------------
# rule 1 — money is integer minor units, never float
# --------------------------------------------------------------------------------------

# Modules permitted to contain a float, with the reason. Nothing here touches an amount.
FLOAT_ALLOWLIST: dict[str, str] = {
    "retry.py": "retry backoff jitter, in seconds — the argument time.sleep takes",
}


def test_no_float_literal_or_conversion_outside_the_allowlist() -> None:
    offenders: list[str] = []
    for path in _modules():
        rel = _rel(path)
        if rel in FLOAT_ALLOWLIST:
            continue
        tree = _parse(path)
        for node in ast.walk(tree):
            if isinstance(node, ast.Constant) and isinstance(node.value, float):
                offenders.append(f"{rel}:{node.lineno} float literal {node.value!r}")
            elif (
                isinstance(node, ast.Call)
                and isinstance(node.func, ast.Name)
                and node.func.id == "float"
            ):
                offenders.append(f"{rel}:{node.lineno} float() conversion")
    assert offenders == [], (
        "floating point reached a module that handles money. CLAUDE.md rule 1.\n"
        + "\n".join(offenders)
    )


def test_the_float_allowlist_only_contains_modules_that_exist() -> None:
    # A stale allowlist entry silently re-permits float in a module that gets recreated
    # under the same name later.
    missing = [rel for rel in FLOAT_ALLOWLIST if not (SRC / rel).exists()]
    assert missing == [], f"stale float allowlist entries: {missing}"


# --------------------------------------------------------------------------------------
# rule 2 — the ledger is append-only, and only one module writes to it
# --------------------------------------------------------------------------------------

LEDGER_WRITER = "ledger/posting.py"
LEDGER_TABLES = ("ledger_entry", "ledger_transaction")


def test_only_the_posting_module_writes_ledger_rows() -> None:
    offenders: list[str] = []
    for path in _modules():
        rel = _rel(path)
        if rel == LEDGER_WRITER:
            continue
        for sql in _sql_literals(_parse(path)):
            for table in LEDGER_TABLES:
                for verb in ("insert into", "update", "delete from"):
                    if f"{verb} {table}" in sql:
                        offenders.append(f"{rel}: {verb} {table}")
    assert offenders == [], (
        f"only {LEDGER_WRITER} may write ledger rows. CLAUDE.md rule 2.\n" + "\n".join(offenders)
    )


def test_nothing_anywhere_updates_or_deletes_a_ledger_row() -> None:
    # Including the posting module. Corrections are new compensating entries.
    offenders: list[str] = []
    for path in _modules():
        for sql in _sql_literals(_parse(path)):
            for table in LEDGER_TABLES:
                for verb in ("update", "delete from"):
                    if f"{verb} {table}" in sql:
                        offenders.append(f"{_rel(path)}: {verb} {table}")
    assert offenders == [], "\n".join(offenders)


# --------------------------------------------------------------------------------------
# rule 7 — no business logic branches on partner identity
# --------------------------------------------------------------------------------------

# Where partner- and BSP-specific code is allowed to live.
ADAPTER_DIRS = ("settlement/adapters", "channels/adapters")

# Brand tokens that must not appear outside an adapter directory. Add the real partner
# and BSP names here the moment they are chosen — that is what makes P3.1's "grep the
# codebase for provider names" an automated check instead of a habit.
BRAND_TOKENS: tuple[str, ...] = ("mockpay", "wavelink")


def test_no_partner_or_bsp_brand_name_outside_its_adapter() -> None:
    offenders: list[str] = []
    for path in _modules():
        rel = _rel(path)
        if any(rel.startswith(d) for d in ADAPTER_DIRS):
            continue
        lowered = path.read_text(encoding="utf-8").lower()
        offenders.extend(f"{rel}: {token}" for token in BRAND_TOKENS if token in lowered)
    assert offenders == [], (
        "a partner or BSP name leaked outside its adapter. CLAUDE.md rule 7.\n"
        + "\n".join(offenders)
    )


# --------------------------------------------------------------------------------------
# rule 8 — the AI layer has no write access and no direct data access
# --------------------------------------------------------------------------------------

DATA_ACCESS_MODULES = ("sqlalchemy", "psycopg", "iwp.db")


def test_the_ai_package_never_imports_the_database() -> None:
    ai_dir = SRC / "ai"
    if not ai_dir.exists():
        pytest.skip("AI package not built yet (P7)")
    offenders: list[str] = []
    for path in sorted(ai_dir.rglob("*.py")):
        if "__pycache__" in path.parts:
            continue
        for name in _imported_modules(_parse(path)):
            if any(name == m or name.startswith(f"{m}.") for m in DATA_ACCESS_MODULES):
                offenders.append(f"{_rel(path)} imports {name}")
    assert offenders == [], (
        "the AI layer must receive a pre-rendered context object and never query the "
        "database. CLAUDE.md rule 8.\n" + "\n".join(offenders)
    )


def test_the_ai_package_never_imports_the_ledger_or_domain_writers() -> None:
    ai_dir = SRC / "ai"
    if not ai_dir.exists():
        pytest.skip("AI package not built yet (P7)")
    forbidden = ("iwp.ledger", "iwp.domain", "iwp.settlement")
    offenders: list[str] = []
    for path in sorted(ai_dir.rglob("*.py")):
        if "__pycache__" in path.parts:
            continue
        for name in _imported_modules(_parse(path)):
            if any(name == m or name.startswith(f"{m}.") for m in forbidden):
                offenders.append(f"{_rel(path)} imports {name}")
    assert offenders == [], "the AI layer has no write access. CLAUDE.md rule 8.\n" + "\n".join(
        offenders
    )


# --------------------------------------------------------------------------------------
# rule 4 — intent state and settlement state are separate fields
# --------------------------------------------------------------------------------------


def test_no_migration_declares_a_single_status_column_on_transaction() -> None:
    migrations = sorted((SRC.parents[1] / "migrations").glob("*.sql"))
    assert migrations, "no migrations found"
    for path in migrations:
        sql = path.read_text(encoding="utf-8").lower()
        if "create table transaction" not in sql:
            continue
        table = sql.split("create table transaction", 1)[1].split(");", 1)[0]
        assert "intent_state" in table, f"{path.name}: transaction lacks intent_state"
        assert "settlement_state" in table, f"{path.name}: transaction lacks settlement_state"
        assert "\n    status " not in table, (
            f"{path.name}: transaction has a collapsed status column. CLAUDE.md rule 4."
        )
