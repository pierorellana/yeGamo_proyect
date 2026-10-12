import type { INestApplication } from '@nestjs/common';
import { Test as NestTest } from '@nestjs/testing';
import request from 'supertest';

import { configureApp } from '../../src/app.bootstrap';
import { AppModule } from '../../src/app.module';
import {
  TRANSIT_READ_PORT,
  TransitReadPort,
} from '../../src/transit/domain/transit.ports';

async function createApp(port?: TransitReadPort): Promise<INestApplication> {
  let builder = NestTest.createTestingModule({ imports: [AppModule] });
  if (port !== undefined) {
    builder = builder.overrideProvider(TRANSIT_READ_PORT).useValue(port);
  }

  const moduleRef = await builder.compile();
  const app = configureApp(moduleRef.createNestApplication());
  await app.init();
  return app;
}

describe('transit HTTP API', () => {
  let app: INestApplication;

  beforeAll(async () => {
    app = await createApp();
  });

  afterAll(async () => {
    await app.close();
  });

  it('returns 422 for invalid nearby coordinates and radius', async () => {
    await request(app.getHttpServer())
      .get('/v1/transit/stops/nearby')
      .query({ lat: '91', lon: '-79.9', radiusM: '20' })
      .expect(422);
  });

  it('propagates canonical 503 when transit is unavailable', async () => {
    await request(app.getHttpServer())
      .get('/v1/transit/stops/nearby')
      .set('X-Trace-Id', 'transit-unavailable')
      .query({ lat: '-2.17', lon: '-79.9' })
      .expect(503)
      .expect(({ body, headers }) => {
        expect(headers['x-trace-id']).toBe('transit-unavailable');
        expect(body).toMatchObject({
          code: 'PROVIDER_UNAVAILABLE',
          details: {
            capability: 'transit',
            dataState: 'UNAVAILABLE',
            retryable: true,
          },
          traceId: 'transit-unavailable',
        });
      });
  });

  it('validates stop and route UUID path parameters', async () => {
    await request(app.getHttpServer())
      .get('/v1/transit/stops/not-a-uuid/departures')
      .expect(422);

    await request(app.getHttpServer())
      .get('/v1/transit/routes/not-a-uuid')
      .expect(422);
  });

  it('propagates canonical 503 for departures and routes without a provider', async () => {
    await request(app.getHttpServer())
      .get('/v1/transit/stops/550e8400-e29b-41d4-a716-446655440001/departures')
      .expect(503)
      .expect(({ body }) => {
        expect(body).toMatchObject({
          code: 'PROVIDER_UNAVAILABLE',
          details: { capability: 'transit', dataState: 'UNAVAILABLE' },
        });
      });

    await request(app.getHttpServer())
      .get('/v1/transit/routes/550e8400-e29b-41d4-a716-446655440002')
      .expect(503);
  });
});

describe('transit canonical success and 404 mapping', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const port: TransitReadPort = {
      nearbyStops: async () => [
        {
          id: '550e8400-e29b-41d4-a716-446655440001',
          name: 'Parada Centro',
          location: { lat: -2.17, lon: -79.9 },
          distanceM: 420,
          dataState: 'CURRENT',
        },
      ],
      departures: async () => [],
      route: async () => null,
    };
    app = await createApp(port);
  });

  afterAll(async () => {
    await app.close();
  });

  it('returns canonical nearby stops', async () => {
    await request(app.getHttpServer())
      .get('/v1/transit/stops/nearby')
      .query({ lat: '-2.17', lon: '-79.9', radiusM: '800' })
      .expect(200)
      .expect(({ body }) => {
        expect(body).toEqual([
          {
            id: '550e8400-e29b-41d4-a716-446655440001',
            name: 'Parada Centro',
            location: { lat: -2.17, lon: -79.9 },
            distanceM: 420,
            dataState: 'CURRENT',
          },
        ]);
      });
  });

  it('maps an unknown route to canonical 404', async () => {
    await request(app.getHttpServer())
      .get('/v1/transit/routes/550e8400-e29b-41d4-a716-446655440002')
      .expect(404)
      .expect(({ body }) => {
        expect(body).toMatchObject({
          code: 'NOT_FOUND',
          details: { resource: 'transit-route' },
          traceId: expect.any(String),
        });
      });
  });
});
