-- yeGamo migration 0002: identity, account preferences and privacy audit.

CREATE TABLE users (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    issuer              text NOT NULL,
    subject             text NOT NULL,
    email               text,
    display_name        text,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    deleted_at          timestamptz,
    CONSTRAINT users_issuer_subject_uk UNIQUE (issuer, subject),
    CONSTRAINT users_email_ck CHECK (email IS NULL OR length(trim(email)) > 3),
    CONSTRAINT users_deleted_at_ck CHECK (deleted_at IS NULL OR deleted_at >= created_at)
);

CREATE TABLE user_preferences (
    user_id                     uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    travel_preference           text NOT NULL DEFAULT 'BALANCED'
        CHECK (travel_preference IN ('FASTEST', 'RELIABLE', 'BALANCED', 'LOW_WALK')),
    max_walk_min                integer NOT NULL DEFAULT 15
        CHECK (max_walk_min BETWEEN 0 AND 180),
    extra_safety_margin_min     integer NOT NULL DEFAULT 0
        CHECK (extra_safety_margin_min BETWEEN 0 AND 120),
    language                    text NOT NULL DEFAULT 'es'
        CHECK (language IN ('es', 'en')),
    units                       text NOT NULL DEFAULT 'METRIC'
        CHECK (units IN ('METRIC', 'IMPERIAL')),
    location_history_consent   boolean NOT NULL DEFAULT false,
    recurring_trips_consent    boolean NOT NULL DEFAULT false,
    updated_at                 timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE notification_preferences (
    user_id                 uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    leave_alert_enabled     boolean NOT NULL DEFAULT true,
    getoff_alert_enabled    boolean NOT NULL DEFAULT true,
    route_change_enabled    boolean NOT NULL DEFAULT true,
    community_enabled       boolean NOT NULL DEFAULT true,
    updated_at              timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE device_installations (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    installation_key    text NOT NULL,
    platform            text NOT NULL CHECK (platform IN ('IOS', 'ANDROID', 'WEB')),
    push_token          text,
    app_version         text,
    enabled             boolean NOT NULL DEFAULT true,
    last_seen_at        timestamptz,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT device_installations_user_key_uk UNIQUE (user_id, installation_key),
    CONSTRAINT device_installations_token_ck CHECK (push_token IS NULL OR length(push_token) > 0)
);

CREATE TABLE data_export_requests (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status          text NOT NULL DEFAULT 'REQUESTED'
        CHECK (status IN ('REQUESTED', 'PROCESSING', 'READY', 'EXPIRED', 'FAILED')),
    format          text NOT NULL DEFAULT 'JSON'
        CHECK (format IN ('JSON', 'CSV')),
    requested_at    timestamptz NOT NULL DEFAULT now(),
    expires_at      timestamptz,
    completed_at    timestamptz,
    result_ref      text,
    CONSTRAINT data_export_requests_expiry_ck CHECK (expires_at IS NULL OR expires_at > requested_at)
);

CREATE TABLE guest_migration_audits (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    idempotency_key     text NOT NULL,
    request_hash        text NOT NULL,
    status              text NOT NULL CHECK (status IN ('STARTED', 'COMPLETED', 'FAILED')),
    imported_counts     jsonb NOT NULL DEFAULT '{}'::jsonb,
    error_code          text,
    created_at          timestamptz NOT NULL DEFAULT now(),
    completed_at        timestamptz,
    CONSTRAINT guest_migration_audits_user_key_uk UNIQUE (user_id, idempotency_key)
);

CREATE INDEX users_deleted_at_idx ON users (deleted_at);
CREATE INDEX device_installations_user_enabled_idx ON device_installations (user_id, enabled);
CREATE INDEX data_export_requests_user_created_idx ON data_export_requests (user_id, requested_at DESC);
CREATE INDEX guest_migration_audits_user_created_idx ON guest_migration_audits (user_id, created_at DESC);
