-- yeGamo migration 0005: saved places, routines, leave alerts and notifications.

CREATE TABLE saved_places (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    label               text NOT NULL CHECK (length(trim(label)) > 0),
    location            geography(Point, 4326) NOT NULL,
    geocoding_metadata  jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE commute_profiles (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                 uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name                    text NOT NULL CHECK (length(trim(name)) > 0),
    origin                  geography(Point, 4326) NOT NULL,
    destination             geography(Point, 4326) NOT NULL,
    weekdays                smallint[] NOT NULL,
    target_arrival          time NOT NULL,
    timezone                text NOT NULL DEFAULT 'America/Guayaquil',
    preference              text NOT NULL DEFAULT 'BALANCED'
        CHECK (preference IN ('FASTEST', 'RELIABLE', 'BALANCED', 'LOW_WALK')),
    max_walk_min            integer NOT NULL DEFAULT 15 CHECK (max_walk_min BETWEEN 0 AND 180),
    extra_margin_min        integer NOT NULL DEFAULT 0 CHECK (extra_margin_min BETWEEN 0 AND 120),
    enabled                 boolean NOT NULL DEFAULT true,
    created_at              timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT commute_profiles_weekdays_ck CHECK (
        cardinality(weekdays) BETWEEN 1 AND 7 AND weekdays <@ ARRAY[0, 1, 2, 3, 4, 5, 6]::smallint[]
    )
);

CREATE TABLE leave_alerts (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    commute_profile_id  uuid REFERENCES commute_profiles(id) ON DELETE CASCADE,
    journey_plan_id     uuid REFERENCES journey_plans(id) ON DELETE CASCADE,
    scheduled_for       timestamptz NOT NULL,
    status              text NOT NULL DEFAULT 'SCHEDULED'
        CHECK (status IN ('SCHEDULED', 'TRIGGERED', 'CANCELLED', 'FAILED', 'EXPIRED')),
    idempotency_key     text NOT NULL,
    created_at          timestamptz NOT NULL DEFAULT now(),
    triggered_at        timestamptz,
    CONSTRAINT leave_alerts_target_ck CHECK (commute_profile_id IS NOT NULL OR journey_plan_id IS NOT NULL),
    CONSTRAINT leave_alerts_user_idempotency_uk UNIQUE (user_id, idempotency_key)
);

CREATE TABLE notifications (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type                text NOT NULL CHECK (type IN ('LEAVE_ALERT', 'GETOFF_ALERT', 'ROUTE_CHANGE', 'INCIDENT', 'SYSTEM')),
    title               text NOT NULL,
    body                text NOT NULL,
    payload             jsonb NOT NULL DEFAULT '{}'::jsonb,
    is_read             boolean NOT NULL DEFAULT false,
    deduplication_key   text,
    created_at          timestamptz NOT NULL DEFAULT now(),
    read_at             timestamptz,
    CONSTRAINT notifications_dedup_uk UNIQUE (user_id, deduplication_key)
);

CREATE TABLE notification_deliveries (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id     uuid NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
    device_id           uuid NOT NULL REFERENCES device_installations(id) ON DELETE CASCADE,
    channel             text NOT NULL CHECK (channel IN ('PUSH', 'LOCAL', 'IN_APP')),
    status              text NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'SENT', 'DELIVERED', 'FAILED', 'SKIPPED')),
    provider            text,
    provider_message_id text,
    deduplication_key   text NOT NULL,
    attempted_at        timestamptz,
    delivered_at        timestamptz,
    last_error          text,
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT notification_deliveries_dedup_uk UNIQUE (device_id, deduplication_key)
);

CREATE INDEX saved_places_user_created_idx ON saved_places (user_id, created_at DESC);
CREATE INDEX commute_profiles_user_enabled_idx ON commute_profiles (user_id, enabled);
CREATE INDEX leave_alerts_scheduled_status_idx ON leave_alerts (scheduled_for, status);
CREATE INDEX notifications_user_created_idx ON notifications (user_id, created_at DESC);
CREATE INDEX notification_deliveries_notification_idx ON notification_deliveries (notification_id, status);
