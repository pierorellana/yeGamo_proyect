import type { INestApplication } from '@nestjs/common';
import { Test as NestTest } from '@nestjs/testing';
import request from 'supertest';

import { configureApp } from '../../src/app.bootstrap';
import { AppModule } from '../../src/app.module';
import type {
  JourneyOption,
  TransitPlan,
} from '../../src/provider-gateway/domain/provider.types';
import {
  JOURNEY_TRANSIT_PORT,
  JourneyTransitPort,
} from '../../src/journeys/domain/journeys.ports';

const origin = { lat: -2.17, lon: -79.9 };
const destination = { lat: -2.14, lon: -79.89 };

async function createApp(port?: JourneyTransitPort): Promise<INestApplication> {
  let builder = NestTest.createTestingModule({ imports: [AppModule] });
  if (port !== undefined) {
    builder = builder.overrideProvider(JOURNEY_TRANSIT_PORT).useValue(port);
  }

  const moduleRef = await builder.compile();
  const app = configureApp(moduleRef.createNestApplication());
  await app.init();
  return app;
}

describe('journeys HTTP API', () => {
  let app: INestApplication;

  beforeAll(async () => {
    app = await createApp();
  });

  afterAll(async () => {
    await app.close();
  });

  it('returns 422 when a scheduled plan omits its required time', async () => {
    await request(app.getHttpServer())
      .post('/v1/journeys/plan')
      .send({ origin, destination, timeMode: 'ARRIVE_BY' })
      .expect(422)
      .expect(({ body }) => {
        expect(body).toMatchObject({
          code: 'VALIDATION_ERROR',
          details: { validationErrors: expect.any(Array) },
        });
      });
  });

  it('returns 422 for an invalid scheduled time', async () => {
    await request(app.getHttpServer())
      .post('/v1/journeys/plan')
      .send({
        origin,
        destination,
        timeMode: 'DEPART_AT',
        time: 'not-a-date',
      })
      .expect(422);
  });

  it('rejects unknown request fields through the whitelist contract', async () => {
    await request(app.getHttpServer())
      .post('/v1/journeys/plan')
      .send({
        origin,
        destination,
        timeMode: 'LEAVE_NOW',
        unexpected: true,
      })
      .expect(422);
  });

  it('propagates canonical 503 when journey planning has no transit provider', async () => {
    await request(app.getHttpServer())
      .post('/v1/journeys/plan')
      .set('X-Trace-Id', 'journey-unavailable')
      .send({ origin, destination, timeMode: 'LEAVE_NOW' })
      .expect(503)
      .expect(({ body, headers }) => {
        expect(headers['x-trace-id']).toBe('journey-unavailable');
        expect(body).toMatchObject({
          code: 'PROVIDER_UNAVAILABLE',
          details: {
            capability: 'transit',
            dataState: 'UNAVAILABLE',
            retryable: true,
          },
          traceId: 'journey-unavailable',
        });
      });
  });

  it('returns 404 for an unknown UUID plan', async () => {
    await request(app.getHttpServer())
      .get('/v1/journeys/550e8400-e29b-41d4-a716-446655440099')
      .expect(404)
      .expect(({ body }) => {
        expect(body).toMatchObject({
          code: 'NOT_FOUND',
          details: { resource: 'journey-plan' },
        });
      });
  });
});

describe('journeys canonical planning and repository boundary', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const port: JourneyTransitPort = {
      plan: async () => canonicalPlan(),
    };
    app = await createApp(port);
  });

  afterAll(async () => {
    await app.close();
  });

  it('orders canonical options by preference and retrieves the stored plan', async () => {
    const response = await request(app.getHttpServer())
      .post('/v1/journeys/plan')
      .send({
        origin,
        destination,
        timeMode: 'LEAVE_NOW',
        preference: 'FASTEST',
      })
      .expect(200);

    expect(response.body.options.map((option: JourneyOption) => option.id)).toEqual([
      '550e8400-e29b-41d4-a716-446655440011',
      '550e8400-e29b-41d4-a716-446655440010',
    ]);

    await request(app.getHttpServer())
      .get(`/v1/journeys/${response.body.planId}`)
      .expect(200)
      .expect(({ body }) => {
        expect(body).toEqual(response.body);
        expect(body).not.toHaveProperty('providerKey');
      });
  });
});

function canonicalPlan(): TransitPlan {
  return {
    planId: '550e8400-e29b-41d4-a716-446655440009',
    recommendedLeaveAt: null,
    arrivalWindow: null,
    dataState: 'DEGRADED',
    options: [
      canonicalOption('550e8400-e29b-41d4-a716-446655440010', 50, 5),
      canonicalOption('550e8400-e29b-41d4-a716-446655440011', 20, 10),
    ],
  };
}

function canonicalOption(id: string, durationMin: number, walkMin: number): JourneyOption {
  return {
    id,
    durationMin,
    walkMin,
    transfers: 0,
    reliability: { score: null, level: null, sampleSize: null },
    dataQuality: {
      freshness: 'UNKNOWN',
      dataState: 'DEGRADED',
      liveVehicle: false,
      observedAt: null,
      providerDisplayName: null,
      sourceAuthorized: false,
    },
    legs: [
      {
        mode: 'WALK',
        from: origin,
        to: destination,
        durationMin: walkMin,
        departureAt: null,
        arrivalAt: null,
        instructions: ['Sigue las indicaciones canónicas.'],
        routeId: null,
        fromStopId: null,
        toStopId: null,
      },
    ],
  };
}
