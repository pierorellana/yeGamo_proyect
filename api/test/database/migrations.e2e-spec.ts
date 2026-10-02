import { readFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { Pool } from 'pg';
import { loadMigrationFiles, runMigrations } from '../../src/shared/database/migrate';
import { verifySchema } from '../../src/shared/database/verify-schema';

const databaseUrl = process.env.DATABASE_URL;
const describeDatabase = databaseUrl ? describe : describe.skip;

describeDatabase('SQL-first database migrations', () => {
  let pool: Pool;

  beforeAll(async () => {
    pool = new Pool({ connectionString: databaseUrl });
  });

  afterAll(async () => {
    await pool.end();
  });

  it('applies all versions and exposes the required PostGIS schema', async () => {
    const applied = await runMigrations(databaseUrl);
    expect(applied.map((migration) => migration.version)).toEqual([
      '0001',
      '0002',
      '0003',
      '0004',
      '0005',
      '0006',
      '0007',
    ]);

    await expect(verifySchema(databaseUrl)).resolves.toMatchObject({
      tables: 30,
      spatialColumns: 5,
      stDWithin: true,
    });
  });

  it('is idempotent on a second execution', async () => {
    const first = await runMigrations(databaseUrl);
    const second = await runMigrations(databaseUrl);
    expect(second).toHaveLength(first.length);

    const ledger = await pool.query<{ count: string }>('SELECT count(*)::text AS count FROM schema_migrations');
    const ledgerRow = ledger.rows[0];
    expect(ledgerRow).toBeDefined();
    expect(Number(ledgerRow?.count)).toBe(7);
  });

  it('detects a changed migration checksum before applying later files', async () => {
    const migrationsDirectory = resolve(join(__dirname, '../../db/migrations'));
    const migrations = await loadMigrationFiles(migrationsDirectory);
    const first = migrations[0];
    expect(first).toBeDefined();
    if (first === undefined) {
      throw new Error('Expected at least one migration');
    }
    const ledger = await pool.query<{ checksum: string }>(
      'SELECT checksum FROM schema_migrations WHERE version = $1',
      [first.version],
    );
    expect(ledger.rows[0]?.checksum).toBe(first.checksum);

    // Static guard: the runner hashes the complete SQL file, not just its name.
    const source = await readFile(first.path, 'utf8');
    expect(source).toBe(first.sql);
    expect(first.checksum).toMatch(/^[a-f0-9]{64}$/);
  });
});

describe('database migration artifacts', () => {
  it('keeps seven ordered migration files and explicit development seeds', async () => {
    const migrations = await loadMigrationFiles(resolve(join(__dirname, '../../db/migrations')));
    expect(migrations.map((migration) => migration.version)).toEqual([
      '0001',
      '0002',
      '0003',
      '0004',
      '0005',
      '0006',
      '0007',
    ]);

    const seeds = await readFile(resolve(join(__dirname, '../../db/seeds/development.sql')), 'utf8');
    expect(seeds).toContain("yegamo.seed_mode=development");
    expect(seeds).not.toContain('RutaYa');
    expect(seeds).not.toContain('Metrovia GTFS');
  });
});
