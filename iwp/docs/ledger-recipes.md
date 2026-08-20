# Posting recipes

**Status:** first cut by engineering. **Requires sign-off from an accountant before alpha.**

The ledger engine (P1.3) enforces that every posting balances. It has no opinion about
*which* accounts a given business event should touch. That opinion lives here, and in
`src/iwp/ledger/recipes.py`, so it can be reviewed in one place by someone who reads
double-entry rather than Python.

Every recipe below is in USD. See "Why the ledger is single-currency at MVP" at the end.

---

## Accounts

| Account | Normal balance | Scope | Meaning |
|---|---|---|---|
| `partner_custody` | debit (asset) | provider | Funds under the settlement partner's control on our instruction |
| `recipient_payable` | credit (liability) | relationship | Committed but not yet delivered |
| `sender_balance` | credit (liability) | user | Stored value held for a sender — non-zero only under custody model B |
| `fee_revenue` | credit (revenue) | system | Fees recognised at commitment |
| `fx_spread_revenue` | credit (revenue) | system | Margin between the rate quoted to us and the rate applied |
| `suspense` | debit (asset) | system | Where a reconciliation discrepancy is parked while a person decides |

No account names a partner or a custody model. Under model A `partner_custody` simply
returns to zero between commitment and settlement; under B and C it carries a real
balance. **No caller branches on which.**

---

## Recipes

Sender commits $102.00 — $100.00 principal, $2.00 fee.

### 1. `funding_committed` — the sender approves

| | Account | Amount |
|---|---|---|
| Debit | `partner_custody` | 10200 |
| Credit | `recipient_payable` | 10000 |
| Credit | `fee_revenue` | 200 |

The fee is recognised at commitment, not at delivery, because that is when it is
earned and disclosed (PRD Feature 7). Recipe 4 reverses it if the transfer fails.

### 2. `settlement_delivered` — the partner confirms the recipient received the money

| | Account | Amount |
|---|---|---|
| Debit | `recipient_payable` | 10000 |
| Credit | `partner_custody` | 10000 |

The obligation is discharged and the cash leaves custody. The $2.00 fee remains in
custody as realised revenue.

### 3. `settlement_partial` — the partner delivered part of it

Same shape as recipe 2, for the amount actually received. The remainder stays in
`recipient_payable`, which is what "remainder tracked and surfaced" (PRD §10) means
concretely: the residual balance on that account *is* the remainder. The transfer's
settlement state stays `in_flight` — see `iwp/states.py` for why partial settlement is
not a state of its own.

### 4. `settlement_failed` — the payout failed

| | Account | Amount |
|---|---|---|
| Debit | `recipient_payable` | 10000 |
| Debit | `fee_revenue` | 200 |
| Credit | `partner_custody` | 10200 |

The fee is given back. Debiting a credit-normal revenue account reduces it, which is
the correct expression of "this fee was never earned". Funds are never silently lost
(PRD §10) — the full 10200 leaves custody, back toward the sender's funding source.

### 5. `transfer_cancelled` — the sender cancelled inside the window

Identical entries to recipe 4, with `posting_type = 'transfer_cancelled'`. The shape is
the same because the money movement is the same; the *reason* differs, and the reason
is what the receipt and the history view show. Keeping them as separate posting types
rather than one type with a flag means the distinction survives into every report.

### 6. `settlement_reversed` — a settled transfer is pulled back

Recipe 2's entries, inverted, as **new** entries (PRD §10: "Recorded as new ledger
entries, never by mutating prior ones"). The original entries stay exactly as they were.

### 7. `reconciliation_adjustment` — a person corrects a discrepancy

Whatever entries the person decides, against `suspense`. **Never written by the
reconciler.** `iwp/ledger/reconciliation.py` has no import path to the posting function,
and a guardrail test enforces that. A discrepancy is resolved by a human who then
records the resulting transaction id against it.

---

## Invariants a reviewer should check

1. Every recipe balances per currency. The engine rejects it otherwise, and the P1.3
   property test asserts the global trial balance is zero after any sequence of postings.
2. No recipe mutates an existing entry. The database refuses.
3. `fee_revenue` is only ever debited by recipes 4 and 5 — a fee refund. If you find a
   third, ask why we are giving money back.
4. `recipient_payable` for a relationship should be zero once every transfer on it has
   reached a terminal settlement state. A non-zero residual means either an untracked
   partial settlement or a missing posting.

## Why the ledger is single-currency at MVP

The recipient is paid in GTQ, but the FX conversion happens at the settlement partner,
and PRD §9 already stores `fx_rate_applied` and `recipient_amount` on the `Transaction`.
Adding GTQ legs to these recipes would mean modelling an FX position we do not hold and
a partner payable we do not owe — inventing accounting for a risk that sits with the
partner.

The engine is fully multi-currency: accounts carry a currency, `Money` refuses to mix
currencies, and postings balance **per currency**, so a GTQ leg cannot be balanced
against a USD leg by accident. The day we take FX risk ourselves, the recipes gain a
`fx_position` pair and nothing in the engine changes.
