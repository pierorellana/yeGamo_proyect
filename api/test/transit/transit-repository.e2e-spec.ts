import { PrismaService } from '../../src/shared/database/prisma.service';
import { PrismaTransitReadRepository } from '../../src/transit/infrastructure/prisma-transit.repository';

const describeDatabase = process.env.DATABASE_URL ? describe : describe.skip;

describeDatabase('Prisma transit catalog repository', () => {
  let prisma: PrismaService;
  let repository: PrismaTransitReadRepository;

  beforeAll(async () => {
    prisma = new PrismaService();
    repository = new PrismaTransitReadRepository(prisma);
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('returns active demo stops ordered by PostGIS distance', async () => {
    const stops = await repository.nearbyStops({
      lat: -2.155,
      lon: -79.895,
      radiusM: 3000,
    });

    expect(stops).toHaveLength(2);
    expect(stops[0]).toMatchObject({
      id: '00000000-0000-4000-8000-000000000003',
      name: 'Demo origin stop',
      dataState: 'DEGRADED',
      location: { lat: -2.17, lon: -79.9 },
    });
    expect(stops[0]?.distanceM).toBeGreaterThan(0);
    expect(stops[1]?.distanceM).toBeGreaterThan(stops[0]?.distanceM ?? -1);
  });

  it('does not return the farther demo stop outside a narrow radius', async () => {
    const stops = await repository.nearbyStops({
      lat: -2.17,
      lon: -79.9,
      radiusM: 50,
    });

    expect(stops.map((stop) => stop.id)).toEqual([
      '00000000-0000-4000-8000-000000000003',
    ]);
  });

  it('maps the demo route and agency without provider DTOs', async () => {
    await expect(
      repository.route('00000000-0000-4000-8000-000000000002'),
    ).resolves.toEqual({
      id: '00000000-0000-4000-8000-000000000002',
      shortName: 'D-01',
      longName: 'Demo route only',
      agency: {
        id: '00000000-0000-4000-8000-000000000001',
        name: 'yeGamo Demo Agency',
        url: null,
        timezone: 'America/Guayaquil',
      },
      color: null,
      dataState: 'DEGRADED',
    });
  });

  it('does not invent departures when no timetable is stored', async () => {
    await expect(
      repository.departures('00000000-0000-4000-8000-000000000003'),
    ).resolves.toEqual([]);
  });
});
