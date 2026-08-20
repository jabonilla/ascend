-- P1.2 — ledger core.
--
-- Append-only is enforced here, at the database, by trigger. Application-level or
-- ORM-level enforcement is not sufficient: a psql session, a migration, or a future
-- agent writing raw SQL all bypass it. See build guide P1.2.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------------------
-- accounts
-- ---------------------------------------------------------------------------------

CREATE TABLE account (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_type    TEXT        NOT NULL,
    -- Debit-normal accounts (assets) increase on debit; credit-normal accounts
    -- (liabilities, revenue) increase on credit. Stored rather than derived so a
    -- balance query is a single aggregate and cannot drift from application code.
    normal_balance  TEXT        NOT NULL CHECK (normal_balance IN ('debit', 'credit')),
    currency        CHAR(3)     NOT NULL,
    -- Scope: what this account belongs to — a relationship, a user, a provider.
    -- Kept as an opaque pair so the ledger does not gain foreign keys into every
    -- domain table it serves. Sentinel values rather than NULL for singleton system
    -- accounts, so the uniqueness constraint below is a plain one: NULLs are not
    -- equal to each other, and a nullable unique key would let duplicate system
    -- accounts through.
    scope_type      TEXT        NOT NULL DEFAULT '',
    scope_id        UUID        NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000',
    name            TEXT        NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- One account per (type, currency, scope). This is what makes account lookup
-- idempotent: two concurrent requests racing to create the same account cannot
-- produce two accounts.
CREATE UNIQUE INDEX account_identity_idx
    ON account (account_type, currency, scope_type, scope_id);

-- ---------------------------------------------------------------------------------
-- ledger transactions
-- ---------------------------------------------------------------------------------

CREATE TABLE ledger_transaction (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Externally supplied. The UNIQUE constraint is the idempotency mechanism:
    -- a replayed posting loses the insert race and reads back the original.
    idempotency_key     TEXT        NOT NULL UNIQUE,
    posting_type        TEXT        NOT NULL,
    -- Hash of the posting the key was first used for. A replay with the same key but
    -- a different payload is a bug in the caller, and silently returning the original
    -- result would hide it. See ledger.posting.IdempotencyKeyReuse.
    request_fingerprint TEXT        NOT NULL,
    -- The domain Transaction this posting is about, when there is one. Deliberately
    -- not a foreign key: the ledger is written by P1.3 and the domain tables arrive
    -- in P2, and the ledger must not depend on them.
    business_txn_id     UUID        NULL,
    description         TEXT        NOT NULL DEFAULT '',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ledger_transaction_business_txn_idx
    ON ledger_transaction (business_txn_id) WHERE business_txn_id IS NOT NULL;

-- ---------------------------------------------------------------------------------
-- ledger entries  ⚠ APPEND-ONLY, NEVER UPDATED
-- ---------------------------------------------------------------------------------

CREATE TABLE ledger_entry (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id  UUID        NOT NULL REFERENCES ledger_transaction (id),
    -- Position within its posting. Every entry in one posting shares a created_at,
    -- because now() in PostgreSQL is transaction start time — so without this there
    -- is no stable order in which to read a posting back, and a replayed result would
    -- not match the original.
    entry_index     SMALLINT    NOT NULL CHECK (entry_index >= 0),
    account_id      UUID        NOT NULL REFERENCES account (id),
    direction       TEXT        NOT NULL CHECK (direction IN ('debit', 'credit')),
    -- Integer minor units. Always positive; the sign lives in `direction`. A signed
    -- amount plus a direction gives two ways to say "negative", and they disagree.
    amount          BIGINT      NOT NULL CHECK (amount > 0),
    currency        CHAR(3)     NOT NULL,
    entry_type      TEXT        NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX ledger_entry_transaction_idx ON ledger_entry (transaction_id, entry_index);
CREATE INDEX ledger_entry_account_idx     ON ledger_entry (account_id, created_at);

-- An entry's currency must match its account's currency. Enforced by trigger rather
-- than a composite foreign key so that `account.currency` stays a plain column.
CREATE FUNCTION ledger_entry_currency_matches_account() RETURNS trigger AS $$
DECLARE
    account_currency CHAR(3);
BEGIN
    SELECT currency INTO account_currency FROM account WHERE id = NEW.account_id;
    IF account_currency IS DISTINCT FROM NEW.currency THEN
        RAISE EXCEPTION
            'ledger_entry currency % does not match account currency %',
            NEW.currency, account_currency
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ledger_entry_currency_check
    BEFORE INSERT ON ledger_entry
    FOR EACH ROW EXECUTE FUNCTION ledger_entry_currency_matches_account();

-- ---------------------------------------------------------------------------------
-- append-only enforcement
-- ---------------------------------------------------------------------------------

CREATE FUNCTION reject_row_mutation() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION
        '% is append-only: % rejected. Corrections are new compensating entries.',
        TG_TABLE_NAME, TG_OP
        USING ERRCODE = 'restrict_violation';
END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION reject_statement_mutation() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION
        '% is append-only: % rejected.', TG_TABLE_NAME, TG_OP
        USING ERRCODE = 'restrict_violation';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ledger_entry_append_only
    BEFORE UPDATE OR DELETE ON ledger_entry
    FOR EACH ROW EXECUTE FUNCTION reject_row_mutation();

-- Row-level triggers do not fire for TRUNCATE. Without this, `TRUNCATE ledger_entry`
-- would succeed and take the whole ledger with it.
CREATE TRIGGER ledger_entry_no_truncate
    BEFORE TRUNCATE ON ledger_entry
    FOR EACH STATEMENT EXECUTE FUNCTION reject_statement_mutation();

-- A ledger transaction header is immutable for the same reason its entries are.
CREATE TRIGGER ledger_transaction_append_only
    BEFORE UPDATE OR DELETE ON ledger_transaction
    FOR EACH ROW EXECUTE FUNCTION reject_row_mutation();

CREATE TRIGGER ledger_transaction_no_truncate
    BEFORE TRUNCATE ON ledger_transaction
    FOR EACH STATEMENT EXECUTE FUNCTION reject_statement_mutation();
