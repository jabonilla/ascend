# Open questions raised by the build

PRD §13 lists the founder's and counsel's open decisions. This file records questions
the *implementation* surfaced — places where the code had to make a choice that a
person should confirm. Each names where the decision is encoded so it can be changed in
one place.

---

## 1. What currency does a recipient mean when they type "500"?

**Where:** `src/iwp/channels/conversations.py`, `_PLAN_CURRENCY`.

Requests are denominated in the plan's currency (USD), because caps and recurring
amounts are in that currency and a tier decision comparing USD to GTQ would be
meaningless. But a recipient in Guatemala typing `500` almost certainly means Q500, and
the difference is roughly 7.75x in the direction that hurts.

The code currently reads it as USD. The copy has to carry the currency explicitly on
every prompt and confirmation, and it does not yet.

**Options:** quote both currencies in the prompt; accept a currency prefix (`Q500` is
already parsed and currently ignored as a marker); or denominate requests in GTQ and
convert for the cap check at the disclosed rate.

**Owner:** founder + research, with recipient testing on real devices (PRD §14 Phase 0).

---

## 2. Which sender is a message about, when a recipient has several?

**Where:** `src/iwp/channels/conversations.py`, `_active_relationship_as`.

PRD §10 says a recipient with several senders "sees requests grouped by sender", and
CLAUDE.md rule 9 says never assume 1:1. The data model is fully many-to-many and the
domain layer handles it. **The conversation layer does not**: an inbound message
resolves to the first active relationship in the relevant role.

For a recipient with two senders, a request would go to the wrong one. This is a
correctness bug for a case the PRD explicitly supports, and it is called out here rather
than hidden because the fix is a product decision, not a coding one: the recipient has
to be asked which sender, and that is an extra exchange in a flow the PRD budgets at
three.

**Options:** ask when ambiguous ("¿Para Marco o para Luisa?" as buttons); default to the
most recent relationship and allow correction; require a per-sender keyword.

**Owner:** founder + research.

---

## 3. What reason is recorded when a sender declines over a channel?

**Where:** `src/iwp/channels/conversations.py`, `PRESET_DECLINE_REASON`.

PRD Feature 1 requires both "one action from any channel" and "declining requires a
reason — selected or written". Over SMS those pull against each other: collecting a
written reason is a second exchange.

Replying `NO` currently selects a preset reason. It satisfies "selected", and the decline
copy tells the recipient the sender will follow up (PRD §10). But the preset is
engineering's wording, not the product's.

**Owner:** founder, with the copy review.

---

## 4. Does a cancellation reach the partner?

**Where:** `src/iwp/settlement/lifecycle.py`, `_recall_from_provider`.

PRD Feature 7 requires a cancellation window. Once an instruction has been accepted by
the provider, whether it can be recalled depends on the partner's capabilities, and
`SettlementProvider` has no `cancel` operation — only `reverse`, which is capability-gated.

Today: our ledger returns the money immediately, a recall is attempted where reversal is
supported, and where it is not the case is flagged for a human and left for
reconciliation. That is honest but it means the sender may be told "cancelled" while the
payout still completes.

**Resolution needed before alpha.** Either the cancellation window must close before we
instruct the provider, or the partner must support recall.

**Owner:** founder + technical, at partner selection.

---

## 5. What is a fee, and what is the FX margin?

PRD §13 already lists both as blocking. Recording here only that the code is ready for
either: fees are an explicit `Money` on approval, the applied FX rate is stored as a
`Decimal` on the transaction, and `docs/ledger-recipes.md` recipe 1 recognises the fee at
commitment and recipe 4 refunds it on failure. No default fee is hardcoded anywhere.

---

## 6. The design system §6.2 banned-word list

**Where:** `src/iwp/voice.py`, `BANNED_WORDS`.

PRD Feature 9 names four words and refers to a design system list that was not supplied
(see `docs/COMPANION-DOCS.md`). The tuple currently holds the four plus a conservative
extension in both languages. **The eval gate in P7.2 cannot be considered complete until
the real list is merged into that tuple.**

**Owner:** design, on delivery of the design system.
