-- yeGamo migration 0007: spatial indexes, operational constraints and retention policy.

CREATE INDEX transit_stops_location_gist_idx ON transit_stops USING gist (location);
CREATE INDEX saved_places_location_gist_idx ON saved_places USING gist (location);
CREATE INDEX community_reports_location_gist_idx ON community_reports USING gist (location);
CREATE INDEX transit_route_shapes_shape_gist_idx ON transit_route_shapes USING gist (shape);
CREATE INDEX journey_legs_shape_gist_idx ON journey_legs USING gist (shape);
CREATE INDEX journey_plans_origin_gist_idx ON journey_plans USING gist (origin);
CREATE INDEX journey_plans_destination_gist_idx ON journey_plans USING gist (destination);

CREATE INDEX provider_references_external_id_idx ON provider_references (external_id);
CREATE INDEX transit_routes_short_name_idx ON transit_routes (short_name);
CREATE INDEX transit_stops_code_idx ON transit_stops (code);
CREATE INDEX active_journeys_updated_idx ON active_journeys (updated_at DESC);
CREATE INDEX journey_events_occurred_idx ON journey_events (occurred_at DESC);

CREATE UNIQUE INDEX active_journeys_one_current_per_user_idx
    ON active_journeys (user_id)
    WHERE user_id IS NOT NULL AND status IN ('PLANNED', 'ACTIVE');

CREATE TABLE retention_policies (
    table_name          text PRIMARY KEY,
    timestamp_column    text NOT NULL,
    retention_interval  interval NOT NULL CHECK (retention_interval > interval '0'),
    purpose             text NOT NULL,
    requires_consent    boolean NOT NULL DEFAULT false,
    enabled             boolean NOT NULL DEFAULT true,
    updated_at          timestamptz NOT NULL DEFAULT now()
);

INSERT INTO retention_policies (table_name, timestamp_column, retention_interval, purpose, requires_consent)
VALUES
    ('route_observations', 'observed_at', interval '30 days', 'Detailed observations are minimized and short-lived.', false),
    ('provider_health_snapshots', 'observed_at', interval '180 days', 'Operational provider diagnostics.', false),
    ('community_reports', 'created_at', interval '90 days', 'Community reports expire and are removed after moderation retention.', false),
    ('journey_events', 'occurred_at', interval '30 days', 'Journey event history is retained only with recurring-trips consent.', true)
ON CONFLICT (table_name) DO UPDATE
SET timestamp_column = EXCLUDED.timestamp_column,
    retention_interval = EXCLUDED.retention_interval,
    purpose = EXCLUDED.purpose,
    requires_consent = EXCLUDED.requires_consent,
    updated_at = now();

COMMENT ON TABLE retention_policies IS
    'Allowlisted retention metadata consumed by a future worker; no arbitrary table names are executed.';
