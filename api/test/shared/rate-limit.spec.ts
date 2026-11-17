import type { INestApplication } from '@nestjs/common';
import { Test as NestTest } from '@nestjs/testing';
import request from 'supertest';

import { configureApp } from '../../src/app.bootstrap';
import { AppModule } from '../../src/app.module';

describe('rate limiting and security headers', () => {
  let app: INestApplication;

  beforeAll(async () => {
    process.env.RATE_LIMIT_PER_MINUTE = '3';
    process.env.RATE_LIMIT_PLAN_PER_MINUTE = '2';
    const moduleRef = await NestTest.createTestingModule({ imports: [AppModule] }).compile();
    app = configureApp(moduleRef.createNestApplication());
    await app.init();
  });

  afterAll(async () => {
    delete process.env.RATE_LIMIT_PER_MINUTE;
    delete process.env.RATE_LIMIT_PLAN_PER_MINUTE;
    await app.close();
  });

  it('answers 429 in the canonical shape with Retry-After once the budget is spent', async () => {
    const body = { origin: { lat: -2.17, lon: -79.9 }, destination: { lat: -2.14, lon: -79.89 }, timeMode: 'LEAVE_NOW' };
    for (let i = 0; i < 2; i += 1) await request(app.getHttpServer()).post('/v1/journeys/plan').send(body);
    const limited = await request(app.getHttpServer()).post('/v1/journeys/plan').send(body).expect(429);
    expect(limited.body).toMatchObject({ code: 'RATE_LIMITED', traceId: expect.any(String) });
    expect(Number(limited.headers['retry-after'])).toBeGreaterThan(0);
    expect(limited.headers['x-ratelimit-remaining']).toBe('0');
  });

  it('sends security headers and exempts health checks', async () => {
    for (let i = 0; i < 6; i += 1) {
      const response = await request(app.getHttpServer()).get('/v1/health');
      expect(response.status).not.toBe(429);
    }
    const response = await request(app.getHttpServer()).get('/v1/providers/status');
    expect(response.headers['x-content-type-options']).toBe('nosniff');
    expect(response.headers['x-frame-options']).toBe('DENY');
    expect(response.headers['x-powered-by']).toBeUndefined();
  });
});
