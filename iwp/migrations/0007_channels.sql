-- P4 — channel gateway.
--
-- WhatsApp and SMS are full transaction surfaces (PRD Feature 4), not notification
-- pipes. Everything here exists because the recipient side of the product lives on a
-- channel that delivers at least once, out of order, and sometimes not at all.

-- ---------------------------------------------------------------------------------
-- templates
-- ---------------------------------------------------------------------------------

-- WhatsApp requires templates to be pre-approved by the BSP before they can be sent
-- outside a session window (PRD Feature 4). Recording approval state here means an
-- unapproved template fails in our code, with a clear message, rather than at the BSP
-- with an opaque one.
CREATE TABLE message_template (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_key TEXT        NOT NULL,
    channel      TEXT        NOT NULL CHECK (channel IN ('whatsapp', 'sms', 'push')),
    locale       TEXT        NOT NULL,
    body         TEXT        NOT NULL,
    -- Ordered button labels for channels that have them. Empty for SMS.
    buttons      TEXT[]      NOT NULL DEFAULT '{}',
    bsp_status   TEXT        NOT NULL DEFAULT 'draft'
                     CHECK (bsp_status IN ('draft', 'submitted', 'approved', 'rejected')),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (template_key, channel, locale)
);

-- ---------------------------------------------------------------------------------
-- conversations
-- ---------------------------------------------------------------------------------

-- One per (user, channel). Conversation state is persisted, never held in memory:
-- P4.3 requires the state machine to reconstruct from storage, because the process
-- that handled the last message is not the process handling this one.
CREATE TABLE conversation (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id               UUID        NOT NULL REFERENCES app_user (id),
    channel               TEXT        NOT NULL CHECK (channel IN ('whatsapp', 'sms')),
    state_name            TEXT        NOT NULL DEFAULT 'idle',
    state_data            JSONB       NOT NULL DEFAULT '{}'::JSONB,
    -- The WhatsApp 24-hour session window (P4.2). NULL means no open window, which is
    -- the safe default: outside a window only approved templates may be sent.
    session_expires_at    TIMESTAMPTZ NULL,
    last_inbound_at       TIMESTAMPTZ NULL,
    -- The provider timestamp of the newest message we have applied. Used to notice
    -- out-of-order delivery; the state machine still decides by state, not by clock.
    last_applied_event_at TIMESTAMPTZ NULL,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, channel)
);

-- ---------------------------------------------------------------------------------
-- inbound
-- ---------------------------------------------------------------------------------

CREATE TABLE inbound_message (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel             TEXT        NOT NULL CHECK (channel IN ('whatsapp', 'sms')),
    -- The BSP's message id. UNIQUE per channel is the idempotency mechanism
    -- (CLAUDE.md rule 6): a redelivered message loses the insert and is a no-op.
    provider_message_id TEXT        NOT NULL,
    conversation_id     UUID        NULL REFERENCES conversation (id),
    from_phone          TEXT        NOT NULL,
    body                TEXT        NOT NULL DEFAULT '',
    button_payload      TEXT        NOT NULL DEFAULT '',
    occurred_at         TIMESTAMPTZ NOT NULL,
    received_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (channel, provider_message_id)
);

CREATE INDEX inbound_message_conversation_idx
    ON inbound_message (conversation_id, occurred_at);

CREATE TRIGGER inbound_message_append_only
    BEFORE UPDATE OR DELETE ON inbound_message
    FOR EACH ROW EXECUTE FUNCTION reject_row_mutation();

-- ---------------------------------------------------------------------------------
-- outbound  (PRD §9 Notification)
-- ---------------------------------------------------------------------------------

CREATE TABLE notification (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID        NOT NULL REFERENCES app_user (id),
    channel             TEXT        NOT NULL CHECK (channel IN ('whatsapp', 'sms', 'push', 'app')),
    template_key        TEXT        NOT NULL DEFAULT '',
    -- Freeform sends carry no template. Which is which matters for the session window:
    -- outside one, only an approved template may go out.
    is_template         BOOLEAN     NOT NULL,
    locale              TEXT        NOT NULL DEFAULT 'es-GT',
    body                TEXT        NOT NULL,
    payload_ref         JSONB       NOT NULL DEFAULT '{}'::JSONB,
    delivery_state      TEXT        NOT NULL DEFAULT 'queued'
                            CHECK (delivery_state IN ('queued', 'sent', 'delivered', 'read', 'failed')),
    provider_message_id TEXT        NULL,
    -- Set when this notification exists because another one failed (P4.4 fallback).
    fallback_of_id      UUID        NULL REFERENCES notification (id),
    -- Groups the parallel dispatch of one logical event across channels, so a delivery
    -- audit can answer "did we reach them at all?" rather than only "did WhatsApp work?"
    dispatch_group      UUID        NULL,
    related_entity_type TEXT        NOT NULL DEFAULT '',
    related_entity_id   UUID        NULL,
    sent_at             TIMESTAMPTZ NULL,
    delivered_at        TIMESTAMPTZ NULL,
    failure_reason      TEXT        NOT NULL DEFAULT '',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX notification_user_idx ON notification (user_id, created_at DESC);
CREATE INDEX notification_entity_idx ON notification (related_entity_type, related_entity_id);
CREATE INDEX notification_dispatch_group_idx ON notification (dispatch_group)
    WHERE dispatch_group IS NOT NULL;

-- Every delivery-state change, appended. The current state lives on `notification`;
-- this is the audit trail behind it, and it is what a dispute is settled with.
CREATE TABLE notification_delivery_event (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID        NOT NULL REFERENCES notification (id),
    delivery_state  TEXT        NOT NULL,
    detail          TEXT        NOT NULL DEFAULT '',
    occurred_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX notification_delivery_event_idx
    ON notification_delivery_event (notification_id, occurred_at);

CREATE TRIGGER notification_delivery_event_append_only
    BEFORE UPDATE OR DELETE ON notification_delivery_event
    FOR EACH ROW EXECUTE FUNCTION reject_row_mutation();

-- What handling an inbound message produced.
--
-- Separate from `inbound_message` because that table is append-only: the message as it
-- arrived is one fact and never changes, and what we did about it is another. Keeping
-- them apart means a redelivery can read the outcome without the arrival record ever
-- being rewritten.
CREATE TABLE inbound_message_outcome (
    channel             TEXT        NOT NULL,
    provider_message_id TEXT        NOT NULL,
    outcome             TEXT        NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (channel, provider_message_id)
);
