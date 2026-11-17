import { randomUUID } from 'node:crypto';

import { ActiveJourneysService } from '../../src/active-journeys/application/active-journeys.service';
import { PrismaActiveJourneyRepository } from '../../src/active-journeys/infrastructure/prisma-active-journeys.repository';
import { PrismaJourneyPlanRepository } from '../../src/journeys/infrastructure/prisma-journey-plans.repository';
import type { JourneyPlanRequest, TransitPlan } from '../../src/provider-gateway/domain/provider.types';
import { PrismaService } from '../../src/shared/database/prisma.service';
import { IdempotencyService, InMemoryIdempotencyStore } from '../../src/shared/idempotency/idempotency.service';

const describeDatabase = process.env.DATABASE_URL ? describe : describe.skip;

const request: JourneyPlanRequest = {
  origin: { lat: -2.17, lon: -79.9 },
  destination: { lat: -2.14, lon: -79.89 },
  timeMode: 'LEAVE_NOW',
  preference: 'FEWER_TRANSFERS',
  maxWalkMin: 12,
  extraSafetyMarginMin: 0,
};

function plan(): TransitPlan {
  const quality = {
    freshness: 'UNKNOWN' as const,
    dataState: 'DEGRADED' as const,
    liveVehicle: false,
    observedAt: null,
    providerDisplayName: null,
    sourceAuthorized: false,
  };
  const leg = (mode: 'WALK' | 'TRANSIT', routeId: string | null) => ({
    mode,
    from: request.origin,
    to: request.destination,
    durationMin: 5,
    departureAt: null,
    arrivalAt: null,
    instructions: [`Instrucción ${mode}`, 'Segunda línea'],
    routeId,
    fromStopId: null,
    toStopId: null,
  });
  return {
    planId: randomUUID(),
    recommendedLeaveAt: '2026-11-17T12:00:00.000Z',
    arrivalWindow: { from: '2026-11-17T12:40:00.000Z', to: '2026-11-17T12:50:00.000Z' },
    dataState: 'DEGRADED',
    options: [
      {
        id: randomUUID(),
        durationMin: 45,
        walkMin: 10,
        transfers: 1,
        reliability: { score: null, level: null, sampleSize: null },
        dataQuality: quality,
        // A route id that is not in the catalog must survive in metadata, not as a dangling FK.
        legs: [leg('WALK', null), leg('TRANSIT', 'osm-relation-123')],
      },
    ],
  };
}

describeDatabase('PostgreSQL journey plan persistence', () => {
  let prisma: PrismaService;
  let userId: string;

  beforeAll(async () => {
    prisma = new PrismaService();
    const user = await prisma.user.create({ data: { issuer: 'test', subject: randomUUID() } });
    userId = user.id;
  });

  afterAll(async () => {
    await prisma.user.delete({ where: { id: userId } });
    await prisma.$disconnect();
  });

  it('survives a client restart and starts a journey from the persisted option', async () => {
    const original = plan();
    await new PrismaJourneyPlanRepository(prisma).save(original, request, {
      providerKey: 'test',
      expiresAt: new Date(Date.now() + 60_000),
    });

    // "Restart": brand-new connection and repositories, nothing shared in memory.
    const restarted = new PrismaService();
    try {
      const stored = await new PrismaJourneyPlanRepository(restarted).get(original.planId);
      expect(stored).toEqual(original);
      expect(stored?.options[0]?.legs[1]?.routeId).toBe('osm-relation-123');

      const service = new ActiveJourneysService(
        new PrismaActiveJourneyRepository(restarted),
        { hasLocationConsent: async () => false } as never,
        new IdempotencyService(new InMemoryIdempotencyStore()),
      );
      const optionId = original.options[0]!.id;
      const journey = await service.start(userId, original.planId, optionId, 'persist-1');

      expect(journey).toMatchObject({
        planId: original.planId,
        optionId,
        status: 'ACTIVE',
        currentLegIndex: 0,
        eta: null,
        // Never upgraded to CURRENT: the journey inherits the option's honesty level.
        dataState: 'DEGRADED',
        dataQuality: { sourceAuthorized: false, liveVehicle: false },
      });
      expect(journey.legs).toHaveLength(2);
      expect(journey.legs[0]?.instructions).toEqual(['Instrucción WALK', 'Segunda línea']);

      const moved = await service.progress(userId, journey.id, { currentLegIndex: 1 }, 'persist-progress-1');
      expect(moved.currentLegIndex).toBe(1);
      await expect(service.progress(userId, journey.id, { currentLegIndex: 2 }, 'persist-progress-2')).rejects.toMatchObject({ status: 422 });

      const finished = await service.finish(userId, journey.id, 'persist-finish-1');
      expect(finished.status).toBe('COMPLETED');
    } finally {
      await restarted.$disconnect();
    }
  });

  it('does not return or start from an expired plan', async () => {
    const expired = plan();
    const repository = new PrismaJourneyPlanRepository(prisma);
    await repository.save(expired, request, { providerKey: 'test', expiresAt: new Date(Date.now() - 1_000) });

    await expect(repository.get(expired.planId)).resolves.toBeNull();
    await expect(new PrismaActiveJourneyRepository(prisma).optionBelongsToPlan(expired.planId, expired.options[0]!.id)).resolves.toBe(false);
  });
});
