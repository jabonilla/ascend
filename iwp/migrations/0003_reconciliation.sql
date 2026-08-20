-- P1.5 — reconciliation.
--
-- Our ledger is authoritative for intent; the provider is authoritative for
-- settlement. Where they disagree, the disagreement is recorded here and resolved by
-- a person. Nothing in this schema lets a discrepancy change the ledger.

CREATE TABLE reconciliation_run (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider        TEXT        NOT NULL,
    period_start    TIMESTAMPTZ NOT NULL,
    period_end      TIMESTAMPTZ NOT NULL,
    expected_count  INTEGER     NOT NULL,
    statement_count INTEGER     NOT NULL,
    matched_count   INTEGER     NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (period_end > period_start)
);

CREATE INDEX reconciliation_run_period_idx
    ON reconciliation_run (provider, period_start, period_end);

CREATE TABLE reconciliation_discrepancy (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    run_id              UUID        NOT NULL REFERENCES reconciliation_run (id),
    -- The five kinds named in build guide P1.5. Constrained here so a sixth kind
    -- cannot be introduced by a typo in application code.
    kind                TEXT        NOT NULL CHECK (kind IN (
                            'missing', 'unexpected', 'amount_mismatch',
                            'state_mismatch', 'timing')),
    business_txn_id     UUID        NULL,
    provider_reference  TEXT        NULL,
    -- Both sides of the disagreement, recorded verbatim. Neither is corrected.
    our_amount          BIGINT      NULL,
    our_currency        CHAR(3)     NULL,
    our_state           TEXT        NULL,
    provider_amount     BIGINT      NULL,
    provider_currency   CHAR(3)     NULL,
    provider_state      TEXT        NULL,
    detail              TEXT        NOT NULL,
    -- Deterministic identity of this disagreement. Re-running the same period over
    -- the same data must not produce a second row for the same problem, so the
    -- uniqueness of this key is what makes reconciliation idempotent.
    discrepancy_key     TEXT        NOT NULL UNIQUE,
    first_seen_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX reconciliation_discrepancy_run_idx ON reconciliation_discrepancy (run_id);
CREATE INDEX reconciliation_discrepancy_txn_idx
    ON reconciliation_discrepancy (business_txn_id) WHERE business_txn_id IS NOT NULL;

-- A discrepancy record is evidence. It is never edited or withdrawn.
CREATE TRIGGER reconciliation_discrepancy_append_only
    BEFORE UPDATE OR DELETE ON reconciliation_discrepancy
    FOR EACH ROW EXECUTE FUNCTION reject_row_mutation();

CREATE TRIGGER reconciliation_discrepancy_no_truncate
    BEFORE TRUNCATE ON reconciliation_discrepancy
    FOR EACH STATEMENT EXECUTE FUNCTION reject_statement_mutation();

-- Resolutions are appended, not written over the discrepancy. The current status of a
-- discrepancy is its latest resolution row; the history of who said what stays intact.
CREATE TABLE reconciliation_resolution (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    discrepancy_id  UUID        NOT NULL REFERENCES reconciliation_discrepancy (id),
    -- Never NULL: resolving a discrepancy is a human act, by design.
    actor_id        UUID        NOT NULL,
    status          TEXT        NOT NULL CHECK (status IN (
                        'acknowledged', 'resolved', 'reopened')),
    note            TEXT        NOT NULL,
    -- The compensating posting a person chose to make, if any. The reconciler never
    -- sets this: a correcting entry is written by the ordinary posting path, and its
    -- id is recorded here afterwards.
    compensating_txn_id UUID    NULL REFERENCES ledger_transaction (id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX reconciliation_resolution_discrepancy_idx
    ON reconciliation_resolution (discrepancy_id, created_at);

CREATE TRIGGER reconciliation_resolution_append_only
    BEFORE UPDATE OR DELETE ON reconciliation_resolution
    FOR EACH ROW EXECUTE FUNCTION reject_row_mutation();
