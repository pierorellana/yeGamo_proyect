import { createHash } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { Pool, PoolClient } from 'pg';

const ADVISORY_LOCK_KEY = 'yegamo:schema-migrations:v1';
const MIGRATION_FILE = /^(\d{4})_[a-z0-9_]+\.sql$/;

export interface MigrationFile {
  version: string;
  name: string;
  path: string;
  sql: string;
  checksum: string;
}

export interface AppliedMigration {
  version: string;
  name: string;
  checksum: string;
  appliedAt: Date;
  executionTimeMs: number;
}

function migrationsPath(directory?: string): string {
  return resolve(directory ?? join(__dirname, '../../../db/migrations'));
}

export async function loadMigrationFiles(directory?: string): Promise<MigrationFile[]> {
  const files = (await readdir(migrationsPath(directory)))
    .filter((file) => MIGRATION_FILE.test(file))
    .sort();

  const migrations = await Promise.all(
    files.map(async (file) => {
      const sql = await readFile(join(migrationsPath(directory), file), 'utf8');
      const match = MIGRATION_FILE.exec(file);
      if (!match) {
        throw new Error(`Invalid migration filename: ${file}`);
      }

      const version = match[1];
      if (version === undefined) {
        throw new Error(`Migration filename is missing a version: ${file}`);
      }

      return {
        version,
        name: file,
        path: join(migrationsPath(directory), file),
        sql,
        checksum: createHash('sha256').update(sql, 'utf8').digest('hex'),
      };
    }),
  );

  const versions = new Set<string>();
  for (const migration of migrations) {
    if (versions.has(migration.version)) {
      throw new Error(`Duplicate migration version: ${migration.version}`);
    }
    versions.add(migration.version);
  }
  return migrations;
}

async function hasMigrationLedger(client: PoolClient): Promise<boolean> {
  const result = await client.query<{ table_name: string | null }>(
    "SELECT to_regclass('public.schema_migrations') AS table_name",
  );
  return result.rows[0]?.table_name !== null;
}

async function appliedMigrations(client: PoolClient): Promise<Map<string, AppliedMigration>> {
  if (!(await hasMigrationLedger(client))) {
    return new Map();
  }

  const result = await client.query<{
    version: string;
    name: string;
    checksum: string;
    applied_at: Date;
    execution_time_ms: number;
  }>(
    `SELECT version, name, checksum, applied_at, execution_time_ms
       FROM schema_migrations
      ORDER BY version`,
  );

  return new Map(
    result.rows.map((row) => [
      row.version,
      {
        version: row.version,
        name: row.name,
        checksum: row.checksum,
        appliedAt: row.applied_at,
        executionTimeMs: row.execution_time_ms,
      },
    ]),
  );
}

async function applyMigration(client: PoolClient, migration: MigrationFile): Promise<void> {
  const startedAt = Date.now();
  await client.query('BEGIN');
  try {
    // Each SQL file is deliberately executed as one statement batch inside this transaction.
    await client.query(migration.sql);
    await client.query(
      `INSERT INTO schema_migrations (version, name, checksum, execution_time_ms)
       VALUES ($1, $2, $3, $4)`,
      [migration.version, migration.name, migration.checksum, Date.now() - startedAt],
    );
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  }
}

export async function runMigrations(
  databaseUrl = process.env.DATABASE_URL,
  directory?: string,
): Promise<AppliedMigration[]> {
  if (!databaseUrl) {
    throw new Error('DATABASE_URL is required to run migrations');
  }

  const migrations = await loadMigrationFiles(directory);
  const pool = new Pool({ connectionString: databaseUrl });
  const client = await pool.connect();

  try {
    await client.query('SELECT pg_advisory_lock(hashtext($1))', [ADVISORY_LOCK_KEY]);
    try {
      let applied = await appliedMigrations(client);
      for (const migration of migrations) {
        const previous = applied.get(migration.version);
        if (previous) {
          if (previous.checksum !== migration.checksum) {
            throw new Error(
              `Migration checksum mismatch for ${migration.name}: ` +
                `database=${previous.checksum} file=${migration.checksum}`,
            );
          }
          continue;
        }

        await applyMigration(client, migration);
        applied = await appliedMigrations(client);
      }
      return [...applied.values()];
    } finally {
      await client.query('SELECT pg_advisory_unlock(hashtext($1))', [ADVISORY_LOCK_KEY]);
    }
  } finally {
    client.release();
    await pool.end();
  }
}

async function main(): Promise<void> {
  const result = await runMigrations();
  process.stdout.write(`Applied/verified ${result.length} yeGamo migrations.\n`);
}

if (require.main === module) {
  main().catch((error: unknown) => {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    process.exitCode = 1;
  });
}
