-- yeGamo migration 0006: reliability aggregates, provider health and community reports.

CREATE TABLE route_observations (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    route_id            uuid REFERENCES transit_routes(id) ON DELETE CASCADE,
    direction_id        text NOT NULL DEFAULT '0',
    observed_at         timestamptz NOT NULL,
    expected_duration_sec integer CHECK (expected_duration_sec IS NULL OR expected_duration_sec >= 0),
    actual_duration_sec integer CHECK (actual_duration_sec IS NULL OR actual_duration_sec >= 0),
    wait_duration_sec   integer CHECK (wait_duration_sec IS NULL OR wait_duration_sec >= 0),
    source              text NOT NULL,
    quality             numeric(5, 2) CHECK (quality BETWEEN 0 AND 100),
    metadata            jsonb NOT NULL DEFAULT '{}'::jsonb,
    expires_at          timestamptz,
    CONSTRAINT route_observations_expiry_ck CHECK (expires_at IS NULL OR expires_at >= observed_at)
);

CREATE TABLE route_metrics (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    route_id            uuid NOT NULL REFERENCES transit_routes(id) ON DELETE CASCADE,
    direction_id        text NOT NULL DEFAULT '0',
    day_of_week         smallint NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
    time_bucket         time NOT NULL,
    sample_size         integer NOT NULL CHECK (sample_size >= 0),
    median_duration_sec integer CHECK (median_duration_sec IS NULL OR median_duration_sec >= 0),
    p50_duration_sec    integer CHECK (p50_duration_sec IS NULL OR p50_duration_sec >= 0),
    p90_duration_sec    integer CHECK (p90_duration_sec IS NULL OR p90_duration_sec >= 0),
    dispersion_sec      integer CHECK (dispersion_sec IS NULL OR dispersion_sec >= 0),
    yegamo_score        integer CHECK (yegamo_score BETWEEN 0 AND 100),
    computed_at         timestamptz NOT NULL DEFAULT now(),
    valid_until         timestamptz,
    CONSTRAINT route_metrics_route_window_uk UNIQUE (route_id, direction_id, day_of_week, time_bucket)
);

CREATE TABLE provider_health_snapshots (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    provider            text NOT NULL,
    capability          text NOT NULL,
    status              text NOT NULL CHECK (status IN ('HEALTHY', 'DEGRADED', 'UNAVAILABLE')),
    latency_ms          integer CHECK (latency_ms IS NULL OR latency_ms >= 0),
    error_code          text,
    freshness_at        timestamptz,
    observed_at         timestamptz NOT NULL DEFAULT now(),
    metadata            jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE community_reports (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             uuid REFERENCES users(id) ON DELETE SET NULL,
    report_type         text NOT NULL CHECK (report_type IN ('DELAY', 'CLOSURE', 'CROWDING', 'SAFETY', 'OTHER')),
    location            geography(Point, 4326) NOT NULL,
    route_id            uuid REFERENCES transit_routes(id) ON DELETE SET NULL,
    description         text,
    status              text NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('ACTIVE', 'CONFIRMED', 'RESOLVED', 'EXPIRED', 'REJECTED')),
    confidence          numeric(5, 2) NOT NULL DEFAULT 0 CHECK (confidence BETWEEN 0 AND 100),
    expires_at          timestamptz NOT NULL,
    created_at          timestamptz NOT NULL DEFAULT now(),
    resolved_at         timestamptz,
    metadata            jsonb NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT community_reports_expiry_ck CHECK (expires_at > created_at)
);

CREATE TABLE report_confirmations (
    report_id           uuid NOT NULL REFERENCES community_reports(id) ON DELETE CASCADE,
    user_id             uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    confirmed_at        timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (report_id, user_id)
);

CREATE INDEX route_observations_route_time_idx ON route_observations (route_id, direction_id, observed_at DESC);
CREATE INDEX route_observations_expires_idx ON route_observations (expires_at);
CREATE INDEX route_metrics_route_window_idx ON route_metrics (route_id, direction_id, day_of_week, time_bucket);
CREATE INDEX provider_health_provider_time_idx ON provider_health_snapshots (provider, capability, observed_at DESC);
CREATE INDEX community_reports_status_expiry_idx ON community_reports (status, expires_at);
CREATE INDEX report_confirmations_user_time_idx ON report_confirmations (user_id, confirmed_at DESC);
