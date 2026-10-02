-- yeGamo migration 0001
-- The runner owns the transaction and the session advisory lock.

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS schema_migrations (
    version             text PRIMARY KEY,
    name                text NOT NULL,
    checksum            text NOT NULL,
    applied_at          timestamptz NOT NULL DEFAULT now(),
    execution_time_ms   integer NOT NULL DEFAULT 0 CHECK (execution_time_ms >= 0)
);

COMMENT ON TABLE schema_migrations IS
    'Checksummed SQL migration ledger maintained by the yeGamo migration runner.';
