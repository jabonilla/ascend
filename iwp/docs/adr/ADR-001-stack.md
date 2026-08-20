# ADR-001 — Stack

**Status:** Accepted
**Date:** 2026-08-20
**Decider:** Technical co-founder
**Supersedes:** nothing

---

## Context

Build guide P0.3 requires a recorded stack decision covering language and runtime,
database, mobile framework, hosting, and rationale against the four priorities named in
the architecture brief:

1. correctness under concurrency
2. small payloads
3. two-person operability
4. auditability

The only hard constraint is that the database must support real transactional guarantees
and serializable isolation for ledger writes.

The architecture brief itself was not supplied to this build (see
`docs/COMPANION-DOCS.md`); the four priorities are taken verbatim from build guide P0.3.

---

## Decision

### Language and runtime: Python 3.11

Chosen over TypeScript/Node and Go.

- **Correctness under concurrency.** The correctness surface here is not request
  throughput, it is *ledger* correctness — and that is enforced by Postgres, not by the
  application runtime. What the application language has to do well is express invariants
  and test them. Python's Hypothesis is the strongest property-testing library available
  in any of the three candidate ecosystems, and the build guide mandates property tests in
  four separate tasks (P1.1, P1.3, P2.4, P4.3). Choosing the language with the best
  property-testing story is choosing the priority the build guide ranked first.
- **Two-person operability.** One deployable, one language, one test runner. A Node
  backend plus a Python data/AI layer would be two of everything.
- Rejected **Go**: better raw concurrency primitives, materially worse property-testing
  and fixture ergonomics, and we do not need its concurrency ceiling — Postgres is the
  serialization point.
- Rejected **TypeScript**: viable, and its integer-money story via `bigint` is fine, but
  its property-testing and stateful-model-testing tooling is weaker, and we would be
  choosing it mostly for shared types with a React Native client we have not committed to.

Money is `int` minor units end to end. Python's arbitrary-precision integers remove a
whole class of overflow bug that a 64-bit-integer language would leave us to reason about.

### Database: PostgreSQL 16, and only PostgreSQL

- Meets the hard constraint: real transactions, and `SERIALIZABLE` isolation used
  explicitly on every ledger posting.
- **Auditability.** Append-only is enforced by a `BEFORE UPDATE OR DELETE` trigger on
  `ledger_entry` and `audit_log`. This is a database guarantee, not an ORM convention —
  P1.2 is explicit that ORM-level enforcement is insufficient.
- **Two-person operability.** No Redis, no queue broker, no separate search index at MVP.
  Scheduled work (recurring rules, digests, reconciliation, expiry sweeps) runs as
  `SELECT ... FOR UPDATE SKIP LOCKED` over a Postgres-backed outbox/job table. One
  datastore to back up, and one *restore* to test (P8.2).
- Advisory locks give us per-account serialization where we want to avoid full
  serialization retries.

### Data access: SQLAlchemy 2.0 Core, not the ORM's unit-of-work

Typed Core expressions, explicit statements, explicit transaction boundaries. The reason
is rule 2: a unit-of-work session flushes UPDATEs for you, and on a ledger the thing you
most need is for an UPDATE to be impossible to write by accident. Migrations are plain,
reviewable SQL applied by a tiny in-repo runner — a money schema change should be readable
as SQL by counsel's auditor, not as a Python DSL.

### HTTP: FastAPI

Channel webhooks, settlement webhooks, and the sender API. Chosen for Pydantic request
validation at the boundary, which is where untrusted payloads (BSP and settlement partner
webhooks) arrive.

### Mobile framework: React Native — decision recorded, build deferred

- The recipient never installs an app (PRD §2). The app is a **sender** surface only, and
  PRD §3 makes it additive rather than required. So the mobile client is not on the
  critical path and must not be allowed to dictate the backend.
- React Native over native-twice: two-person team, and the sender screens (P5.2) are
  list-and-form surfaces, not graphics-heavy — the framework tax is low.
- **Deferred, not started.** P5.2 says to build against `docs/design-system.md` and
  `design-system-visual.html`, neither of which exists in this repo. The API those screens
  will call is built and tested; the screens are not.
- Push: FCM + APNs directly, no third-party push aggregator, because approval-from-
  notification (Feature 1) needs notification *actions*, and aggregators complicate that.

### Hosting: single containerized service + managed Postgres

- One container image, one managed Postgres with point-in-time recovery, one object store
  for attachments. Deliberately boring, and the same shape in staging and production.
- **Small payloads** is a channel property, not a hosting property: the recipient's
  surfaces are WhatsApp/SMS text, measured in bytes. The rule that protects the 2G floor
  lives in the channel gateway (message body ≤3 lines before buttons, PRD Feature 4), not
  in the infrastructure. Image uploads are the only expensive path and are recipient-
  initiated, direct-to-object-store, and never on a blocking path.
- No serverless at MVP: `SERIALIZABLE` retries and connection pooling against Postgres are
  simpler with long-lived processes, and a two-person team should not be debugging cold
  starts on a money path.

---

## Consequences

- Every ledger write pays a serialization-failure retry cost. Accepted: it is the price of
  the guarantee, and the retry is contained in one function (`ledger/posting.py`).
- Python's GIL caps CPU-bound throughput per process. Irrelevant at this stage — the work
  is I/O against Postgres and partner APIs — and horizontally scalable when it stops being.
- No Redis means no off-the-shelf rate limiter or scheduler. Both are implemented against
  Postgres. Emergency rate limiting (PRD Feature 3, max 3 per relationship per 7 days) is
  a query, not a counter that can drift.
- Choosing SQLAlchemy Core over the ORM costs some verbosity in domain code. Accepted for
  the money paths; it is not a general prohibition on convenience elsewhere.
