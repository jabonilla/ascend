-- P3.3 — settlement lifecycle.
--
-- Two tables that exist because the network is unreliable:
--   * settlement_event records every webhook we have ever seen, keyed by the
--     provider's event id, so at-least-once delivery becomes exactly-once effect.
--   * outbox holds notifications to send, so a crash between "the money failed" and
--     "we told both parties" loses nothing.

-- Where a sender's money comes from (PRD Feature 6).
CREATE TABLE funding_source (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id            UUID        NOT NULL REFERENCES app_user (id),
    -- The provider's identifier. We never hold an account or card number: it stays at
    -- the partner, and the data-minimisation posture in PRD §13 is a reason to keep
    -- it that way.
    provider_reference TEXT        NOT NULL,
    kind               TEXT        NOT NULL CHECK (kind IN ('bank_account', 'debit_card')),
    last4              TEXT        NOT NULL DEFAULT '' CHECK (length(last4) <= 4),
    status             TEXT        NOT NULL DEFAULT 'pending'
                           CHECK (status IN ('pending', 'active', 'removed')),
    is_default         BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX funding_source_user_idx ON funding_source (user_id, status);
-- At most one default per user, enforced rather than assumed.
CREATE UNIQUE INDEX funding_source_one_default_idx
    ON funding_source (user_id) WHERE is_default AND status = 'active';

-- Where the recipient collects (PRD §6 payout methods). Cash pickup is not a fallback:
-- the recipient is often unbanked (PRD §2).
CREATE TABLE payout_destination (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    relationship_id    UUID        NOT NULL REFERENCES relationship (id),
    payout_method      TEXT        NOT NULL
                           CHECK (payout_method IN ('bank_deposit', 'cash_pickup', 'mobile_wallet')),
    account_reference  TEXT        NOT NULL,
    holder_name        TEXT        NOT NULL,
    status             TEXT        NOT NULL DEFAULT 'active'
                           CHECK (status IN ('active', 'removed')),
    is_default         BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX payout_destination_one_default_idx
    ON payout_destination (relationship_id) WHERE is_default AND status = 'active';

-- Every webhook we have ever seen.
CREATE TABLE settlement_event (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider           TEXT        NOT NULL,
    -- The provider's own event id. UNIQUE per provider is the idempotency mechanism:
    -- a redelivered webhook loses the insert and is a no-op.
    provider_event_id  TEXT        NOT NULL,
    transaction_id     UUID        NULL REFERENCES transaction (id),
    provider_reference TEXT        NOT NULL,
    state              TEXT        NOT NULL,
    delivered_amount   BIGINT      NOT NULL DEFAULT 0 CHECK (delivered_amount >= 0),
    currency           CHAR(3)     NOT NULL,
    sequence           INTEGER     NOT NULL,
    occurred_at        TIMESTAMPTZ NOT NULL,
    received_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- FALSE when the event was recorded but did not move our state: a late duplicate,
    -- or an event that would move settlement backwards. Recorded either way, because
    -- an event we chose not to apply is exactly what an operator needs to see when
    -- reconciliation disagrees.
    applied            BOOLEAN     NOT NULL,
    not_applied_reason TEXT        NOT NULL DEFAULT '',
    UNIQUE (provider, provider_event_id)
);

CREATE INDEX settlement_event_transaction_idx ON settlement_event (transaction_id, sequence);
CREATE INDEX settlement_event_reference_idx ON settlement_event (provider_reference);

CREATE TRIGGER settlement_event_append_only
    BEFORE UPDATE OR DELETE ON settlement_event
    FOR EACH ROW EXECUTE FUNCTION reject_row_mutation();

-- Notifications waiting to be sent. Written in the same transaction as the state change
-- that caused them, so "the transfer failed" and "both parties were told" cannot come
-- apart (PRD §10: funds are never silently lost, and neither is the news).
CREATE TABLE outbox (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    topic          TEXT        NOT NULL,
    -- Deduplicates producers: the same logical notification enqueued twice is one row.
    dedupe_key     TEXT        NOT NULL UNIQUE,
    recipient_user_id UUID     NULL REFERENCES app_user (id),
    payload        JSONB       NOT NULL,
    available_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    attempts       INTEGER     NOT NULL DEFAULT 0,
    delivered_at   TIMESTAMPTZ NULL,
    last_error     TEXT        NOT NULL DEFAULT '',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- The claim query: undelivered, due now, oldest first.
CREATE INDEX outbox_pending_idx ON outbox (available_at)
    WHERE delivered_at IS NULL;
