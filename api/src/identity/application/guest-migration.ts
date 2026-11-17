import { Prisma } from '@prisma/client';

/** Canonical reasons returned per migrated item. */
export type MigrationItemStatus = 'IMPORTED' | 'DUPLICATE' | 'REJECTED';
export type MigrationReason = 'INVALID_COORDINATES' | 'INVALID_FIELD' | 'UNSUPPORTED_TYPE' | 'ALREADY_EXISTS' | 'LIMIT_REACHED';

export interface MigrationItemResult {
  readonly index: number;
  readonly type: string;
  readonly status: MigrationItemStatus;
  readonly reason: MigrationReason | null;
  /** Server id of the created resource (IMPORTED) or the existing one (DUPLICATE). */
  readonly id: string | null;
}

export const SUPPORTED_CLIENT_DATA_VERSION = '1';
export const MAX_MIGRATION_ITEMS = 200;
const MAX_FAVORITES = 100;
const MAX_ROUTINES = 50;

interface Point { lat: number; lon: number }

/**
 * Migrates one guest item inside the caller's transaction. Each item is
 * validated on its own so a bad item is REJECTED with a reason instead of
 * failing (or silently dropping) the whole package.
 */
export async function migrateItem(tx: Prisma.TransactionClient, userId: string, index: number, raw: Record<string, unknown>): Promise<MigrationItemResult> {
  const type = typeof raw.type === 'string' ? raw.type : 'UNKNOWN';
  if (type === 'FAVORITE_PLACE') return migrateFavorite(tx, userId, index, raw);
  if (type === 'COMMUTE_PROFILE') return migrateRoutine(tx, userId, index, raw);
  return { index, type, status: 'REJECTED', reason: 'UNSUPPORTED_TYPE', id: null };
}

async function migrateFavorite(tx: Prisma.TransactionClient, userId: string, index: number, raw: Record<string, unknown>): Promise<MigrationItemResult> {
  const type = 'FAVORITE_PLACE';
  const label = typeof raw.label === 'string' ? raw.label.trim() : '';
  if (label.length === 0 || label.length > 120) return rejected(index, type, 'INVALID_FIELD');
  const location = toPoint(raw.location);
  if (location === null) return rejected(index, type, 'INVALID_COORDINATES');

  const existing = await tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
    SELECT id FROM saved_places
    WHERE user_id = ${userId}::uuid AND lower(label) = lower(${label})
      AND ST_DWithin(location, ST_SetSRID(ST_MakePoint(${location.lon}, ${location.lat}), 4326)::geography, 25)
    LIMIT 1`);
  if (existing[0] !== undefined) return { index, type, status: 'DUPLICATE', reason: 'ALREADY_EXISTS', id: existing[0].id };

  const count = await tx.$queryRaw<Array<{ n: bigint }>>(Prisma.sql`SELECT count(*) AS n FROM saved_places WHERE user_id = ${userId}::uuid`);
  if (Number(count[0]?.n ?? 0) >= MAX_FAVORITES) return rejected(index, type, 'LIMIT_REACHED');

  const rows = await tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
    INSERT INTO saved_places (user_id, label, location, geocoding_metadata)
    VALUES (${userId}::uuid, ${label}, ST_SetSRID(ST_MakePoint(${location.lon}, ${location.lat}), 4326)::geography, '{"origin":"guest-migration"}'::jsonb)
    RETURNING id`);
  return { index, type, status: 'IMPORTED', reason: null, id: rows[0]?.id ?? null };
}

async function migrateRoutine(tx: Prisma.TransactionClient, userId: string, index: number, raw: Record<string, unknown>): Promise<MigrationItemResult> {
  const type = 'COMMUTE_PROFILE';
  const name = typeof raw.name === 'string' ? raw.name.trim() : '';
  if (name.length === 0 || name.length > 100) return rejected(index, type, 'INVALID_FIELD');
  const origin = toPoint(raw.origin);
  const destination = toPoint(raw.destination);
  if (origin === null || destination === null) return rejected(index, type, 'INVALID_COORDINATES');
  const weekdays = raw.weekdays;
  if (!Array.isArray(weekdays) || weekdays.length < 1 || weekdays.length > 7 || !weekdays.every((day) => Number.isInteger(day) && day >= 1 && day <= 7)) {
    return rejected(index, type, 'INVALID_FIELD');
  }
  const targetArrival = raw.targetArrival;
  if (typeof targetArrival !== 'string' || !/^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/.test(targetArrival)) return rejected(index, type, 'INVALID_FIELD');
  const days = [...new Set(weekdays as number[])].sort((a, b) => a - b).map((day) => day - 1);

  const existing = await tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
    SELECT id FROM commute_profiles
    WHERE user_id = ${userId}::uuid AND lower(name) = lower(${name}) AND target_arrival = ${targetArrival}::time
      AND weekdays::int[] = ${days}::int[]
      AND ST_DWithin(origin, ST_SetSRID(ST_MakePoint(${origin.lon}, ${origin.lat}), 4326)::geography, 25)
      AND ST_DWithin(destination, ST_SetSRID(ST_MakePoint(${destination.lon}, ${destination.lat}), 4326)::geography, 25)
    LIMIT 1`);
  if (existing[0] !== undefined) return { index, type, status: 'DUPLICATE', reason: 'ALREADY_EXISTS', id: existing[0].id };

  const count = await tx.$queryRaw<Array<{ n: bigint }>>(Prisma.sql`SELECT count(*) AS n FROM commute_profiles WHERE user_id = ${userId}::uuid`);
  if (Number(count[0]?.n ?? 0) >= MAX_ROUTINES) return rejected(index, type, 'LIMIT_REACHED');

  const rows = await tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
    INSERT INTO commute_profiles (user_id, name, origin, destination, weekdays, target_arrival)
    VALUES (${userId}::uuid, ${name}, ST_SetSRID(ST_MakePoint(${origin.lon}, ${origin.lat}), 4326)::geography,
      ST_SetSRID(ST_MakePoint(${destination.lon}, ${destination.lat}), 4326)::geography, ${days}::smallint[], ${targetArrival}::time)
    RETURNING id`);
  return { index, type, status: 'IMPORTED', reason: null, id: rows[0]?.id ?? null };
}

function rejected(index: number, type: string, reason: MigrationReason): MigrationItemResult {
  return { index, type, status: 'REJECTED', reason, id: null };
}

function toPoint(value: unknown): Point | null {
  if (typeof value !== 'object' || value === null) return null;
  const { lat, lon } = value as { lat?: unknown; lon?: unknown };
  if (typeof lat !== 'number' || typeof lon !== 'number' || !Number.isFinite(lat) || !Number.isFinite(lon)) return null;
  return Math.abs(lat) <= 90 && Math.abs(lon) <= 180 ? { lat, lon } : null;
}
