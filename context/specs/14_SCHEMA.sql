CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text UNIQUE,
  display_name text,
  created_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE transit_routes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  short_name text,
  long_name text,
  route_type text NOT NULL DEFAULT 'BUS',
  canonical_status text NOT NULL DEFAULT 'ACTIVE',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE transit_stops (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  location geography(Point,4326) NOT NULL,
  canonical_status text NOT NULL DEFAULT 'ACTIVE',
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_transit_stops_location ON transit_stops USING gist(location);

CREATE TABLE provider_references (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type text NOT NULL,
  entity_id uuid,
  provider text NOT NULL,
  external_id text NOT NULL,
  storage_policy text NOT NULL CHECK (storage_policy IN ('PERSIST_ALLOWED','EPHEMERAL_ONLY','METADATA_ONLY')),
  last_seen_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE(provider, entity_type, external_id)
);

CREATE TABLE saved_places (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  label text NOT NULL,
  location geography(Point,4326) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_saved_places_location ON saved_places USING gist(location);

CREATE TABLE commute_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name text NOT NULL,
  origin geography(Point,4326) NOT NULL,
  destination geography(Point,4326) NOT NULL,
  weekdays smallint[] NOT NULL,
  target_arrival time NOT NULL,
  preference text NOT NULL DEFAULT 'BALANCED',
  extra_margin_min integer NOT NULL DEFAULT 0,
  enabled boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE journey_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  origin geography(Point,4326) NOT NULL,
  destination geography(Point,4326) NOT NULL,
  time_mode text NOT NULL,
  requested_time timestamptz,
  preference text NOT NULL DEFAULT 'BALANCED',
  recommended_leave_at timestamptz,
  provider_summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE journey_options (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES journey_plans(id) ON DELETE CASCADE,
  rank integer NOT NULL,
  duration_min integer NOT NULL,
  walk_min integer NOT NULL DEFAULT 0,
  transfers integer NOT NULL DEFAULT 0,
  reliability_score integer,
  provider text NOT NULL,
  payload jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE active_journeys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  option_id uuid NOT NULL REFERENCES journey_options(id),
  status text NOT NULL CHECK (status IN ('ACTIVE','COMPLETED','CANCELLED','ABANDONED')),
  started_at timestamptz NOT NULL DEFAULT now(),
  finished_at timestamptz,
  actual_arrival_at timestamptz
);

CREATE TABLE community_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  report_type text NOT NULL,
  location geography(Point,4326) NOT NULL,
  route_id uuid REFERENCES transit_routes(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'ACTIVE',
  confidence numeric(5,2) NOT NULL DEFAULT 0,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_reports_location ON community_reports USING gist(location);

CREATE TABLE route_observations (
  id bigserial PRIMARY KEY,
  route_id uuid REFERENCES transit_routes(id) ON DELETE CASCADE,
  observed_at timestamptz NOT NULL,
  expected_duration_sec integer,
  actual_duration_sec integer,
  source text NOT NULL,
  quality numeric(5,2),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);


-- yeGamo v1.1: alerts and notification center
create table if not exists leave_alerts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid null,
  commute_profile_id uuid null,
  journey_plan_id uuid null,
  scheduled_for timestamptz not null,
  status text not null default 'SCHEDULED',
  idempotency_key text null,
  created_at timestamptz not null default now()
);

create unique index if not exists ux_leave_alerts_idempotency
  on leave_alerts(idempotency_key) where idempotency_key is not null;

create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid null,
  type text not null,
  title text not null,
  body text not null,
  payload jsonb not null default '{}'::jsonb,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists ix_notifications_user_created
  on notifications(user_id, created_at desc);

create table if not exists notification_preferences (
  user_id uuid primary key,
  leave_alert_enabled boolean not null default true,
  getoff_alert_enabled boolean not null default true,
  route_change_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);
