-- P2 — domain model. Mirrors PRD §9.
--
-- Two things here are load-bearing and easy to undo by accident:
--   * `transaction` has intent_state AND settlement_state. Never one status column.
--   * `plan_version` is immutable; the active version is a pointer on `money_plan`,
--     not a flag on the version rows.

-- ---------------------------------------------------------------------------------
-- users
-- ---------------------------------------------------------------------------------

CREATE TABLE app_user (
    id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- E.164. The CHECK is a shape check only; real validation is in domain/phone.py.
    phone                     TEXT        NOT NULL UNIQUE CHECK (phone ~ '^\+[1-9][0-9]{6,14}$'),
    -- A user may hold several roles at once (PRD §9 User.roles[]): a recipient who
    -- starts sending does not get a second account.
    roles                     TEXT[]      NOT NULL DEFAULT '{}',
    display_name              TEXT        NOT NULL DEFAULT '',
    locale                    TEXT        NOT NULL DEFAULT 'es-GT',
    preferred_channel         TEXT        NOT NULL DEFAULT 'whatsapp'
                                  CHECK (preferred_channel IN ('app', 'whatsapp', 'sms')),
    identity_assurance_level  TEXT        NOT NULL DEFAULT 'none',
    kyc_status                TEXT        NOT NULL DEFAULT 'not_started',
    created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (roles <@ ARRAY['sender', 'recipient']::TEXT[])
);

-- ---------------------------------------------------------------------------------
-- relationships  ⚠ MANY-TO-MANY
-- ---------------------------------------------------------------------------------

CREATE TABLE relationship (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_a_id     UUID        NOT NULL REFERENCES app_user (id),
    user_b_id     UUID        NOT NULL REFERENCES app_user (id),
    role_of_a     TEXT        NOT NULL,
    role_of_b     TEXT        NOT NULL,
    status        TEXT        NOT NULL DEFAULT 'invited'
                      CHECK (status IN ('invited', 'active', 'paused', 'terminated')),
    invited_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    activated_at  TIMESTAMPTZ NULL,
    terminated_at TIMESTAMPTZ NULL,
    CHECK (user_a_id <> user_b_id),
    -- The column names are the PRD's, deliberately generic. The canonical orientation
    -- is fixed here so that the uniqueness below actually means something: without it,
    -- (A=sender, B=recipient) and (B=recipient, A=sender) are two rows for one
    -- relationship, and a recipient could be invited twice by the same sender.
    CHECK (role_of_a = 'sender' AND role_of_b = 'recipient')
);

-- One relationship per ordered pair. A recipient may hold relationships with many
-- senders, and a sender with many recipients — this constrains neither.
CREATE UNIQUE INDEX relationship_pair_idx ON relationship (user_a_id, user_b_id);
CREATE INDEX relationship_recipient_idx ON relationship (user_b_id, status);
CREATE INDEX relationship_sender_idx ON relationship (user_a_id, status);

-- ---------------------------------------------------------------------------------
-- money plans  ⚠ PLAN VERSIONS ARE IMMUTABLE
-- ---------------------------------------------------------------------------------

CREATE TABLE money_plan (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    relationship_id    UUID        NOT NULL UNIQUE REFERENCES relationship (id),
    -- A pointer, not a flag on the version rows. Set after each version is written.
    current_version_id UUID        NULL,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE plan_version (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_id        UUID        NOT NULL REFERENCES money_plan (id),
    version_number INTEGER     NOT NULL CHECK (version_number > 0),
    created_by     UUID        NOT NULL REFERENCES app_user (id),
    change_note    TEXT        NOT NULL DEFAULT '',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (plan_id, version_number)
);

ALTER TABLE money_plan
    ADD CONSTRAINT money_plan_current_version_fk
    FOREIGN KEY (current_version_id) REFERENCES plan_version (id);

CREATE TRIGGER plan_version_append_only
    BEFORE UPDATE OR DELETE ON plan_version
    FOR EACH ROW EXECUTE FUNCTION reject_row_mutation();

CREATE TABLE category (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_version_id UUID        NOT NULL REFERENCES plan_version (id),
    -- Stable across versions. `id` changes with every new version, so anything that
    -- needs to refer to "the housing category" across an edit — a recurring rule,
    -- month-to-date spend, a report — refers to this instead. Without it, editing a
    -- plan would orphan every recurring rule attached to it.
    category_key    TEXT        NOT NULL,
    name            TEXT        NOT NULL,
    icon            TEXT        NOT NULL DEFAULT '',
    -- Integer minor units, or NULL for no cap. PRD Feature 1: caps are optional.
    monthly_cap     BIGINT      NULL CHECK (monthly_cap IS NULL OR monthly_cap > 0),
    currency        CHAR(3)     NOT NULL,
    is_system       BOOLEAN     NOT NULL DEFAULT FALSE,
    display_order   SMALLINT    NOT NULL DEFAULT 0,
    UNIQUE (plan_version_id, category_key)
);

CREATE TRIGGER category_append_only
    BEFORE UPDATE OR DELETE ON category
    FOR EACH ROW EXECUTE FUNCTION reject_row_mutation();

CREATE TABLE recurring_rule (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_id      UUID        NOT NULL REFERENCES money_plan (id),
    -- Keyed by category_key, not category id: the rule outlives the plan version it
    -- was created under.
    category_key TEXT        NOT NULL,
    amount       BIGINT      NOT NULL CHECK (amount > 0),
    currency     CHAR(3)     NOT NULL,
    cadence      TEXT        NOT NULL CHECK (cadence IN ('weekly', 'biweekly', 'monthly')),
    status       TEXT        NOT NULL DEFAULT 'active'
                     CHECK (status IN ('active', 'paused', 'cancelled')),
    -- Schedules evaluate in the sender's timezone (PRD Feature 2); the instant itself
    -- is stored UTC like every other timestamp (PRD §10).
    next_run_at  TIMESTAMPTZ NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX recurring_rule_plan_idx ON recurring_rule (plan_id, category_key, status);
CREATE INDEX recurring_rule_due_idx ON recurring_rule (next_run_at)
    WHERE status = 'active' AND next_run_at IS NOT NULL;

-- ---------------------------------------------------------------------------------
-- requests
-- ---------------------------------------------------------------------------------

CREATE TABLE request (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    relationship_id    UUID        NOT NULL REFERENCES relationship (id),
    requested_by       UUID        NOT NULL REFERENCES app_user (id),
    amount             BIGINT      NOT NULL CHECK (amount > 0),
    currency           CHAR(3)     NOT NULL,
    -- The concrete category row of the plan version in force when the request was
    -- made. That is what makes "historical transactions resolve against the plan
    -- version in effect at their time" true by construction.
    category_id        UUID        NULL REFERENCES category (id),
    description        TEXT        NOT NULL DEFAULT '' CHECK (length(description) <= 200),
    tier               TEXT        NOT NULL
                           CHECK (tier IN ('recurring', 'planned_investment',
                                           'emergency', 'unrecognized')),
    tier_reason        TEXT        NOT NULL,
    is_emergency       BOOLEAN     NOT NULL DEFAULT FALSE,
    channel_of_origin  TEXT        NOT NULL CHECK (channel_of_origin IN ('app', 'whatsapp', 'sms')),
    status             TEXT        NOT NULL DEFAULT 'pending'
                           CHECK (status IN ('pending', 'approved', 'declined', 'expired')),
    resolved_by        UUID        NULL REFERENCES app_user (id),
    resolved_at        TIMESTAMPTZ NULL,
    decline_reason     TEXT        NULL CHECK (decline_reason IS NULL OR length(decline_reason) <= 200),
    expires_at         TIMESTAMPTZ NOT NULL,
    -- Externally supplied by the channel gateway, from the provider's message id.
    -- CLAUDE.md rule 6: inbound channel messages arrive at least once, so submitting
    -- the same message twice must produce one request.
    idempotency_key    TEXT        NULL UNIQUE,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- A declined request must carry its reason (PRD Feature 1), and a pending one
    -- must not have been resolved by anybody.
    CHECK (status <> 'declined' OR decline_reason IS NOT NULL),
    CHECK (status = 'pending' OR resolved_at IS NOT NULL),
    CHECK (status <> 'pending' OR (resolved_at IS NULL AND resolved_by IS NULL))
);

CREATE INDEX request_relationship_idx ON request (relationship_id, created_at DESC);
CREATE INDEX request_pending_expiry_idx ON request (expires_at) WHERE status = 'pending';

-- ---------------------------------------------------------------------------------
-- transactions  ⚠ INTENT AND SETTLEMENT ARE SEPARATE FIELDS
-- ---------------------------------------------------------------------------------

CREATE TABLE transaction (
    id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- One transaction per approved request. The UNIQUE is what makes approval
    -- idempotent at the database rather than by a check-then-insert.
    request_id                UUID        NOT NULL UNIQUE REFERENCES request (id),
    relationship_id           UUID        NOT NULL REFERENCES relationship (id),
    amount                    BIGINT      NOT NULL CHECK (amount > 0),
    currency                  CHAR(3)     NOT NULL,

    intent_state              TEXT        NOT NULL DEFAULT 'committed'
                                  CHECK (intent_state IN ('committed', 'cancelled')),
    settlement_state          TEXT        NOT NULL DEFAULT 'not_started'
                                  CHECK (settlement_state IN ('not_started', 'instructed',
                                         'in_flight', 'settled', 'failed', 'reversed')),

    -- Disclosure figures (PRD Feature 7). Stored as applied, not as quoted.
    -- fx_rate is a decimal, never a float: NUMERIC in the database, Decimal in Python.
    fx_rate_applied           NUMERIC(20, 10) NULL CHECK (fx_rate_applied IS NULL OR fx_rate_applied > 0),
    fee_amount                BIGINT      NOT NULL DEFAULT 0 CHECK (fee_amount >= 0),
    recipient_amount          BIGINT      NULL CHECK (recipient_amount IS NULL OR recipient_amount > 0),
    recipient_currency        CHAR(3)     NULL,
    -- Partial settlement is an amount fact, not a state: see iwp/states.py.
    settled_amount            BIGINT      NOT NULL DEFAULT 0 CHECK (settled_amount >= 0),

    approved_by               UUID        NOT NULL REFERENCES app_user (id),
    approved_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    assurance_level_at_approval TEXT      NOT NULL,
    -- 'system' is auto-approval from a standing recurring rule (PRD Feature 2): the
    -- sender agreed in advance, so there is an approver but no channel they used.
    -- Collapsing it into 'app' would misreport how approvals actually happen, which is
    -- one of the metrics PRD §11 tracks.
    approval_channel          TEXT        NOT NULL
                                  CHECK (approval_channel IN ('app', 'whatsapp', 'sms', 'system')),

    settlement_provider       TEXT        NULL,
    provider_reference_id     TEXT        NULL,
    failure_reason            TEXT        NULL,

    verification_status       TEXT        NOT NULL DEFAULT 'unverified'
                                  CHECK (verification_status IN ('unverified', 'requested',
                                         'in_progress', 'verified', 'failed')),
    escrow_stage              TEXT        NULL,

    -- PRD Feature 7: the sender can cancel within a window and must see how long
    -- they have. NULL once the window has been consumed by settlement starting.
    cancellable_until         TIMESTAMPTZ NULL,
    reference_number          TEXT        NOT NULL UNIQUE,

    created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (settled_amount <= amount)
);

CREATE INDEX transaction_relationship_idx ON transaction (relationship_id, created_at DESC);
CREATE INDEX transaction_settlement_idx ON transaction (settlement_state, created_at);
CREATE INDEX transaction_provider_ref_idx ON transaction (provider_reference_id)
    WHERE provider_reference_id IS NOT NULL;
