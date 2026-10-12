-- yeGamo migration 0008: bounded idempotency records for authenticated writes.
-- The table stores only canonical response bodies and a request hash; it never
-- stores bearer tokens, secrets, or provider DTOs.

CREATE TABLE idempotency_operations (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    principal_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    operation_key    text NOT NULL CHECK (length(operation_key) BETWEEN 8 AND 128),
    request_hash     text NOT NULL CHECK (request_hash ~ '^[a-f0-9]{64}$'),
    response_status  integer NOT NULL CHECK (response_status BETWEEN 200 AND 299),
    response_body    jsonb NOT NULL,
    created_at       timestamptz NOT NULL DEFAULT now(),
    expires_at       timestamptz NOT NULL,
    CONSTRAINT idempotency_operations_expiry_ck CHECK (expires_at > created_at),
    CONSTRAINT idempotency_operations_principal_key_uk UNIQUE (principal_id, operation_key)
);

CREATE INDEX idempotency_operations_expiry_idx
    ON idempotency_operations (expires_at);

COMMENT ON TABLE idempotency_operations IS
    'Canonical authenticated write replays with bounded retention; bearer credentials are never persisted.';
