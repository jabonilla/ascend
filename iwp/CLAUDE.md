# Project context for AI agents

## What this is
A cross-border payments product. A US-based sender and a Guatemala-based
recipient share a structured financial relationship. Money moves with a stated
purpose attached and an approval gate. Read docs/immigrant-wealth-protection-PRD-v2.md
before any task.

## NON-NEGOTIABLE RULES

1. MONEY IS INTEGER MINOR UNITS. Never float. Never Decimal-as-string-parsed-lazily.
   Any code that does money math with a floating point type is wrong and must be rejected.

2. LEDGER ENTRIES ARE APPEND-ONLY. Never UPDATE or DELETE a ledger row.
   Corrections are new compensating entries. If you are writing an UPDATE against
   the ledger table, stop.

3. DEBITS MUST EQUAL CREDITS for every transaction. Always. This is asserted in tests.

4. INTENT STATE AND SETTLEMENT STATE ARE SEPARATE FIELDS.
   Never collapse them into one status enum.

5. EVERY STATE TRANSITION WRITES AN AUDIT LOG ROW.

6. EVERY FINANCIAL OPERATION AND EVERY INBOUND CHANNEL MESSAGE IS IDEMPOTENT.
   Assume at-least-once delivery everywhere.

7. NO BUSINESS LOGIC BRANCHES ON PARTNER IDENTITY.
   All settlement goes through the SettlementProvider interface.

8. THE AI LAYER HAS NO WRITE ACCESS AND NO DIRECT DATA ACCESS.
   It receives a pre-rendered context object. It never queries the database.

9. RELATIONSHIPS ARE MANY-TO-MANY. One recipient may have several senders.
   One sender may have several recipients. Never assume 1:1.

10. WRITE THE TEST FIRST for anything touching money, state machines, or the ledger.

## When you are unsure
Stop and ask. Do not invent business rules. Do not guess at money semantics.
Do not "fix" a failing money test by changing the assertion.

## Conventions
- Commits: conventional commits (feat:, fix:, chore:, test:, docs:)
- Every task ends with tests passing and a clean lint run
- No task is complete without its acceptance criteria verified

## Stack (ADR-001)

- **Python 3.11**, package/venv management with `uv`. Source under `src/iwp/`, tests under `tests/`.
- **PostgreSQL 16** is the only datastore. Ledger writes run at `SERIALIZABLE` isolation.
  Append-only is enforced by a database trigger, not by the ORM.
- **SQLAlchemy 2.0 Core** (typed, explicit SQL) — no lazy-loading ORM session magic on
  money paths. Schema lives in `src/iwp/db/schema.py`; migrations are plain SQL files in
  `migrations/` applied by `src/iwp/db/migrate.py`.
- **FastAPI** for HTTP surfaces (channel webhooks, settlement webhooks, sender API).
- **pytest + Hypothesis** for tests. Property tests are mandatory where the build guide
  says so. `pytest-randomly` shuffles test order so nothing passes by ordering luck.
- **ruff** (lint + format) and **mypy --strict** for types.
- `make verify` runs lint, types, and tests. CI runs the same target. All three must pass.

### Layout
```
src/iwp/
  money.py          money primitive          (P1.1)
  db/               schema, engine, migrate  (P1.2)
  ledger/           posting, balances, recon (P1.3-P1.5)
  domain/           users, plans, tiers, requests (P2)
  settlement/       provider interface, mock, lifecycle (P3)
  channels/         adapter, session window, conversations (P4)
  app/              auth, disclosures, receipts, HTTP api (P5)
  ai/               context renderer, guardrails, assistant (P7)
  events/           event taxonomy (P8.1)
```

### Rules that the stack makes enforceable — do not weaken them
- `tests/test_guardrails.py` greps the tree. It fails if a provider or BSP brand name
  appears outside its adapter directory, if the AI package imports the database, or if a
  float creeps onto a money path. If you are tempted to add an exception, you are about
  to break rule 1, 7, or 8.
- Nothing outside `src/iwp/ledger/posting.py` may INSERT into `ledger_entry`.
