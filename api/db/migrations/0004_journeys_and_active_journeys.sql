-- yeGamo migration 0004: planning results, normalized legs and active journeys.

CREATE TABLE journey_plans (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                 uuid REFERENCES users(id) ON DELETE SET NULL,
    origin                  geography(Point, 4326) NOT NULL,
    destination             geography(Point, 4326) NOT NULL,
    time_mode               text NOT NULL CHECK (time_mode IN ('LEAVE_NOW', 'DEPART_AT', 'ARRIVE_BY')),
    requested_time          timestamptz,
    preference              text NOT NULL DEFAULT 'BALANCED'
        CHECK (preference IN ('FASTEST', 'RELIABLE', 'BALANCED', 'LOW_WALK')),
    max_walk_min            integer NOT NULL DEFAULT 15 CHECK (max_walk_min BETWEEN 0 AND 180),
    extra_safety_margin_min integer NOT NULL DEFAULT 0 CHECK (extra_safety_margin_min BETWEEN 0 AND 120),
    status                  text NOT NULL DEFAULT 'READY'
        CHECK (status IN ('REQUESTED', 'READY', 'FAILED', 'EXPIRED')),
    data_state              text NOT NULL DEFAULT 'CURRENT'
        CHECK (data_state IN ('CURRENT', 'STALE', 'DEGRADED', 'OFFLINE_CACHE', 'UNAVAILABLE')),
    recommended_leave_at    timestamptz,
    arrival_window_from     timestamptz,
    arrival_window_to       timestamptz,
    provider_summary        jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at              timestamptz NOT NULL DEFAULT now(),
    expires_at              timestamptz,
    CONSTRAINT journey_plans_time_ck CHECK (time_mode = 'LEAVE_NOW' OR requested_time IS NOT NULL),
    CONSTRAINT journey_plans_arrival_window_ck CHECK (
        arrival_window_to IS NULL OR arrival_window_from IS NULL OR arrival_window_to >= arrival_window_from
    )
);

CREATE TABLE journey_options (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_id             uuid NOT NULL REFERENCES journey_plans(id) ON DELETE CASCADE,
    rank                integer NOT NULL CHECK (rank > 0),
    duration_min        integer NOT NULL CHECK (duration_min >= 0),
    walk_min            integer NOT NULL DEFAULT 0 CHECK (walk_min >= 0),
    transfers           integer NOT NULL DEFAULT 0 CHECK (transfers >= 0),
    reliability_score   integer CHECK (reliability_score BETWEEN 0 AND 100),
    reliability_level   text CHECK (reliability_level IN ('HIGH', 'MEDIUM', 'LOW')),
    sample_size         integer CHECK (sample_size IS NULL OR sample_size >= 0),
    provider            text,
    data_state          text NOT NULL DEFAULT 'CURRENT'
        CHECK (data_state IN ('CURRENT', 'STALE', 'DEGRADED', 'OFFLINE_CACHE', 'UNAVAILABLE')),
    payload             jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT journey_options_plan_rank_uk UNIQUE (plan_id, rank)
);

CREATE TABLE journey_legs (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    option_id           uuid NOT NULL REFERENCES journey_options(id) ON DELETE CASCADE,
    sequence            integer NOT NULL CHECK (sequence >= 0),
    mode                text NOT NULL CHECK (mode IN ('WALK', 'TRANSIT', 'TRANSFER', 'BIKE', 'OTHER')),
    route_id            uuid REFERENCES transit_routes(id) ON DELETE SET NULL,
    from_stop_id        uuid REFERENCES transit_stops(id) ON DELETE SET NULL,
    to_stop_id          uuid REFERENCES transit_stops(id) ON DELETE SET NULL,
    departure_at        timestamptz,
    arrival_at          timestamptz,
    duration_min        integer NOT NULL CHECK (duration_min >= 0),
    distance_m          integer CHECK (distance_m IS NULL OR distance_m >= 0),
    instruction         text,
    shape               geometry(LineString, 4326),
    data_state          text NOT NULL DEFAULT 'CURRENT'
        CHECK (data_state IN ('CURRENT', 'STALE', 'DEGRADED', 'OFFLINE_CACHE', 'UNAVAILABLE')),
    metadata            jsonb NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT journey_legs_option_sequence_uk UNIQUE (option_id, sequence),
    CONSTRAINT journey_legs_time_ck CHECK (arrival_at IS NULL OR departure_at IS NULL OR arrival_at >= departure_at)
);

CREATE TABLE active_journeys (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             uuid REFERENCES users(id) ON DELETE SET NULL,
    option_id           uuid NOT NULL REFERENCES journey_options(id) ON DELETE RESTRICT,
    status              text NOT NULL DEFAULT 'PLANNED'
        CHECK (status IN ('PLANNED', 'ACTIVE', 'COMPLETED', 'CANCELLED', 'ABANDONED')),
    current_leg_sequence integer CHECK (current_leg_sequence IS NULL OR current_leg_sequence >= 0),
    current_data_state  text NOT NULL DEFAULT 'CURRENT'
        CHECK (current_data_state IN ('CURRENT', 'STALE', 'DEGRADED', 'OFFLINE_CACHE', 'UNAVAILABLE')),
    estimated_arrival_at timestamptz,
    started_at          timestamptz,
    finished_at         timestamptz,
    actual_arrival_at   timestamptz,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT active_journeys_status_time_ck CHECK (
        status IN ('PLANNED', 'ACTIVE') OR finished_at IS NOT NULL
    )
);

CREATE TABLE journey_events (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    active_journey_id   uuid NOT NULL REFERENCES active_journeys(id) ON DELETE CASCADE,
    event_type          text NOT NULL CHECK (event_type IN (
        'STARTED', 'LEG_CHANGED', 'ETA_UPDATED', 'GETOFF_ALERT', 'PAUSED', 'RESUMED',
        'FINISHED', 'CANCELLED', 'ABANDONED'
    )),
    leg_sequence        integer CHECK (leg_sequence IS NULL OR leg_sequence >= 0),
    occurred_at         timestamptz NOT NULL DEFAULT now(),
    source              text,
    data_state          text NOT NULL DEFAULT 'CURRENT'
        CHECK (data_state IN ('CURRENT', 'STALE', 'DEGRADED', 'OFFLINE_CACHE', 'UNAVAILABLE')),
    payload             jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX journey_plans_user_created_idx ON journey_plans (user_id, created_at DESC);
CREATE INDEX journey_plans_data_state_created_idx ON journey_plans (data_state, created_at DESC);
CREATE INDEX journey_options_plan_rank_idx ON journey_options (plan_id, rank);
CREATE INDEX journey_legs_route_idx ON journey_legs (route_id, departure_at);
CREATE INDEX active_journeys_user_status_idx ON active_journeys (user_id, status, updated_at DESC);
CREATE INDEX journey_events_journey_time_idx ON journey_events (active_journey_id, occurred_at DESC);
