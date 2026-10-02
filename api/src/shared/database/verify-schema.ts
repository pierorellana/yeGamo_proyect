import { Pool } from 'pg';

const REQUIRED_TABLES = [
  'schema_migrations',
  'users',
  'user_preferences',
  'notification_preferences',
  'device_installations',
  'data_export_requests',
  'guest_migration_audits',
  'transit_agencies',
  'transit_routes',
  'transit_stops',
  'route_stops',
  'provider_references',
  'transit_feed_versions',
  'transit_route_shapes',
  'journey_plans',
  'journey_options',
  'journey_legs',
  'active_journeys',
  'journey_events',
  'saved_places',
  'commute_profiles',
  'leave_alerts',
  'notifications',
  'notification_deliveries',
  'route_observations',
  'route_metrics',
  'provider_health_snapshots',
  'community_reports',
  'report_confirmations',
  'retention_policies',
] as const;

const REQUIRED_INDEXES = [
  'transit_stops_location_gist_idx',
  'saved_places_location_gist_idx',
  'community_reports_location_gist_idx',
  'transit_route_shapes_shape_gist_idx',
  'journey_legs_shape_gist_idx',
  'active_journeys_one_current_per_user_idx',
] as const;

const SPATIAL_COLUMNS = [
  ['transit_stops', 'location', 'geography(Point,4326)'],
  ['saved_places', 'location', 'geography(Point,4326)'],
  ['community_reports', 'location', 'geography(Point,4326)'],
  ['transit_route_shapes', 'shape', 'geometry(LineString,4326)'],
  ['journey_legs', 'shape', 'geometry(LineString,4326)'],
] as const;

export interface SchemaVerification {
  tables: number;
  indexes: number;
  spatialColumns: number;
  stDWithin: boolean;
}

export async function verifySchema(databaseUrl = process.env.DATABASE_URL): Promise<SchemaVerification> {
  if (!databaseUrl) {
    throw new Error('DATABASE_URL is required to verify the schema');
  }

  const pool = new Pool({ connectionString: databaseUrl });
  try {
    const extensionResult = await pool.query<{ extname: string }>(
      `SELECT extname FROM pg_extension WHERE extname = ANY($1::text[])`,
      [['postgis', 'pgcrypto']],
    );
    const extensions = new Set(extensionResult.rows.map((row) => row.extname));
    for (const extension of ['postgis', 'pgcrypto']) {
      if (!extensions.has(extension)) {
        throw new Error(`Missing required PostgreSQL extension: ${extension}`);
      }
    }

    const tableResult = await pool.query<{ table_name: string }>(
      `SELECT table_name
         FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_name = ANY($1::text[])`,
      [REQUIRED_TABLES],
    );
    const tables = new Set(tableResult.rows.map((row) => row.table_name));
    const missingTables = REQUIRED_TABLES.filter((table) => !tables.has(table));
    if (missingTables.length > 0) {
      throw new Error(`Missing required tables: ${missingTables.join(', ')}`);
    }

    const indexResult = await pool.query<{ indexname: string }>(
      `SELECT indexname FROM pg_indexes WHERE schemaname = 'public' AND indexname = ANY($1::text[])`,
      [REQUIRED_INDEXES],
    );
    const indexes = new Set(indexResult.rows.map((row) => row.indexname));
    const missingIndexes = REQUIRED_INDEXES.filter((index) => !indexes.has(index));
    if (missingIndexes.length > 0) {
      throw new Error(`Missing required indexes: ${missingIndexes.join(', ')}`);
    }

    const spatialResult = await pool.query<{ table_name: string; column_name: string; type_name: string }>(
      `SELECT c.table_name, c.column_name, postgis_typmod_type(a.atttypmod) AS type_name
         FROM information_schema.columns c
         JOIN pg_catalog.pg_attribute a
           ON a.attrelid = format('%I.%I', c.table_schema, c.table_name)::regclass
          AND a.attname = c.column_name
        WHERE c.table_schema = 'public'
          AND (c.table_name, c.column_name) IN (
            ('transit_stops', 'location'),
            ('saved_places', 'location'),
            ('community_reports', 'location'),
            ('transit_route_shapes', 'shape'),
            ('journey_legs', 'shape')
          )`,
    );
    const spatialTypes = new Map(
      spatialResult.rows.map((row) => [`${row.table_name}.${row.column_name}`, row.type_name]),
    );
    for (const [table, column, expected] of SPATIAL_COLUMNS) {
      const actual = spatialTypes.get(`${table}.${column}`);
      if (actual !== expected) {
        throw new Error(`Unexpected spatial type for ${table}.${column}: ${actual ?? 'missing'} (expected ${expected})`);
      }
    }

    const proximityResult = await pool.query<{ supported: boolean }>(
      `SELECT ST_DWithin(
        ST_SetSRID(ST_MakePoint(-79.9000, -2.1700), 4326)::geography,
        ST_SetSRID(ST_MakePoint(-79.8990, -2.1700), 4326)::geography,
        250
      ) AS supported`,
    );
    if (proximityResult.rows[0]?.supported !== true) {
      throw new Error('ST_DWithin geography verification failed');
    }

    return {
      tables: REQUIRED_TABLES.length,
      indexes: REQUIRED_INDEXES.length,
      spatialColumns: SPATIAL_COLUMNS.length,
      stDWithin: true,
    };
  } finally {
    await pool.end();
  }
}

async function main(): Promise<void> {
  const result = await verifySchema();
  process.stdout.write(
    `Schema verified: ${result.tables} tables, ${result.indexes} indexes, ` +
      `${result.spatialColumns} spatial columns, ST_DWithin=ok.\n`,
  );
}

if (require.main === module) {
  main().catch((error: unknown) => {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    process.exitCode = 1;
  });
}
