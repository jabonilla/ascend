-- CLAUDE.md rule 5: every state transition writes an audit row.
-- PRD §9: AuditLog is immutable.

CREATE TABLE audit_log (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- NULL actor means the system acted (a scheduled sweep, a provider webhook).
    -- Never NULL for a human action.
    actor_id         UUID        NULL,
    actor_kind       TEXT        NOT NULL CHECK (actor_kind IN ('user', 'system', 'provider')),
    action           TEXT        NOT NULL,
    entity_type      TEXT        NOT NULL,
    entity_id        UUID        NOT NULL,
    assurance_level  TEXT        NULL,
    channel          TEXT        NULL,
    before_state     JSONB       NULL,
    after_state      JSONB       NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX audit_log_entity_idx ON audit_log (entity_type, entity_id, created_at);
CREATE INDEX audit_log_actor_idx  ON audit_log (actor_id, created_at) WHERE actor_id IS NOT NULL;

CREATE TRIGGER audit_log_append_only
    BEFORE UPDATE OR DELETE ON audit_log
    FOR EACH ROW EXECUTE FUNCTION reject_row_mutation();

CREATE TRIGGER audit_log_no_truncate
    BEFORE TRUNCATE ON audit_log
    FOR EACH STATEMENT EXECUTE FUNCTION reject_statement_mutation();
