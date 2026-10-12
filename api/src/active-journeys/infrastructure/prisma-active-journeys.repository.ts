import { ConflictException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../../shared/database/prisma.service';
import type { ActiveJourneyRecord, ActiveJourneyRepository, JourneyEventRecord } from '../domain/active-journeys.ports';

@Injectable()
export class PrismaActiveJourneyRepository implements ActiveJourneyRepository {
  constructor(private readonly prisma: PrismaService) {}

  async optionBelongsToPlan(planId: string, optionId: string): Promise<boolean> {
    const option = await this.prisma.journeyOption.findFirst({ where: { id: optionId, planId } });
    return option !== null;
  }

  async create(userId: string, optionId: string): Promise<ActiveJourneyRecord> {
    try {
      const journey = await this.prisma.$transaction(async (tx) => {
        const created = await tx.activeJourney.create({ data: { userId, optionId, status: 'ACTIVE', currentLegSequence: 0, currentDataState: 'CURRENT', startedAt: new Date() } });
        await tx.journeyEvent.create({ data: { activeJourneyId: created.id, eventType: 'STARTED', legSequence: 0, source: 'USER', dataState: 'CURRENT', payload: {} } });
        return tx.activeJourney.findUniqueOrThrow({ where: { id: created.id }, include: { events: { orderBy: { occurredAt: 'asc' } } } });
      });
      return toActiveJourney(journey);
    } catch (error) {
      if (isUniqueViolation(error)) throw new ConflictException({ code: 'ACTIVE_JOURNEY_EXISTS', message: 'Ya existe un viaje activo para este usuario.', details: { resource: 'active-journey' } });
      throw error;
    }
  }

  async get(userId: string, id: string): Promise<ActiveJourneyRecord | null> {
    const journey = await this.prisma.activeJourney.findFirst({ where: { id, userId }, include: { events: { orderBy: { occurredAt: 'asc' } } } });
    return journey === null ? null : toActiveJourney(journey);
  }

  async progress(userId: string, id: string, currentLegIndex: number | undefined, payload: Record<string, unknown>, occurredAt: Date): Promise<ActiveJourneyRecord | null> {
    return this.prisma.$transaction(async (tx) => {
      const existing = await tx.activeJourney.findFirst({ where: { id, userId } });
      if (existing === null) return null;
      const updated = await tx.activeJourney.update({ where: { id }, data: { ...(currentLegIndex === undefined ? {} : { currentLegSequence: currentLegIndex }), updatedAt: new Date() } });
      await tx.journeyEvent.create({ data: { activeJourneyId: id, eventType: currentLegIndex === undefined ? 'ETA_UPDATED' : 'LEG_CHANGED', ...(currentLegIndex === undefined ? {} : { legSequence: currentLegIndex }), occurredAt, source: 'USER', dataState: updated.currentDataState, payload: JSON.parse(JSON.stringify(payload)) as Prisma.InputJsonValue } });
      return tx.activeJourney.findUniqueOrThrow({ where: { id }, include: { events: { orderBy: { occurredAt: 'asc' } } } });
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
      return tx.activeJourney.findUniqueOrThrow({ where: { id }, include: { events: { orderBy: { occurredAt: 'asc' } } } });
    }).then((journey) => journey === null ? null : toActiveJourney(journey));
  }
}

function toActiveJourney(item: { id: string; optionId: string; status: string; currentLegSequence: number | null; currentDataState: string; events: Array<{ id: string; eventType: string; occurredAt: Date; payload: unknown }> }): ActiveJourneyRecord {
  return {
    id: item.id,
    optionId: item.optionId,
    status: item.status as ActiveJourneyRecord['status'],
    currentLegIndex: item.currentLegSequence ?? 0,
    eta: null,
    dataState: item.currentDataState as ActiveJourneyRecord['dataState'],
    events: item.events.map((event): JourneyEventRecord => ({ id: event.id, type: event.eventType, occurredAt: event.occurredAt.toISOString(), details: isRecord(event.payload) ? event.payload : {} })),
  };
}

function isRecord(value: unknown): value is Record<string, unknown> { return typeof value === 'object' && value !== null && !Array.isArray(value); }
function isUniqueViolation(value: unknown): boolean { return typeof value === 'object' && value !== null && (value as { code?: unknown }).code === 'P2002'; }
