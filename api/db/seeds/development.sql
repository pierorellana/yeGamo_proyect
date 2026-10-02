-- Development-only synthetic fixture. Never run this file in production.
DO $$
BEGIN
    IF current_setting('yegamo.seed_mode', true) IS DISTINCT FROM 'development' THEN
        RAISE EXCEPTION 'Development seeds require yegamo.seed_mode=development';
    END IF;
END
$$;

INSERT INTO transit_agencies (id, name, timezone, is_demo)
VALUES ('00000000-0000-4000-8000-000000000001', 'yeGamo Demo Agency', 'America/Guayaquil', true)
ON CONFLICT (id) DO UPDATE SET is_demo = true, updated_at = now();

INSERT INTO transit_routes (id, agency_id, short_name, long_name, route_type)
VALUES ('00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'D-01', 'Demo route only', 'BUS')
ON CONFLICT (id) DO UPDATE SET agency_id = EXCLUDED.agency_id, canonical_status = 'ACTIVE', updated_at = now();

INSERT INTO transit_stops (id, agency_id, name, code, location)
VALUES
    ('00000000-0000-4000-8000-000000000003', '00000000-0000-4000-8000-000000000001', 'Demo origin stop', 'D-01-A', ST_SetSRID(ST_MakePoint(-79.9000, -2.1700), 4326)::geography),
    ('00000000-0000-4000-8000-000000000004', '00000000-0000-4000-8000-000000000001', 'Demo destination stop', 'D-01-B', ST_SetSRID(ST_MakePoint(-79.8900, -2.1400), 4326)::geography)
ON CONFLICT (id) DO NOTHING;

INSERT INTO route_stops (route_id, stop_id, direction_id, stop_sequence)
VALUES
    ('00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000003', '0', 0),
    ('00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000004', '0', 1)
ON CONFLICT DO NOTHING;

INSERT INTO provider_references (entity_type, entity_id, provider, external_id, storage_policy, metadata)
VALUES
    ('AGENCY', '00000000-0000-4000-8000-000000000001', 'demo-transit', 'demo-agency-1', 'EPHEMERAL_ONLY', '{"demo":true}'::jsonb),
    ('ROUTE', '00000000-0000-4000-8000-000000000002', 'demo-transit', 'demo-route-1', 'EPHEMERAL_ONLY', '{"demo":true}'::jsonb)
ON CONFLICT (provider, entity_type, external_id) DO UPDATE
SET storage_policy = 'EPHEMERAL_ONLY', metadata = EXCLUDED.metadata, updated_at = now();
