import { randomUUID } from 'node:crypto';

import { Test as NestTest } from '@nestjs/testing';

import { AlertsService } from '../../src/alerts/application/alerts.service';
import { AppModule } from '../../src/app.module';
import { PrismaJourneyPlanRepository } from '../../src/journeys/infrastructure/prisma-journey-plans.repository';
import { PrismaUserRepository } from '../../src/identity/infrastructure/prisma-user.repository';
import { PrismaService } from '../../src/shared/database/prisma.service';
import { WorkerScheduler } from '../../src/worker/application/worker.scheduler';
import { WorkerService } from '../../src/worker/application/worker.service';
import type { JourneyPlanRequest, TransitPlan } from '../../src/provider-gateway/domain/provider.types';

const describeDatabase = process.env.DATABASE_URL ? describe : describe.skip;

describeDatabase('leave alerts: schedule, dedupe, fire once (PostgreSQL)', () => {
  let prisma: PrismaService;
  let alerts: AlertsService;
  let worker: WorkerService;
  let scheduler: WorkerScheduler;
  let userId: string;
  let planId: string;
  const closeApp: Array<() => Promise<void>> = [];

  const request: JourneyPlanRequest = { origin: { lat: -2.17, lon: -79.9 }, destination: { lat: -2.14, lon: -79.89 }, timeMode: 'LEAVE_NOW' };
  const minutes = (n: number) => new Date(Date.now() + n * 60_000);

  beforeAll(async () => {
    const moduleRef = await NestTest.createTestingModule({ imports: [AppModule] }).compile();
    const app = moduleRef.createNestApplication();
    await app.init();
    closeApp.push(() => app.close());
    prisma = app.get(PrismaService);
    alerts = app.get(AlertsService);
    worker = app.get(WorkerService);
    scheduler = app.get(WorkerScheduler);
    userId = (await new PrismaUserRepository(prisma).upsertPrincipal({ issuer: 'test', subject: randomUUID(), email: null, displayName: null, scopes: [] })).id;

    const plan: TransitPlan = { planId: randomUUID(), recommendedLeaveAt: null, arrivalWindow: null, dataState: 'DEGRADED', options: [] };
    await new PrismaJourneyPlanRepository(prisma).save(plan, request, { providerKey: 'test', expiresAt: minutes(60) });
    planId = plan.planId;
  });

  afterAll(async () => {
    await prisma.user.delete({ where: { id: userId } });
    await prisma.journeyPlan.delete({ where: { id: planId } });
    for (const close of closeApp) await close();
  });

  it('accepts alerts for an anonymous plan, rejects past times and duplicates', async () => {
    await expect(alerts.create(userId, { journeyPlanId: planId, scheduledFor: minutes(-5).toISOString() }, 'alert-past-001')).rejects.toMatchObject({ status: 422 });
    await expect(alerts.create(userId, { journeyPlanId: planId, scheduledFor: minutes(60 * 24 * 8).toISOString() }, 'alert-far-0001')).rejects.toMatchObject({ status: 422 });

    const when = minutes(10).toISOString();
    const created = await alerts.create(userId, { journeyPlanId: planId, scheduledFor: when }, 'alert-main-001');
    expect(created).toMatchObject({ status: 'SCHEDULED' });
    // Same idempotency key replays; a different key for the same plan conflicts.
    await expect(alerts.create(userId, { journeyPlanId: planId, scheduledFor: when }, 'alert-main-001')).resolves.toMatchObject({ id: created.id });
    await expect(alerts.create(userId, { journeyPlanId: planId, scheduledFor: minutes(20).toISOString() }, 'alert-main-002')).rejects.toMatchObject({ status: 409 });
  });

  it('fires once even when two workers race, and a cancelled alert never fires', async () => {
    const pending = (await prisma.leaveAlert.findMany({ where: { userId, status: 'SCHEDULED' } }))[0]!;
    const due = new Date(pending.scheduledFor.getTime() + 60_000);

    const [a, b] = await Promise.all([worker.runAlerts(due, true), worker.runAlerts(due, true)]);
    expect(a.processed + b.processed).toBe(1);
    expect(await prisma.notification.count({ where: { userId, type: 'LEAVE_ALERT' } })).toBe(1);
    expect((await worker.runAlerts(due, true)).processed).toBe(0);

    const second = await alerts.create(userId, { journeyPlanId: planId, scheduledFor: minutes(30).toISOString() }, 'alert-cancel-01');
    await alerts.delete(userId, second.id);
    const later = await worker.runAlerts(minutes(60), true);
    expect(later.processed).toBe(0);
    expect((await prisma.leaveAlert.findUniqueOrThrow({ where: { id: second.id } })).status).toBe('CANCELLED');
  });

  it('expires a stale alert instead of announcing a moment that already passed', async () => {
    const stale = await prisma.leaveAlert.create({ data: { userId, journeyPlanId: planId, scheduledFor: minutes(-120), idempotencyKey: 'stale-0001' } });
    const result = await worker.runAlerts(new Date(), true);
    expect(result.processed).toBe(0);
    expect((await prisma.leaveAlert.findUniqueOrThrow({ where: { id: stale.id } })).status).toBe('EXPIRED');
  });

  it('scheduler tick does not overlap itself', async () => {
    let calls = 0;
    const slow = { name: 'overlap', everyMs: 1000, run: async () => { calls += 1; await new Promise((resolve) => setTimeout(resolve, 150)); } };
    const results = await Promise.all([scheduler.tick(slow), scheduler.tick(slow)]);
    expect(results.filter(Boolean)).toHaveLength(1);
    expect(calls).toBe(1);
  });
});
