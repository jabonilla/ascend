-- Runtime-configurable values.
--
-- PRD Feature 5 requires step-up authentication thresholds to be "configurable without
-- a deploy", and PRD §13 lists their values as an open question. Anything in that shape
-- lives here rather than in code: request expiry windows, approval thresholds, transfer
-- limits, the cancellation window.
--
-- Values are JSONB so a setting can be a scalar or a structure. Money values are stored
-- as integer minor units, like everywhere else.

CREATE TABLE runtime_setting (
    key         TEXT PRIMARY KEY,
    value       JSONB       NOT NULL,
    description TEXT        NOT NULL DEFAULT '',
    updated_by  UUID        NULL,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Every change is kept: a limit that was different last Tuesday is the explanation for
-- why last Tuesday's approval behaved differently.
CREATE TABLE runtime_setting_history (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key         TEXT        NOT NULL,
    old_value   JSONB       NULL,
    new_value   JSONB       NOT NULL,
    changed_by  UUID        NULL,
    changed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX runtime_setting_history_key_idx ON runtime_setting_history (key, changed_at DESC);

CREATE TRIGGER runtime_setting_history_append_only
    BEFORE UPDATE OR DELETE ON runtime_setting_history
    FOR EACH ROW EXECUTE FUNCTION reject_row_mutation();

-- Defaults. These are placeholders pending PRD §13 decisions, and the point of this
-- table is that changing them is not a deploy.
INSERT INTO runtime_setting (key, value, description) VALUES
    ('request.expiry_hours', '72',
     'Hours a pending request stays open before expiring (PRD Feature 3 uses 72h as the sender-inactivity horizon)'),
    ('request.emergency_expiry_hours', '24',
     'Emergency requests expire sooner: an urgent need that is a week old is not the same need'),
    ('request.emergency_limit_per_7_days', '3',
     'PRD Feature 3: max 3 emergency requests per relationship per 7 days, then a soft warning to both parties'),
    ('approval.step_up_threshold_minor_units', '20000',
     'Above this a sender must step up (PRD Feature 5). Value pending research; USD minor units'),
    ('approval.app_required_threshold_minor_units', '100000',
     'Above this the approval must happen in the app (PRD Feature 5). Value pending research'),
    ('transfer.cancellation_window_minutes', '30',
     'PRD Feature 7 cancellation window. Exact obligation pending counsel Reg E analysis'),
    ('transfer.per_transaction_limit_minor_units', '300000',
     'PRD §10 transfer limits. Value pending partner constraints and counsel guidance'),
    ('transfer.per_day_limit_minor_units', '500000',
     'PRD §10 daily cap. Value pending partner constraints and counsel guidance');
