# Build Guide
## Step-by-step execution plan for the technical co-founder

**Audience:** Technical co-founder, and any AI coding agent working under their direction
**Companion docs:** PRD v2.0, Architecture Brief, Partner Evaluation Matrix
**Format:** Every task is self-contained — goal, dependencies, invariants, acceptance criteria, verification command

---

## How to use this document

Tasks are numbered `P{phase}.{task}`. Each is written so it can be handed to an AI coding agent as a single unit of work with no additional context beyond this file, `CLAUDE.md`, and the PRD.

**The rule that matters most:** do not skip the invariants section of any task. This is a financial ledger. An agent will produce plausible, confident, subtly wrong money code if you let it. The invariants and property tests are what stop that.

**Do not work ahead.** Phases 1–4 have no dependency on partner selection — that is deliberate. Phase 6 does. If you find yourself blocked on a partner decision before Phase 6, you have worked ahead.

---

# Phase 0 — Repository & agent setup

## P0.1 — Initialize repository

**Goal:** A repo with docs, structure, and CI skeleton.

```bash
mkdir -p <project> && cd <project> && git init
mkdir -p docs src tests scripts
# Copy all companion docs into docs/
git add . && git commit -m "chore: initial repo with product documentation"
```

**Done when:** all six companion documents are in `docs/` and committed.

---

## P0.2 — Write CLAUDE.md

**Goal:** Persistent context so an agent behaves correctly without re-explanation every session.

Create `CLAUDE.md` at repo root:

```markdown
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
```

**Done when:** `CLAUDE.md` exists and is committed.

---

## P0.3 — Choose the stack

**Goal:** Make and record the stack decision. This is yours, not the founder's.

Decide and write `docs/adr/ADR-001-stack.md` covering: language and runtime, database, mobile framework, hosting, and rationale against the four priorities in the architecture brief (correctness under concurrency, small payloads, two-person operability, auditability).

Then **update `CLAUDE.md`** with a Stack section so agents stop guessing.

**Done when:** ADR-001 committed and CLAUDE.md updated.

> Only hard constraint: the database must support real transactional guarantees and serializable isolation for ledger writes. Everything else is open.

---

## P0.4 — CI skeleton

Set up: test runner, linter, type checker, and a CI pipeline that fails on any of the three. Add a `make verify` (or equivalent) that runs all three locally.

**Done when:** `make verify` passes on an empty project and CI runs on push.

---

# Phase 1 — Ledger core

> No UI. No partner. No channels. This phase is pure correctness.

## P1.1 — Money type

**Goal:** A money primitive that makes float errors impossible.

**Invariants**
- Stored as integer minor units + ISO currency code
- Arithmetic between different currencies raises, never coerces
- No constructor accepts a float
- Division specifies a rounding mode explicitly; no silent rounding

**Acceptance criteria**
- [ ] `Money(1000, "USD")` represents $10.00
- [ ] Adding USD to GTQ raises
- [ ] Constructing from a float raises
- [ ] Allocation splits without losing or inventing minor units (e.g. 100 split 3 ways = 34/33/33)

**Test first.** Include a property test: for any split of any amount into any number of parts, the parts sum exactly to the original.

**Verify:** `make verify`

---

## P1.2 — Ledger schema and append-only enforcement

**Goal:** `LedgerEntry` table with database-level immutability.

**Invariants**
- Append-only enforced at the **database** level, not only in application code — a trigger or equivalent that rejects UPDATE and DELETE
- Every entry has: transaction_id, account_id, direction, amount, currency, entry_type, created_at

**Acceptance criteria**
- [ ] A direct SQL `UPDATE` against the ledger table fails
- [ ] A direct SQL `DELETE` against the ledger table fails
- [ ] Entries are queryable by transaction and by account

> Agent note: the natural instinct is to enforce this in the ORM. That is insufficient. It must fail at the database.

---

## P1.3 — Double-entry posting

**Goal:** A posting function that writes balanced entries atomically.

**Invariants**
- A posting writes all its entries in a single transaction, or none
- Sum of debits equals sum of credits, per transaction, always
- Postings are idempotent by an externally supplied key

**Acceptance criteria**
- [ ] A balanced posting succeeds
- [ ] An unbalanced posting raises and writes nothing
- [ ] Replaying the same idempotency key writes nothing the second time and returns the original result
- [ ] Concurrent postings to the same account do not corrupt balances

**Property test required:** generate random sequences of valid postings; after every sequence, assert global debits equal global credits.

**Concurrency test required:** N parallel postings against one account; assert final balance equals expected sum exactly.

---

## P1.4 — Account model and balance derivation

**Goal:** Balances derived from entries, never stored as a mutable field.

**Invariants**
- Balance is always a function of ledger entries
- If a cached balance exists for performance, it is reconstructible and verified against derivation in tests

**Acceptance criteria**
- [ ] Balance for any account at any point in time is derivable
- [ ] Cached and derived balances match under randomized posting sequences

---

## P1.5 — Reconciliation model

**Goal:** Represent disagreement between our intent record and a provider's settlement record.

**Invariants**
- Our ledger is authoritative for **intent**
- The provider is authoritative for **settlement**
- Disagreements are recorded, never silently resolved in either direction

**Acceptance criteria**
- [ ] A reconciliation run compares our expected settlement state against a provider statement
- [ ] Discrepancies produce a typed record: missing, unexpected, amount mismatch, state mismatch, timing
- [ ] Reconciliation is re-runnable and idempotent
- [ ] A discrepancy never auto-mutates the ledger

**Done when:** you can run reconciliation against a synthetic provider statement and get a correct discrepancy report.

> This task is the heart of the system. Do not rush it. If you build one thing carefully, build this.

---

# Phase 2 — Domain model

## P2.1 — Users and many-to-many relationships

**Invariants**
- A user may hold multiple roles (sender, recipient, both)
- Relationships are many-to-many with a role per edge
- Phone numbers stored E.164

**Acceptance criteria**
- [ ] One recipient can be linked to three senders, each with an independent plan
- [ ] One sender can be linked to three recipients
- [ ] A recipient can become a sender without a new account
- [ ] Relationship states: invited, active, paused, terminated

---

## P2.2 — Money plans with immutable versioning

**Invariants**
- `PlanVersion` is never mutated. Edits create a new version.
- The active version is a pointer, not a flag on rows

**Acceptance criteria**
- [ ] Editing a plan creates a new version and preserves the old one
- [ ] Historical transactions resolve against the plan version in effect at their time
- [ ] Plan history shows who changed what, when

---

## P2.3 — Trust tier classification

**Goal:** Pure function classifying a request into a tier.

**Invariants**
- Deterministic and side-effect free
- Same inputs always produce the same tier
- Never auto-rejects — over-cap requests flag for approval

**Acceptance criteria**
- [ ] Within an active recurring rule and under cap → `recurring`
- [ ] Recurring category but over cap → `unrecognized` (flagged, not rejected)
- [ ] Recurring rule paused → `unrecognized` with paused note
- [ ] Marked urgent by recipient → `emergency`
- [ ] Category not in plan → `unrecognized`

**Test first.** This is a pure function; table-driven tests, exhaustive.

---

## P2.4 — Request and approval state machine

**Invariants**
- Legal transitions only: `pending → approved | declined | expired`
- A declined request never creates a Transaction
- Every transition writes an audit row with actor, channel, and assurance level
- Transitions are idempotent

**Acceptance criteria**
- [ ] Approving a pending request creates a Transaction with `intent_state = committed`
- [ ] Declining requires a reason and creates no Transaction
- [ ] Approving an already-resolved request is a no-op returning the existing result
- [ ] Requests expire after a configured window
- [ ] Every transition produces exactly one audit row

**Property test required:** apply random transition sequences; assert no illegal state is ever reachable.

---

# Phase 3 — Settlement abstraction

## P3.1 — SettlementProvider interface

**Goal:** The boundary that keeps you partner-agnostic.

```
SettlementProvider
  capabilities() -> Capabilities
  quote(amount, from_currency, to_currency) -> Quote      // rate, fees, recipient amount, expiry
  hold(user, amount) -> HoldRef                           // only if supportsHeldBalance
  release(hold_or_source, beneficiary, amount) -> SettlementRef
  status(ref) -> SettlementState
  reverse(ref) -> ReversalRef                             // only if supportsReversal
  statement(period) -> [SettlementRecord]                 // for reconciliation
```

**Invariants**
- No caller ever branches on which provider is in use
- Capability flags gate behavior; unsupported operations raise a typed `CapabilityUnsupported`
- Every call is idempotent by an externally supplied key

**Acceptance criteria**
- [ ] Interface defined with capability flags per PRD §6
- [ ] Calling an unsupported capability raises the typed error, never fails silently
- [ ] Grep the codebase for provider names — zero matches outside the adapter directory

---

## P3.2 — Mock provider

**Goal:** Develop everything without a signed partner.

**Acceptance criteria**
- [ ] Mock is configurable to simulate each of custody models A, B, and C
- [ ] Mock can simulate: success, delay, failure, partial settlement, reversal, timeout, out-of-order webhook
- [ ] Mock produces statements suitable for reconciliation testing
- [ ] Full test suite runs against the mock with no network access

> This unblocks Phases 4 and 5 entirely. Build it well; you will live in it for months.

---

## P3.3 — Settlement lifecycle wiring

**Acceptance criteria**
- [ ] Approval triggers `release()` and moves settlement state to `instructed`
- [ ] Webhooks advance settlement state; duplicates are no-ops
- [ ] Out-of-order webhooks resolve correctly by state, not arrival order
- [ ] Failure moves state to `failed` and notifies both parties
- [ ] Partial settlement records the received amount and tracks the remainder
- [ ] A settlement state change never mutates a ledger entry — it writes new ones

---

# Phase 4 — Channel gateway

## P4.1 — Channel adapter interface

**Invariants**
- Product logic is channel-agnostic; the gateway translates
- Every outbound message logs channel, template, and delivery state
- Every inbound message is idempotent by provider message ID

**Acceptance criteria**
- [ ] Interface supports send-template, send-freeform, and receive
- [ ] BSP is isolated to the adapter — grep for the BSP name returns adapter-only matches
- [ ] Delivery state transitions are recorded

---

## P4.2 — Session window state

**Goal:** Track the WhatsApp 24-hour window per conversation.

**Acceptance criteria**
- [ ] Inbound message opens or refreshes a 24-hour window
- [ ] Outside the window, only approved templates may send; freeform attempts raise
- [ ] Window state is queryable before composing a message
- [ ] Every product notification is classified as session-eligible or template-required

---

## P4.3 — Conversational state machines

**Goal:** Recipient flows over messaging.

**Acceptance criteria**
- [ ] Pairing acceptance completes in ≤3 exchanges (PRD Feature 0)
- [ ] Request submission flow works over WhatsApp buttons and SMS keywords
- [ ] SMS keywords `SI` `NO` `URGENTE` `AYUDA` `RESUMEN` behave per PRD Feature 4, case-insensitive
- [ ] Unrecognized reply returns the keyword help message — never a dead end
- [ ] Reply to a stale request returns current state clearly
- [ ] Duplicate inbound message causes no double action
- [ ] State reconstructs correctly from persisted conversation state, not memory

**Property test required:** replay message sequences with duplicates and reordering; assert final state is always correct.

---

## P4.4 — Fallback and delivery

**Acceptance criteria**
- [ ] WhatsApp delivery failure triggers SMS within 60 seconds, logged
- [ ] Emergency dispatches push, WhatsApp, and SMS in parallel
- [ ] Delivery audit is queryable per notification — required for dispute resolution

---

# Phase 5 — Sender application

## P5.1 — Auth and assurance levels

**Acceptance criteria**
- [ ] Phone-based auth with verification
- [ ] Every approval records actor and assurance level
- [ ] Step-up triggers above a configurable value threshold
- [ ] App required above a second, higher threshold
- [ ] Thresholds change without a deploy
- [ ] Number change requires re-verification before approval authority restores
- [ ] A second device invalidates the prior session

---

## P5.2 — Core screens

Build against the design system (`docs/design-system.md`, tokens in `design-system-visual.html`).

**Order:** onboarding → plan creation → request inbox and approval → transaction history → detail view.

**Acceptance criteria**
- [ ] Approval is one action from a push notification without opening the app
- [ ] History is list-only — no charts (PRD Feature 8)
- [ ] Failed transactions display with plain-language explanation
- [ ] Empty states are warm and actionable
- [ ] Full Spanish and English throughout

---

## P5.3 — Disclosures, receipts, cancellation

> Content pending counsel. Build the surfaces now.

**Acceptance criteria**
- [ ] Pre-commitment disclosure shows amount, fees, FX rate, recipient amount, estimated availability
- [ ] Disclosure appears on every channel where a transfer can be committed
- [ ] Receipt delivered post-commitment with a reference number
- [ ] Receipts retrievable from history indefinitely
- [ ] Cancellation window with remaining time clearly shown

---

# Phase 6 — Partner integration

> **Blocked until the partner is signed.** Do not start early.

## P6.1 — Real provider adapter

**Acceptance criteria**
- [ ] Implements `SettlementProvider` with no changes to any caller
- [ ] Full test suite passes against the real sandbox
- [ ] Capability flags reflect actual partner capability, verified in sandbox
- [ ] Webhook signature verification implemented

**Verification:** switch a config value from mock to real. Nothing else changes. If anything else has to change, P3.1 was done wrong — fix the abstraction, not the caller.

---

## P6.2 — Reconciliation against real statements

**Acceptance criteria**
- [ ] Daily reconciliation runs automatically
- [ ] Discrepancies alert a human
- [ ] A reconciliation report is produced and retained
- [ ] Zero unexplained discrepancies across 30 consecutive days before alpha

---

# Phase 7 — AI layer

> Build last. It depends on rendered context from everything above.

## P7.1 — Context renderer

**Invariants**
- The AI receives **only** a server-rendered context object
- Values are pre-formatted by the same code path that renders the UI
- The AI never queries the database
- The AI has no write access

**Acceptance criteria**
- [ ] Context object contains formatted strings, not raw numerics for the model to reformat
- [ ] A request for data absent from context returns a deterministic non-generated response
- [ ] Grep confirms the AI module has no database imports

---

## P7.2 — Evaluation harness

**Build this before the assistant itself.**

**Acceptance criteria**
- [ ] ≥100 adversarial prompts in Guatemalan Spanish with expected behaviors
- [ ] Categories per PRD Feature 9: balance elicitation, transfer confirmation, FX quoting, delivery guarantees, action attempts, banned words, regional idioms
- [ ] Runs in CI; **any failure blocks deploy**
- [ ] Reports pass rate per category
- [ ] Banned-word check is a separate hard gate at 100%

> Agent warning: an agent asked to "make the eval pass" may weaken assertions. Assertions are frozen. Only the implementation changes. Review every diff that touches the eval directory.

---

## P7.3 — Assistant implementation

**Acceptance criteria**
- [ ] Eval suite at 100%
- [ ] Available on app, WhatsApp, and SMS with consistent voice
- [ ] Spanish and English, switchable
- [ ] Escalation to human with defined triggers
- [ ] Unavailability produces a clear fallback

---

# Phase 8 — Instrumentation & alpha

## P8.1 — Event taxonomy

**Acceptance criteria**
- [ ] Every metric in PRD §11 maps to a named event
- [ ] Events fire from server, not client, wherever the server knows
- [ ] Dashboard exists **before** alpha
- [ ] Analytics respects the data-minimization posture from counsel

---

## P8.2 — Operational readiness

**Acceptance criteria**
- [ ] Deploy runbook with tested rollback
- [ ] Incident response plan
- [ ] Database backup with a **tested restore**
- [ ] Error tracking and alerting
- [ ] Status page

---

## P8.3 — Alpha

**Acceptance criteria**
- [ ] 5–10 real pairs, known network, real money, small amounts
- [ ] Daily reconciliation clean
- [ ] Every failure documented and triaged
- [ ] No unexplained ledger discrepancy at any point

---

# Working with an AI agent — specific guidance

**Give it one task at a time.** Paste the task block. It is self-contained by design.

**Force test-first on anything touching money.** Prompt shape:

> Read CLAUDE.md and docs/build-guide.md task P1.3. Write the failing tests first, including the required property test and concurrency test. Show me the tests. Do not write the implementation until I approve the tests.

**Watch for these failure modes specifically:**

| Failure mode | What it looks like | Defense |
|---|---|---|
| Float money | `amount * 1.05` anywhere | Grep for float ops on money in review |
| Weakened assertions | Test edited to pass | Assertions are frozen; review every test diff |
| Ledger mutation | An `UPDATE` on ledger | Database-level trigger from P1.2 catches it |
| Invented business rules | Plausible logic not in the PRD | Ask "which PRD line specifies this?" |
| Partner leakage | Provider name outside adapter | Grep in CI |
| Collapsed states | One `status` field | Schema review |
| Silent reconciliation fix | Discrepancy auto-resolved | P1.5 forbids it; assert in tests |

**Reject any diff you do not understand.** On a ledger, "it passes the tests" is not sufficient. You must be able to explain why it is correct.

**Commit per task.** Small diffs. Reviewable.

---

# Critical path summary

```
P0 setup ──► P1 ledger ──► P2 domain ──► P3 settlement abstraction ──┐
                                                                     │
                              P4 channels ─────────────────────────► P5 app
                                                                     │
   [partner signed] ──► P6 real integration ◄────────────────────────┘
                                    │
                                    ▼
                          P7 AI ──► P8 alpha
```

**Phases 1–5 require no partner.** That is the point of P3.1. If you are blocked on a partner decision before P6, you have worked ahead — return to the ledger or the channel gateway.

**The two highest-risk tasks are P1.5 (reconciliation) and P4.3 (conversational state).** Both are correctness problems disguised as plumbing. Both are where an agent will produce confident, wrong code. Spend disproportionate review time there.

---

*Update this document as decisions land. It is a working plan, not a contract.*
