import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import type {
  DataQuality,
  JourneyLeg,
  JourneyOption,
  JourneyPlanRequest,
  Reliability,
  TransitPlan,
} from '../../provider-gateway/domain/provider.types';
import { PrismaService } from '../../shared/database/prisma.service';
import type { JourneyPlanRepository, SavePlanContext } from '../domain/journeys.ports';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type LegRow = {
  sequence: number;
  mode: string;
  routeId: string | null;
  fromStopId: string | null;
  toStopId: string | null;
  departureAt: Date | null;
  arrivalAt: Date | null;
  durationMin: number;
  instruction: string | null;
  metadata: Prisma.JsonValue;
};

/**
 * PostgreSQL implementation of the plan store. Plans, options and legs are
 * canonical rows (never raw provider DTOs) so an option can be started after the
 * API restarts. Expired plans are treated as absent.
 */
@Injectable()
export class PrismaJourneyPlanRepository implements JourneyPlanRepository {
  constructor(private readonly prisma: PrismaService) {}

  async save(plan: TransitPlan, request: JourneyPlanRequest, context: SavePlanContext): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      const requestedTime = request.time === undefined || request.time === null ? null : new Date(request.time);
      await tx.$executeRaw`
        INSERT INTO journey_plans (
          id, user_id, origin, destination, time_mode, requested_time, preference,
          max_walk_min, extra_safety_margin_min, status, data_state, recommended_leave_at,
          arrival_window_from, arrival_window_to, provider_summary, expires_at
        ) VALUES (
          ${plan.planId}::uuid, ${context.userId ?? null}::uuid,
          ST_SetSRID(ST_MakePoint(${request.origin.lon}, ${request.origin.lat}), 4326)::geography,
          ST_SetSRID(ST_MakePoint(${request.destination.lon}, ${request.destination.lat}), 4326)::geography,
          ${request.timeMode}, ${requestedTime}, ${request.preference ?? 'BALANCED'},
          ${request.maxWalkMin ?? 12}, ${request.extraSafetyMarginMin ?? 0}, 'READY', ${plan.dataState},
          ${plan.recommendedLeaveAt === null ? null : new Date(plan.recommendedLeaveAt)},
          ${plan.arrivalWindow === null ? null : new Date(plan.arrivalWindow.from)},
          ${plan.arrivalWindow === null ? null : new Date(plan.arrivalWindow.to)},
          ${JSON.stringify({ provider: context.providerKey })}::jsonb, ${context.expiresAt}
        )`;

      const legRefs = plan.options.flatMap((option) => option.legs.flatMap((leg) => [leg.routeId, leg.fromStopId, leg.toStopId]));
      const knownRoutes = await knownIds(tx, 'transit_routes', legRefs);
      const knownStops = await knownIds(tx, 'transit_stops', legRefs);

      for (const [index, option] of plan.options.entries()) {
        await tx.journeyOption.create({
          data: {
            id: option.id,
            planId: plan.planId,
            rank: index + 1,
            durationMin: option.durationMin,
            walkMin: option.walkMin,
            transfers: option.transfers,
            reliabilityScore: option.reliability.score,
            reliabilityLevel: option.reliability.level,
            sampleSize: option.reliability.sampleSize,
            provider: option.dataQuality.providerDisplayName,
            dataState: option.dataQuality.dataState,
            payload: json({ dataQuality: option.dataQuality, reliability: option.reliability }),
            legs: {
              create: option.legs.map((leg, sequence) => ({
                sequence,
                mode: leg.mode,
                routeId: leg.routeId !== null && knownRoutes.has(leg.routeId) ? leg.routeId : null,
                fromStopId: leg.fromStopId !== null && knownStops.has(leg.fromStopId) ? leg.fromStopId : null,
                toStopId: leg.toStopId !== null && knownStops.has(leg.toStopId) ? leg.toStopId : null,
                departureAt: leg.departureAt === null ? null : new Date(leg.departureAt),
                arrivalAt: leg.arrivalAt === null ? null : new Date(leg.arrivalAt),
                durationMin: leg.durationMin,
                instruction: leg.instructions.join('\n') || null,
                dataState: option.dataQuality.dataState,
                metadata: json({
                  from: leg.from,
                  to: leg.to,
                  instructions: leg.instructions,
                  routeId: leg.routeId,
                  fromStopId: leg.fromStopId,
                  toStopId: leg.toStopId,
                }),
              })),
            },
          },
        });
      }
    });
  }

  async get(planId: string): Promise<TransitPlan | null> {
    if (!UUID.test(planId)) return null;
    const plan = await this.prisma.journeyPlan.findFirst({
      where: { id: planId, OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }] },
      include: { options: { orderBy: { rank: 'asc' }, include: { legs: { orderBy: { sequence: 'asc' } } } } },
    });
    if (plan === null) return null;
    return {
      planId: plan.id,
      recommendedLeaveAt: plan.recommendedLeaveAt?.toISOString() ?? null,
      arrivalWindow:
        plan.arrivalWindowFrom !== null && plan.arrivalWindowTo !== null
          ? { from: plan.arrivalWindowFrom.toISOString(), to: plan.arrivalWindowTo.toISOString() }
          : null,
      dataState: plan.dataState as TransitPlan['dataState'],
      options: plan.options.map((option): JourneyOption => {
        const payload = record(option.payload);
        return {
          id: option.id,
          durationMin: option.durationMin,
          walkMin: option.walkMin,
          transfers: option.transfers,
          reliability: (payload.reliability as Reliability | undefined) ?? { score: null, level: null, sampleSize: null },
          dataQuality: payload.dataQuality as DataQuality,
          legs: option.legs.map(legFromRow),
        };
      }),
    };
  }
}

/** Shared by the active-journey repository so both read legs identically. */
export function legFromRow(row: LegRow): JourneyLeg {
  const meta = record(row.metadata);
  return {
    mode: row.mode as JourneyLeg['mode'],
    from: meta.from as JourneyLeg['from'],
    to: meta.to as JourneyLeg['to'],
    durationMin: row.durationMin,
    departureAt: row.departureAt?.toISOString() ?? null,
    arrivalAt: row.arrivalAt?.toISOString() ?? null,
    instructions: Array.isArray(meta.instructions) ? meta.instructions.filter((item): item is string => typeof item === 'string') : [],
    routeId: typeof meta.routeId === 'string' ? meta.routeId : null,
    fromStopId: typeof meta.fromStopId === 'string' ? meta.fromStopId : null,
    toStopId: typeof meta.toStopId === 'string' ? meta.toStopId : null,
  };
}

async function knownIds(tx: Prisma.TransactionClient, table: 'transit_routes' | 'transit_stops', refs: Array<string | null>): Promise<Set<string>> {
  const ids = [...new Set(refs.filter((ref): ref is string => ref !== null && UUID.test(ref)))];
  if (ids.length === 0) return new Set();
  const rows = table === 'transit_routes'
    ? await tx.transitRoute.findMany({ where: { id: { in: ids } }, select: { id: true } })
    : await tx.transitStop.findMany({ where: { id: { in: ids } }, select: { id: true } });
  return new Set(rows.map((row) => row.id));
}

function json(value: unknown): Prisma.InputJsonValue {
  return JSON.parse(JSON.stringify(value)) as Prisma.InputJsonValue;
}

function record(value: unknown): Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value) ? (value as Record<string, unknown>) : {};
}
