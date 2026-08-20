-- P5.1 — authentication and assurance.
--
-- PRD Feature 5: "Approving a request moves money. Every approval is an authentication
-- event." Shared devices and frequent number changes (PRD §2) make phone-as-identity
-- insufficient on its own, so identity here is a phone number *plus* what we know
-- about how the person proved it, and when.

-- A one-time verification code. The code itself is never stored — only a hash — so a
-- database read cannot be turned into an account takeover.
CREATE TABLE verification_code (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone        TEXT        NOT NULL,
    code_hash    TEXT        NOT NULL,
    purpose      TEXT        NOT NULL CHECK (purpose IN ('login', 'phone_change', 'step_up')),
    attempts     INTEGER     NOT NULL DEFAULT 0,
    max_attempts INTEGER     NOT NULL DEFAULT 5,
    expires_at   TIMESTAMPTZ NOT NULL,
    consumed_at  TIMESTAMPTZ NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX verification_code_lookup_idx
    ON verification_code (phone, purpose, created_at DESC);

-- A device that has proved the phone number.
CREATE TABLE device_session (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID        NOT NULL REFERENCES app_user (id),
    -- Client-generated and stable per install. Not a secret; the session token is.
    device_id        TEXT        NOT NULL,
    token_hash       TEXT        NOT NULL UNIQUE,
    assurance_level  TEXT        NOT NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at       TIMESTAMPTZ NOT NULL,
    revoked_at       TIMESTAMPTZ NULL,
    revoked_reason   TEXT        NOT NULL DEFAULT ''
);

CREATE INDEX device_session_user_idx ON device_session (user_id, revoked_at);

-- PRD Feature 5: "Number change requires re-verification before any approval authority
-- is restored." Tracked explicitly rather than by reading identity_assurance_level,
-- because "has never verified" and "verified, then changed number" are different facts
-- and conflating them makes both unreadable.
ALTER TABLE app_user
    ADD COLUMN approval_authority_suspended_at TIMESTAMPTZ NULL,
    ADD COLUMN approval_authority_suspended_reason TEXT NOT NULL DEFAULT '';

-- PRD Feature 5: per-transaction and per-day limits a sender sets for a relationship.
-- Integer minor units, NULL for no limit. Distinct from the system-wide limits in
-- runtime_setting: those are ours, these are the sender's.
ALTER TABLE relationship
    ADD COLUMN per_transaction_limit BIGINT NULL
        CHECK (per_transaction_limit IS NULL OR per_transaction_limit > 0),
    ADD COLUMN per_day_limit BIGINT NULL
        CHECK (per_day_limit IS NULL OR per_day_limit > 0),
    ADD COLUMN limit_currency CHAR(3) NOT NULL DEFAULT 'USD';

-- Disclosures shown before a commitment (PRD Feature 7). Recorded because the
-- obligation is to have shown them, and "we would have shown that" is not evidence.
CREATE TABLE disclosure_record (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id         UUID        NOT NULL REFERENCES request (id),
    user_id            UUID        NOT NULL REFERENCES app_user (id),
    channel            TEXT        NOT NULL CHECK (channel IN ('app', 'whatsapp', 'sms')),
    locale             TEXT        NOT NULL,
    send_amount        BIGINT      NOT NULL,
    fee_amount         BIGINT      NOT NULL,
    currency           CHAR(3)     NOT NULL,
    fx_rate            NUMERIC(20, 10) NOT NULL,
    recipient_amount   BIGINT      NOT NULL,
    recipient_currency CHAR(3)     NOT NULL,
    estimated_availability TEXT    NOT NULL,
    rendered_text      TEXT        NOT NULL,
    quote_expires_at   TIMESTAMPTZ NOT NULL,
    shown_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX disclosure_record_request_idx ON disclosure_record (request_id, shown_at);

CREATE TRIGGER disclosure_record_append_only
    BEFORE UPDATE OR DELETE ON disclosure_record
    FOR EACH ROW EXECUTE FUNCTION reject_row_mutation();

-- Receipts (PRD Feature 7). Retrievable indefinitely, so the row is the receipt rather
-- than something regenerated later from data that may have moved on.
CREATE TABLE receipt (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id     UUID        NOT NULL UNIQUE REFERENCES transaction (id),
    reference_number   TEXT        NOT NULL,
    locale             TEXT        NOT NULL,
    send_amount        BIGINT      NOT NULL,
    fee_amount         BIGINT      NOT NULL,
    currency           CHAR(3)     NOT NULL,
    fx_rate            NUMERIC(20, 10) NOT NULL,
    recipient_amount   BIGINT      NOT NULL,
    recipient_currency CHAR(3)     NOT NULL,
    rendered_text      TEXT        NOT NULL,
    issued_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX receipt_reference_idx ON receipt (reference_number);

CREATE TRIGGER receipt_append_only
    BEFORE UPDATE OR DELETE ON receipt
    FOR EACH ROW EXECUTE FUNCTION reject_row_mutation();
