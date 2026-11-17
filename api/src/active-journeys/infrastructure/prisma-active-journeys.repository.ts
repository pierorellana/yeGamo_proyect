import { ConflictException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../../shared/database/prisma.service';
import { legFromRow } from '../../journeys/infrastructure/prisma-journey-plans.repository';
import type { DataQuality } from '../../provider-gateway/domain/provider.types';
import type { ActiveJourneyRecord, ActiveJourneyRepository, JourneyEventRecord } from '../domain/active-journeys.ports';

@Injectable()
export class PrismaActiveJourneyRepository implements ActiveJourneyRepository {
  constructor(private readonly prisma: PrismaService) {}

  async optionBelongsToPlan(planId: string, optionId: string): Promise<boolean> {
    const option = await this.prisma.journeyOption.findFirst({ where: { id: optionId, planId, plan: { OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }] } } });
    return option !== null;
  }

  async create(userId: string, optionId: string): Promise<ActiveJourneyRecord> {
    try {
      const journey = await this.prisma.$transaction(async (tx) => {
        // The journey inherits the honesty level of the option it started from.
        const option = await tx.journeyOption.findUniqueOrThrow({ where: { id: optionId }, select: { dataState: true } });
        const created = await tx.activeJourney.create({ data: { userId, optionId, status: 'ACTIVE', currentLegSequence: 0, currentDataState: option.dataState, startedAt: new Date() } });
        await tx.journeyEvent.create({ data: { activeJourneyId: created.id, eventType: 'STARTED', legSequence: 0, source: 'USER', dataState: option.dataState, payload: {} } });
        return tx.activeJourney.findUniqueOrThrow({ where: { id: created.id }, include: JOURNEY_INCLUDE });
      });
      return toActiveJourney(journey);
    } catch (error) {
      if (isUniqueViolation(error)) throw new ConflictException({ code: 'ACTIVE_JOURNEY_EXISTS', message: 'Ya existe un viaje activo para este usuario.', details: { resource: 'active-journey' } });
      throw error;
    }
  }

  async get(userId: string, id: string): Promise<ActiveJourneyRecord | null> {
    const journey = await this.prisma.activeJourney.findFirst({ where: { id, userId }, include: JOURNEY_INCLUDE });
    return journey === null ? null : toActiveJourney(journey);
  }

  async progress(userId: string, id: string, currentLegIndex: number | undefined, payload: Record<string, unknown>, occurredAt: Date): Promise<ActiveJourneyRecord | null> {
    return this.prisma.$transaction(async (tx) => {
      const existing = await tx.activeJourney.findFirst({ where: { id, userId } });
      if (existing === null) return null;
      const updated = await tx.activeJourney.update({ where: { id }, data: { ...(currentLegIndex === undefined ? {} : { currentLegSequence: currentLegIndex }), updatedAt: new Date() } });
      await tx.journeyEvent.create({ data: { activeJourneyId: id, eventType: currentLegIndex === undefined ? 'ETA_UPDATED' : 'LEG_CHANGED', ...(currentLegIndex === undefined ? {} : { legSequence: currentLegIndex }), occurredAt, source: 'USER', dataState: updated.currentDataState, payload: JSON.parse(JSON.stringify(payload)) as Prisma.InputJsonValue } });
      return tx.activeJourney.findUniqueOrThrow({ where: { id }, include: JOURNEY_INCLUDE });
    }).then((journey) => journey === null ? null : toActiveJourney(journey));
  }

  async finish(userId: string, id: string, occurredAt: Date): Promise<ActiveJourneyRecord | null> { return this.transition(userId, id, 'COMPLETED', 'FINISHED', occurredAt); }
  async cancel(userId: string, id: string, occurredAt: Date): Promise<ActiveJourneyRecord | null> { return this.transition(userId, id, 'CANCELLED', 'CANCELLED', occurredAt); }

  private async transition(userId: string, id: string, status: 'COMPLETED' | 'CANCELLED', eventType: 'FINISHED' | 'CANCELLED', occurredAt: Date): Promise<ActiveJourneyRecord | null> {
    return this.prisma.$transaction(async (tx) => {
      const existing = await tx.activeJourney.findFirst({ where: { id, userId } });
      if (existing === null) return null;
      const updated = await tx.activeJourney.update({ where: { id }, data: { status, finishedAt: occurredAt, actualArrivalAt: status === 'COMPLETED' ? occurredAt : null, updatedAt: new Date() } });
      await tx.journeyEvent.create({ data: { activeJourneyId: id, eventType, legSequence: updated.currentLegSequence, occurredAt, source: 'USER', dataState: updated.currentDataState, payload: {} } });
      return tx.activeJourney.findUniqueOrThrow({ where: { id }, include: JOURNEY_INCLUDE });
    }).then((journey) => journey === null ? null : toActiveJourney(journey));
  }
}

const JOURNEY_INCLUDE = {
  events: { orderBy: { occurredAt: 'asc' } },
  option: { include: { legs: { orderBy: { sequence: 'asc' } } } },
} satisfies Prisma.ActiveJourneyInclude;

type JourneyRow = Prisma.ActiveJourneyGetPayload<{ include: typeof JOURNEY_INCLUDE }>;

function toActiveJourney(item: JourneyRow): ActiveJourneyRecord {
  const payload = isRecord(item.option.payload) ? item.option.payload : {};
  return {
    id: item.id,
    planId: item.option.planId,
    optionId: item.optionId,
    legs: item.option.legs.map(legFromRow),
    dataQuality: isRecord(payload.dataQuality) ? (payload.dataQuality as unknown as DataQuality) : null,
    status: item.status as ActiveJourneyRecord['status'],
    currentLegIndex: item.currentLegSequence ?? 0,
    eta: null,
    dataState: item.currentDataState as ActiveJourneyRecord['dataState'],
    events: item.events.map((event): JourneyEventRecord => ({ id: event.id, type: event.eventType, occurredAt: event.occurredAt.toISOString(), details: isRecord(event.payload) ? event.payload : {} })),
  };
}

function isRecord(value: unknown): value is Record<string, unknown> { return typeof value === 'object' && value !== null && !Array.isArray(value); }
function isUniqueViolation(value: unknown): boolean { return typeof value === 'object' && value !== null && (value as { code?: unknown }).code === 'P2002'; }
