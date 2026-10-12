import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../../shared/database/prisma.service';
import type { Place } from '../../provider-gateway/domain/provider.types';
import type { FavoritePlaceInput, FavoritePlacesRepository } from '../domain/favorites.ports';

interface PlaceRow { id: string; label: string; lat: number; lon: number }

@Injectable()
export class PrismaFavoritePlacesRepository implements FavoritePlacesRepository {
  constructor(private readonly prisma: PrismaService) {}

  async list(userId: string): Promise<Place[]> {
    const rows = await this.prisma.$queryRaw<PlaceRow[]>(Prisma.sql`
      SELECT id, label, ST_Y(location::geometry)::float8 AS lat, ST_X(location::geometry)::float8 AS lon
      FROM saved_places WHERE user_id = ${userId}::uuid ORDER BY created_at DESC`);
    return rows.map(toPlace);
  }

  async create(userId: string, input: FavoritePlaceInput): Promise<Place> {
    const rows = await this.prisma.$queryRaw<PlaceRow[]>(Prisma.sql`
      INSERT INTO saved_places (user_id, label, location, geocoding_metadata)
      VALUES (${userId}::uuid, ${input.label}, ST_SetSRID(ST_MakePoint(${input.location.lon}, ${input.location.lat}), 4326)::geography, '{}'::jsonb)
      RETURNING id, label, ST_Y(location::geometry)::float8 AS lat, ST_X(location::geometry)::float8 AS lon`);
    const row = rows[0];
    if (row === undefined) throw new Error('saved_places insert returned no row');
    return toPlace(row);
  }

  async update(userId: string, id: string, input: FavoritePlaceInput): Promise<Place | null> {
    const rows = await this.prisma.$queryRaw<PlaceRow[]>(Prisma.sql`
      UPDATE saved_places SET label = ${input.label}, location = ST_SetSRID(ST_MakePoint(${input.location.lon}, ${input.location.lat}), 4326)::geography, updated_at = now()
      WHERE id = ${id}::uuid AND user_id = ${userId}::uuid
      RETURNING id, label, ST_Y(location::geometry)::float8 AS lat, ST_X(location::geometry)::float8 AS lon`);
    return rows[0] === undefined ? null : toPlace(rows[0]);
  }

  async delete(userId: string, id: string): Promise<boolean> {
    const result = await this.prisma.$executeRaw(Prisma.sql`DELETE FROM saved_places WHERE id = ${id}::uuid AND user_id = ${userId}::uuid`);
    return result > 0;
  }
}

function toPlace(row: PlaceRow): Place {
  return { id: row.id, label: row.label, location: { lat: Number(row.lat), lon: Number(row.lon) }, source: null };
}
