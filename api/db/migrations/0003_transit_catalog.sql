-- yeGamo migration 0003: canonical transit catalog and licensed provider metadata.

CREATE TABLE transit_agencies (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name                text NOT NULL,
    timezone            text NOT NULL DEFAULT 'America/Guayaquil',
    is_demo             boolean NOT NULL DEFAULT false,
    canonical_status    text NOT NULL DEFAULT 'ACTIVE'
        CHECK (canonical_status IN ('ACTIVE', 'INACTIVE', 'PENDING')),
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE transit_routes (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id           uuid REFERENCES transit_agencies(id) ON DELETE SET NULL,
    short_name          text,
    long_name           text,
    route_type          text NOT NULL DEFAULT 'BUS'
        CHECK (route_type IN ('BUS', 'TRAM', 'SUBWAY', 'RAIL', 'FERRY', 'CABLE_CAR', 'OTHER')),
    canonical_status    text NOT NULL DEFAULT 'ACTIVE'
        CHECK (canonical_status IN ('ACTIVE', 'INACTIVE', 'PENDING')),
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT transit_routes_name_ck CHECK (short_name IS NOT NULL OR long_name IS NOT NULL)
);

CREATE TABLE transit_stops (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id           uuid REFERENCES transit_agencies(id) ON DELETE SET NULL,
    name                text NOT NULL,
    code                text,
    location            geography(Point, 4326) NOT NULL,
    canonical_status    text NOT NULL DEFAULT 'ACTIVE'
        CHECK (canonical_status IN ('ACTIVE', 'INACTIVE', 'PENDING')),
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE route_stops (
    route_id            uuid NOT NULL REFERENCES transit_routes(id) ON DELETE CASCADE,
    stop_id             uuid NOT NULL REFERENCES transit_stops(id) ON DELETE CASCADE,
    direction_id        text NOT NULL DEFAULT '0',
    stop_sequence       integer NOT NULL CHECK (stop_sequence >= 0),
    pickup_type         text NOT NULL DEFAULT 'REGULAR'
        CHECK (pickup_type IN ('REGULAR', 'NONE', 'PHONE', 'COORDINATED')),
    drop_off_type       text NOT NULL DEFAULT 'REGULAR'
        CHECK (drop_off_type IN ('REGULAR', 'NONE', 'PHONE', 'COORDINATED')),
    PRIMARY KEY (route_id, direction_id, stop_sequence),
    CONSTRAINT route_stops_route_stop_uk UNIQUE (route_id, direction_id, stop_id, stop_sequence)
);

CREATE TABLE provider_references (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type         text NOT NULL CHECK (entity_type IN ('AGENCY', 'ROUTE', 'STOP', 'SHAPE', 'FEED')),
    entity_id           uuid NOT NULL,
    provider            text NOT NULL,
    external_id         text NOT NULL,
    storage_policy      text NOT NULL CHECK (storage_policy IN ('PERSIST_ALLOWED', 'EPHEMERAL_ONLY', 'METADATA_ONLY')),
    last_seen_at        timestamptz,
    metadata            jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT provider_references_external_uk UNIQUE (provider, entity_type, external_id)
);

CREATE TABLE transit_feed_versions (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    provider            text NOT NULL,
    feed_name           text NOT NULL,
    version              text NOT NULL,
    storage_policy      text NOT NULL CHECK (storage_policy IN ('PERSIST_ALLOWED', 'EPHEMERAL_ONLY', 'METADATA_ONLY')),
    status              text NOT NULL DEFAULT 'RECEIVED'
        CHECK (status IN ('RECEIVED', 'APPLIED', 'REJECTED', 'EXPIRED')),
    fetched_at          timestamptz NOT NULL DEFAULT now(),
    valid_from          timestamptz,
    valid_until         timestamptz,
    metadata            jsonb NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT transit_feed_versions_identity_uk UNIQUE (provider, feed_name, version),
    CONSTRAINT transit_feed_versions_window_ck CHECK (valid_until IS NULL OR valid_from IS NULL OR valid_until > valid_from)
);

CREATE TABLE transit_route_shapes (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    route_id            uuid NOT NULL REFERENCES transit_routes(id) ON DELETE CASCADE,
    direction_id        text NOT NULL DEFAULT '0',
    shape                geometry(LineString, 4326) NOT NULL,
    source_feed_version_id uuid REFERENCES transit_feed_versions(id) ON DELETE SET NULL,
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT transit_route_shapes_route_direction_uk UNIQUE (route_id, direction_id)
);

CREATE INDEX transit_routes_agency_status_idx ON transit_routes (agency_id, canonical_status);
CREATE INDEX transit_stops_agency_status_idx ON transit_stops (agency_id, canonical_status);
CREATE INDEX route_stops_stop_idx ON route_stops (stop_id, route_id);
CREATE INDEX provider_references_entity_idx ON provider_references (entity_type, entity_id);
CREATE INDEX provider_references_last_seen_idx ON provider_references (last_seen_at DESC);
CREATE INDEX transit_feed_versions_provider_fetched_idx ON transit_feed_versions (provider, fetched_at DESC);
CREATE INDEX transit_route_shapes_route_idx ON transit_route_shapes (route_id, direction_id);
