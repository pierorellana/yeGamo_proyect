import { randomUUID } from 'node:crypto';

import { IdentityOperationsService } from '../../src/identity/application/identity-operations.service';
import { PrismaUserRepository } from '../../src/identity/infrastructure/prisma-user.repository';
import { PrismaService } from '../../src/shared/database/prisma.service';
import { IdempotencyService, InMemoryIdempotencyStore } from '../../src/shared/idempotency/idempotency.service';

const describeDatabase = process.env.DATABASE_URL ? describe : describe.skip;

describeDatabase('guest → account migration (PostgreSQL)', () => {
  let prisma: PrismaService;
  let service: IdentityOperationsService;
  let principal: { issuer: string; subject: string; email: null; displayName: null; scopes: string[]; userId: string };

  const home = { type: 'FAVORITE_PLACE', label: 'Casa', location: { lat: -2.17, lon: -79.9 } };
  const work = { type: 'COMMUTE_PROFILE', name: 'Trabajo', origin: { lat: -2.17, lon: -79.9 }, destination: { lat: -2.14, lon: -79.89 }, weekdays: [1, 2, 3, 4, 5], targetArrival: '08:30' };

  beforeAll(async () => {
    prisma = new PrismaService();
    const user = await new PrismaUserRepository(prisma).upsertPrincipal({ issuer: 'test', subject: randomUUID(), email: null, displayName: null, scopes: [] });
    principal = { issuer: 'test', subject: 's', email: null, displayName: null, scopes: [], userId: user.id };
    service = new IdentityOperationsService(prisma, new IdempotencyService(new InMemoryIdempotencyStore()));
  });

  afterAll(async () => {
    await prisma.user.delete({ where: { id: principal.userId } });
    await prisma.$disconnect();
  });

  it('imports valid items, rejects invalid ones with a reason and reports duplicates', async () => {
    const result = await service.migrateGuest(principal, {
      clientDataVersion: '1',
      items: [
        home,
        work,
        { type: 'FAVORITE_PLACE', label: 'Sin ubicación' },
        { type: 'FAVORITE_PLACE', label: 'Fuera de rango', location: { lat: 95, lon: 0 } },
        { type: 'COMMUTE_PROFILE', name: 'Sin días', origin: home.location, destination: home.location, weekdays: [], targetArrival: '08:30' },
        { type: 'RECENT_SEARCH', query: 'x' },
        { ...home, label: 'casa' },
      ],
    }, 'migration-key-0001');

    expect(result).toMatchObject({ importedCount: 2, skippedCount: 1, rejectedCount: 4, idempotentReplay: false });
    const byIndex = Object.fromEntries((result.results as Array<{ index: number; status: string; reason: string | null }>).map((r) => [r.index, r]));
    expect(byIndex[2]).toMatchObject({ status: 'REJECTED', reason: 'INVALID_COORDINATES' });
    expect(byIndex[3]).toMatchObject({ status: 'REJECTED', reason: 'INVALID_COORDINATES' });
    expect(byIndex[4]).toMatchObject({ status: 'REJECTED', reason: 'INVALID_FIELD' });
    expect(byIndex[5]).toMatchObject({ status: 'REJECTED', reason: 'UNSUPPORTED_TYPE' });
    expect(byIndex[6]).toMatchObject({ status: 'DUPLICATE', reason: 'ALREADY_EXISTS' });

    expect(await prisma.savedPlace.count({ where: { userId: principal.userId } })).toBe(1);
    expect(await prisma.commuteProfile.count({ where: { userId: principal.userId } })).toBe(1);
  });

  it('does not duplicate data when the same package is retried, even with a new key', async () => {
    const payload = { clientDataVersion: '1', items: [home, work] };
    const retry = await service.migrateGuest(principal, payload, 'migration-key-0002');
    expect(retry).toMatchObject({ idempotentReplay: false, importedCount: 0, skippedCount: 2, rejectedCount: 0 });
    const replay = await service.migrateGuest(principal, payload, 'migration-key-0003');
    expect(replay).toMatchObject({ idempotentReplay: true, skippedCount: 2 });
    expect(await prisma.savedPlace.count({ where: { userId: principal.userId } })).toBe(1);
    expect(await prisma.commuteProfile.count({ where: { userId: principal.userId } })).toBe(1);
  });

  it('rejects an unsupported client data version and oversized packages', async () => {
    await expect(service.migrateGuest(principal, { clientDataVersion: '99', items: [] }, 'migration-key-0004')).rejects.toMatchObject({ status: 422 });
    await expect(service.migrateGuest(principal, { clientDataVersion: '1', items: Array.from({ length: 201 }, () => home) }, 'migration-key-0005')).rejects.toMatchObject({ status: 422 });
  });
});
