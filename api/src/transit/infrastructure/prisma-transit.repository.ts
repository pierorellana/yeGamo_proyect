import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../../shared/database/prisma.service';
import type {
  Departure,
  NearbyStopsInput,
  TransitAgency,
  TransitReadPort,
  TransitRoute,
  TransitStop,
} from '../domain/transit.ports';

interface NearbyStopRow {
  id: string;
  name: string;
  lat: number;
  lon: number;
  distance_m: number;
}

interface TransitRouteRow {
  id: string;
  short_name: string | null;
  long_name: string | null;
  agency_id: string | null;
  agency_name: string | null;
  agency_timezone: string | null;
}

/**
 * SQL is kept here because the transit catalog uses PostGIS geography
 * operators that Prisma cannot express through its typed CRUD API.
 */
@Injectable()
export class PrismaTransitReadRepository implements TransitReadPort {
  constructor(private readonly prisma: PrismaService) {}

  async nearbyStops(input: NearbyStopsInput): Promise<TransitStop[]> {
    const rows = await this.prisma.$queryRaw<NearbyStopRow[]>(Prisma.sql`
      SELECT
        s.id::text AS id,
        s.name,
        ST_Y(s.location::geometry)::float8 AS lat,
        ST_X(s.location::geometry)::float8 AS lon,
        ST_Distance(
          s.location,
          ST_SetSRID(ST_MakePoint(${input.lon}, ${input.lat}), 4326)::geography
        )::float8 AS distance_m
      FROM transit_stops AS s
      WHERE s.canonical_status = 'ACTIVE'
        AND ST_DWithin(
          s.location,
          ST_SetSRID(ST_MakePoint(${input.lon}, ${input.lat}), 4326)::geography,
          ${input.radiusM}
        )
      ORDER BY distance_m ASC, s.name ASC
    `);

    return rows.map((row) => ({
      id: row.id,
      name: row.name,
      location: { lat: Number(row.lat), lon: Number(row.lon) },
      distanceM: Number(row.distance_m),
      dataState: 'DEGRADED',
    }));
  }

  // The canonical schema has no timetable/departure table yet, so returning
  // an empty list is more honest than inventing scheduled or live arrivals.
  async departures(_stopId: string): Promise<Departure[]> {
    return [];
  }

  async route(routeId: string): Promise<TransitRoute | null> {
    const rows = await this.prisma.$queryRaw<TransitRouteRow[]>(Prisma.sql`
      SELECT
        r.id::text AS id,
        r.short_name,
        r.long_name,
        a.id::text AS agency_id,
        a.name AS agency_name,
        a.timezone AS agency_timezone
      FROM transit_routes AS r
      LEFT JOIN transit_agencies AS a ON a.id = r.agency_id
      WHERE r.id = ${routeId}::uuid
        AND r.canonical_status = 'ACTIVE'
        AND (a.id IS NULL OR a.canonical_status = 'ACTIVE')
      LIMIT 1
    `);
    const row = rows[0];
    if (
      row === undefined ||
      row.agency_id === null ||
      row.agency_name === null ||
      row.agency_timezone === null
    ) {
      return null;
    }

    const agency: TransitAgency = {
      id: row.agency_id,
      name: row.agency_name,
      url: null,
      timezone: row.agency_timezone,
    };

    return {
      id: row.id,
      shortName: row.short_name ?? row.long_name ?? row.id,
      longName: row.long_name,
      agency,
      color: null,
      dataState: 'DEGRADED',
    };
  }
}
