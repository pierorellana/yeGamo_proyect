import { randomUUID } from 'node:crypto';

import { PrismaUserRepository } from '../../src/identity/infrastructure/prisma-user.repository';
import { PrismaService } from '../../src/shared/database/prisma.service';

const describeDatabase = process.env.DATABASE_URL ? describe : describe.skip;

describeDatabase('PostgreSQL user preferences', () => {
  let prisma: PrismaService;
  let repository: PrismaUserRepository;
  let userId: string;

  beforeAll(async () => {
    prisma = new PrismaService();
    repository = new PrismaUserRepository(prisma);
    userId = (await repository.upsertPrincipal({ issuer: 'test', subject: randomUUID(), email: null, displayName: null, scopes: [] })).id;
  });

  afterAll(async () => {
    await prisma.user.delete({ where: { id: userId } });
    await prisma.$disconnect();
  });

  it.each(['LESS_WALKING', 'FEWER_TRANSFERS', 'RELIABLE', 'FASTEST', 'BALANCED'])('stores the API preference %s', async (value) => {
    const saved = await repository.updatePreferences(userId, { defaultPreference: value, maxWalkMin: 20, extraSafetyMarginMin: 5, locationConsent: true });
    expect(saved).toMatchObject({ defaultPreference: value, maxWalkMin: 20, extraSafetyMarginMin: 5, locationConsent: true });
    await expect(repository.hasLocationConsent(userId)).resolves.toBe(true);
  });
});
