import { createServer, type Server } from 'node:http';
import { generateKeyPairSync, createSign, randomUUID } from 'node:crypto';
import type { AddressInfo } from 'node:net';

import type { INestApplication } from '@nestjs/common';
import { Test as NestTest } from '@nestjs/testing';
import request from 'supertest';

import { configureApp } from '../../src/app.bootstrap';
import { AppModule } from '../../src/app.module';
import { PrismaService } from '../../src/shared/database/prisma.service';

const describeDatabase = process.env.DATABASE_URL ? describe : describe.skip;

/**
 * End-to-end over real HTTP + PostgreSQL: the plan is created by one API
 * instance and started by a *different* instance (simulated restart). Tokens are
 * signed by a local OIDC issuer so the production verifier runs unmodified.
 */
describeDatabase('plan → start → progress → finish across an API restart', () => {
  const { publicKey, privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const kid = 'test-key';
  let jwks: Server;
  let issuer: string;
  const subject = `e2e-${randomUUID()}`;
  const previousEnv = { ...process.env };

  function token(): string {
    const b64 = (value: unknown) => Buffer.from(JSON.stringify(value)).toString('base64url');
    const signingInput = `${b64({ alg: 'RS256', kid, typ: 'JWT' })}.${b64({
      iss: issuer,
      aud: 'yegamo-api',
      sub: subject,
      exp: Math.floor(Date.now() / 1000) + 600,
      scope: 'openid',
    })}`;
    const signature = createSign('RSA-SHA256').update(signingInput).sign(privateKey).toString('base64url');
    return `${signingInput}.${signature}`;
  }

  async function createApp(): Promise<INestApplication> {
    const moduleRef = await NestTest.createTestingModule({ imports: [AppModule] }).compile();
    const app = configureApp(moduleRef.createNestApplication());
    await app.init();
    return app;
  }

  beforeAll(async () => {
    jwks = createServer((_, response) => {
      response.setHeader('content-type', 'application/json');
      response.end(JSON.stringify({ keys: [{ ...publicKey.export({ format: 'jwk' }), kid, alg: 'RS256', use: 'sig' }] }));
    });
    await new Promise<void>((resolve) => jwks.listen(0, '127.0.0.1', resolve));
    issuer = `http://127.0.0.1:${(jwks.address() as AddressInfo).port}/`;
    process.env.NODE_ENV = 'test';
    process.env.DEMO_PROVIDER_ENABLED = 'true';
    process.env.OIDC_ISSUER_URL = issuer;
    process.env.OIDC_AUDIENCE = 'yegamo-api';
    process.env.OIDC_JWKS_URL = `${issuer}jwks`;
  });

  afterAll(async () => {
    const prisma = new PrismaService();
    await prisma.user.deleteMany({ where: { subject } });
    await prisma.$disconnect();
    await new Promise<void>((resolve) => jwks.close(() => resolve()));
    process.env = previousEnv;
  });

  it('runs the whole vertical flow with honest, non-live fixture data', async () => {
    const body = {
      origin: { lat: -2.17, lon: -79.9 },
      destination: { lat: -2.14, lon: -79.89 },
      timeMode: 'LEAVE_NOW',
    };

    const first = await createApp();
    const plan = await request(first.getHttpServer()).post('/v1/journeys/plan').send(body).expect(200);
    await first.close();
    expect(plan.body.dataState).toBe('DEGRADED');
    const option = plan.body.options[0];
    expect(option.dataQuality).toMatchObject({ liveVehicle: false, sourceAuthorized: false, dataState: 'DEGRADED' });
    expect(option.legs).toHaveLength(2);

    const second = await createApp();
    try {
      const server = second.getHttpServer();
      // The plan survived the restart.
      await request(server).get(`/v1/journeys/${plan.body.planId}`).expect(200).expect(({ body: stored }) => expect(stored.options[0].id).toBe(option.id));

      const startUrl = `/v1/journeys/${plan.body.planId}/options/${option.id}/start`;
      await request(server).post(startUrl).set('Idempotency-Key', 'e2e-start-0001').expect(401);

      const started = await request(server).post(startUrl).set('Authorization', `Bearer ${token()}`).set('Idempotency-Key', 'e2e-start-0001').expect(201);
      expect(started.body).toMatchObject({ planId: plan.body.planId, optionId: option.id, status: 'ACTIVE', currentLegIndex: 0, eta: null, dataState: 'DEGRADED' });
      expect(started.body.legs).toHaveLength(2);
      expect(started.body.legs[0].instructions[0]).toContain('fixture de desarrollo');
      expect(started.body.dataQuality).toMatchObject({ liveVehicle: false, sourceAuthorized: false });
      const auth = { Authorization: `Bearer ${token()}` };
      const id: string = started.body.id;

      // Same Idempotency-Key replays the same journey; a second active journey conflicts.
      await request(server).post(startUrl).set(auth).set('Idempotency-Key', 'e2e-start-0001').expect(201).expect(({ body: replay }) => expect(replay.id).toBe(id));
      await request(server).post(startUrl).set(auth).set('Idempotency-Key', 'e2e-start-0002').expect(409);

      // Canonical progress: only currentLegIndex/location/occurredAt are accepted.
      await request(server).patch(`/v1/active-journeys/${id}/progress`).set(auth).set('Idempotency-Key', 'e2e-prog-0001').send({ stepIndex: 1 }).expect(422);
      await request(server).patch(`/v1/active-journeys/${id}/progress`).set(auth).set('Idempotency-Key', 'e2e-prog-0002').send({ currentLegIndex: 2 }).expect(422);
      await request(server).patch(`/v1/active-journeys/${id}/progress`).set(auth).set('Idempotency-Key', 'e2e-prog-0003').send({ currentLegIndex: 1, occurredAt: new Date().toISOString() }).expect(200).expect(({ body: moved }) => expect(moved.currentLegIndex).toBe(1));
      // Location is refused without consent.
      await request(server).patch(`/v1/active-journeys/${id}/progress`).set(auth).set('Idempotency-Key', 'e2e-prog-0004').send({ location: { lat: -2.15, lon: -79.9 } }).expect(403);

      await request(server).get(`/v1/active-journeys/${id}`).set(auth).expect(200).expect(({ body: current }) => expect(current.currentLegIndex).toBe(1));
      await request(server).post(`/v1/active-journeys/${id}/finish`).set(auth).set('Idempotency-Key', 'e2e-fin-0001').expect(200).expect(({ body: done }) => expect(done.status).toBe('COMPLETED'));
      await request(server).patch(`/v1/active-journeys/${id}/progress`).set(auth).set('Idempotency-Key', 'e2e-prog-0005').send({ currentLegIndex: 0 }).expect(409);
    } finally {
      await second.close();
    }
  });
});
