import type { INestApplication } from '@nestjs/common';
import { Test as NestTest } from '@nestjs/testing';
import request from 'supertest';

import { configureApp } from '../../src/app.bootstrap';
import { AppModule } from '../../src/app.module';
import {
  GEOCODING_PROVIDERS,
} from '../../src/provider-gateway/application/geocoding-gateway.service';
import type { GeocodingProvider } from '../../src/provider-gateway/domain/provider.ports';

const placeId = '550e8400-e29b-41d4-a716-446655440000';

async function createApp(providers?: GeocodingProvider[]): Promise<INestApplication> {
  let builder = NestTest.createTestingModule({ imports: [AppModule] });
  if (providers !== undefined) {
    builder = builder.overrideProvider(GEOCODING_PROVIDERS).useValue(providers);
  }

  const moduleRef = await builder.compile();
  const app = configureApp(moduleRef.createNestApplication());
  await app.init();
  return app;
}

describe('places HTTP API', () => {
  let app: INestApplication;

  beforeAll(async () => {
    app = await createApp([]);
  });

  afterAll(async () => {
    await app.close();
  });

  it('returns 422 for an invalid search query', async () => {
    await request(app.getHttpServer())
      .get('/v1/places/search')
      .query({ q: 'a' })
      .expect(422)
      .expect(({ body, headers }) => {
        expect(headers['x-trace-id']).toBe(body.traceId);
        expect(body).toMatchObject({
          code: 'VALIDATION_ERROR',
          details: { validationErrors: expect.any(Array) },
          traceId: expect.any(String),
        });
      });
  });

  it('returns 422 when only one optional search coordinate is supplied', async () => {
    await request(app.getHttpServer())
      .get('/v1/places/search')
      .query({ q: 'Centro', lat: '-2.17' })
      .expect(422);
  });

  it('propagates canonical 503 when geocoding is unavailable', async () => {
    await request(app.getHttpServer())
      .get('/v1/places/search')
      .set('X-Trace-Id', 'places-unavailable')
      .query({ q: 'Centro' })
      .expect(503)
      .expect(({ body, headers }) => {
        expect(headers['x-trace-id']).toBe('places-unavailable');
        expect(body).toEqual({
          code: 'PROVIDER_UNAVAILABLE',
          message: 'No geocoding provider is configured',
          details: {
            capability: 'geocoding',
            dataState: 'UNAVAILABLE',
            retryable: true,
          },
          traceId: 'places-unavailable',
        });
      });
  });

  it('validates reverse-geocoding coordinates', async () => {
    await request(app.getHttpServer())
      .get('/v1/places/reverse')
      .query({ lat: '91', lon: '-79.9' })
      .expect(422);
  });

  it('propagates the same canonical 503 for reverse geocoding', async () => {
    await request(app.getHttpServer())
      .get('/v1/places/reverse')
      .query({ lat: '-2.17', lon: '-79.9' })
      .expect(503)
      .expect(({ body }) => {
        expect(body).toMatchObject({
          code: 'PROVIDER_UNAVAILABLE',
          details: { capability: 'geocoding', dataState: 'UNAVAILABLE' },
        });
      });
  });
});

describe('places canonical success mapping', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const provider: GeocodingProvider = {
      providerKey: 'authorized-geocoder',
      isDemo: false,
      search: async () => ({
        providerKey: 'authorized-geocoder',
        isDemo: false,
        sourceAuthorized: true,
        observedAt: '2026-10-12T12:00:00.000Z',
        data: [
          {
            id: placeId,
            label: 'Centro de Guayaquil',
            location: { lat: -2.17, lon: -79.9 },
          },
        ],
      }),
      reverse: async () => ({
        providerKey: 'authorized-geocoder',
        isDemo: false,
        sourceAuthorized: true,
        observedAt: '2026-10-12T12:00:00.000Z',
        data: {
          id: placeId,
          label: 'Centro de Guayaquil',
          location: { lat: -2.17, lon: -79.9 },
        },
      }),
    };
    app = await createApp([provider]);
  });

  afterAll(async () => {
    await app.close();
  });

  it('returns the canonical Place shape without provider DTO fields', async () => {
    await request(app.getHttpServer())
      .get('/v1/places/search')
      .query({ q: 'Centro', lat: '-2.17', lon: '-79.9' })
      .expect(200)
      .expect(({ body }) => {
        expect(body).toEqual([
          {
            id: placeId,
            label: 'Centro de Guayaquil',
            location: { lat: -2.17, lon: -79.9 },
            source: 'authorized-geocoder',
          },
        ]);
        expect(body[0]).not.toHaveProperty('providerKey');
      });
  });
});
