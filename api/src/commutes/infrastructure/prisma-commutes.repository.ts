import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../../shared/database/prisma.service';
import type { CommuteProfile, CommuteProfileInput, CommuteRepository } from '../domain/commutes.ports';

interface CommuteRow { id: string; name: string; originLat: number; originLon: number; destinationLat: number; destinationLon: number; weekdays: number[]; targetArrival: string; enabled: boolean }

@Injectable()
export class PrismaCommuteRepository implements CommuteRepository {
  constructor(private readonly prisma: PrismaService) {}

  async list(userId: string): Promise<CommuteProfile[]> {
    const rows = await this.prisma.$queryRaw<CommuteRow[]>(selectSql(userId));
    return rows.map(toProfile);
  }

  async create(userId: string, input: CommuteProfileInput): Promise<CommuteProfile> {
    const rows = await this.prisma.$queryRaw<CommuteRow[]>(Prisma.sql`
      INSERT INTO commute_profiles (user_id, name, origin, destination, weekdays, target_arrival)
      VALUES (${userId}::uuid, ${input.name}, ST_SetSRID(ST_MakePoint(${input.origin.lon}, ${input.origin.lat}), 4326)::geography, ST_SetSRID(ST_MakePoint(${input.destination.lon}, ${input.destination.lat}), 4326)::geography, ${input.weekdays.map((day) => day - 1)}::smallint[], ${input.targetArrival}::time)
      RETURNING id, name, ST_Y(origin::geometry)::float8 AS "originLat", ST_X(origin::geometry)::float8 AS "originLon", ST_Y(destination::geometry)::float8 AS "destinationLat", ST_X(destination::geometry)::float8 AS "destinationLon", weekdays::int[] AS weekdays, target_arrival::text AS "targetArrival", enabled`);
    const row = rows[0];
    if (row === undefined) throw new Error('commute_profiles insert returned no row');
    return toProfile(row);
  }

  async update(userId: string, id: string, input: CommuteProfileInput): Promise<CommuteProfile | null> {
    const rows = await this.prisma.$queryRaw<CommuteRow[]>(Prisma.sql`
      UPDATE commute_profiles SET name = ${input.name}, origin = ST_SetSRID(ST_MakePoint(${input.origin.lon}, ${input.origin.lat}), 4326)::geography, destination = ST_SetSRID(ST_MakePoint(${input.destination.lon}, ${input.destination.lat}), 4326)::geography, weekdays = ${input.weekdays.map((day) => day - 1)}::smallint[], target_arrival = ${input.targetArrival}::time, updated_at = now()
      WHERE id = ${id}::uuid AND user_id = ${userId}::uuid
      RETURNING id, name, ST_Y(origin::geometry)::float8 AS "originLat", ST_X(origin::geometry)::float8 AS "originLon", ST_Y(destination::geometry)::float8 AS "destinationLat", ST_X(destination::geometry)::float8 AS "destinationLon", weekdays::int[] AS weekdays, target_arrival::text AS "targetArrival", enabled`);
    return rows[0] === undefined ? null : toProfile(rows[0]);
  }

  async setEnabled(userId: string, id: string, enabled: boolean): Promise<CommuteProfile | null> {
    const rows = await this.prisma.$queryRaw<CommuteRow[]>(Prisma.sql`
      UPDATE commute_profiles SET enabled = ${enabled}, updated_at = now()
      WHERE id = ${id}::uuid AND user_id = ${userId}::uuid
      RETURNING id, name, ST_Y(origin::geometry)::float8 AS "originLat", ST_X(origin::geometry)::float8 AS "originLon", ST_Y(destination::geometry)::float8 AS "destinationLat", ST_X(destination::geometry)::float8 AS "destinationLon", weekdays::int[] AS weekdays, target_arrival::text AS "targetArrival", enabled`);
    return rows[0] === undefined ? null : toProfile(rows[0]);
  }

  async delete(userId: string, id: string): Promise<boolean> {
    return (await this.prisma.$executeRaw(Prisma.sql`DELETE FROM commute_profiles WHERE id = ${id}::uuid AND user_id = ${userId}::uuid`)) > 0;
  }

  async existsForUser(userId: string, id: string): Promise<boolean> {
    const rows = await this.prisma.$queryRaw<Array<{ id: string }>>(Prisma.sql`SELECT id FROM commute_profiles WHERE id = ${id}::uuid AND user_id = ${userId}::uuid`);
    return rows.length > 0;
  }
}

function selectSql(userId: string) {
  return Prisma.sql`SELECT id, name, ST_Y(origin::geometry)::float8 AS "originLat", ST_X(origin::geometry)::float8 AS "originLon", ST_Y(destination::geometry)::float8 AS "destinationLat", ST_X(destination::geometry)::float8 AS "destinationLon", weekdays::int[] AS weekdays, target_arrival::text AS "targetArrival", enabled FROM commute_profiles WHERE user_id = ${userId}::uuid ORDER BY created_at DESC`;
}

function toProfile(row: CommuteRow): CommuteProfile {
  return { id: row.id, name: row.name, origin: { lat: Number(row.originLat), lon: Number(row.originLon) }, destination: { lat: Number(row.destinationLat), lon: Number(row.destinationLon) }, weekdays: row.weekdays.map((day) => Number(day) + 1), targetArrival: row.targetArrival.slice(0, 8), enabled: row.enabled };
}
