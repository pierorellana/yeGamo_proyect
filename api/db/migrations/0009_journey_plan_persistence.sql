-- yeGamo migration 0009: allow every API preference value on persisted plans and
-- index plan expiry so stale plans can be filtered/purged cheaply.

ALTER TABLE journey_plans DROP CONSTRAINT journey_plans_preference_check;
ALTER TABLE journey_plans ADD CONSTRAINT journey_plans_preference_check
    CHECK (preference IN (
        'FASTEST', 'RELIABLE', 'BALANCED', 'LESS_WALKING', 'FEWER_TRANSFERS', 'LOW_WALK'
    ));

CREATE INDEX journey_plans_expires_idx ON journey_plans (expires_at)
    WHERE expires_at IS NOT NULL;
CREATE INDEX journey_legs_option_sequence_idx ON journey_legs (option_id, sequence);

COMMENT ON COLUMN journey_legs.metadata IS
    'Canonical leg geometry endpoints (from/to), instructions and provider-neutral stop/route references. Never raw provider DTOs.';
COMMENT ON COLUMN journey_options.payload IS
    'Canonical dataQuality and reliability for the option. Never raw provider DTOs.';
